import 'dart:async';

import 'package:dart_mcp/server.dart';

import 'config.dart';
import 'services/gemini_service.dart';
import 'services/github_service.dart';
import 'services/notion_service.dart';

import 'tools/get_backlog.dart';
import 'tools/triage_issue.dart';
import 'tools/investigate_issue.dart';
import 'tools/deploy_fix.dart';
import 'tools/sync_status.dart';

import 'resources/vision_statement.dart';
import 'resources/backlog_summary.dart';

import 'prompts/triage_prompt.dart';
import 'prompts/investigate_prompt.dart';

base class GhostMaintainerServer extends MCPServer
    with ToolsSupport, ResourcesSupport, PromptsSupport {
  final Config config;
  late final NotionService notion;
  late final GitHubService github;
  late final GeminiService gemini;

  GhostMaintainerServer(
    super.channel, {
    required this.config,
  }) : super.fromStreamChannel(
          implementation: Implementation(
            name: 'ghost-maintainer',
            version: '0.1.0',
          ),
          instructions: '''Ghost Maintainer is an AI-powered junior partner for solo open-source maintainers.
It uses Notion as the operations center to triage GitHub issues, investigate code, propose fixes, and open PRs.

Available tools:
- ghost_get_backlog: View the maintenance backlog from Notion
- ghost_triage_issue: AI-powered issue triage with priority and label assignment
- ghost_investigate_issue: Deep code investigation with proposed fix
- ghost_deploy_fix: Create a GitHub branch and PR from proposed fix
- ghost_sync_status: Manually update an issue's stage

Available resources:
- ghost://vision: Project vision statement
- ghost://backlog/summary: Dynamic backlog summary with counts

Available prompts:
- triage: Get a structured triage prompt for an issue
- investigate: Get a code investigation prompt for an issue''',
        ) {
    notion = NotionService(token: config.notionToken, databaseId: config.notionDatabaseId);
    github = GitHubService(token: config.githubToken);
    gemini = GeminiService(apiKey: config.geminiApiKey);
  }

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    final result = await super.initialize(request);

    // Register tools
    registerGetBacklogTool(this);
    registerTriageIssueTool(this);
    registerInvestigateIssueTool(this);
    registerDeployFixTool(this);
    registerSyncStatusTool(this);

    // Register resources
    registerVisionResource(this);
    registerBacklogSummaryResource(this);

    // Register prompts
    registerTriagePrompt(this);
    registerInvestigatePrompt(this);

    return result;
  }

  @override
  Future<void> shutdown() async {
    notion.dispose();
    github.dispose();
    gemini.dispose();
    await super.shutdown();
  }
}
