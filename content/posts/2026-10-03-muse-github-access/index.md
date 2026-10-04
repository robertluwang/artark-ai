+++
date = '2026-10-03T16:16:56-04:00'
draft = true
title = 'Git Access for Muse, Scoped to Two Repos'
tags = ['github', 'git', 'muse', 'security']

[params.cover]
  image = "banner.png"
  alt = "Git Access for Muse, Scoped to Two Repos"
  relative = true
+++

Saturday afternoon, on my phone, I asked Muse a short question: is GitHub access ready? The honest answer was no, and it was no in three different ways at once. The SSH key existed. The git config existed. Nothing could actually log in. What followed took about an hour, most of it spent removing access I had just granted, and I ended up in a better place than the one I had planned.

This post is the full record, with the real commands, because I will have to redo parts of it in a year when the token expires.

## SSH was dead before we started

Back in September I had installed my own RSA key on the Muse VM at `~/.ssh/dc-key`, permissions 600, with a host entry in `~/.ssh/config` pointing github.com at it. On paper the setup looked finished. In practice:

```bash
ssh -T git@github.com
# kex_exchange_identification: read: Connection reset by peer
# Connection reset by 198.19.0.1 port 3128
```

Every outbound SSH connection from that VM goes through a proxy, and the proxy resets SSH on sight. Port 443 to ssh.github.com died the same way. The key was never the problem and never got a chance to be the solution. HTTPS, on the other hand, worked fine: github.com returned 200 and a public `git ls-remote` went through on the first try. So the path was always going to be HTTPS. I just had to accept it and move on.

## The device flow, twice

The GitHub CLI was already installed (gh 2.102.0, git 2.43.0), so Muse started the web device flow:

```bash
gh auth login --hostname github.com --git-protocol https \
  --web --skip-ssh-key --scopes repo,read:org,gist
```

GitHub answers with a one-time code. You open github.com/login/device on any browser where you are signed in, type the code, and approve. The CLI polls in the background and stores the token when you finish.

The first code died quietly. The VM had rebooted in between, which killed the polling process; when I asked Muse to check, uptime said 12 minutes and there was no login process left to receive anything. The second code worked within a couple of minutes. Lesson recorded for next time: a device code is a live process, not a message you can answer later.

The login landed as account `robertluwang`, protocol HTTPS, and `gh auth setup-git` wired gh in as the git credential helper. A private repo answered `git ls-remote` over HTTPS on the first try. Access was ready. It was also much wider than I wanted.

## An account-wide token feels wrong

The token from the CLI flow is an OAuth token, prefix `gho_`. Its scopes were `repo, read:org, gist, workflow`, and `repo` on this kind of token covers every repository the account can reach. For me that is 66 repos, 15 of them private. The token has no expiry date either. GitHub retires it after a full year of disuse, or when someone revokes it, and that is the whole safety model.

I asked Muse whether a token could cover one repo only. OAuth tokens and classic personal access tokens cannot be narrowed that way. Fine-grained personal access tokens can. That feature has existed for a while and I had simply never had a reason sharp enough to use it.

## A token for two repos

I only need Muse working in two repos right now: `life`, the blog you may know from my other posts, and `artark-ai`, where the raw posts for this site live. So I created a second token, named `muse-vm-life-artark`, at github.com/settings/personal-access-tokens/new:

1. Repository access: Only select repositories, then `life` and `artark-ai`.
2. Contents: Read and write. This covers clone, fetch, and push.
3. Pull requests: Read and write.
4. Workflows: Read and write. Both repos carry GitHub Actions under `.github/workflows`, and pushes that touch workflow files get rejected without this permission.
5. Expiration: one year, the maximum GitHub allows for this token type.

I already had an older fine-grained token for another app covering the same two repos. Reusing it would have worked and would also have tangled two tools together: revoke one and the other breaks, and the usage log cannot tell them apart. GitHub only displays a token value once at creation anyway, so the old one was not even retrievable. A fresh token cost three minutes.

