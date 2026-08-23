+++
date = '2026-08-23T14:40:00-04:00'
draft = false
title = 'Hugo Blog Pipeline: From Markdown to Live Site in One Push'
tags = ['hugo', 'github-pages', 'git', 'open-source']

[params.cover]
  image = "banner.jpg"
  alt = "Hugo Blog Pipeline: From Markdown to Live Site in One Push"
  relative = true
+++

I open-sourced the tooling I use to run this blog. It is a set of scripts that sit on top of Hugo and GitHub Pages, handling the things Hugo does not: scaffolding posts correctly, validating front matter before deploy, fitting banner images for social cards, and keeping two devices in sync through git alone.

The repo is here: [github.com/robertluwang/hugo-blog-pipeline](https://github.com/robertluwang/hugo-blog-pipeline)

This post explains why it exists and how to set up a new blog from scratch using it.

## Why Not Just Hugo?

Hugo is excellent at one thing: turning markdown into a fast static site. But between writing a post and having it live with a working social card, there are several steps Hugo does not cover:

- **Front matter correctness.** PaperMod (and similar themes) silently emit a broken `og:image` if you forget `relative = true` in your cover config. The page looks fine; only social crawlers see the 404. `hugo build` cannot catch this — the HTML is valid, it just points somewhere empty.

- **Banner sizing.** Social platforms render cards near 1.91:1. An AI-generated 3:2 image gets centre-cropped by the platform, cutting whatever was at the top and bottom. A 2 MB PNG is re-fetched on every share.

- **Multi-device sync.** The moment you write from both a phone and a laptop, you need a sync mechanism that understands history, not just timestamps. I learned this the hard way — an `rsync` script silently deleted a section from a published post.

- **Draft safety.** Hugo's `draft = true` excludes a post from the build with no other signal. If you forget to flip it, you end up debugging a working pipeline while the post simply is not there.

These are not Hugo bugs. They are gaps between "Hugo builds a site" and "I have a reliable publishing pipeline." The scripts fill exactly those gaps.

## What the Pipeline Does

| Script | Purpose |
|--------|---------|
| `scripts/new-post.sh` | Scaffold a page bundle with correct front matter |
| `scripts/fit-banner.py` | Normalise banners to 1200×630, archive originals |
| `scripts/check-posts.sh` | CI gate — fail on broken og:image, warn on oversized banners |
| `publish.sh` | Pull, scan banners, validate, build, push |

Plus:
- `_templates/` — Obsidian Templater templates for iPhone
- `.github/workflows/hugo.yml` — GitHub Actions: validate → build → deploy

## Setting Up a New Blog

### Prerequisites

- Linux, macOS, or WSL
- Hugo ([install guide](https://gohugo.io/installation/))
- Python 3 + Pillow:
  ```bash
  python3 -m venv .venv
  source .venv/bin/activate
  pip install pillow
  ```
- A GitHub account

### Step 1: Create the Hugo Site

```bash
hugo new site my-blog
cd my-blog
git init
```

### Step 2: Add the Pipeline

**Option A — git clone (recommended):**

```bash
git clone https://github.com/robertluwang/hugo-blog-pipeline.git /tmp/hugo-blog-pipeline
cp -r /tmp/hugo-blog-pipeline/scripts .
cp -r /tmp/hugo-blog-pipeline/_templates .
cp -r /tmp/hugo-blog-pipeline/.github .
cp /tmp/hugo-blog-pipeline/publish.sh .
cp /tmp/hugo-blog-pipeline/.gitattributes .
cp /tmp/hugo-blog-pipeline/.gitignore .
cp /tmp/hugo-blog-pipeline/hugo.toml.example .
rm -rf /tmp/hugo-blog-pipeline
```

**Option B — one-liner (no clone needed):**

```bash
curl -sL https://github.com/robertluwang/hugo-blog-pipeline/archive/main.tar.gz \
  | tar xz --strip-components=1 --wildcards \
    '*/scripts/*' '*/.github/*' '*/publish.sh' '*/_templates/*' \
    '*/.gitattributes' '*/.gitignore' '*/hugo.toml.example'
```

Both drop in the scripts, CI workflow, templates, and config files. Nothing else — no sample posts, no theme.

### Step 3: Set Up Python Venv

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pillow
```

The venv is gitignored. `fit-banner.py` needs Pillow; without it, `new-post.sh --banner` falls back to a plain copy and `check-posts.sh` skips the dimension check.

### Step 4: Add a Theme

Any Hugo theme works. PaperMod is minimal and fast:

```bash
git submodule add https://github.com/adityatelange/hugo-PaperMod.git themes/papermod
```

### Step 5: Configure

```bash
cp hugo.toml.example hugo.toml
```

Edit `hugo.toml`:

```toml
baseURL = 'https://yourname.github.io/my-blog/'
title = 'My Blog'
theme = 'papermod'

[params]
  env = "production"
  title = "My Blog"
  description = "Your description"
  author = "yourname"
```

Also edit `.github/workflows/hugo.yml` — the `--baseURL` on the build line:

```yaml
run: hugo --minify --baseURL "https://yourname.github.io/my-blog/"
```

### Step 6: Create Your First Post

```bash
source .venv/bin/activate
./scripts/new-post.sh "My First Post" --slug first-post --publish
```

Add a banner:

```bash
./scripts/fit-banner.py ~/Downloads/banner-art.png content/posts/2026-08-23-first-post/banner.jpg
```

Preview:

```bash
hugo server -D
# → http://localhost:1313/
```

### Step 7: Push to GitHub

Create an empty repo on GitHub (no README, no .gitignore, no license — you already have them).

```bash
git add -A
git commit -m "initial blog setup"
git remote add origin git@github.com:yourname/my-blog.git
git push -u origin main
```

Go to **Settings → Pages → Source → GitHub Actions**. That is the only manual step on GitHub — everything else is automated.

Within a minute your site is live at `https://yourname.github.io/my-blog/`.

### Step 8 (Optional): Add the iPhone

If you also want to write from your phone:

1. Install Obsidian + the **Git** community plugin
2. Clone the same repo via HTTPS + a fine-grained Personal Access Token
3. Install the **Templater** plugin, set template folder to `_templates`
4. Create posts with the `new-post` template — it produces byte-identical front matter

Push from the phone lands on GitHub, CI validates and deploys. Next time you are at the laptop: `git pull`.

## Daily Workflow

**Laptop:**
```bash
./scripts/new-post.sh "New Post" --slug my-post --tags hugo,git --banner ~/img.png --publish
# write...
./publish.sh "new post - my post"
```

**iPhone:**
Templater → new-post → write → Commit and Sync.

**After phone posts, on the laptop:**
```bash
git pull --rebase origin main
./scripts/fit-banner.py --scan    # fits any oversized phone banners
```

## How the CI Gate Works

The workflow runs `scripts/check-posts.sh` before `hugo build`. It catches what Hugo cannot:

```
ERROR  my-post: cover "banner.jpg" declared but content/posts/my-post/banner.jpg is missing.
       og:image would 404 and the social card would show no banner.

ERROR  my-post: cover set but 'relative = true' missing from [params.cover].
       og:image would resolve against the site root, not the page bundle.
```

These fail the build and block deployment. Warnings (oversized banners, odd ratios) appear in the log but do not block:

```
WARN   my-post: cover is 1591KB (> 500KB) — slow for every scrape.
```

Posts from any device — phone or laptop — pass through the same gate. A local hook would only protect the machine you were already careful on.

## Banner Handling

`fit-banner.py` normalises any image to 1200×630:

- **Crops** when the source ratio is near the target (16:9 → 1.91:1, minimal loss)
- **Pads** when it is far off (3:2), using the border colour sampled from the image, so nothing is cut
- **Never upscales** — a 1024px source stays sharp at 1024×538
- **Archives the original** to `banners/originals/` (gitignored) before writing the fitted copy

AI-generated art cannot be regenerated identically, so the downscaled card image must not be the only copy.

For a batch fix after phone posts:

```bash
./scripts/fit-banner.py --scan --dry-run    # what needs adjusting
./scripts/fit-banner.py --scan              # archive + fit + rewrite front matter
```

## What You End Up With

```
my-blog/
├── .github/workflows/hugo.yml   # validate → build → deploy
├── .gitattributes               # LF enforcement
├── .gitignore
├── _templates/                  # Obsidian (iPhone)
├── content/posts/               # your posts (page bundles)
├── hugo.toml
├── publish.sh                   # one-command publish
├── scripts/
│   ├── check-posts.sh           # CI gate
│   ├── fit-banner.py            # banner normalisation
│   └── new-post.sh             # scaffolding
└── themes/papermod/             # or any theme
```

No database. No CMS. No block editor. Write markdown, push, site is live — with a CI gate that stops broken social cards before they reach the world.

The repo: [github.com/robertluwang/hugo-blog-pipeline](https://github.com/robertluwang/hugo-blog-pipeline)
