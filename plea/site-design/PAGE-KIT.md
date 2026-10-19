# Page kit: how a PLEA mockup page is built

Rules for every file in `pages/`. The design system is `tokens.css` + `components.css` (+ `site.js`, `text-check.js`, `icons.js`); `components.html` is the markup reference for every component.

## Start from the shell
- Copy `pages/_shell.html` exactly. Change only: the `<title>` ("Buy PLEA · PLEA"), `aria-current="page"` on this page's link in **both** `.nav__links` and the drawer (none on Home and Profile), the `<main>` content and the design-reference band.
- Do not edit `tokens.css`, `components.css`, `site.js`, `text-check.js`, `icons.js`, `_shell.html` or another page. If a page truly needs a style the kit lacks, put a small `<style>` in the page's `<head>` that uses only `var(--…)` tokens (no hex, rgb or named colours, no new font sizes outside the scale, spacing only from `--space-*`) and report it, so it can move into the kit.

## Numbers and words
- Every number comes from `sample-data.json` (or follows from its `rules`: show the sum when a page explains one). The clock is **2026-11-16 08:00 UTC**; the connected wallet is **mira_eth** (`0x7a3f…c21e`, holds an IMD seat). No lorem ipsum, no invented figures. Mainnet PLEA contracts do not exist yet: show `[after launch]`.
- Plea text is shown as text, in curly quotes on cards, exactly as in the data.
- Tone: a court with a wink. Anything about money (verdicts, need, fees, windows, amounts, errors) is plain and exact; a joke may live only in an empty state, a toast or a share card, one line at most.
- Buttons name the action ("Buy PLEA", "Submit plea", "Sell now", "Record my points", "Object", "Claim 48,210 PLEA"). A cost goes in a `.btn__sub` after the label, with no dot: `Submit plea <span class="btn__sub">0.50 IMD</span>`. Errors say what is wrong and how to fix it.
- Formats: PLEA as whole numbers with thousands separators; IMD with 2 decimals; times in UTC (`08:19 UTC`); countdowns `mm:ss` under an hour, `3h 41m` under a day, `9d 4h` above; addresses short and mono (`0x7a3f…c21e`); `1M PLEA = 14.16 IMD` for the price.
- Words for states: APPROVED, DENIED, PENDING, NO VERDICT, LAPSED, SOLD (= executed), OVERTURNED and UPHELD (appeals), OBJECTION, SUSTAINED, OVERRULED.
- **The stamp rule, everywhere:** the stamp shows the plea's main state (APPROVED, DENIED, PENDING, NO VERDICT, LAPSED, SOLD, OVERTURNED, UPHELD) with "N vs need N" under it (the time left for PENDING, the reason for NO VERDICT); never an amount. An objection's state is a second `stamp--sm stamp--objection` (OBJECTION #9, SUSTAINED, OVERRULED). Amounts and points go in the card's foot.
- Card times are when the plea was sent (`submittedAgo`). Points still inside the objection window or under a pending objection say "held".

## Components to use (see components.html)
Layout `.page`, `.main`, `.split` (7/5 from 1100 px), `.auto-grid`, `.wall-grid`, `.stack`, `.cluster`, `.section` + `.section__head`. Type `.page-title` + `h1`, `.lead`, `.label`, `.meta`, `.num`, `.mono`. Surfaces `.card` (main objects, shadowed), `.panel` (static containers), `.panel--flush` + `.panel__head` + `.panel__body`. Controls `.btn` (`--primary` once per view, `--ink` only for the sell window, `--sm`, `--block`), `.field` + `.input` + `.input__control` + `.input__unit`, `.textarea` + `.textarea__bar` + `.counter` + `.checks` (wire with `data-text-check="plea|letter|objection|name"`, `data-counter`, `data-checks`, `data-reads`, `data-submit="<button id>"` so the button stays disabled until the text passes, and on a name box `data-current="<name>"`; do not put `aria-live` on the checks list: site.js adds one polite summary line), `.chips` + `.chip[aria-pressed]`, `.toggle-card` + `.box`, `.costs`. Layout helpers `.split--stretch`, `.panel--fill` + `.panel__foot`, `.btn-row--fill`, `.chips--fit` (five chips on one phone row), `.stats--4`, `.steps--3`, `.ref__col`, `.ref__item--wide`, `.ref__note`. Tables `.table--tight`, `.cell-note`. Forms `.input--addr`, `.addr-check`, `.costs .is-part`. Empty `.empty__icon`. Signals `.stamp` (+ `--approved|denied|pending|noverdict|lapsed|sold|objection`, `--sm|--lg|--xl`, `.stamp__sub`), `.badge` (`--seat|letter|auto|you`), `.pill`, `.countdown` (`--urgent` only for the 7-minute sell window, `--wait`, `--block`), `.meter` (`--score`, `--need`), `.facts` + `.fact`, `.plea`, `.wall-card`, `.timeline`, `.lb` (leaderboard), `.table` in `.table-wrap`, `.stats` + `.stat`, `.steps` + `.step`, `.cmds` + `.cmd`, `.letter-sample`, `.chain-text`, `.addr` + `.copy-btn`, `.addr-list`, `.notice` (`--info|warn|bad|ok`), `.empty`, `.skeleton`, `.error-box`, `.toast`, `.share-frame` + `.share-card`. Icons: `<svg class="icon" aria-hidden="true"><use href="#i-NAME"/></svg>` with the names in `icons.js`.

## Every element has a real state
The page shows its main state. Below `</main>`, the `.ref` band ("Design reference · other states") shows the other states of the page's key parts: not connected, loading, empty, error, busy, success, and the page's own (cooldown, CannotPass, claimed, …). Each state is a `.ref__item` with a `.ref__caption`. The band is for the site builder, not the site.

## Accessibility (WCAG 2.1 AA)
- One `h1`, headings in order, landmarks from the shell. Every input has a `<label>`; hints and errors are tied with `aria-describedby`; invalid fields get `aria-invalid="true"`.
- Links go somewhere, buttons do something (`<a href>` vs `<button type="button">`). Icon-only buttons have `aria-label`. Decorative SVG is `aria-hidden="true"`.
- Never remove focus outlines. Colour is never the only signal: the state is always in words.
- Countdowns: `role="timer"` with an `aria-label` that reads in words. The checks list is `aria-live="polite"`.
- Tables: `<caption>` (may be `.sr-only`), `<th scope>`; a `.table-wrap` that can scroll gets `tabindex="0" role="region" aria-label`.
- Body text at least 4.5:1, large text 3:1 (the tokens already pass: don't put text on a fill that isn't a token pair from components.html).

## Layout
Mobile first. No sideways scroll at 360, 768 or 1280 px. Long words and addresses wrap (`.addr__text`, `overflow-wrap: anywhere` is built in). Use the grid classes; no fixed widths over 328 px except inside a scroll box.

## Check before you finish
```
PLAYWRIGHT=/opt/node-tools/node_modules/playwright/index.mjs AXE=<path>/axe-core/axe.min.js \
  node tools/check.mjs pages/<page>.html --out <scratch dir>
```
Add `--widths 320,360,768,1280`. It must report `"ok": true` for all eight runs (four widths × light/dark): no overflow, no console errors, no axe violations. Then look at the 360 and 1280 screenshots yourself and fix what looks wrong (crowding, orphans, misaligned edges, uneven spacing).
