# B15 · Pool: fees, key announcements, size and gas report

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`, `gas-and-size-report`
**Depends on:** B14
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Add sweepFees (anyone, once per 7,200 blocks per asset, sends fees to the distributor and calls notify),
announce (event only) and the views cap, checkpoint and isKnownRoot. Produce docs/gas-report.md with measured
gas for deposit, activate, refund and spend, today's rules and the EIP-8037/8038 rules computed from the
storage operations each call performs. Work only from the pinned commit of the project repository and the
build specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity
0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Pool.sol`

## Paths the job may write

- `src/Pool.sol`
- `test/PoolFees.t.sol`
- `docs/gas-report.md`

## Acceptance tests

1. sweepFees transfers exactly fees[asset], zeroes it, and reverts if called twice within 7,200 blocks.
2. announce writes no storage (state diff test).
3. Pool deployed size is at most 24,576 bytes (`make sizes`).
4. docs/gas-report.md lists, per function, measured gas, new slots, overwritten slots and the Glamsterdam estimate; the spend estimate is under 1,500,000.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
