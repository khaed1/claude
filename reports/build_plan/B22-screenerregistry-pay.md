# B22 · ScreenerRegistry: pay

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** B21
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement fund(asset, amount) from the distributor, the per-asset pot, and the 16-slot ring. Each slot is
tagged with its epoch and cleared when reused, and holds the accepted hash, the majority hash, how many agreed
and the pay per head in each asset. At the first registry call after an epoch with an accepted batch, the pot
and one share of the screeners' token budget are divided equally among the screeners who revealed that batch.
The budget is paid in 730 equal shares, one per accepted epoch (paidEpochs counts them), so an epoch without a
batch delays its share and does not destroy it. A screener is credited at its next commit, exit, eviction or
withdrawPay, within 16 epochs. Expose lastAccepted for the distributor. Work only from the pinned commit of
the project repository and the build specification (`reports/Murmuration v4 specification.html`, section
"Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause,
upgrade or setter may appear in any contract. Every duration is in seconds of block.timestamp counted from
Params.GENESIS; no schedule may count blocks. If the specification is ambiguous, stop and report the ambiguity
instead of choosing.

## Contracts named

- `src/ScreenerRegistry.sol`

## Paths the job may write

- `src/ScreenerRegistry.sol`
- `test/RegistryPay.t.sol`

## Acceptance tests

1. Each screener who revealed the accepted batch is credited pot/agreed for every asset; others are credited nothing.
2. Fees received in an epoch with no accepted batch stay in the pot and are paid in the next accepted epoch.
3. After 730 accepted epochs the token paid equals SCREENER_BUDGET less rounding and never exceeds it, however many epochs had no batch in between.
4. For each asset, balance >= pot + sum of owed, plus stakes, unbonding stakes and the unpaid budget for the token, after every call (invariant test).
5. A ring slot is read only when its tag matches: a screener that settles after more than 16 epochs gets nothing for the overwritten epoch and never another epoch's pay.
6. A screener that exits or is evicted is settled before its record changes.
7. Registry deployed size is at most 24,576 bytes.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
