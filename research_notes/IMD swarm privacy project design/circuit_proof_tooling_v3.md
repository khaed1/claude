# Machine-checkable correctness evidence for a ~22k-constraint Groth16 join-split, produced by AI agents (v3)

Research date: 10 November 2026. Read-only: nothing was posted, nobody was contacted, no tool in this list was built or run here. Every repository date below is the committer date of the default-branch HEAD, read from a shallow `git clone` on 10 Nov 2026; every quote was fetched on 10 Nov 2026 unless marked otherwise. Items that could not be confirmed are collected in section 9.

Target (as updated by the coordinator): one Groth16 circuit of about 22,000 R1CS constraints with Poseidon at widths 3, 4 and 5, two depth-32 Merkle paths, 96-bit range checks, one exact division, and value and reward conservation equations. Properties wanted: (1) no under-constrained signals, meaning outputs are determined by inputs; (2) value conservation; (3) nullifier uniqueness; (4) equivalence between the circuit and a readable specification.

STATUS: complete draft. Section 9 lists what was not verified.

---

## 1. Verdict

**Use the Circom/snarkjs R1CS tool chain, and put the proofs in Lean 4 with `clean`.** Of the two languages asked about, Circom is the better fit; Noir is the weaker choice for this circuit today.

- Properties 2, 3 and 4 can only be machine-checked today with an interactive prover. The one framework with a public record on a comparable circuit is `clean` (Lean 4, MIT): it was used for the Zcash Orchard/Ironwood Action circuit in June-July 2026, largely with AI-written Lean, and the result ships in production.
- `clean` already emits binary `.r1cs` and a Circom-ABI WASM witness generator that snarkjs consumes for `groth16 setup`. So the circuit that is proved can be the circuit that is deployed, with no Circom compiler in between. If the team insists on `.circom` source, the Lean model is a hand or AI port and the link to the Circom output is a file comparison, not a theorem.
- That exporter entered the repository in mid-September 2026 (first commits 16 Sep 2026). I found no production use of it. Treat it as new, untested code.
- The gap that matters most for this design is Poseidon. On `clean`'s `main` branch only width 2 (arity 1) has a circuit proof; widths 3, 4 and 5 have specifications and test vectors only. An unmerged branch, `poseidon-n-arity` (last commit 2 Nov 2026), carries a commit titled "Generalize verified Poseidon circuit to arities 1 through 16". Until it merges, the agents either build on an unreviewed branch or redo that work. About 70% of the constraints in this circuit are Poseidon rounds (my estimate, see section 9).
- Property 1 cannot be established for the whole circuit by the push-button SMT tools (Picus, CIVER, ConsCS). Their own documentation and an independent 2026 evaluation say they stall on hashes and on anything above small circuits. They remain useful on the non-hash templates and as bug finders. In `clean`, property 1 follows from the soundness theorem when the specification is a function of the inputs.
- "An LLM agent writes the Lean proof and anyone re-runs the checker" has public precedents for circuits (section 7). The documented failures are almost all about the statement, not the proof: added assumptions, weakened input types, vacuous specifications, and one case of agents disabling the checker.

What stays only tested under the recommended path: that the Poseidon specification equals the reference Poseidon for all inputs (test vectors only), witness generation against real inputs, the snarkjs setup and prover, the Solidity verifier, and everything in the contract (nullifier set, root history).

---

## 2. Comparison table

Property columns: 1 = determinism / no under-constraint, 2 = value conservation, 3 = nullifier uniqueness, 4 = equivalence to a specification. "Yes" means the tool can produce a machine-checked result for that property in principle; scale and maturity limits are in the next columns.

