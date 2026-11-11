# B15 · Pool: fees, key announcements, size and gas report

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`, `gas-and-size-report`
**Depends on:** B14
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Add sweepFees (anyone, at most once per 86,400 seconds per asset and only when the fees are at least the
asset's smallest exit size; sends the fees to the distributor and calls notify), announce (event only) and the
views cap, checkpoints and isKnownRoot. The distributor's address comes from Addresses.sol and the token's
from Distribution.token(). Produce docs/gas-report.md with measured gas for deposit, activate, refund, roll, a
self-sent spend and a relayed spend, under today's rules and under the EIP-8037/8038 rules computed from the
storage operations each call performs. Work only from the pinned commit of the project repository and the
build specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity
0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. Every duration is in seconds of block.timestamp counted from Params.GENESIS; no schedule may count
blocks. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Pool.sol`

## Paths the job may write

- `src/Pool.sol`
- `test/PoolFees.t.sol`
- `docs/gas-report.md`

## Acceptance tests

1. sweepFees transfers exactly fees[asset], zeroes it, reverts if called twice within 86,400 seconds, and reverts below the smallest exit size.
2. announce writes no storage (state diff test).
3. Pool deployed size is at most 24,576 bytes (`make sizes`).
4. docs/gas-report.md lists, per function, measured gas, new slots, overwritten slots and the Glamsterdam estimate; the relayed spend estimate is under 1,600,000.
5. No Pool function sends an asset anywhere but a depositor, a recipient or relayer named in a verified call, or the distributor (a test enumerates every transfer site).

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
