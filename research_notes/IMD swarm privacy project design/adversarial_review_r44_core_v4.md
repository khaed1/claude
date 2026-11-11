# Adversarial review of Murmuration v4, revision 4.4: circuit, notes and pool

## 1. Header

- Reviewed: "Murmuration v4 specification, revision 4.4", dated 11 November 2026, in its plain-text rendering (1,615 lines). Line numbers below refer to that rendering.
- Reviewer's area: "How a payment moves", "The pool", "How private rewards work", the build specification from "Conventions" through "Keys, notes and addresses", "The circuit", contract 1 "Pool" and contract 2 "Verifier", "State machines", "Rules for the wallet and the relayer", "Size, gas and state pricing", "What operators can see", and the rows of the parameter, defaults and risk tables that concern them. The pool's interface with the registry (`isApproved`, `isRefused`, `START`) is included.
- Method: the whole page was read once in full. No other file in the repository was opened. Arithmetic was redone with scripts kept outside the repository.
- Verdict, for this area only: it passes the test the page sets, with two caveats. I found no critical fault and nothing I rate high or high if misread. The circuit as fifteen equations, the pool's ledgers, the reward index and the new relay-fee path held against every attack listed in section 5.
- Counts: 0 critical, 0 high, 0 high if misread, 4 medium (P-1 to P-4, two of them dependent on reading), 3 low (P-5 to P-7), 15 contradictions between sections, 22 points a builder would have to guess.
- The two caveats, where the letter of the calibration and my rating differ, so that the owner can decide. P-1 is "a way around the standard exit sizes", which the calibration lists under high. I rate it medium because the 0.2% is still paid, no balance can be exceeded, and the only privacy it weakens is that of the user who takes the route. If the owner holds that standard sizes must be enforced by the contract, P-1 is high and the page does not pass. P-4's literal reading locks an unactivated deposit for good, for a narrow class of depositing contracts. I rate it medium because the page already accepts the general case of a depositor that cannot receive its own asset back, and because the page's own record rates the two nearest earlier faults medium (a recipient that refuses payment, line 448, and a wallet that could not be restored, line 397).
- What should change before a build job is written: the wording of lemma 11 and of two other statements to be proved (P-3), the refund's missing fallback (P-4), the address format (P-2), and either the constant in the relay-fee ceiling or the sentences that describe it (P-1). Each fix is a sentence or a few lines.

## 2. Findings

Terms used below. A *spend* is one call of `Pool.spend` with one proof. The *relay fee* is the public input `relayFee`, an amount paid by the pool to the address named as `relayer`. The *ceiling* is the largest `relayFee` the pool accepts in a block. *Base fee* is the per-gas price every transaction in a block must pay, set by the protocol (EIP-1559), which rises by at most 12.5% after a full block. *Self-relay* means a user names an address of their own as `relayer`.

### P-1. Medium. The relay-fee ceiling is 46 times the gas cost today for ETH and 372 times for every other asset, with no limit per day, so the relay fee is a second way out in any amount

**Where.**

- Line 668: "For ETH it is `(4 × block.basefee + 1 gwei) × 2,000,000` param: enough for a relayer when gas is anywhere near normal, and never enough to be worth using as a way out. For another asset it is eight times that param, converted at a rate frozen in the build".
- Line 90: "The relayer's fee is public, like a gas payment, and is limited to a few times the cost of the gas."
- Line 123: "The relay fee is the only other way value leaves, and it is limited to a few times the gas cost".
- Line 333: "Dust below the smallest size can never leave by itself." Line 1312: "A stablecoin remainder under 10 cannot leave by itself."
- Line 1267: "base fee 0.046 gwei at 00:13 UTC, seven-day mean 0.203 gwei (median 0.058)".

**How it works.** The ceiling has a constant part, 1 gwei × 2,000,000 gas = 0.002 ETH, that does not shrink when gas is cheap. At the base fees the page itself reports, the constant part is nearly all of it. Redone with `ceiling.py` (ETH at $2,130, relayed spend 1,107,000 gas, owner-sent spend 1,082,000 gas):

| Base fee (gwei) | Ceiling, ETH spend | As a multiple of the gas cost | Ceiling, any other asset | As a multiple of the gas cost | Gas as a share of a self-relayed amount, other assets |
|---|---|---|---|---|---|
| 0.046 (10 Nov) | 0.002368 ETH ($5.04) | 46.5 | $40.35 | 372 | 0.26% |
| 0.058 (7-day median) | 0.002464 ETH ($5.25) | 38.4 | $41.99 | 307 | 0.32% |
| 0.2 (planning price) | 0.0036 ETH ($7.67) | 16.3 | $61.34 | 130 | 0.75% |
| 2 | 0.018 ETH ($38) | 8.1 | $307 | 65 | 1.50% |
| 20 | 0.162 ETH ($345) | 7.3 | $2,760 | 58 | 1.67% |
| 253 (spike of 29 Oct) | 2.026 ETH ($4,315) | 7.2 | $34,523 | 58 | 1.69% |

Steps, at today's base fee, for a holder of shielded USDT who wants 137.42 USDT at an address without using a standard size:

1. Build a spend with `publicAmount = 0`, `publicAsset = 2`, `relayer` = the holder's own address, `relayFee = 40.35 USDT`. Send it from any funded address. The pool checks `relayFee ≤ feeCeiling` (40.35 USDT), takes 0.2%, and pays 40.27 USDT to the address.
2. Repeat three more times with 40.35, 40.35 and 16.37 USDT.
3. Cost: four spends at 1,082,000 gas and 0.046 gwei, about $0.11 each, plus the 0.2%. No standard size was used and nothing limits how often this is done.

The same route removes "dust": a 7 USDT or 0.004 ETH remainder, which lines 333 and 1312 say can never leave by itself, leaves in one or two self-relayed spends.

Per day there is no bound in the contract. At the gas target of 30M per block, 27 spends fit in a block, 194,400 a day: about 460 ETH a day by the ETH route and about $7.8M a day in each of the other assets, more than the whole pool holds at the stop on the caps ($5.1M). Above the target the base fee rises and the ceiling rises with it.

