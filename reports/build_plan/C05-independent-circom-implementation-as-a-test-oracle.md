# C05 · Independent Circom implementation as a test oracle

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write the same Spend circuit in Circom 2 with circomlib's Poseidon, by an agent that has not seen the clean
implementation. It is never deployed. It exists so that two independent implementations can be compared:
differential.mjs feeds the same inputs to both witness generators and compares all fourteen public values.
Work only from the pinned commit of the project repository and the build specification (`reports/Murmuration
v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp; no schedule may count blocks. Screening epochs count from Params.GENESIS; caps, emissions and
the deposit window count from START, which the registry records at its first applied batch. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `circuit/circom/spend.circom`
- `circuit/circom/lib/`
- `circuit/circom/test/differential.mjs`
- `circuit/circom/package.json`
- `Makefile`

## Acceptance tests

1. `circom --inspect` and circomspect report no warning that is not listed and justified in circuit/circom/WARNINGS.md.
2. `make differential` runs 10,000 random valid inputs and 2,000 edge cases through both implementations with identical public outputs.
3. Every invalid input rejected by one implementation is rejected by the other (5,000 mutated inputs).
4. Constraint count is within 15% of the clean circuit's, or the difference is explained.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