| Tool | Kind | 1 | 2 | 3 | 4 | Re-runnable artifact | Handles ~22k constraints with Poseidon? | HEAD date | Licence | Headless |
|---|---|---|---|---|---|---|---|---|---|---|
| **clean** (zkSecurity, Verified-zkEVM) | Lean 4 circuit DSL with soundness and completeness proofs; R1CS + WASM export | Yes (via functional spec) | Yes | Yes, relative to a hash assumption | Yes | Lean proof, `lake build`; `lake comparator` | Yes in principle: proofs compose per gadget, and zk.golf holds kernel-checked R1CS solutions for circuits whose baselines are 150k-210k constraints. Poseidon widths 3-5 are proved only on an unmerged branch | 2026-11-09 | MIT (Circomlib ports LGPL) | Yes |
| **CIVER** (`costa-group/circom_civer`) | Modular SMT (Z3) inside a circom fork | Yes | Partly (user postconditions) | No | Partly (postconditions per template) | Re-run of tool; no proof certificate | Not shown. Hashes need `spec_fact` assumptions. Fork is on circom 2.1.6, no buses | 2026-02-19 | GPL-3.0 | Yes |
| **Picus** (Veridise, open repo) | SMT uniqueness check (cvc5 finite fields) on Circom/R1CS | Yes | No | No | No | Re-run; counterexample when unsafe | No. README: hashes must be replaced by abstractions | 2024-03-14 | MIT | Yes |
| **ConsCS** | Constraint-solving uniqueness on `.r1cs` | Yes | No | No | No | Re-run | No evidence; research artifact | 2025-02-04 (single commit) | MIT | Yes |
| **Ecne** (0xPARC) | R1CS uniqueness by propagation rules, Julia | Yes | No | No | No | Re-run | No evidence; needs `--O0` | 2022-05-22 | GPL-3.0 | Yes |
| **LLEQ** (project-llzk, Veridise) | SMT equivalence of witness generator vs constraints on LLZK IR | Yes (per struct) | No | No | No | Re-run; SMT-LIB query can be dumped | No. One struct at a time; subcomponent calls poorly supported | 2026-09-01 | Apache-2.0 | Yes |
| **circomspect** (Trail of Bits) | Static analyzer / linter | Flags only | No | No | No | SARIF report | Yes (lint speed) | 2026-09-30, v0.9.0 | GPL-3.0 (LICENSE file) | Yes |
| **ZKAP** | Static detectors on circom via LLVM | Flags only | No | No | No | Report | Yes, with false positives | 2024-08-14 | MIT | Yes (Docker, ~100 GB disk) |
| **zkFuzz** | Mutation fuzzer for Circom (prototype for Noir) | Tests only | No | No | No | Counterexample JSON | Yes as a tester; proves nothing | 2026-10-15 | GPL-3.0 | Yes |
| **Coda** (Veridise) | Refinement types + Coq | Yes | Yes | Yes | Yes | Coq proof | Dormant; Coq Platform 2022.04 | 2023-06-26 | MIT | Yes |
| **Garden** (Formal Land) | Rocq framework; Circom, LLZK, Plonky3, Halo2 front ends | Yes | Yes | Yes | Yes | Rocq proof | Circom side: circomlib is translated, only two small proofs. Halo2 side: full Orchard Action circuit | 2026-08-07 | MIT | Yes |
| **zk-lean** (Galois) | Lean 4 DSL for ZK statements (used with Jolt) | Yes | Yes | Yes | Yes | Lean proof | Only toy examples public | 2026-05-04 | BSD-3-Clause | Yes |
| **ACL2 r1cs / PFCS** (Kestrel, in ACL2 books) | ACL2 + Axe lifter for R1CS | Yes | Yes | Yes | Yes | ACL2 certified books | "thousands of constraints" per Kestrel; Semaphore proofs partial | 2026-11-10 (ACL2 repo) | BSD-3 style (ACL2) | Yes |
| **gnark-lean-extractor + proven-zk** (Reilabs) | gnark circuit to Lean 4 | Yes | Yes | Yes | Yes | Lean proof | Used on depth-30 Poseidon Merkle batch circuits; gnark only, extractor stale | 2024-03-28 / 2026-05-27 | Apache-2.0 | Yes |
| **lampe** (Reilabs) | Noir source semantics in Lean 4; extractor CLI | Yes at source level | Yes | Yes | Yes (to Noir source, not to R1CS) | Lean proof | No public proof of a comparable circuit found; tracks Noir 1.0.0-beta.14 | 2026-10-21 | Apache-2.0 | Yes |
| **NAVe** (Blockhouse) | ACIR to SMT-LIB (cvc5), `formal-verify` in a nargo fork | Yes on small programs | Simple asserts | No | No | Re-run | No. Only the Range black box is formalised; largest test ~1k opcodes; 120 s timeouts | 2026-07-01 | MIT/Apache-2.0 | Yes |
| **Blocksense Noir fork** | Noir to Verus/Z3 prototype | Partly | Partly | No | No | Re-run | Not shown; prototype | 2025-05-15 (`formal-verification` branch) | MIT/Apache-2.0 | Yes (nix) |
| **`nargo fuzz`, `#[fuzz]`, `nargo test`** | Coverage-guided fuzzing and tests in Noir | Tests only | Tests only | Tests only | Differential test vs oracle | Failing input file | Yes as tests | Noir v1.0.0-rc.7, 2026-11-09 | MIT/Apache-2.0 | Yes |
| **formal-snarks-project** | Lean 4 proofs about SNARK proof systems (not circuits) | No | No | No | No | Lean proof | n/a | 2026-08-15 | Apache-2.0 | Yes |
| **LLZK** (`project-llzk/llzk-lib`) | Shared IR and passes; Circom front end in `project-llzk/circom` | Substrate only | - | - | - | - | n/a | 2026-11-06, v2.1.2 | Apache-2.0 | Yes |

---

## 3. Circom-side tools: evidence

### 3.1 Picus (Veridise) - `github.com/Veridise/Picus`
- What it is: "Picus is an implementation of the QED² tool, which checks the uniqueness property (under-constrained signals) of ZKP circuits." Targets: "Circom, R1CS, and gnark." (README)
- Output: "`safe`: Picus cannot find underconstrained bugs / `unsafe`: Picus can find an underconstrained bug and it usually will also output the attack vector / `unknown`: Picus cannot get a result within the given time limit." (README)
- Scale, in its own words: "In case no response / solving for a long time: this usually means the finite field solver in `cvc5` chokes. There is currently no direct solution to quickly improve the solver's performance." and "If a big target is too difficult to verify all at once fully automatically (which is the case for many real-world circuits), it is possible to do a semi-automatic way by manually tearing the circuits into pieces". On hashes: "In some difficult cases where a template is very complicated -- e.g., a crypto hashing function -- and it is already difficult to verify the hash function itself, but supposing it is correct, it is possible to manually rewrite this difficult template into a relatively simple one with the same output domain". (README)
- Paper abstract (QED², PLDI 2023): evaluated "on 163 Circom circuits" and "can successfully solve 70% of these benchmarks". https://eprint.iacr.org/2023/512
- Independent evaluation (zkFuzz, IEEE S&P 2026, Table IV, as summarised by the fetch tool, not read line by line): on 452 Circom circuits bucketed by constraint count, Picus and ConsCS had true positives only in the smallest bucket (under 100 constraints) and none in the buckets above. The paper's own sentences: "Formal methods offer better precision but don't scale to large circuits due to SMT solver bottlenecks" and "Picus exhibits slower performance, relying on expensive queries to SMT solvers." https://arxiv.org/html/2504.11961
- Maturity: last commit 2024-03-14 ("release: make a new release"); CHANGELOG stops at v1.0.2 (2023-11-02), which supports Circom 2.1.6. MIT. Veridise continues to use Picus commercially (section 6), but the public repository has not moved in 20 months.
- Agent use: `./run-picus --solver cvc5 --timeout <ms> --json out.json file.circom` (or a `.r1cs` compiled with `--O0 --sym`). Exit code and JSON are machine-readable. Docker build provided.
- Verdict for this circuit: usable on range-check, comparator, multiplexer and conservation templates in isolation. Not usable on Poseidon or on the whole circuit.

