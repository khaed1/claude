# P04 · Proofs: the relation and its eleven lemmas

**Kind:** Proof · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C04, P01, P03
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Prove the twelve theorems of Challenge.lean for the composed Spend circuit: the relation theorem (every
satisfying assignment satisfies SpendValid) and lemmas 1 to 11 of part A of "What must be shown" in the build
specification: spend authority; membership; one nullifier per note, as a function of the position, the rho
inside ownerCommit and the nk inside ownerPk; no value created per asset, with no position used twice and the
merged case when asset equals feeAsset; no reward created; outputs start at the checkpoint; the public asset
is true; nothing is left free, in the exact form the specification gives; no wrap-around in constraints 8, 9,
12 and 13, the packed word, the emptiness test and the position; every public input occurs in a surviving
constraint and the public columns are linearly independent; and completeness over the reachable ranges.
circuit/PROOFS.md lists each theorem, its Lean name, its hypotheses and its axioms. Work only from the pinned
commit of the project repository and the build specification (`reports/Murmuration v4 specification.html`,
section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin,
pause, upgrade or setter may appear in any contract. Every duration is in seconds of block.timestamp; no
schedule may count blocks. Screening epochs count from Params.GENESIS; caps, emissions and the deposit window
count from START, which the registry records at its first applied batch. If the specification is ambiguous,
stop and report the ambiguity instead of choosing. The gate is not a green build. It is: `lake build --wfail`;
an axiom allow-list on every theorem named below (propext, Classical.choice, Quot.sound and nothing else
unless named here); and `lake comparator` against the frozen Challenge.lean, whose hash must equal
circuit/lean/FROZEN.

## Paths the job may write

- `circuit/lean/Murmuration/Proofs/Spend.lean`
- `circuit/lean/Murmuration/Proofs/Capstone.lean`
- `circuit/lean/Murmuration/Proofs/Complete.lean`
- `circuit/PROOFS.md`

## Acceptance tests

1. `make lean-proofs` passes with --wfail, no `sorry`, and `lake comparator` reports the twelve Challenge theorems proved against the frozen statements.
2. Axiom check: only the allow-listed axioms plus the named Poseidon hypotheses, which appear as theorem hypotheses and not as axioms.
3. The completeness proof covers every scenario class of C04 and the ends of every range, with the ranges read from the parameter files and not typed into the proof.
4. The circuit proved is the one exported in C04: the build hashes spend.r1cs from the same Lean term the theorems are about.
5. PROOFS.md states in plain words what is proved, what is assumed and what is only tested, and lists parts B, C and D with where each is covered.
6. FROZEN hashes are unchanged.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
