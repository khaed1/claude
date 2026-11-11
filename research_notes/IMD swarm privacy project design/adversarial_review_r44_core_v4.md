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
- Or shrink the constant. `(4 × basefee + 0.1 gwei) × 2,000,000` gives 11.5 times the gas cost today and still 7.2 times in a spike. The cost is less room for priority fees when the base fee is near zero: 0.1 gwei of headroom instead of 1.

**Confidence.** Certain (arithmetic from the page's own figures).

(more findings pending)

## 3. Contradictions between sections

(pending)

## 4. Points a builder would have to guess

(pending)

## 5. What held

(pending)

## 6. Suspicions not made concrete, and what was not checked

(pending)
