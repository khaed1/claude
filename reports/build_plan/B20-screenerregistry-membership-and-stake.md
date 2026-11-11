# B20 · ScreenerRegistry: membership and stake

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B10
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement register, activate, requestExit, withdrawStake and evict, with activeCount, joining and the
snapshot. Every state-changing function begins by closing the previous epoch if that has not been done;
closing folds joining into activeCount and fixes snapActive (B21 and B22 add the rest of closing). register
requires ownerOf(seatId) on the seat contract to be the caller and the seat not to be barred; if the seat has
a record under an earlier holder that record is evicted first, in full; if it has a record under the caller it
reverts. It takes Params.STAKE of the token, read from Distribution.token(). activate(seatId) is open to the
holder or operator from Params.SCREENER_WAIT epochs after registering, checks the seat is still held, and adds
the screener to joining, so it counts from the next epoch. evict is open to anyone and, after settling,
removes the screener when the seat's owner is no longer the registered holder (an ownerOf call that reverts
counts as not held), when it has not revealed for 7 epochs counted from the later of its last reveal and its
first active epoch, or when it has 14 strikes (the counter is written by B21). For the last two grounds
barredUntil[seatId] is set 90 epochs ahead. Exit and eviction move the stake to unbonding[holder], one total
per holder, released 14 epochs after the latest addition. Work only from the pinned commit of the project
repository and the build specification (`reports/Murmuration v4 specification.html`, section "Build
specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade
or setter may appear in any contract. Every duration is in seconds of block.timestamp; no schedule may count
blocks. Screening epochs count from Params.GENESIS; caps, emissions and the deposit window count from START,
which the registry records at its first applied batch. If the specification is ambiguous, stop and report the
ambiguity instead of choosing.

## Contracts named

- `src/ScreenerRegistry.sol`

## Paths the job may write

- `src/ScreenerRegistry.sol`
- `test/RegistryMembership.t.sol`
- `test/mocks/MockSeat.sol`

## Acceptance tests

1. One live record per seat. register by a new owner over an old record leaves activeCount equal to the number of active records and moves the old stake to the old holder's unbonding; register by the same holder twice reverts.
2. No screener counts in any snapshot before SCREENER_WAIT + 1 epochs after registering, including in the first epochs after launch (fuzz over registration times).
3. activeCount equals the number of active records after every call (invariant test with seat transfers, exits, evictions and re-registrations in the handler).
4. After the seat is transferred, commit by the old operator reverts and evict succeeds; a seat contract that reverts is treated as not held.
5. A seat evicted for silence or strikes cannot be registered for 90 epochs, by any holder; a seat evicted because it changed hands can be registered at once.
6. withdrawStake reverts before 14 epochs and pays exactly the stakes to the holder who posted them; no path reduces a stake.
7. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
