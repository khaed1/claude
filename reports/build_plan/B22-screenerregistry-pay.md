# B22 · ScreenerRegistry: pay

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** B21
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement fund(asset, amount) from the distributor, the per-asset pot, the 16-epoch ring of accepted batch,
agree count and pay per head, settlement of a screener's previous reveal at its next commit, withdrawPay, and
the token stream: each accepted epoch within the first 730 adds SCREENER_BUDGET/730 to the token pot; an epoch
with no accepted batch adds nothing and its share stays locked. Work only from the pinned commit of the
project repository and the build specification (`reports/Murmuration v4 specification.html`, section "Build
specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade
or setter may appear in any contract. If the specification is ambiguous, stop and report the ambiguity instead
of choosing.

## Contracts named

- `src/ScreenerRegistry.sol`

## Paths the job may write

- `src/ScreenerRegistry.sol`
- `test/RegistryPay.t.sol`

## Acceptance tests

1. Each screener who revealed the accepted batch is credited pot/agreed for every asset; others are credited nothing.
2. Fees received in an epoch with no accepted batch are paid in the next accepted epoch; the token share of that epoch is never paid.
3. For each asset, balance >= pot + sum of owed (+ stakes and the unpaid budget for the token) after every call (invariant test).
4. A screener that settles after more than 16 epochs gets nothing for the overwritten epoch and nothing reverts.
5. Total token paid to screeners never exceeds SCREENER_BUDGET.
6. Registry deployed size is at most 24,576 bytes.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
