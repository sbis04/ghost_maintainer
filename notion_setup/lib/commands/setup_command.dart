import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../notion_client.dart';
import '../schemas.dart';

/// `ghost_maintainer setup` — one-command project setup.
class SetupCommand extends Command<void> {
  @override
  final name = 'setup';

  @override
  final description =
      'Set up Ghost Maintainer on your repo (creates Notion databases, '
      'adds GitHub secrets, pushes workflows).';

  SetupCommand() {
    argParser
      ..addOption('notion-token', help: 'Notion integration token (ntn_...)')
      ..addOption('github-token', help: 'GitHub PAT (ghp_...)')
      ..addOption('gemini-key', help: 'Gemini API key')
      ..addOption('repo', help: 'GitHub repo (owner/repo). Auto-detected if omitted.')
      ..addOption('notion-parent-page-id', help: 'Notion page URL or ID')
      ..addOption('source-repo',
          help: 'Ghost Maintainer source repo',
          defaultsTo: 'sbis04/ghost_maintainer')
      ..addFlag('auto-fix-bugs',
          help: 'Auto-investigate bugs and create PRs',
          defaultsTo: true)
      ..addOption('webhook-url',
          help: 'Cloudflare Worker URL for one-click buttons (optional)')
      ..addOption('webhook-secret',
          help: 'Webhook secret for one-click buttons (optional)');
  }

