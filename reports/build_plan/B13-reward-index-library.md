# B13 · Reward index library

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** B00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement RewardIndex.sol: the accumulator g with 64 fractional bits, the weighted total, the divisor floor of
a quarter of capacity at the current cap step, emission per block per step in proportion to the caps,
released, and the 300-block checkpoints gCur and gPrev. accrueTo(block) must handle any number of cap-step
boundaries since the last call. g rounds down, released rounds up. Work only from the pinned commit of the
project repository and the build specification (`reports/Murmuration v4 specification.html`, section "Build
specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade
or setter may appear in any contract. If the specification is ambiguous, stop and report the ambiguity instead
of choosing.

## Contracts named

- `src/lib/RewardIndex.sol`

## Paths the job may write

- `src/lib/RewardIndex.sol`
- `test/RewardIndex.t.sol`

## Acceptance tests

1. g never decreases and stays below 2^90 over the whole schedule at the smallest possible weighted total (test at weighted = 0 and = 1).
2. released never exceeds the users' allocation; equality within 1e-9 relative when the pool is at or above the floor for the whole schedule.
3. Differential test: 10,000 fuzzed sequences of balance changes and block jumps match a Python reference in test/ref within rounding bounds stated in the test.
4. For any set of simulated notes, the sum of floor(weight*value*(gRef-index)/2^64) is at most released (invariant test).
5. After the last emission step g stops changing.
6. The checkpoint at an epoch boundary equals g at that block whether or not any call happened in the epoch before.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
