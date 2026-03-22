import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../lib/notion_client.dart';

/// One-command setup for Ghost Maintainer.
///
/// Creates all Notion databases, adds GitHub repo secrets,
/// pushes workflows, and enables PR creation.
///
/// Can run standalone (downloads files from public repo) or locally.
void main(List<String> args) async {
  final parsed = _parseArgs(args);
  final notionToken = parsed['notion-token'];
  final githubToken = parsed['github-token'];
  final geminiKey = parsed['gemini-key'];
  final targetRepo = parsed['repo'];
  final parentPageId = parsed['notion-parent-page-id'];
  final sourceRepo = parsed['source-repo'] ?? 'sbis04/ghost_maintainer';

  if (notionToken == null ||
      githubToken == null ||
      geminiKey == null ||
      targetRepo == null ||
      parentPageId == null) {
    print('''
Ghost Maintainer - Setup

Usage:
  dart run bin/setup.dart \\
    --notion-token ntn_... \\
    --github-token ghp_... \\
    --gemini-key AIza... \\
    --repo owner/repo \\
    --notion-parent-page-id PAGE_ID

Get your tokens:
  Notion: https://www.notion.so/profile/integrations
  GitHub: https://github.com/settings/tokens (scopes: repo, actions)
  Gemini: https://aistudio.google.com/apikey
''');
    exit(1);
  }

  final notionClient = NotionClient(token: notionToken);
  final httpClient = http.Client();

  print('');
  print('=== Ghost Maintainer Setup ===');
  print('');

  // --- Step 1: Create all Notion databases ---
  print('[1/6] Creating Notion databases...');

  final maintenanceDb = await notionClient.createDatabase(
    parentPageId: parentPageId,
    title: 'Maintenance Backlog',
    properties: _maintenanceBacklogProps,
  );
  final maintenanceDbId = maintenanceDb['id'] as String;
  print('  + Maintenance Backlog');

  final triageDb = await notionClient.createDatabase(
    parentPageId: parentPageId,
    title: 'Triage Queue',
    properties: _triageQueueProps,
  );
  final triageDbId = triageDb['id'] as String;
  print('  + Triage Queue');

  final featureDb = await notionClient.createDatabase(
    parentPageId: parentPageId,
    title: 'Feature Backlog',
    properties: _featureBacklogProps,
  );
  final featureDbId = featureDb['id'] as String;
  print('  + Feature Backlog');

  final archiveDb = await notionClient.createDatabase(
    parentPageId: parentPageId,
    title: 'Archive',
    properties: _archiveProps,
  );
  final archiveDbId = archiveDb['id'] as String;
  print('  + Archive');

  // --- Step 2: Create Vision Statement ---
  print('[2/6] Creating Project Vision Statement...');

  final visionPage = await notionClient.createPage(
    parentPageId: parentPageId,
    title: 'Project Vision Statement',
    children: _visionContent,
  );
  final visionPageId = visionPage['id'] as String;
  print('  + Vision Statement');

  // --- Step 3: Add GitHub repo secrets ---
  print('[3/6] Adding GitHub repo secrets...');

  final secrets = {
    'NOTION_TOKEN': notionToken,
    'NOTION_DATABASE_ID': maintenanceDbId,
    'NOTION_VISION_PAGE_ID': visionPageId,
    'NOTION_TRIAGE_DB_ID': triageDbId,
    'NOTION_FEATURE_DB_ID': featureDbId,
    'NOTION_ARCHIVE_DB_ID': archiveDbId,
    'GEMINI_API_KEY': geminiKey,
  };

  var secretsOk = true;
  for (final entry in secrets.entries) {
    final result = Process.runSync('gh', [
      'secret',
      'set',
      entry.key,
      '--repo',
      targetRepo,
      '--body',
      entry.value,
    ]);
    if (result.exitCode == 0) {
      print('  + ${entry.key}');
    } else {
      secretsOk = false;
      print('  ! ${entry.key} failed');
    }
  }

  if (!secretsOk) {
    print('');
    print('  Some secrets failed. If `gh` CLI is not installed:');
    print('    brew install gh && gh auth login');
    print('  Or add secrets manually at:');
    print('    https://github.com/$targetRepo/settings/secrets/actions');
  }

  // --- Step 4: Enable PR creation for Actions ---
  print('[4/6] Enabling GitHub Actions PR creation...');

  final permResponse = await httpClient.put(
    Uri.parse(
        'https://api.github.com/repos/$targetRepo/actions/permissions/workflow'),
    headers: {
      'Authorization': 'token $githubToken',
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'default_workflow_permissions': 'write',
      'can_approve_pull_request_reviews': true,
    }),
  );

  if (permResponse.statusCode == 204 || permResponse.statusCode == 200) {
    print('  + GitHub Actions can now create PRs');
  } else {
    print('  ! Could not enable automatically. Enable manually:');
    print('    $targetRepo > Settings > Actions > General > '
        'Allow Actions to create PRs');
  }

  // --- Step 5: Push workflows and scripts to target repo ---
  print('[5/6] Pushing workflows and scripts to $targetRepo...');

  final filesToPush = [
    '.github/workflows/issue_to_notion.yml',
    '.github/workflows/pr_merged_archive.yml',
    '.github/workflows/implement_feature.yml',
    'notion_setup/pubspec.yaml',
    'notion_setup/lib/notion_client.dart',
    'notion_setup/bin/issue_ingestion.dart',
    'notion_setup/bin/archive_merged.dart',
    'notion_setup/bin/auto_triage.dart',
    'notion_setup/bin/auto_investigate.dart',
    'notion_setup/bin/auto_deploy.dart',
  ];

  final ghHeaders = {
    'Authorization': 'token $githubToken',
    'Accept': 'application/vnd.github.v3+json',
    'Content-Type': 'application/json',
  };

  for (final filePath in filesToPush) {
    // Try reading locally first, fall back to downloading from source repo
    String? content;

    // Check if running from the ghost-maintainer repo (local files available)
    final localFile = File('../$filePath');
    if (localFile.existsSync()) {
      content = localFile.readAsStringSync();
    } else {
      // Download from public repo
      final rawUrl =
          'https://raw.githubusercontent.com/$sourceRepo/main/$filePath';
      final dlResponse = await httpClient.get(Uri.parse(rawUrl));
      if (dlResponse.statusCode == 200) {
        content = dlResponse.body;
      }
    }

    if (content == null) {
      print('  ! $filePath: not found');
      continue;
    }

    final encoded = base64Encode(utf8.encode(content));

    // Check if file exists in target repo (need SHA to update)
    String? existingSha;
    final checkResponse = await httpClient.get(
      Uri.parse(
          'https://api.github.com/repos/$targetRepo/contents/$filePath'),
      headers: ghHeaders,
    );
    if (checkResponse.statusCode == 200) {
      final data = jsonDecode(checkResponse.body) as Map<String, dynamic>;
      existingSha = data['sha'] as String?;
    }

    final body = <String, dynamic>{
      'message': 'chore: add $filePath for Ghost Maintainer',
      'content': encoded,
    };
    if (existingSha != null) body['sha'] = existingSha;

    final response = await httpClient.put(
      Uri.parse(
          'https://api.github.com/repos/$targetRepo/contents/$filePath'),
      headers: ghHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('  + $filePath');
    } else {
      print('  ! $filePath: ${response.statusCode}');
    }
  }

  // --- Step 6: Write local .env for reference ---
  print('[6/6] Writing local .env...');

  final envContent = '''# Ghost Maintainer Configuration (auto-generated)
NOTION_TOKEN=$notionToken
NOTION_DATABASE_ID=$maintenanceDbId
NOTION_VISION_PAGE_ID=$visionPageId
NOTION_TRIAGE_DB_ID=$triageDbId
NOTION_FEATURE_DB_ID=$featureDbId
NOTION_ARCHIVE_DB_ID=$archiveDbId
GITHUB_TOKEN=$githubToken
TARGET_REPO=$targetRepo
GEMINI_API_KEY=$geminiKey
''';
  File('.ghost_maintainer.env').writeAsStringSync(envContent);
  print('  + .ghost_maintainer.env (local reference)');

  print('');
  print('=== Setup complete! ===');
  print('');
  print('Ghost Maintainer is now active on $targetRepo.');
  print('');
  print('Test it: create a GitHub issue and watch the automation run.');
  print('');
  print('Optional: Set up the Cloudflare Worker webhook for one-click');
  print('feature implementation from Notion. See:');
  print('  https://github.com/$sourceRepo/blob/main/webhook/README.md');
  print('');

  httpClient.close();
  notionClient.dispose();
}

