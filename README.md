# The Ghost Maintainer

Solo maintainers wear too many hats. Ghost Maintainer takes over the repetitive parts — triaging issues, reading code, writing fixes, and opening PRs — so you can focus on the work that actually needs a human.

It uses Notion as an operations center. Bugs get triaged and fixed automatically. Features queue up for you to trigger with one click. Everything stays visible in Notion so you never lose track.

Built with Dart, MCP, Google Gemini, and the Notion API.

## Getting Started

You'll need [Dart](https://dart.dev/get-dart) (>= 3.7.0) and [GitHub CLI](https://cli.github.com/) installed.

Grab three API keys before you start:

| What | Where | Notes |
|---|---|---|
| Notion token | [notion.so/profile/integrations](https://www.notion.so/profile/integrations) | Internal integration, read + write permissions |
| GitHub PAT | [github.com/settings/tokens](https://github.com/settings/tokens) | Classic token, `repo` + `actions` scopes |
| Gemini key | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | Any project works |

Then create an **empty** page in Notion (call it whatever you want), connect your integration to it (page `...` menu > Connections), and copy the page URL.

### Quick install

From inside your repo:

```bash
curl -sL https://raw.githubusercontent.com/sbis04/ghost-maintainer/main/install.sh | bash
```

It'll ask for your tokens, detect your repo, set everything up, and you're done.

### Or install the CLI

```bash
dart pub global activate --source git https://github.com/sbis04/ghost-maintainer.git --git-path notion_setup
```

```bash
cd your-repo
ghost_maintainer setup \
  --notion-token ntn_... \
  --github-token ghp_... \
  --gemini-key AIza... \
  --notion-parent-page-id "https://notion.so/Your-Page-abc123..."
```

Repo is auto-detected from `git remote`. Setup creates all the Notion databases, adds your GitHub secrets, enables Actions permissions, and pushes the workflows. One command, done.

### Configuration

```bash
ghost_maintainer config                        # see current settings
ghost_maintainer config --auto-fix-bugs=false  # stop auto-creating PRs for bugs
ghost_maintainer config --auto-fix-bugs=true   # turn it back on
```

Settings live in `.ghost_maintainer.json` in your repo and get pushed to GitHub automatically.

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
Feature Backlog
    |
    +-- one-click "Implement" --> webhook --> investigate --> PR
    |
PR merged
    |
    +-- archived in Notion
```

Bugs go through the full pipeline automatically. Features wait in the backlog until you decide to implement one — then it's one click from Notion (via a [Cloudflare Worker webhook](webhook/README.md)).

### Notion databases

The setup creates five things under your page:

- **Triage Queue** — where every issue lands first. AI sorts it.
- **Maintenance Backlog** — confirmed bugs. Auto-investigated, auto-PR'd.
- **Feature Backlog** — feature requests. One-click to implement.
- **Archive** — merged items go here with timestamps.
- **Project Vision Statement** — edit this to guide how the AI prioritizes and triages.

### One-click features (optional)

If you want the "Implement" button in Notion:

1. Deploy [`webhook/worker.js`](webhook/worker.js) to [Cloudflare Workers](https://workers.cloudflare.com) (free tier)
2. Set env vars: `GITHUB_TOKEN`, `TARGET_REPO`, `WEBHOOK_SECRET`
3. Add a Formula property to the Feature Backlog:
   ```
   link("Implement", "https://your-worker.workers.dev?issue=" + format(prop("Issue Number")) + "&secret=YOUR_SECRET")
   ```

## MCP Server

There's also a full MCP server (`ghost_maintainer_mcp/`) you can connect to Gemini CLI, Claude, or any MCP client. It exposes 5 tools, 2 resources, and 2 prompts.

| Type | Name | What it does |
|---|---|---|
| Tool | `ghost_get_backlog` | Query the backlog by stage |
| Tool | `ghost_triage_issue` | AI triage with priority + labels |
| Tool | `ghost_investigate_issue` | Read code and propose fixes |
| Tool | `ghost_deploy_fix` | Create a branch and PR |
| Tool | `ghost_sync_status` | Update issue stage manually |
| Resource | `ghost://vision` | Vision statement |
| Resource | `ghost://backlog/summary` | Backlog stats |
| Prompt | `triage` / `investigate` | Structured prompts for each workflow |

MCP config for Gemini CLI or Claude:

```json
{
  "mcpServers": {
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

## Project structure

```
ghost-maintainer/
├── ghost_maintainer_mcp/       # MCP server (Dart)
│   └── lib/src/
│       ├── services/           # Notion, GitHub, Gemini
│       ├── tools/              # 5 tools
│       ├── resources/          # 2 resources
│       └── prompts/            # 2 prompts
├── notion_setup/               # CLI + automation scripts
│   ├── bin/ghost_maintainer.dart   # CLI entry point
│   ├── bin/auto_*.dart             # GitHub Action scripts
│   └── lib/                        # shared code
├── webhook/worker.js           # Cloudflare Worker
├── install.sh                  # interactive installer
└── .github/workflows/          # 3 workflows
```

## Tech

Dart, [MCP](https://modelcontextprotocol.io/) (`dart_mcp`), Google Gemini 2.5 Flash, Notion API, GitHub Actions, Cloudflare Workers.

## License

[MIT](LICENSE)
