# B20 · ScreenerRegistry: membership and stake

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B10
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement register, requestExit, withdrawStake and evict, with the active count and its per-epoch snapshot.
register requires ownerOf(seatId) on the seat contract to be the caller and takes Params.STAKE. A screener
counts from epoch registered + 30, or from epoch 7 if registered before epoch 7. evict is open to anyone when
the seat's owner is no longer the registered holder, when the screener has not revealed for 7 epochs, or when
it has missed 7 accepted batches. Stakes return 14 epochs after exit or eviction, to the holder only. Work
only from the pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. If the specification is
ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/ScreenerRegistry.sol`

## Paths the job may write

- `src/ScreenerRegistry.sol`
- `test/RegistryMembership.t.sol`
- `test/mocks/MockSeat.sol`

## Acceptance tests

1. One registration per seat; a second reverts until the first has exited or been evicted.
2. A screener registered in epoch e >= 7 is not counted before epoch e + 30; one registered in epochs 0-6 counts from epoch 7.
3. After the seat is transferred, commit by the old operator reverts and evict succeeds.
4. withdrawStake reverts before 14 epochs and pays exactly the stake to the registered holder afterwards; no path reduces a stake.
5. activeCount equals the number of screeners that are registered, past their start epoch and not exited or evicted (invariant test).
6. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
