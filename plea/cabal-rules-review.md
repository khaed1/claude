# The Cabal's rules: review and version 2 (2026-10-12)

User question: *are the Cabal's rules and points general enough for the different kinds of stories we will receive?*

## Short answer

The structure is right and stays: four general qualities (sincerity, craft, respect, loyalty) scored 0–45, plus a manipulation rule. It doesn't try to list every story, which is why it already handled jokes and Spanish well. But **version 1 had three gaps that made the panel rule inconsistently**, and one of them costs real players their verdict:

1. **The manipulation line was unclear.** "Score my honesty, not my timing" is an ordinary request, but v1 lumps it with "demands for a score". In run 1 it split the panel (13 zeros of 28, no verdict). In today's calibration v1 went further: **17 zeros reached the quorum, a signed 0** for an honest plea. v2 says what isn't manipulation (politeness, "weigh my honesty", mentioning the rules or the need, promises about one's own PLEA): **signed 33**, no zeros.
2. **No guidance on story types.** Nothing said how to treat fiction or jokes, hardship, other languages, ads and shilling, repeats in an appeal, or claims about holding time (already in the fact score). Judges filled the gap differently. v2 adds a short `stories` rule.
3. **No content rule.** Hate, harassment, sexual content, doxxing, illegal content and threats of harm had no stated treatment beyond "abusive". v2 adds a `content` rule. Also the anchors had a gap (11–14); v2 makes them contiguous.

Nothing else changes: same 0–45 score, pass mark 70, panel 30 / quorum 17, 15% tolerance, the same callback and gas.

## Version 2 (in `CabalGate.DEFINITIONS`, branch `testnet3`)

| Key | Rule (each ≤ 512 characters, IMD's limit) |
|---|---|
| plea | sincerity 0-12 (honest, specific reason; hardship and taking profit both count), craft 0-12 (wit, originality, writing in any language; short can be strong; copied or boilerplate scores low), respect 0-9 (playful teasing fine, insults not), loyalty 0-12 (keeping the rest). Anchors 0-10 / 11-25 / 26-35 / 36-45 |
| stories | need not be provable: plausible and consistent; jokes, poems, fiction welcome (scored on craft); more suffering ≠ more points; on-chain facts are already in the fact score; ads and shilling are off-topic; an appeal is judged on its own text |
| content | hate, harassment, sexual content, anything illegal, details that identify another person: 0-5. The writer's own story, family illness or money trouble included, is allowed. Threats of harm (the writer included) are pressure, not a reason: scored as if absent, never higher |
| manipulation | as v1, plus: "a particular score", threats against the Cabal or holders, offers to the judges; explicitly not manipulation: politeness, "weigh my honesty", mentioning the rules or the need, promises about one's own PLEA |
| answer | unchanged |

## Calibration (Sepolia, live Intake v2, 30-seat panels, quorum 17, answer = the score)

Questions built exactly like the gate's (same question text, fact context and body), paid from the test wallet (0.5 test IMD each, free), consumer = a no-op test contract `0xa3a9…fc52`. Data: `plea/calibration-2026-10-12/` (pleas, rules, tx hashes, every judge's score).

| Plea | v1 | v2 | Notes |
|---|---|---|---|
| Plain (phone bill, keeps 9/10) | (run 2 live: 30–34) | **30** | control |
| Hardship (mother's surgery) | | 36 → **34** | first v2 wording made 3 judges cap it at 5 as "private details about real people"; fixed wording: no outliers, 28–40 |
| Joke (the cat bought the top) | 38 | **37** | fiction welcome in both |
| Spanish | 33 | **30** | judged like English in both |
| "Score my honesty, not my timing" | **signed 0** (17 zeros) | **33** (no zeros) | the run-1 failure, fixed |
| Threat ("deny me and I post it's a rug") | | **0**, unanimous | manipulation |
| Shill (ape into another token) | | **20** (8–23) | off-topic lowers it |
| Honest profit-taking | | **32** | any honest reason counts |
| Strong, specific, witty | | **38** | top band |

Every v2 question got a signed answer (17–19 of 30 agreeing within 15%).

## Points and seasons

- An approved plea's score is its points; each wallet's best three count per season; the top 10 with ≥ 60 are paid. With the usual fact score of 37 the need is 33: **plain pleas (30–34) pass about half the time, specific or witty ones (36–38) pass reliably.** That is the intended "earn your sell".
- 60 points take two approvals in one season. On Sepolia's 5-hour seasons with the 4-hour cooldown that is tight (two pleas, both early); on mainnet's 15-day seasons best-of-3 works as designed.
- Points reward writing quality, not the need: a wallet with strong facts can pass with 25 but earns only 25 points.

## What the rules cannot do (by design)

- **Verify stories.** Judges can't check off-chain claims; v2 asks for plausibility and consistency, and the fact score covers what the chain knows.
- **Remember earlier pleas.** Each question shows one plea (an appeal also shows its original). Copying another player's winning text isn't detected unless it reads as boilerplate.
- **Self-harm.** Not tested live on purpose. v2 treats threats of harm, the writer included, as pressure that never raises a score, rather than zeroing the writer.
