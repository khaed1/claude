# Murmuration: design note for revision 4.4 (v4 note, 11 November 2026)

This note continues `design_review_v3.md`. It records the owner's decisions taken in session on 11 November 2026, the fourth review (of revision 4.3) and the design decisions that follow. The specification is the authority once a revision is merged; this note says why.

## 1. Owner's decisions, 11 November 2026 (in session, by question and answer)

The ten defaults that revision 4.3 listed as unconfirmed were put to the owner, with the question of scope. Source for every row: the owner's answers in session.

| Question | Answer | Effect |
|---|---|---|
| Keep patching or cut scope? | **Keep patching.** Every feature stays and each finding gets a fix | No mechanism is removed for the sake of scope. A removal is still allowed where it is the fix |
| Screening threshold and fallback | **Confirmed as recommended**: two thirds of active screeners, at least seven, no fallback, removal at 14 strikes (+2 / −1) or after 7 silent days, 90-day bar | Parameter row "decided" |
| Stop on the caps | **Stop at 800 ETH**: five doublings, 1,600,000 of each stablecoin, 80,000 IMD, reached on day 450 | Parameter row "decided" |
| How the relayer is paid | **Pay from the spent note.** No separate fee note. The relayer is paid a public amount out of the notes being spent, in that asset. Same ceiling, and the 0.2% is charged on it | Changes the circuit: two inputs instead of three, three outputs instead of four, 11 public inputs instead of 14, one nullifier slot less per relayed spend. Cost: every relayed spend shows which asset moved. This replaces the 4.3 recommendation (a fee note of any listed asset) |
| Minimum age | **Confirmed**: one day, measured at the start of the epoch whose batch covers the deposit | "decided" |
| Start of the schedules | **Confirmed**: caps, emissions and the deposit window count from the registry's first applied batch; vesting from launch | "decided" |
| Refund of a refused deposit by others | **Confirmed**: once refused and at least 21 days old | "decided" |
| Screener waits | **Confirmed**: 30 epochs before a new screener counts, no exception at launch; stake returned 14 epochs after exit or removal | "decided" |
| Exit sizes for USDT and USDC | **10 to 1,000,000**, the 1, 2, 5 series: sixteen sizes. The recommendation was 1 to 1,000,000 | Smallest stablecoin deposit and smallest fee sweep become 10. The token's sizes, 1,000 to 100,000,000, were in the same question and were not changed |
| Deposit window, reward floor, swarm vest, auction design | **All four confirmed**: four years from the first batch; divisor floor at a quarter of capacity; two-year linear swarm vest with no cliff; one continuous descending-price auction, then a bounded buyback and burn every 12 hours | "decided" |

Nothing is left under "to confirm" except engineering constants marked "build".

## 2. What the relay-fee decision does to the circuit

The decision is a removal. Revision 4.3 already had the case "relayer paid in the spend's own asset by a wallet that holds a single note" (the fee asset equal to the spent asset, the fee input empty). The owner's choice makes that the only case and deletes the rest: the third input, its nullifier, the fee change output, the public `feeAsset`, the reward term for the fee note, the flags `hasFee` and `same`, and the rule that let value cross between two sides.

Decisions taken while writing it down, and why:

- **The leaf stays a bundle of four.** A spend now has three commitments (recipient, change, reward). The leaf is still `H4(C0, C1, C2, 0)`. A bundle of three under `H3` would save about 16,700 gas per insert, but a two-bit slot selector would then have one illegal value that needs a new constraint, and position arithmetic would change. The four-slot bundle with a zero in the last slot is what activation leaves already look like, and the tree and membership text of 4.3 stay as they were.
- **One public asset.** `publicAsset` is the asset of both the public amount and the relay fee. It is zero exactly when both are zero. The circuit ties it to the real asset with `(publicAmount + relayFee) × (asset − publicAsset) = 0`; neither term can wrap because both are range-checked to 96 bits.
- **The two public amounts appear in the conservation equation only as a sum.** What keeps a proof for one split from verifying for another is that each has its own range check, so each has its own column in the constraint system. This is written into the specification next to lemma 10, because a builder who drops a range check on a public input as redundant (the contract checks sizes anyway) would make the two interchangeable.
- **Relaying an asset now always depends on the frozen conversion rate** for every asset but ETH. With the ceiling at about seven times the gas of a spend in ETH and a factor of eight for other assets, relaying in an asset stops working if its price in ETH falls to about a fiftieth of the frozen rate. Its owner can then still send the spend from a public address. Stated as a risk.

## 3. Fourth review, of revision 4.3

In progress. Two reviewers, each given only a plain-text rendering of the page: `adversarial_review_r43_mechanisms_v4.md` (registry, launch, fees, canary; ids Q-n) on revision 4.3 as published, and a core review (circuit, notes, pool; ids P-n) on the text with the owner's relay-fee decision applied, because the fee note it would otherwise have reviewed no longer exists. A first attempt at both was lost to a container restart before either had recorded a finding.

## 4. Provisional facts re-checked

See `status_changes_v4.md`. The audit reports of 13 November and the developer call of 19 November 2026 are still in the future on the day of this note, so EIP-8037 and EIP-8038 can only be re-checked as they stand today.
