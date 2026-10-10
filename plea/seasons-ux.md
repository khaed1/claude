# PLEA Seasons: user experience (draft, 2026-10-10)

Walkthrough of the protocol decided in `brainstorm-seasons.md`, phase by phase, as a user sees it on the site. Ideas only; not in any prompt.

## The loop
Season (≤15 days, Cabal alive) → payout → next season … until the Cabal dies (33h with no verdict) → 24h free trading → ransom (500 IMD) → 24h warning → Cabal returns, new season.

## 1. A season is live (Cabal alive)
- **Header:** season number, days left (e.g. "Season 3 · 9d 4h left"), prize pot in IMD, Cabal status.
- **Buy:** same as v4. Fee 1.75%, of which 0.5% comes back as sIMD; the site shows "0.25% to this season's prizes".
- **Plead:** same as v4 (fact score, need, 0.5 IMD oracle fee, verdict in ~5 min, 7 min to sell). New: "An approved plea earns its judges' score as season points."
- **After a verdict:** approved shows "+38 points · you're #4"; denied shows "no points" and the appeal option.
- **Leaderboard tab:** top 10 with points, prize share (25%, 18% …) and IMD amount at the current pot; the 60-point minimum; your rank, points, which 3 pleas count, and your relic bonus.
- **Wall:** each approved plea shows its points; Laureates from past seasons carry a badge.

## 2. Season ends (day 15)
- Anyone can call `closeSeason()` (small tip); the site shows the button once the timer hits 0.
- **Payout is pushed** to the top 10 in the same tx (no claim needed). Below 60 points: no prize, the share rolls over.
- The top 5 pleas are minted as **Laureate NFTs** to their authors (plea text, stamp, season, rendered on chain).
- **Hall of Fame** page: every season's top 10 and Laureates.
- The next season starts at once; the leaderboard resets.

## 3. The Cabal dies (33h with no verdict)
- Anyone calls `killCabal()`; the season ends early and pays out as above.
- **Banner:** "The Cabal is dead. Free trading for 24h, then the ransom opens."
- **Sell** is now a plain swap on the Buy page; Plead is hidden.
- Other pools may appear (other DEXes, lower fees); the site keeps quoting our pool.

## 4. Ransom
- **Ransom page:** progress bar to 500 IMD, contributors list, "Contribute" (minimum 6 IMD for a relic).
- Contributing gives a **soulbound relic** ("Revived the Cabal, season N"): +10% on next season's points. Shown on the profile and leaderboard.
- The whole pot becomes next season's prize pot.

## 5. Warning (24h)
- Starts when the pot reaches 500 IMD. **Full-width countdown on every page:** "Sell limits return in 23:41. Sell now or hold through the next season."
- **LP notice:** "Providing liquidity in a Uniswap v2/v3 PLEA pool? Register it so you can still withdraw" → `registerExit(pool)` button (anyone can press it; only genuine Uniswap pools are accepted).

## 6. The Cabal returns
- Sell limits are back; a new season starts with the ransom pot as its prizes.
- Relic holders see "+10% active". Registered outside pools can only drain (withdrawals and buys), never take sells.

## Who does what
| User | What they see and do |
|---|---|
| Buyer / holder | Buys, gets sIMD cashback, watches the pot and countdowns |
| Pleader | Writes pleas, earns points, chases the top 10 and a Laureate |
| Spectator | Reads the Wall, the leaderboard and the Hall of Fame |
| Ransom contributor | Funds the revival, gets a relic and a head start |
| Outside LP | Gets a 24h warning and a one-click exit registration |

## Open UX questions
1. **Ransom never reaches 500 IMD:** contributions would be stuck. Recommended: refundable if the target isn't hit within 7 days of the ransom opening, and the token stays free.
2. **Notifications:** verdicts, rank changes and countdowns appear on the site only. Optional later: an RSS feed or a Telegram bot.
3. **Who calls `closeSeason()` and `killCabal()`:** a small tip from the prize stream so a keeper always does.
