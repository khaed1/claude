# C00 · Formal specification of Spend, frozen

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** B00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write the specification of the Spend circuit in Lean 4 for the `clean` framework (Verified-zkEVM/clean, MIT),
pinned to a commit. Spec.lean defines, as plain functions over field elements and naturals: key derivation,
the packed word, the note commitment, the nullifier, the bundle leaf, Merkle root recomputation, the asset
table with integer weights, earned reward as an integer floor division, and the predicate SpendValid(public,
private) that is the conjunction of the sixteen constraints in the build specification, for three inputs (two
of the asset, one of feeAsset), four outputs and the 14 public inputs. Challenge.lean states, with `sorry`
proofs, part A of "What must be shown": the relation theorem (every assignment that satisfies the constraint
system satisfies SpendValid) and the eleven lemmas, the last of which is completeness: for every state in the
reachable ranges of the parameter table the honest witness satisfies the constraint system. Poseidon collision
and preimage resistance appear as named hypotheses, never as axioms. circuit/SPEC.md restates each statement
in plain words and lists parts B, C and D of the specification with where each is checked. No proofs in this
job. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. Every
duration is in seconds of block.timestamp; no schedule may count blocks. Screening epochs count from
Params.GENESIS; caps, emissions and the deposit window count from START, which the registry records at its
first applied batch. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `circuit/lean/Murmuration/Spec.lean`
- `circuit/lean/Murmuration/Challenge.lean`
- `circuit/lean/lakefile.toml`
- `circuit/lean/lean-toolchain`
- `circuit/SPEC.md`
- `Makefile`

## Acceptance tests

1. `make lean-spec` (lake build of Spec.lean and Challenge.lean) succeeds with only the twelve expected `sorry` warnings.
2. Every constraint 1-16 of the build specification maps to a named definition in Spec.lean, listed in a table in circuit/SPEC.md.
3. Conservation and the reward bound are stated over the integers, not the field, with the merged case for asset == feeAsset stated separately.
4. The completeness lemma quantifies over explicit ranges taken from params/mainnet.json and params/canary.json, and SPEC.md lists them.
5. SPEC.md names, for each of these broken circuits, the statement it violates: no spend authority; a free nk or rho in the nullifier; a free output index; a free output asset; an unbound extHash; a fee input not of feeAsset; the same note in two inputs; a circuit that accepts nothing.
6. No theorem has a hypothesis that is false for an honest spend; SPEC.md lists every hypothesis and why it is needed.
7. The files' sha256 hashes are written to circuit/lean/FROZEN so later jobs can prove against an unchanged statement.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run. The statements are the trust anchor. R01 reviews them and the owner signs them off before any proof job
starts. The first two lists in this specification were too weak: a circuit missing whole constraints satisfied
the first, and a circuit that accepts nothing the second.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
