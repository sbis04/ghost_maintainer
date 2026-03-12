import 'dart:convert';

import 'package:http/http.dart' as http;

class NotionService {
  final String token;
  final String databaseId;
  final _client = http.Client();
  static const _baseUrl = 'https://api.notion.com/v1';
  static const _notionVersion = '2022-06-28';

  NotionService({required this.token, required this.databaseId});

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Notion-Version': _notionVersion,
      };

  Future<Map<String, dynamic>> createBacklogEntry({
    required String title,
    required String body,
    required String githubUrl,
    required int issueNumber,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/pages'),
      headers: _headers,
      body: jsonEncode({
        'parent': {'database_id': databaseId},
        'properties': {
          'Title': {
            'title': [
              {
                'text': {'content': title}
              }
            ]
          },
          'Stage': {'select': {'name': 'New'}},
          'GitHub Issue': {'url': githubUrl},
          'Issue Number': {'number': issueNumber},
        },
        'children': _buildOriginalIssueBlocks(body),
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updatePageProperties(
    String pageId, {
    String? stage,
    String? priority,
    List<String>? labels,
    String? prUrl,
    String? aiSummary,
    int? aiConfidence,
  }) async {
    final properties = <String, dynamic>{};

    if (stage != null) {
      properties['Stage'] = {
        'select': {'name': stage}
      };
    }
    if (priority != null) {
      properties['Priority'] = {
        'select': {'name': priority}
      };
    }
    if (labels != null) {
      properties['Labels'] = {
        'multi_select': labels.map((l) => {'name': l}).toList(),
      };
    }
    if (prUrl != null) {
      properties['PR URL'] = {'url': prUrl};
    }
    if (aiSummary != null) {
      properties['AI Summary'] = {
        'rich_text': [
          {
            'text': {'content': _truncate(aiSummary, 2000)}
          }
        ]
      };
    }
    if (aiConfidence != null) {
      properties['AI Confidence'] = {'number': aiConfidence};
    }

    final response = await _client.patch(
      Uri.parse('$_baseUrl/pages/$pageId'),
      headers: _headers,
      body: jsonEncode({'properties': properties}),
    );
    return _handleResponse(response);
  }

  Future<List<Map<String, dynamic>>> queryBacklog({
    String? filterByStage,
  }) async {
    final filter = filterByStage != null
        ? {
            'filter': {
              'property': 'Stage',
              'select': {'equals': filterByStage},
            }
          }
        : <String, dynamic>{};

    final sorts = {
      'sorts': [
        {'timestamp': 'created_time', 'direction': 'descending'}
      ]
    };

    final response = await _client.post(
      Uri.parse('$_baseUrl/databases/$databaseId/query'),
      headers: _headers,
      body: jsonEncode({...filter, ...sorts}),
    );
    final data = _handleResponse(response);
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getPage(String pageId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/pages/$pageId'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  Future<void> appendPageContent(
    String pageId,
    List<Map<String, dynamic>> blocks,
  ) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/blocks/$pageId/children'),
      headers: _headers,
      body: jsonEncode({'children': blocks}),
    );
    _handleResponse(response);
  }

  Future<void> archivePage(String pageId) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/pages/$pageId'),
      headers: _headers,
      body: jsonEncode({'archived': true}),
    );
    _handleResponse(response);
  }

  Future<String> getVisionStatement(String visionPageId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/blocks/$visionPageId/children?page_size=100'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    final results = data['results'] as List;

    final buffer = StringBuffer();
    for (final block in results) {
      final type = block['type'] as String;
      final blockData = block[type] as Map<String, dynamic>?;
      if (blockData == null) continue;

      final richTexts = blockData['rich_text'] as List?;
      if (richTexts == null) continue;

      for (final rt in richTexts) {
        buffer.write(rt['plain_text'] ?? '');
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  Future<List<Map<String, dynamic>>> getPageBlocks(String pageId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/blocks/$pageId/children?page_size=100'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }

  // --- Notion Block Builders ---

  static List<Map<String, dynamic>> _buildOriginalIssueBlocks(String body) {
    return [
      _heading2('Original Issue'),
      ..._splitTextToBlocks(body),
      _divider(),
    ];
  }

  static List<Map<String, dynamic>> buildTriageBlocks(String analysis) {
    return [
      _heading2('Triage Analysis'),
      ..._splitTextToBlocks(analysis),
      _divider(),
    ];
  }

  static List<Map<String, dynamic>> buildInvestigationBlocks({
    required String analysis,
    required String proposedDiff,
  }) {
    return [
      _heading2('Investigation Report'),
      ..._splitTextToBlocks(analysis),
      _heading2('Proposed Fix'),
      _codeBlock(proposedDiff),
      _divider(),
    ];
  }

  static List<Map<String, dynamic>> buildDeploymentBlocks({
    required String prUrl,
    required String branchName,
  }) {
    return [
      _heading2('Deployment'),
      _paragraph('PR: $prUrl'),
      _paragraph('Branch: $branchName'),
    ];
  }

  static Map<String, dynamic> _heading2(String text) => {
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

  static Map<String, dynamic> _paragraph(String text) => {
        'object': 'block',
        'type': 'paragraph',
        'paragraph': {
          'rich_text': [
            {
              'type': 'text',
              'text': {'content': _truncate(text, 2000)}
            }
          ]
        },
      };

  static Map<String, dynamic> _codeBlock(String code) => {
        'object': 'block',
        'type': 'code',
        'code': {
          'rich_text': [
            {
              'type': 'text',
              'text': {'content': _truncate(code, 2000)}
            }
          ],
          'language': 'diff',
        },
      };

  static Map<String, dynamic> _divider() => {
        'object': 'block',
        'type': 'divider',
        'divider': {},
      };

  static List<Map<String, dynamic>> _splitTextToBlocks(String text) {
    if (text.isEmpty) return [_paragraph('(empty)')];
    final chunks = <String>[];
    var remaining = text;
    while (remaining.isNotEmpty) {
      chunks.add(remaining.substring(0, remaining.length.clamp(0, 2000)));
      remaining = remaining.length > 2000
          ? remaining.substring(2000)
          : '';
    }
    return chunks.map(_paragraph).toList();
  }

  static String _truncate(String s, int maxLen) {
    return s.length <= maxLen ? s : '${s.substring(0, maxLen - 3)}...';
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw NotionApiException(
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  void dispose() => _client.close();
}

class NotionApiException implements Exception {
  final int statusCode;
  final String body;

  NotionApiException({required this.statusCode, required this.body});

  @override
  String toString() => 'NotionApiException($statusCode): $body';
}

// --- Helper to extract properties from Notion pages ---

class NotionPageHelper {
  static String getTitle(Map<String, dynamic> page) {
    final titleProp = page['properties']?['Title']?['title'] as List?;
    if (titleProp == null || titleProp.isEmpty) return '';
    return titleProp.map((t) => t['plain_text'] ?? '').join();
  }

  static String? getSelect(Map<String, dynamic> page, String property) {
    return page['properties']?[property]?['select']?['name'] as String?;
  }

  static List<String> getMultiSelect(
      Map<String, dynamic> page, String property) {
    final items =
        page['properties']?[property]?['multi_select'] as List? ?? [];
    return items.map((i) => i['name'] as String).toList();
  }

  static String? getUrl(Map<String, dynamic> page, String property) {
    return page['properties']?[property]?['url'] as String?;
  }

  static int? getNumber(Map<String, dynamic> page, String property) {
    final val = page['properties']?[property]?['number'];
    return val is int ? val : val?.toInt();
  }

  static String getRichText(Map<String, dynamic> page, String property) {
    final texts = page['properties']?[property]?['rich_text'] as List? ?? [];
    return texts.map((t) => t['plain_text'] ?? '').join();
  }
}
