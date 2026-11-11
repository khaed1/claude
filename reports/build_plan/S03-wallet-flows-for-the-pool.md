# S03 · Wallet flows for the pool

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C06, C07
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the wallet module for the pool: deposit with an ownerCommit derived from the seed and a counter,
paying the value plus 0.2%; activate and refund; note discovery by trial decryption of Spent events from
snapshot files; building a spend (input selection, an empty input when one note is enough, the ETH fee note
for a relayed spend, optional reward claim) and proving it with prove.mjs; keeping a small shielded ETH note
for relay fees and topping it up; restore.ts, which rebuilds every note from the seed and chain events alone;
and plan.ts, which splits an amount into standard sizes, defaults deposits to standard sizes, and warns before
several exits go to one address. Work only from the pinned commit of the project repository and the build
specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30,
Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. Every duration is in seconds of block.timestamp counted from Params.GENESIS; no schedule may count
blocks. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `wallet/src/pool/deposit.ts`
- `wallet/src/pool/spend.ts`
- `wallet/src/pool/plan.ts`
- `wallet/src/pool/scan.ts`
- `wallet/src/pool/restore.ts`
- `wallet/test/pool.test.ts`

## Acceptance tests

1. The end-to-end scenario of B60 is driven entirely through this module against a local chain.
2. plan.ts splits every multiple of 0.005 ETH below 1,000 ETH into at most 16 standard sizes and never leaves a remainder of 0.005 ETH or more; a deposit of a standard size becomes a note of exactly that size.
3. restore.ts, given only the seed, recovers every note of the scenario with its value, accrued reward and index: activated deposits not yet spent, change, ETH fee change and reward notes.
4. A relayed spend with no usable ETH fee note is refused with a clear message, and the module offers a self-sent spend or a top-up.
5. A spend built against the previous checkpoint is rebuilt automatically when it would be stale.
6. The module warns when a planned set of exits to one address sums to within 1% of a single deposit by the same wallet.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
