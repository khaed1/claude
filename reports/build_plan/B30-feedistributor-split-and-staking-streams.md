# B30 · FeeDistributor: split and staking streams

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B10, B22
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement notify(asset), callable by the Pool only. The receipt is what actually arrived: the balance less
accounted[asset]. It is split 40/40/20. The stakers' 40% joins that asset's stream: what is left of the stream
plus the new amount, paid evenly over the next 604,800 seconds. The screeners' 40% goes to the registry with
fund(asset) when the registry's lastApplied is the current epoch or the one before, and otherwise joins the
staker stream. The last 20% joins basketStream[asset], which B31 releases into the basket; for the project
token it goes to the burn address, and for IMD it is added to buybackImd, a balance kept apart from IMD owed
to stakers. With nothing staked, whatever would go to stakers follows the 20%. Implement fundBuyback(amount),
and stake, unstake and claim with reward-per-token accounting per asset in which the per-token figure is
scaled by 10^36 and the rate by 10^18. While nothing is staked a stream's clock stops and resumes at the next
stake. Transfers use SafeTransfer.sol. Work only from the pinned commit of the project repository and the
build specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity
0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. Every duration is in seconds of block.timestamp; no schedule may count blocks. Screening epochs
count from Params.GENESIS; caps, emissions and the deposit window count from START, which the registry records
at its first applied batch. If the specification is ambiguous, stop and report the ambiguity instead of
choosing.

## Contracts named

- `src/FeeDistributor.sol`

## Paths the job may write

- `src/FeeDistributor.sol`
- `test/DistributorStaking.t.sol`

## Acceptance tests

1. The three parts of every notify add up to the receipt, with any remainder in the basket stream (fuzz), and the receipt is the measured balance increase even when the token takes a fee on transfer.
2. Six-decimal asset: with the whole supply staked and one receipt of 1 USDT, stakers can claim the staker share to within one base unit per update, however often the stream is updated (fuzz over update times).
3. A staker who stakes 12 seconds before a notify and unstakes 12 seconds after earns at most 24/604,800 of that receipt's staker share.
4. A stream that runs while nothing is staked pays out in full to later stakers; nothing is stranded (test with a gap of 30 days).
5. For each asset, balance >= accounted after every call (invariant test).
6. The screeners' 40% goes to the registry only when lastApplied is the current or the previous epoch, and to stakers otherwise, including for ever after commits stop.
7. notify from any address but the Pool reverts. For IMD the 20% lands in buybackImd, never in the basket, and buybackImd never overlaps IMD owed to stakers (invariant test).
8. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
