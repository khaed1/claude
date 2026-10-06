PondPad is a token launchpad on Robinhood Chain where every coin is paired with IMD. Coins hatch on a bonding curve ("tadpoles"), make **the Leap** into a locked pool ("frogs"), and the IMD swarm, **the Chorus**, builds their websites. This book sets how PondPad looks, sounds and behaves, so every page, post and swarm-built site feels like the same pond.

## Brand idea

**A pond at night, lit by fireflies.** Calm deep water underneath (the rules are fixed, liquidity is locked, nothing hidden), and lots of small living things on top (coins hatching, trades rippling, frogs leaping). The UI is the water: quiet, dark, legible. The coins and moments are the life: green, gold and pink.

Four traits, in order of priority when they conflict:

1. **Honest.** Fees, risks and rules are always visible. We show the math, never hide it in a modal. Trust beats hype.
2. **Alive.** Things move and ripple: the Leap meter fills like water, the trade feed ripples, a graduation is a moment. Movement always means something happened.
3. **Playful.** A friend who's been in the pond a while: warm, a little cheeky, never salesy. One frog joke per paragraph, at most.
4. **Communal.** The Pond (stakers), the Chorus (the swarm) and holders share in what happens. We say "we" and "the pond", not "users".

## Vocabulary

Use these words everywhere: in the UI, docs, posts and swarm-built sites.

| Thing | Word | Where it shows |
|---|---|---|
| Launching a coin | **Spawn** ("lay an egg") | Spawn button, create page |
| Brand-new coin (first minutes, max-buy window) | **Egg** | `pp-stage-egg` chip |
| Coin on the bonding curve | **Tadpole** | `pp-stage-tadpole` chip, Leap meter |
| Graduation | **The Leap** | Leap meter, Leap modal, ripple feed |
| Graduated coin | **Frog** | `pp-stage-frog` chip |
| sPONDPAD stakers | **The Pond** | Stake page |
| The IMD swarm | **The Chorus** (link to the swarm explorer the first time on a page) | badges, website card, docs |
| Live trade feed | **Ripples** | top-of-page feed |

## Voice

- Short sentences. Plain words. Sentence case for everything except the wordmark and tickers.
- Second person to the reader ("your coin"), first person plural for PondPad ("we checked").
- Numbers are exact and carry units: "2,520 / 4,000 IMD", "Fee: 2.0% (1.5% base + 0.5% to holders)". Never "low fees".
- Never: "revolutionary", "unlock", "moon", "guaranteed", "safe", price promises, APY promises. Say "rewards depend on how much trading happens".
- Buttons say exactly what happens: "Spawn it", "Buy $RIBBIT", "Collect your IMD", "Leave the pond". The toast confirms in the same words.
- Errors say what went wrong and what to do, without blame: "The price moved while you were deciding. Try again or raise slippage a little."
- Risk lines stay in plain sight and in the same voice: "Coins here are made by anyone and can go to zero."
- Full copy deck: `launchpad/SITE-COPY.md`.

## Logo

- **The mark** is a lily pad with its notch: `assets/Logos/pondpad-mark.svg` (lily green, for night grounds) and `pondpad-mark-day.svg` (deep lily, for day grounds). The notch points up and right, like the chart we hope you'll see.
- **The wordmark** is "pondpad" in lowercase, set live in the display face (`hero`/`title` family) next to the mark, mark height = 1.25 × the cap height. It is live type, not an image, so it follows the theme's `ink`.
- **The app icon** (`pondpad-app-icon.svg`) puts the mark on `pond-deep` with one firefly. Use it for favicons, social avatars and the PWA icon.
- Clear space around the mark: half its width. Minimum size 20px.
- Don't: recolor the mark outside `lily`, add a face to it, rotate it, outline it, put it on a photo without a `pond-deep` plate.

## Mascot: Pip

`assets/Logos/pip-frog.svg`: a round, geometric frog peeking over the water line. Pip appears in **moments, not chrome**: the Leap modal, empty states ("No frogs by that name"), the 404, the airdrop "Wake the pond" page, social posts. Never in the header, never on a trade button, never more than once per screen. Pip is our own frog: never draw it in the style of Pepe or any other existing character.

## Color

