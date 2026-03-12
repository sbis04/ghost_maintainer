import 'dart:io';

import '../lib/notion_client.dart';

/// Creates a sample Vision Statement page in Notion.
///
/// Usage:
///   NOTION_TOKEN=ntn_... PARENT_PAGE_ID=... dart run bin/seed_vision.dart
void main() async {
  final token = Platform.environment['NOTION_TOKEN'];
  final parentPageId = Platform.environment['PARENT_PAGE_ID'];

  if (token == null || parentPageId == null) {
    stderr.writeln('Required env vars: NOTION_TOKEN, PARENT_PAGE_ID');
    exit(1);
  }

  final client = NotionClient(token: token);

  print('Creating Vision Statement page...');

  final page = await client.createPage(
    parentPageId: parentPageId,
    title: 'Project Vision Statement',
    children: [
      _heading2('Mission'),
      _paragraph(
        'Build a reliable, well-documented open-source tool that developers love to use. '
        'Prioritize stability and developer experience over feature count.',
      ),
      _heading2('Principles'),
      ..._bulletedList([
        'Keep the API surface small and intuitive',
        'Every feature should have comprehensive tests',
        'Performance matters — avoid unnecessary allocations',
        'Security is non-negotiable — validate all inputs',
        'Documentation is a feature, not an afterthought',
      ]),
      _heading2('Current Focus'),
      _paragraph(
        'The current release cycle focuses on stability and bug fixes. '
        'New features are deprioritized until the existing test suite reaches 90% coverage. '
        'Security issues are always P0.',
      ),
      _heading2('Non-Goals'),
      ..._bulletedList([
        'Supporting every edge case — focus on the 80% use case',
        'Backward compatibility at all costs — deprecate cleanly',
        'Competing with larger frameworks — stay focused and lean',
      ]),
    ],
  );

  final pageId = page['id'];
  print('Vision Statement page created!');
  print('Page ID: $pageId');
  print('\nAdd this to your .env file:');
  print('NOTION_VISION_PAGE_ID=$pageId');

  client.dispose();
}

Map<String, dynamic> _heading2(String text) => {
      'object': 'block',
      'type': 'heading_2',
      'heading_2': {
        'rich_text': [
          {
            'type': 'text',
            'text': {'content': text}
          }
        ]
      },
    };

Map<String, dynamic> _paragraph(String text) => {
      'object': 'block',
      'type': 'paragraph',
      'paragraph': {
        'rich_text': [
          {
            'type': 'text',
            'text': {'content': text}
          }
        ]
      },
    };

List<Map<String, dynamic>> _bulletedList(List<String> items) => [
      for (final item in items)
        {
          'object': 'block',
          'type': 'bulleted_list_item',
          'bulleted_list_item': {
            'rich_text': [
              {
                'type': 'text',
                'text': {'content': item}
              }
            ]
          },
        },
    ];
