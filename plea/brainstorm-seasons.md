# PLEA seasons: brainstorm (2026-10-10)

Ideas only. Nothing here is decided or in any prompt. v4 (testnet) deliberately leaves all of it out; consider it for mainnet or a PLEA II.

## The problem
The game happens once per token: `killCabal()` can't be undone. The Cabal dies only after 33h with no verdict, so it lives as long as people keep pleading. When it dies, PLEA becomes a normal token. A sell-off is likely; the locked liquidity, the IMD buy wall and past burns soften it.

## Ideas
1. **Season leaderboard and prizes** (easiest, no rule changes)
   - Fixed seasons, e.g. 30 days.
   - Approved pleas earn points from the judges' score.
   - The top pleaders split a prize pot (e.g. appeal fees or a slice of the owner fee).
   - A Hall of Fame on the Wall.
2. **Themed seasons**
   - Each season has a Cabal "mood", e.g. classic, rhyming pleas only, or strict with a higher pass mark.
   - The whole schedule is fixed at launch, so the owner can't change rules mid-game.
3. **The Cabal "ransom"**
   - When the Cabal dies, PLEA trades freely (a "holiday").
   - Holders fill a ransom pot in IMD; at a target (e.g. 500 IMD) the Cabal returns and the next season starts.
   - The pot goes to the buy wall or cashback.
   - **Catch:** selling limits come back after free trading. That needs a long, loud warning (e.g. a 72h countdown) so nobody is trapped, and the token's limits must switch on and off instead of ending once (more complex).
4. **Season badges**
   - The top plea of each season becomes an on-chain collectible.

## Favourite: 3 + 4 with tradable NFTs (user idea, 2026-10-10)
- **Season end:** the Cabal dies, and the season's best pleas are minted as **tradable ERC-721 "Laureates"** (the plea text, its verdict stamp and the season, rendered on-chain).
- ~~**Revival:** ransom contributors get a tradable **"Ransom"** NFT for that season.~~ Dropped: contributors get the soulbound relic instead.
- **Small perks only:**
  - a Laureate gives one free plea next season, or a badge on the Wall
  - perks stay cosmetic or small, so farming pleas from many wallets doesn't pay
- **Fair revival:** a 72h warning countdown before limits return; the ransom window opens only after a free-trading period.
- **Risks:**
  - **Farming:** tradable prizes invite Sybil farming. The judges resist well: both injections in calibration got all zeros. Small perks reduce the incentive further.
  - **Legal:** tradable prizes from a paid game deserve a light legal check before mainnet.
  - **Size:** more contract surface, so more audits and a bigger prompt.

## If we build it
- **When:** after v4 is proven. Mainnet v1 or PLEA II.
- **How:** a separate `Seasons` contract that the Gate reports verdicts and scores to, with season rules fixed at launch.
- **Revival:** needs PLEA's restriction to read `gate.cabalAlive()` instead of a one-way flag.
- **Testing:** try it on Sepolia with the IMD NFT test token, `0xa0443799c320e16c80801c9c1911f3571260287f`, the seat stand-in.

## Round 2 (2026-10-10): combo 1 + 3 + 4
User's picks: season leaderboard (1), ransom revival (3), badges (4). Open proposals, nothing decided:
- **Ransom relics are soulbound** (non-transferable), one per wallet per season, with a minimum contribution. Recommended use: **leaderboard points next season only, never the sell verdict**. If a relic lowered `need`, the ransom would buy easier sells (pay-to-win) and make it worth splitting deposits across wallets.
- **Ransom pot → next season's prize pot** (recommended over buy-and-burn): contributors fund prizes they can win back, and a buy during the holiday would pump the price just before limits return.
- **24h warning** is fine if: the countdown starts only when the target is hit, the pot's progress is shown live the whole time, and the ransom opens only after a minimum free-trading holiday.
- **Prize funding:** fees today total 1.5% (IMD side 1.25%: cashback 0.5, owner 0.5, liquidity 0.25; plus a 0.25% PLEA burn). Adding 0.25% for prizes makes **1.75%**. Recommended instead: take the 0.25% from the owner's 0.5%, so the total stays 1.5%. The ransom pot tops prizes up each season.