Two themes from one set of tokens: **night** (default; trading happens here) and **day** (follows the system's light setting, or the toggle). Every text pair below holds 4.5:1 in both themes (checked by `build_tokens.py`).

- **Water (surfaces):** `pond-deep` page, `pond` cards and the trade box, `pond-raised` inputs and chips, `reed` hairlines, `reed-strong` hover borders and empty meter track.
- **Ink:** `ink` for text and numbers, `ink-muted` for labels and metadata, `ink-faint` only for placeholders.
- **Lily (brand green):** primary actions, buys, positive change, links. Text on a lily fill is `on-lily`. One primary (lily) button per view: the thing the page is for.
- **Firefly (gold):** the Leap and $PONDPAD. `firefly` is a fill (Leap meter near the end, the $PONDPAD button, the "About to Leap" spotlight border) with `on-firefly` text; `firefly-ink` is gold as text.
- **Lotus (pink):** the Chorus and social proof: "Site by the Chorus", "X verified", swarm job links, takeover notices.
- **Coral:** sells, losses, errors. Always paired with a word or ▲▼ arrow; never color alone.
- **Ripple (teal):** the water in the Leap meter, IMD price lines in charts, decorative water.
- **Focus:** `focus` ring, 2px solid with 2px offset, on every interactive element.

Proportions on a typical page: 80% water, 10% ink, 10% life (lily, gold, pink, coral together). If a screen feels loud, take color away from chrome first, never from state.

## Type

- **Display, `Lilita One`** (`hero`, `title`, `heading`): round, chunky, a little silly. The wordmark, page titles, the Leap modal, coin names on the coin page. Never for numbers, labels or more than one line of running text.
- **Text, `Nunito`** (`lead`, `body`, `body-strong`, `label`, `caption`, `number-xl`): rounded and friendly, readable at 12px, tabular numbers on. Everything else.
- **Data, `Martian Mono`** (`address`, `ticker`): addresses (shortened `0x4b91…6821`), tickers (`$RIBBIT`), tx hashes.
- Fonts are self-hosted (`launchpad/design/fonts/`, SIL Open Font License); no font CDN at runtime.
- Numbers: always tabular, always with units, thousands separators, at most 4 significant decimals in the UI (full precision in a tooltip). IMD first; dollar values in `ink-muted` beside it when a price feed exists.

## Shape, space and depth

- Lily-pad round: `radius-lg` (22px) for cards, the trade box and modals; `radius-md` (14px) for buttons and coin images; `radius-sm` (8px) for chips and inputs; `radius-pill` for the Leap meter, presets and tab bar.
- 4px base: `space-1` … `space-7` (4 to 48). Cards pad `space-4` on phones and `space-5` on desktop; grid gap `space-5`; sections `space-6` apart.
- Depth comes from water layers (`pond-deep` → `pond` → `pond-raised`) and `reed` borders, not shadows. `shadow-card` is only for floating things: menus, toasts, the mobile trade sheet.

## Motion

- Motion means something happened: a new trade (a ripple ring on its feed chip), the Leap meter filling after a buy (300ms ease-out), the Leap (one celebration: Pip jumps, gold ripples, 1.2s, once).
- Hover: cards lift 2px; buttons brighten. Press: 1px down.
- Everything respects `prefers-reduced-motion`: ripples and the Leap celebration become a plain color change.
- No auto-playing confetti, no shaking prices, no blinking "LIVE" lights.

## Iconography and imagery

- Icons: simple filled glyphs on a 24px grid, `currentColor`, 2px rounded corners where possible. One set across the site (the frontend uses Phosphor "fill" or equivalent; the X logo is the official glyph).
- Coin images are the creator's: always shown in a `radius-md` square, never stretched, with a `pond-raised` placeholder while loading.
- Our own illustrations are flat and geometric (lily pads, ripples, fireflies, Pip), built from the palette. No 3D renders, no stock photos, no AI-generated imagery on PondPad's own pages.
- No emoji or Unicode glyphs as icons in the UI: notices, the ripple feed and buttons use drawn SVG icons. 🐸 belongs to social posts and share text only (`SITE-COPY.md`).
- Browser surfaces carry the palette too: text selection `lily-soft`, caret and checkboxes `lily`, scrollbars `reed-strong` on `pond-deep`, link underline offset 3px, tabular numerals everywhere.

## Layout

- Desktop: top bar (logo, Explore, $PONDPAD, The Pond, Docs, search, Spawn, wallet), then the ripple feed, then the page. Content max width 1200px.
- Phone: compact top bar (logo, search, wallet) and a bottom tab bar: Explore, $PONDPAD, Spawn (the one lily button), Pond, Profile. 16px side gutters.
- Coin page: chart and tabs on the left, the trade box sticky on the right (desktop) or as a bottom sheet behind a fixed Buy / Sell bar (phone).
- Every page answers "what is this, what can I do, what does it cost" above the fold.

## Components

The components (`pp-` classes in `components/bundle.css`) are the frontend's real stylesheet. The signature pieces:

- **Leap meter:** a water track with three lily pads at 25 / 50 / 75%, a tadpole head that becomes a round frog at 100%; turns gold from 90%.
- **Stage chip:** Egg / Tadpole / Frog, always on coin cards and the coin page.
- **Coin card:** image, name, ticker, stage, two-line description, market cap in IMD, 24h change with arrow, age, Leap meter (tadpoles only), the total fee, at most two badges (X verified, Site by the Chorus).
- **Trade box:** Buy / Sell, pay with IMD / ETH / USDG, presets, the quote (minimum received, route, price impact, slippage) and the fee line, always visible.
- **Ripples:** the live feed of buys, sells, spawns and Leaps.

## Do and don't

- Do show the fee on every trade, before the button. Don't hide it behind "details".
- Do label every state with a word (Tadpole, Sell, Takeover). Don't rely on color alone.
- Do keep one lily button per view. Don't make every button green.
- Do let coin images bring the color. Don't add gradients or glows to chrome.
- Do say "can go to zero". Don't say "safe", "guaranteed" or show APY promises.
