# Cap ratchet: 25 vs 15 days (model, 2026-10-14)

Model of `PleaHook`'s market band (constant-product from the start price up, virtual IMD reserve = 0.82 × seed), the cap ratchet and trims. `cap(t) = max(lowest holding so far, seed − rate·t, 900k)`; a sell that lifts the holding above the cap is trimmed: the excess PLEA burns, the matching IMD share of the position leaves to the buy wall, the price does not move. Seed 14,000 IMD at $7.60. Scenario: $20k/day of buys for 7 days, then $3k/day of buys and $2k/day of approved sells. Simplifications: sells trade on the market band only (the wall is ignored), fees 1.5% on buys, no 0.25% per-trade burn counted.

| day | hook PLEA (25d) | cap (25d) | burned (25d) | wall (25d) | hook PLEA (15d) | cap (15d) | burned (15d) | wall (15d) |
|---|---|---|---|---|---|---|---|---|
| 7 | 31.8% | 59.1% | 0 | $0 | 31.8% | 43.8% | 0 | $0 |
| 10 | 31.4% | 49.2% | 0 | $0 | 31.1% | 31.1% | 2.7M | $2k |
| 15 | 30.7% | 32.9% | 0 | $0 | 29.1% | 29.1% | 16.0M | $12k |
| 20 | 28.8% | 28.8% | 12.8M | $10k | 27.2% | 27.2% | 28.8M | $22k |
| 30 | 25.3% | 25.3% | 36.7M | $30k | 23.7% | 23.7% | 52.6M | $42k |
| 45 | 20.5% | 20.5% | 68.9M | $60k | 19.0% | 19.0% | 84.4M | $71k |

Reading: nothing burns until the cap line reaches the holding (day ~16 at 25 days, day ~9 at 15 days); from then on **every PLEA sold back burns** (the daily burn equals the day's sells, not a percentage of supply) and its IMD share thickens the wall. 15 days burns ~16M more and builds ~$12k more wall over 45 days in this scenario, and starts a week earlier. Hidden cost of trims: each one removes liquidity from the market band (position IMD $232k → $202k at 25 days, → $190k at 15 days by day 45), so later buys move the price more; the IMD is not lost, it moves under the price as wall.

Live test note: on Sepolia a trim can be demonstrated within the hour: buy X PLEA, wait X / 32.8M days (1M PLEA ≈ 44 minutes), sell PLEA back → `Trimmed`. No live trim has fired in any run so far (volumes were tiny, the cap stayed above the holding).