Map<String, String?> _parseArgs(List<String> args) {
  final result = <String, String?>{};
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--') && i + 1 < args.length) {
      result[args[i].substring(2)] = args[i + 1];
      i++;
    }
  }
  return result;
}

// --- Database schemas ---

final _maintenanceBacklogProps = <String, dynamic>{
  'Title': {'title': {}},
  'Stage': {
    'select': {
      'options': [
        {'name': 'New', 'color': 'gray'},
        {'name': 'Triaged', 'color': 'blue'},
        {'name': 'Investigating', 'color': 'yellow'},
        {'name': 'Review', 'color': 'orange'},
        {'name': 'Deploy', 'color': 'green'},
        {'name': 'Archived', 'color': 'default'},
      ]
    }
  },
  'Priority': {
    'select': {
      'options': [
        {'name': 'P0-Critical', 'color': 'red'},
        {'name': 'P1-High', 'color': 'orange'},
        {'name': 'P2-Medium', 'color': 'yellow'},
        {'name': 'P3-Low', 'color': 'gray'},
      ]
    }
  },
  'Labels': {
    'multi_select': {
      'options': [
        {'name': 'Bug', 'color': 'red'},
        {'name': 'Feature', 'color': 'blue'},
        {'name': 'Docs', 'color': 'green'},
        {'name': 'Performance', 'color': 'yellow'},
        {'name': 'Security', 'color': 'pink'},
        {'name': 'Chore', 'color': 'gray'},
      ]
    }
  },
  'GitHub Issue': {'url': {}},
  'Issue Number': {'number': {'format': 'number'}},
  'PR URL': {'url': {}},
  'AI Summary': {'rich_text': {}},
  'AI Confidence': {'number': {'format': 'number'}},
};

