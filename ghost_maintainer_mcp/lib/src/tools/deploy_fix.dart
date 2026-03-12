import 'dart:convert';

import 'package:dart_mcp/server.dart';

import '../server.dart';
import '../services/notion_service.dart';

void registerDeployFixTool(GhostMaintainerServer server) {
  final tool = Tool(
    name: 'ghost_deploy_fix',
    description:
        'Deploy the proposed fix from an investigated issue. Creates a GitHub branch, '
        'commits the changes, opens a PR, and updates Notion with the PR link.',
    inputSchema: ObjectSchema(
      properties: {
        'page_id': Schema.string(
          description: 'The Notion page ID of the backlog item to deploy',
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

    // 2. Extract proposed changes from page blocks
    final blocks = await server.notion.getPageBlocks(pageId);
    final proposedDiff = _extractProposedDiff(blocks);

    if (proposedDiff.isEmpty) {
      return CallToolResult(
        content: [
          TextContent(
            text: 'No proposed fix found on this Notion page. '
                'Run ghost_investigate_issue first to generate a proposed fix.',
          ),
        ],
        isError: true,
      );
    }

    // 3. Parse the diff to get file changes
    final changes = _parseDiff(proposedDiff);
    if (changes.isEmpty) {
      return CallToolResult(
        content: [
          TextContent(
            text: 'Could not parse the proposed diff into actionable file changes.',
          ),
        ],
        isError: true,
      );
    }

    final owner = server.config.repoOwner;
    final repo = server.config.repoName;

    // 4. Create a branch
    final branchName =
        'ghost/fix-issue-${issueNumber ?? DateTime.now().millisecondsSinceEpoch}';
    final baseSha = await server.github.getDefaultBranchSha(owner, repo);
    final defaultBranch = await server.github.getDefaultBranch(owner, repo);

    await server.github.createBranch(owner, repo, branchName, baseSha);

    // 5. Apply each file change
    for (final change in changes) {
      // Get existing file content and apply the diff
      String newContent;
      try {
        final existing = await server.github.getFileContent(
          owner,
          repo,
          change.filePath,
          branch: branchName,
        );
        newContent = _applySimpleDiff(existing, change);
      } catch (_) {
        // File doesn't exist, use the added lines
        newContent = change.addedLines.join('\n');
      }

      await server.github.createOrUpdateFile(
        owner,
        repo,
        change.filePath,
        newContent,
        'fix: ${change.filePath} — ghost fix for #$issueNumber',
        branchName,
      );
    }

    // 6. Create PR
    final prBody = '''## Ghost Maintainer Fix

Automated fix for issue #$issueNumber: $title

### Changes
${changes.map((c) => '- `${c.filePath}`').join('\n')}

### Investigation
See the [Notion backlog item](https://notion.so/${pageId.replaceAll('-', '')}) for full analysis.

---
*Created by [Ghost Maintainer](https://github.com) MCP Server*''';

    final pr = await server.github.createPullRequest(
      owner,
      repo,
      title: 'fix: $title (#$issueNumber)',
      body: prBody,
      head: branchName,
      base: defaultBranch,
    );

    final prUrl = pr['html_url'] as String;

    // 7. Update Notion
    await server.notion.updatePageProperties(
      pageId,
      stage: 'Deploy',
      prUrl: prUrl,
    );

    await server.notion.appendPageContent(
      pageId,
      NotionService.buildDeploymentBlocks(
        prUrl: prUrl,
        branchName: branchName,
      ),
    );

    return CallToolResult(
      content: [
        TextContent(
          text: '''Deployment complete for issue #$issueNumber: "$title"

**Branch:** $branchName
**PR:** $prUrl
**Files changed:** ${changes.length}

The Notion page has been updated with the PR link. Stage set to "Deploy".
The maintainer can now review and merge the PR on GitHub.''',
        ),
      ],
    );
  });
}

String _extractProposedDiff(List<Map<String, dynamic>> blocks) {
  var foundProposedFix = false;

  for (final block in blocks) {
    final type = block['type'] as String;

    if (type == 'heading_2') {
      final texts = block['heading_2']?['rich_text'] as List? ?? [];
      final text = texts.map((t) => t['plain_text'] ?? '').join();
      if (text == 'Proposed Fix') {
        foundProposedFix = true;
        continue;
      } else if (foundProposedFix) {
        break;
      }
    }

    if (!foundProposedFix) continue;

    if (type == 'code') {
      final texts = block['code']?['rich_text'] as List? ?? [];
      return texts.map((t) => t['plain_text'] ?? '').join();
    }

    if (type == 'divider') break;
  }

  return '';
}

class _FileChange {
  final String filePath;
  final List<String> removedLines;
  final List<String> addedLines;
  final String rawDiff;

  _FileChange({
    required this.filePath,
    required this.removedLines,
    required this.addedLines,
    required this.rawDiff,
  });
}

List<_FileChange> _parseDiff(String diff) {
  final changes = <_FileChange>[];
  final lines = const LineSplitter().convert(diff);

  String? currentFile;
  var removed = <String>[];
  var added = <String>[];
  var rawLines = <String>[];

  void flushCurrent() {
    if (currentFile != null) {
      changes.add(_FileChange(
        filePath: currentFile!,
        removedLines: removed,
        addedLines: added,
        rawDiff: rawLines.join('\n'),
      ));
    }
    currentFile = null;
    removed = <String>[];
    added = <String>[];
    rawLines = <String>[];
  }

  for (final line in lines) {
    if (line.startsWith('--- ')) {
      flushCurrent();
      // Extract file path (strip a/ or b/ prefix)
      currentFile = line.substring(4).replaceFirst(RegExp(r'^[ab]/'), '');
      rawLines.add(line);
    } else if (line.startsWith('+++ ')) {
      currentFile = line.substring(4).replaceFirst(RegExp(r'^[ab]/'), '');
      rawLines.add(line);
    } else if (currentFile != null) {
      rawLines.add(line);
      if (line.startsWith('-') && !line.startsWith('---')) {
        removed.add(line.substring(1));
      } else if (line.startsWith('+') && !line.startsWith('+++')) {
        added.add(line.substring(1));
      }
    }
  }
  flushCurrent();

  return changes;
}

String _applySimpleDiff(String original, _FileChange change) {
  if (change.removedLines.isEmpty) {
    // Pure addition — append to end
    return '$original\n${change.addedLines.join('\n')}';
  }

  var result = original;
  // Try to find and replace the removed lines with added lines
  final removedBlock = change.removedLines.join('\n');
  final addedBlock = change.addedLines.join('\n');

  if (result.contains(removedBlock)) {
    result = result.replaceFirst(removedBlock, addedBlock);
  } else {
    // Fallback: try line-by-line replacement
    final resultLines = result.split('\n');
    for (var i = 0; i < change.removedLines.length; i++) {
      final idx = resultLines.indexOf(change.removedLines[i]);
      if (idx != -1) {
        if (i < change.addedLines.length) {
          resultLines[idx] = change.addedLines[i];
        } else {
          resultLines.removeAt(idx);
        }
      }
    }
    // Add any remaining added lines
    if (change.addedLines.length > change.removedLines.length) {
      resultLines.addAll(
        change.addedLines.sublist(change.removedLines.length),
      );
    }
    result = resultLines.join('\n');
  }

  return result;
}
