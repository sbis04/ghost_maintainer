import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

import '../notion_client.dart';

/// `ghost_maintainer sync` — import existing GitHub issues into Notion.
///
/// Fetches all open issues from the repo, creates Triage Queue entries,
/// and optionally runs AI triage on each one.
class SyncCommand extends Command<void> {
  @override
  final name = 'sync';

  @override
  final description =
      'Import existing GitHub issues into the Notion Triage Queue.';

  SyncCommand() {
    argParser
      ..addOption('repo',
          help: 'GitHub repo (owner/repo). Auto-detected if omitted.')
      ..addOption('github-token',
          help: 'GitHub PAT. Reads from .ghost_maintainer.env if omitted.')
      ..addOption('notion-token',
          help: 'Notion token. Reads from .ghost_maintainer.env if omitted.')
      ..addOption('triage-db-id',
          help: 'Triage Queue DB ID. Reads from .ghost_maintainer.env if omitted.')
      ..addOption('state',
          help: 'Issue state to sync.',
          allowed: ['open', 'closed', 'all'],
          defaultsTo: 'open')
      ..addOption('limit',
          help: 'Max issues to sync (0 = all).',
          defaultsTo: '0');
  }

  @override
  Future<void> run() async {
    final env = _readEnv();

    final repo = argResults!['repo'] as String? ?? env['TARGET_REPO'] ?? _detectRepo();
    final githubToken =
        argResults!['github-token'] as String? ?? env['GITHUB_TOKEN'];
    final notionToken =
        argResults!['notion-token'] as String? ?? env['NOTION_TOKEN'];
    final triageDbId =
        argResults!['triage-db-id'] as String? ?? env['NOTION_TRIAGE_DB_ID'];
    final state = argResults!['state'] as String;
    final limit = int.tryParse(argResults!['limit'] as String) ?? 0;

    if (repo == null || githubToken == null || notionToken == null || triageDbId == null) {
      print('''
Missing required values. Either provide flags or run from a directory
with a .ghost_maintainer.env file (created by `ghost_maintainer setup`).

Usage:
  ghost_maintainer sync [--state open] [--limit 20]
''');
      exit(1);
    }

    final httpClient = http.Client();
    final notionClient = NotionClient(token: notionToken);

    // 1. Get existing issue numbers already in Triage Queue to avoid duplicates
    print('');
    print('Checking existing Notion entries...');
    final existingPages = await notionClient.queryDatabase(triageDbId);
    final existingIssueNumbers = <int>{};
    for (final page in existingPages) {
      final issueNum = (page['properties']?['Issue Number']?['number'] as double?)?.toInt();
      if (issueNum != null) existingIssueNumbers.add(issueNum);
    }

    // Also check Maintenance Backlog and Feature Backlog
    final bugDbId = env['NOTION_DATABASE_ID'];
    final featureDbId = env['NOTION_FEATURE_DB_ID'];
    for (final dbId in [bugDbId, featureDbId]) {
      if (dbId == null) continue;
      final pages = await notionClient.queryDatabase(dbId);
      for (final page in pages) {
        final issueNum = (page['properties']?['Issue Number']?['number'] as double?)?.toInt();
        if (issueNum != null) existingIssueNumbers.add(issueNum);
      }
    }

    if (existingIssueNumbers.isNotEmpty) {
      print('  Found ${existingIssueNumbers.length} issues already in Notion, will skip those.');
    }

    // 2. Fetch issues from GitHub
    print('Fetching $state issues from $repo...');
    final issues = <Map<String, dynamic>>[];
    var page = 1;

    while (true) {
      final response = await httpClient.get(
        Uri.parse(
            'https://api.github.com/repos/$repo/issues?state=$state&per_page=100&page=$page&sort=created&direction=asc'),
        headers: {
          'Authorization': 'token $githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode != 200) {
        stderr.writeln('GitHub API error: ${response.statusCode}');
        exit(1);
      }

      final batch = (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
      if (batch.isEmpty) break;

      // Filter out pull requests (GitHub returns PRs in the issues endpoint)
      for (final issue in batch) {
        if (issue.containsKey('pull_request')) continue;
        issues.add(issue);
      }

      page++;
      if (limit > 0 && issues.length >= limit) {
        issues.removeRange(limit, issues.length);
        break;
      }
    }

    // Filter out already-synced issues
    final toSync = issues
        .where((i) => !existingIssueNumbers.contains(i['number'] as int))
        .toList();

    print('  ${issues.length} issues found, ${toSync.length} new to sync.');

    if (toSync.isEmpty) {
      print('');
      print('Nothing to sync!');
      httpClient.close();
      notionClient.dispose();
      return;
    }

    // 3. Create Triage Queue entries
    print('');
    print('Syncing ${toSync.length} issues to Triage Queue...');

    var synced = 0;
    for (final issue in toSync) {
      final number = issue['number'] as int;
      final title = issue['title'] as String? ?? 'Untitled';
      final body = issue['body'] as String? ?? '';
      final url = issue['html_url'] as String? ?? '';

      // Build body chunks (max 2000 chars per block)
      final bodyChunks = <Map<String, dynamic>>[];
      var remaining = body;
      while (remaining.isNotEmpty) {
        final chunk = remaining.length > 2000
            ? remaining.substring(0, 2000)
            : remaining;
        bodyChunks.add({
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [
              {'type': 'text', 'text': {'content': chunk}}
            ]
          },
        });
        remaining = remaining.length > 2000 ? remaining.substring(2000) : '';
      }

      if (bodyChunks.isEmpty) {
        bodyChunks.add({
          'object': 'block',
          'type': 'paragraph',
          'paragraph': {
            'rich_text': [
              {'type': 'text', 'text': {'content': '(No issue body)'}}
            ]
          },
        });
      }

      await notionClient.createDatabasePage(
        databaseId: triageDbId,
        properties: {
          'Title': {
            'title': [
              {'text': {'content': title}}
            ]
          },
          'Stage': {'select': {'name': 'New'}},
          'Issue Type': {'select': {'name': 'Unknown'}},
          'GitHub Issue': {'url': url.isNotEmpty ? url : null},
          'Issue Number': {'number': number},
        },
        children: [
          {
            'object': 'block',
            'type': 'heading_2',
            'heading_2': {
              'rich_text': [
                {'type': 'text', 'text': {'content': 'Original Issue'}}
              ]
            },
          },
          ...bodyChunks,
          {'object': 'block', 'type': 'divider', 'divider': {}},
        ],
      );

      synced++;
      print('  [$synced/${toSync.length}] #$number: $title');
    }

    print('');
    print('Synced $synced issues to Triage Queue.');
    print('');
    print('Next: create a GitHub Action run or use the MCP server to triage them.');
    print('The next time a new issue is created, the triage workflow will also');
    print('pick up these synced issues if they\'re still in "New" stage.');
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

  Map<String, String> _readEnv() {
    final result = <String, String>{};
    final file = File('.ghost_maintainer.env');
    if (!file.existsSync()) return result;
    for (final line in file.readAsLinesSync()) {
      if (line.startsWith('#') || !line.contains('=')) continue;
      final idx = line.indexOf('=');
      result[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
    }
    return result;
  }
}
