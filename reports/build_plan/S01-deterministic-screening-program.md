# S01 · Deterministic screening program

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** B21
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the screening program for the criteria file and the Batch rules in the specification. The base block
is the last block whose timestamp is before the epoch's start, once finalized; the registry's bitmap is read
there. Inputs are logs, receipts and the value of top-level transactions only. Only deposits still open are
evaluated; a closed deposit's bit is written as 0. upTo is the highest deposit id at least one day old at the
epoch's start. A word is listed when the bit of an open, covered deposit in it must change; words that set a
bit come first, then words that only clear, each group ascending; at most 96; if more than 96 set a bit, list
the first 96 and lower upTo to just below the first deposit of the first one left out; clear-only words that
do not fit wait. Rules: deny listed(depositor); deny flagged(deposit), which needs Flag(seatId, depositId)
events from more than half of the epoch's snapshot within 14 epochs; hold 7 epochs when
fundedByListed(depositor) is 25% or more; hold 3 epochs for a deposit over 10 ETH at the frozen weights from
an address first funded within 72 hours. The file in force is the one more than two thirds of the snapshot's
seats have signalled, each seat's latest signal counting, else the file named in the parameter file. dataCid
is the CIDv1 (raw, sha2-256) of a canonical JSON file naming every refusal and its rule. No wall-clock time,
no floating point. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. Every
duration is in seconds of block.timestamp; no schedule may count blocks. Screening epochs count from
Params.GENESIS; caps, emissions and the deposit window count from START, which the registry records at its
first applied batch. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `node/src/screen/criteria.ts`
- `node/src/screen/batch.ts`
- `node/src/screen/data.ts`
- `node/test/determinism.test.ts`
- `node/test/vectors/`
- `node/criteria/sanctions-flags-and-funding.v4.json`
- `node/package.json`

## Acceptance tests

1. Two runs on different machines from the same recorded RPC responses produce byte-identical batch and explanation files, and both reproduce every vector in node/test/vectors/.
2. Each rule has a test with a deposit it refuses and one it allows; dust sent by a listed address to a depositor changes nothing; a held deposit is cleared in the batch after its last hold epoch.
3. A deposit made one second less than a day before the epoch's start is not covered; one made exactly a day before is.
4. With 97 words that set a bit, the batch lists 96 and upTo stops below the first deposit of the 97th. With 90 that set and 20 that only clear, all 90 and the first 6 clears are listed and upTo is not lowered.
5. Flags from half of the snapshot refuse nothing; from one more they refuse that deposit and no other deposit of the same address; the same flags refuse nothing 15 epochs later.
6. A deposit that was activated or refunded never causes a word to be listed, whatever its depositor's status becomes.
7. The batch hash equals the Solidity hash used by ScreenerRegistry.apply (shared vector).

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
