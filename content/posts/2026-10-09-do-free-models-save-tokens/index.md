+++
date = '2026-10-09T12:52:35-04:00'
draft = true
title = 'Counting the Tokens: What a Free-Model Setup Actually Saved Me'
tags = ['pi', 'openrouter', 'llm', 'muse', 'tokens']

[params.cover]
  image = "banner.png"
  alt = "Counting the Tokens: What a Free-Model Setup Actually Saved Me"
  relative = true
+++

A post has been making the rounds on X for a while now. The pitch is simple and very shareable: point your coding agent at OpenRouter's free flagship models, let the free models do the work, and stop burning your main agent's tokens. The Chinese posts about it use the word for getting a free ride, and the screenshots make it look like free money. This morning I built the whole setup for real, with my agent Muse doing the wiring. Then I did the part the pitch skips. I counted what it actually cost and what it actually saved.

## The setup, briefly

The short version: Muse installed the Pi coding agent (version 1.1.0) on my cloud VM, stored my OpenRouter key in a secure vault where Pi loads it through a placeholder that never touches disk, scanned OpenRouter's catalogue and found 19 free models, and pinned two verified ones as Pi's defaults. The default is NVIDIA Nemotron 3 Ultra at 550B parameters, the fallback is Nemotron 3 Super at 120B, and a daily scan at 08:00 watches the free list because models drop off it without notice. The full wiring, with commands and settings, is in [the previous post](https://robertluwang.github.io/artark-ai/posts/2026-10-09-pi-openrouter-free-models/). Everything in this post is about the bill.

## Test one: small jobs with cheap supervision

First, two small tasks, the same for both free models, with the results checked independently afterwards.

A reasoning problem in Chinese, three legs of a car trip, correct answer 270 km and 56.84 km/h. Ultra got it right in 24 seconds. Super got it right in 5 seconds.

A small Python project with a real bug in a discount function and one failing unit test. Each model had to read the files, fix the source, and run the tests itself. Both fixed it. Ultra took 52 seconds, Super took 13. My supervision cost on this one was close to zero, because the test suite is the referee. I re-ran the tests, they passed, done. Jobs shaped like this are where the scheme shines, and my rough estimate is that the bug fix saved half to two thirds of what the task would have cost in Muse tokens, because Pi did the reading, editing, and iterating inside its own context and I only paid for the brief and the final check.

## Test two: one real article, counted honestly

Then came the expensive experiment. The previous post on this blog was drafted by Pi itself. Muse wrote a brief with every verified fact and a set of style rules. Pi's Ultra model read the brief and produced a 1,206-word draft in 263 seconds. Muse then read the draft, fact-checked it line by line, and edited it into the published 1,148 words.

Afterwards I counted the Muse tokens on both sides of the road, using the real files, roughly four characters to a token, rounded.

If Muse had written the article alone, the writing itself comes to about 2,000 tokens of output, draft plus self-revision.

With Pi in the loop, the actual spend was:

- The brief Muse wrote for Pi: about 1,750 tokens out
- Reading Pi's draft back into Muse's context: about 1,950 tokens in
- The edited final text, which Muse output again almost in full: about 1,850 tokens out

Total, roughly 5,500 tokens. The free model did not save 2,000 tokens of writing. It added about 3,500 tokens of supervision on top of them.

## Why the draft needed that much supervision

The draft read well. It also invented things, fluently and in the right places. It replaced my reasoning test with a different problem and still quoted my answer. It described the bug as an off-by-one error in a tiered discount calculation, when the real bug was a function subtracting the percentage number from the price. It wrote an auth command with a path that does not exist on my machine. It added a crontab line and a log file I never set up, and a sentence about having replaced the VM twice. Six inventions in 1,200 words, every one of them plausible, every one of them wrong.

That is structural, and it matters for the accounting. A fact-dense article is mostly facts the model cannot know, so it fills the gaps with facts it invents, and the only defence is reading every line against the record. The review cost comes with the genre. Generation is the cheap part of writing something true. Verification is the expensive part, and verification stays with the main agent.

## The arithmetic that decides it

The honest formula is one line: net saving equals the output you outsourced, minus the brief, minus the review. When the output can be checked mechanically, the review term collapses and the formula turns positive fast. Twenty documents that each need a summary is the clean case. The summaries are about 40,000 tokens of generation, all of it movable to Pi, against maybe 2,500 tokens of brief and spot-checking on Muse's side. When the output needs line-by-line human-grade checking, the review term eats the saving and then some, as the article test showed.

There are costs outside the token count too. The free Ultra model took 263 seconds to write its draft, which is slow enough to change how you work. Free models carry daily request limits and answer with 429 errors when you push them. And the free list itself moves: 19 models today, a daily scan exists precisely because that number and those names will not hold.

## Where the free models stay in my setup

The scheme is real. The probes recorded a cost of exactly zero, the models are genuinely flagship-sized, and Pi does useful work with them. What the viral version leaves out is that the saving is denominated in your main agent's tokens, and the exchange rate is set by how the task is shaped. Verifiable, batch-shaped, low-judgment work goes to Pi, and there it saves real money. Fact-dense writing stays home.

This post is the demonstration. Muse wrote it directly, no Pi draft, because the last experiment already told me what a Pi draft of this article would cost. The scan runs again tomorrow at 08:00, and the next folder of raw material that needs summarizing goes to Pi, where the arithmetic works.

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/robertluwang)
