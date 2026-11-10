# P03 · Proofs: Merkle membership and bundle

**Kind:** Proof · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C03, P02, R01
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Prove, by induction over depth, that the Merkle gadget's satisfying assignments are exactly those where the
recomputed root equals Spec.merkleRoot(leaf, index, siblings), and that the bundle gadget places the
commitment at the stated slot. Prove that the conditional check forces membership whenever value or accrued is
non-zero. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. If the
specification is ambiguous, stop and report the ambiguity instead of choosing. The gate is not a green build.
It is: `lake build --wfail`; an axiom allow-list on every theorem named below (propext, Classical.choice,
Quot.sound and nothing else unless named here); and `lake comparator` against the frozen Challenge.lean, whose
hash must equal circuit/lean/FROZEN.

## Paths the job may write

- `circuit/lean/Murmuration/Proofs/Merkle.lean`
- `circuit/lean/Murmuration/Proofs/Bundle.lean`

## Acceptance tests

1. `make lean-proofs-merkle` passes with --wfail and no `sorry`.
2. The theorem for the conditional check has no hypothesis on the path when value = accrued = 0 and forces root equality otherwise.
3. Axiom check passes. FROZEN hashes are unchanged.
4. position = 4*leafIndex + slot is proved to be the position used by the nullifier.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
