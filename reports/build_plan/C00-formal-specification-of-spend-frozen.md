# C00 · Formal specification of Spend, frozen

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** B00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write the specification of the Spend circuit in Lean 4 for the `clean` framework (Verified-zkEVM/clean, MIT),
pinned to a commit. Spec.lean defines, as plain functions over field elements and naturals: key derivation,
the packed word, the note commitment, the nullifier, the bundle leaf, Merkle root recomputation, earned reward
as an integer floor division, and the predicate SpendValid(public, private) that is the conjunction of the
fourteen constraints in the build specification. Challenge.lean states the five capstone theorems (no value
created, one nullifier per position and key, reward bound, determinism, no wrap-around) with `sorry` proofs.
circuit/SPEC.md restates each theorem in plain words. No proofs in this job. Work only from the pinned commit
of the project repository and the build specification (`reports/Murmuration v4 specification.html`, section
"Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause,
upgrade or setter may appear in any contract. If the specification is ambiguous, stop and report the ambiguity
instead of choosing.

## Paths the job may write

- `circuit/lean/Murmuration/Spec.lean`
- `circuit/lean/Murmuration/Challenge.lean`
- `circuit/lean/lakefile.toml`
- `circuit/lean/lean-toolchain`
- `circuit/SPEC.md`
- `Makefile`

## Acceptance tests

1. `make lean-spec` (lake build of Spec.lean and Challenge.lean) succeeds with only the five expected `sorry` warnings.
2. Every constraint 1-14 of the build specification maps to a named definition in Spec.lean, listed in a table in circuit/SPEC.md.
3. Conservation and the reward bound are stated over the integers, not the field.
4. No theorem in Challenge.lean has a hypothesis that is false for an honest spend; SPEC.md lists every hypothesis and why it is needed.
5. The files' sha256 hashes are written to circuit/lean/FROZEN so later jobs can prove against an unchanged statement.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run. The statements are the trust anchor. R01 reviews them and the owner signs them off before any proof job
starts.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
