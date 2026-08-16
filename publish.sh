#!/bin/bash
# publish.sh — Sync posts between Obsidian vault and Hugo repo, build, push
# Usage: ./publish.sh [commit message]
#
# Configure these environment variables (e.g. in ~/.bashrc):
#   OBSIDIAN_VAULT_POSTS - path to Obsidian vault posts folder
#   HUGO_SITE_DIR        - path to Hugo site root (optional, defaults to script's directory)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HUGO_SITE="${HUGO_SITE_DIR:-$SCRIPT_DIR}"
HUGO_POSTS="$HUGO_SITE/content/posts"
VAULT="${OBSIDIAN_VAULT_POSTS:?Set OBSIDIAN_VAULT_POSTS to your Obsidian vault posts folder}"

cd "$HUGO_SITE"

# Pull latest (in case another device pushed new posts)
git pull --rebase origin main

# Sync NEW files from repo → vault (posts from other devices)
rsync -av --ignore-existing "$HUGO_POSTS/" "$VAULT/"

# Sync VAULT → REPO (vault is the source of truth for local edits)
rsync -av --delete --exclude='.obsidian' "$VAULT/" "$HUGO_POSTS/"

# Show changes
git status --short

# Build test
hugo --minify --quiet
if [ $? -ne 0 ]; then
    echo "ERROR: Hugo build failed."
    exit 1
fi

# Commit and push
MSG="${1:-update blog posts}"
git add -A
if git diff --cached --quiet; then
    echo "Nothing to publish."
    exit 0
fi
git commit -m "$MSG"
git push origin main

echo "✓ Published. Site live in ~60 seconds."
