#!/bin/bash
# new-post.sh — scaffold a Hugo post bundle on the laptop.
#
# The WSL equivalent of the Obsidian _templates/new-post.md template, so posts
# created on either device get identical front matter — including
# `relative = true`, without which og:image resolves against the site root and
# social cards render with no banner.
#
# Usage:
#   ./scripts/new-post.sh "My Post Title"
#   ./scripts/new-post.sh "My Post Title" --tags hugo,git --banner ~/Pictures/x.png
#   ./scripts/new-post.sh "My Post Title" --publish
#
# Posts are created as draft = true, so an unfinished post can be committed
# safely. Set draft = false (or use --publish) when it is ready to go live.
#
# Options:
#   --tags a,b,c     Comma-separated tags
#   --banner FILE    Copy FILE into the bundle as banner.png
#   --publish        Create with draft = false — goes live on the next push

set -euo pipefail

cd "$(cd "$(dirname "$0")/.." && pwd)"

TITLE=""
TAGS=""
BANNER=""
DRAFT="true"

while [ $# -gt 0 ]; do
    case "$1" in
        --tags)   TAGS="${2:?--tags needs a value}"; shift 2 ;;
        --banner) BANNER="${2:?--banner needs a path}"; shift 2 ;;
        --publish) DRAFT="false"; shift ;;
        --draft)   DRAFT="true";  shift ;;
        -h|--help)
            sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        -*) echo "ERROR: unknown option $1" >&2; exit 1 ;;
        *)
            if [ -z "$TITLE" ]; then TITLE="$1"; else
                echo "ERROR: unexpected argument '$1' (quote the title)" >&2; exit 1
            fi
            shift ;;
    esac
done

if [ -z "$TITLE" ]; then
    read -rp "Post title: " TITLE
    [ -n "$TITLE" ] || { echo "ERROR: title is required" >&2; exit 1; }
fi

# "My Post: Title!" -> "my-post-title"
SLUG=$(printf '%s' "$TITLE" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
[ -n "$SLUG" ] || { echo "ERROR: title produced an empty slug" >&2; exit 1; }

DIR="content/posts/$(date +%Y-%m-%d)-$SLUG"
if [ -e "$DIR" ]; then
    echo "ERROR: $DIR already exists." >&2
    exit 1
fi

# TOML array: hugo,git -> 'hugo', 'git'
TAG_LINE="tags = []"
if [ -n "$TAGS" ]; then
    quoted=$(printf '%s' "$TAGS" | awk -F, '{
        for (i = 1; i <= NF; i++) {
            gsub(/^[ \t]+|[ \t]+$/, "", $i)
            if ($i != "") { printf "%s'\''%s'\''", (n++ ? ", " : ""), $i }
        }
    }')
    [ -n "$quoted" ] && TAG_LINE="tags = [$quoted]"
fi

# TOML strings: a literal 'single-quoted' string cannot contain an apostrophe
# and has no escape for one, so fall back to a "basic" string in that case.
esc_basic() {
    local s=${1//\\/\\\\}   # backslash first
    printf '%s' "${s//\"/\\\"}"
}
if [[ "$TITLE" == *"'"* ]]; then
    TITLE_TOML="\"$(esc_basic "$TITLE")\""
else
    TITLE_TOML="'$TITLE'"
fi
ALT_TOML="\"$(esc_basic "$TITLE")\""

mkdir -p "$DIR"
cat > "$DIR/index.md" <<EOF
+++
date = '$(date +%Y-%m-%dT%H:%M:%S%:z)'
draft = $DRAFT
title = $TITLE_TOML
$TAG_LINE

[params.cover]
  image = "banner.png"
  alt = $ALT_TOML
  relative = true
+++

EOF

echo "✓ created $DIR/index.md"

if [ -n "$BANNER" ]; then
    if [ ! -f "$BANNER" ]; then
        echo "ERROR: banner '$BANNER' not found — post created without one." >&2
        exit 1
    fi
    cp "$BANNER" "$DIR/banner.png"
    echo "✓ copied banner  $DIR/banner.png"
else
    echo
    echo "NEXT: add a banner before publishing"
    echo "      cp /path/to/image.png $DIR/banner.png"
    echo "      1200x630 is the size social cards want."
    if [ "$DRAFT" = "false" ]; then
        echo
        echo "This post is draft = false, so ./scripts/check-posts.sh will fail"
        echo "until banner.png exists."
    fi
fi

echo
if [ "$DRAFT" = "true" ]; then
    echo
    echo "This post is draft = true — it will NOT appear on the live site."
    echo "Set draft = false in the front matter when it is ready."
fi

echo
echo "Write:    \$EDITOR $DIR/index.md"
echo "Preview:  hugo server -D   ->  http://localhost:1313/"
echo "Publish:  ./publish.sh \"new post - $SLUG\""
