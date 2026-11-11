# B31 · FeeDistributor: basket auction

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** B30
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the basket stream and buy(assets, to, saleId, deadline, maxPay). Each receipt's 20% is released into
basket[asset] evenly over 604,800 seconds. The price falls linearly from the starting price to
Params.AUCTION_FLOOR over 86,400 seconds and stays at the floor; the first sale's clock starts at the first
notify. The buyer names assets by id, must receive something, pays the price in IMD, which is added to
buybackImd, and receives the released basket balance of each asset named. The next starting price is twice the
price paid and at least Params.AUCTION_MIN_START. The design follows Euler's FeeFlowController (GPL-2.0-or-
later, audited) with three changes: a non-zero floor, explicit basket balances instead of whole balances, and
the seven-day release. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. Every
duration is in seconds of block.timestamp; no schedule may count blocks. Screening epochs count from
Params.GENESIS; caps, emissions and the deposit window count from START, which the registry records at its
first applied batch. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/FeeDistributor.sol`

## Paths the job may write

- `src/FeeDistributor.sol`
- `test/DistributorAuction.t.sol`

## Acceptance tests

1. Price at offsets 0, 43,200, 86,400 and 1,000,000 seconds equals start, the midpoint, floor and floor.
2. After one notify the released basket at time t is 20% of the receipt times min(t, 604,800)/604,800, within 1 wei.
3. buy reverts before the first notify, on a stale saleId, a passed deadline, a price above maxPay, or when the buyer would receive nothing.
4. The buyer receives exactly the released basket of each named asset and nothing of the unreleased stream, the staker streams or the stakes.
5. A sale that names all assets but one whose transfer reverts (blocklist mock) succeeds when that asset is left out.
6. After a sale at price x the next starting price is max(2x, AUCTION_MIN_START).
7. Re-entrancy through an ETH payout or a token callback cannot reach buy, claim or unstake.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
