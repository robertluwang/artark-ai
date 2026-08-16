+++
date = '2026-08-15T18:17:00-04:00'
draft = false
title = 'Blog from iPhone with Obsidian Git'
tags = ['obsidian', 'hugo', 'github-pages', 'iphone']

[params.cover]
  image = "banner.png"
  alt = "Blog from iPhone with Obsidian Git"
  relative = true
+++

You can write and publish blog posts from your iPhone using Obsidian and the Obsidian Git community plugin. No computer needed — write a post on the train, push to GitHub, and your Hugo site updates automatically.

Here is the setup.

### What You Need

- iPhone with Obsidian installed (free from App Store)
- GitHub repo with Hugo + GitHub Actions pipeline already working
- GitHub Personal Access Token (fine-grained)

### Step 1: Generate a GitHub Token

1. Go to https://github.com/settings/tokens
2. **Generate new token → Fine-grained token**
   - **Token name:** `obsidian-iphone`
   - **Expiration:** 90 days (or longer)
   - **Repository access:** Only select repositories → pick your Hugo repo
3. Under **Permissions**, click **"+ Add permissions"**
   - Find **"Contents"** → set to **Read and write**
   - **Metadata** (Read-only) is auto-added
4. Generate token → copy it immediately

### Step 2: Create a Vault

Open Obsidian on iPhone → **Create new vault**:
- **Vault name:** anything (e.g. `my-blog`)
- **Storage:** On my device (NOT iCloud — Obsidian Git needs local storage)

### Step 3: Install and Configure Obsidian Git

1. **Settings → Community plugins** → Turn off Restricted Mode
2. **Browse** → search **"Git"** → Install → Enable
3. **Settings → Git** (under Community plugins):
   - **Authentication → Username:** your GitHub username
   - **Authentication → Password/Token:** paste the Personal Access Token
   - **Pull on startup:** On
   - **Push on commit-and-sync:** On
   - **Pull on commit-and-sync:** On
4. Leave everything else at default

### Step 4: Clone Your Repo

1. Open command palette (swipe down on the editor)
2. Run: **Obsidian Git: Clone an existing remote repo**
3. Enter URL: `https://github.com/yourusername/your-repo.git`
4. Leave "custom git directory path" empty
5. Wait for clone to complete

After cloning, you will see the full repo structure in Obsidian's file browser. Your posts live in `content/posts/`.

### Step 5: Install Templater Plugin

The Templater community plugin lets you create a new page bundle post (folder + `index.md` + front matter) in one tap.

1. **Settings → Community plugins → Browse** → search **"Templater"** → Install → Enable
2. **Settings → Templater** → set **Template folder location:** `_templates`
3. (Optional) Under **Template Hotkeys**, add `new-post` — this puts a one-tap icon in the sidebar ribbon

The repo already includes `_templates/new-post.md` which handles everything automatically.

### Step 6: Configure Image Attachments

So that images you paste or attach land next to the post (inside the page bundle folder):

1. **Settings → Files and links**
2. **Use `[[Wikilinks]]`** → turn OFF (outputs standard `![](image.png)` syntax)
3. **Default location for new attachments** → **"Same folder as current file"**

### Writing and Publishing

**Write a new post:**

1. Open Obsidian → it auto-pulls the latest from GitHub
2. Open command palette (swipe down) → **"Templater: Insert template"** → pick `new-post`
3. Type your post title when prompted → type tags (comma-separated, or leave empty)
4. Templater creates the page bundle folder + `index.md` and opens it
5. Write your post. Paste or attach images — they land in the same folder automatically.

**Publish:**

1. Open command palette (swipe down)
2. Run: **Obsidian Git: Commit-and-sync**
3. Enter a commit message

Your site rebuilds via GitHub Actions and is live in about 60 seconds.

### Adding Images

Posts use Hugo **page bundles** — each post is a folder containing `index.md` plus any images:

```
content/posts/2026-08-16-my-post/
├── index.md
├── banner.png      ← cover image (shown on listing + post header)
└── screenshot.png  ← inline image
```

- **Cover image:** the `new-post` template pre-fills `[params.cover]` pointing to `banner.png`. Drop or paste a banner image and name it `banner.png`.
- **Inline images:** paste any image while editing — Obsidian inserts `![](filename.png)` and saves the file in the same folder. Hugo picks it up automatically.

### Pulling Updates from Desktop

If you wrote posts on your desktop since last opening Obsidian on iPhone, the plugin auto-pulls when you open the app. You can also manually pull:

- Command palette → **Obsidian Git: Pull**

### Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `403` on push | Token missing Contents: Read and write permission | Regenerate token with correct permissions |
| `Push rejected: not a fast-forward` | Desktop force-pushed or history diverged | Delete vault, re-clone fresh |
| `Merges with conflicts not supported` | Same file edited on two devices | Delete vault, re-clone, re-do your edit |
| Templater shows raw `<%` code | Templater plugin not enabled | Settings → Community plugins → enable Templater |
| Image shows as broken link | Wikilinks still on, outputs `![[img]]` | Settings → Files and links → turn off Wikilinks |
| Image not in post folder | Attachment location wrong | Set "Default location for new attachments" to "Same folder as current file" |

### Conflict Prevention

- Always let Obsidian pull on open before editing
- Do not edit the same post on phone and desktop at the same time
- If conflicts happen: easiest fix is delete the vault and re-clone

### Limitations

| Limitation | Workaround |
|-----------|------------|
| No Hugo preview on phone | Trust your markdown, or check the live site after push |
| Full repo visible (config, themes) | Ignore them, only work in `content/posts/` |
| HTTPS only (no SSH) | Use Personal Access Token |
| Token expires | Regenerate on GitHub, update in plugin settings |
| Slow clone on large repos | Only happens once — incremental pulls are fast |
| Large images slow to push | Keep images under 1MB, use .jpg/.webp for photos |

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
