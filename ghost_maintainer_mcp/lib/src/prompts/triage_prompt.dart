import 'package:dart_mcp/server.dart';

import '../server.dart';

void registerTriagePrompt(GhostMaintainerServer server) {
  server.addPrompt(
    Prompt(
      name: 'triage',
      description:
          'Generate a structured triage prompt for a GitHub issue, '
          'incorporating the project vision statement.',
      arguments: [
        PromptArgument(
          name: 'issue_title',
          description: 'The title of the GitHub issue',
          required: true,
        ),
        PromptArgument(
          name: 'issue_body',
          description: 'The body text of the GitHub issue',
          required: true,
        ),
      ],
    ),
    (GetPromptRequest request) async {
      final args = request.arguments ?? {};
      final issueTitle = args['issue_title'] as String? ?? '';
      final issueBody = args['issue_body'] as String? ?? '';

      // Fetch vision statement for context
      final vision = await server.notion
          .getVisionStatement(server.config.notionVisionPageId);

      return GetPromptResult(
        description: 'Triage prompt for: $issueTitle',
        messages: [
          PromptMessage(
            role: Role.user,
            content: Content.text(
              text: '''You are a senior open-source maintainer triaging a GitHub issue.

PROJECT VISION:
$vision

ISSUE TITLE: $issueTitle

ISSUE BODY:
$issueBody

Please analyze this issue and provide:
1. **Priority** (P0-Critical, P1-High, P2-Medium, P3-Low)
2. **Labels** (Bug, Feature, Docs, Performance, Security, Chore)
3. **Summary** — one paragraph describing the issue and recommended action
4. **Reasoning** — your detailed analysis of why you assigned this priority and these labels

Then call the ghost_triage_issue tool with the appropriate page_id to apply your triage.''',
            ),
          ),
        ],
      );
    },
  );
}
