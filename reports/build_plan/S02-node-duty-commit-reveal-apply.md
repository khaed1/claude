# S02 · Node duty: commit, reveal, apply

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** S01
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the screener duty for the node: each epoch run S01, commit in the commit window with a fresh salt
kept on disk, reveal in the reveal window, call apply when a batch is accepted and not yet applied, and
withdraw pay on request. The duty runs under its own Unix user with its own operator key and never reads IMD's
worker files. It makes no call to api.imd.fun. Work only from the pinned commit of the project repository and
the build specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity
0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `node/src/duty/screener.ts`
- `node/src/duty/schedule.ts`
- `node/test/duty.test.ts`
- `node/README.md`

## Acceptance tests

1. Against a local chain with the contracts from B22, ten simulated nodes reach acceptance in every epoch of a 20-epoch test.
2. A node restarted between commit and reveal still reveals the committed batch (salt persisted).
3. A node whose RPC returns different data from the others reveals a different hash and the test shows it is not paid.
4. No outbound request goes to any host other than the configured RPC and IPFS endpoints (network mock).

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
