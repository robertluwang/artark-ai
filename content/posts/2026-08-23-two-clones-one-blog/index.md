+++
date = '2026-08-23T09:58:00-04:00'
draft = false
title = 'Two Clones, One Blog: When a Sync Script Eats Your Post'
tags = ['hugo', 'wsl', 'git', 'obsidian']

[params.cover]
  image = "banner.jpg"
  alt = "Two Clones, One Blog: When a Sync Script Eats Your Post"
  relative = true
+++

My Hugo blog ran on an `rsync` script for a week without a complaint. Then it silently deleted a 20-line section from a post that was already live. No error, no merge conflict, nothing in `git status` to suggest anything had been reverted.

The script was not buggy. It was correct for the setup I designed it for — **one** writing device. The moment a second device appeared, it became a machine for quietly discarding edits.

This post is about that failure mode and the WSL-only tooling I replaced it with. If you write from a single machine, [the original pipeline](/artark-ai/posts/2026-08-15-obsidian-hugo-pipeline/) still works fine and this is a solution to a problem you do not have.

## The Setup That Worked

Obsidian is a Windows app. Hugo and git live in WSL. Obsidian cannot open a WSL path — `\\wsl.localhost\...` throws `EISDIR`, junctions demand local volumes — so I kept a Windows-native vault and synced it into the repo before publishing:

```bash
# repo → vault: bring in posts written elsewhere
rsync -av --ignore-existing "$HUGO_POSTS/" "$VAULT/"

# vault → repo: vault is the source of truth for local edits
rsync -av --delete --exclude='.obsidian' "$VAULT/" "$HUGO_POSTS/"
```

With one device this is airtight. The vault is where you write, the repo is what you publish, and the copy always flows the same direction.

## The Setup That Broke

Then I [added the iPhone](/artark-ai/posts/2026-08-15-iphone-obsidian-git/) with Obsidian Git, which clones the repo and pushes straight to GitHub. Now I had three copies of every post, and only two were under git:

| Copy | Kept current by |
|------|-----------------|
| iPhone vault | Obsidian Git — a real clone, commits and pushes |
| WSL Hugo repo | `git pull` |
| Windows vault | **only** the rsync above |

Look again at the two flags, because the bug lives in the gap between them.

`--ignore-existing` copies only files the vault does **not** already have. A brand-new post from the phone arrives fine. A **modified** post does not — the file exists on both sides, so rsync skips it and the vault keeps its stale copy.

`--delete` then makes that stale copy authoritative and overwrites the repo.

So this sequence loses work:

1. Edit an existing post on the iPhone. Obsidian Git commits and pushes.
2. On the laptop, `git pull`. The repo now has the new version. **The Windows vault does not** — nothing syncs into it outside the publish script.
3. Run the publish script. Pass one skips the file because the vault already has one. Pass two deletes the repo's version and restores the vault's.
4. The edit is gone, and the deletion is committed and pushed as if you meant it.

New posts survived because they did not exist in the vault, so `--ignore-existing` did copy them. Edits did not. That mix is what made the breakage look random rather than systematic.

The generalisation is worth keeping:

> **If a copy of your content is not a git clone, it will eventually overwrite one that is.**

`rsync` compares filenames and timestamps. It has no notion of ancestry, so it cannot distinguish "newer" from "correct." Git can, because it knows which version descends from which.

## How I Found It

Not from the sync at all — from a broken social card, which is its own [separate rabbit hole](/artark-ai/posts/2026-08-23-hugo-social-card/). While reconstructing what had been published when, I diffed a commit against its parent and found a hunk nobody had written:

```bash
$ git diff 83049e6 caacd89 -- content/posts/
 content/posts/2026-08-15-iphone-obsidian-git/index.md | 20 ----
```

Twenty deletions, zero insertions, in a post I had not touched that day. That is the signature of this bug: a commit that removes content while claiming to add a different post.

Two commands make it visible on demand:

```bash
# any commit that deleted lines from a post you didn't mean to touch
git log --stat --oneline -- content/posts/ | grep -B3 -- '-----'

# what a specific commit did to your posts
git diff <old>..<new> -- content/posts/
```

Nothing recovers content you never committed. Everything that reached a commit is recoverable — `git show <commit>:<path>` gave the section back verbatim.

## The Fix: Every Copy Is a Clone

Delete the mirror. Keep exactly two working copies, both clones of the same repo:

```
iPhone (Obsidian + Obsidian Git)          Laptop (WSL)
┌────────────────────────────┐            ┌────────────────────────────┐
│ vault = git clone          │            │ ~/hugo-site = git clone    │
│   content/posts/           │            │   content/posts/           │
└─────────────┬──────────────┘            └─────────────┬──────────────┘
              │ push/pull (HTTPS + PAT)                 │ push/pull (SSH)
              └──────────────────┬──────────────────────┘
                                 ▼
                    GitHub → Actions → Pages
```

