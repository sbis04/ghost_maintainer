import 'package:dart_mcp/server.dart';

import '../server.dart';
import '../services/notion_service.dart';

void registerGetBacklogTool(GhostMaintainerServer server) {
  final tool = Tool(
    name: 'ghost_get_backlog',
    description:
        'Query the Notion Maintenance Backlog. Optionally filter by stage.',
    inputSchema: ObjectSchema(
      properties: {
        'stage_filter': Schema.string(
          description:
              'Filter by stage: New, Triaged, Investigating, Review, Deploy, Archived',
        ),
      },
    ),
  );

  server.registerTool(tool, (CallToolRequest request) async {
    final args = request.arguments ?? {};
    final stageFilter = args['stage_filter'] as String?;

    final pages = await server.notion.queryBacklog(filterByStage: stageFilter);

    if (pages.isEmpty) {
      final filterMsg =
          stageFilter != null ? ' with stage "$stageFilter"' : '';
      return CallToolResult(
        content: [TextContent(text: 'No backlog items found$filterMsg.')],
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('# Maintenance Backlog');
    if (stageFilter != null) buffer.writeln('Filter: $stageFilter');
    buffer.writeln('Total: ${pages.length} items\n');

    for (final page in pages) {
      final title = NotionPageHelper.getTitle(page);
      final stage = NotionPageHelper.getSelect(page, 'Stage') ?? 'Unknown';
      final priority =
          NotionPageHelper.getSelect(page, 'Priority') ?? 'Unset';
      final labels = NotionPageHelper.getMultiSelect(page, 'Labels');
      final issueUrl = NotionPageHelper.getUrl(page, 'GitHub Issue');
      final prUrl = NotionPageHelper.getUrl(page, 'PR URL');
      final pageId = page['id'] as String;

      buffer.writeln('## $title');
      buffer.writeln('- **Page ID:** $pageId');
      buffer.writeln('- **Stage:** $stage');
      buffer.writeln('- **Priority:** $priority');
      if (labels.isNotEmpty) buffer.writeln('- **Labels:** ${labels.join(', ')}');
      if (issueUrl != null) buffer.writeln('- **Issue:** $issueUrl');
      if (prUrl != null) buffer.writeln('- **PR:** $prUrl');
      buffer.writeln();
    }

    return CallToolResult(
      content: [TextContent(text: buffer.toString())],
    );
  });
}
