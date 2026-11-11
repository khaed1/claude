# F04 · Fuzz: distributor

**Kind:** Build · **IMD template:** `fuzz` · **Steps:** `write-foundry-tests`
**Depends on:** B32
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write one Foundry invariant harness, test/fuzz/Distributor.fuzz.sol, with handler functions for every external
function of the contract under test and ghost variables for the sums the invariants need. Run it for 1,000,000
calls. Mock verifiers accept every proof so that the harness explores the contract's own checks. Work only
from the pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp counted from Params.GENESIS; no schedule may count blocks. If the specification is ambiguous,
stop and report the ambiguity instead of choosing.

## Contracts named

- `test/fuzz/Distributor.fuzz.sol`

## Paths the job may write

- `test/fuzz/Distributor.fuzz.sol`

## Acceptance tests

1. Invariant holds over 1,000,000 calls: each receipt is split 40/40/20 with the remainder in the basket stream.
2. Invariant holds over 1,000,000 calls: balances cover streams, owed, basket and basket stream.
3. Invariant holds over 1,000,000 calls: buybackImd only ever decreases through the swap callback.
4. Invariant holds over 1,000,000 calls: a buyback step is at most half of fee rate times the locked position's virtual reserve, at most once per 43,200 seconds.
5. The handler reaches every external function at least 1,000 times (call summary in the output).

## Notes

IMD's fuzz template takes exactly one harness and a run count; this brief sets runs to 1,000,000.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
