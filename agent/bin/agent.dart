import 'dart:async';
import 'dart:io';

import '../lib/src/poller.dart';
import '../lib/src/orchestrator.dart';

/// Ghost Maintainer Agent — polls Notion for stage changes and orchestrates
/// the MCP server tools automatically.
///
/// Usage:
///   NOTION_TOKEN=ntn_... NOTION_DATABASE_ID=... dart run bin/agent.dart
void main() async {
  final token = Platform.environment['NOTION_TOKEN'];
  final databaseId = Platform.environment['NOTION_DATABASE_ID'];

  if (token == null || databaseId == null) {
    stderr.writeln('Required env vars: NOTION_TOKEN, NOTION_DATABASE_ID');
    exit(1);
  }

  final pollInterval = Duration(
    seconds: int.tryParse(
          Platform.environment['POLL_INTERVAL_SECONDS'] ?? '30',
        ) ??
        30,
  );

  final poller = NotionPoller(
    token: token,
    databaseId: databaseId,
    pollInterval: pollInterval,
  );

  final orchestrator = Orchestrator(poller: poller);

  print('Ghost Maintainer Agent started.');
  print('Polling every ${pollInterval.inSeconds}s...');
  print('Press Ctrl+C to stop.\n');

  // Handle graceful shutdown
  late StreamSubscription<ProcessSignal> sigint;
  sigint = ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');
    await orchestrator.stop();
    await sigint.cancel();
    exit(0);
  });

  await orchestrator.start();
}
