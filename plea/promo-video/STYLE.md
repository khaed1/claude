# PLEA promo video: style guide

The reference is our own design system (`plea/site-design/`: `tokens.css`, `components.css`, the page mockups and `shots/`) and the X brand v2 (`plea/brand/v2/`). The video page loads the site's real CSS, so cards, stamps, pills and the urgent box are the site's own components. The user's picks (2026-10-26): a court with a wink, text and music only (no narrator), a royalty-free track, the site's look.

## Frame
- 16:9 at 1920 × 1080 and 9:16 at 1080 × 1920, both laid out from one timeline (a layout function per format, never a crop). 60 fps for the final render, 30 fps for drafts.
- Safe area: 96 px from every edge at 1920 wide (X's player overlays the bottom 10%).
- Scale: the site is drawn for 1280 px, so components are scaled ×1.5 in 16:9 (borders 3 → 4.5 px, hard shadows 4–6 → 6–9 px).

## Colour (from `tokens.css`, no others)
- Ground: paper `#FBF6EA`, sunken `#F3EDDD`, card `#FFFFFF`; ink `#121212`, secondary `#4A463E`.
- Action (the one "do this" colour, never a state): yellow `#FFD92E`.
- Verdict fills, always with ink text and the state in words: approved `#4BE08F`, denied `#FF5A4E`, pending stripes `#FFC247` / `#FFE08A`, sold `#6FA8FF`, objection `#C8A6FF`, no verdict `#C9C3B6`, lapsed = a dashed outline.
- Dark (the dead-man scene and the end card): paper `#17150F`, card `#26221A`, ink `#F5F0E4`; the end card is brand v2 B, the yellow PLEA stamp on ink `#121212`.

## Type
- Display: Archivo at width 125, weight 800 (headlines, captions, stamps). UI: Archivo 400–600. Numbers, plea numbers, countdowns, "35 vs need 35", addresses: IBM Plex Mono 600. All SIL OFL 1.1.
- Captions: at least 64 px at 1920 wide (readable at 360 px on a phone), at most about 7 words a line, left-aligned like a docket, never centred on an empty ground. A caption sits on paper or on an ink label, never loose over busy UI.

## Shapes
- 3 px ink outlines (×1.5 on screen), radius 12 on cards, 8 on buttons and inputs, 4 on stamps and badges.
- Hard offset shadows with no blur, only on cards, buttons and the stamp.
- The stamp: ink outline, tilted −3°, the state in capitals, "N vs need N" in mono under it.

## Motion
- Every value is a closed-form spring and a pure function of time (`window.seek(t)`); no CSS transitions, timers or `Math.random` (seeded noise only).
- Springs: snappy (stiffness 320, damping 30) for buttons, pills and the cursor; default (170 / 26) for cards and panels; heavy (120 / 22) for big type, the stamp and camera moves. A hair of overshoot on UI, none on type.
- Things enter by dropping, sliding or being typed, never by fading alone. Something new happens every 1–2 bars.
- The stamp lands on a downbeat: scale 1.6 → 1 on the heavy spring, the tilt settles to −3°, the shadow appears on impact, a 2-frame camera jolt (±6 px). It is the film's signature move.
- "One shape never cuts" through the plea's life (shots 2–7): the text box becomes the plea card, the card folds into an envelope, waits in the docket, is judged, is stamped, opens the sell window, and becomes SOLD.
- Cuts are hard and fall on downbeats; a moving card may wipe one scene into the next.
- Site captures get a slow push-in (scale 1.00 → 1.04 over the shot) or a spring scroll, never a static hold longer than 2 bars.

## Sound
- Music: "The Builder" by Kevin MacLeod (incompetech.com), CC BY 4.0, cut to 78.37 s by `tools/make_music.sh` (one quiet bar, the band at 1.98 s, break 1 at 27.6–33.4 s, break 3 at 57.4–64.7 s, the hard stop at 76.38 s), −14 LUFS. Beat grid in `data/beats-16x9.json` (122.4 BPM, 0.49 s a beat, 1.956 s a bar).
- Sound effects synthesized in code, placed on beats: key clicks (typing, on 16ths), a paper fold and a whoosh (the plea is sent), seat ticks (judges answering), the stamp thud (low sine sweep with a short noise burst), a countdown tick, the OBJECTION slam, a clock rattle. Effects sit about 6 dB under the music, except the stamp thud in the two silences.

## Truth rules
- Real UI only: the site's own components and real captures of the run 9 site (https://plea-test-run-9.sites.imd.fun/), never an invented screen and never a fake Etherscan.
- Real data only: run 9's pleas, panels, scores and transactions (`data/panels.json`, `plea/live-run9/`), or the agreed mainnet numbers in captions.
- Every run 9 screen keeps the site's own "Sepolia test run 9 · test tokens, no value" strip; animated cards with run 9 data say "Sepolia test run 9" in their meta line, not in a corner label.

## Banned
Centred titles on a gradient, everything fading in, glows, gradients on UI, particle bursts, corner labels and frame borders, blurry scaled text (no `will-change` on scaled layers), dead beats with nothing happening.

## Quality loop (before anything is shown)
Contact sheet (one frame per bar), a 12-frame strip around each fast action, a 360-px phone test. Score 1–10: hook in the first 2 s, readability at phone size, motion, variety, composition, brand accuracy, sound sync. Fix the three worst problems, re-render the affected seconds, repeat until every score is 8 or more. Determinism check: the same frame rendered twice hashes the same.
