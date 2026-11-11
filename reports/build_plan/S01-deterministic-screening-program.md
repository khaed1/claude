# S01 · Deterministic screening program

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** B21
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the screening program: parse a criteria file, read deposits, Flag events and list data from
finalized blocks as of the epoch's start from an RPC endpoint, evaluate the rules, and output the Batch and
its hash. upTo is the highest deposit id that was at least one day old at the epoch's start. words are the
full refusal bitmap of each word that differs from the registry's, in ascending order; if more than 96 differ,
the batch lists the first 96 and lowers upTo to just below the first deposit of the first word left out. Flags
count only from active screeners, lapse after 14 epochs, need max(3, one third of active screeners) and reach
only the address flagged. dataCid is the CIDv1 (raw, sha2-256) of a canonical JSON file naming every refusal
and its rule. Same inputs must give the same bytes on any machine: canonical ordering, fixed number formats,
no wall-clock time, no floating point. Work only from the pinned commit of the project repository and the
build specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity
0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. Every duration is in seconds of block.timestamp counted from Params.GENESIS; no schedule may count
blocks. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `node/src/screen/criteria.ts`
- `node/src/screen/batch.ts`
- `node/src/screen/data.ts`
- `node/test/determinism.test.ts`
- `node/criteria/sanctions-flags-and-hops.v3.json`
- `node/package.json`

## Acceptance tests

1. Two runs on different machines from the same recorded RPC responses produce byte-identical batch and explanation files (fixture replay test).
2. Each rule in the reference criteria file has a test with a deposit it refuses and one it allows.
3. A deposit made one second less than a day before the epoch's start is not covered; one made exactly a day before is.
4. With 97 changed words the batch lists 96 and upTo stops below the first deposit of the 97th; the next epoch's batch picks up the rest.
5. Two flags from active screeners out of nine refuse nothing; three do; the same three flags refuse nothing 15 epochs later; a flag on an address does not refuse deposits from addresses it sent funds to.
6. A reorg of unfinalized blocks changes nothing because only finalized data is read (test with a recorded reorg).
7. The batch hash equals the Solidity hash used by ScreenerRegistry.apply (shared vector).

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
