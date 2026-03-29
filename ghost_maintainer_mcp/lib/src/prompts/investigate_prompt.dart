import 'package:dart_mcp/server.dart';

import '../server.dart';

void registerInvestigatePrompt(GhostMaintainerServer server) {
  server.addPrompt(
    Prompt(
      name: 'investigate',
      description:
          'Generate a code investigation prompt for a GitHub issue, '
          'with the project vision and file list for context.',
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
        PromptArgument(
          name: 'file_list',
          description:
              'Comma-separated list of relevant source file paths to investigate',
          required: false,
        ),
      ],
    ),
    (GetPromptRequest request) async {
      final args = request.arguments ?? {};
      final issueTitle = args['issue_title'] as String? ?? '';
      final issueBody = args['issue_body'] as String? ?? '';
      final fileList = args['file_list'] as String? ?? '';

      final vision = await server.notion
          .getVisionStatement(server.config.notionVisionPageId);

      final fileSection = fileList.isNotEmpty
          ? '\nFILES TO INVESTIGATE:\n${fileList.split(',').map((f) => '- ${f.trim()}').join('\n')}'
          : '\n(No specific files provided — the tool will auto-detect relevant files)';

      return GetPromptResult(
        description: 'Investigation prompt for: $issueTitle',
        messages: [
          PromptMessage(
            role: Role.user,
            content: Content.text(
              text: '''You are a senior developer investigating a GitHub issue and proposing a fix.

PROJECT VISION:
$vision

ISSUE TITLE: $issueTitle

ISSUE BODY:
$issueBody
$fileSection

Please:
1. Analyze the issue and identify the likely root cause
2. Determine which files are affected
3. Propose a specific code fix with a unified diff
4. Explain the fix and your confidence level (0-100)

Use Notion MCP's retrieve-a-page to read the full issue details and any prior triage notes from Notion.
Then call the ghost_investigate_issue tool with the appropriate page_id to apply your investigation.
If you know which files to focus on, pass them as file_hints.
After investigating, use Notion MCP's append-block-children to add your analysis to the Notion page.''',
            ),
          ),
        ],
      );
    },
  );
}
