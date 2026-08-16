+++
date = '2026-08-15'
draft = false
title = 'Obsidian + Hugo + GitHub Pages on Windows 11'
tags = ['obsidian', 'hugo', 'github-pages', 'wsl']

[params.cover]
  image = "banner.png"
  alt = "Obsidian + Hugo + GitHub Pages on Windows 11"
  relative = true
+++

Obsidian is a beautiful markdown editor. Hugo is a fast static site generator. GitHub Pages is free hosting with CI/CD. The challenge is wiring them together on Windows 11 where Obsidian runs natively but Hugo and git live in WSL.

Here is the setup that works.

### The Problem

Obsidian is a Windows desktop app. Hugo and git run in WSL (Ubuntu). They need to read and write the same markdown files. The obvious answers all fail:

| Approach | Problem |
|----------|---------|
| Obsidian vault at `\\wsl.localhost\...` | `EISDIR` error — Obsidian cannot watch WSL network paths |
| Windows junction (`mklink /J`) to WSL path | "Local volumes required" — junctions need local drives |
| Symlink from Hugo repo to Windows folder | GitHub Actions runner does not have your Windows path — CI breaks |
| Obsidian Git plugin pushing directly | Two git clients on same remote = merge conflicts |

### The Solution: Vault + Publish Script

Keep two copies: Obsidian writes to a Windows-native folder, a one-line publish script syncs to the Hugo repo and pushes.

```
Obsidian (Win11)                              WSL
┌─────────────────────────────┐              ┌──────────────────────────────┐
│ C:\Users\you\               │              │ ~/hugo-site/                 │
│   obsidian-vaults\          │  publish.sh  │   content/posts/             │
│     my-blog\                │ ──────────▶  │     (real files, in git)     │
│       posts\*.md            │   rsync      │                              │
└─────────────────────────────┘              └──────────────┬───────────────┘
                                                            │ git push
                                                            ▼
                                             GitHub Actions → Pages (live)
```

### Step 1: Create the Vault Folder

From WSL:

```bash
mkdir -p /mnt/c/Users/you/obsidian-vaults/my-blog/posts
```

Copy any existing posts into it:

```bash
cp -r ~/hugo-site/content/posts/* /mnt/c/Users/you/obsidian-vaults/my-blog/posts/
```

### Step 2: Open the Vault in Obsidian

In Obsidian on Windows → **Create new vault**:

- **Vault name:** `my-blog`
- **Location:** `C:\Users\you\obsidian-vaults`

You should see your `posts/` folder in the sidebar immediately.

### Step 3: Configure Obsidian

Under **Settings → Files & Links**:

- **New link format:** Relative path to file
- **Default location for new notes:** `posts/`
- **Use `[[Wikilinks]]`:** turn OFF
- **Default location for new attachments:** Same folder as current file

> **Tip:** Turning off Wikilinks makes Obsidian output `![](image.png)` instead of `![[image.png]]` — standard Markdown that Hugo understands. Setting attachments to "Same folder as current file" ensures images land inside the page bundle alongside `index.md`.

### Step 4: Create the Publish Script

Save this as `publish.sh` in your Hugo site root:

```bash
#!/bin/bash
# publish.sh — Sync posts between Obsidian vault and Hugo repo, build, push
# Usage: ./publish.sh [commit message]

VAULT="/mnt/c/Users/you/obsidian-vaults/my-blog/posts"
HUGO_POSTS="$HOME/hugo-site/content/posts"

cd "$HOME/hugo-site"

# Pull latest (in case iPhone pushed new posts)
git pull --rebase origin main

# Sync REPO → VAULT (so Obsidian sees iPhone posts)
rsync -av --delete --exclude='.obsidian' "$HUGO_POSTS/" "$VAULT/"

# Sync VAULT → REPO (pick up desktop Obsidian edits)
rsync -av --delete --exclude='.obsidian' "$VAULT/" "$HUGO_POSTS/"

# Show changes
git status --short

# Verify build
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
```

Make it executable:

```bash
chmod +x publish.sh
```

