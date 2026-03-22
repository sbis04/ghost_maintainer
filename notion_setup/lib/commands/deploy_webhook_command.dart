import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

import '../notion_client.dart';

/// `ghost_maintainer deploy-webhook` — deploy the Cloudflare Worker and
/// add one-click buttons to Notion databases.
class DeployWebhookCommand extends Command<void> {
  @override
  final name = 'deploy-webhook';

  @override
  final description =
      'Deploy the Cloudflare Worker webhook and add Fix/Implement buttons to Notion.';

  DeployWebhookCommand() {
    argParser
      ..addOption('cf-account-id', help: 'Cloudflare Account ID')
      ..addOption('cf-api-token', help: 'Cloudflare API token (Workers permission)')
      ..addOption('github-token',
          help: 'GitHub PAT. Reads from .ghost_maintainer.env if omitted.')
      ..addOption('notion-token',
          help: 'Notion token. Reads from .ghost_maintainer.env if omitted.')
      ..addOption('repo',
          help: 'Target repo. Reads from .ghost_maintainer.env if omitted.')
      ..addOption('maintenance-db-id',
          help: 'Maintenance Backlog DB ID. Reads from env if omitted.')
      ..addOption('feature-db-id',
          help: 'Feature Backlog DB ID. Reads from env if omitted.')
      ..addOption('worker-name',
          help: 'Cloudflare Worker name', defaultsTo: 'ghost-maintainer')
      ..addOption('source-repo',
          help: 'Ghost Maintainer source repo',
          defaultsTo: 'sbis04/ghost-maintainer');
  }

