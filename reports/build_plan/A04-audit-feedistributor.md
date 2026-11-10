# A04 · Audit: FeeDistributor

**Kind:** Audit · **IMD template:** `audit` · **Steps:** `audit (four specialists and a judge, added by IMD)`
**Depends on:** B32
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Audit the named contracts at the pinned commit against the build specification. They are immutable once
deployed: there is no owner, pause or upgrade, so every finding that would normally be fixed by an admin is a
permanent loss. What worries us most: staking reward sniping, a blocked or underpriced basket sale, IMD
leaving except through the pool swap, and extraction around a buyback step. Check every invariant listed for
these contracts in the build specification and say for each whether it holds, with the test or trace that
shows it. Token behaviours to assume: USDC can blocklist any address including these contracts; DAI is plain;
the project token is plain.

## Contracts named

- `src/FeeDistributor.sol`

## Paths the job may write

- `(read-only; report at /jobs/:id/report.md)`

## Acceptance tests

1. The judge's coverage record has one row per external function: holds, finding, or unreached.
2. Each invariant of the build specification for these contracts has a verdict and evidence.
3. Every finding has a severity, file and line, a reproduction, and where possible a Foundry proof.
4. No high or critical finding is open at sign-off; each fix goes through fix-findings and a second audit of the changed contract.

## Notes

IMD's audit template covers Solidity only: four specialists (math, permissions, economics, control flow) and a
judge. It names at most four contracts per request.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
