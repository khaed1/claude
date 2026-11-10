# S01 · Deterministic screening program

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** B21
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the screening program: parse a criteria file, read deposits, Flag events and list data at the
epoch's first block from an RPC endpoint, evaluate the rules, and output the Batch (upTo, the refusal bitmap
words that differ from on-chain state, dataCid of the explanation file) and its hash. Same inputs must give
the same bytes on any machine: canonical ordering, fixed number formats, no wall-clock time, no floating
point. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `node/src/screen/criteria.ts`
- `node/src/screen/batch.ts`
- `node/src/screen/data.ts`
- `node/test/determinism.test.ts`
- `node/criteria/sanctions-flags-and-hops.v2.json`
- `node/package.json`

## Acceptance tests

1. Two runs on different machines from the same recorded RPC responses produce byte-identical batch and explanation files (fixture replay test).
2. Each rule in the reference criteria file has a test with a deposit it refuses and one it allows.
3. The explanation file names, for every refused deposit, the rule and the evidence.
4. A reorg of the epoch's first block before finality changes nothing because only finalized data is read (test with a recorded reorg).
5. The batch hash equals the Solidity hash used by ScreenerRegistry.apply (shared vector).

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
