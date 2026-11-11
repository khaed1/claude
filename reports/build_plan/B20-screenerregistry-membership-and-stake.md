# B20 · ScreenerRegistry: membership and stake

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B10
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement register, activate, requestExit, withdrawStake and evict, with activeCount, joining and the per-
epoch snapshot taken at the first registry call of an epoch. register requires ownerOf(seatId) on the seat
contract to be the caller and takes Params.STAKE of the token, whose address is read from
Distribution.token(). Nobody is active before Params.SCREENER_WAIT epochs after registering, and there is no
shortcut at launch. activate(seatId) is then called by the holder or operator, checks the seat is still held,
and adds the screener to joining, which is folded into activeCount at the next snapshot. evict is open to
anyone when the seat's owner is no longer the registered holder (an ownerOf call that reverts counts as not
held), when the screener has not revealed for 7 epochs counted from the later of its last reveal and its first
active epoch, or when it has 7 consecutive misses (the counter is written by B21). Exit and eviction move the
stake to unbonding[holder], released 14 epochs later to that holder only, so a seat that changed hands can be
registered again at once. Work only from the pinned commit of the project repository and the build
specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30,
Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. Every duration is in seconds of block.timestamp counted from Params.GENESIS; no schedule may count
blocks. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/ScreenerRegistry.sol`

## Paths the job may write

- `src/ScreenerRegistry.sol`
- `test/RegistryMembership.t.sol`
- `test/mocks/MockSeat.sol`

## Acceptance tests

1. One registration per seat; a second reverts until the first has exited or been evicted, and succeeds straight after.
2. No screener counts in any snapshot before SCREENER_WAIT epochs after registering, including in epochs 0 to 7 after launch (fuzz over registration times).
3. activeCount changes only at a snapshot, an exit or an eviction, and equals the number of screeners activated and not exited or evicted (invariant test).
4. After the seat is transferred, commit by the old operator reverts and evict succeeds; a seat contract that reverts is treated as not held.
5. A screener that became active but never revealed is evictable 7 epochs after its first active epoch and not before.
6. withdrawStake reverts before 14 epochs and pays exactly the stake to the holder who posted it; no path reduces a stake.
7. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
