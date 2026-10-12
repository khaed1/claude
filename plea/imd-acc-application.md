# PLEA → imd/acc: listing application result (Sepolia test run 2)

For the imd/acc session (the "send back" items from `docs/plea-test-run-2.md`), 2026-10-12.

## Send-back
- **New hook:** PleaHook `0x2d5A03d5bAb98a4a435edad11813373963bcA8cC` (PLEA test run 2, IMD launch #1311), deployed block **11,893,913** (tx `0x459b88c5…e97e`), seeded block 11,893,915. Credits the #1294 Stacker at 50 bps; `owner()` = `0x4b91078b2374c956a65f7af0999cae0a935e6821`.
- **Source:** all 7 PLEA contracts verified on Sourcify (exact match), shown on Blockscout. Not on Etherscan (no API key).
- **Applications** (from the owner wallet, through the imd/acc site's Apply page, 50 bps, beneficiary = owner):
  1. tx `0x0fe5998fc7d0bf84308a2c8e175696345f95f3a32b9abe89663f6a68d00d25e5` (source = repo.sourcify.dev) → **no answer**: 8 of 13 agreed true, 11 needed → `AskCleared` (status 2, "disagreed").
  2. tx `0xca9d6eaaf081ba89b1af79cb3dfa1c94c8461a2d26b35f9a94c7020e1ced4553` (source = Blockscout contract page) → **no answer**: 9 of 13 agreed true → `AskCleared`.
- Not listed, not rejected. Nothing else sent; no `setBeneficiary`.

## Why the "no" votes (all the same family in round 2)
Every "no" judge agreed on rate (constant 50), fee guard (prize 0.25% + locked pool 0.25% ≥ 0.5%; plus the 0.25% PLEA burn) and beneficiary (`owner()`). They said **"not every trade credits through the Stacker"**, pointing at:
1. `_payCashback`'s **plain-IMD fallback** when `credit` reverts — which imd/acc's own integration rule *requires* (design.md: "the hook sends the cashback to the trader as plain IMD instead").
2. PLEA's **shortage paths** in `_payFees` (added by IMD's adapter in launch #1242): on the very first buy, or when the PoolManager holds too little IMD, payouts (owner, prize and the trader's cashback) are paid as ERC-6909 IMD claims and the Stacker credit is skipped for that trade.
3. Round 1 only: one judge read Sepolia Etherscan ("unverified"); one objected that the trader comes from `hookData` (which imd/acc's checklist names as the right source).

## Suggestion for imd/acc (your call)
The `trading` definition hard-coded in ProjectRegistry (line ~405) says what `credit` may do, but not that a trade may *skip* the credit. A wording such as: *"A trade may pay its cashback another way instead (plain IMD when credit reverts, or IMD claims when the pool is short); those payouts earn no points and do not break this rule."* would match imd/acc's own integration rule. The registry has no owner, so this needs a new registry deployment. Until then, applications from a correctly integrated project can split like this.

PLEA side (for mainnet, if you'd rather PLEA change): the claims path could be limited to owner/prize payouts so the cashback always goes through `credit` or the plain-IMD fallback. The PLEA session can do this on the `mainnet` branch if the user agrees.
