# PLEA site design system: neo-brutal docket

The look of the next PLEA site (plea.sites.imd.fun), built by IMD's site job. This folder is the spec: the tokens and component CSS can be used as they are, the HTML pages are mockups with real numbers, and `text-check.js` is the contract's text rules in the browser.

**Open first:** [`components.html`](components.html) (every component in every state) and [`pages/index.html`](pages/index.html) (the page mockups; the theme button switches light and dark). Screenshots are in [`shots/`](shots/).

**How it was checked:** every page and the gallery pass `tools/check.mjs` at 320, 360, 768 and 1280 px in light and dark (96 runs: no sideways scroll, no console errors, no axe violations); `text-check.js` matches the contracts' Solidity on about 75,000 inputs and every Unicode code point (`tools/difftest/`); every number on every page was recomputed from the contracts by independent reviewers, and keyboard, screen-reader announcements, forced colours, reduced motion and 200% zoom were tested by hand-written Playwright scripts.

**The user's choices (2026-10-19):** direction A, neo-brutal docket ([step 1](step-1-styles/README.md)); light first plus a real dark theme; medium colour; a display face for headlines; a court with a wink; one motion moment; redo the X logo and header ([`../brand/`](../brand/README.md)).

## Files

| File | What |
|---|---|
| `tokens.css` | Every colour (light and dark), the type, spacing, border, radius, shadow and motion tokens. The only place raw colours live. |
| `components.css` | All components, mobile first. Uses only tokens. |
| `components.html` | The gallery and markup reference: colour, type, space, nav, buttons, inputs with the byte counter, pills, the stamp, the plea card, the Wall card, countdowns, tables and the leaderboard, toasts, empty/loading/error states. |
| `text-check.js` | `PleaText.checkText / checkObjection / checkLetter / checkName / byteLength`: what `CabalGate`, `Tribunal` and `Letterbox` accept, with the reason in plain words. Unit tests: `node --test tools/text-check.test.cjs`. Differential test against the contracts' own Solidity on a local EVM (about 75,000 inputs plus every Unicode code point): `node tools/difftest/run.mjs` (needs Foundry). |
| `site.js`, `icons.js` | Mockup behaviour (theme, menu, live text checks, auto-sell box, copy) and the icon sprite (Phosphor Bold, MIT). |
| `pages/` | The mockups: `index` (home and how it works), `buy`, `plead` (with the auto-sell box), `plea` (a plea's status page), `letters` (the Etherscan how-to), `objections`, `seasons` (leaderboard with the seat multiplier), `wall`, `claim` (the 12% and delegate.xyz), `profile`, `share-cards` (the X card per plea). `_shell.html` is the frame every page copies. Each page ends with a dashed "Design reference · other states" band: the other states of its parts, for the builder, not for the site. |
| `sample-data.json` | One consistent set of numbers for every mockup, computed by `tools/sample_data.py` from the agreed mainnet numbers. Names, wallets and plea texts are made up; mainnet PLEA addresses are `[after launch]`. |
| `PAGE-KIT.md` | The rules a page follows (also for the site builder). |
| `tools/` | `check.mjs` (a page in Chromium at 320/360/768/1280 px, light and dark: sideways overflow, console errors, axe-core WCAG 2.1 AA), `render_share_cards.mjs` (every share card to a 1200 × 675 PNG), `difftest/` (text-check.js against the Solidity), `contrast.py`, `crop.py`, `sample_data.py`, `build_icons.cjs`, the text-check unit tests. |
| `brief-imd-site-job.md` | The brief for IMD's site job (under 5,500 characters). |
| `brief-site-job-run9.md` | The same brief for the Sepolia test site on run 9 (launch #2234): the run's addresses, imdTEST, PoolSwapTest, events read from the chain instead of an indexer, the not-yet-seeded and no-claims states. Sent as IMD job `plea/job-run9-site.json` on 2026-10-20. |
| `run9-site-review.md` | The test of the site that job built (https://plea-test-run-9.sites.imd.fun/): 158 verified findings from fork playthroughs, automated checks, a chain and code review and mockup comparisons, merged into 73 fix items (19 P1) for the follow-up fix job. |
| `shots/` | Share cards as PNG (`share-card-<id>.png`, one per verdict state, plus the dark #214 and the default link card) and every page at 1280 px light, 360 px light and 1280 px dark (`shots/pages/`). |

## Decisions the pages follow

- Plea #214 (the sample's star) is a manual plea: its seller sells with "Sell now" in the 7-minute window; the auto-sell box is shown unticked on Plead, ticked in its reference band.
- The urgent pair (the sell window and Sell now) shows only to the wallet that can sell; everyone else sees a plain countdown.
- Card times are when the plea was sent; the verdict moment on the hero, the status page and objection cards says "approved N ago".
- Points inside an objection window or under a pending objection always say "held"; points are never recorded by themselves (anyone presses Record my points).
- After the Cabal dies every page shows the same strip and banner (commented in `pages/_shell.html`).
- Prizes and payouts are rounded down, as the chain pays them; a list and its total may differ by a cent, and the page says so.

## Principles

1. **Restraint, because it moves money.** Hard shadows only on what you can press, on cards and on the stamp. One action colour (yellow), never used for a state. Ink text on every fill. The one exception is the urgent pair, the 7-minute sell window and its Sell now button: the loudest box in each theme (black with yellow digits in light, yellow in dark).
2. **The stamp is the signature.** One shape everywhere (ink outline, tilted -3°, the state in capitals, the score against the need under it), in four sizes. It is the only thing that moves: it lands once when a verdict arrives.
3. **A colour per verdict state, never colour alone.** The word is the state; pending is striped and lapsed is a dashed outline, so they read in greyscale and in Windows high contrast too. One stamp rule everywhere: the stamp shows the plea's main state with "N vs need N" (or the time left, or the reason) under it, never an amount; an objection's state is a second, small lilac stamp.
4. **Numbers you can trust.** Tabular figures for every amount; mono for countdowns, inputs, plea numbers and addresses; UTC times; IMD with 2 decimals, PLEA whole.
5. **Plain words for money, jokes elsewhere.** Verdicts, needs, fees, windows and errors are exact. A wink may live in an empty state, a toast or a share card.
6. **Every element has a real state:** not connected, loading, empty, error, busy, done, and its own (cooldown, CannotPass, claimed…).
7. **Not IMD.** No diamond logo, no "official" wording; the footer says so.

## Tokens

**Colour.** Light (default): paper `#FBF6EA`, sunken `#F3EDDD`, card `#FFFFFF`, ink `#121212`, secondary `#4A463E` (8.7:1), tertiary `#6B665B` (4.9:1 on sunken), action `#FFD92E`, your row `#FFF3B0`. Dark (`html[data-theme="dark"]`): paper `#17150F`, sunken `#201D16`, card `#26221A`, ink `#F5F0E4` (16:1), secondary `#C9C1AE`, tertiary `#A89F8B` (6:1), your row `#3D3519`; outlines and shadows turn cream.

| State | Token | Fill | Stamp words | Also |
|---|---|---|---|---|
| Approved | `--approved` | `#4BE08F` | APPROVED, OVERTURNED | |
| Denied | `--denied` | `#FF5A4E` | DENIED, UPHELD | |
| Pending | `--pending` | `#FFC247` / `#FFE08A` | PENDING | striped |
| No verdict | `--noverdict` | `#C9C3B6` | NO VERDICT | |
| Lapsed | `--lapsed` | none | LAPSED | dashed outline |
| Executed | `--executed` | `#6FA8FF` | SOLD | |
| Objection | `--objection` | `#C8A6FF` | OBJECTION, SUSTAINED, OVERRULED | |

Text on every fill is `#121212` in both themes (6.1:1 on denied up to 11.7:1 on pending). As text on cards: `--approved-text` `#137A3E` / dark `#4BE08F`, `--denied-text` `#C2271C` / dark `#FF8A80`. Focus ring: blue `#1F4FE0` in light (6:1), yellow in dark (11:1), ink on any state fill. Dark shadows are `#5E5644`, darker than the cream outline, so depth never reads as a glow.

**Type.** Archivo (variable, width 62–125) and IBM Plex Mono, both SIL OFL 1.1, self-hosted as woff2. Display = Archivo at 125% width, 800. Scale: 12, 14, 16, 18 (plea text on cards), 22, 22–28 (section headings), 28–36 (page titles), 36–56 (home only). Line heights 1.1 / 1.3 / 1.5. Tabular figures on the whole page; headings balance their lines.

**Space.** 4, 8, 12, 16, 24, 32, 48, 64, 96 px. Grid 4 / 8 / 12 columns at 360 / 768 / 1280 px, max 1200 px, gutters 16 / 24 / 32 px; two columns (7/5) from 1100 px; the full nav from 1100 px. The only off-scale values are optical: the stamp's and logo's inner padding (a tilted capital box needs 1 px less at the bottom) and 1–2 px icon nudges.

**Borders, radii, shadows.** Outlines 3 px (2 px on pills, badges, dividers). Radii 4 (stamps, badges), 8 (buttons, inputs), 12 (cards, panels), pill. Shadows 3 / 4 / 6 px offset, no blur, in ink.

**Motion.** Exponential ease-out `cubic-bezier(0.16, 1, 0.3, 1)`. The stamp lands in 420 ms (from 1.7× and -14° to 1× and -3°); buttons press 4 px into their shadow in 90 ms. `prefers-reduced-motion` turns both off. Countdowns change their digits, nothing slides.

## The text checks (byte counter)

Every text box (plea, appeal, objection, letter, name) shows `193 / 280 bytes` and four live checks, the contract's own rules: 1–280 UTF-8 bytes; one line, no control characters; no hidden characters (zero-width, direction marks, variation selectors, tags and the rest of Unicode's format and default-ignorable characters, the exact list of `CabalGate._refused`); no `[plea`, `[/plea`, `[objection`, `[/objection` in any case (so `[please` is refused too). Common traps get a tip: ❤️ carries an invisible variation selector, joined emoji carry a zero-width joiner. The letter checker also says how the Letterbox will read the letter (`APPEAL`, `SELL`, `NAME` in capitals at the very start; "SELL me some mercy" is a SELL). It does not check chain state (cooldown, balance, a taken name).

## Accessibility

Body text at least 4.5:1 and large text 3:1 in both themes (`tools/contrast.py`, and axe in `tools/check.mjs`). Keyboard: a 3 px focus ring 3 px off every control (blue, yellow in dark, ink on fills); a skip link; the desktop links are a `nav` landmark; the menu is a real button with `aria-expanded` that Escape closes. Targets at least 44 px. Countdowns are `role="timer"` with a label in words. Text boxes start neutral, show their checks as you type and announce only when the verdict changes (one polite line); submit stays disabled until the text passes. The leaderboard rows carry their column names on phones. Tables have captions and scoped headers. Reduced motion and forced colours (Windows high contrast) are handled. Colour is never the only signal. Every mockup passes `check.mjs` at 320, 360, 768 and 1280 px in light and dark: no sideways scroll, no console errors, no axe violations.

## Porting to the site (Vite + React)

Use `tokens.css` and `components.css` as they are (or as CSS modules); build each component once in React with the markup of `components.html`; use `text-check.js` as a module (it exports CommonJS and sets `window.PleaText`); self-host the fonts and the icons; set `data-theme` before first paint from `localStorage["plea-theme"]` (default light). The mockups' clock is 2026-11-16 08:00 UTC and the connected wallet is `mira_eth`; the site reads everything from the chain and IMD's API.
