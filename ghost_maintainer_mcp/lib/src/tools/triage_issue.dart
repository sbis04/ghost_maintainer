import 'package:dart_mcp/server.dart';

import '../server.dart';
import '../services/notion_service.dart';

void registerTriageIssueTool(GhostMaintainerServer server) {
  final tool = Tool(
    name: 'ghost_triage_issue',
    description:
        'AI-powered triage of a GitHub issue. Reads the issue from Notion, '
        'assigns priority and labels using Claude, and updates the Notion page.',
    inputSchema: ObjectSchema(
      properties: {
        'page_id': Schema.string(
          description: 'The Notion page ID of the backlog item to triage',
        ),
      },
      required: ['page_id'],
    ),
  );

  server.registerTool(tool, (CallToolRequest request) async {
    final pageId = request.arguments!['page_id'] as String;

    // 1. Read the issue from Notion
    final page = await server.notion.getPage(pageId);
    final title = NotionPageHelper.getTitle(page);
    final issueNumber = NotionPageHelper.getNumber(page, 'Issue Number');

    // 2. Get the issue body from page blocks
    final blocks = await server.notion.getPageBlocks(pageId);
    final issueBody = _extractIssueBody(blocks);

    // 3. Get vision statement for context
    final vision =
        await server.notion.getVisionStatement(server.config.notionVisionPageId);

    // 4. Call Claude for triage
    final result = await server.anthropic.triageIssue(
      issueTitle: title,
      issueBody: issueBody,
      visionStatement: vision,
    );

    // 5. Update Notion page with triage results
    await server.notion.updatePageProperties(
      pageId,
      stage: 'Triaged',
      priority: result.priority,
      labels: result.labels,
      aiSummary: result.summary,
    );

    // 6. Append triage analysis to page
    await server.notion.appendPageContent(
      pageId,
      NotionService.buildTriageBlocks(result.reasoning),
    );

    return CallToolResult(
      content: [
        TextContent(
          text: '''Triage complete for issue #$issueNumber: "$title"

**Priority:** ${result.priority}
**Labels:** ${result.labels.join(', ')}
**Summary:** ${result.summary}

The Notion page has been updated with the triage analysis. Stage set to "Triaged".''',
        ),
      ],
    );
  });
}

String _extractIssueBody(List<Map<String, dynamic>> blocks) {
  final buffer = StringBuffer();
  var inOriginalIssue = false;

  for (final block in blocks) {
    final type = block['type'] as String;

    // Check for "Original Issue" heading
    if (type == 'heading_2') {
      final texts = block['heading_2']?['rich_text'] as List? ?? [];
      final headingText = texts.map((t) => t['plain_text'] ?? '').join();
      if (headingText == 'Original Issue') {
        inOriginalIssue = true;
        continue;
      } else if (inOriginalIssue) {
        break; // Stop at next heading
      }
    }

    if (!inOriginalIssue) continue;
    if (type == 'divider') break;

    // Extract text from paragraph blocks
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
