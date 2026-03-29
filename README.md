# Ghost Maintainer

<img width="1280" height="640" alt="ghost maintainer cover" src="https://github.com/user-attachments/assets/979938f8-370b-4185-a662-531630d50e7c" />


Solo maintainers wear too many hats. Ghost Maintainer takes over the repetitive parts — triaging issues, reading code, writing fixes, and opening PRs — so you can focus on the work that actually needs a human.

It uses Notion as an operations center. Bugs get triaged and fixed automatically. Features queue up until you're ready. Everything stays visible in Notion so you never lose track.

Built with Dart, MCP, Google Gemini, and the Notion API.

## Getting Started

You'll need [Dart](https://dart.dev/get-dart) (>= 3.7.0) and [GitHub CLI](https://cli.github.com/) installed.

Grab three API keys before you start:

| What | Where | Notes |
|---|---|---|
| Notion token | [notion.so/profile/integrations](https://www.notion.so/profile/integrations) | See steps below |
| GitHub PAT | [github.com/settings/tokens](https://github.com/settings/tokens) | Classic token, `repo` + `actions` scopes |
| Gemini key | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | Any project works |

You can either follow the steps in the next section, or have a look at the [**demo video**](https://youtu.be/AwVQcZSCFgM?si=yRfQOhqyjYBC6zYR) to learn more about the tool and get step-by-step instruction for installing Ghost Maintainer for your repository.


**Notion setup (1 minute):**
1. Go to [notion.so/profile/integrations](https://www.notion.so/profile/integrations) → **New integration**
2. Give it a name (e.g. "Ghost Maintainer"), select your workspace, click **Submit**
3. Copy the **Internal Integration Secret** (starts with `ntn_`)
4. Create an **empty** page in Notion (call it whatever you want)
5. On that page, click `...` (top right) → **Connections** → select your integration
6. Copy the page URL (Share → Copy link)

### Quick install

From inside your repo:

```bash
curl -sL https://raw.githubusercontent.com/sbis04/ghost_maintainer/main/install.sh -o install.sh && bash install.sh && rm install.sh
```

It walks you through everything: tokens, Notion setup, and optionally syncs your existing issues.

### Or install the CLI manually

```bash
dart pub global activate --source git https://github.com/sbis04/ghost_maintainer.git --git-path notion_setup
```

```bash
cd your-repo
ghost_maintainer setup \
  --notion-token ntn_... \
  --github-token ghp_... \
  --gemini-key AIza... \
  --notion-parent-page-id "https://notion.so/Your-Page-abc123..."
```

Repo is auto-detected from `git remote`. Setup creates all the Notion databases, adds your GitHub secrets, enables Actions permissions, and pushes the workflows.

### CLI commands

```bash
ghost_maintainer setup                 # full setup (Notion, GitHub, workflows)
ghost_maintainer fix <issue_number>    # investigate a bug and create a PR
ghost_maintainer implement <issue>     # implement a feature and create a PR
ghost_maintainer sync                  # import existing GitHub issues to Notion
ghost_maintainer config                # view/change settings
```

```bash
# examples
ghost_maintainer fix 7                          # trigger a bug fix for issue #7
ghost_maintainer implement 9                    # implement feature request #9
ghost_maintainer sync                           # sync all open issues
ghost_maintainer sync --state all --limit 20    # include closed, cap at 20
ghost_maintainer config --auto-fix-bugs=false   # stop auto-creating PRs for bugs
```

Settings live in `.ghost_maintainer.json` in your repo and get pushed to GitHub automatically. Sync and fix/implement commands read tokens from `.ghost_maintainer.env` (created by setup).

### Connect Notion MCP (for interactive AI use)

If you want to use Ghost Maintainer interactively through an AI client (Gemini CLI, Claude, Cursor), set up both Notion MCP and Ghost Maintainer MCP together.

**1. Install the Notion MCP server:**

```bash
npm install -g @notionhq/notion-mcp-server
```

**2. Add both servers to your AI client:**

**Gemini CLI:**

```bash
gemini mcp add notion -- npx -y @notionhq/notion-mcp-server
# Set NOTION_TOKEN in the Gemini CLI MCP settings

gemini mcp add ghost-maintainer -- dart run bin/server.dart
# Set env vars in the Gemini CLI MCP settings (cwd: /path/to/ghost_maintainer_mcp)
```

**Claude Code:**

```bash
claude mcp add notion -- npx -y @notionhq/notion-mcp-server
claude mcp add ghost-maintainer -- dart run bin/server.dart
```

**Cursor / other MCP clients** — add to `.cursor/mcp.json` or equivalent:

```json
{
  "mcpServers": {
    "notion": {
      "command": "npx",
      "args": ["-y", "@notionhq/notion-mcp-server"],
      "env": {
        "NOTION_TOKEN": "ntn_..."
      }
    },
    "ghost-maintainer": {
      "command": "dart",
      "args": ["run", "bin/server.dart"],
      "cwd": "/path/to/ghost_maintainer_mcp",
      "env": {
        "NOTION_TOKEN": "ntn_...",
        "NOTION_DATABASE_ID": "...",
        "NOTION_VISION_PAGE_ID": "...",
        "GITHUB_TOKEN": "ghp_...",
        "TARGET_REPO": "owner/repo",
        "GEMINI_API_KEY": "..."
      }
    }
  }
}
```

Notion MCP gives the AI general workspace access. Ghost Maintainer MCP adds the maintenance tools. See the [MCP Server](#mcp-server) section for details.

## How it works

```
GitHub Issue opened
    |
    v
Triage Queue (Notion)
    |
    +-- AI classifies it
    |     |
    |     +-- Bug       --> Maintenance Backlog --> investigate --> PR
    |     +-- Feature   --> Feature Backlog
    |     +-- Uncertain --> stays for human review
    |
Want to fix a bug or implement a feature manually?
    |
    +-- ghost_maintainer fix 7         --> investigate --> PR
    +-- ghost_maintainer implement 9   --> investigate --> PR
    |
PR merged
    |
    +-- archived in Notion
```

Bugs go through the full pipeline automatically (if `auto_fix_bugs` is on). Features wait in the backlog until you trigger them with `ghost_maintainer implement <issue>`.

### Notion databases

<img height="915" alt="Ghost Maintainer Notion Page" src="https://github.com/user-attachments/assets/cf96e98e-86c0-4eac-8a46-c0f5aa8ce0ef" />

The setup creates five things under your page:

- **Triage Queue** — where every issue lands first. AI sorts it.
- **Maintenance Backlog** — confirmed bugs. Auto-investigated, auto-PR'd.
- **Feature Backlog** — feature requests. Trigger with `ghost_maintainer implement`.
- **Archive** — merged items go here with timestamps.
- **Project Vision Statement** — edit this to guide how the AI prioritizes and triages.

## MCP Server

Ghost Maintainer ships with a Dart MCP server that works alongside **[Notion MCP](https://developers.notion.com/guides/mcp/mcp)** (`@notionhq/notion-mcp-server`). Both servers connect to the same AI client:

- **Notion MCP** handles general workspace operations — searching, reading pages, creating content
- **Ghost Maintainer MCP** handles the specialized maintenance workflow — triage, investigation, deployment

Together, they give your AI assistant full access to both your Notion workspace and the Ghost Maintainer pipeline.

### Ghost Maintainer MCP tools

| Type | Name | What it does |
|---|---|---|
| Tool | `ghost_get_backlog` | Query the backlog by stage |
| Tool | `ghost_triage_issue` | AI triage with priority + labels |
| Tool | `ghost_investigate_issue` | Read code and propose fixes |
| Tool | `ghost_deploy_fix` | Create a branch and PR |
| Tool | `ghost_sync_status` | Update issue stage manually |
| Resource | `ghost://vision` | Vision statement (from Notion) |
| Resource | `ghost://backlog/summary` | Backlog stats (from Notion) |
| Prompt | `triage` / `investigate` | Structured prompts referencing both Notion MCP and Ghost Maintainer tools |

See the [Getting Started](#connect-notion-mcp-for-interactive-ai-use) section for setup instructions, or check [`mcp_config.example.json`](mcp_config.example.json).

The prompts guide the AI to use both servers — e.g., the triage prompt tells the AI to use Notion MCP's search to check for duplicates before triaging with Ghost Maintainer tools.

## Project structure

```
ghost-maintainer/
├── ghost_maintainer_mcp/           # MCP server (Dart)
│   └── lib/src/
│       ├── services/               # Notion, GitHub, Gemini
│       ├── tools/                  # 5 tools
│       ├── resources/              # 2 resources
│       └── prompts/                # 2 prompts
├── notion_setup/                   # CLI + automation scripts
│   ├── bin/ghost_maintainer.dart   # CLI entry point
│   ├── bin/auto_*.dart             # GitHub Action scripts
│   └── lib/                        # shared code
├── install.sh                      # interactive installer
└── .github/workflows/              # 3 workflows
```

## Tech

Dart, [MCP](https://modelcontextprotocol.io/) (`dart_mcp`), Google Gemini 2.5 Flash, Notion API, GitHub Actions.

## [License](LICENSE)

MIT
