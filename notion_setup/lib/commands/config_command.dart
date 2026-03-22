import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// `ghost_maintainer config` — view or update configuration.
///
/// Examples:
///   ghost_maintainer config                         # Show current config
///   ghost_maintainer config --auto-fix-bugs=false   # Disable auto bug fixes
///   ghost_maintainer config --auto-fix-bugs=true    # Re-enable
class ConfigCommand extends Command<void> {
  @override
  final name = 'config';

  @override
  final description = 'View or update Ghost Maintainer configuration.';

  ConfigCommand() {
    argParser.addOption(
      'auto-fix-bugs',
      help: 'Automatically investigate bugs and create PRs (true/false).',
      allowed: ['true', 'false'],
    );
    argParser.addOption(
      'repo',
      help: 'GitHub repo (owner/repo). Auto-detected from git remote if omitted.',
    );
    argParser.addOption(
      'github-token',
      help: 'GitHub PAT for pushing config. Reads from .ghost_maintainer.env if omitted.',
    );
  }

  @override
  Future<void> run() async {
    final config = GhostConfig.load();

    // If no flags provided, just show current config
    if (argResults!['auto-fix-bugs'] == null) {
      print('');
      print('Ghost Maintainer Config (.ghost_maintainer.json):');
      print('');
      print('  auto_fix_bugs: ${config.autoFixBugs}');
      print('');
      print('To change: ghost_maintainer config --auto-fix-bugs=false');
      print('');
      return;
    }

    // Update config
    var changed = false;

    if (argResults!['auto-fix-bugs'] != null) {
      config.autoFixBugs = argResults!['auto-fix-bugs'] == 'true';
      changed = true;
    }

    if (!changed) return;

    // Save locally
    config.save();
    print('');
    print('Config updated:');
    print('  auto_fix_bugs: ${config.autoFixBugs}');

    // Push to repo
    final repo = argResults!['repo'] as String? ?? _detectRepo();
    final token = argResults!['github-token'] as String? ?? _readTokenFromEnv();

    if (repo != null && token != null) {
      print('');
      print('Pushing config to $repo...');
      await _pushConfigToRepo(config, repo, token);
      print('Done.');
    } else {
      print('');
      print('Could not auto-push to repo. Push .ghost_maintainer.json manually,');
      print('or run: ghost_maintainer config --auto-fix-bugs=${config.autoFixBugs} --repo owner/repo --github-token ghp_...');
    }

    print('');
  }

  String? _detectRepo() {
    final result = Process.runSync('git', ['remote', 'get-url', 'origin']);
    if (result.exitCode != 0) return null;
    final url = (result.stdout as String).trim();
    final match = RegExp(r'github\.com[:/]([^/]+/[^/.]+)').firstMatch(url);
    return match?.group(1);
  }

  String? _readTokenFromEnv() {
    final envFile = File('.ghost_maintainer.env');
    if (!envFile.existsSync()) return null;
    for (final line in envFile.readAsLinesSync()) {
      if (line.startsWith('GITHUB_TOKEN=')) {
        return line.substring('GITHUB_TOKEN='.length).trim();
      }
    }
    return null;
  }

  Future<void> _pushConfigToRepo(
      GhostConfig config, String repo, String token) async {
    final client = http.Client();
    final headers = {
      'Authorization': 'token $token',
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
    };

    final content =
        base64Encode(utf8.encode('${JsonEncoder.withIndent('  ').convert(config.toJson())}\n'));

    // Check if file exists
    String? sha;
    final checkResponse = await client.get(
      Uri.parse(
          'https://api.github.com/repos/$repo/contents/${GhostConfig.fileName}'),
      headers: headers,
    );
    if (checkResponse.statusCode == 200) {
      sha = (jsonDecode(checkResponse.body) as Map)['sha'] as String?;
    }

    final body = <String, dynamic>{
      'message': 'chore: update Ghost Maintainer config',
      'content': content,
    };
    if (sha != null) body['sha'] = sha;

    final response = await client.put(
      Uri.parse(
          'https://api.github.com/repos/$repo/contents/${GhostConfig.fileName}'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('  + ${GhostConfig.fileName} pushed to $repo');
    } else {
      print('  ! Failed: ${response.statusCode}');
    }

    client.close();
  }
}
