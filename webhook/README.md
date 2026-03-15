# Ghost Maintainer Webhook

A Cloudflare Worker that triggers the "Implement Feature" GitHub Action from Notion.

## Setup (2 minutes)

1. Go to https://workers.cloudflare.com and sign up (free)
2. Create a new Worker
3. Paste the contents of `worker.js`
4. Add environment variables in Settings → Variables:
   - `GITHUB_TOKEN` → your GitHub PAT (same one used for the repo)
   - `TARGET_REPO` → `sbis04/taskly`
   - `WEBHOOK_SECRET` → any random string (e.g. `ghost-abc123`)
5. Deploy and note the Worker URL (e.g. `https://ghost-maintainer.xxx.workers.dev`)

## Notion Formula

Add a **Formula** property called "Implement" to the Feature Backlog with this formula:

```
link("Implement", "https://YOUR_WORKER_URL?issue=" + format(prop("Issue Number")) + "&secret=YOUR_SECRET")
```

Replace `YOUR_WORKER_URL` and `YOUR_SECRET` with your actual values.

This creates a clickable "Implement" link on each feature row. One click triggers the full pipeline.
