# R05 · Review: launch, auction and buyback on a fork

**Kind:** Review · **IMD template:** `single` · **Steps:** `adversarial-review`
**Depends on:** B32, B41
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Adversarial review of the token's market mechanics on a mainnet fork with the real IMD token and Uniswap v3:
try to make launch revert or place the position at a wrong price by acting first; try to take value from a
buyback step by any sequence of swaps and liquidity changes in the same block; try to buy the basket below its
value by manipulating the auction's state; try to strand an asset in the basket. Report what a third party can
gain and at what cost. This step may write only the review test file.

## Paths the job may write

- `docs/reviews/R05-market.md`
- `test/review/Market.t.sol`

## Acceptance tests

1. Each attack attempted is a Foundry test in test/review/Market.t.sol with the attacker's profit asserted.
2. No attack shows a profit above gas cost, or the finding is filed as high.
3. The report quantifies the cost to delay launch by pre-creating the pool with real liquidity.
4. The report lists the IMD token's owner powers that affect this market, including bridge-side minting.

## Notes

IMD's review skills are read-only by default; this brief needs a variant that may add one test file, or a
build job that writes the tests followed by a read-only review.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
