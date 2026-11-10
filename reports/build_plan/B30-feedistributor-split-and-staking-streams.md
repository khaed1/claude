# B30 · FeeDistributor: split and staking streams

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B10, B22
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement notify(asset, amount), callable by the Pool only, splitting each receipt 40/40/20: 40% into that
asset's staker stream restarted to pay evenly over the next 50,400 blocks, 40% sent to the registry with fund,
20% to basket[asset]; for the project token the 20% goes to the burn address; with nothing staked the stakers'
40% goes to the basket. Implement stake, unstake and claim with reward-per-token accounting per asset. Work
only from the pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. If the specification is
ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/FeeDistributor.sol`

## Paths the job may write

- `src/FeeDistributor.sol`
- `test/DistributorStaking.t.sol`

## Acceptance tests

1. The three parts of every notify add up to the amount, with any remainder in the basket (fuzz).
2. A staker who stakes one block before a notify and unstakes one block after earns at most 2/50,400 of that receipt's staker share.
3. Two stakers with equal stake over the same blocks earn equal amounts within 1 wei per asset.
4. For each asset, balance >= unpaid stream + sum owed + basket after every call (invariant test).
5. Staked tokens return only to their staker; unstake of more than staked reverts.
6. notify from any address but the Pool reverts.
7. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