## Round 3 (2026-10-10): prize funding and points
- **The user keeps the full 0.5% owner share.** Options for prizes: (A) add 0.25%, total 1.75% (1.25% net after cashback); (B) send the 0.25% PLEA burn to prizes instead, total stays 1.5%; (C) liquidity share, not recommended (thins the pool and the buy wall). Recommended: **A**. Every pool needs our hook and hookData, so no cheaper PLEA pool competes, and the cashback offsets part of the fee.
- **Points draft:** only approved pleas score. Points = the judges' plea score (0–45), counting each wallet's **best 3** per season, so grinding many pleas doesn't pay. A ransom relic adds a **flat +10%** to the season total, the same for any contribution above the minimum. Ties go to the earlier plea.

## Round 4 (2026-10-10): decisions and outside pools
- **Decided: option A.** Prizes get a new 0.25% fee; the total becomes 1.75% (owner keeps 0.5%). For seasons only, not v4.
- **Payout:** the "best 3" is per wallet (which of its pleas count); the prize split is across the leaderboard. **Decided: top 10**, 25/18/14/11/9/7/6/4/3/3 %, with a minimum score to qualify; unclaimed shares roll to next season. (Top 5 at 35/25/18/12/10 was the alternative.)
- **Outside pools.** While the Cabal lives, nobody can fund another pool (PLEA can't be sent to it). During the holiday, anyone can create PLEA pools (Uniswap v2/v3/v4, other DEXes) with lower fees; arbitrage keeps prices in line and our hook's share of volume (and fees) falls. That's fine for a holiday.
- **The revival problem:** when limits return, LPs in v2/v3 pools can't withdraw (the pair sending PLEA is blocked), so they'd be trapped. Uniswap v4 pools are already fine, since transfers from the PoolManager are allowed: LPs can withdraw and people can buy, but nobody can sell into them.
- **Decided fix:** a permissionless `registerExit(pair)` that accepts only real Uniswap v2/v3 pools (checked against the factory). A registered pool may send PLEA (LP withdrawals and buys work) but can't receive it from wallets (no selling), so it just drains. Don't exempt any contract with code: a Safe or 7702 wallet could then skip the Cabal.

## Round 5 (2026-10-10): timing
- **Decided: 24h free-trading break** after the Cabal dies, then the ransom opens; on target, the **24h warning**, then the Cabal returns. Sellers get at least 48h of free trading.
- **Decided: seasons are capped at 15 days.** On day 15 the top 10 are paid, the leaderboard resets and a new season starts at once with the Cabal still alive. A season also ends early if the Cabal dies (then break → ransom → revival).
- **Decided:** ransom target 500 IMD; relic minimum **6 IMD**; minimum 60 points to win a prize; **5 Laureate NFTs per season** (the top 5 pleas).

## Seasons: decided so far (summary)
| Item | Value |
|---|---|
| Combination | Leaderboard (1) + ransom revival (3) + NFTs (4) |
| Prize funding | New 0.25% fee → total 1.75% (owner keeps 0.5%) + the ransom pot |
| Season length | 15 days max; ends early if the Cabal dies |
| Era | Each Cabal lives 2 seasons (30 days) with a mood fixed at launch, then retires on schedule; the 33h dead-man can end it early |
| Points | Judges' plea score (0–45) on approved pleas; each wallet's best 3 count; ties to the earlier plea |
| Ransom relic | Soulbound, one per wallet per season, minimum 6 IMD, flat +10% to next season's points (never the sell verdict) |
| Payout | Top 10: 25/18/14/11/9/7/6/4/3/3 %, minimum 60 points, unpaid shares roll over |
| Laureates | 5 tradable ERC-721s per season (top 5 pleas), small cosmetic perks |
| Revival | Cabal dies → **72h** free-trading break (changed from 24h on 2026-10-10) → ransom opens (target 500 IMD, pot → next season's prizes) → 24h warning → Cabal returns |
| Outside pools | Permissionless `registerExit` for genuine Uniswap v2/v3 pools: they can send PLEA out, not receive it |
| Contributor reward | Soulbound relic only; the tradable "Ransom" NFT is dropped (2026-10-10) |
| Open | Legal check before mainnet |

## Round 6 (2026-10-10): how the Cabal ends, and moods
- **Decided: 72h free-trading break** (was 24h), so a new mood has time to draw people in. The 24h warning before limits return is unchanged.
- **The gap:** with only the 33h dead-man, a busy Cabal may never die, so the ransom and a new mood would never happen.
- **Options to end a Cabal:** (A) time only, as now; (B) **planned retirement**: each Cabal (an "era") retires on schedule after a fixed number of seasons, with its mood fixed at launch; (C) a holder vote (whales can capture it, more code); (D) an activity threshold (like A, more complex); (E) a price or approval-rate trigger (can be manipulated).
- **Recommended: A + B.** Keep the 33h dead-man as the early exit, and add a planned retirement after 4 seasons (60 days). Each era has its own Cabal mood from a schedule fixed at launch; the ransom starts the next era with the next mood. Every era ends with a known free-trading window, which also gives long-locked holders a fair exit. **Decided** (era = 2 seasons, see below).
- **Era length (user, 2026-10-10): 2–3 seasons.** **Decided: 2 seasons (30 days)**, "a new Cabal every month". One cycle ≈ 30 days of Cabal + 72h break + up to 72h ransom + 24h warning ≈ 34–37 days, so PLEA trades free about 10–19% of the time (3 seasons: about 7–13%).

## Round 7 (2026-10-10): the moods
**Decided cycle (repeats; one mood per era, fixed at launch):** 1 The Classic Cabal · 2 The Rekt Cabal · 3 The Jester's Cabal · 4 The Loyal Cabal. At 30 days per era, the cycle is about 4–5 months.

### The Rekt Cabal (user idea; draft)
Pleas from people who lost money to scams and rugs. The plea links the wallet that got rekt and the transactions.
- **Proof the wallet is yours:** the rekt wallet signs a short message ("I link this wallet to PLEA plea N"); the Gate checks it on chain (ecrecover, cheap). Without this, anyone could cite a famous victim's wallet. The pleading wallet itself also counts.
- **Evidence in the plea:** chain, token address, the buy tx(s) and, if known, the rug tx (LP pulled, dev dump, honeypot, mint).
- **What the judges score (Rekt mood):**
  - Proof: the buy txs exist and belong to the linked wallet, and the token really rugged (LP removed, price ~0, sells blocked).
  - Severity: kind of rug (honeypot or LP pull > slow dev dump > ordinary loss), how fast, how much of the liquidity went.
  - Loss: the amount lost (in USD or ETH at the time), with diminishing credit so whales don't dominate.
  - Story: honesty and what they learned (craft and respect as in Classic).
- **Abuse guards:**
  - Self-rugs: someone launches a token, buys and rugs it to fake a loss. Require the rug to be ≥30 days before the plea, the token to have had ≥50 independent holders, and the buyer not to be the deployer or an LP remover.
  - Reuse: each rug tx counts once across all pleas (the Gate stores its hash); one rekt wallet per pleader per era.
  - Lies the judges can't check fail: a plea that can't be proven scores no Rekt credit.
- **Must check with IMD first:** can the judges read chain data (txs, logs, LP events) on Ethereum and other chains, or only the plea text (`evidence: "panel"` today)? If only text, Rekt pleas can't be verified, and this mood needs a chain-evidence feature from IMD.
- **Privacy:** linking a wallet makes its history public on the Wall. Warn before submitting.
