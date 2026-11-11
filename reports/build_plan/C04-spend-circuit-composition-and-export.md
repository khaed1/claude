# C04 · Spend circuit: composition and export

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C01, C03
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Compose the Spend circuit in clean from the gadgets: the sixteen constraints of the build specification over
three inputs (inputs 0 and 1 of the asset, input 2 of feeAsset) and four outputs, with the fourteen public
inputs in the order root, nf0, nf1, nf2, C0, C1, C2, C3, publicAmount, publicAsset, relayFee, feeAsset, gRef,
extHash. Export the constraint system as .r1cs and the witness generator as Circom-ABI WASM with clean's
exporter, so that snarkjs can consume them without the Circom compiler. Work only from the pinned commit of
the project repository and the build specification (`reports/Murmuration v4 specification.html`, section
"Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause,
upgrade or setter may appear in any contract. Every duration is in seconds of block.timestamp; no schedule may
count blocks. Screening epochs count from Params.GENESIS; caps, emissions and the deposit window count from
START, which the registry records at its first applied batch. If the specification is ambiguous, stop and
report the ambiguity instead of choosing.

## Paths the job may write

- `circuit/lean/Murmuration/Spend.lean`
- `circuit/lean/Export.lean`
- `circuit/build/spend.r1cs`
- `circuit/build/spend.wasm`
- `circuit/COUNTS.md`
- `circuit/vectors/scenarios.json`
- `Makefile`

## Acceptance tests

1. `make circuit` regenerates spend.r1cs and spend.wasm byte for byte from a clean checkout.
2. snarkjs r1cs info reports 14 public inputs and a constraint count under 40,000, written to COUNTS.md.
3. A valid witness is produced for each of the nine scenarios in circuit/vectors/scenarios.json: self-sent transfer; transfer with one empty input; transfer relayed for an ETH fee note; spend relayed for a fee in its own asset from a single note; claim; withdrawal; relayed withdrawal; token withdrawal; and a spend at the largest values and index the parameter table allows.
4. For each scenario, changing any single private input makes witness generation or constraint checking fail, or changes a public output.
5. No satisfying witness exists with the same non-empty note in two inputs, with a fee input of an asset other than feeAsset, with value crossing sides when asset != feeAsset, or with feeAsset = 0 and a non-empty input 2 or output 2.
6. The public input order matches IVerifier in B14 (a shared JSON file checked by both).

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run. clean's R1CS exporter dates from September 2026 and has no known production use; C05 exists to test it.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
