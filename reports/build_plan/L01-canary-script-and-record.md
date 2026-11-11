# L01 · Canary script and record

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** B60, S02, S03
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write the canary's published script as a machine-readable list of steps covering every line of the build
specification's canary checklist, and run.ts, which executes a step through the wallet and node modules and
appends the transaction hash to record.json. The script runs on the canary parameter file and must reach every
external function of the contracts and each of the seven circuit scenarios. Write, under canary/fork/, the
tests for the paths the specification says cannot be reached on mainnet in 90 days: a launch that a block
builder front-runs with bids and with a block's worth of ticks, a batch with more than 96 changed words, a
stablecoin issuer freezing the pool, the end of the two-year vesting, and the 30-day screener wait. Work only
from the pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp counted from Params.GENESIS; no schedule may count blocks. If the specification is ambiguous,
stop and report the ambiguity instead of choosing.

## Paths the job may write

- `canary/script.md`
- `canary/run.ts`
- `canary/record.json`
- `canary/fork/`
- `canary/README.md`

## Acceptance tests

1. Run against a local fork with canary parameters, every step completes and record.json has a transaction hash for each.
2. A coverage check lists every external function selector of the contracts and the step that calls it; none is missing.
3. The script includes: a refused deposit refunded by its depositor and another by a third party; an activation that fails at a full cap and succeeds after a withdrawal; an epoch with no accepted batch; evictions for silence, for seven misses and for a transferred seat; a restore from seed; spends and refunds after deposits close.
4. The funds the script needs at each step are listed, and the canary's caps can be filled with them.
5. Each fork test under canary/fork/ passes and its result is written to a file the README links.
6. canary/README.md states what a completed canary shows and what it does not.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run. Running the canary on mainnet is not part of this job and needs the lawyer's review first. It also needs
at least seven seat holders willing to stake a canary token, which no job can arrange.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
