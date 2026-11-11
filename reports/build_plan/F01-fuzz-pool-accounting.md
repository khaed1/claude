# F01 · Fuzz: pool accounting

**Kind:** Build · **IMD template:** `fuzz` · **Steps:** `write-foundry-tests`
**Depends on:** B15
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write one Foundry invariant harness, test/fuzz/PoolAccounting.fuzz.sol, with handler functions for every
external function of the contract under test and ghost variables for the sums the invariants need. Run it for
1,000,000 calls. Mock verifiers accept every proof so that the harness explores the contract's own checks.
Work only from the pinned commit of the project repository and the build specification (`reports/Murmuration
v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp counted from Params.GENESIS; no schedule may count blocks. If the specification is ambiguous,
stop and report the ambiguity instead of choosing.

## Contracts named

- `test/fuzz/PoolAccounting.fuzz.sol`

## Paths the job may write

- `test/fuzz/PoolAccounting.fuzz.sol`

## Acceptance tests

1. Invariant holds over 1,000,000 calls: balance >= pending + shielded + fees for every capped asset, and for the token >= pending + fees + tokenIn - tokenOut.
2. Invariant holds over 1,000,000 calls: withdrawn <= activated per asset, and for the token tokenOut <= tokenIn + released.
3. Invariant holds over 1,000,000 calls: shielded <= cap at the time it last grew.
4. Invariant holds over 1,000,000 calls: each deposit id ends activated or refunded at most once, and a refund always pays the depositor.
5. The handler reaches every external function at least 1,000 times (call summary in the output).

## Notes

IMD's fuzz template takes exactly one harness and a run count; this brief sets runs to 1,000,000.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
