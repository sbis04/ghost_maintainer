import 'package:dart_mcp/server.dart';

import '../server.dart';

void registerVisionResource(GhostMaintainerServer server) {
  server.addResource(
    Resource(
      uri: 'ghost://vision',
      name: 'Project Vision Statement',
      description:
          'The project vision statement from Notion, used to guide AI triage and investigation.',
      mimeType: 'text/plain',
    ),
    (ReadResourceRequest request) async {
      final vision = await server.notion
          .getVisionStatement(server.config.notionVisionPageId);
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: 'ghost://vision',
            text: vision,
            mimeType: 'text/plain',
          ),
        ],
      );
    },
  );
}
