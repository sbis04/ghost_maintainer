import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

/// `ghost_maintainer implement <issue_number>` — trigger feature implementation.
class ImplementCommand extends Command<void> {
  @override
  final name = 'implement';

  @override
  final description = 'Implement a feature and create a PR. Usage: ghost_maintainer implement <issue_number>';

  ImplementCommand() {
    argParser
      ..addOption('repo', help: 'GitHub repo. Auto-detected if omitted.')
      ..addOption('github-token', help: 'GitHub PAT. Reads from .ghost_maintainer.env if omitted.');
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      print('Usage: ghost_maintainer implement <issue_number>');
      exit(1);
    }

    final issueNumber = argResults!.rest.first;
    if (int.tryParse(issueNumber) == null) {
      print('Error: "$issueNumber" is not a valid issue number.');
      exit(1);
    }

    final env = _readEnv();
    final repo = argResults!['repo'] as String? ?? env['TARGET_REPO'] ?? _detectRepo();
    final token = argResults!['github-token'] as String? ?? env['GITHUB_TOKEN'];

    if (repo == null || token == null) {
      print('Missing repo or GitHub token. Run from a directory with .ghost_maintainer.env');
      exit(1);
    }

    await _triggerWorkflow(repo, token, issueNumber, 'feature');
  }

  Future<void> _triggerWorkflow(String repo, String token, String issueNumber, String type) async {
    print('Triggering feature implementation for #$issueNumber on $repo...');

    final client = http.Client();
    final response = await client.post(
      Uri.parse('https://api.github.com/repos/$repo/actions/workflows/implement_feature.yml/dispatches'),
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'ref': 'main',
        'inputs': {'issue_number': issueNumber, 'type': type},
      }),
    );

    client.close();

    if (response.statusCode == 204) {
      print('Feature implementation triggered! Check GitHub Actions for progress:');
      print('  https://github.com/$repo/actions');
    } else {
      print('Failed: ${response.statusCode} ${response.body}');
    }
  }

  String? _detectRepo() {
    final result = Process.runSync('git', ['remote', 'get-url', 'origin']);
    if (result.exitCode != 0) return null;
    final url = (result.stdout as String).trim();
    return RegExp(r'github\.com[:/]([^/]+/[^/.]+)').firstMatch(url)?.group(1);
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
