import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Pushes workflow files and notion_setup scripts to the target repo.
void main() async {
  final token = Platform.environment['GITHUB_TOKEN']!;
  final repo = Platform.environment['TARGET_REPO']!;
  final client = http.Client();

  final headers = {
    'Authorization': 'token $token',
    'Accept': 'application/vnd.github.v3+json',
    'Content-Type': 'application/json',
  };

  final baseDir = Platform.environment['BASE_DIR'] ??
      '/Users/souvikbiswas/MobileDev/notion_mcp_challenge';

  final filesToPush = {
    '.github/workflows/issue_to_notion.yml':
        '$baseDir/.github/workflows/issue_to_notion.yml',
    '.github/workflows/pr_merged_archive.yml':
        '$baseDir/.github/workflows/pr_merged_archive.yml',
    'notion_setup/pubspec.yaml': '$baseDir/notion_setup/pubspec.yaml',
    'notion_setup/lib/notion_client.dart':
        '$baseDir/notion_setup/lib/notion_client.dart',
    'notion_setup/bin/issue_ingestion.dart':
        '$baseDir/notion_setup/bin/issue_ingestion.dart',
    'notion_setup/bin/archive_merged.dart':
        '$baseDir/notion_setup/bin/archive_merged.dart',
    'notion_setup/bin/auto_triage.dart':
        '$baseDir/notion_setup/bin/auto_triage.dart',
    'notion_setup/bin/auto_investigate.dart':
        '$baseDir/notion_setup/bin/auto_investigate.dart',
    'notion_setup/bin/auto_deploy.dart':
        '$baseDir/notion_setup/bin/auto_deploy.dart',
  };

  for (final entry in filesToPush.entries) {
    final repoPath = entry.key;
    final localPath = entry.value;
    final content = File(localPath).readAsStringSync();
    final encoded = base64Encode(utf8.encode(content));

    // Check if file exists to get SHA
    String? existingSha;
    final checkResponse = await client.get(
      Uri.parse(
          'https://api.github.com/repos/$repo/contents/$repoPath'),
      headers: headers,
    );
    if (checkResponse.statusCode == 200) {
      final data = jsonDecode(checkResponse.body) as Map<String, dynamic>;
      existingSha = data['sha'] as String?;
    }

    final body = <String, dynamic>{
      'message': 'chore: add $repoPath for Ghost Maintainer',
      'content': encoded,
    };
    if (existingSha != null) body['sha'] = existingSha;

    final response = await client.put(
      Uri.parse(
          'https://api.github.com/repos/$repo/contents/$repoPath'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✓ $repoPath');
    } else {
      print('✗ $repoPath: ${response.statusCode} ${response.body}');
    }
  }

  client.close();
  print('\nDone! All files pushed to $repo.');
}
