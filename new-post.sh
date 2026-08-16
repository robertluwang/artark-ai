#!/bin/bash
# new-post.sh — Create a new page bundle post with front matter
# Usage: ./new-post.sh "My Post Title" [tag1,tag2,tag3]

TITLE="${1:?Usage: ./new-post.sh \"My Post Title\" [tag1,tag2]}"
TAGS="${2:-}"

# Generate slug from title
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
DATE=$(date +%Y-%m-%d)
DATETIME=$(date +%Y-%m-%dT%H:%M:%S%:z)
FOLDER="content/posts/${DATE}-${SLUG}"

# Create page bundle
mkdir -p "$FOLDER"

# Format tags
if [ -n "$TAGS" ]; then
    TAG_ARRAY=$(echo "$TAGS" | sed "s/,/', '/g")
    TAG_LINE="tags = ['${TAG_ARRAY}']"
else
    TAG_LINE="tags = []"
fi

# Write index.md with front matter
cat > "$FOLDER/index.md" << EOF
+++
date = '${DATETIME}'
draft = false
title = '${TITLE}'
${TAG_LINE}

[params.cover]
  image = "banner.png"
  alt = "${TITLE}"
  relative = true
+++

EOF

echo "✓ Created: $FOLDER/index.md"
echo "  → Drop banner.png into: $FOLDER/"
echo "  → Edit: $FOLDER/index.md"
