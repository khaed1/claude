# B13 · Reward index library

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** B00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement RewardIndex.sol exactly as the reward-index box of the build specification: t = now - START; step =
min(t / 90 days, LAST_STEP) in every formula; cap(a) = cap0(a) * 2^step; an emission rate per second of USERS
* 2^step / D while t < 730 days and zero afterwards, where D is the sum of 2^step over the 730 days; g with 64
fractional bits, rounded down and held at 2^90 - 1; released rounded up and never above USERS; weighted over
ETH, USDT, USDC and IMD with the integer weights; the floor of a quarter of weighted capacity. Nothing
advances before START is known. roll(): reads START from the registry if it is still zero and does nothing
more while it is zero; otherwise, if no checkpoint was taken in the current hourly window, advances g to now,
then sets gPrev = gCur and gCur = g and records the window. Exactly one shift per call, however many windows
have passed. roll never reverts. Work only from the pinned commit of the project repository and the build
specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30,
Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. Every duration is in seconds of block.timestamp; no schedule may count blocks. Screening epochs
count from Params.GENESIS; caps, emissions and the deposit window count from START, which the registry records
at its first applied batch. If the specification is ambiguous, stop and report the ambiguity instead of
choosing.

## Contracts named

- `src/lib/RewardIndex.sol`

## Paths the job may write

- `src/lib/RewardIndex.sol`
- `test/RewardIndex.t.sol`
- `test/ref/reward_index.py`

## Acceptance tests

1. g never decreases and stays below 2^90 over the whole schedule at the smallest possible weighted total (test at weighted = 0 and = 1), for the mainnet and the canary parameter files.
2. With parameters chosen to overflow, g stops at 2^90 - 1, released stops growing, and roll, activate and spend keep working.
3. released never exceeds the users' allocation; equality within 1e-9 relative when the pool is at or above the floor for the whole 730 days.
4. Differential test: 10,000 fuzzed sequences of balance changes and time jumps match the Python reference in test/ref within rounding bounds stated in the test.
5. For any set of simulated notes, the sum of floor(weight*value*(gRef-index)/2^64) is at most released (invariant test).
6. After any idle time, including 20 years, one roll leaves gPrev equal to the old gCur and gCur equal to g; a second roll in the same window changes nothing; roll does not revert in any reachable state (fuzz).
7. Before START nothing is emitted and caps are those of step 0; after 730 days g stops changing and roll still rotates.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
