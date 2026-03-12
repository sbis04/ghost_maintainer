import 'dart:async';

import 'poller.dart';

/// Orchestrates automated actions based on Notion stage changes.
///
/// For now, this just logs actionable items. In a full implementation,
/// it would invoke the MCP server tools via subprocess or direct API calls.
class Orchestrator {
  final NotionPoller poller;
  StreamSubscription<List<ActionableItem>>? _subscription;
  final _processedIds = <String>{};

  Orchestrator({required this.poller});

  Future<void> start() async {
    _subscription = poller.poll().listen(_handleItems);
    // Keep running
    await Completer<void>().future;
  }

  void _handleItems(List<ActionableItem> items) {
    for (final item in items) {
      if (_processedIds.contains(item.pageId)) continue;
      _processedIds.add(item.pageId);

      switch (item.stage) {
        case 'New':
          print('[ACTION] ${item.title} — needs triage');
          print('  Run: ghost_triage_issue(page_id: "${item.pageId}")');
        case 'Triaged':
          print('[ACTION] ${item.title} — ready for investigation');
          print('  Run: ghost_investigate_issue(page_id: "${item.pageId}")');
        default:
          print('[SKIP] ${item.title} — stage: ${item.stage}');
      }
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    poller.dispose();
  }
}