final _triageQueueProps = <String, dynamic>{
  'Title': {'title': {}},
  'Stage': {
    'select': {
      'options': [
        {'name': 'New', 'color': 'gray'},
        {'name': 'Triaged', 'color': 'blue'},
        {'name': 'Needs Review', 'color': 'orange'},
        {'name': 'Routed', 'color': 'green'},
      ]
    }
  },
  'Issue Type': {
    'select': {
      'options': [
        {'name': 'Bug', 'color': 'red'},
        {'name': 'Feature', 'color': 'blue'},
        {'name': 'Unknown', 'color': 'gray'},
      ]
    }
  },
  'Priority': {
    'select': {
      'options': [
        {'name': 'P0-Critical', 'color': 'red'},
        {'name': 'P1-High', 'color': 'orange'},
        {'name': 'P2-Medium', 'color': 'yellow'},
        {'name': 'P3-Low', 'color': 'gray'},
      ]
    }
  },
  'Labels': {
    'multi_select': {
      'options': [
        {'name': 'Bug', 'color': 'red'},
        {'name': 'Feature', 'color': 'blue'},
        {'name': 'Docs', 'color': 'green'},
        {'name': 'Performance', 'color': 'yellow'},
        {'name': 'Security', 'color': 'pink'},
        {'name': 'Chore', 'color': 'gray'},
      ]
    }
  },
  'GitHub Issue': {'url': {}},
  'Issue Number': {'number': {'format': 'number'}},
  'AI Summary': {'rich_text': {}},
  'AI Confidence': {'number': {'format': 'number'}},
};

