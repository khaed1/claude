# P01 · Proofs: range, division, selection and packing gadgets

**Kind:** Proof · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C01, R01
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Prove soundness and completeness of each gadget from C01 as clean FormalCircuits against Spec.lean: a
satisfying assignment implies the specified relation over the integers, and every valid input has a satisfying
assignment. The division gadget's soundness must use the range bounds, since a field inverse alone would admit
wrong quotients. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. If the
specification is ambiguous, stop and report the ambiguity instead of choosing. The gate is not a green build.
It is: `lake build --wfail`; an axiom allow-list on every theorem named below (propext, Classical.choice,
Quot.sound and nothing else unless named here); and `lake comparator` against the frozen Challenge.lean, whose
hash must equal circuit/lean/FROZEN.

## Paths the job may write

- `circuit/lean/Murmuration/Proofs/Range.lean`
- `circuit/lean/Murmuration/Proofs/Division.lean`
- `circuit/lean/Murmuration/Proofs/AssetTable.lean`
- `circuit/lean/Murmuration/Proofs/Pack.lean`

## Acceptance tests

1. `make lean-proofs-gadgets` passes with --wfail and no `sorry`, `admit` or `native_decide`.
2. `#print axioms` for each of the eight soundness and completeness theorems lists only the allow-listed axioms (checked by script).
3. No file outside the four listed paths changes; Spec.lean and Challenge.lean hashes equal FROZEN.
4. The packing proof shows the packed word determines asset, value and accrued uniquely given the range checks.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run. Documented failure modes of agent-written proofs are about statements: added assumptions, weakened input
types, vacuous specifications, a disabled checker. The gate above exists for those.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
