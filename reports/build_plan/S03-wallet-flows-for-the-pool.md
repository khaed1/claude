# S03 · Wallet flows for the pool

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C06, C07
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the wallet module for the pool and the wallet rules of the build specification: deposit with an
ownerCommit derived from the seed and a counter, paying the value plus 0.2%; activate and refund; note
discovery from snapshot files by trying the ciphertext-1 key and the X-Wing key on every Spent event; building
a spend (input selection, empty inputs filled at random, optional reward claim) and proving it with prove.mjs.
One proving policy: always the checkpoint root and gCur; roll first when the current window has no checkpoint;
wait for the next roll before spending a newer note. Fee asset: ETH from a small fee note when the wallet has
one, otherwise the asset being spent, with a notice that this shows the asset. Quotes: refuse one above the
fee ceiling less a margin, and never hand the same inputs to a second relayer before the first quote has
expired. restore.ts rebuilds every note from the seed and chain events alone, with a gap limit of 20 deposit
counters. plan.ts splits an amount into standard sizes, defaults deposits to standard sizes, warns before
several exits go to one address and before reward tokens are withdrawn to an address linked to other exits.
The long address is the default; the short one needs announce and a warning about what it reveals. Work only
from the pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp; no schedule may count blocks. Screening epochs count from Params.GENESIS; caps, emissions and
the deposit window count from START, which the registry records at its first applied batch. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

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
3. restore.ts, given only the seed, recovers every note of the scenario with its value, accrued reward and index: activated deposits not yet spent, change, fee change and reward notes, including when several deposits carry one ownerCommit.
4. A wallet holding a single USDT note completes a relayed withdrawal with change and pays the fee in USDT; a wallet holding an ETH fee note pays in ETH.
5. Every proof in a 200-spend test uses the checkpoint root and gCur; none mixes policies.
6. A quote above the ceiling is refused before proving, and a second relayer is not given the same nullifiers while a quote is live.
7. The module warns when a planned set of exits to one address sums to within 1% of a single deposit by the same wallet.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
