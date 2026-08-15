+++
date = '2026-08-15T18:17:00-04:00'
draft = false
title = 'Blog from iPhone with Obsidian Git'
tags = ['obsidian', 'hugo', 'github-pages', 'iphone']
+++

You can write and publish blog posts from your iPhone using Obsidian and the Obsidian Git community plugin. No computer needed — write a post on the train, push to GitHub, and your Hugo site updates automatically.

Here is the setup.

### What You Need

- iPhone with Obsidian installed (free from App Store)
- GitHub repo with Hugo + GitHub Actions pipeline already working
- GitHub Personal Access Token

### Step 1: Generate a GitHub Token

1. Go to https://github.com/settings/tokens
2. **Generate new token → Fine-grained token**
   - **Token name:** `obsidian-iphone`
   - **Expiration:** 90 days (or longer)
   - **Repository access:** Only select repositories → pick your Hugo repo
   - **Permissions → Contents:** Read and write
3. Copy the token immediately — you will not see it again

### Step 2: Create a Vault

Open Obsidian on iPhone → **Create new vault**:
- **Vault name:** anything (e.g. `my-blog`)
- **Storage:** On my device (NOT iCloud — Obsidian Git needs local storage)

### Step 3: Install and Configure Obsidian Git

1. **Settings → Community plugins** → Turn off Restricted Mode
2. **Browse** → search **"Obsidian Git"** → Install → Enable
3. **Settings → Obsidian Git** (under Authentication):
   - **Username:** your GitHub username
   - **Password/Token:** paste the Personal Access Token

Leave other settings at defaults.

### Step 4: Clone Your Repo

1. Open command palette (swipe down on the editor)
2. Run: **Obsidian Git: Clone an existing remote repo**
3. Enter URL: `https://github.com/yourusername/your-repo.git`
4. Wait for clone to complete

After cloning, you will see the full repo structure in Obsidian's file browser. Your posts live in `content/posts/`.

### Step 5: Set Up Hugo Template

1. Create a folder `_templates/` at the vault root
2. Create a note `_templates/hugo-post` with this content:

```
+++
date = '{{date:YYYY-MM-DDTHH:mm:ssZ}}'
draft = false
title = ''
tags = []
+++

```

3. **Settings → Core plugins → Templates** → toggle On
4. **Settings → Templates** → set **Template folder location:** `_templates`

### Writing and Publishing

**Write a new post:**

1. Open Obsidian → it auto-pulls the latest from GitHub
2. Navigate to `content/posts/`
3. Create a new note (name it like `2026-08-15-my-topic`)
4. Tap the Templates icon in the ribbon (bottom-right) → select `hugo-post`
5. Date fills in automatically. Type your title and start writing.

**Publish:**

1. Open command palette (swipe down)
2. Run: **Obsidian Git: Commit-and-push**
3. Enter a commit message

Your site rebuilds via GitHub Actions and is live in about 60 seconds.

### Pulling Updates from Desktop

If you wrote posts on your desktop since last opening Obsidian on iPhone, the plugin auto-pulls when you open the app. You can also manually pull:

- Command palette → **Obsidian Git: Pull**

### Conflict Prevention

- Always let Obsidian pull on open before editing
- Do not edit the same post on phone and desktop at the same time
- If you do get a conflict, you will see `<<<<<<< HEAD` markers in the file — edit to resolve, then commit and push again

### Limitations

| Limitation | Workaround |
|-----------|------------|
| No Hugo preview on phone | Trust your markdown, or check the live site after push |
| Full repo visible (config, themes) | Ignore them, only work in `content/posts/` |
| HTTPS only (no SSH) | Use Personal Access Token |
| Token expires | Regenerate on GitHub, update in plugin settings |
| Slow clone on large repos | Only happens once — incremental pulls are fast |

### Security

- Use a **fine-grained token** limited to your blog repo only
- Token is stored locally in `.obsidian/` on your device
- Set a reasonable expiry (90 days) and rotate when it expires
- If you lose your phone, revoke the token immediately at GitHub → Settings → Tokens

### The Complete Multi-Device Pipeline

```
iPhone (Obsidian Git)          Desktop (Obsidian + publish.sh)
       │                                │
       ▼                                ▼
   git push (HTTPS)              git push (SSH)
       │                                │
       └──────────┬─────────────────────┘
                  ▼
         GitHub: artark-ai repo
         GitHub Actions → Hugo build
         GitHub Pages → live site
```

Write anywhere. Push from anywhere. One pipeline builds it all.
