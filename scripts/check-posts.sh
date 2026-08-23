#!/bin/bash
# check-posts.sh — validate post front matter before the site is built.
#
# Catches failures that `hugo build` does NOT catch, because they produce
# valid HTML pointing at the wrong place:
#
#   1. A cover declared in front matter whose image file is missing
#      -> og:image / twitter:image 404 and social cards render with no banner.
#   2. A page-bundle cover without `relative = true`
#      -> PaperMod resolves the image against the SITE ROOT instead of the
#         page bundle, so og:image 404s while the page itself looks fine.
#
# Runs in CI so it protects posts pushed from any device, including phones
# that commit straight to GitHub. Also runnable by hand from anywhere.
#
# Exit 0 = clean, 1 = problems found.

set -uo pipefail

cd "$(cd "$(dirname "$0")/.." && pwd)"

NOW=$(date +%s)
problems=0
warnings=0
checked=0

# Front matter = everything above the closing +++ (TOML) or --- (YAML).
frontmatter() {
    awk 'NR==1 && /^(\+\+\+|---)[[:space:]]*$/ {d=substr($0,1,3); next}
         d && $0 ~ "^" (d=="+++" ? "\\+\\+\\+" : "---") "[[:space:]]*$" {exit}
         d {print}' "$1"
}

for post in content/posts/*/index.md; do
    [ -e "$post" ] || continue
    dir=$(dirname "$post")
    slug=$(basename "$dir")
    checked=$((checked + 1))

    fm=$(frontmatter "$post")

    cover=$(printf '%s\n' "$fm" | grep -oP '^\s*image\s*=\s*"\K[^"]+' | head -1)

    if [ -n "$cover" ]; then
        case "$cover" in
            http://*|https://*)
                # External cover: nothing local to verify.
                ;;
            *)
                if [ ! -f "$dir/$cover" ]; then
                    echo "ERROR  $slug: cover \"$cover\" declared but $dir/$cover is missing."
                    echo "       og:image would 404 and the social card would show no banner."
                    echo "       Fix: add the image, or remove the [params.cover] block."
                    problems=$((problems + 1))
                fi
                if ! printf '%s\n' "$fm" | grep -qP '^\s*relative\s*=\s*true'; then
                    echo "ERROR  $slug: cover set but 'relative = true' missing from [params.cover]."
                    echo "       og:image would resolve against the site root, not the page bundle."
                    echo "       Fix: add 'relative = true' under [params.cover]."
                    problems=$((problems + 1))
                fi
                ;;
        esac
    fi

    # Future-dated posts are excluded from the build. Legitimate for
    # scheduling, so warn rather than fail.
    pdate=$(printf '%s\n' "$fm" | grep -oP "^\s*date\s*=\s*['\"]\K[^'\"]+" | head -1)
    if [ -n "$pdate" ]; then
        if ts=$(date -d "$pdate" +%s 2>/dev/null); then
            if [ "$ts" -gt "$NOW" ]; then
                echo "WARN   $slug: dated in the future ($pdate) — Hugo will skip it."
                warnings=$((warnings + 1))
            fi
        fi
    fi
done

# Non-bundle posts can't use relative covers; flag them so they aren't
# silently validated by the bundle rules above.
for post in content/posts/*.md; do
    [ -e "$post" ] || continue
    [ "$(basename "$post")" = "_index.md" ] && continue
    if frontmatter "$post" | grep -qP '^\s*image\s*=\s*"'; then
        echo "WARN   $(basename "$post"): cover on a non-bundle post — verify og:image by hand."
        warnings=$((warnings + 1))
    fi
done

echo
echo "Checked $checked post(s): $problems error(s), $warnings warning(s)."

if [ "$problems" -gt 0 ]; then
    echo "FAILED — fix the errors above before publishing."
    exit 1
fi

echo "PASSED"
