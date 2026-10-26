# PLEA promo video

A ~78-second 16:9 trailer (and a ~45-second 9:16 cut) rendered from code in the site's look. Status and decisions: `HANDOFF.md` (promo video entries).

- `STYLE.md`: the look, motion, sound, truth rules and the quality loop.
- `SHOTLIST.md`: 12 shots on the music's bar grid, with the run 9 data and the fork captures each needs.
- `data/beats-16x9.json`: the beat grid of the music edit; `data/panels.json`: the real oracle panels of pleas #14 and #1 (IMD requests `69014807…` and `55f61036…`).
- `tools/make_music.sh <dir>`: rebuilds the music edit from the original track (not committed).

Engine (next gates): one HTML page with `window.seek(t)` that loads `../site-design/tokens.css` and `components.css`, rendered frame by frame with Playwright and encoded with ffmpeg; captures of the run 9 site from a Sepolia fork.

Music: "The Builder" Kevin MacLeod (incompetech.com), licensed under Creative Commons: By Attribution 4.0, https://creativecommons.org/licenses/by/4.0/

## Explainer series: "How PLEA works · §1–§7" (16:9, ~21 s each, one per X post)

Its own look, not cuts of the promo (the user's call, 2026-10-26): the site's dark theme, a § watermark, a step tracker,
numbered step headlines on the left and the mechanic animated on the right, a recap card (an index card from the
rulebook) at the end with the PLEA stamp on the music's closing hit. Real run 9 data, never the promo's moments.

- `data/clips.json`: the seven clips (number, title, scene module, next title). `src/series/kit.js`: the shared parts;
  `src/series/<name>.js`: one scene per clip, with its own `cues()` for the sound effects.
- Music: `tools/make_clips_music.py <spy.wav> data/spy-beats-original.json <dir>` cuts "Spy Glass" (Kevin MacLeod, 110 BPM):
  the first 6 bars + the last 2 bars and the closing hit (20.9 s, −14 LUFS); `data/beats-clip.json` is its grid (`hit` = the closing hit).
- Build one: `node tools/cues.mjs clipN <dir>/cues.json`, `python3 -I tools/sfx.py series <dir>/cues.json <dir>/clip.wav <dir>`,
  `FILM=clipN node tools/render.mjs <out.mp4> 16x9 0 20.9 60 <dir>/mix.wav`; stills: `FILM=clipN node tools/still.mjs <dir> 16x9 <t…>`.
- `data/panels.json` `plea19`: plea #19's text and IMD panel (request `bfc7011e…`: 18 answers, 17 agreed on 34, need 33), used by §1.

Music for the series: "Spy Glass" Kevin MacLeod (incompetech.com), licensed under Creative Commons: By Attribution 4.0, https://creativecommons.org/licenses/by/4.0/
