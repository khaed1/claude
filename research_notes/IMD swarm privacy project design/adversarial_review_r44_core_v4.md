# Adversarial review of Murmuration v4, revision 4.4: circuit, notes and pool

Status: IN PROGRESS. This file is written and committed finding by finding. Until the header below carries a verdict, treat it as incomplete.

## 1. Header

- Reviewed: "Murmuration v4 specification, revision 4.4", dated 11 November 2026, in its plain-text rendering (1,615 lines). Line numbers below refer to that rendering.
- Reviewer's area: "How a payment moves", "The pool", "How private rewards work", the build specification from "Conventions" through "Keys, notes and addresses", "The circuit", contract 1 "Pool" and contract 2 "Verifier", "State machines", "Rules for the wallet and the relayer", "Size, gas and state pricing", "What operators can see", and the rows of the parameter, defaults and risk tables that concern them. The pool's interface with the registry (`isApproved`, `isRefused`, `START`) is included.
- Method: the whole page was read once in full. No other file in the repository was opened. Arithmetic was redone with scripts kept outside the repository.
- Verdict: pending.

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

**Who and cost.** Nobody attacks this. It decides whether the proofs, which replace an external audit, exclude a circuit that locks notes.

**Consequence.** As the page stands, the one lemma that answers last round's high finding (C-5, "Nothing required honest spends to work") either cannot be proved or is proved in a form that lets a too-tight range check through. The canary and the comparison against the Circom copy would catch a gross error (a 64-bit check fails on the first IMD note). They would not catch one in a range the canary never reaches: the canary's largest ETH exit is 10 ETH, so a 64-bit check on `publicAmount` (18.4 ETH) passes there and blocks every ETH exit of 20 ETH or more on mainnet, and the canary's `g` ends near 2^80.5. I rate it medium because a lock needs a second error, in the circuit, on top of the weak statement.

**Smallest fix.** Split lemma 11 and write its hypotheses down.

- 11a, part A, machine-checked. For every tree and every one or two notes in it with one `sk` and one asset, every `gRef`, and every choice of outputs, `claim` and public amounts for which these *integer* statements hold, the frozen witness generator produces an assignment that satisfies the constraint system: each value, `accrued` and `claim` is under 2^96; each `index ≤ gRef < 2^90`; `weight × (value₀ × (gRef − index₀) + value₁ × (gRef − index₁)) < 2^160`; the two conservation equalities hold over the integers; the positions differ. No hypothesis may mention a signal of the circuit. The witness generator is frozen with the statements, or "the honest witness" can be chosen to suit the proof.
- 11b, part D, argued on paper and fuzzed. In every reachable state those statements hold for every spend an honest wallet can form. The only one that is not immediate is the 2^160 bound. It follows from: note values add up to at most `shielded`; an input's index is at most `g`; reward earned in total is at most `released ≤ USERS`; and supply × 10^18 < 2^96.
- Reword lemma 9 for constraint 14 to "`publicAmount + relayFee` is under the modulus", and lemma 3 to "under one root, and assuming no hash collision".
- In part B, add a paired test to the single-input test: a valid proof must fail when `publicAmount` is raised by δ and `relayFee` lowered by δ. The single-input test at line 630 passes even when the two inputs share a key point, which is the failure lemma 10 is about ("pairwise different" at the same line does catch it).

**Confidence.** Certain for items 1, 3, 5 and 6 (arithmetic and a counter-example each). Likely for item 4.

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

(findings complete below this line when the header says so)

## 3. Contradictions between sections

(pending)

## 4. Points a builder would have to guess

(pending)

## 5. What held

(pending)

## 6. Suspicions not made concrete, and what was not checked

(pending)
