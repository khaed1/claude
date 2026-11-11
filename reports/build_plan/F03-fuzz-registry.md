# F03 · Fuzz: registry

**Kind:** Build · **IMD template:** `fuzz` · **Steps:** `write-foundry-tests`
**Depends on:** B22
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write one Foundry invariant harness, test/fuzz/Registry.fuzz.sol, with handler functions for every external
function of the contract under test and ghost variables for the sums the invariants need. Run it for 1,000,000
calls. Mock verifiers accept every proof so that the harness explores the contract's own checks. Work only
from the pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp; no schedule may count blocks. Screening epochs count from Params.GENESIS; caps, emissions and
the deposit window count from START, which the registry records at its first applied batch. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `test/fuzz/Registry.fuzz.sol`

## Paths the job may write

- `test/fuzz/Registry.fuzz.sol`

## Acceptance tests

1. Invariant holds over 1,000,000 calls: at most one accepted batch per epoch, and only with two thirds of the snapshot count and at least seven.
2. Invariant holds over 1,000,000 calls: no deposit younger than one day at the last applied batch's data time is approved or refused, and activeCount equals the number of active records.
3. Invariant holds over 1,000,000 calls: token and fee balances cover pots, owed, stakes and unbonding stakes.
4. Invariant holds over 1,000,000 calls: a stake is returned once, to its holder.
5. The handler reaches every external function at least 1,000 times (call summary in the output).

## Notes

IMD's fuzz template takes exactly one harness and a run count; this brief sets runs to 1,000,000.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