### 3.2 CIVER - `github.com/costa-group/circom_civer`
- **The `--civer` flag is not in the upstream compiler.** `iden3/circom` 2.2.4 (HEAD 2026-10-20) has no `civer`, `check_safety`, `check_tags` or `check_postconditions` option in `mkdocs/docs/getting-started/compilation-options.md` or in `circom/src/input_user.rs`. The options exist only in the fork, whose binary is `civer_circom`; there `--civer <file>` passes a tag-specification file.
- What it proves: "CIVER is a tool that can verify **weak safety**, also known as determinism, which means there is a single valid output for any given inputs." Three modes: "`--check_safety`, `--check_tags`, and `--check_postconditions`". Postconditions are "quantifier-free formulas over the signals of the circuit". (README)
- Hashes: "When dealing with cryptographic structures, some properties are often assumed by the programmers ... we can use the instruction `spec_fact Exp` to claim a fact that CIVER interprets as true." So a Poseidon template is assumed, not verified.
- Limits stated in the README: "CIVER currently uses the Z3 SMT solver as its back-end"; "The current version of **circom supported is 2.1.6**"; buses are not supported; R1CS/PLONK/ACIR input is "soon".
- Scale claim by its authors: on ZisK recursion circuits, "The size of these ZisK circuits ranges from one million to over five million constraints"; "Using CIVER we have detected **two subtle bugs**"; "The full verification of the recursion/aggregation circuits is not finished yet." https://costa.fdi.ucm.es/web/news/CIVER_ZisK.html (undated page). Paper: Isabel, Rodríguez-Núñez, Rubio, "Scalable verification of zero-knowledge protocols", IEEE S&P 2024 (not read).
- Maturity: last commit 2026-02-19; GPL-3.0; no tags.
- Agent use: `civer_circom circuit.circom --check_safety`, then `--check_postconditions --civer tags_specification.circom`. Output is a per-component count of verified / failed / timeout.
- Verdict: the best automatic option for property 1 on the non-hash templates, and its postconditions can state the conservation equation for one template. It gives no certificate a third party can check other than re-running Z3, and it is tied to circom 2.1.6.

### 3.3 Other automatic checkers
- **ConsCS** (`jinan789/ConsCS`): one commit, 2025-02-04, MIT. `python3 analyze_circuit.py <file.r1cs> <log> <log2> 111 4`. Research artifact; no evidence at this scale.
- **Ecne** (`franklynwang/EcneProject`): last commit 2022-05-22, GPL-3.0. "It returns `true` when able to verify the soundness of the constraints, and `false` otherwise. Note that `false` does not mean that the constraints aren't sound". Needs `--O0`: "**Note that this means using optimized constraints in production assumes the correctness of the Circom Compiler**". Dormant.
- **LLEQ** (`project-llzk/LLEQ`, Apache-2.0, 2026-09-01): "an equivalence verifier for zero-knowledge circuits in LLZK IR, based on Zequal". It compares the witness generator with the constraints. `lleq verify --struct <Name> --flatten input.llzk`. README limits: "Analysis of structs with multidimensional arrays or subcomponent calls is not currently well-supported." Veridise's post (25 Aug 2026) adds that equivalence "does not on its own establish that a circuit computes what its developer intended" and that lookups and algebra beyond field arithmetic are out of reach. https://veridise.com/?p=20508
- **circomspect** (Trail of Bits): v0.9.0, last commit 2026-09-30. "a static analyzer and linter for the Circom programming language". `circomspect path/to/circuit --sarif-file out.sarif`. Lint only.
- **ZKAP**: USENIX Security 2024, last commit 2024-08-14, MIT. The README admits "a few benchmarks (around 10) are broken". Lint only.
- **zkFuzz** (`Koukyosyumei/zkFuzz`, GPL-3.0, 2026-10-15): "leverages fuzzing with program mutation to uncover counterexamples that reveal under-constrained or over-constrained behavior". `zkfuzz circuit.circom --search_mode=ga --save_output`. The paper: "zkFuzz adopts a fuzzing approach for bug detection and thus inherits certain limitations." Its trophy list includes an issue in a privacy-pools repository. A test tool, and the right one to run continuously.
- **zkSecurity `zk-skills` / Circom-Auditor** (5 Aug 2026): "a set of open-source security skills for AI coding agents, starting with circo[m]". Review aid, not proof. https://blog.zksecurity.xyz/posts/circom-auditor.md

