*This is a submission for the [Notion MCP Challenge](https://dev.to/challenges/notion-2026-03-04)*

## What I Built
<!-- Provide a description of your project. -->

## Video Demo
<!-- Share a video walkthrough of your workflow in action -->

## Show us the code
<!-- Embed or share a link to your code repo. -->

## How I Used Notion MCP
<!-- Explain how you integrated Notion MCP and what it unlocks in your workflow or system. -->

<!-- Don't forget to add a cover image (if you want). -->

<!-- Team Submissions: Please pick one member to publish the submission and credit teammates by listing their DEV usernames directly in the body of the post. -->

<!-- Thanks for participating! -->


---

*This is a submission for the [Notion MCP Challenge](https://dev.to/challenges/notion-2026-03-04)*

## What I Built

I maintain a few open source projects solo, and honestly, the hardest part isn't writing code — it's everything around it. Triaging issues, figuring out which ones are bugs vs feature requests, reading through the codebase to understand what's broken, and then actually getting around to fixing it. Most issues sit there for weeks.

Ghost Maintainer is my attempt to fix that. It's an AI-powered system that turns Notion into an operations center for your GitHub repository. When someone files an issue, it automatically:

1. Lands in a **Triage Queue** in Notion
2. Gets classified by Gemini as a bug or feature request (with confidence scoring)
3. Routes to the right backlog — **Maintenance Backlog** for bugs, **Feature Backlog** for feature requests
4. If it's a bug (and you have auto-fix on), it reads your entire codebase, proposes a fix, and opens a PR

The only thing left for you is reviewing the PR and hitting merge.

For bug reports, if you have disabled auto PR creation, then you trigger a fix using:

```plaintext
ghost_maintainer fix 3
```

For features, you trigger implementation when you're ready:

```plaintext
ghost_maintainer implement 9
```

That kicks off the same pipeline — reads the codebase, writes the code, opens a PR.

The whole thing installs with one command from inside your repo:

```shell
curl -sL https://raw.githubusercontent.com/sbis04/ghost_maintainer/main/install.sh \
  -o install.sh && \
  bash install.sh && \
  rm install.sh
```

It asks for your Notion, GitHub, and Gemini tokens, then sets up everything — databases, secrets, workflows, the lot.

I also built a full **MCP server** (in Dart, using the `dart_mcp` package) that exposes 5 tools, 2 resources, and 2 prompts. You can connect it to Gemini CLI or Claude and interact with your maintenance backlog conversationally — triage issues, investigate bugs, deploy fixes, all through natural language.

### The Notion workspace

![Ghost Maintainer Notion Page](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/zerg7f7g10lhzg1jim14.png)

- **Triage Queue** — every issue starts here, AI sorts it
- **Maintenance Backlog** — confirmed bugs with AI summaries, priority, and PR links
- **Feature Backlog** — feature requests waiting for implementation
- **Archive** — completed items with resolved dates
- **Project Vision Statement** — you edit this to guide how the AI thinks about your project

![Feature Request Notion Page](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/bdtoibmewxlk8svhxti3.png)

## Video Demo

{% embed https://youtu.be/AwVQcZSCFgM?si=yRfQOhqyjYBC6zYR %}

## Link to Code on GitHub

{% github sbis04/ghost_maintainer %}

The project has three main pieces:

- `ghost_maintainer_mcp/` — The MCP server (Dart). 5 tools, 2 resources, 2 prompts.
- `notion_setup/` — The CLI tool and GitHub Action scripts that power the automation.
- `.github/workflows/` — 4 workflows: issue ingestion, triage, implementation, and PR archival.

The CLI doubles as a globally installable tool (`dart pub global activate` from the repo, no publishing needed).

## How I Used Notion MCP

Notion is the central nervous system of Ghost Maintainer. Every piece of data flows through it.

**As the Issue Tracker:**
The Triage Queue, Maintenance Backlog, Feature Backlog, and Archive are all Notion databases. Each has structured properties (Stage, Priority, Labels, AI Summary, PR URL, Issue Number) that the automation reads and writes. When AI triages an issue, it updates the Notion page with its analysis. When a PR is created, the URL gets linked back. When the PR merges, the item moves to Archive with a timestamp.

**As the AI's Memory:**
The Project Vision Statement page is a Notion document that the AI reads before every triage and investigation. It contains your project's mission, principles, and current focus areas. This means the AI doesn't just categorize issues mechanically — it understands that "security issues are always P0" or "we're in a stability phase, deprioritize new features." You edit a Notion page, and the AI's behavior changes.

**Through MCP:**
The MCP server exposes Notion data as resources (`ghost://vision` for the vision statement, `ghost://backlog/summary` for live stats) and provides tools that read from and write to Notion. When you ask the MCP server to triage an issue, it pulls the vision from Notion, calls Gemini, then writes the results back to Notion. The protocol bridges conversational AI with structured project data.

**The flow end to end:**

```plaintext
GitHub Issue
    --> GitHub Action
    --> Notion Triage Queue
    --> AI Classification
    --> Notion Backlog
    --> AI Investigation
    --> GitHub PR
    --> Merge
    --> Notion Archive
```

Every step is visible in Notion. You always know where every issue is, what the AI decided, and why. No black boxes.

What I like most about this setup is that Notion becomes the source of truth that both humans and AI operate on. I check my Notion dashboard, I see what's happening. The AI checks the same dashboard. We're looking at the same board.
