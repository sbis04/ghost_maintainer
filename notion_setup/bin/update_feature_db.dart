import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Adds the "Implement" stage option to Feature Backlog.
void main() async {
  final token = Platform.environment['NOTION_TOKEN']!;
  final dbId = Platform.environment['NOTION_FEATURE_DB_ID']!;

  final client = http.Client();
  final response = await client.patch(
    Uri.parse('https://api.notion.com/v1/databases/$dbId'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Notion-Version': '2022-06-28',
    },
    body: jsonEncode({
      'properties': {
        'Stage': {
          'select': {
            'options': [
              {'name': 'Implement', 'color': 'purple'},
            ]
          }
        },
      },
    }),
  );

  if (response.statusCode == 200) {
    print('Added "Implement" stage to Feature Backlog.');
  } else {
    stderr.writeln('Error: ${response.statusCode} ${response.body}');
  }
  client.close();
}
