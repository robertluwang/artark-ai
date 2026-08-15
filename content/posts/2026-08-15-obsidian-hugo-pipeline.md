+++
date = '2026-08-15'
draft = false
title = 'Obsidian + Hugo + GitHub Pages on Windows 11'
tags = ['obsidian', 'hugo', 'github-pages', 'wsl']
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
cp ~/hugo-site/content/posts/*.md /mnt/c/Users/you/obsidian-vaults/my-blog/posts/
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

### Step 4: Create the Publish Script

Save this as `publish.sh` in your Hugo site root:

```bash
#!/bin/bash
# publish.sh — Sync posts from Obsidian vault to Hugo repo, build, push
# Usage: ./publish.sh [commit message]

VAULT="/mnt/c/Users/you/obsidian-vaults/my-blog/posts"
HUGO_POSTS="$HOME/hugo-site/content/posts"

# One-way sync: vault → repo
rsync -av --delete --exclude='.obsidian' "$VAULT/" "$HUGO_POSTS/"

cd "$HOME/hugo-site"

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

### Daily Workflow

**Write** — Open Obsidian, create a new note in `posts/`. Add Hugo front matter at the top:

```
+++
date = '2026-08-15'
draft = false
title = 'My Post Title'
tags = ['topic']
+++

Your content here...
```

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

### Why Not Obsidian Git Plugin?

The Obsidian Git community plugin can auto-commit and push on a timer. Sounds perfect, but:

1. You lose the Hugo build verification step — a broken front matter goes straight to production
2. Two git clients (Obsidian on Windows + terminal on WSL) hitting the same remote causes conflicts
3. Auto-commits every 5 minutes create noisy history
4. The plugin operates at vault root — your repo structure (themes, config, workflow) would clutter the Obsidian sidebar

Keeping git in WSL gives you control: preview before publish, meaningful commit messages, and one source of authority.

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
