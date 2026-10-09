+++
date = '2026-10-09T11:20:29-04:00'
draft = false
title = 'Pi and OpenRouter Free Models, Wired Into Muse'
tags = ['pi', 'openrouter', 'llm', 'muse', 'agents']

[params.cover]
  image = "banner.jpg"
  alt = "Pi and OpenRouter Free Models, Wired Into Muse"
  relative = true
+++

This morning I sent Muse a short message from my phone, three jobs in one breath: install a skill collection I had found, install the Pi coding agent, and configure Pi to run on a free model. What I wanted was a free second pair of hands for the grunt work that piles up. The kind of work that is pure text, easy to verify, and does not need my browser sessions or my judgment calls. A coding agent that runs on zero-cost models would fit that slot, if I could find one that does not quietly fall back to paid endpoints.

## The skill that refuses to guess

I found a small open-source skill collection called min-skill, maintained by GitHub user limin112 under an MIT license. One skill in it, FreeToken-Bots, is built around a single hard rule: never fall back to a paid model automatically. On OpenRouter a model ID missing its `:free` suffix routes to the paid variant of the same model, so the skill's probe resolves every ID against its latest scan of verified-free models and refuses anything it cannot prove is free. That fail-closed design matched exactly what I needed. The skill does not assume good faith. It checks candidates against the live API, where a free model has to show zero price for both prompt and completion tokens.

## Installing Pi with a surviving home

Pi is an open-source terminal coding agent created by Mario Zechner and now maintained under Earendil Works. I installed it with:

```bash
npm install -g --prefix ~/.local @earendil-works/pi-coding-agent
```

This gave me `pi` version 1.1.0 in `~/.local/bin`. The `--prefix ~/.local` was deliberate. A global install under `/usr` would vanish when the cloud VM is replaced, while Pi's config directory `~/.pi/agent/` lives in the home directory and survives. Keeping the agent binary in `~/.local/bin` and the config in `~/.pi/agent/` means I only need to re-run the npm command after a fresh VM boots. Everything else, settings, auth, enabled models, comes back with the home directory.

## The key never touches disk

OpenRouter's free models still need an API key because free usage is rate-limited per key. I store that key in a secure vault, not in a file. Pi supports loading a key by running a command; the `key` field in `~/.pi/agent/auth.json` can start with `!`. A small helper script prints only a placeholder token, and the placeholder is exchanged for the real key on the way out, only for requests to openrouter.ai. The real key never touches disk. Running `pi auth check --provider openrouter` reports ready. The auth.json entry looks like this, with the helper living in the OpenRouter skill I keep for Muse:

```json
{
  "openrouter": {
    "type": "api_key",
    "key": "!/usr/bin/python3 /home/hatch/workspace/skills/openrouter/bin/openrouter_key.py"
  }
}
```

## Scanning for models that are actually free

FreeToken-Bots includes `radar.py`, a Python standard-library script that calls OpenRouter's public model list and filters for models whose prompt and completion prices are both zero. On 2026-10-09 it found 19 free models. The API does not report parameter counts, so a model's size has to be checked against the provider's own documentation before calling it flagship-class. I checked the leading candidates that way.

Two models passed that check:

- NVIDIA Nemotron 3 Ultra, 550B total parameters with 55B active, 1M token context, free ID `nvidia/nemotron-3-ultra-550b-a55b:free`
- Nemotron 3 Super, 120B total with 12B active, free ID `nvidia/nemotron-3-super-120b-a12b:free`

Both support tool calling. Pi's own model catalog lists both at price 0.

I wrote the Pi settings to `~/.pi/agent/settings.json`:

```json
{
  "defaultProvider": "openrouter",
  "defaultModel": "nvidia/nemotron-3-ultra-550b-a55b:free",
  "enabledModels": [
    "openrouter/nvidia/nemotron-3-ultra-550b-a55b:free",
    "openrouter/nvidia/nemotron-3-super-120b-a12b:free",
    "openrouter/openrouter/free"
  ]
}
```

The third entry, `openrouter/free`, is OpenRouter's own router that only routes to free models. It sits in the list as a selectable safety net: by construction it cannot pick a paid model.

## Daily scan because eligibility changes

Free eligibility changes without notice. A scheduled job runs `python3 scripts/radar.py scan` every day at 08:00 local time. It stays silent when nothing changed and reports if a default model stops being free. It never edits Pi's settings on its own. If a model ever drops off the free list, the settings change is a decision, and decisions stay with me and Muse.

## Two tests, same tasks, verified independently

I ran the same tasks on both models and re-verified the results independently rather than trusting the models' own reports.

Reasoning test: a Chinese word problem about a car trip, three legs at 60 km/h for 2.5 hours, 40 km/h for 1.5 hours, and 80 km/h for 45 minutes. The correct answer is 270 km total and 56.84 km/h average. Ultra produced the correct answer in 24 seconds. Super produced the correct answer in 5 seconds.

Coding test: a small Python project with a real bug in a `discount()` function and a unittest suite with one failing test. The function subtracted the percentage number itself from the price instead of taking that percent of the price. Each model had to read the files, fix only the source file, and run the tests itself. Both fixed it correctly and the re-run passed. Ultra took 52 seconds and summarized its fix in Chinese as asked. Super took 13 seconds but answered in English even though the prompt was in Chinese.

A separate probe verified tool calling directly against the API. The Ultra model emitted a correct function call, and the recorded cost was 0.

## Limits that shape the workflow

Both default models take text only, no image input. A few smaller free models do accept images, for example Google's Gemma 4 free variants. No free model on the list generates images, and none generates video. Free models have daily request limits and can return 429 rate-limit errors. Ultra is noticeably slow, and the test times above are typical of what I saw all morning.

## The working arrangement

Pi on free models takes grunt work, meaning batch text jobs, first drafts, and tasks whose results can be checked mechanically. Muse keeps the work that needs my accounts, my browser sessions, my files and memory, and judgment calls. This post is the first real example of the split. The drafting went to Pi. The brief, the fact-checking, and the final edit stayed with Muse.

## Disclosure

The first draft of this very post was written by Pi running the free Ultra model, working from a brief Muse prepared, and Muse then fact-checked and edited it. The draft needed real corrections: it invented a different reasoning problem, described the coding bug wrong, and made up a crontab entry and a log file that do not exist in my setup. All of that came out in the edit. You are reading the edited version.

The draft also took Ultra 263 seconds to write, close to four and a half minutes for 1,200 words. That is the honest price of free. The daily scan runs again tomorrow at 08:00.

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/robertluwang)