### 3.4 clean (zkSecurity, in `Verified-zkEVM/clean`)
- What it is: "`clean` is an embedded Lean DSL for writing zk circuits, targeting popular arithmetizations like AIR, PLONK and R1CS." (README) A `FormalCircuit` bundles `main`, `Assumptions`, `Spec`, `soundness` ("constraints → assumptions → spec") and `completeness` ("assumptions → constraints satisfiable"). (AGENTS.md)
- Maturity: HEAD 2026-11-09 (PR #511), MIT, release tags per Lean toolchain (latest v4.35.0). Ships `AGENTS.md`, `CLAUDE.md`, a `skills/lean-mcp` skill and `doc/proving-guide.md` for coding agents.
- **R1CS and snarkjs export exists** (`Clean/Backends/Circom/README.md`): "A compiler written in Lean that turns Clean circuits into standalone artifacts the snarkjs toolchain can consume directly: Binary WASM witness-generation modules implementing the Circom 2 witness-calculator ABI ... R1CS constraint files ... the binary `.r1cs` format consumed directly by `snarkjs r1cs info`, `groth16 setup`". Lookups are rejected in R1CS export, and "`native` witnesses (Lean closures) ❌ Not compilable", so witnesses must be written in the witness IR. The README gives BN254 examples with `compileR1CSBin BN254_PRIME ...`.
- **Circomlib ports with proofs** (`Clean/Circomlib/`, LGPL like circomlib): AliasCheck, BinSub, BinSum, Bitify, Bitify2, CompConstant, Comparators, Gates, Mux1-3, Poseidon, Rotate, Sign. No `sorry` string in any of these files at HEAD. The folder README: "This project aims to formally verify all of circomlib in clean."
- **Poseidon status** (`Clean/Circomlib/Poseidon.md` at HEAD, and the 4 May 2026 post): "Currently, the proof is about arity 1 Poseidon." "Arities 2, 3, 4 have specs and test vectors but no circuit/formal-proof." "`poseidon1Opt = poseidon1` is checked only via `native_decide` on a handful of inputs, not proven." "The translation from the original `poseidon.circom` source to this Clean model is not mechanically checked; it is a direct hand model". The post says the arity-1 proof took "weeks of work". https://blog.zksecurity.xyz/posts/poseidon-clean/
- **Unmerged generalisation.** Branch `poseidon-n-arity` (author Martin Ochoa; commits 17 Sep, 21 Sep and 2 Nov 2026): "Generalize verified Poseidon circuit to arities 1 through 16". On that branch `Clean/Circomlib/Poseidon.lean` defines `Poseidon2` ... `Poseidon16` as `FormalCircuit F (fields n) field` over a generic `Poseidon/Generic.lean`, and none of the Poseidon files contains the string `sorry`. Arities 2, 3 and 4 are the widths 3, 4 and 5 this design needs. I inspected the branch by listing and grep only; it was not built.
- The BN254 primality gap described in the May post is closed on `main`: `Clean/Specs/Poseidon.lean` now has `instance : Fact (Nat.Prime BN254_PRIME) := ⟨BN254.ScalarField_is_prime⟩`. The spec test vectors still use `native_decide`.
- Dates from the repository history: the Circom/R1CS backend's first commits are 16 Sep 2026; the SHA-256 gadget's first commit is 15 May 2026; the first Poseidon commit (3 Jul 2025) is titled "some initial ai slop attempt at poseidon".
- Not there yet (README roadmap): "Create clean circuits from LLZK - this gives us frontends like Circom - subproject: demonstrate actual e2e extraction from Circom". So there is no mechanical Circom-to-clean import today.
- Agent use: `lake exe cache get`, `lake build --wfail`; state `Spec` and `Assumptions`; prove with `circuit_proof_start`; export with `compileR1CSBin` / `compileModule`; then `snarkjs groth16 setup circuit.r1cs pot_final.ptau circuit.zkey`.

### 3.5 Other proof-assistant frameworks
- **Coda** (Veridise): "Certified circom circuits in Coq." Needs Coq Platform 2022.04.1. Last commit 2023-06-26. zkSecurity's 2025 comparison lists it under "Some dormant projects".
- **Garden** (Formal Land, Rocq 9, MIT, 2026-08-07): properties are "Determinism ... Functional correctness ... Completeness". "We handle circuits at the implementation level in: Plonky3, LLZK, Circom". `Garden/Circom/Circomlib/translation/` holds machine translations of circomlib (including `poseidon.v`, `comparators.v`, `bitify.v`), but `proof/` holds only `binsum.v` and `sha256/xor3.v`. Its Halo2 side contains "the formal verification of the Orchard Action circuit". Has an `AGENT.md`.
- **zk-lean** (Galois): 2026-05-04. In the zkSecurity comparison (19 Nov 2025) neither the author nor Claude Code could prove IsZero in it.
- **ACL2 r1cs** (Kestrel): the ACL2 books contain `kestrel/ethereum/semaphore`. Kestrel: "We have also used Axe to prove the main correctness theorems for R1CS circuits with thousands of variables and thousands of constraints" and "The main R1CS circuits that we are currently formally verifying are those used by" Semaphore. https://www.kestrel.edu/research/fv-of-r1cs/
- **"circom-lean", "ZKLib" as a circom extractor**: no such tool found. ZKLib is the former name of ArkLib, which formalises proof systems, not circuits. `formal-snarks-project` is about proof-system soundness, not circuits.
- **Certora**: no ZK-circuit tool found (one search; see section 9).

---

## 4. Noir-side tools: evidence

- **Noir itself**: v1.0.0-rc.7, HEAD 2026-11-09. The README still carries "This implementation is in early development. It has not been reviewed or audited. It is not suitable to be used in production. Expect bugs!" (this line may be stale boilerplate; it is quoted as it stands). The compiler has default-on heuristics for hint misuse; the flags to disable them are documented as "Flag to turn off the compiler check for under constrained values ... This check should always be run on production code" (`--skip-underconstrained-check`) and likewise `--skip-brillig-constraints-check`. These are lints, not proofs. The standard library's `hash` folder holds only `poseidon2.nr`, so classic Poseidon at widths 3-5 would come from an external Noir library.
- **Noir does not target Groth16.** Its artifact is ACIR for PLONKish back ends. The maintained route to Groth16 is Reilabs **Sunspot** (`reilabs/sunspot`, v1.0.0, 2026-10-06): ACIR to gnark Groth16, built for Solana verification, "Requires Noir 1.0.0-beta.22", "audited by HashCloak between April and September 2026". Its own setup command is flagged "THIS IS UNSAFE! ... NO MITIGATION FOR CRYPTOGRAPHIC TOXIC WASTE". This adds an unverified ACIR-to-R1CS translator to the trust base.
- **lampe** (Reilabs, Apache-2.0, 2026-10-21): "a model of Noir's semantics in the Lean programming language". Run `lampe` in a Nargo project to extract Lean; proofs are separation-logic triples over the extracted code. Unconstrained calls are modelled as arbitrary values: `Lampe/Lampe/Builtin/Basic.lean` defines `fresh` ("Corresponds to an unconstrained function call") with the rule `(∀ v, Q (some (st, v)))`, and the stdlib README says unconstrained functions "are extracted with an empty body". That is the right model for malicious hints. Limits: it tracks stdlib 1.0.0-beta.14 (extracted folder name), while Noir is at rc.7 and Sunspot needs beta.22; the proofs are about Noir source, so the Noir compiler and the Groth16 translator are trusted; no public lampe proof of a join-split-sized program was found.
- **NAVe** (`blockhouse-sec/nave`, moved from `pedrotbtl/nave`, tag `sefm26`, 2026-07-01; arXiv 2601.09372): "translates a ACIR program into a corresponding set of SMT constraints". From the paper (via the fetch tool): "we have only provided a formalisation of the Range black box function"; "We do not formalise the Call opcode"; Brillig calls "are translated as the always satisfied constraint true"; 50 test programs, the largest about 984 opcodes; 120-second timeouts hit on range-check-heavy programs. It cannot take a circuit with Poseidon.
- **Blocksense fork**: "Formal verification of Noir circuits, based on the Z3 SMT solver and the IR language of the Verus project ... a proof-of-concept FV system". The `formal-verification` branch last moved 2025-05-15.
- **`nargo fuzz` / `#[fuzz]`**: "Uses coverage-guided fuzzing"; "Can be used with an oracle to perform differential fuzzing against a known good implementation in another language". Testing.
- **zkFuzz for Noir**: `zkfuzz-noir`, pinned to nargo 1.0.0-beta.6; the paper calls it "preliminary".
- **Aztec**: Barretenberg carries an `smt_verification` module (cvc5) for its own C++ circuit primitives. No Aztec tool that proves properties of a user's Noir program was found (see section 9).

---

## 5. Recommended paths

### 5a. Circom / R1CS path (recommended)

Tier A, tests and lints, run on every change: `circom --inspect`, `circomspect`, `zkfuzz`, and differential tests of the witness generator against a reference implementation.

Tier B, automatic determinism where it terminates: `civer_circom --check_safety` and `run-picus` on each non-hash template (range checks, the division gadget, selectors, the conservation template). Record `unknown`/timeout honestly; expect it for Poseidon and for the top level.

Tier C, the actual evidence, Lean 4 + clean:
1. Humans write and review the specification in Lean: note commitment, nullifier, Merkle membership, 96-bit ranges, the conservation equations over the integers, the division relation. This file is the trust anchor and should be short.
2. Agents implement each gadget as a `FormalCircuit` and prove soundness and completeness. Reuse the proved Bitify/Comparators/Mux ports. Poseidon at widths 3, 4 and 5 comes from the `poseidon-n-arity` branch if it has merged; otherwise it is new work. Also new: the Merkle path by induction over depth, the 96-bit range gadget, the exact-division gadget (the quotient can be witnessed with a field inverse; soundness over the integers needs the range bounds), and the top-level composition.
3. The gate is not "the build is green". It is: `lake build --wfail`; an axiom allow-list on the capstone theorems (`propext`, `Classical.choice`, `Quot.sound`, plus any named exception); and `lake comparator` (in Lean core since v4.35.0) against a frozen, human-owned `Challenge` file so that agents cannot change statements.
4. Deployment artifact. Option 1 (stronger, and my recommendation): export `.r1cs` and WASM from clean and run snarkjs on those. Keep an independent Circom implementation as a differential-test oracle (same public outputs on random and edge-case inputs). The exporter is about eight weeks old, so test it as unproven code. Option 2 (if `.circom` must be the source): keep the Circom file, port it to clean, and add a CI check that the clean-exported constraint system equals the circom-compiled one for the pinned compiler version and flags. That check is a test of one artifact, not a theorem, and it is my proposal, not an existing tool.

What is machine-checked on this path:
- (1) Determinism: yes, as a corollary of soundness against a functional specification, for the whole circuit, relative to the model.
- (2) Conservation: yes at circuit level (any satisfying assignment balances over the integers, given the range checks). "Cannot create value" for the system also needs the contract and the hash assumptions; Ironwood needed a separate ledger-level development for that.
- (3) Nullifier: yes for "the nullifier is the specified function of the note and key". "Cannot spend twice" additionally needs collision resistance of Poseidon and the on-chain nullifier set, which are outside the circuit proof.
- (4) Equivalence: yes between the clean circuit and the Lean specification. Between that and a `.circom` file: only by the artifact comparison in step 4.

What is only tested: `poseidonOpt = poseidon` for all inputs; the Poseidon constants against circomlibjs vectors; witness generation; the R1CS exporter; snarkjs; the verifier contract.

### 5b. Noir path

`nargo test`, `nargo fuzz` and the compiler checks for tests; `lampe` to extract to Lean and prove the same four properties about the Noir source, with unconstrained calls treated as adversarial; Sunspot to get to Groth16.

What is machine-checked: properties 1-4 about the Noir program's semantics as modelled by lampe. What is not: that the compiled ACIR and the translated R1CS implement that program. Three components are pinned to three different Noir versions today (lampe beta.14, Sunspot beta.22, Noir rc.7). Poseidon at widths 3-5 would be a Noir library, and no lampe proof of it was found.

### 5c. Which language makes the proofs easier

Circom/R1CS, for this circuit:
- Groth16 consumes R1CS. With clean the proved object is the R1CS itself, so the compiler leaves the trust base. With Noir the proof sits two translations above the R1CS.
- The proved gadget library that exists (bit decomposition, comparators, multiplexers, Poseidon width 2, circomlib constants) is circomlib-shaped.
- The only precedent at this difficulty, the Orchard/Ironwood Action circuit, used clean.
- Noir's real advantage is that ordinary code cannot be under-constrained, only `unconstrained` hints can. That lowers the bug rate but does not by itself produce evidence for properties 2-4.

### 5d. Residual trust on the recommended path

- **The specification.** Everything is relative to it. zkSecurity on the Orchard port: "not all circuit specs and interfaces were human-written or reviewed, and such a review is essential".
- **Lean kernel and tool chain.** zkSecurity (5 Oct 2026) refers to "the recent bug in the Lean kernel" and judges the impact on honest developments "non-existent" once upgraded; `lake comparator` can replay with a second kernel. `native_decide` adds compiler trust; OpenVM's and Ironwood's CI treat it as a tracked exception.
- **clean's circuit model and exporters.** The definition of constraint satisfaction, and the Lean code that writes `.r1cs` and WASM. Whether the exporter is proved against the model was not verified (section 9).
- **Poseidon.** Constants are "copied verbatim from circomlib's `poseidon_constants.circom`" and checked on seven vectors. The optimised and reference forms are equal only on tested inputs. Cryptographic strength is an assumption no proof assistant addresses.
- **Circom compiler**, only if `.circom` stays the source. The Circuzz compiler fuzzer lists 5 confirmed circom bugs (4 fixed) and 3 in Noir (`BUGS.md`).
- **Groth16 setup, prover, verifier.** zkSecurity, 27 Feb 2026: "The first two known exploits against live ZK circuits happened in the past week. Both stem from the same root cause. They were not subtle underconstrained bugs, but rather Groth16 verifiers (generated by snarkjs) with an incorrect setup (just missing the last step). One was exploited by white-hat hackers for ~$1.5M, the other was drained for 5 ETH." And: "A critical invariant: γ and δ must be distinct, independent group elements." https://blog.zksecurity.xyz/posts/groth16-setup-exploit.md A circuit proof says nothing about the ceremony or the deployed verification key; add an explicit check of the verification key to the release gate.
- **Contract logic**: nullifier set, root history, public-input encoding.
- **Knowledge soundness of Groth16 itself**: assumed.

---

## 6. Precedents: machine-checked proofs of comparable production circuits

| Project | What was proved | Tool | Effort stated | Source |
|---|---|---|---|---|
| **Zcash Ironwood / Orchard Action circuit** (Halo2, not Groth16; spend of a note with nullifier, Merkle path, value commitment) | "a machine-checked proof, written in Lean, which shows that undetectable counterfeiting bugs do not exist in Ironwood"; one property, "balance integrity"; covers the proof system (knowledge soundness in the algebraic group model), the circuit (in clean) and ledger accounting. Privacy not covered. Spendability and spend authority "not yet finished" per the repo's guide | Lean 4, clean, Mathlib; `zcash/ironwood`, MIT/Apache-2.0, HEAD 2026-11-09 | "It took three teams of researchers and cryptographers well over a month"; "more than 2,700 theorems". No cost figure | https://tachyon.z.cash/blog/ironwood-verification-complete/ (28 Jul 2026); https://cointelegraph.com/news/zcash-ironwood-proof-counterfeiting-orchard-flaw (29 Jul 2026); repo book |
| **Orchard Action circuit MVP** (`zksecurity/clean-orchard`) | "end-to-end soundness and completeness proofs for the top-level Action circuit, covering all of its gadget dependencies. Proofs depend on zero sorries and a single benign axiom that establishes the Pallas curve order." Not mechanically tied to the Rust source | Lean 4, clean | Part of an audit that "lasted one week with two consultants" from 8 June 2026; port done "in an AI-assisted manner" | https://reports.zksecurity.xyz/reports/zcash-orchard.md (14 Jul 2026) |
| **Orchard Action circuit, independent** | "from the captured Halo 2 configuration and synthesis through the gadget, Action-statement, transaction-balance, and operational-soundness proofs" | Rocq, Garden (Formal Land) | Not stated | Garden README |
| **Worldcoin semaphore-mtb** (gnark Groth16, Poseidon Merkle tree depth 30, batch 4) | `root_transformation_correct`, `assignment_exists`, `inputHash_deterministic`, `inputHash_injective`, `before_insertion_all_items_zero` for the insertion and deletion circuits | Lean 4 via gnark-lean-extractor + proven-zk; pinned to `lean4:nightly-2023-07-12` | Not stated | `worldcoin/semaphore-mtb`, `formal-verification/Main.lean` |
| **Semaphore (original, MiMC)** | Component proofs, e.g. MiMC sponge; whole circuit described as in progress | ACL2 + Axe (Kestrel) | Reproducing the public books took the zkSecurity author "three hours" | Kestrel page; ACL2 books |
| **SP1 Hypercube RISC-V chips** | Per-chip soundness against the Sail RISC-V model; completeness partly open ("currently five" deferred) | Lean 4, now expressed in clean (`succinctlabs/sp1-lean`, 2026-06-25) | Not stated | repo README |
| **OpenVM RV32IM + Keccak/SHA-2 chips** | "all 45 of the RISC-V RV32IM opcodes satisfy their RISC-V specifications"; soundness only for precompiles; CI gates include `leanprover/comparator` | Lean 4 (`openvm-org/openvm-fv`, 2026-07-14) | Not stated | repo README |
| **ZKsync Airbender; RISC Zero** | Determinism only. Airbender: "Picus verified 21 of the 26 targeted circuits as deterministic"; the page does not say why five were not. RISC Zero: determinism of some circuits (search summary only) | Picus through Veridise AuditHub | Airbender: "From February to April 2026", three analysts, 21 person-weeks | https://veridise.com/?p=20256 (30 Jun 2026); https://risczero.com/blog/RISCZero-formally-verified-zkvm |
| **ZKsync on-chain verifier** | Yul verifier contract matches an honest-verifier model (search summary only) | EasyCrypt (Nethermind, Feb 2025) | Not stated | https://www.nethermind.io/blog/we-verified-the-verifier-a-first-for-zero-knowledge-proof-systems |
| **StarkWare STRK20 privacy pool** | The protocol "modeled in Lean as a state machine": notes cannot be forged, no double-spend through a one-time nullifier, exact accounting, funds recoverable and spendable. A model, not the Cairo contract and not a circuit | Lean 4; `starkware-libs/starknet-privacy`, folder `lean/` | "over 230 theorems"; effort not stated | https://starkware.co/blog/strk20-formal-verification/ (23 Jul 2026) |
| Tornado Cash, Privacy Pools, Semaphore v4, Zcash Sapling, Linea | No published machine-checked circuit proof found | - | - | section 9 |

The semaphore-mtb development shows the hash-assumption problem in miniature. It uses `[Fact (CollisionResistant poseidon₂)]` and an axiom whose own comment reads: "It is obviously not true (e.g. by the pigeonhole principle), but it captures the usual intuition behind hash functions."

---

## 7. LLM agents writing circuit proofs: public precedents

- **zk.golf** (zkSecurity, 2 Jul 2026): "People can submit arbitrary circuits, as long as they provide a machine-checkable Lean proof that their circuit satisfies the interface. We verify the Lean proofs using comparator." Targets R1CS over BN254. On SHA-256 in clean: "It took a couple of nights of work for Opus 4.7, and some light steering into the right direction". "Sometimes, it came up with unsound optimizations, however, since it could not prove them, it backtracked". https://blog.zksecurity.xyz/posts/zkgolf.md
- **clean-orchard** (14 Jul 2026): "The translation of circuit code was done 'by hand', in an AI-assisted manner, with strong instructions to use source-conformant circuits but no waterproof mechanism to enforce such conformance."
- **Ironwood** (repo guide, HEAD 9 Nov 2026): "it turns out that AIs are very good at writing a lot of Lean code (and comments) quickly. That is what made this development possible, but it also presents a huge challenge to reining in complexity, verbosity, and overclaims. The path of least resistance is to let the AI produce more output than is humanly reviewable." The repository has a `.claude/skills` folder and its latest merge is from a bot branch named `codex/...`.
- **Framework comparison with Claude Code** (zkSecurity, 19 Nov 2025): Claude Code proved IsZero and a 65-input weighted-sum gadget in ACL2 ("The whole process took 30 minutes"; "stating and proving correctness theorems happened 100x faster with Claude Code than just me"), needed intervention in Rocq/Garden, and failed in zk-lean and, at that time, in clean. https://blog.zksecurity.xyz/posts/formal-verification-arithmetic-circuits.md
- **Runtime Verification experience report** (arXiv 2605.30106, May-Jul 2026; Rust from Plonky3 and RISC Zero to Lean): "AI provers operated as a productivity multiplier"; "We did not observe AI provers bypassing the inherent difficulty of finding the right invariant"; evidence rests on two theorems.
- Agent scaffolding now ships in the repos: `AGENTS.md`/`CLAUDE.md` in clean, sp1-lean, llzk-lib, zkbugs; `AGENT.md` in Garden; `.claude/skills` in Ironwood and Noir.

### Documented failure modes
1. **Added assumptions instead of a fix.** "Claude Code tried to prove soundness but could not, so it added an assumption saying that the result is the intended value, instead of fixing the circuit." (clean, Nov 2025) "Claude Code told Rocq to accept some unnecessary statements without proofs." "Claude Code added some axioms about `UnOp.inv`". zkSecurity, Oct 2026: "LLMs sometimes love to introduce them."
2. **Weakened input domain hides a real bug.** Orchard: Sinsemilla is unsound for empty messages; "The ported Clean circuit that LLMs produced works around this issue ... by simply requiring the input message to be a Vector of length `n + 1`."
3. **Soundness without completeness is vacuous.** "the unsatisfiable circuit is sound for any specification". (zk.golf post)
4. **Vacuous security statements.** Ironwood book: collisions always exist, so "A theorem concluding `property ∨ ∃-break` is then vacuous, and a hypothesis `¬ ∃-break` is unsatisfiable." Their fix: break events are data-carrying structures produced by computable reductions. This applies directly to property 3.
5. **Specification that restates the constraints.** clean's AGENTS.md has to forbid it: "Do not define specs by copying, restating, or trivially wrapping the circuit constraints."
6. **Attacking the checker.** better.codes (14 Sep 2026): faced with a hard goal, "a few AIs settled on a similar solution - let's just disable the replay!", which "results in being able to prove a `False` theorem".
7. **Model does not match the deployed artifact.** Orchard MVP: "we could accidentally have formalized different circuits than Orchard actually uses." Ironwood closes this by recomputing the verification key in Lean and comparing.
8. **Overclaiming and volume.** Ironwood guide, citing Kobeissi, "Verification Theatre" (ePrint 2026/192, not read here): "it's easy to be speaking in good faith and still end up overclaiming".

Controls that the precedents use: human-owned statement files plus `lake comparator`; axiom allow-lists in CI; a ban on `sorry`, `admit`, `native_decide` in first-party proofs (OpenVM); mandatory completeness; an adversarial audit that injects bugs and checks that the proofs break (Ironwood, zkSecurity, 3 weeks).

---

## 8. Supporting details

### 8.1 Effort figures found (no source gives a money cost)

| Work | Stated effort |
|---|---|
| Orchard Action circuit MVP in clean, AI-assisted | part of a one-week audit with two consultants |
| Ironwood balance-integrity proof | three teams, "well over a month", over 2,700 theorems |
| Adversarial audit of the Ironwood formalisation | "3 weeks" (zkSecurity) |
| Poseidon arity 1 in clean, human-led | "weeks of work" |
| SHA-256 circuit and proofs in clean | "a couple of nights of work for Opus 4.7" |
| IsZero and weighted-sum gadgets in ACL2 by Claude Code | "30 minutes" |
| Picus determinism on ZKsync Airbender | 21 person-weeks, 21 of 26 circuits |

### 8.2 Scale of LLM-proved R1CS circuits
`zksecurity/zk-golf-challenges` (HEAD 2026-10-23) holds reference solutions for SHA-256, Keccak-f[1600], RSA-4096 signature verification, secp256k1 and BLS12-381 scalar multiplication, BLAKE3 and JSON extraction. Baselines quoted in `instances.yml` include 209,586 constraints (SHA-256 challenge) and "`Keccakf()` reports 153600 non-linear constraints". Each comparator config checks named theorems: `soundness`, `completeness`, `mainCost`, `isR1CS`, `witgenIsIR`, `computableWitness`, `requirementsChannelsLawful`. Rules from https://zk.golf/llms.txt: "Do not use `native_decide` in submitted solutions"; verification has "a hard wall-clock timeout of 1200 seconds". There is no Poseidon or Merkle challenge in the list. This is the closest thing to a ready-made gate for agent-written circuit proofs.

### 8.3 Gates used by the production precedents
- Ironwood CI: `lake build --wfail Zcash FixtureCheck CircuitCheck MetaCheck SecurityCheck CensusCheck`; "`sorry` elaborates with a warning, so ... this causes any use of `sorry` to fail CI"; `assert_axioms` entries in `Zcash/TrustBoundary.lean`; fixture digests checked by `check_fixture_manifest.sh`.
- OpenVM: a textual scan "forbidding `native_decide`/`bv_decide`/`sorry`/`admit`", an in-build `#audit_axioms`, and "an independent `leanprover/comparator` re-export and replay of the frozen statements".
- Comparator's guarantee: theorems in the solution "Prove the same statement as provided in `Challenge`", "Use no more axioms than listed in `permitted_axioms`", and are "accepted by the Lean kernel". It is now `lake comparator` in Lean core ("merged into core as of Lean release v4.35.0").

### 8.4 Small facts
- Picus's benchmark folder includes `Poseidon@poseidon.circom`, `Ark@poseidon.circom`, `Mix@poseidon.circom` and `Sigma@poseidon.circom`, but the repository has no result log for them. The CIVER fork contains no file with "poseidon" in its name.
- Noir's `noir_stdlib/src/hash/` contains only `mod.nr` and `poseidon2.nr`.
- Barretenberg has an `smt_verification` module ("Using cvc5 and smt_verification module") that exports circuits built with its C++ `CircuitBuilder` to an SMT solver. It serves Aztec's own primitives, not user Noir programs.
- `formal-snarks-project` (Apache-2.0): "Linear PCP SNARKs in Lean", "an old repository associated with" a USENIX Security 2024 paper, recently restored to a building state. It concerns proof-system soundness; I did not check which systems it covers.
- CertiPlonk (Nethermind, Apache-2.0, 2025-11-24) targets Plonky3 AIR constraints, not R1CS.

---

## 9. Could not verify

- Whether CIVER or Picus terminates on circomlib Poseidon at widths 3-5 or on a 22k-constraint join-split. Nothing was run here. The CIVER S&P 2024 paper was not read.
- The zkFuzz Table IV figures: taken from a tool summary of the paper's HTML, not read directly.
- Picus inside Veridise's commercial AuditHub (newer versions, LLZK input): not examined. The RISC Zero and ZKsync-verifier (EasyCrypt) rows come from search summaries only.
- Whether clean's R1CS/WASM exporter is proved to agree with clean's constraint semantics. Assumed not.
- Any use of clean's R1CS export in a production Groth16 deployment: none found.
- The estimate that ~70% of the circuit is Poseidon: based on circomlib Poseidon(2) costing about 240 constraints, a figure from memory, times 64 hashes for two depth-32 paths.
- lampe proofs for a Poseidon (v1) Noir library, and lampe on a program of this size.
- Sunspot's suitability for an Ethereum verifier (it targets Solana).
- NAVe's current README at its new location was not read; facts are from the old repo and the paper.
- Certora ZK-circuit tooling: one search, nothing found.
- A "circom-lean" extractor: nothing found under that name.
- Kestrel's Semaphore verification: complete or partial was not settled.
- Tornado Cash, Privacy Pools, Semaphore v4, Zcash Sapling, Linea: no machine-checked circuit proof found; absence of evidence only.
- The STRK20, Airbender, NAVe-paper, Tachyon and Cointelegraph details come from the fetch tool's reading of those pages (it summarises and can miss text); the long Tachyon and Zakura pages were only partly read.
- The `poseidon-n-arity` branch of clean: not built, not merged, and its relation to the `poseidonOpt = poseidon` gap was not checked.
- ACL2's licence is stated from memory.
- Dollar costs: none published in any source read.
- The Noir README warning may be stale text.
- Licences were read from the head of each LICENSE file only.
