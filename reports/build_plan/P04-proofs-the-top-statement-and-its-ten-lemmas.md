# P04 · Proofs: the top statement and its ten lemmas

**Kind:** Proof · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C04, P01, P03
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Prove the eleven theorems of Challenge.lean for the composed Spend circuit. The top statement: every
satisfying assignment yields a key and up to three notes for which SpendValid holds. The lemmas: (1) each non-
empty input's owner is derived from the sk in the witness; (2) each non-empty input is in the tree under root
at the position used, assuming Poseidon collision resistance where stated; (3) the position inside each
nullifier is the position proved in the tree; (4) value is conserved over the integers per asset, with outputs
0 and 1 in the inputs' asset and output 2 in ETH; (5) reward out equals reward in plus earned, earned uses
each input's committed index and its own asset's weight, and output 3 is a token note with no accrued reward;
(6) every output's index is gRef; (7) the public asset is the inputs' asset whenever the public amount is non-
zero; (8) the public outputs are a function of the private inputs; (9) no sum or product in constraints 8, 11
and 12 reaches the field modulus; (10) every one of the 13 public inputs takes part in a constraint that fixes
it. circuit/PROOFS.md lists each theorem, its Lean name, its hypotheses and its axioms. Work only from the
pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp counted from Params.GENESIS; no schedule may count blocks. If the specification is ambiguous,
stop and report the ambiguity instead of choosing. The gate is not a green build. It is: `lake build --wfail`;
an axiom allow-list on every theorem named below (propext, Classical.choice, Quot.sound and nothing else
unless named here); and `lake comparator` against the frozen Challenge.lean, whose hash must equal
circuit/lean/FROZEN.

## Paths the job may write

- `circuit/lean/Murmuration/Proofs/Spend.lean`
- `circuit/lean/Murmuration/Proofs/Capstone.lean`
- `circuit/PROOFS.md`

## Acceptance tests

1. `make lean-proofs` passes with --wfail, no `sorry`, and `lake comparator` reports the eleven Challenge theorems proved against the frozen statements.
2. Axiom check: only the allow-listed axioms plus the named Poseidon collision-resistance hypothesis, which appears as a theorem hypothesis and not as an axiom.
3. The circuit proved is the one exported in C04: the build hashes spend.r1cs from the same Lean term the theorems are about.
4. PROOFS.md states in plain words what is proved, what is assumed and what is only tested.
5. FROZEN hashes are unchanged.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
