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

This server works alongside the Notion MCP server (@notionhq/notion-mcp-server).
Use Notion MCP tools (search, retrieve-a-page, create-a-page, append-block-children)
for general Notion workspace operations, and Ghost Maintainer tools for the
specialized maintenance workflow built on top of Notion.

Ghost Maintainer tools:
- ghost_get_backlog: View the maintenance backlog from Notion
- ghost_triage_issue: AI-powered issue triage with priority and label assignment
- ghost_investigate_issue: Deep code investigation with proposed fix
- ghost_deploy_fix: Create a GitHub branch and PR from proposed fix
- ghost_sync_status: Manually update an issue's stage

Ghost Maintainer resources:
- ghost://vision: Project vision statement (from Notion)
- ghost://backlog/summary: Dynamic backlog summary with counts (from Notion)

Ghost Maintainer prompts:
- triage: Get a structured triage prompt for an issue
- investigate: Get a code investigation prompt for an issue

Workflow: Use Notion MCP to browse the workspace and find issues, then use
Ghost Maintainer tools to triage, investigate, and deploy fixes.''',
        ) {
    notion = NotionService(token: config.notionToken, databaseId: config.notionDatabaseId);
    github = GitHubService(token: config.githubToken);
    gemini = GeminiService(apiKey: config.geminiApiKey);

    // Register tools, resources, and prompts eagerly in constructor
    registerGetBacklogTool(this);
    registerTriageIssueTool(this);
    registerInvestigateIssueTool(this);
    registerDeployFixTool(this);
    registerSyncStatusTool(this);

    registerVisionResource(this);
    registerBacklogSummaryResource(this);

    registerTriagePrompt(this);
    registerInvestigatePrompt(this);
  }

  @override
  Future<void> shutdown() async {
    notion.dispose();
    github.dispose();
    gemini.dispose();
    await super.shutdown();
  }
}
