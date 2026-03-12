import 'package:dart_mcp/server.dart';

import '../server.dart';
import '../services/notion_service.dart';

void registerBacklogSummaryResource(GhostMaintainerServer server) {
  server.addResource(
    Resource(
      uri: 'ghost://backlog/summary',
      name: 'Backlog Summary',
      description:
          'Dynamic summary of the maintenance backlog: counts by stage, top priority items.',
      mimeType: 'text/plain',
    ),
    (ReadResourceRequest request) async {
      final allPages = await server.notion.queryBacklog();

      // Count by stage
      final stageCounts = <String, int>{};
      final priorityItems = <String, List<String>>{};

      for (final page in allPages) {
        final stage = NotionPageHelper.getSelect(page, 'Stage') ?? 'Unknown';
        final priority =
            NotionPageHelper.getSelect(page, 'Priority') ?? 'Unset';
        final title = NotionPageHelper.getTitle(page);

        stageCounts[stage] = (stageCounts[stage] ?? 0) + 1;
        priorityItems.putIfAbsent(priority, () => []).add(title);
      }

      final buffer = StringBuffer();
      buffer.writeln('# Maintenance Backlog Summary');
      buffer.writeln('Total items: ${allPages.length}\n');

      buffer.writeln('## By Stage');
      for (final stage in [
        'New',
        'Triaged',
        'Investigating',
        'Review',
        'Deploy',
        'Archived',
      ]) {
        final count = stageCounts[stage] ?? 0;
        if (count > 0) buffer.writeln('- $stage: $count');
      }

      buffer.writeln('\n## Top Priority Items');
      for (final priority in [
        'P0-Critical',
        'P1-High',
        'P2-Medium',
        'P3-Low',
      ]) {
        final items = priorityItems[priority];
        if (items != null && items.isNotEmpty) {
          buffer.writeln('\n### $priority');
          for (final item in items) {
            buffer.writeln('- $item');
          }
        }
      }

      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: 'ghost://backlog/summary',
            text: buffer.toString(),
            mimeType: 'text/plain',
          ),
        ],
      );
    },
  );
}
