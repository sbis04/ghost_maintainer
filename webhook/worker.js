// Cloudflare Worker — triggers GitHub Actions "Implement Feature" workflow.
// Deploy to Cloudflare Workers (free tier: 100K requests/day).
//
// Environment variables (set in Cloudflare dashboard):
//   GITHUB_TOKEN  — GitHub PAT with repo + actions scope
//   TARGET_REPO   — e.g. "sbis04/taskly"
//   WEBHOOK_SECRET — a random string to prevent unauthorized triggers

export default {
  async fetch(request, env) {
    // Only allow GET (clickable from Notion) and POST
    if (request.method !== 'GET' && request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const url = new URL(request.url);
    const issueNumber = url.searchParams.get('issue');
    const secret = url.searchParams.get('secret');

    if (!issueNumber) {
      return new Response('Missing ?issue= parameter', { status: 400 });
    }

    if (secret !== env.WEBHOOK_SECRET) {
      return new Response('Unauthorized', { status: 401 });
    }

    // Trigger GitHub Actions workflow_dispatch
    const response = await fetch(
      `https://api.github.com/repos/${env.TARGET_REPO}/actions/workflows/implement_feature.yml/dispatches`,
      {
        method: 'POST',
        headers: {
          'Authorization': `token ${env.GITHUB_TOKEN}`,
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
          'User-Agent': 'Ghost-Maintainer-Webhook',
        },
        body: JSON.stringify({
          ref: 'main',
          inputs: { issue_number: issueNumber },
        }),
      }
    );

    if (response.status === 204) {
      // Return a nice HTML page so the user sees confirmation
      return new Response(
        `<!DOCTYPE html>
<html>
<head><title>Ghost Maintainer</title></head>
<body style="font-family: system-ui; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #191919; color: #fff;">
  <div style="text-align: center;">
    <h1>Ghost Maintainer</h1>
    <p style="font-size: 1.5em;">Feature #${issueNumber} implementation triggered!</p>
    <p style="color: #888;">You can close this tab. Check GitHub Actions for progress.</p>
  </div>
</body>
</html>`,
        {
          status: 200,
          headers: { 'Content-Type': 'text/html' },
        }
      );
    } else {
      const body = await response.text();
      return new Response(`GitHub API error: ${response.status} ${body}`, {
        status: 500,
      });
    }
  },
};
