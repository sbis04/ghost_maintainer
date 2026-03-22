#!/bin/bash
set -e

# Ghost Maintainer - One-command installer
# Run from inside your GitHub repo:
#   curl -sL https://raw.githubusercontent.com/sbis04/ghost-maintainer/main/install.sh | bash

GHOST_REPO="sbis04/ghost-maintainer"

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

# Collect tokens
read -p "Notion Integration Token (ntn_...): " NOTION_TOKEN
if [ -z "$NOTION_TOKEN" ]; then
  echo ""
  echo "  Get one at: https://www.notion.so/profile/integrations"
  echo "  Create an internal integration with read/write permissions."
  echo ""
  read -p "Notion Integration Token: " NOTION_TOKEN
fi

read -p "Notion Page URL (paste the full link to your empty Ghost Maintainer page): " NOTION_PAGE_INPUT
if [ -z "$NOTION_PAGE_INPUT" ]; then
  echo ""
  echo "  1. Create an EMPTY page in Notion called 'Ghost Maintainer'"
  echo "     (don't add any content — the setup will populate it)"
  echo "  2. Connect your integration (... menu > Connections)"
  echo "  3. Copy the page URL (Share > Copy link)"
  echo ""
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

echo ""
echo "Ghost Maintainer CLI is now globally installed."
echo "Run 'ghost_maintainer config' to view or change settings."
echo ""
