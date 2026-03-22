#!/bin/bash
set -e

# Ghost Maintainer - One-command installer
# Run from inside your GitHub repo:
#   curl -sL https://raw.githubusercontent.com/sbis04/ghost_maintainer/main/install.sh | bash

GHOST_REPO="sbis04/ghost_maintainer"

echo ""
echo "=== Ghost Maintainer Installer ==="
echo ""

# Check prerequisites
if ! command -v dart &> /dev/null; then
  echo "Error: Dart SDK not found. Install from https://dart.dev/get-dart"
  exit 1
fi

if ! command -v git &> /dev/null; then
  echo "Error: git not found."
  exit 1
fi

if ! command -v gh &> /dev/null; then
  echo "Warning: GitHub CLI (gh) not found. Install from https://cli.github.com"
  echo "         Secrets will need to be added manually without it."
  echo ""
fi

# Auto-detect repo from git remote
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [ -z "$REMOTE_URL" ]; then
  echo "Error: Not in a git repo or no 'origin' remote found."
  echo "Run this from inside your GitHub repo directory."
  exit 1
fi

TARGET_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$|\1|')
echo "Detected repo: $TARGET_REPO"
echo ""

# --- Step 1: Collect API tokens ---

echo "--- Step 1: API Tokens ---"
echo ""

read -p "Notion Integration Token (ntn_...): " NOTION_TOKEN
if [ -z "$NOTION_TOKEN" ]; then
  echo ""
  echo "  Get one at: https://www.notion.so/profile/integrations"
  echo "  Create an internal integration with read/write permissions."
  echo ""
  read -p "Notion Integration Token: " NOTION_TOKEN
fi

echo ""
echo "  Before pasting the URL, make sure you've:"
echo "    1. Created an EMPTY page in Notion"
echo "    2. Connected your integration to it (... menu > Connections > select integration)"
echo "    3. Copied the page URL (Share > Copy link)"
echo ""
read -p "Notion Page URL: " NOTION_PAGE_INPUT
if [ -z "$NOTION_PAGE_INPUT" ]; then
  read -p "Notion Page URL: " NOTION_PAGE_INPUT
fi

read -p "GitHub Personal Access Token (ghp_...): " GITHUB_TOKEN
if [ -z "$GITHUB_TOKEN" ]; then
  echo ""
  echo "  Get one at: https://github.com/settings/tokens"
  echo "  Required scopes: repo, actions"
  echo ""
  read -p "GitHub Token: " GITHUB_TOKEN
fi

read -p "Gemini API Key (AIza...): " GEMINI_KEY
if [ -z "$GEMINI_KEY" ]; then
  echo ""
  echo "  Get one at: https://aistudio.google.com/apikey"
  echo ""
  read -p "Gemini API Key: " GEMINI_KEY
fi

echo ""
read -p "Auto-fix bugs with PRs? (Y/n): " AUTO_FIX
AUTO_FIX_FLAG=""
if [[ "$AUTO_FIX" =~ ^[Nn] ]]; then
  AUTO_FIX_FLAG="--no-auto-fix-bugs"
fi

# --- Step 2: Cloudflare Worker for one-click buttons ---

echo ""
echo "--- Step 2: Cloudflare Worker (for Fix/Implement buttons in Notion) ---"
echo ""
echo "  Ghost Maintainer needs a small webhook (Cloudflare Workers, free tier)"
echo "  so you can trigger bug fixes and feature implementations from Notion."
echo ""
echo "  If you don't have a Cloudflare account yet:"
echo "    1. Sign up at https://workers.cloudflare.com (free)"
echo "    2. Go to https://dash.cloudflare.com — copy your Account ID from the sidebar"
echo "    3. Go to https://dash.cloudflare.com/profile/api-tokens"
echo "       → Create Token → use 'Edit Cloudflare Workers' template"
echo ""

read -p "Cloudflare Account ID: " CF_ACCOUNT_ID
if [ -z "$CF_ACCOUNT_ID" ]; then
  echo ""
  echo "  Find it at: https://dash.cloudflare.com → sidebar → Account ID"
  echo ""
  read -p "Cloudflare Account ID: " CF_ACCOUNT_ID
fi

read -p "Cloudflare API Token: " CF_API_TOKEN
if [ -z "$CF_API_TOKEN" ]; then
  echo ""
  echo "  Create one at: https://dash.cloudflare.com/profile/api-tokens"
  echo "  Use the 'Edit Cloudflare Workers' template."
  echo ""
  read -p "Cloudflare API Token: " CF_API_TOKEN
fi

# --- Step 3: Install CLI and run setup ---

echo ""
echo "--- Step 3: Installing and running setup ---"
echo ""

echo "Installing Ghost Maintainer CLI..."
dart pub global activate --source git "https://github.com/$GHOST_REPO.git" --git-path notion_setup 2>&1 | tail -1

echo ""
ghost_maintainer setup \
  --notion-token "$NOTION_TOKEN" \
  --github-token "$GITHUB_TOKEN" \
  --gemini-key "$GEMINI_KEY" \
  --repo "$TARGET_REPO" \
  --notion-parent-page-id "$NOTION_PAGE_INPUT" \
  --source-repo "$GHOST_REPO" \
  $AUTO_FIX_FLAG

# --- Step 4: Deploy webhook ---

echo ""
ghost_maintainer deploy-webhook \
  --cf-account-id "$CF_ACCOUNT_ID" \
  --cf-api-token "$CF_API_TOKEN" \
  --source-repo "$GHOST_REPO"

# --- Step 5: Sync existing issues ---

echo ""
read -p "Sync existing open issues to Notion? (y/N): " SYNC_ISSUES
if [[ "$SYNC_ISSUES" =~ ^[Yy] ]]; then
  ghost_maintainer sync
fi

echo ""
echo "=== All done! ==="
echo ""
echo "Ghost Maintainer is active on $TARGET_REPO."
echo "Create a GitHub issue to test, or use the Fix/Implement buttons in Notion."
echo ""
echo "Commands:"
echo "  ghost_maintainer config          - view/change settings"
echo "  ghost_maintainer sync            - import existing issues"
echo "  ghost_maintainer deploy-webhook  - redeploy the webhook"
echo ""
