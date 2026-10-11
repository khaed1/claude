# PLEA site: fixes for the next version (testnet run 2 site job)

Collected 2026-10-11 from the live IMD site https://plea-make-your-case.sites.imd.fun/ (job d456a90e, source launch-1242 `web/` at e1a93f13).

## Must fix
1. **Verdict stamps all red.** `web/src/style.css` `.stamp` uses `--error` for every state; only `.stamp.gold` (Laureate) differs. Give each state its own colour, with tokens for light and dark themes and readable contrast:
   - Approved / Executed: green
   - Denied / Upheld: red
   - Pending: amber (with the 20-min countdown)
   - No verdict / Expired / Lapsed: neutral grey
   - Laureate: gold (as now)
   The stamp text carries the state too, so colour is never the only signal.
2. **sIMD decimals.** sIMD has 24 decimals; the profile showed the sIMD wallet balance ×1e6. `Stacker.stackedBy` is tIMD credited, not sIMD. Patch: `khaed1/plea-site` `source/simd-decimals.diff`.

## Polish
3. **Text too large overall.** Plea quotes use `--text-title` (1.5rem) in the display serif; on cards that's too big and makes cards very tall. Scale down: plea text on cards ~1.125rem (detail page can stay larger), display/heading sizes one step smaller, tighter card padding. Check 360 / 768 / 1280 px.
4. Profile: "This name is available to you" shows for the name the wallet already owns; say "This is your current name".
5. 360 px: the nav wraps to two rows (all visible); a single scrollable-free row with smaller items would save space.

## New in testnet run 2 (contracts)
- Season PLEA bonus: show "+ 5,000,000 PLEA bonus" per season for the first 4 seasons (shares per rank in PLEA next to the IMD prize), `Seasons.bonusBurned()`, `BonusPaid` / `BonusBurned` events on the Seasons page.
- Intake v2: a plea with no verdict is cleared automatically (`PleaFailed(id, status, reason, agreed, answered)`); show the reason and keep "Clear" (`expire`) only as the fallback after 20 min.
- New addresses from the run-2 launch; supply split 88 / 2 / 10.