  @override
  Future<void> run() async {
    final notionToken = argResults!['notion-token'] as String?;
    final githubToken = argResults!['github-token'] as String?;
    final geminiKey = argResults!['gemini-key'] as String?;
    var targetRepo = argResults!['repo'] as String?;
    final parentPageInput = argResults!['notion-parent-page-id'] as String?;
    final sourceRepo = argResults!['source-repo'] as String;
    final autoFixBugs = argResults!['auto-fix-bugs'] as bool;
    final webhookUrl = argResults!['webhook-url'] as String?;
    final webhookSecret = argResults!['webhook-secret'] as String?;

    // Auto-detect repo if not provided
    targetRepo ??= _detectRepo();

    if (notionToken == null ||
        githubToken == null ||
        geminiKey == null ||
        targetRepo == null ||
        parentPageInput == null) {
      print('''
Ghost Maintainer - Setup

Usage:
  ghost_maintainer setup \\
    --notion-token ntn_... \\
    --github-token ghp_... \\
    --gemini-key AIza... \\
    --notion-parent-page-id PAGE_URL_OR_ID \\
    [--repo owner/repo] \\
    [--no-auto-fix-bugs]

Get your tokens:
  Notion: https://www.notion.so/profile/integrations
  GitHub: https://github.com/settings/tokens (scopes: repo, actions)
  Gemini: https://aistudio.google.com/apikey
''');
      exit(1);
    }

    // Extract page ID from URL if needed
    final parentPageId = _extractPageId(parentPageInput);

    final notionClient = NotionClient(token: notionToken);
    final httpClient = http.Client();

    print('');
    print('=== Ghost Maintainer Setup ===');
    print('  Repo: $targetRepo');
    print('  Auto-fix bugs: $autoFixBugs');
    print('');

    // --- Step 1: Create all Notion databases ---
    print('[1/7] Creating Notion databases...');

    final maintenanceDb = await notionClient.createDatabase(
      parentPageId: parentPageId,
      title: 'Maintenance Backlog',
      properties: maintenanceBacklogProps,
    );
    final maintenanceDbId = maintenanceDb['id'] as String;
    print('  + Maintenance Backlog');

    final triageDb = await notionClient.createDatabase(
      parentPageId: parentPageId,
      title: 'Triage Queue',
      properties: triageQueueProps,
    );
    final triageDbId = triageDb['id'] as String;
    print('  + Triage Queue');

    final featureDb = await notionClient.createDatabase(
      parentPageId: parentPageId,
      title: 'Feature Backlog',
      properties: featureBacklogProps,
    );
    final featureDbId = featureDb['id'] as String;
    print('  + Feature Backlog');

    final archiveDb = await notionClient.createDatabase(
      parentPageId: parentPageId,
      title: 'Archive',
      properties: archiveProps,
    );
    final archiveDbId = archiveDb['id'] as String;
    print('  + Archive');

    // --- Step 2: Create Vision Statement ---
    print('[2/7] Creating Project Vision Statement...');

    final visionPage = await notionClient.createPage(
      parentPageId: parentPageId,
      title: 'Project Vision Statement',
      children: visionContent,
    );
    final visionPageId = visionPage['id'] as String;
    print('  + Vision Statement');

    // --- Step 3: Add one-click buttons (if webhook configured) ---
    if (webhookUrl != null && webhookSecret != null) {
      print('[3/8] Adding one-click buttons to Notion...');

      final fixExpression =
          'link("Fix", "$webhookUrl?issue=" + format(prop("Issue Number")) + "&type=bug&secret=$webhookSecret")';
      final implementExpression =
          'link("Implement", "$webhookUrl?issue=" + format(prop("Issue Number")) + "&type=feature&secret=$webhookSecret")';

      await notionClient.updateDatabase(maintenanceDbId, properties: {
        'Fix': {
          'formula': {'expression': fixExpression}
        },
      });
      print('  + Maintenance Backlog: "Fix" button');

      await notionClient.updateDatabase(featureDbId, properties: {
        'Implement': {
          'formula': {'expression': implementExpression}
        },
      });
      print('  + Feature Backlog: "Implement" button');
    } else {
      print('[3/8] Skipping one-click buttons (no --webhook-url provided)');
    }

    // --- Step 4: Save and push config ---
    print('[4/8] Creating config...');

    final config = GhostConfig(autoFixBugs: autoFixBugs);
    config.save();
    print('  + .ghost_maintainer.json (auto_fix_bugs: $autoFixBugs)');

    // --- Step 5: Add GitHub repo secrets ---
    print('[5/8] Adding GitHub repo secrets...');

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
        'secret', 'set', entry.key, '--repo', targetRepo, '--body', entry.value,
      ]);
      if (result.exitCode == 0) {
        print('  + ${entry.key}');
      } else {
        secretsOk = false;
        print('  ! ${entry.key} failed');
      }
    }

    if (!secretsOk) {
      print('  Some secrets failed. Install gh CLI: brew install gh && gh auth login');
      print('  Or add manually: https://github.com/$targetRepo/settings/secrets/actions');
    }

    // --- Step 6: Enable PR creation for Actions ---
    print('[6/8] Enabling GitHub Actions PR creation...');

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
      print('  ! Enable manually: Settings > Actions > General > Allow Actions to create PRs');
    }

    // --- Step 7: Push config, workflows, and scripts ---
    print('[7/8] Pushing files to $targetRepo...');

    final filesToPush = [
      '.ghost_maintainer.json',
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
      String? content;

      // For config file, use the one we just created
      if (filePath == '.ghost_maintainer.json') {
        content = File('.ghost_maintainer.json').readAsStringSync();
      } else {
        // Try local first, then download from source repo
        final localFile = File('../$filePath');
        if (localFile.existsSync()) {
          content = localFile.readAsStringSync();
        } else {
          final rawUrl =
              'https://raw.githubusercontent.com/$sourceRepo/main/$filePath';
          final dlResponse = await httpClient.get(Uri.parse(rawUrl));
          if (dlResponse.statusCode == 200) {
            content = dlResponse.body;
          }
        }
      }

      if (content == null) {
        print('  ! $filePath: not found');
        continue;
      }

      final encoded = base64Encode(utf8.encode(content));

      String? existingSha;
      final checkResponse = await httpClient.get(
        Uri.parse(
            'https://api.github.com/repos/$targetRepo/contents/$filePath'),
        headers: ghHeaders,
      );
      if (checkResponse.statusCode == 200) {
        existingSha =
            (jsonDecode(checkResponse.body) as Map)['sha'] as String?;
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

    // --- Step 8: Write local env reference ---
    print('[8/8] Writing local .ghost_maintainer.env...');

    final envContent = '''# Ghost Maintainer (auto-generated)
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
    print('  + .ghost_maintainer.env');

    print('');
    print('=== Setup complete! ===');
    print('');
    print('Ghost Maintainer is active on $targetRepo.');
    print('Test it: create a GitHub issue and watch the automation run.');
    if (!autoFixBugs) {
      print('');
      print('Note: Auto-fix for bugs is DISABLED. Bugs will be triaged but');
      print('not auto-investigated. Enable with: ghost_maintainer config --auto-fix-bugs=true');
    }
    print('');

    httpClient.close();
    notionClient.dispose();
  }

  String? _detectRepo() {
    final result = Process.runSync('git', ['remote', 'get-url', 'origin']);
    if (result.exitCode != 0) return null;
    final url = (result.stdout as String).trim();
    final match = RegExp(r'github\.com[:/]([^/]+/[^/.]+)').firstMatch(url);
    return match?.group(1);
  }

  String _extractPageId(String input) {
    // Strip query params
    final clean = input.split('?').first.split('#').first;

    // Extract last 32 hex chars (Notion page ID is always at the end of the URL slug)
    final match = RegExp(r'([0-9a-fA-F]{32})').allMatches(clean).lastOrNull;
    if (match != null) return match.group(1)!;

    // Try UUID format (with dashes)
    final uuidMatch = RegExp(r'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})').firstMatch(clean);
    if (uuidMatch != null) return uuidMatch.group(1)!;

    // Return as-is (user pasted raw ID)
    return input.trim();
  }
}
