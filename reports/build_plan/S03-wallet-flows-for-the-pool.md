# S03 · Wallet flows for the pool

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C06, C07
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the wallet module for the pool: deposit with a fresh ownerCommit, activate and refund; note
discovery by trial decryption of Spent events from snapshot files; building a spend (input selection, padding,
relay fee note, optional reward claim) and proving it with prove.mjs; and plan.ts, which splits an amount into
standard sizes, defaults deposits to standard sizes grossed up for the entry fee, and warns before several
exits go to one address. Work only from the pinned commit of the project repository and the build
specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30,
Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `wallet/src/pool/deposit.ts`
- `wallet/src/pool/spend.ts`
- `wallet/src/pool/plan.ts`
- `wallet/src/pool/scan.ts`
- `wallet/test/pool.test.ts`

## Acceptance tests

1. The end-to-end scenario of B60 is driven entirely through this module against a local chain.
2. plan.ts splits every amount from 0.001 to 1,000 ETH into at most 18 standard sizes and never leaves dust above the smallest size.
3. A wallet restored from its seed alone recovers every note and its accrued reward from chain data.
4. A spend built against the previous checkpoint is rebuilt automatically when it would be stale.
5. The module warns when a planned set of exits to one address sums to within 1% of a single deposit by the same wallet.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
