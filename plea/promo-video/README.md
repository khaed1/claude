# PLEA promo video

A ~78-second 16:9 trailer (and a ~45-second 9:16 cut) rendered from code in the site's look. Status and decisions: `HANDOFF.md` (promo video entries).

- `STYLE.md`: the look, motion, sound, truth rules and the quality loop.
- `SHOTLIST.md`: 12 shots on the music's bar grid, with the run 9 data and the fork captures each needs.
- `data/beats-16x9.json`: the beat grid of the music edit; `data/panels.json`: the real oracle panels of pleas #14 and #1 (IMD requests `69014807…` and `55f61036…`).
- `tools/make_music.sh <dir>`: rebuilds the music edit from the original track (not committed).

Engine (next gates): one HTML page with `window.seek(t)` that loads `../site-design/tokens.css` and `components.css`, rendered frame by frame with Playwright and encoded with ffmpeg; captures of the run 9 site from a Sepolia fork.

Music: "The Builder" Kevin MacLeod (incompetech.com), licensed under Creative Commons: By Attribution 4.0, https://creativecommons.org/licenses/by/4.0/