The new token went into a secure vault page Muse opened for me. I pasted it there, never in the chat. Muse works with a placeholder value that gets exchanged for the real token when a request leaves the machine, so the token itself has never been written to a file on the VM, a config, or this conversation.

## Checking what the token can actually see

Trust comes after a test. Muse ran a small check against the API with only the new token attached: who am I, what does this repo look like, what does that one look like. `life` answered 200 with push permission. `artark-ai` answered 200 as well, push included.

The negative test mattered as much as the positive ones. The check also tried a private repo of mine that sits outside the selection, and GitHub answered a flat 404, the same response it gives for a repo that does not exist. To this token, an unselected private repo and a nonexistent one look identical. That sameness is the whole point of scoping it.

## Wiring the token in, and where it stops

The rule was that the raw value stays out of `~/.git-credentials`, out of the repo config, and off this machine's disk in general. The vault mechanism honors it with a placeholder. Scripts on this VM carry the placeholder, and the placeholder gets exchanged for the real token when a request leaves the machine, provided the request carries it in a Bearer header. Every API call in the checks above rides on that exchange. The token is used constantly and handled never.

Git speaks a different dialect. Over HTTPS it presents credentials as Basic auth, and the exchange leaves Basic headers alone. So the vault token has no authenticated path into git itself: no credential helper can fix that, because the helper can only hand git the placeholder, and GitHub reads the placeholder as a bad password. The clones live with that limit. They were pulled over plain HTTPS, which public repos allow anonymously, and any authenticated write from this VM goes through the API instead of git. The receipt for that sits near the end of this post, dated the morning after the rest of it.

## Logging the big token out

With the small token proven, the account-wide one had no job left. Removing it took one command:

```bash
gh auth logout --hostname github.com
```

The stored hosts file is now an empty `{}`, and `~/.gitconfig` holds nothing but my name and email. A test fetch against a private repo outside the PAT's scope now fails with `could not read Username`, which is the correct sound for this machine to make.

Two clones live at `/home/hatch/pdata/github/`, pulled during the same session: `life` at 30 tracked files and `artark-ai` at 35. Halfway through the work a scheduled vault-backup commit landed in `artark-ai` at 16:10, so the clone is newer than the token check that preceded it. These repos have their own automation running, and now this VM can join it with a key that opens two doors instead of sixty-six.

## The first push failed

Sunday morning I committed this post locally and pushed:

```bash
git push origin main
# remote: Invalid username or token. Password authentication is not
# supported for Git operations.
# fatal: Authentication failed for 'https://github.com/robertluwang/artark-ai.git/'
```

During Saturday's setup I had wired a small credential helper into both clones, a short Python script that answers git with the placeholder, and the reads had all come back green: `ls-remote` returned both HEADs, a fetch completed, and the setup went into my notes as verified. The green was hollow. Both repos are public, so those reads never carried a credential in the first place, and the placeholder never met GitHub until the push, the first request that actually needed it. GitHub took one look at a string that means nothing to it and rejected it as a bad password. The token had been valid the whole time, sitting in the vault, waiting on a pipe that was never connected.

The commit went up through the Git Data API instead: upload the markdown and the banner as blobs, build a tree on top of the current one, create the commit, move `main` to it. Four calls, each carrying the placeholder in a Bearer header, each exchanged on the way out. Commit `7e635a7`, the one that carried this post to GitHub, was made exactly that way, and the local clone reset to meet it, with the same tree hash on both sides. The credential helper came out of both clones the same morning. A helper that stays silent until the moment it matters is worse than no helper at all.

One loose end stays on my list. Logout is local; GitHub still shows the CLI authorization under Settings, Applications, and revoking it there kills CLI tokens on every device I own. That click can wait for a moment when I am sitting at my laptop. The token on this VM expires next October, and rotation is a five-minute job: mint a new one, paste it into the vault page, run the check. I can live with that schedule.

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/robertluwang)
