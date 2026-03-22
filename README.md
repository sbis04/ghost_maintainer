# The Ghost Maintainer

An AI-powered junior partner for solo open-source maintainers. Uses **Notion as the operations center** to triage GitHub issues, investigate code, propose fixes, and open PRs — all with human-in-the-loop review.

Built with Dart, the Notion API, Google Gemini, and the Model Context Protocol (MCP).

## How It Works

```
GitHub Issue Created
       |
       v
  GitHub Action
       |
       +---> Notion Triage Queue (Stage: New)
       |
       +---> AI Triage (Gemini)
       |        |
       |        +---> Bug (confident)     --> Maintenance Backlog --> Investigate --> PR
       |        +---> Feature (confident) --> Feature Backlog
       |        +---> Uncertain           --> Stays in Triage Queue for human review
       |
  Feature Backlog
       |
       +---> Click "Implement" in Notion
       |        |
       |        +---> Cloudflare Worker webhook
       |        +---> GitHub Action: Investigate --> PR
       |
  PR Merged
       |
       +---> GitHub Action: Archive in Notion
```

**Bugs** are fully automated: issue created -> triaged -> investigated -> PR opened. The maintainer only reviews and merges.

**Features** are one-click: the maintainer clicks "Implement" in Notion, and Ghost Maintainer handles the rest.

## Notion Databases

| Database | Purpose |
|---|---|
| **Triage Queue** | All new issues land here. AI classifies as Bug/Feature and routes. Low-confidence items stay for human review. |
| **Maintenance Backlog** | Bugs only. Auto-investigated with AI-proposed fixes and auto-created PRs. |
| **Feature Backlog** | Features only. One-click "Implement" button triggers AI implementation via webhook. |
| **Archive** | Completed items moved here when PRs are merged. Tracks type, priority, and resolved date. |
| **Project Vision Statement** | Guides AI triage and investigation decisions. |

## Architecture

### MCP Server (`ghost_maintainer_mcp/`)

A Dart MCP server exposing 5 tools, 2 resources, and 2 prompts — the full MCP surface area.

**Tools:**

| Tool | Description |
|---|---|
| `ghost_get_backlog` | Query the maintenance backlog with optional stage filter |
| `ghost_triage_issue` | AI-powered triage: assigns priority, labels, and summary |
| `ghost_investigate_issue` | Reads codebase, proposes concrete fixes with full file diffs |
| `ghost_deploy_fix` | Creates a GitHub branch and PR from the proposed fix |
| `ghost_sync_status` | Manually update the stage of a backlog item |

**Resources:**

| URI | Description |
|---|---|
| `ghost://vision` | Project vision statement from Notion |
| `ghost://backlog/summary` | Dynamic summary with stage counts and top priority items |

**Prompts:**

| Prompt | Description |
|---|---|
| `triage` | Structured triage prompt referencing the project vision |
| `investigate` | Code investigation prompt with file context |

### GitHub Actions (`.github/workflows/`)

| Workflow | Trigger | What it does |
|---|---|---|
| `issue_to_notion.yml` | Issue opened | Ingest to Triage Queue -> AI triage -> route -> investigate bugs -> create PR |
| `implement_feature.yml` | `workflow_dispatch` | Investigate a feature and create a PR |
| `pr_merged_archive.yml` | PR merged | Move the Notion item to Archive |

### Webhook (`webhook/`)

A Cloudflare Worker that bridges Notion to GitHub Actions. A clickable formula link in the Feature Backlog calls the worker, which triggers the `implement_feature` workflow.

### Automation Scripts (`notion_setup/`)

| Script | Purpose |
|---|---|
| `issue_ingestion.dart` | Creates a Triage Queue entry from a GitHub issue |
| `auto_triage.dart` | AI classification and routing (Bug/Feature/Uncertain) |
| `auto_investigate.dart` | Reads the full codebase, calls Gemini, proposes fixes |
| `auto_deploy.dart` | Applies changes, creates branch, pushes, opens PR |
| `archive_merged.dart` | Searches both backlogs, moves merged items to Archive |
| `setup_database.dart` | Creates the Maintenance Backlog database |
| `setup_all_databases.dart` | Creates the Triage Queue and Feature Backlog databases |
| `setup_archive_db.dart` | Creates the Archive database |
| `seed_vision.dart` | Creates the Project Vision Statement page |
| `push_to_repo.dart` | Pushes workflow and script files to a target repo |

