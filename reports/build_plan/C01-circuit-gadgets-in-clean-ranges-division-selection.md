# C01 · Circuit gadgets in clean: ranges, division, selection

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement as clean circuits, reusing clean's proved bit-decomposition and comparator ports: range checks of 2,
32, 64, 90 and 96 bits; exact division by 2^64 with a 64-bit remainder; the asset table lookup that maps an
asset id (1 to 5) to its constant weight and rejects unlisted ids, in two forms: one that rejects zero (for
asset) and one that maps zero to weight zero (for feeAsset); an equality test that yields a constrained
boolean; the emptiness test on value + 2^96*accrued; and the packed word TAG_NOTE*2^200 + accrued*2^104 +
value*2^8 + asset. Constraint generation only; proofs are P01. Work only from the pinned commit of the project
repository and the build specification (`reports/Murmuration v4 specification.html`, section "Build
specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade
or setter may appear in any contract. Every duration is in seconds of block.timestamp; no schedule may count
blocks. Screening epochs count from Params.GENESIS; caps, emissions and the deposit window count from START,
which the registry records at its first applied batch. If the specification is ambiguous, stop and report the
ambiguity instead of choosing.

## Paths the job may write

- `circuit/lean/Murmuration/Gadgets/Range.lean`
- `circuit/lean/Murmuration/Gadgets/Division.lean`
- `circuit/lean/Murmuration/Gadgets/AssetTable.lean`
- `circuit/lean/Murmuration/Gadgets/Pack.lean`
- `circuit/lean/test/Gadgets.lean`

## Acceptance tests

1. `make lean-gadgets` builds and runs the gadget tests.
2. Witness tests: each gadget accepts 1,000 random valid inputs and rejects boundary violations (value = 2^96, remainder = 2^64, asset id = 0 and = 6).
3. Constraint counts per gadget are printed and written to circuit/COUNTS.md.
4. No gadget uses an unconstrained hint whose value is not fixed by a constraint (listed in COUNTS.md with the fixing constraint).

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
