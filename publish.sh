#!/bin/bash
# publish.sh — Copy posts from Obsidian vault to Hugo repo and push
# Usage: ./publish.sh [commit message]

VAULT="/mnt/c/Users/YOU/obsidian-vaults/SITE/posts"
HUGO_POSTS="$HOME/ai/lab/hugo/artark-ai/content/posts"

# Sync posts from vault to Hugo (one-way: vault → repo)
rsync -av --delete --exclude='.obsidian' "$VAULT/" "$HUGO_POSTS/"

cd "$HOME/ai/lab/hugo/artark-ai"

# Show what changed
git status --short

# Build test
hugo --minify --quiet
if [ $? -ne 0 ]; then
    echo "ERROR: Hugo build failed. Fix the issue before publishing."
    exit 1
fi

# Commit and push
MSG="${1:-update blog posts}"
git add -A
git commit -m "$MSG"
git push origin main

echo "✓ Published. Site will be live in ~60 seconds."
