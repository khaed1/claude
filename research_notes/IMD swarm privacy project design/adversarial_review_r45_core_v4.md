# Fifth adversarial review, circuit, notes and pool (reviewer CORE)

**Reviewed:** "Murmuration v4 specification, revision 4.5", plain-text rendering `murmuration_spec_r45.txt` (1,732 lines), read on 2026-11-12.
**Area:** how a payment moves, the pool, private rewards, the build specification from "Conventions" through "Keys, notes and addresses", the circuit, contracts 1 (Pool) and 2 (Verifier), state machines, wallet and relayer rules, size and gas, what operators can see, and the parameter, default and risk rows that concern them.
**Independence:** no other file in this repository was opened; no earlier note or git history was read.

## Verdict

IN PROGRESS. The review is not finished; this section is rewritten at the end.

- Pass or fail: not yet decided.
- Counts by severity: not yet counted.
- Status: skeleton committed before reading; findings are added and committed one at a time.

## 1. Findings, most severe first

Ids are in order of discovery. Line numbers are those of the text rendering.

### X-1. High if misread. Lemma 10 and the test in part B do not exclude a circuit whose proofs anyone can re-target

**Where.** Three passages that have to work together.

- Constraint 15 (line 700): "Binding. `extHash` takes part in one constraint so that no tool can drop it from the proof." The form of that one constraint is left open.
- Lemma 10 (line 719): "Each of the 11 occurs in a constraint that survives compilation, and their columns in the constraint system are linearly independent, so the key holds a separate point for each one and a proof made for one set of public inputs does not verify for another. […] the check is simple: the eleven public-input columns have rank eleven."
- Part B (line 722): "On the deployed verifier, changing any one public input of a valid proof makes it fail". Part C (line 724): "Groth16 has that property when the public-input columns are independent, which lemma 10 checks, and every claim that a relayer cannot alter a spend it was handed rests on it".

**What is wrong.** The property the pool needs is: someone who sees a valid proof cannot produce a valid proof for different public inputs. Independence of the eleven public-input columns *among themselves* is not enough for that. The columns also have to be independent of the columns of the private signals. In Groth16 the key contains, for every private signal `j`, the point `K_j = (β·A_j + α·B_j + C_j)/δ`. If the column of a public input `x` (its coefficients across all rows of A, B and C) equals a combination `Σ c_j × column_j` of private columns, then anyone can take a proof `(A, B, C)` for the value `x`, and for any `t` publish `(A, B, C − t × Σ c_j K_j)`, which verifies for `x + t`. No witness is needed, only the public key.

**A circuit that passes everything on the page and is broken.** Write constraint 15 as an equality with a fresh private signal: `extHash − d = 0`, where `d` occurs nowhere else. This is "one constraint", and it "survives compilation" in the named tool chain, whose exporter "writes one row per linear constraint" (line 1656). Then:

1. Relation theorem: holds (the formal constraint 15 is that equality).
2. Lemma 8: holds (`d` is determined by the inputs).
3. Lemma 10: holds. `extHash` occurs in a surviving constraint and the eleven public columns have rank eleven.
4. Part B: holds. Changing `extHash` and re-sending the *same* proof fails.
5. Analysers for under-constrained circuits: clean, nothing is free.
6. The attack: the column of `extHash` is minus the column of `d`. A relayer, or anyone who sees the transaction before it is included, computes a new `ext` (their own address as `recipient` and `relayer`, any ciphertexts), sets `t = extHash' − extHash`, and sends `(A, B, C + t × K_d)` with `extHash'`. I ran this on a toy Groth16 instance (`core/groth_shift.py` in the review folder): the same proof fails for the new hash, the shifted proof verifies.

**Who and cost.** Any relayer handed a spend, and any observer of a spend sent from a public address. Cost: one transaction. **Consequence under that construction:** every withdrawal and every relay fee in flight can be redirected, the nullifiers are consumed and the user's notes are gone. That is critical. Under the usual construction (`extHash × extHash = s`, or `extHash × 0 = 0`) the column of `extHash` has entries in A or B that no private signal shares, and the attack does not exist.

**Why this is "if misread" and not certain.** Nothing on the page says which form constraint 15 takes, and the unsafe form is the less usual one. But the whole point of lemma 10, part B and part C is that safety must not depend on the builder choosing well, and all three accept the unsafe form. The same wrong criterion is used for the pair `publicAmount`, `relayFee` ("Their separate range checks in constraint 3 are what give them separate columns"). That pair happens to be safe when the range check is a bit decomposition with one boolean constraint per bit, because no combination of bit columns equals the difference of the two public columns. It is safe for a reason the lemma does not state.

**Part C misquotes the theorem it leans on.** The published result (Baghery, Kohlweiss, Siim, Volkhov, "Another Look at Extraction and Randomization of Groth's zk-SNARK", 2021, as I recall it and did not re-fetch) needs two things of the left-hand (A) polynomials: those of the public inputs are linearly independent, *and* their span meets the span of the private ones only in zero. A public input that occurs only on the C side has a zero A-polynomial and fails the first condition even though its stacked column is non-zero. snarkjs repairs this by adding one row `x_i × 0 = 0` per public input when it builds the key. Whether the tool that builds this key does so is not on the page.

**Smallest fix.**

1. Constraint 15: fix the form, for example `extHash × extHash = extSquare`.
2. Lemma 10: replace "the eleven public-input columns have rank eleven" by "no non-zero combination of the eleven public-input columns lies in the span of the other columns (the constant and every private signal)", that is, rank(all columns) = rank(private and constant columns) + 11, checked on the system as the key-building tool extends it. State the A-side condition of the theorem as well.
3. Part B: add the attack as a test. For each public input and each private-signal point in the proving key, shift `C` and check that no shifted proof verifies for a changed input; or, simpler, check the rank condition of point 2 on the exported system with a second tool.
4. Part C: quote the theorem's hypothesis exactly.

**Confidence.** Certain that the three checks accept the unsafe circuit and that the attack works on it (run). Depends on reading whether a builder would produce it.

## 2. Contradictions between sections

| Passage A | Passage B | Which one a builder would follow |
|---|---|---|
| (none recorded yet) | | |

## 3. Points a builder would have to guess

(none recorded yet)

## 4. What held

(none recorded yet)

## 5. Suspicions not made concrete, and what was not checked

(none recorded yet)
