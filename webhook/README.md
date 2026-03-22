# Ghost Maintainer Webhook

A Cloudflare Worker that triggers Ghost Maintainer workflows from Notion.

Handles both bug fixes (`?type=bug`) and feature implementations (`?type=feature`).

## Setup (2 minutes)

1. Go to https://workers.cloudflare.com and sign up (free)
2. Create a new Worker (Start with Hello World)
3. Replace the code with the contents of `worker.js`
4. Add environment variables in Settings > Variables and Secrets:
   - `GITHUB_TOKEN` — your GitHub PAT
   - `TARGET_REPO` — e.g. `sbis04/taskly`
   - `WEBHOOK_SECRET` — any random string (e.g. `ghost-abc123`)
5. Deploy and note the Worker URL

## Notion Formulas

**Feature Backlog** — add a Formula property called "Implement":

```
link("Implement", "https://YOUR_WORKER_URL?issue=" + format(prop("Issue Number")) + "&type=feature&secret=YOUR_SECRET")
```

**Maintenance Backlog** — add a Formula property called "Fix":

```
link("Fix", "https://YOUR_WORKER_URL?issue=" + format(prop("Issue Number")) + "&type=bug&secret=YOUR_SECRET")
```

Replace `YOUR_WORKER_URL` and `YOUR_SECRET` with your actual values.