**Across prices.** For an asset other than ETH the ceiling is a number of that asset's units fixed by the frozen rate, so its worth moves with the asset's price. If the pool's token trades at 16 times its starting valuation (three quarters of the public pool bought, line 961), its ceiling is worth about $650 a spend at today's base fee, some 6,000 times the gas. If an asset falls, the ceiling falls with it: relaying stops paying when the asset is worth about a 370th of its frozen rate at today's base fee, and about a 50th to a 70th from 1 gwei up, which is the figure the page gives (line 668).

**Who can move the base fee, and what it buys.** Anyone who pays to fill blocks. Raising it from 0.05 to 20 gwei takes 51 full blocks and burns about 10 ETH; to 100 gwei, 65 blocks and about 51 ETH. It buys a larger ceiling per spend (0.162 ETH or $2,760 at 20 gwei). It is not worth paying for: the same ceilings arrive for nothing in every natural spike, and the 0.2% is charged either way. Nobody can push the ceiling below 0.002 ETH, so relaying in ETH cannot be priced out from below.

**Who and cost.** Any holder of shielded funds, for gas of 0.26% of the amount (assets other than ETH) or 2.1% (ETH) at today's base fee, on top of the 0.2%.

**Consequence.** No funds are at risk and the 0.2% is always paid: the per-asset balance check and the fee apply to the relay fee as to a withdrawal (see "What held"). What fails is the description, in four places:

