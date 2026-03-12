import 'dart:io';

import '../lib/notion_client.dart';

/// Creates the Maintenance Backlog database in Notion.
///
/// Usage:
///   NOTION_TOKEN=ntn_... PARENT_PAGE_ID=... dart run bin/setup_database.dart
void main() async {
  final token = Platform.environment['NOTION_TOKEN'];
  final parentPageId = Platform.environment['PARENT_PAGE_ID'];

  if (token == null || parentPageId == null) {
    stderr.writeln('Required env vars: NOTION_TOKEN, PARENT_PAGE_ID');
    exit(1);
  }

  final client = NotionClient(token: token);

  print('Creating Maintenance Backlog database...');

  final db = await client.createDatabase(
    parentPageId: parentPageId,
    title: 'Maintenance Backlog',
    properties: {
      // Title is always included by default
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
    },
  );

  final dbId = db['id'];
  print('Database created successfully!');
  print('Database ID: $dbId');
  print('\nAdd this to your .env file:');
  print('NOTION_DATABASE_ID=$dbId');

  client.dispose();
}
