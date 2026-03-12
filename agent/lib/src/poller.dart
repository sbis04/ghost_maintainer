import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Polls the Notion Maintenance Backlog for items that need action.
class NotionPoller {
  final String token;
  final String databaseId;
  final Duration pollInterval;
  final _client = http.Client();

  static const _baseUrl = 'https://api.notion.com/v1';
  static const _notionVersion = '2022-06-28';

  NotionPoller({
    required this.token,
    required this.databaseId,
    required this.pollInterval,
  });

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Notion-Version': _notionVersion,
      };

  /// Returns pages that are in actionable stages.
  Stream<List<ActionableItem>> poll() async* {
    while (true) {
      try {
        final items = await _queryActionableItems();
        if (items.isNotEmpty) {
          yield items;
        }
      } catch (e) {
        print('Poll error: $e');
      }
      await Future.delayed(pollInterval);
    }
  }

  Future<List<ActionableItem>> _queryActionableItems() async {
    // Query for items in stages that need automated action
    final response = await _client.post(
      Uri.parse('$_baseUrl/databases/$databaseId/query'),
      headers: _headers,
      body: jsonEncode({
        'filter': {
          'or': [
            {
              'property': 'Stage',
              'select': {'equals': 'New'},
            },
            {
              'property': 'Stage',
              'select': {'equals': 'Triaged'},
            },
          ],
        },
        'sorts': [
          {'property': 'Created', 'direction': 'ascending'},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Notion query failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List).cast<Map<String, dynamic>>();

    return results.map((page) {
      final titleParts =
          page['properties']?['Title']?['title'] as List? ?? [];
      final title = titleParts.map((t) => t['plain_text'] ?? '').join();
      final stage =
          page['properties']?['Stage']?['select']?['name'] as String? ??
              'Unknown';

      return ActionableItem(
        pageId: page['id'] as String,
        title: title,
        stage: stage,
      );
    }).toList();
  }

  void dispose() => _client.close();
}

class ActionableItem {
  final String pageId;
  final String title;
  final String stage;

  ActionableItem({
    required this.pageId,
    required this.title,
    required this.stage,
  });

  @override
  String toString() => 'ActionableItem($title, stage: $stage)';
}