1. "A few times the cost of the gas" is false by a factor of 6 (ETH) to 50 (other assets) at the gas prices on the page. It is true only above roughly 2 gwei, and then only for ETH.
2. "Never enough to be worth using as a way out" is false for USDT, USDC, IMD and the token: 0.26% of extra cost buys an exit in any amount.
3. Standard exit sizes are therefore a default that each user can step around, not a property of the pool. This harms only the user who does it: other users' withdrawals are not made easier to match.
4. The contract ceiling does not protect a user from an expensive relayer in a thin asset. The wallet rule at line 884 ("The wallet refuses a quote above the fee ceiling less a margin") lets a quote of $40 through for a job that costs $0.11. Where one relayer is the only one accepting an asset (IMD and the pool's token are the likely cases), that is what it can charge.

I rate this medium and not high. The calibration lists "a way around the standard exit sizes" under high, and by the letter this is one. But the user who takes it pays the fee, cannot exceed any balance, and weakens nobody's privacy but their own. The owner may weigh that differently.

**Smallest fix.** Either of two, and the first costs nothing:

- Keep the formula and correct the page: say that the ceiling is about 0.002 ETH plus eight times the base-fee cost of a spend (eight times that again for other assets), that any amount can leave through it in pieces, and that dust can leave this way. Add to the wallet rule that a quote is refused when it exceeds a multiple of the *current gas cost*, not only when it exceeds the contract ceiling.
- Or shrink the constant. `(4 × basefee + 0.1 gwei) × 2,000,000` gives about 11 times the gas cost today and still 7.2 times in a spike. The cost is less room for priority fees when the base fee is near zero: 0.1 gwei of headroom instead of 1.

**Confidence.** Certain (arithmetic from the page's own figures).

### P-2. Medium, depends on reading. A payer cannot fill in the diversifier that ciphertext 0 must carry, and a restored wallet has no rule for finding it

A *diversifier* (`d`) is the 8-byte value mixed into a wallet's owner key so that one wallet can have many owner keys. To spend a note the owner must know the `d` that note was made with.

**Where.**

- Line 529: "`ownerPk = H4(TAG_PK, spk, nk, d)`". The owner key is a hash, so `d` cannot be read back out of it.
- Line 548: "Address a payer needs: ownerPk (32 bytes) followed by the recipient's X-Wing public key (1,216 bytes)." No `d`.
- Line 557: ciphertext 0's "payload is asset (1 byte), value (12), accrued (12), rho (31), diversifier (8) and a memo (16)."
- Lines 542 and 544 derive `d` for a deposit (`"deposit-d" ‖ n`) and for outputs 1 and 2 of the wallet's own spends (`"out-d" ‖ nf0 ‖ slot`). Nothing derives the `d` of an address handed to a payer.
- Line 552: "A wallet is rebuilt from its seed and the chain. This is a rule for the wallet, not a suggestion."

**How it works.** Bob gives Alice an address made with some `d_B`. Alice holds `ownerPk_B` and Bob's encryption key and nothing else. She must write 8 bytes of "diversifier" into the payload of ciphertext 0 and has no way to know `d_B`. Two readings follow.

- Reading 1: the address really carries `d` (it would then be 1,256 bytes, not 1,248, and the short address 72, not 64). Alice copies it into the payload. Bob's restored wallet decrypts, reads `d_B`, rebuilds `ownerPk_B`, checks the commitment and can spend. This works for any way of choosing `d_B`, but it is not what line 548 says.
- Reading 2: the address is as line 548 says. Alice writes zeros. Bob's wallet must find `d_B` by itself. If the builder picked `d_B` at random when the address was made and kept it in the wallet's local storage, a wallet restored from its seed sees the payment, shows the balance, and cannot build `ownerPk_B`. Searching 2^64 values of `d` with a Poseidon hash each is not practical. The note is lost to that user for good.

**Who and cost.** Nobody attacks. It happens to any user who receives a payment at an address and later restores from the seed, under reading 2 with a `d` that is not derived.

**Consequence.** Under the worse reading, received funds are unspendable after a restore. Launch gate 7 ("a wallet restored from its seed alone recovers every note in the canary") catches it only if the canary script includes a payment from a second wallet to an address the first one handed out, and the canary list at line 935 does not name such a spend. I rate it medium and not "high if misread" because line 552 is explicit that restoring from the seed is a rule, so a builder who meets the gap is told to stop and ask.

**Smallest fix.** One of:

- Put `d` in the address (and in the short address) and say the payer copies it into the payload. Then say the wallet derives address diversifiers as `first 8 bytes of HKDF(viewRoot, "addr-d" ‖ m)` for a counter `m`, so nothing depends on local storage either way.
- Or drop `d` from the design. It hides nothing on-chain that `rho` does not already hide (the only place an owner key reaches the chain is inside `ownerCommit = H3(TAG_OC, ownerPk, rho)`), and line 555 already says it "does nothing for addresses". Without it there is nothing left that a restored wallet cannot derive.

Add to the canary list: a payment from one wallet to an address of another, spent by the second wallet after a restore from its seed.

**Confidence.** Certain that the two passages contradict each other. The loss depends on reading.

### P-3. Medium. Lemma 11 is false as written, is not a property of the constraint system, and its natural repair is empty where it matters. Two more statements in part A cannot be proved as worded

A *constraint system* is the list of equations the proof system enforces. A statement about it can be machine-checked. A statement about which states the Pool contract can reach cannot be read off it.

**Where.**

- Line 616: "A. Machine-checked on the constraint system that goes into the ceremony."
- Line 628, lemma 11: "For every state the pool can reach, with values, indexes and checkpoints anywhere in the ranges the parameter table allows, the honest witness satisfies the constraints. This covers ... the ends of every range."
- Line 596, constraint 3: "Every `value`, `accrued`, `claim`, `earned` ... fits in 96 bits. `gRef` and each input's `index` fit in 90 bits."
- Line 634, part D: "For each asset the values of all unspent notes add up to at most `shielded`, which is what keeps `earned` inside 96 bits."
- Line 515: "The build script computes the largest possible value from the parameter file and fails unless it is under 2^88."
- Line 626, lemma 9: "No sum, product or difference reaches the field modulus in constraints 8, 9, 12, 13 and 14".

**How it fails, with numbers.**

1. *Lemma 11 is false over the ranges.* Take values every one of which is inside the ranges the page gives: an ETH note of 800 ETH (the cap), weight 807, `index = 0`, `gRef = 2^88 − 1` (inside the 90-bit range and inside the build's own limit for the index). The honest `earned` is 807 × 8×10^20 × 2^88 ÷ 2^64 ≈ 2^103. It does not fit in 96 bits, so constraint 3 cannot be satisfied (`arith.py`). "Anywhere in the ranges" and "the ends of every range" therefore name spends the circuit rejects. The lemma is true only for states the pool can actually reach, where total reward earned is at most `released`, which is at most the users' 45%, which is under 2^96 whenever the supply rule of line 512 holds. I checked that bound on paper and in a model (`model.py`, 40 random runs over the full schedule: largest `earned` seen 2^85).
2. *That bound is a fact about the Pool, not about the circuit.* It needs three things the constraint system does not contain: that note values add up to at most `shielded`, how the pool advances `g`, and the supply limit. The page puts it in part D (tests, fuzzing, audits) at line 634 and at the same time puts lemma 11, which depends on it, in part A (machine-checked). The build plan has no job that models the Pool contract in the proof checker.
3. *The build's check is not the one that matters.* A parameter file that passes "`g` under 2^88" tells nothing about `earned`: 2^88 with an 800 ETH note gives 2^103. The check that does the work is supply × 10^18 < 2^96.
4. *What a proof writer will do.* The statement cannot be proved as worded, so the job that freezes the formal statements has to add a hypothesis. The easy one is "the witness passes the circuit's range checks". With that hypothesis the lemma says nothing about any range check: a circuit whose check on `value` is 88 bits wide instead of 96, or whose check on `gRef − index` is 80 bits instead of 90, satisfies the relation theorem (88 bits implies 96), satisfies lemmas 1 to 10, and satisfies this lemma 11. That is the fault the lemma was added to exclude ("a constraint that is one bit too tight would lock notes for good", line 628). The page itself lists "added assumptions" as the known failure of agent-written proofs (line 1462).
5. *Lemma 9 is false for constraint 14.* `publicAsset` has no range check in constraint 3 and is free when both public amounts are zero, so `asset − publicAsset` wraps around the modulus in satisfying assignments (asset 1, `publicAsset` 7). It does no harm, because the other factor is then zero. But the lemma as worded cannot be proved, and what constraint 14 needs is narrower: that `publicAmount + relayFee` does not wrap.
6. *Lemma 3, second sentence* ("Two satisfying assignments that spend the same position publish the same nullifier") is false for two assignments with different `root` values, and with the same root it holds only under the hash assumption of part C. It needs both said.

7. *Part C names one property of Groth16 and the page relies on two.* Line 632 assumes "that Groth16 proofs can only be made by someone who knows a satisfying assignment". A relayer who is handed a proof is in a different position: it has seen a valid proof made with the witness it lacks. That it cannot turn this proof into one for another recipient, relayer or split is a second property (a proof seen for one statement does not help to prove another). Groth16 has it, under the same kind of assumption, exactly when the public-input columns are independent, which is what lemma 10 checks. It should be named in part C, because every claim that a relayer cannot alter a spend rests on it and not on the first.

**Who and cost.** Nobody attacks this. It decides whether the proofs, which replace an external audit, exclude a circuit that locks notes.

**Consequence.** As the page stands, the one lemma that answers last round's high finding (C-5, "Nothing required honest spends to work") either cannot be proved or is proved in a form that lets a too-tight range check through. The canary and the comparison against the Circom copy would catch a gross error (a 64-bit check fails on the first IMD note). They would not catch one in a range the canary never reaches: the canary's largest ETH exit is 10 ETH, so a 64-bit check on `publicAmount` (18.4 ETH) passes there and blocks every ETH exit of 20 ETH or more on mainnet, and the canary's `g` ends near 2^80.5. I rate it medium because a lock needs a second error, in the circuit, on top of the weak statement.

**Smallest fix.** Split lemma 11 and write its hypotheses down.

- 11a, part A, machine-checked. For every tree and every one or two notes in it with one `sk` and one asset, every `gRef`, and every choice of outputs, `claim` and public amounts for which these *integer* statements hold, the frozen witness generator produces an assignment that satisfies the constraint system: each value, `accrued` and `claim` is under 2^96; each `index ≤ gRef < 2^90`; `weight × (value₀ × (gRef − index₀) + value₁ × (gRef − index₁)) < 2^160`; the two conservation equalities hold over the integers; the positions differ. No hypothesis may mention a signal of the circuit. The witness generator is frozen with the statements, or "the honest witness" can be chosen to suit the proof.
- 11b, part D, argued on paper and fuzzed. In every reachable state those statements hold for every spend an honest wallet can form. The only one that is not immediate is the 2^160 bound. It follows from: note values add up to at most `shielded`; an input's index is at most `g`; reward earned in total is at most `released ≤ USERS`; and supply × 10^18 < 2^96.
- Reword lemma 9 for constraint 14 to "`publicAmount + relayFee` is under the modulus", and lemma 3 to "under one root, and assuming no hash collision".
- In part B, add a paired test to the single-input test: a valid proof must fail when `publicAmount` is raised by δ and `relayFee` lowered by δ. The single-input test at line 630 passes even when the two inputs share a key point, which is the failure lemma 10 is about ("pairwise different" at the same line does catch it).

- Add to part C: a proof seen for one set of public inputs does not help anyone without the witness to make a proof for another.

**Confidence.** Certain for items 1, 3, 5, 6 and 7 (arithmetic, a counter-example, or the text of line 632). Likely for item 4.

### P-4. Medium, depends on reading. A refund is the one ETH payment with no fallback. If it is sent with the 50,000-gas allowance, a depositing contract whose receiving code costs more can never be refunded, and Glamsterdam's storage prices put ordinary contracts in that group

**Where.**

- Line 520: "ETH payments | By `call` with a gas allowance of 50,000 param. If the call fails the amount is credited to `owed[address]` and the transaction goes on. ... The one exception is a refund, which reverts if its payment fails".
- Line 660: `refund` "Reverts if that payment fails, so the record stays."
- Line 663: `claimOwed` sends "with all remaining gas".
- Line 121: "Screening failure or capture can never trap funds". Line 88: "No screening decision can stop it."
- Line 177: "A shared deposit contract is one depositor for all of its users".
- Line 903: "A new storage slot | 22,100, then 110,020".

**The two readings.** Line 520 states the exception only for what happens on failure. Read literally, a refund is still sent with 50,000 gas, and reverts when that is not enough. The other reading is that a refund forwards all remaining gas, as `claimOwed` does. The page does not say.

**How it works under the first reading.**

1. A contract deposits 20 ETH for its users. Its code for receiving ETH records the receipt in a fresh storage slot. Today that costs about 22,100 gas plus overhead and fits in the allowance.
2. Glamsterdam's state pricing (line 903) raises a fresh slot to 110,020 gas. The same receiving code now needs more than the 52,300 gas it is given (50,000 plus the stipend for a transfer of value).
3. The deposit is refused, or the cap is full and stays full, which line 297 calls the most likely failure. The contract calls `refund`. The payment fails, `refund` reverts, the record stays. A refund by a third party after 21 days fails the same way.
4. The pool cannot be changed. If the depositing contract cannot be changed either, the 20 ETH and its fee stay in `pending` until the deposit can be activated, and for good if it stays refused.

Every other ETH payment survives this: a withdrawal or relay fee that fails is credited to `owed` and claimed later with all gas. The refund alone has neither the fallback nor the gas.

**Who and cost.** No attacker. It falls on depositors that are contracts with more than trivial receiving code: shared deposit contracts, some smart wallets, and after the fork anything that writes one fresh slot on receipt.

**Consequence.** Under the first reading, the two sentences quoted from lines 88 and 121 are false for those depositors, and the cause is a gas constant in a contract that cannot follow a fork. The page already accepts one case with no way out (a depositor frozen by a stablecoin issuer, line 859). This would be a second, for ETH, that it does not mention. Unactivated deposits are outside the caps, so the amount is not bounded by them.

**Smallest fix.** Treat a refund like every other ETH payment: if the 50,000-gas call fails, clear the record, credit `owed[depositor]` and let `claimOwed` deliver it with all gas. The "one exception" then disappears from line 520 and the invariant at line 692 is unchanged (the credit is recorded for the depositor and can go nowhere else). Or state that a refund forwards all remaining gas. Either way add a canary line: a refund to a contract whose receiving code uses more than 50,000 gas.

**Confidence.** Certain that the page admits both readings. The lock depends on reading and on the gas figures of line 903, which the page calls provisional.

### P-5. Low. Slots that are empty are made indistinguishable for inputs only. Nothing says what an empty output or an unused ciphertext 0 contains

**Where.**

- Line 553: "Empty inputs are filled with fresh random numbers every time: `rho`, `leafIndex` and `slot`." No matching rule for outputs.
- Line 587: "The sender computes each `ownerCommit` from an address and a `rho`." With no recipient there is no address.
- Line 559: "The pool checks the two lengths and nothing else about the ciphertexts."
- Line 274: "Every spend has that output slot whether it is used or not, so nobody can tell a claim from a payment."
- Line 566: "A spend that its owner sends from a public address ... shows no asset."

**How it works.** An empty output's commitment is `H3(packed(asset, 0, 0), gRef, ownerCommit)`. `gRef` is public and `packed(asset, 0, 0)` has five possible values. If a builder fills the `ownerCommit` of an unused output with a constant (zero is the obvious one), anyone computes the five candidates for each checkpoint and reads off, for every spend: that output 0 has no recipient, which asset the spend is in (also for an owner-sent spend, which line 566 says shows none), and for output 2 that there is no claim, which by elimination marks the spends that do claim. Outputs 1 and 2 are probably safe, because line 544 derives their `rho` without conditions. Output 0 has no rule. The same holds for ciphertext 0: a wallet that posts 1,216 zero bytes when there is no recipient marks those spends at a glance.

**Who and cost.** Any observer, for free, if the builder chooses a constant.

**Consequence.** Under that reading the claim at line 274 fails and owner-sent spends show their asset. No funds are at risk.

**Smallest fix.** One sentence beside line 553: every output, used or not, has an `ownerCommit` made from a fresh or derived `rho` (give output 0 the same derivation as outputs 1 and 2 when the sender keeps it), and ciphertext 0 is always a real encryption, to the sender's own key when there is no recipient. A string of random bytes is not enough: a real ciphertext contains an X25519 public key, which is always a point on the curve, and about half of all random 32-byte strings are not, so random filler can be told from real ciphertexts over many spends.

**Confidence.** Depends on reading.

### P-6. Low. A quote's expiry is not in the proof. A relayer that was handed a spend can land it until two more checkpoints have been taken, which in a quiet pool is never

**Where.**

- Line 884: "A relayer's quote names an amount of the asset being spent and an expiry."
- Line 885: "The wallet does not give the same inputs to a second relayer until the first quote has expired."
- Line 578: `extHash` covers the chain id, the pool, the recipient, the relayer and the two ciphertext hashes. No deadline.
- Line 873: "A proof built against the checkpoint root and `gCur` stays valid until two more rolls have happened".
- Line 1229: "A relayer refuses or delays ... What remains: A short delay".

**How it works.**

1. At 10:10 a wallet hands relayer R1 a proof that withdraws 1 ETH to X with a fee of 0.0001 ETH. The quote expires at 10:15. R1 keeps the proof and sends nothing.
2. At 10:16 the wallet, following line 885, proves again with the same notes for relayer R2 (and may by now pay a different recipient or amount).
3. R1 watches for R2's transaction and lands its own first. R1 is paid its fee. R2's transaction reverts at the nullifier check and R2 pays for about 65,000 gas.
4. If the pool is quiet, as it will be in its first weeks, no roll happens unless someone calls one, and R1's proof stays valid for days.

**Who and cost.** Any relayer, at no cost: it is paid for the spend it lands.

**Consequence.** Bounded. The spend that lands is one the user signed, so nothing is stolen. A relayer can make its competitors lose a little gas on every request it stalls, the wallet cannot treat a handed-over spend as cancelled, and "a short delay" understates what a stalling relayer can do.

**Smallest fix.** Add a `deadline` timestamp to `extHash` and one comparison in `spend`. It costs no constraint and no public input. Otherwise say in the wallet rules that notes given to a relayer stay committed until their nullifiers appear or two later rolls have been seen.

**Confidence.** Certain.

### P-7. Low. Under the wallet's proving rule a note can be spent only after the next hourly checkpoint, so one note supports one spend an hour. The state table says the opposite

**Where.**

- Line 882: "The wallet always proves against the checkpoint root and `gCur`. ... It waits for the next roll before spending a note newer than the checkpoint."
- Line 872: "A note made by a spend carries that spend's checkpoint and can be spent in the next transaction against a recent root."
- Line 91: "A larger amount leaves as several standard withdrawals, spread over time by the wallet." Line 1312: "A full exit of any amount under 1,000 ETH takes at most 16 withdrawals."

**How it works.** Every spend replaces its inputs with new notes, and new notes are "newer than the checkpoint". A wallet holding one note of 999.995 ETH needs 16 withdrawals. Each leaves a change note that the rule forbids spending until the next roll, which can come no sooner than the next hour. The exit takes 16 hours, or about 5 if the wallet first splits the note in two at each step. A user who pays two people within an hour from one note waits up to an hour for the second payment, and so does anyone who wants to pass on a payment just received.

**Who and cost.** Every user of a wallet that follows the rule.

**Consequence.** A usability cost the page does not state, and two passages a wallet builder cannot both follow. Under the other reading (recent roots for fresh notes) the leak named at line 882 returns: observers can tell which spends use notes less than an hour old.

**Smallest fix.** Keep line 882, change line 872 to say that the contract permits it and the wallet does not do it, and state the one-spend-per-note-per-hour cost where exits and payments are described. If the 64 recent roots are then used by no conforming wallet, consider removing them: they cost 64 storage slots, a write on every insert and a lookup of up to 64 cold reads (see section 4).

**Confidence.** Certain.

## 3. Contradictions between sections

"L" is a line of the text rendering. The last column says which passage a builder would follow.

| # | Passage A | Passage B | A builder would follow |
|---|---|---|---|
| 1 | L90, L123, L1251, L1322: the relay fee is limited to "a few times the gas cost" | L668: the formula. At the base fee of L1267 it allows 46 times the gas cost for ETH and 372 times for other assets | L668. See P-1 |
| 2 | L333: "Dust below the smallest size can never leave by itself." L1312: "A stablecoin remainder under 10 cannot leave by itself" | L575, L668: up to 0.0024 ETH or 40 USDT per spend is paid to any address the spender names | L575. The dust sentences are wrong, in the user's favour |
| 3 | L333: the smallest size "is 1 unit for a stablecoin" | L44, L123, L1283, L1312: from 10 | L1283. L333 is left over from before the decision |
| 4 | L548: an address is `ownerPk` and the encryption key | L557: the payer writes a diversifier into ciphertext 0 | Unclear. See P-2 |
| 5 | L616, L628: lemma 11 is machine-checked on the constraint system | L634: the bound it depends on is a property of the Pool, covered by tests | Unclear. See P-3 |
| 6 | L520: a refund is "the one exception" and reverts when its payment fails | L663: `claimOwed` pays with all remaining gas. L121: "can never trap funds" | L520, read literally. See P-4 |
| 7 | L872: a new note "can be spent in the next transaction against a recent root" | L882: the wallet "waits for the next roll" | L882. See P-7 |
| 8 | L88, L121: anyone can send back "a deposit that has stayed refused for three weeks" | L660: anyone can, "once the deposit is at least 21 days old" and is refused now | L660. A deposit that waited 21 days for room under a full cap can be sent back by anyone on the first day it is flagged. L660's own reason ("a refusal that is going to lapse cannot be turned into a forced refund") does not hold for deposits older than 21 days |
| 9 | L141: "The most that a circuit flaw can take is about $160,000 at launch and about $5.1M". L1508: "Caps bound the loss to the sum of the caps" | L1285: "The token has no cap". L276: a fault can "drain the reward budget released so far and any tokens users have deposited" | L276. The dollar figures leave out the token: every deposited token, and up to 45% of supply once released |
| 10 | L1538: "One constant depends on gas: the relay-fee ceiling reads the block's base fee" | L668: the 2,000,000 gas inside the ceiling. L520: the 50,000-gas allowance | Three constants depend on gas prices. The third is the one in P-4 |
| 11 | L840 to L848: the deposit diagram has no way back from Covered to Pending | L727: `apply` "Sets ... `screenedThrough` to the batch's `upTo`". L748: the batch "lowers upTo" | L727. Coverage can move backwards, so a deposit that could be activated yesterday may be neither approved nor refused today. A wallet has to expect it |
| 12 | L566: "A spend that its owner sends from a public address pays no relay fee" | L575, L662: the pool accepts a relay fee on any spend, whoever sends it | L662. It is what makes self-relay possible |
| 13 | L627: "If a builder or a compiler setting removed either range check, the same proof would verify with value moved" | Arithmetic: with one of the two checks left, the two inputs still have different columns. Both must be gone (`columns.py`) | Keep both, as L596 says. The sentence overstates, on the safe side |
| 14 | L211: "after activation nothing connects the deposit to what happens inside" | L117: "inside the pool a small asset's crowd is the users of that asset". L1526 | L117. For an asset with a handful of depositors, every relayed spend of it is tied to that handful |
| 15 | L668: an asset's price must fall "to roughly a fiftieth". L1529: "IMD and the pool's own token are the assets this could happen to" | Arithmetic: a 372nd at today's base fee, a 47th to a 72nd from 1 gwei up. USDT and USDC reach it if ETH rises about fifty-fold in dollars, and the pool has no end date | The figure is right for busy blocks only |

## 4. Points a builder would have to guess

1. The diversifier of an address handed to a payer: how it is chosen, whether the address carries it, and how many candidates a restored wallet tries (P-2).
2. The `ownerCommit` of an unused output and the content of ciphertext 0 when there is no recipient (P-5).
3. The other private inputs of an empty input. L553 names `rho`, `leafIndex` and `slot`. `index` must be at most `gRef` or constraint 8 fails, and `d`, `others` and `path` need values too. A wallet that randomises `index` cannot make a spend with one real input.
4. Where `accrued` goes when the payment is to someone else. If the wallet splits it in proportion, the payee learns how much reward the payer had earned, which is the "value held for how long" that L887 warns about. If there is no change, it has to go into an output with value zero and `accrued` above zero (allowed: that output is not empty), or be claimed.
5. The asset of output 1. Ciphertext 1 (L558) does not carry it and an owner-sent spend shows none. A restored wallet has to take it from the inputs it spent or try the five ids against `C1`.
6. That the wallet must recompute `C0` from the decrypted payload, `gRef` and its own key before it counts a payment, and whether the encryption binds `C0` or `nf0` as associated data. L557 gives the info string and nothing else. A wallet that skips the check can be shown a payment that does not exist.
7. The 44 spare bytes of ciphertext 1. They must stay zero, or be covered by the key derivation, because the nonce is zero: the same key with two different plaintexts breaks the cipher. As specified it is safe (same key means same `C1` and `C2`, so the same plaintext).
8. Whether hourly window 0 counts as already taken. `window` starts at zero (L652) and the first window after `START` is number 0. Either answer is safe: under one the first note waits for the next hour, under the other it can be spent at once.
9. The formulas while the pool's copy of `START` is still zero. Written as `t = now − START` (L675) they give a `t` of about 57 years: step 5, caps at 32 times, no emission, and a deposit window that has closed. L518 says what is wanted ("Before START the caps are those of the first step ... deposits are open"), so each formula needs a branch. Without it deposits are rejected until the first batch. If the screening program produces no batch while there are no deposits, the pool never opens.
10. Whether `deposit` reads `START` from the registry. Only `roll` is said to (L661). If not, `deposit` works from a stale zero until the first `roll`, `activate` or `spend` after the first batch. Harmless, since every activation rolls first.
11. The unit of `rate` (L678, "tokens per second"). It must be base units per second. In whole tokens it is 0.44 at step 0 and rounds to nothing.
12. The gas forwarded with a refund (P-4).
13. The order of the root check. A wallet that follows L882 uses a checkpoint root, so those two should be compared first. Scanning the 64 recent roots first costs up to 64 cold reads, about 134,000 gas today, on every conforming spend. I could not tell whether the 1,082,000 gas of L897 includes it.
14. That an activated note has `accrued` zero (L659 does not say).
15. That each payment needs enough gas left to make the credit if it fails. See the EIP-150 item in "What held": a line `require(gasleft() > ...)` before each payment closes the one corner left.
16. `claimOwed`: clear the credit before sending. The re-entry guard makes either order safe, and this one stays safe if the guard is ever wrong.
17. How `sweepFees` pays ETH to the distributor. Under L520 it is a 50,000-gas call that falls back to `owed`, after which `notify` sees nothing new and the ETH arrives later through `claimOwed`. That works. It should be said.
18. The resolution of the weights. IMD has weight 1 and ETH "about 807" (L514), so ETH's weight is exact to about one part in 800. If IMD rises a hundredfold against ETH before the freeze, ETH's weight is 8 and its rounding error 6%. A common scale factor on all weights (say 10^6) removes this. The products still fit the field (2^245 against 2^253).
19. The token's rate for the fee ceiling ("the rate at the starting valuation", L668): 48,000 IMD for the supply, turned into ETH at the freeze-day IMD rate. About 16.8 million tokens per ETH at a supply of one billion.
20. The order of the 11 public inputs in `inputs[11]`, and the rounding direction of the ceiling's conversion.
21. Whether the wallet treats notes handed to a relayer as committed after the quote expires (P-6).
22. Lemma 11's hypotheses and its witness generator (P-3).

## 5. What held

Each item names the attack tried and why it failed. Scripts are in `/tmp/claude-0/-home-user-claude/29945ecd-c0f3-5435-9820-8daff0f0ffe0/scratchpad/review_r44/core/` (`arith.py`, `ceiling.py`, `columns.py`, `gas.py`, `model.py`).

**The circuit, as fifteen equations over a prime field.**

- *Wrapped values.* Every term of constraints 12 and 13 is range-checked to 96 bits, so each side is under 2^98 against a modulus near 2^253.6. The product in constraint 9 is at most 2^225.5 and its right side at most 2^160, so the division is exact over the integers and `earned` is unique. The packed word uses 203 bits. The emptiness test uses 192. `gRef − index` with both under 2^90 passes a 90-bit check only when it is not negative.
- *Both inputs empty.* Conservation forces both outputs, both public amounts, `earned` and `claim` to zero. Such a spend adds a leaf of three empty notes and two nullifiers, at full gas. The tree has 2^32 leaves, so filling it is out of reach.
- *A claim with no real input, and a reward claimed twice.* `earned` is weight times value times index movement of the inputs only, and every output takes `gRef` as its index. Using `gPrev` and then `gCur` on the same value telescopes: the two periods add up to one. An activated note takes the exact index of its block, and constraint 8 keeps it out of any proof whose `gRef` is lower.
- *Reward in total.* A note's value is part of `shielded`, so weight times value is at most the divisor `max(weighted, floor)`, and the sum of what all notes earn is at most `released`, which is rounded up while `g` is rounded down. `model.py` runs random activations, spends against either checkpoint, exits and relay fees over the whole schedule: credited reward stayed at or under `released` and `released` at or under the users' 45% in 40 runs.
- *The same note in both inputs.* Constraint 7 and the pool's check that the two nullifiers differ each stop it. A note at one position has one nullifier, because the position bits that select the Merkle path are the bits hashed into the nullifier.
- *Two notes with the same `rho`.* Their positions differ, so their nullifiers differ. Someone who copies an `ownerCommit` into a deposit of their own makes a gift.
- *A note at slot 3, or at slots 1 and 2 of an activation leaf.* Those slots hold the field element 0, and a commitment equal to 0 would be a preimage of zero.
- *An output in another asset.* One private `asset` feeds both input words and both output words. Output 2 is fixed to the token with `accrued` zero.
- *A token note as input.* Weight 0 forces `earned` and the remainder to zero. Every token note has `accrued` zero, by induction from how they are made, so `claim` is zero and nothing is created.
- *Burning someone else's nullifier with an empty input.* The nullifier of an empty input is still `H4(TAG_NF, nk, pos, rho)` with `nk` derived inside the circuit from the prover's `sk`. Hitting another wallet's nullifier is a hash preimage. A view-only wallet holds `nk` but not `sk` and cannot do it either.
- *A payer tracking or spending the note it made.* The payer knows `rho`, the position and `ownerPk`, and not `nk`.
- *`gRef` and `index` at their limits.* `g` cannot pass 2^74.85 on mainnet or 2^80.5 on the canary at a supply of one billion (2^81.2 and 2^86.8 at the 79 billion limit), under the build bound of 2^88 and the clamp at 2^90 − 1.
- *The split between `publicAmount` and `relayFee`.* Lemma 10's reasoning is right. A public input's key point comes from its column across the constraint matrices, and two inputs can be traded under one proof only if their columns are linearly dependent. The two range checks give the two inputs different columns (`columns.py`). A relayer therefore cannot move value from the withdrawal to its own fee. The spender can choose any split when proving, which is by design.
- *`publicAsset` with both amounts zero.* Free in the circuit, forced to zero by the pool, and still bound to the proof because it has a column of its own in constraint 14.
- *`extHash`.* It binds the chain, the pool, the recipient, the relayer and both ciphertexts. Someone who copies a pending relayed spend pays the gas and the named relayer is paid. The canary and the pool share a circuit, and the pool address inside `extHash` keeps their proofs apart.
- *Honest spends.* I walked each kind in the canary list (L935) through the fifteen constraints and the pool's table: two real inputs, one real and one empty, relayed in each of the five assets, a single-note wallet, owner-sent, with a claim, against `gPrev`, token notes, a freshly activated note after the next roll, smallest and largest sizes. Each has a satisfying witness and passes the pool's checks, given the reachable-state bound discussed in P-3.

**The pool.**

- *Ledgers.* Deposit, activate, refund, spend, `claimOwed` and `sweepFees` each move the same amount out of one counter and into another or out of the pool. `model.py` asserts `balance = pending + shielded + fees` and notes = `shielded` per asset after every call, and the token identity `balance = USERS + pending + tokenIn + fees − tokenOut`. Every standard size is a multiple of 500 base units, so the exit fee is exact.
- *A way round the 0.2%.* None. The relay fee pays it. Rounding lets at most 499 base units per spend leave free.
- *A way round the caps or screening.* Value enters `shielded` only in `activate`, which checks the cap and the registry.
- *One asset draining another.* The public asset must equal the circuit's asset whenever anything leaves, and the pool lowers that asset's own counter.
- *`owed`, the 50,000 gas and EIP-150.* A submitter cannot starve a recipient into `owed` by trimming the gas limit: to give the payment less than 50,000 gas the pool must have under 50,794 left, a payment that runs out leaves the pool under 794, and the credit needs a storage write of 5,000 to 22,100. The whole call reverts. The one corner is a recipient that itself reverts early when gas is short, and the cost there is a detour through `claimOwed`. Paying the relayer first changes nothing: every state change is done before either payment, and all functions are guarded.
- *Griefing a relayer.* A stale checkpoint, a spent nullifier, an evicted root and a fee above the ceiling are all rejected before the proof is verified, at about 65,000 gas. A recipient that burns its allowance costs the relayer about 72,000 gas more than simulated.
- *Blocking exits by flooding the root window.* The two checkpoint roots are accepted, and a roll can be taken only once an hour.
- *`START`.* Reading it lazily gives the same state as reading it at once, because nothing can be shielded before the first activation and every activation rolls first. Before `START` nothing is emitted. Between `START` and the first activation `g` grows against the floor and nothing is released. If the registry never starts, deposits stay refundable and `roll` does nothing.
- *`roll` reverting.* I found no input that makes it revert: the largest product is under 2^160 in 256-bit arithmetic, even at the largest supply the page allows, the divisor has a floor above zero, and the clamps on `g` and `released` are plain minimums.
- *The clamps.* If `g` is held at 2^90 − 1 emission stops, so `released` cannot run ahead in a way that matters. If `released` is held at the users' 45%, the claims it limits were rounded down.

**Other actors.**

- *A block builder.* It can order a `roll` first in an hour, censor, and move a timestamp by seconds. The first lowers the hour's checkpoint slightly for everyone alike. It cannot set the base fee, which follows the protocol's rule, and a roll cannot be repeated inside an hour.
- *A token issuer.* A freeze of the pool traps that asset, as the page says. One consequence of revision 4.4 is not on the page: a frozen or paused asset also loses relaying for private transfers inside the pool, because the relayer's fee is a transfer of that asset. Its holders can still move it privately only by sending the spend from a public address.
- *A depositor who never activates.* The deposit sits in `pending`, outside the caps and outside the reward divisor, and affects nobody. Many open deposits cost their maker gas and refundable capital.
- *A recipient contract.* It can refuse a payment, which then waits in `owed`, and it can burn its 50,000 gas. It cannot make a spend fail or change any state of the pool.

**What a wallet restored from its seed recovers, under the derivations of lines 537 to 546.**

- Its deposits, by trying counters against `Deposited` events, with the position and index from `Activated`. Deposits by someone else that copied its `ownerCommit` show up as its own. That is harmless and the wallet must not offer to activate or refund them.
- Outputs 1 and 2 of its own spends: values from ciphertext 1, `rho` and `d` from `nf0` and the slot, the index from `gRef`, the position from the event. The asset of output 1 by trial (section 4, item 5).
- Payments received, by trying its encryption key on every ciphertext 0. Spending them needs the diversifier (P-2).
- Which notes are spent, by computing each nullifier and looking it up.
- Not recovered: whom it paid and the memos it sent (the amounts can be worked out from the inputs and the change), the addresses it handed out, and spends it gave to a relayer that have not landed (P-6).

**Privacy claims.**

- A claim cannot be told from a payment, provided unused outputs are filled as P-5 asks.
- A relayed spend shows the asset, the fee and the relayer, and not the amount, the sender or the recipient. The fee is a lower bound on what the spender held, which is trivial.
- A recipient learns the two nullifiers and the leaf of the payer's spend, as in every pool of this kind, and cannot link them to anything else.
- Ciphertext sizes add up (1,120 + 80 + 16 and 80 + 16) and every spend publishes 1,312 bytes.
- A withdrawal of reward tokens shows what L274 and L887 say it shows.

**Arithmetic redone and found right.** Caps and their dollar totals ($159,850, $5,115,200, $40.9M without the stop). Seventeen ETH sizes, sixteen stablecoin sizes, and 16 withdrawals at most for any amount under 1,000 ETH. The weights. 510 tokens per ETH-equivalent per day and 1.11% a year. 0.77% of emission in 90 days and 12.2% in the first year. IMD's 4.1% and 16.5%. One tree insert at 647,794 gas, the verifier at 255,327, the ciphertext at 31,488, 195,840 of state gas. Every dollar figure in the two gas tables. About 21,400 constraints by my count against the page's 22,000. The three Poseidon addresses match the library's public README, and its gas figures are the page's plus 2,500 for a cold call.

## 6. Suspicions not made concrete, and what was not checked

**Suspicions.**

- *The compiler and the columns.* Lemma 10 holds for the equations as written. Whether the exporter of the `clean` framework or an optimiser pass merges or drops a column can be seen only on the real constraint system. The check is cheap there: the rank of the eleven public-input columns must be eleven.
- *Gas repricing against fixed numbers.* A spend is mostly modular arithmetic and one pairing check. A fork that reprices those could move a spend toward the 2,000,000 gas inside the ceiling. At eight times the base-fee cost there is room for a spend of about 8M gas, so I do not think it binds, but it is a second place besides `block.basefee` where a fork reaches the ceiling.
- *The same proving key on the canary and on mainnet.* The canary's constants are not in the circuit, so the ceremony's output is the same for both. Anyone who finds a flaw can rehearse it on the canary's key. The page says a finder can wait. It does not say the keys are identical.
- *Two devices on one seed.* Both use deposit counter `n`, so two deposits from two addresses can carry the same `ownerCommit` and link those addresses in public.
- *The proof's age shows.* A wallet always proves against `gCur`, but a spend that lands after the next roll shows `gPrev`. Observers learn that the proof was made before that roll.
- *Direct calls to the Poseidon libraries.* The three contracts are Solidity libraries. Their `hash` functions are pure and should answer a `staticcall`, and the pool should check that each call succeeded and returned 32 bytes. I did not run it.

**Outside my area, in two lines each.**

- The canary list (L935) has the project complete relayed spends "by itself" while it "runs no screener and no relayer" (L932). It can do so only by naming an address as relayer and sending the spend itself, which does not test a third-party relayer.
- The example criteria hold a deposit above 10 ETH from a freshly funded address for three batches (L172), and a batch can set bits in at most 96 words (L748). Someone with about 1,000 ETH of refundable deposits spread one per word can make coverage advance by at most 96 words a day. For the registry reviewer.

**Not checked.**

- X-Wing draft 11 and its identifier, USDT's and USDC's code, and EIP-8037 and EIP-8038 beyond the figures the page quotes.
- Anything about the registry's internals, the launch, the fee distributor and the canary script beyond the two notes above.
- No circuit, contract or proof exists, so nothing here was run against real code. The model in `model.py` is my reading of lines 657 to 684, not the pool.
- The gas of a spend beyond re-adding the listed parts. My own sum of the parts is about 66,000 gas under the page's 1,082,000, which is plausible for storage writes I did not itemise.

