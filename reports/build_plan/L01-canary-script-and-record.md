# L01 · Canary script and record

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** B60, S02, S03
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write the canary's published script as a machine-readable list of steps covering every item in the build
specification's canary checklist, and run.ts, which executes a step through the wallet and node modules and
appends the transaction hash to record.json. The script must reach every external function of the six
contracts and each of the six circuit scenarios, on the canary parameter file. Work only from the pinned
commit of the project repository and the build specification (`reports/Murmuration v4 specification.html`,
section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin,
pause, upgrade or setter may appear in any contract. If the specification is ambiguous, stop and report the
ambiguity instead of choosing.

## Paths the job may write

- `canary/script.md`
- `canary/run.ts`
- `canary/record.json`
- `canary/README.md`

## Acceptance tests

1. Run against a local fork with canary parameters, every step completes and record.json has a transaction hash for each.
2. A coverage check lists every external function selector of the six contracts and the step that calls it; none is missing.
3. The script includes the third-party pre-created pool case, a full-cap activation failure, an epoch with no accepted batch, and spends after deposits close.
4. canary/README.md states what a completed canary shows and what it does not.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run. Running the canary on mainnet is not part of this job and needs the lawyer's review first.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