### Step 5: Add `.obsidian/` to `.gitignore`

Just in case Obsidian ever creates config files near the repo:

```text
/public/
/resources/
.hugo_build.lock
.obsidian/
```

### Step 5: Set Up Templater for New Posts

The **Templater** community plugin creates a complete page bundle (folder + `index.md` + front matter) in one action.

1. **Settings → Community plugins** → Turn off Restricted Mode
2. **Browse** → search **"Templater"** → Install → Enable
3. **Settings → Templater** → set **Template folder location:** `_templates`

The repo includes `_templates/new-post.md` which handles everything — prompts for title and tags, creates the folder, writes the front matter with cover image config, and opens the file for editing.

You can also use `_templates/hugo-post.md` to insert front matter into an existing note.

### Page Bundles and Images

Posts use Hugo **page bundles** — each post is a folder:

```
content/posts/2026-08-16-my-post/
├── index.md        ← your post
├── banner.png      ← cover image (shown on listing + post header)
└── diagram.png     ← inline image
```

- **Cover image:** the template pre-fills `[params.cover]` pointing to `banner.png`. Drop any image and name it `banner.png`.
- **Inline images:** paste or drag an image while editing — Obsidian saves it in the same folder. Reference with `![](filename.png)`.

This works on both desktop Obsidian and iPhone — same structure, same syntax.

### Daily Workflow

**Write** — Open command palette → **"Templater: Insert template"** → pick `new-post` → type title and tags. Templater creates the folder and `index.md` with front matter:

```
+++
date = '2026-08-15T17:00:03-04:00'
draft = false
title = 'My Post Title'
tags = ['hugo', 'tutorial']

[params.cover]
  image = "banner.png"
  alt = "My Post Title"
  relative = true
+++
```

Write your content. Paste images — they land in the same folder.

**CLI shortcut** — From WSL, you can also use the `new-post.sh` script:

```bash
./new-post.sh "My Post Title" "hugo,tutorial"
```

This creates the same page bundle structure without opening Obsidian.

**Preview** — In WSL, sync and preview before publishing:

```bash
rsync -av /mnt/c/Users/you/obsidian-vaults/my-blog/posts/ ~/hugo-site/content/posts/
hugo server -D
```

**Publish** — When satisfied:

```bash
./publish.sh "add post: my post title"
```

That is the entire process. Write in Obsidian, run one command, site is live.

### Why Not a Symlink?

It seems elegant — symlink `content/posts/` to the Windows vault folder and everything is one source of truth. It works locally. Hugo builds through it. But git stores the symlink target path literally:

```
content/posts -> /mnt/c/Users/you/obsidian-vaults/my-blog/posts
```

When GitHub Actions checks out the repo, that path does not exist on the Ubuntu runner. The build fails with missing content. Real files in the repo are the only way CI/CD works.

The `rsync` approach costs one extra command but keeps the pipeline reliable.

### Why Not Obsidian Git Plugin on Desktop?

The Obsidian Git plugin works great on iPhone (see the [iPhone pipeline post](/artark-ai/posts/2026-08-15-iphone-obsidian-git/)). But on desktop where you have WSL, the publish script is better because:

1. You get Hugo build verification before pushing — broken front matter never reaches production
2. Two git clients (Obsidian on Windows + terminal on WSL) hitting the same remote causes conflicts
3. Auto-commits every 5 minutes create noisy history
4. The plugin operates at vault root — your repo structure (themes, config, workflow) would clutter the Obsidian sidebar

On iPhone there is no alternative — Obsidian Git is the only way to push. On desktop, keep git in WSL for control.

### The Full Stack

```
Obsidian (Win11 desktop)     — write markdown
rsync (WSL)                  — sync to Hugo repo
Hugo (WSL)                   — build static HTML
Git (WSL)                    — push to GitHub
GitHub Actions (cloud)       — build + deploy
GitHub Pages (cloud)         — serve the site
```

No database. No CMS login. No block editor. No WordPress plugins. Just markdown files, a terminal, and a one-line publish command.
