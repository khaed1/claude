# L01 · Canary script and record

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** B60, S02, S03
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write the canary's published script as a machine-readable list of steps covering the build specification's
three canary lists, and run.ts, which executes a step through the wallet module and appends the transaction
hash and the amounts paid to record.json. First list: lines the project completes as a user, each with the
expected amount to the base unit. Second list: lines that depend on screeners; the script records them when
they occur and never causes them. Under canary/fork/ write tests for the second list and for the paths that
cannot be reached on mainnet in the time: a launch with pools created for its first candidates; launch under
the gas rules in force; a batch in which more than 96 words set a bit; a stablecoin issuer freezing the pool
and freezing a depositor; the end of the two-year vesting; the 30-day screener wait and the 90-day bar; the
end of commits after deposits close. The script runs on the canary parameter file. Work only from the pinned
commit of the project repository and the build specification (`reports/Murmuration v4 specification.html`,
section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin,
pause, upgrade or setter may appear in any contract. Every duration is in seconds of block.timestamp; no
schedule may count blocks. Screening epochs count from Params.GENESIS; caps, emissions and the deposit window
count from START, which the registry records at its first applied batch. If the specification is ambiguous,
stop and report the ambiguity instead of choosing.

## Paths the job may write

- `canary/script.md`
- `canary/run.ts`
- `canary/record.json`
- `canary/fork/`
- `canary/README.md`

## Acceptance tests

1. Run against a local fork with canary parameters, every step of the first list completes and record.json has a transaction hash and an amount equal to the expected one for each.
2. A coverage check lists every external function selector of the Pool, FeeDistributor, Distribution and Token and the step that calls it; none is missing.
3. The first list includes a spend relayed for a fee in its own asset by a single-note wallet, an ETH payment refused and later claimed, a staker's USDT claim of the exact amount, and a restore from seed.
4. No step of the first list needs a screener's key, and the funds each step needs are listed and add up to at most 10 ETH in value through the third cap step.
5. Each fork test under canary/fork/ passes and its result is written to a file the README links.
6. canary/README.md states what a completed canary shows and what it does not, in the words of the specification.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run. Running the canary on mainnet is not part of this job and needs the lawyer's review first. It also needs
at least seven registered seats, which no job can arrange.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
