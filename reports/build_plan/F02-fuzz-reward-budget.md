# F02 · Fuzz: reward budget

**Kind:** Build · **IMD template:** `fuzz` · **Steps:** `write-foundry-tests`
**Depends on:** B14
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write one Foundry invariant harness, test/fuzz/RewardBudget.fuzz.sol, with handler functions for every
external function of the contract under test and ghost variables for the sums the invariants need. Run it for
1,000,000 calls. Mock verifiers accept every proof so that the harness explores the contract's own checks.
Work only from the pinned commit of the project repository and the build specification (`reports/Murmuration
v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp; no schedule may count blocks. Screening epochs count from Params.GENESIS; caps, emissions and
the deposit window count from START, which the registry records at its first applied batch. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `test/fuzz/RewardBudget.fuzz.sol`

## Paths the job may write

- `test/fuzz/RewardBudget.fuzz.sol`

## Acceptance tests

1. Invariant holds over 1,000,000 calls: the sum of reward computable by all live simulated notes plus reward already claimed is at most released.
2. Invariant holds over 1,000,000 calls: released is at most the users' allocation.
3. Invariant holds over 1,000,000 calls: g is monotone and below 2^90, and gCur and gPrev are never above g.
4. Invariant holds over 1,000,000 calls: a note created and spent inside one checkpoint window earns zero.
5. The handler reaches every external function at least 1,000 times (call summary in the output).

## Notes

IMD's fuzz template takes exactly one harness and a run count; this brief sets runs to 1,000,000.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
