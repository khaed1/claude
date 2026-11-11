# R05 · Review: launch, auction and buyback on a fork

**Kind:** Review · **IMD template:** `single` · **Steps:** `adversarial-review`
**Depends on:** B32, B41
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Adversarial review of the token's market mechanics on a mainnet fork with the real IMD token and Uniswap v3.
As a block builder who sees the launch transaction and can act before it in the same block: try to make launch
revert, run out of gas, or place the position at a wrong price, with bids above the start and with a block's
worth of dust positions. As anyone: try to learn the token's address before the launch block; try to take
value from a buyback step by any sequence of swaps and liquidity changes; try to enlarge a step by adding
liquidity or sending IMD to the pool; try to buy the basket below its value by manipulating the auction's
state; try to strand an asset in the basket. Report what a third party can gain and at what cost. This step
may write only the review test file.

## Paths the job may write

- `docs/reviews/R05-market.md`
- `test/review/Market.t.sol`

## Acceptance tests

1. Each attack attempted is a Foundry test in test/review/Market.t.sol with the attacker's profit asserted.
2. No attack shows a profit above gas cost, or the finding is filed as high.
3. The report states what a block builder must spend to block one launch attempt, and that nobody else can block it.
4. The report states what the launch caller gains by buying in the same transaction, in tokens and in dollars at the starting valuation.
5. The report lists the IMD token's owner powers that affect this market, including administration of its bridge peers on Ethereum.

## Notes

IMD's review skills are read-only by default; this brief needs a variant that may add one test file, or a
build job that writes the tests followed by a read-only review.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
