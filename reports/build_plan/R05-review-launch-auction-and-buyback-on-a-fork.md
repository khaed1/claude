# R05 · Review: launch, auction and buyback on a fork

**Kind:** Review · **IMD template:** `single` · **Steps:** `adversarial-review`
**Depends on:** B32, B41
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Adversarial review of the token's market mechanics on a mainnet fork with the real IMD token and Uniswap v3.
Launch: as anyone who sees the launch transaction, including a block builder and a proposer who knows the next
block's randomness, try to make launch revert, run out of gas or place the position wrongly, by creating pools
for its candidate addresses; measure what each blocked candidate costs and how many fit in a block. Buyback:
try to take value from a step by any sequence of swaps and liquidity changes; try to shrink or enlarge a step,
including with the price parked below the range; measure what a holder gains by adding liquidity for one
transaction. Auction: try to buy the basket below its value or strand an asset in it. Report what a third
party can gain and at what cost. This step may write only the review test file.

## Paths the job may write

- `docs/reviews/R05-market.md`
- `test/review/Market.t.sol`

## Acceptance tests

1. Each attack attempted is a Foundry test in test/review/Market.t.sol with the attacker's profit asserted.
2. No attack blocks launch at a cost under that of creating pools for every qualifying candidate, and the report gives that cost in gas for a 60M and a 100M block.
3. No attack shows a profit above gas cost with the price inside the locked range, or the finding is filed as high. What a sandwich or a one-transaction liquidity provider takes below or at the edge of the range is measured and reported.
4. The report states what the launch caller gains by buying in the same transaction, in tokens and in dollars at the starting valuation.
5. The report lists the IMD token's owner powers that affect this market, including administration of its bridge peers on Ethereum, and whether Uniswap's protocol fee is on for this pool.

## Notes

IMD's review skills are read-only by default; this brief needs a variant that may add one test file, or a
build job that writes the tests followed by a read-only review.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
