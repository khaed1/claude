# Fifth adversarial review, circuit, notes and pool (reviewer CORE)

**Reviewed:** "Murmuration v4 specification, revision 4.5", plain-text rendering `murmuration_spec_r45.txt` (1,732 lines), read on 2026-11-12.
**Area:** how a payment moves, the pool, private rewards, the build specification from "Conventions" through "Keys, notes and addresses", the circuit, contracts 1 (Pool) and 2 (Verifier), state machines, wallet and relayer rules, size and gas, what operators can see, and the parameter, default and risk rows that concern them.
**Independence:** no other file in this repository was opened; no earlier note or git history was read.

## Verdict

PROVISIONAL (second run; the whole page has now been read once, findings are still being written up and committed one at a time).

- Pass or fail: **does not pass** as it stands. One high-if-misread finding (X-1) is open.
- Counts so far: critical 0, high 0, high if misread 1, medium 0, low 0. More medium and low findings are being written; no further critical or high candidate has survived a first pass over the circuit, the notes and the pool.
- Status: X-1 was recorded by a first run that was cut off. This run re-read the specification in full, re-derived X-1 independently and keeps it (see the note at its end).

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

**Second run, same reviewer, after a full re-read.** Kept, with one sharpening. The precise condition is this: a public input `x` can be shifted exactly when some assignment of changes to the signals, with a non-zero change for `x`, is annihilated by all three constraint matrices at once. A public input that feeds a real multiplication (directly or through linear rows) is safe, because that row forces its change to zero. `gRef`, `root`, the nullifiers, the commitments, `publicAsset` and, when the range checks are bit decompositions, `publicAmount` and `relayFee` are safe for that reason under any export I could think of. `extHash` is the only public input whose single use is left to the builder, which is why it is the one at risk. If the key is built by snarkjs the extra rows it adds make every public input safe whatever the circuit says; but then the page's own warning about `publicAmount` and `relayFee` would be moot too, so the page is written for a key-building tool that adds no such rows, and under that assumption its criterion is insufficient. The page should name the tool and state the criterion for the system as that tool extends it.

### X-2. Medium (high under the most literal of three readings). The rule that matches a proof to a checkpoint is not defined when both checkpoints carry the same index, which is every hour once emissions end

**Where.**

- Public-input table, row `root` (line 661): "`rootCur` when `gRef` is `gCur`, and `rootPrev` when `gRef` is `gPrev`. No other root is accepted".
- Same table, row `gRef` (line 667): "`gCur` or `gPrev`, with the root saved at the same checkpoint".
- The index stops moving: "rate = USERS × 2^step / D while t < 730 days, and 0 afterwards" (line 772), and "If `g` would still pass 2^90 − 1 the pool holds it there" (line 605).
- The promise the rule has to keep (line 988): "Built against the current one, it stays valid until two more rolls have happened".

**What is wrong.** The first row selects the root by the value of `gRef`. That works while `g` moves between two rolls, which it does during the 730 days of emission (about 1.3 × 10^8 to 5.4 × 10^8 units a second, so never zero in an hour). From day 730 after `START` the rate is zero for good, so after the second roll past that day `gCur = gPrev` for ever, while `rootCur` and `rootPrev` still differ whenever a leaf was inserted between the two rolls. Withdrawals have no end date, so this is the pool's permanent state, not a corner. Three builds follow from the same two rows:

| Reading | Code | After day 730 |
|---|---|---|
| A, a pair | accept if `(gRef, root)` is `(gCur, rootCur)` or `(gPrev, rootPrev)` | Works as the page intends |
| B, select by `gRef` | `if gRef == gCur: require root == rootCur; else if gRef == gPrev: require root == rootPrev; else revert` | A proof against the previous checkpoint is never accepted again. A proof dies at the first transaction of the next hour instead of the hour after. A spend that is the first transaction of an hour and was proved in the hour before reverts, and its own roll is undone with it |
| C, two rules | `if gRef == gCur: require root == rootCur` and `if gRef == gPrev: require root == rootPrev` | A spend is accepted only while `rootCur == rootPrev`, that is, only in an hour that follows an hour with no insert at all |

**Steps under reading C, with numbers.** Day 731. Hour 10 has one spend, so a leaf is inserted. First transaction of hour 11 rolls: `rootPrev` is the root before that leaf, `rootCur` the root after, `gCur = gPrev`. Every spend in hour 11 has `gRef` equal to both, must equal both roots, and reverts. Activations still insert leaves, because they need no proof. Whoever holds a stock of approved minimum deposits (1,000 of the pool's token is about $0.13 at the starting valuation, plus about $0.35 of gas for the deposit and the activation at 0.2 gwei) activates one in each hour and no spend is accepted in the next. That is about $12 a day to stop every exit until deposits close at year four, and after that the pool still alternates: one hour open, one hour shut, as soon as anyone uses the open hour.

**Why the tests on the page would not catch it.** The canary line is "Spends and refunds after deposits have closed and emissions have ended" (line 1057) and, separately, "against the previous checkpoint" (line 1051). A quiet canary with one user has `rootCur == rootPrev` at most rolls, so a single spend after day 81 passes under all three readings. The fault then shows two years after `START` in a contract nobody can change.

**Who and cost.** Under B nobody attacks; every user loses the second hour of validity and relayers lose the gas of spends that straddle the hour (the check is before verification, so tens of thousands of gas each). Under C anyone, for about $12 a day.

**Consequence.** B: a promise on the page is false for ever after day 730, fails safe. C: a cheap lasting denial of spends. I rate the finding medium because I expect most builders to write B or A; a builder or a test writer who turns each table row into its own `require` writes C.

**Smallest fix.** Replace the `root` row by "the pair (`gRef`, `root`) equals (`gCur`, `rootCur`) or (`gPrev`, `rootPrev`)", say that both pairs are tried when the two indexes are equal, and add a line to the canary and to the fuzzing job: after emissions end, insert a leaf, roll, and land a spend proved against the checkpoint before that roll.

**Confidence.** Certain that the rows are ambiguous and that `gCur = gPrev` holds for ever after day 730. Depends on reading which build results.

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
