# P05 · Automatic checkers on the Circom oracle

**Kind:** Proof · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C05
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Run the open-source analysers on the Circom implementation and record the results honestly: circomspect,
`circom --inspect`, Picus and CIVER (`--check_safety`) on each non-hash template, and zkFuzz on the full
circuit for one hour. Picus and CIVER are expected to time out on Poseidon and on the top level; record
`unknown` where they do. Work only from the pinned commit of the project repository and the build
specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30,
Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. Every duration is in seconds of block.timestamp; no schedule may count blocks. Screening epochs
count from Params.GENESIS; caps, emissions and the deposit window count from START, which the registry records
at its first applied batch. If the specification is ambiguous, stop and report the ambiguity instead of
choosing.

## Paths the job may write

- `circuit/analysis/run.sh`
- `circuit/analysis/REPORT.md`
- `circuit/analysis/out/`

## Acceptance tests

1. `circuit/analysis/run.sh` reproduces every result in out/ from pinned tool versions.
2. REPORT.md has one row per template and tool: safe, unsafe with counterexample, or unknown with the time limit used.
3. No template is reported safe unless the tool's own output says so (raw logs are in out/).
4. Any unsafe result or fuzzer counterexample is reproduced as a failing differential test in C05's suite.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run. These tools find bugs. They do not establish the relation or its lemmas, which is what P04 is for.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