## Setup

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart) >= 3.7.0
- A [Notion integration](https://www.notion.so/my-integrations) (internal)
- A [GitHub Personal Access Token](https://github.com/settings/tokens) with `repo` and `actions` scopes
- A [Google Gemini API key](https://aistudio.google.com/apikey)
- (Optional) A [Cloudflare Workers](https://workers.cloudflare.com) account for the feature webhook

### 1. Clone and install

```bash
git clone https://github.com/sbis04/ghost-maintainer.git
cd ghost-maintainer

# Install dependencies for each package
cd notion_setup && dart pub get && cd ..
cd ghost_maintainer_mcp && dart pub get && cd ..
```

### 2. Create Notion databases

```bash
cd notion_setup

# Create the parent page in Notion first, then:
export NOTION_TOKEN=ntn_...
export PARENT_PAGE_ID=...

dart run bin/setup_database.dart       # Maintenance Backlog
dart run bin/setup_all_databases.dart   # Triage Queue + Feature Backlog
dart run bin/setup_archive_db.dart      # Archive
dart run bin/seed_vision.dart           # Project Vision Statement
```

### 3. Configure environment

Create a `.env` file:

```env
# Notion
NOTION_TOKEN=ntn_...
NOTION_DATABASE_ID=...          # Maintenance Backlog
NOTION_TRIAGE_DB_ID=...         # Triage Queue
NOTION_FEATURE_DB_ID=...        # Feature Backlog
NOTION_ARCHIVE_DB_ID=...        # Archive
NOTION_VISION_PAGE_ID=...       # Vision Statement page

# GitHub
GITHUB_TOKEN=ghp_...
TARGET_REPO=owner/repo

# AI
GEMINI_API_KEY=...
```

### 4. Add GitHub repo secrets

Add these secrets to your target repo (Settings > Secrets and variables > Actions):

- `NOTION_TOKEN`
- `NOTION_DATABASE_ID`
- `NOTION_TRIAGE_DB_ID`
- `NOTION_FEATURE_DB_ID`
- `NOTION_ARCHIVE_DB_ID`
- `NOTION_VISION_PAGE_ID`
- `GEMINI_API_KEY`

Also enable **"Allow GitHub Actions to create and approve pull requests"** in Settings > Actions > General.

### 5. Push workflows to your repo

```bash
cd notion_setup
export GITHUB_TOKEN=ghp_...
export TARGET_REPO=owner/repo
dart run bin/push_to_repo.dart
```

### 6. (Optional) Set up the feature webhook

Deploy `webhook/worker.js` to Cloudflare Workers with these environment variables:

- `GITHUB_TOKEN` — your GitHub PAT
- `TARGET_REPO` — e.g. `owner/repo`
- `WEBHOOK_SECRET` — any random string

Then add a Formula property to the Feature Backlog in Notion:

```
link("Implement", "https://your-worker.workers.dev?issue=" + format(prop("Issue Number")) + "&secret=YOUR_SECRET")
```

### 7. Use the MCP server with Claude/Gemini

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

## Tech Stack

- **Dart** — MCP server, automation scripts, setup tools
- **Notion API** — Operations center (databases, pages, blocks)
- **Google Gemini** (gemini-2.5-flash) — AI triage and code investigation
- **GitHub Actions** — Event-driven automation
- **GitHub API** — Issue reading, branch/PR creation
- **Cloudflare Workers** — Webhook bridge from Notion to GitHub Actions
- **Model Context Protocol (MCP)** — Tools, Resources, and Prompts for AI integration

## Project Structure

```
ghost-maintainer/
├── ghost_maintainer_mcp/       # Dart MCP Server (5 tools, 2 resources, 2 prompts)
│   ├── bin/server.dart
│   └── lib/src/
│       ├── server.dart
│       ├── config.dart
│       ├── services/           # Notion, GitHub, Gemini clients
│       ├── tools/              # MCP tool implementations
│       ├── resources/          # MCP resource implementations
│       └── prompts/            # MCP prompt implementations
├── notion_setup/               # Setup and automation scripts
│   ├── bin/                    # CLI scripts
│   └── lib/notion_client.dart  # Lightweight Notion API wrapper
├── webhook/                    # Cloudflare Worker for Notion -> GitHub
│   └── worker.js
├── .github/workflows/          # GitHub Actions
│   ├── issue_to_notion.yml
│   ├── implement_feature.yml
│   └── pr_merged_archive.yml
└── .env.example
```

## License

MIT License - see [LICENSE](LICENSE) for details.
