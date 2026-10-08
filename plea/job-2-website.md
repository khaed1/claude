Build the website for The Cabal (PLEA), the sell-gated token launched in the parent job. Static Vite+React export for IPFS; no backend; read the chain through public RPCs and the oracle through api.imd.fun. Render plea text as text, never HTML.

DESIGN SYSTEM (exact; no other colors, fonts or effects)
:root (light): --paper #fff; --ink #000; --dim #555; --faint #999; --mute #bbb; --soft #e6e6e6; --hover #f4f4f4; --alarm #b3261e; --ok #1f9d55; --rule 1.5px solid var(--ink); --mono "IBM Plex Mono", ui-monospace, monospace; --gutter clamp(16px,4vw,34px); --label 11px; --track 0.06em; --pill-h 40px.
:root[data-theme=dark] (default): --paper #000; --ink #fff; --dim #9a9a9a; --faint #666; --mute #4a4a4a; --soft #262626; --hover #141414; --alarm #ff6b62; --ok #3ecf7a; --rule 1.5px solid #fff.
- IBM Plex Mono only, self-hosted woff2 (400/500/600). Body 14–16px. Tabular figures.
- Labels: uppercase, 11px, 0.06em tracking, --dim.
- Cards/panels: square corners, --rule borders. No shadows, gradients, blur or glass.
- Pills for nav, buttons, inputs: --pill-h tall, fully rounded, --rule border; grouped pills share borders as segmented cells. Primary = --ink fill with --paper text; secondary = outlined; hover --hover; focus 2px --ink outline.
- Logo: text wordmark "PLEA" + blinking "_" cursor, Plex Mono 600, 0.06em, in the left nav pill. No icon; don't use IMD's diamond. Favicon: bold "P".
- Nav: logo · [Buy | Plead | Wall | How] · sun theme toggle · CONNECT pill. Drawer below 640px.
- Stamps: APPROVED / DENIED as outlined uppercase boxes in --ok / --alarm, rotated −3°; PENDING in --dim with blinking cursor.
- Icons: 1.5px line, currentColor. Motion: opacity/transform ≤150ms; honor prefers-reduced-motion.
- Theme via data-theme on <html>, set before first paint from localStorage "plea-theme" (default dark).
- Max width ~1100px, side padding --gutter, no horizontal scroll at 360px.

PAGES
1) Home/status: ALIVE/DEAD; big countdown "THE CABAL DIES IN" to lastVerdictAt+48h; price, market cap, PLEA burned, pleas approved/denied; latest 6 Wall cards.
2) Buy: connect wallet; pay with IMD or ETH (ETH = one Universal Router tx: ETH→IMD via IMD's main Uniswap pool, then IMD→PLEA). Show quote, and during the first 90 min the current launch fee and 5M per-tx cap.
3) Plead:
- amount input + max; cooldown remaining
- live factScore(seller, amount) panel: four facts with points and "Your plea needs N/45 to pass"; if N>45: "Even a perfect plea can't pass at this size. Try selling less or waiting."
- 280-char plea box, counter, placeholder "Make your case to the Cabal.", tips "Be honest, be specific, be funny. Begging works. Threats don't. Trying to trick the judges gets you a public DENIED."
- three read-only example pleas from 2025 CabalCoin
- cost "0.5 IMD, not refunded"
- flow: approve IMD → submitSell → poll oracle → if the callback didn't record it, call deliverVerdict with api.imd.fun/oracle/requests/:id/attestation → if approved, Execute with 15-min countdown and 3% default slippage (minOut)
- per-button pending states and human-readable errors
4) Wall (#/wall): live feed of PleaSubmitted/PleaJudged, newest first.
- Card: plea, seller (short address/ENS), amount, holding %, P/L, hold time, fact score, "needed N/45", time, judges "24/30", stamp APPROVED / DENIED / THE CABAL IS DELIBERATING… (live) / EXPIRED; for approvals, executed or lapsed.
- One judge quote ≤140 chars from api.imd.fun/oracle/requests/:id members' notes, "a judge said:", omitted if none.
- Filters All/Approved/Denied/Pending; sort Latest/Biggest. Counters: total, approval rate, burned.
- Permalink #/p/<requestId>.
- Share: Download image (1200×675 PNG, client-rendered, dark tokens, stamp + plea + stats, PLEA wordmark and URL in footer); Copy image; Share on X with "The Cabal APPROVED my plea 🟩 "<first 100 chars>" Plead your case: plea.sites.imd.fun/#/p/<id>" (DENIED 🟥 for denials), telling users to attach the image since IPFS can't make per-card previews.
5) How it works: five plain sentences; contract addresses with Etherscan links; owner's only power is allow(), which lets an aggregator send PLEA to buyers and can't open a sell bypass; oracle failsafe (no verdict for 48h → Cabal dies, everything unlocks); clear warning that selling is restricted while the Cabal lives; credit "Inspired by CabalCoin by TokenWorks."

DESIGN REVIEW (required before hosting): render every page and state (home, Buy, Plead in each verdict state, Wall, permalink, How) in a real browser at 360/768/1280px, light and dark. Review with the attached design references: check exact token/component use, contrast, no horizontal scroll, clear wallet flow (eth-frontend-ux), share image legibility at X preview size, and no generic AI-template look. Fix blocking findings. Deliver screenshots and the report as artifacts.
