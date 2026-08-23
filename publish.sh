#!/bin/bash
# publish.sh — optional convenience wrapper: validate, build, commit, push.
#
# Entirely optional. Plain git does the same job:
#   git pull --rebase origin main
#   git add -A && git commit -m "msg" && git push origin main
#
# The value here is fast local feedback: it runs the same checks CI runs, so a
# broken cover is caught before you push instead of failing the pipeline.
# The authoritative gate is scripts/check-posts.sh in .github/workflows/hugo.yml,
# which also covers posts pushed from a phone that never runs this script.
#
# Usage: ./publish.sh [commit message]

set -euo pipefail

cd "$(cd "$(dirname "$0")" && pwd)"

HUGO="${HUGO_BIN:-$(command -v hugo || echo ../hugo)}"

echo "==> Pulling latest from origin"
if ! git pull --rebase origin main; then
    echo >&2
    echo "ERROR: pull/rebase failed — resolve the conflict, then re-run." >&2
    echo "       git status ; git rebase --continue   (or: git rebase --abort)" >&2
    exit 1
fi

echo "==> Validating posts"
./scripts/check-posts.sh

echo "==> Building"
if ! "$HUGO" --minify --quiet; then
    echo "ERROR: Hugo build failed. Nothing was committed." >&2
    exit 1
fi

git add -A
if git diff --cached --quiet; then
    echo "Nothing to publish."
    exit 0
fi

echo "==> Changes to publish"
git diff --cached --stat | cat

git commit -m "${1:-update blog posts}"
git push origin main

echo "✓ Published. Site live in ~60 seconds."
