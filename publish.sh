#!/bin/bash
# publish.sh — Sync posts between Obsidian vault and Hugo repo, build, push
# Usage: ./publish.sh [commit message]

VAULT="/mnt/c/Users/YOU/obsidian-vaults/SITE/posts"
HUGO_POSTS="$HOME/ai/lab/hugo/artark-ai/content/posts"

cd "$HOME/ai/lab/hugo/artark-ai"

# Pull latest (in case iPhone pushed new posts)
git pull --rebase origin main

# Sync REPO → VAULT (so Obsidian sees iPhone posts)
rsync -av --delete --exclude='.obsidian' "$HUGO_POSTS/" "$VAULT/"

# Sync VAULT → REPO (pick up desktop Obsidian edits)
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
