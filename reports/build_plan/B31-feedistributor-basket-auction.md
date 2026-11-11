# B31 · FeeDistributor: basket auction

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** B30
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement buy(assets, to, saleId, deadline, maxPay): the price falls linearly from the starting price to
Params.AUCTION_FLOOR over 7,200 blocks and stays at the floor; the buyer pays the price in IMD, which is added
to buybackImd; the buyer receives basket[asset] of each asset named; the next starting price is twice the
price paid and at least Params.AUCTION_MIN_START. The design follows Euler's FeeFlowController (GPL-2.0-or-
later, audited) with two changes: a non-zero floor, and explicit basket balances instead of whole balances.
Work only from the pinned commit of the project repository and the build specification (`reports/Murmuration
v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. If the specification is
ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/FeeDistributor.sol`

## Paths the job may write

- `src/FeeDistributor.sol`
- `test/DistributorAuction.t.sol`

## Acceptance tests

1. Price at block offsets 0, 3,600, 7,200 and 100,000 equals start, the midpoint, floor and floor.
2. buy reverts on a stale saleId, a passed deadline, or a price above maxPay.
3. The buyer receives exactly basket[asset] for each named asset and nothing of the staker streams or stakes.
4. A sale that names all assets but one whose transfer reverts (blocklist mock) succeeds when that asset is left out.
5. After a sale at price x the next starting price is max(2x, AUCTION_MIN_START).
6. Re-entrancy through an ETH payout or a token callback cannot reach buy, claim or unstake.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
