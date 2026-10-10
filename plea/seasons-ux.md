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
- Anyone can call `closeSeason()` (no tip; the owner's agent calls it too); the site shows the button once the timer hits 0.
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
1. **Decided: ransom refund after 72h.** If the pot doesn't reach 500 IMD within 72h of opening, contributors can take their IMD back, no relics are minted, and PLEA stays free.
2. **Notifications:** verdicts, rank changes and countdowns appear on the site only. Optional later: an RSS feed or a Telegram bot.
3. **Decided: no keeper tip.** `closeSeason()` and `killCabal()` are open to anyone with no reward; the owner runs an agent that calls them, and anyone else can too.

## Why does the Cabal die, and what does that mean? (2026-10-10)
- **New seasons don't need a death.** With the 15-day cap, an active Cabal rolls into the next season by itself. Death and the ransom are only the comeback path after a quiet spell.
- **Death = 33h with no signed verdict**, approved or denied. So it means nobody pleaded (or every plea failed to get a verdict) for 33 hours: interest has dropped.
- **It's a tug of war.** Holders who want the Cabal alive can keep it alive by pleading (each plea costs the 0.5 IMD oracle fee, and a denial still counts as a verdict). Holders who want to sell freely want it dead. The Cabal lives as long as someone cares enough to plead every 33h.
- **The ransom is a test:** if people still care, they fund 500 IMD and the game restarts with a ready prize pot. If not, refunds after 72h and PLEA ends as a normal token.
- **Caution:** the owner (or their agent) pleading only to keep the Cabal alive would keep sellers locked artificially. If that's ever done, announce it; better not to do it.
