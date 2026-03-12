import 'package:dart_mcp/server.dart';

import '../server.dart';
import '../services/notion_service.dart';

void registerInvestigateIssueTool(GhostMaintainerServer server) {
  final tool = Tool(
    name: 'ghost_investigate_issue',
    description:
        'Deep investigation of a GitHub issue. Reads the codebase via GitHub API, '
        'analyzes the issue using Claude, proposes a fix with a diff, and updates Notion.',
    inputSchema: ObjectSchema(
      properties: {
        'page_id': Schema.string(
          description: 'The Notion page ID of the backlog item to investigate',
        ),
        'file_hints': Schema.list(
          description:
              'Optional list of file paths to focus investigation on. '
              'If empty, the tool will use the repo tree to find relevant files.',
          items: Schema.string(),
        ),
      },
      required: ['page_id'],
    ),
  );

  server.registerTool(tool, (CallToolRequest request) async {
    final pageId = request.arguments!['page_id'] as String;
    final fileHints =
        (request.arguments!['file_hints'] as List?)?.cast<String>() ?? [];

    // 1. Read the issue from Notion
    final page = await server.notion.getPage(pageId);
    final title = NotionPageHelper.getTitle(page);
    final issueNumber = NotionPageHelper.getNumber(page, 'Issue Number');

    // 2. Get the issue body from page blocks
    final blocks = await server.notion.getPageBlocks(pageId);
    final issueBody = _extractTextFromBlocks(blocks);

    // 3. Get vision statement
    final vision =
        await server.notion.getVisionStatement(server.config.notionVisionPageId);

    // 4. Get relevant source files from GitHub
    final owner = server.config.repoOwner;
    final repo = server.config.repoName;

    Map<String, String> relevantFiles;
    if (fileHints.isNotEmpty) {
      relevantFiles = await _fetchFiles(server, owner, repo, fileHints);
    } else {
      relevantFiles = await _findAndFetchRelevantFiles(
        server,
        owner,
        repo,
        title,
        issueBody,
      );
    }

    if (relevantFiles.isEmpty) {
      return CallToolResult(
        content: [
          TextContent(
            text: 'Could not find relevant source files in the repository. '
                'Try providing file_hints to narrow the investigation.',
          ),
        ],
        isError: true,
      );
    }

    // 5. Update stage to Investigating
    await server.notion.updatePageProperties(pageId, stage: 'Investigating');

    // 6. Call Claude to investigate and propose fix
    final result = await server.gemini.investigateAndFix(
      issueTitle: title,
      issueBody: issueBody,
      relevantFiles: relevantFiles,
      visionStatement: vision,
    );

    // 7. Build the proposed diff string
    final diffBuffer = StringBuffer();
    for (final change in result.proposedChanges) {
      diffBuffer.writeln('--- ${change.file}');
      diffBuffer.writeln('+++ ${change.file}');
      diffBuffer.writeln(change.diff);
      diffBuffer.writeln();
    }
    final proposedDiff = diffBuffer.toString().trim();

    // 8. Update Notion with investigation results
    await server.notion.updatePageProperties(
      pageId,
      stage: 'Review',
      aiSummary: result.explanation,
      aiConfidence: result.confidence,
    );

    await server.notion.appendPageContent(
      pageId,
      NotionService.buildInvestigationBlocks(
        analysis: result.analysis,
        proposedDiff: proposedDiff,
      ),
    );

    return CallToolResult(
      content: [
        TextContent(
          text: '''Investigation complete for issue #$issueNumber: "$title"

**Confidence:** ${result.confidence}%
**Affected files:** ${result.affectedFiles.join(', ')}

**Analysis:**
${result.analysis}

**Explanation:**
${result.explanation}

**Proposed changes:** ${result.proposedChanges.length} file(s)
${result.proposedChanges.map((c) => '- ${c.file}: ${c.description}').join('\n')}

The Notion page has been updated with the full investigation report and proposed diff. Stage set to "Review".''',
        ),
      ],
    );
  });
}

Future<Map<String, String>> _fetchFiles(
  GhostMaintainerServer server,
  String owner,
  String repo,
  List<String> paths,
) async {
  final files = <String, String>{};
  for (final path in paths) {
    try {
      final content = await server.github.getFileContent(owner, repo, path);
      files[path] = content;
    } catch (_) {
      // Skip files that can't be fetched
    }
  }
  return files;
}

Future<Map<String, String>> _findAndFetchRelevantFiles(
  GhostMaintainerServer server,
  String owner,
  String repo,
  String issueTitle,
  String issueBody,
) async {
  // Get repo tree and find source files
  final tree = await server.github.getRepoTree(owner, repo);

  final sourceFiles = tree
      .where((item) => item['type'] == 'blob')
      .map((item) => item['path'] as String)
      .where((path) => _isSourceFile(path))
      .toList();

  // Simple relevance: match keywords from issue title against file paths
  final keywords = _extractKeywords('$issueTitle $issueBody');
  final scored = <String, int>{};
  for (final path in sourceFiles) {
    final pathLower = path.toLowerCase();
    var score = 0;
    for (final kw in keywords) {
      if (pathLower.contains(kw.toLowerCase())) score += 2;
    }
    // Boost lib/ and src/ files
    if (pathLower.contains('lib/') || pathLower.contains('src/')) score += 1;
    if (score > 0) scored[path] = score;
  }

  // Sort by score, take top 10
  final sortedPaths = scored.keys.toList()
    ..sort((a, b) => scored[b]!.compareTo(scored[a]!));
  final topPaths = sortedPaths.take(10).toList();

  // If no matches, take first few source files
  if (topPaths.isEmpty) {
    topPaths.addAll(sourceFiles.take(5));
  }

  return _fetchFiles(server, owner, repo, topPaths);
}

bool _isSourceFile(String path) {
  const extensions = [
    '.dart',
    '.py',
    '.js',
    '.ts',
    '.java',
    '.kt',
    '.go',
    '.rs',
    '.rb',
    '.swift',
    '.c',
    '.cpp',
    '.h',
    '.yaml',
    '.yml',
    '.json',
    '.toml',
  ];
  return extensions.any(path.endsWith);
}

List<String> _extractKeywords(String text) {
  final stopWords = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'can', 'shall', 'to', 'of', 'in', 'for',
    'on', 'with', 'at', 'by', 'from', 'as', 'into', 'through', 'during',
    'before', 'after', 'above', 'below', 'between', 'and', 'but', 'or',
    'not', 'no', 'nor', 'so', 'yet', 'both', 'either', 'neither', 'this',
    'that', 'these', 'those', 'it', 'its', 'i', 'we', 'they', 'them',
    'when', 'where', 'how', 'what', 'which', 'who', 'whom',
  };

  return text
      .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2 && !stopWords.contains(w.toLowerCase()))
      .toList();
}

String _extractTextFromBlocks(List<Map<String, dynamic>> blocks) {
  final buffer = StringBuffer();
  for (final block in blocks) {
    final type = block['type'] as String;
    final blockData = block[type] as Map<String, dynamic>?;
    if (blockData == null) continue;
    final richTexts = blockData['rich_text'] as List? ?? [];
    for (final rt in richTexts) {
      buffer.write(rt['plain_text'] ?? '');
    }
    buffer.writeln();
  }
  return buffer.toString().trim();
}