  @override
  Future<void> run() async {
    final env = _readEnv();

    final cfAccountId = argResults!['cf-account-id'] as String?;
    final cfApiToken = argResults!['cf-api-token'] as String?;
    final githubToken =
        argResults!['github-token'] as String? ?? env['GITHUB_TOKEN'];
    final notionToken =
        argResults!['notion-token'] as String? ?? env['NOTION_TOKEN'];
    final targetRepo =
        argResults!['repo'] as String? ?? env['TARGET_REPO'] ?? _detectRepo();
    final maintenanceDbId =
        argResults!['maintenance-db-id'] as String? ?? env['NOTION_DATABASE_ID'];
    final featureDbId =
        argResults!['feature-db-id'] as String? ?? env['NOTION_FEATURE_DB_ID'];
    final workerName = argResults!['worker-name'] as String;
    final sourceRepo = argResults!['source-repo'] as String;

    if (cfAccountId == null || cfApiToken == null) {
      print('''
Deploy the Ghost Maintainer webhook to Cloudflare Workers.

Usage:
  ghost_maintainer deploy-webhook \\
    --cf-account-id YOUR_ACCOUNT_ID \\
    --cf-api-token YOUR_API_TOKEN

Where to find these:
  Account ID: https://dash.cloudflare.com → pick your account → copy from the URL or sidebar
  API Token:  https://dash.cloudflare.com/profile/api-tokens → Create Token
              Use the "Edit Cloudflare Workers" template

Other values are read from .ghost_maintainer.env (created by setup).
''');
      exit(1);
    }

    if (githubToken == null || targetRepo == null) {
      stderr.writeln('Missing GITHUB_TOKEN or TARGET_REPO. Run setup first.');
      exit(1);
    }

    final httpClient = http.Client();
    final cfHeaders = {
      'Authorization': 'Bearer $cfApiToken',
      'Content-Type': 'application/javascript',
    };

    print('');
    print('=== Deploying Ghost Maintainer Webhook ===');
    print('');

    // 1. Get the workers subdomain
    print('[1/5] Getting Cloudflare subdomain...');
    final subdomainResponse = await httpClient.get(
      Uri.parse(
          'https://api.cloudflare.com/client/v4/accounts/$cfAccountId/workers/subdomain'),
      headers: {
        'Authorization': 'Bearer $cfApiToken',
        'Content-Type': 'application/json',
      },
    );

    String subdomain;
    if (subdomainResponse.statusCode == 200) {
      final data = jsonDecode(subdomainResponse.body) as Map<String, dynamic>;
      subdomain = data['result']?['subdomain'] as String? ?? '';
      if (subdomain.isEmpty) {
        stderr.writeln('No workers subdomain configured. Set one at:');
        stderr.writeln('  dash.cloudflare.com > Workers & Pages > Your subdomain');
        exit(1);
      }
      print('  Subdomain: $subdomain.workers.dev');
    } else {
      stderr.writeln(
          'Failed to get subdomain: ${subdomainResponse.statusCode} ${subdomainResponse.body}');
      exit(1);
    }

    // 2. Download and deploy the worker script
    print('[2/5] Deploying worker script...');

    // Try local first, then download
    String workerScript;
    final localFile = File('../webhook/worker.js');
    if (localFile.existsSync()) {
      workerScript = localFile.readAsStringSync();
    } else {
      final dlResponse = await httpClient.get(Uri.parse(
          'https://raw.githubusercontent.com/$sourceRepo/main/webhook/worker.js'));
      if (dlResponse.statusCode != 200) {
        stderr.writeln('Failed to download worker.js');
        exit(1);
      }
      workerScript = dlResponse.body;
    }

    final deployResponse = await httpClient.put(
      Uri.parse(
          'https://api.cloudflare.com/client/v4/accounts/$cfAccountId/workers/scripts/$workerName'),
      headers: cfHeaders,
      body: workerScript,
    );

    if (deployResponse.statusCode != 200) {
      stderr.writeln(
          'Failed to deploy worker: ${deployResponse.statusCode} ${deployResponse.body}');
      exit(1);
    }
    print('  + Worker deployed');

    // 3. Set worker secrets
    print('[3/5] Setting worker secrets...');

    // Generate a random webhook secret
    final webhookSecret = _generateSecret();

    final workerSecrets = {
      'GITHUB_TOKEN': githubToken,
      'TARGET_REPO': targetRepo,
      'WEBHOOK_SECRET': webhookSecret,
    };

    final secretHeaders = {
      'Authorization': 'Bearer $cfApiToken',
      'Content-Type': 'application/json',
    };

    for (final entry in workerSecrets.entries) {
      final secretResponse = await httpClient.put(
        Uri.parse(
            'https://api.cloudflare.com/client/v4/accounts/$cfAccountId/workers/scripts/$workerName/secrets'),
        headers: secretHeaders,
        body: jsonEncode({
          'name': entry.key,
          'text': entry.value,
          'type': 'secret_text',
        }),
      );

      if (secretResponse.statusCode == 200) {
        print('  + ${entry.key}');
      } else {
        print('  ! ${entry.key}: ${secretResponse.statusCode}');
      }
    }

    final workerUrl = 'https://$workerName.$subdomain.workers.dev';

    // 4. Enable the worker route (workers.dev)
    print('[4/5] Enabling workers.dev route...');
    final enableResponse = await httpClient.post(
      Uri.parse(
          'https://api.cloudflare.com/client/v4/accounts/$cfAccountId/workers/scripts/$workerName/subdomain'),
      headers: secretHeaders,
      body: jsonEncode({'enabled': true}),
    );

    if (enableResponse.statusCode == 200) {
      print('  + $workerUrl');
    } else {
      print('  ! Could not enable route: ${enableResponse.statusCode}');
      print('    Enable manually: Workers & Pages > $workerName > Settings > Triggers > workers.dev');
    }

    // 5. Add formulas to Notion databases
    print('[5/5] Adding one-click buttons to Notion...');

    if (notionToken != null && maintenanceDbId != null && featureDbId != null) {
      final notionClient = NotionClient(token: notionToken);

      final fixFormula =
          '"$workerUrl?issue=" + format(prop("Issue Number")) + "&type=bug&secret=$webhookSecret"';
      final implementFormula =
          '"$workerUrl?issue=" + format(prop("Issue Number")) + "&type=feature&secret=$webhookSecret"';

      await notionClient.updateDatabase(maintenanceDbId, properties: {
        'Fix': {
          'formula': {'expression': 'link("Fix", $fixFormula)'}
        },
      });
      print('  + Maintenance Backlog: "Fix" button');

      await notionClient.updateDatabase(featureDbId, properties: {
        'Implement': {
          'formula': {'expression': 'link("Implement", $implementFormula)'}
        },
      });
      print('  + Feature Backlog: "Implement" button');

      notionClient.dispose();
    } else {
      print('  ! Missing Notion credentials, skipping formula creation.');
      print('    Add formulas manually (see webhook/README.md).');
    }

    print('');
    print('=== Webhook deployed! ===');
    print('');
    print('Worker URL: $workerUrl');
    print('Webhook secret: $webhookSecret');
    print('');
    print('The "Fix" and "Implement" buttons are now live in Notion.');
    print('');

    httpClient.close();
  }

  String _generateSecret() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return 'ghost-${List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join()}';
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
