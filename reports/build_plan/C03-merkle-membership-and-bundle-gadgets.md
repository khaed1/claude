# C03 · Merkle membership and bundle gadgets

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C02
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the bundle gadget (place a commitment at slot 0-3 among three others and hash with H4) and the
depth-32 Merkle root recomputation from a leaf, 32 index bits and 32 siblings, with the conditional check
(value + 2^96*accrued) * (computedRoot - root) = 0. Work only from the pinned commit of the project repository
and the build specification (`reports/Murmuration v4 specification.html`, section "Build specification").
Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may
appear in any contract. Every duration is in seconds of block.timestamp; no schedule may count blocks.
Screening epochs count from Params.GENESIS; caps, emissions and the deposit window count from START, which the
registry records at its first applied batch. If the specification is ambiguous, stop and report the ambiguity
instead of choosing.

## Paths the job may write

- `circuit/lean/Murmuration/Gadgets/Merkle.lean`
- `circuit/lean/Murmuration/Gadgets/Bundle.lean`
- `circuit/lean/test/Merkle.lean`

## Acceptance tests

1. Witness tests against roots produced by the Solidity NoteTree from B11 for 200 random trees (fixture file shared with B11).
2. A wrong sibling, a flipped index bit or a wrong slot makes the constraint system unsatisfiable for a non-zero note.
3. A note with value 0 and accrued 0 satisfies the constraints with any path; a note with value 0 and accrued 1 does not.
4. position = 4*leafIndex + slot is exposed for the nullifier and matches the path bits.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
