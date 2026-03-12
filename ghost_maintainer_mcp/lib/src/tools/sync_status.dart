import 'package:dart_mcp/server.dart';

import '../server.dart';
import '../services/notion_service.dart';

void registerSyncStatusTool(GhostMaintainerServer server) {
  final tool = Tool(
    name: 'ghost_sync_status',
    description:
        'Manually update the stage of a backlog item in Notion.',
    inputSchema: ObjectSchema(
      properties: {
        'page_id': Schema.string(
          description: 'The Notion page ID to update',
        ),
        'new_stage': Schema.string(
          description:
              'The new stage: New, Triaged, Investigating, Review, Deploy, Archived',
        ),
      },
      required: ['page_id', 'new_stage'],
    ),
  );

  server.registerTool(tool, (CallToolRequest request) async {
    final pageId = request.arguments!['page_id'] as String;
    final newStage = request.arguments!['new_stage'] as String;

    const validStages = [
      'New',
      'Triaged',
      'Investigating',
      'Review',
      'Deploy',
      'Archived',
    ];

    if (!validStages.contains(newStage)) {
      return CallToolResult(
        content: [
          TextContent(
            text: 'Invalid stage "$newStage". Valid stages: ${validStages.join(', ')}',
          ),
        ],
        isError: true,
      );
    }

    final page = await server.notion.getPage(pageId);
    final title = NotionPageHelper.getTitle(page);

    if (newStage == 'Archived') {
      await server.notion.updatePageProperties(pageId, stage: 'Archived');
      await server.notion.archivePage(pageId);
    } else {
      await server.notion.updatePageProperties(pageId, stage: newStage);
    }

    return CallToolResult(
      content: [
        TextContent(text: 'Updated "$title" to stage: $newStage'),
      ],
    );
  });
}
