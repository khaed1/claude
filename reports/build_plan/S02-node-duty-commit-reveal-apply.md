# S02 · Node duty: commit, reveal, apply

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** S01
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the screener duty for the node: call activate once the waiting period has passed; each epoch run S01
against the published test vectors first and refuse to commit if any fails; commit in the first 12 hours with
a fresh salt kept on disk; reveal in hours 12 to 20; call apply as soon as a batch is accepted and before the
epoch ends; withdraw pay on request. The duty warns its operator when its batch differs from the recorded
majority hash and shows its strike count and how far it is from 14. It runs under its own Unix user with its
own operator key and never reads IMD's worker files. It makes no call to api.imd.fun. Work only from the
pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp; no schedule may count blocks. Screening epochs count from Params.GENESIS; caps, emissions and
the deposit window count from START, which the registry records at its first applied batch. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `node/src/duty/screener.ts`
- `node/src/duty/schedule.ts`
- `node/test/duty.test.ts`
- `node/README.md`

## Acceptance tests

1. Against a local chain with the contracts from B22, ten simulated nodes reach acceptance and apply the batch inside every epoch of a 20-epoch test.
2. A node restarted between commit and reveal still reveals the committed batch (salt persisted).
3. A node whose RPC returns different data from the others reveals a different hash, is not paid, and logs a warning with its strike count each epoch.
4. With four of ten nodes silent six days in seven, the four become evictable within ten epochs and acceptance is daily again after they are evicted.
5. If no node applies an accepted batch before the epoch ends, nobody is paid for it and the next epoch's batch covers the same deposits.
6. No outbound request goes to any host other than the configured RPC and IPFS endpoints (network mock).

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
