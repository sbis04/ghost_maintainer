import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey;
  final _client = http.Client();
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const _model = 'gemini-2.5-flash';

  GeminiService({required this.apiKey});

  Future<TriageResult> triageIssue({
    required String issueTitle,
    required String issueBody,
    required String visionStatement,
  }) async {
    final prompt = '''You are a senior open-source maintainer triaging a GitHub issue.

PROJECT VISION:
$visionStatement

ISSUE TITLE: $issueTitle

ISSUE BODY:
$issueBody

Analyze this issue and respond with ONLY a JSON object (no markdown, no code fences):
{
  "priority": "P0-Critical" | "P1-High" | "P2-Medium" | "P3-Low",
  "labels": ["Bug" | "Feature" | "Docs" | "Performance" | "Security" | "Chore"],
  "summary": "One paragraph summary of the issue and recommended action",
  "reasoning": "Your detailed analysis of why you assigned this priority and these labels"
}

Priority guidelines:
- P0-Critical: Security vulnerabilities, data loss, complete feature breakage
- P1-High: Major bugs affecting many users, blocked workflows
- P2-Medium: Minor bugs, UX issues, small feature requests
- P3-Low: Cosmetic issues, nice-to-haves, documentation gaps''';

    final responseText = await _callGemini(prompt);
    final json = _parseJson(responseText);

    return TriageResult(
      priority: json['priority'] as String? ?? 'P2-Medium',
      labels: (json['labels'] as List?)?.cast<String>() ?? ['Bug'],
      summary: json['summary'] as String? ?? 'Unable to generate summary.',
      reasoning:
          json['reasoning'] as String? ?? 'Unable to generate reasoning.',
    );
  }

  Future<InvestigationResult> investigateAndFix({
    required String issueTitle,
    required String issueBody,
    required Map<String, String> relevantFiles,
    required String visionStatement,
  }) async {
    final filesSection = relevantFiles.entries
        .map((e) => '--- ${e.key} ---\n${e.value}')
        .join('\n\n');

    final prompt = '''You are a senior developer investigating a GitHub issue and proposing a fix.

PROJECT VISION:
$visionStatement

ISSUE TITLE: $issueTitle

ISSUE BODY:
$issueBody

RELEVANT SOURCE FILES:
$filesSection

Analyze the issue, identify the root cause, and propose a fix.
Respond with ONLY a JSON object (no markdown, no code fences):
{
  "analysis": "Detailed root cause analysis",
  "affected_files": ["list of file paths that need changes"],
  "proposed_changes": [
    {
      "file": "path/to/file",
      "description": "What this change does",
      "diff": "unified diff format showing the change"
    }
  ],
  "explanation": "Human-readable explanation of the fix",
  "confidence": 85
}

The diff should be in unified diff format that can be applied. Be precise about line numbers and context.
Confidence is 0-100 representing how confident you are the fix is correct.''';

    final responseText = await _callGemini(prompt);
    final json = _parseJson(responseText);

    final changes = (json['proposed_changes'] as List?)
            ?.map((c) => ProposedChange(
                  file: c['file'] as String? ?? '',
                  description: c['description'] as String? ?? '',
                  diff: c['diff'] as String? ?? '',
                ))
            .toList() ??
        [];

    return InvestigationResult(
      analysis: json['analysis'] as String? ?? 'Unable to analyze.',
      affectedFiles:
          (json['affected_files'] as List?)?.cast<String>() ?? [],
      proposedChanges: changes,
      explanation: json['explanation'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toInt() ?? 0,
    );
  }

  Future<String> _callGemini(String prompt) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/models/$_model:generateContent?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 16384,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw GeminiApiException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List;
    final content = candidates.first['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List;
    return parts.first['text'] as String;
  }

  Map<String, dynamic> _parseJson(String text) {
    // Try direct parse first
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {}

    // Try extracting from code fences
    final fenceMatch =
        RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```').firstMatch(text);
    if (fenceMatch != null) {
      try {
        return jsonDecode(fenceMatch.group(1)!) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Try finding first { to last }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end > start) {
      try {
        return jsonDecode(text.substring(start, end + 1))
            as Map<String, dynamic>;
      } catch (_) {}
    }

    throw FormatException('Could not parse Gemini response as JSON: $text');
  }

  void dispose() => _client.close();
}

class TriageResult {
  final String priority;
  final List<String> labels;
  final String summary;
  final String reasoning;

  TriageResult({
    required this.priority,
    required this.labels,
    required this.summary,
    required this.reasoning,
  });
}

class InvestigationResult {
  final String analysis;
  final List<String> affectedFiles;
  final List<ProposedChange> proposedChanges;
  final String explanation;
  final int confidence;

  InvestigationResult({
    required this.analysis,
    required this.affectedFiles,
    required this.proposedChanges,
    required this.explanation,
    required this.confidence,
  });
}

class ProposedChange {
  final String file;
  final String description;
  final String diff;

  ProposedChange({
    required this.file,
    required this.description,
    required this.diff,
  });
}

class GeminiApiException implements Exception {
  final int statusCode;
  final String body;

  GeminiApiException({required this.statusCode, required this.body});

  @override
  String toString() => 'GeminiApiException($statusCode): $body';
}
