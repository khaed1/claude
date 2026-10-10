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
- **Revival:** ransom contributors get a tradable **"Ransom"** NFT for that season ("I revived the Cabal").
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
- **Proposed, not yet confirmed:** ransom target 500 IMD; relic minimum 10 IMD; minimum 60 points to win a prize; 3 Laureate NFTs per season (top 3).