final _featureBacklogProps = <String, dynamic>{
  'Title': {'title': {}},
  'Stage': {
    'select': {
      'options': [
        {'name': 'New', 'color': 'gray'},
        {'name': 'Planned', 'color': 'blue'},
        {'name': 'Investigating', 'color': 'yellow'},
        {'name': 'Review', 'color': 'orange'},
        {'name': 'Deploy', 'color': 'green'},
        {'name': 'In Progress', 'color': 'purple'},
        {'name': 'Done', 'color': 'default'},
        {'name': 'Archived', 'color': 'default'},
      ]
    }
  },
  'Priority': {
    'select': {
      'options': [
        {'name': 'P0-Critical', 'color': 'red'},
        {'name': 'P1-High', 'color': 'orange'},
        {'name': 'P2-Medium', 'color': 'yellow'},
        {'name': 'P3-Low', 'color': 'gray'},
      ]
    }
  },
  'Labels': {
    'multi_select': {
      'options': [
        {'name': 'Feature', 'color': 'blue'},
        {'name': 'Enhancement', 'color': 'purple'},
        {'name': 'Docs', 'color': 'green'},
        {'name': 'Performance', 'color': 'yellow'},
      ]
    }
  },
  'GitHub Issue': {'url': {}},
  'Issue Number': {'number': {'format': 'number'}},
  'AI Summary': {'rich_text': {}},
  'AI Confidence': {'number': {'format': 'number'}},
  'PR URL': {'url': {}},
};

final _archiveProps = <String, dynamic>{
  'Title': {'title': {}},
  'Type': {
    'select': {
      'options': [
        {'name': 'Bug', 'color': 'red'},
        {'name': 'Feature', 'color': 'blue'},
      ]
    }
  },
  'Priority': {
    'select': {
      'options': [
        {'name': 'P0-Critical', 'color': 'red'},
        {'name': 'P1-High', 'color': 'orange'},
        {'name': 'P2-Medium', 'color': 'yellow'},
        {'name': 'P3-Low', 'color': 'gray'},
      ]
    }
  },
  'Labels': {
    'multi_select': {
      'options': [
        {'name': 'Bug', 'color': 'red'},
        {'name': 'Feature', 'color': 'blue'},
        {'name': 'Docs', 'color': 'green'},
        {'name': 'Performance', 'color': 'yellow'},
        {'name': 'Security', 'color': 'pink'},
        {'name': 'Chore', 'color': 'gray'},
      ]
    }
  },
  'GitHub Issue': {'url': {}},
  'Issue Number': {'number': {'format': 'number'}},
  'PR URL': {'url': {}},
  'AI Summary': {'rich_text': {}},
  'Resolved Date': {'date': {}},
};

final _visionContent = <Map<String, dynamic>>[
  {
    'object': 'block',
    'type': 'heading_2',
    'heading_2': {
      'rich_text': [
        {'type': 'text', 'text': {'content': 'Mission'}}
      ]
    },
  },
  {
    'object': 'block',
    'type': 'paragraph',
    'paragraph': {
      'rich_text': [
        {
          'type': 'text',
          'text': {
            'content':
                'Build a reliable, well-documented open-source tool that developers love to use. '
                    'Prioritize stability and developer experience over feature count.'
          }
        }
      ]
    },
  },
  {
    'object': 'block',
    'type': 'heading_2',
    'heading_2': {
      'rich_text': [
        {'type': 'text', 'text': {'content': 'Principles'}}
      ]
    },
  },
  ...[
    'Keep the API surface small and intuitive',
    'Every feature should have comprehensive tests',
    'Performance matters — avoid unnecessary allocations',
    'Security is non-negotiable — validate all inputs',
    'Documentation is a feature, not an afterthought',
  ].map((item) => <String, dynamic>{
        'object': 'block',
        'type': 'bulleted_list_item',
        'bulleted_list_item': {
          'rich_text': [
            {'type': 'text', 'text': {'content': item}}
          ]
        },
      }),
  {
    'object': 'block',
    'type': 'heading_2',
    'heading_2': {
      'rich_text': [
        {'type': 'text', 'text': {'content': 'Current Focus'}}
      ]
    },
  },
  {
    'object': 'block',
    'type': 'paragraph',
    'paragraph': {
      'rich_text': [
        {
          'type': 'text',
          'text': {
            'content':
                'The current release cycle focuses on stability and bug fixes. '
                    'New features are deprioritized until the existing test suite reaches 90% coverage. '
                    'Security issues are always P0.'
          }
        }
      ]
    },
  },
];
