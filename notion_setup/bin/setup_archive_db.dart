import 'dart:io';

import '../lib/notion_client.dart';

void main() async {
  final token = Platform.environment['NOTION_TOKEN']!;
  final parentPageId = Platform.environment['PARENT_PAGE_ID']!;

  final client = NotionClient(token: token);

  print('Creating Archive database...');
  final db = await client.createDatabase(
    parentPageId: parentPageId,
    title: 'Archive',
    properties: {
      'Title': {'title': {}},
      'Type': {
        'select': {
          'options': [
            {'name': 'Bug', 'color': 'red'},
            {'name': 'Feature', 'color': 'blue'},
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
      'Resolved Date': {'date': {}},
    },
  );

  print('Archive DB ID: ${db["id"]}');
  print('NOTION_ARCHIVE_DB_ID=${db["id"]}');
  client.dispose();
}