Syncing is now `git pull` and `git push`. Edit the same post on both devices and you get a real merge conflict you can see and resolve, rather than a timestamp comparison silently picking a winner.

The trade-off is explicit: **no Obsidian on the laptop.** Obsidian on Windows still cannot open a WSL path, and that limitation is exactly what the mirror existed to work around. So on the laptop you write in an editor that already lives in WSL — vim, or VS Code through the WSL extension — and the phone keeps Obsidian.

If Obsidian on the desktop matters more to you than a WSL-native repo, invert it: clone the repo into a Windows folder and open that as your vault, running Obsidian Git on the desktop too. Either layout obeys the rule. What you must not keep is a copy that only a sync script maintains.

## WSL Tooling

Losing Obsidian on the laptop means losing Templater, which is what created page bundles with correct front matter. Two small scripts replace it.

### Scaffolding

`scripts/new-post.sh` builds the bundle so the front matter is never hand-typed:

```bash
./scripts/new-post.sh "My Post Title"
./scripts/new-post.sh "My Post Title" --tags hugo,wsl --banner ~/Pictures/x.png
./scripts/new-post.sh "My Post Title" --publish
```

It slugifies the title, creates `content/posts/YYYY-MM-DD-slug/`, writes the front matter, and optionally copies the banner in. Posts default to `draft = true`, so an unfinished one is safe to commit; `--publish` sets `draft = false`.

One detail worth stealing, because it fails as a build error rather than a typo. TOML has two string forms, and the single-quoted *literal* form cannot contain an apostrophe — there is no escape sequence for one. `title = 'Google's Spark'` is a parse error. So emit a literal string normally and switch to a double-quoted basic string when the title needs it:

```bash
if [[ "$TITLE" == *"'"* ]]; then
    TITLE_TOML="\"$(esc_basic "$TITLE")\""   # "Google's Spark"
else
    TITLE_TOML="'$TITLE'"                    # 'Plain Title'
fi
```

### Validation in CI, Not on the Laptop

`scripts/check-posts.sh` rejects front matter that builds cleanly but publishes wrongly — chiefly a cover image that is missing, or one lacking `relative = true`, which makes `og:image` resolve against the site root and 404 while the page itself looks perfect.

The important decision is where it runs:

```yaml
- name: Validate posts
  run: ./scripts/check-posts.sh
- name: Build
  run: hugo --minify --baseURL "https://yourname.github.io/your-repo/"
```

In GitHub Actions, not in a local hook. **Posts pushed from the phone never touch your laptop tooling.** A pre-push hook would only guard the machine least likely to make the mistake — the one where you have scripts, a terminal and a preview server. Put the gate where every device's commits must pass through, and it covers all of them.

Drafts are listed rather than silently skipped, because a post accidentally left at `draft = true` gives no other signal. It simply never appears, and you go looking for a broken pipeline instead of a one-word fix:

```
DRAFT  2026-08-23-half-written-post: draft = true — will NOT be published.
```

### Publishing

Plain git, and the pull is not optional:

```bash
git pull --rebase origin main
git add -A && git commit -m "new post - my post title" && git push origin main
```

Anything written on the phone is already on GitHub. Skip the pull and you earn a rejected non-fast-forward push — which is git protecting you, and precisely the protection `rsync` never offered. A thin `publish.sh` that pulls, runs the checks locally, builds and pushes is a convenience; the CI gate is what actually enforces anything.

## What I Would Tell Myself

Three things, in order of how much time each would have saved.

**Count your copies, and check each one has a `.git`.** Three copies with two clones is not "one extra backup," it is an unmanaged writer with authority over your content. That is the whole bug.

**Distrust `--delete` in any script you run habitually.** It converts a stale directory into an instruction to remove work. Combined with `--ignore-existing` in the other direction, it guarantees that edits are dropped while new files survive — the most confusing failure signature available.

**Put your safety checks where every device pushes through.** Local hooks protect the machine you were already careful on.

The pipeline is smaller now: no mirror, no rsync, no environment variable pointing at a Windows path. Two clones, git in between, and validation in CI.

## The Full Stack

```
new-post.sh (WSL)        — scaffold the page bundle
$EDITOR (WSL)            — write markdown
hugo server -D (WSL)     — preview, drafts included
git                      — the ONLY sync mechanism, both directions
GitHub Actions           — validate front matter, then build
GitHub Pages             — serve the site
```

No database. No CMS login. No block editor. And no unmanaged copy of your content waiting to overwrite the good one.
