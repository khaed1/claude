# Plan: remove community takeovers from v1 (D-82)

**Decided by the user on 7 October 2026. Implemented on 7 October 2026 in `c85b6a9`, with the round-4 fixes (D-83), so round 5 audits one smaller codebase (HANDOFF §5 steps 21–22).** Kept as the record of what was removed. The frontend items below wait for the testnet redeploy (HANDOFF §2, "Frontend and the D-79 to D-83 contracts").

## The decision

- `CTOModule` and everything that exists only for it are removed from v1. **No replacement rule**: no automatic routing of an inactive creator's fees, no oracle question, no council path.
- **What stays:**
  - A coin's creator fees go to its fee recipient, and only that recipient can change the recipient (`CreatorVault.setRecipient`).
  - The recipient can route the fees to the coin's holders by setting the coin itself as recipient. That is final: nobody can call `setRecipient` as the coin.
  - The holder stream (`PadToken`), `SwarmBudget.sweepToHolders` and the R1-A4-1 / R3-A4-1 protections all stay.
  - `SocialRegistry.linkWallet` / `walletHandle` stay: the Profile page shows a wallet's X account.
  - `AttestationVerifier` and `VersionRegistry` stay; `VersionRegistry` is then the oracle's only consumer.
- **Why:** takeovers were the largest source of audit findings: 16 of 111 in `CTOModule` or the takeover rules (1 High, 3 Medium), plus 4 more in the takeover path through `CreatorVault` and the social badge. Every round's fix opened a new finding (P4-1 to P4-3 came from the R3-A4-8 fix). It depended on things outside our control (pinned rules, the X link service, oracle questions that pass IMD's screens, panels judging "abandoned"). And it gave the team Safe (as council) a power over every creator's fees until retired. A DexScreener-style community takeover (listing, socials) needs nothing from our contracts. Abandoned coins trade little, so the fees left with an inactive creator are small.
- **Consequence to state everywhere:** the vault takes no takeover module, so coins launched on v1 can never be taken over. A later version could add takeovers only for its own new coins, with a new vault.

## Order of work (next session)

1. Read the four round-4 reports (job links in `audit/FINDINGS.md`) and record them as in rounds 1–3.
   - Round-4 findings in `CTOModule`, `CTO-RULES.md`, `ctoSetRecipient` or the council path: mark them **"fixed: module removed (D-82)"** with the removal commit, not individually fixed.
   - Fix every other finding as usual: a regression test that fails on `38ad442`, a worktree with `lib/` copied.
2. Do the removal below in the same change set.
3. Run all tests (local, mainnet fork, testnet fork), commit, push, regenerate the round (`make_jobs.py round 5 --check`) and give the user the link and job descriptions.

## Contracts (`launchpad/contracts`)

| File | Change |
|---|---|
| `src/CTOModule.sol` | Delete |
| `src/CreatorVault.sol` | Remove `ctoModule`, `ctoSetRecipient` (and its PoolManager-unlock guard and hook flush, which exist only for it) and the third `initialize` argument (`initialize(curve, hook)`). Decide whether `RecipientChanged` keeps its `byCto` field: dropping it changes the event signature (ABI); keeping it means it is always `false`. Prefer dropping it, since the frontend ABIs are refreshed at the testnet redeploy anyway. Reword the comments ("or by the CTO module…") |
| `src/PadFactory.sol` | Comment only: "(or a swarm-approved takeover)" goes |
| `src/SocialRegistry.sol` | Comments only: `linkWallet` is no longer "for CTO proposers"; the badge note about takeovers becomes "any recipient change" |
| `src/AttestationVerifier.sol` | Comment only: consumers are `VersionRegistry` (and future ones), not `CTOModule` |
| `script/Deploy.s.sol` | Remove the `CTOModule` import, `d.cto`, the `ctoRules` param and `CTO_RULES` env (header comment too), the step-5 deployment, `creatorVault.initialize(curve, hook)`, the `ctoModule` key in `deployments/<chain>.json` and the console line. Check the ownership-handoff and owner lists. The transaction count drops by one (HANDOFF §5a: 51 / 50 without `AUDIT_LINK`); re-measure on a fork |
| `test/Base.t.sol` | Drop `_ctoModuleAddress()` and the third `initialize` argument |
| `test/Governance.t.sol` | Delete the `test_cto_*` tests that exercise takeovers (33 now), the `CTO_ADDR` / `_ctoModuleAddress` override, `_announce`, `_afterNotice`, `_proposeAsBob`, `MockSafe` if unused, and the `cto` deployment in `setUp`. Keep and adapt what tests other things: `test_cto_holderLumpCantBeCapturedInOneBlock` and `test_cto_holdersRoutingIsFinal` become holder-routing tests through the creator's own `setRecipient(coin, coin)` (rename to `test_holders_…`); `test_cto_routeFeesToHolders` likewise (creator routes to holders, then creator fees and swarm budget stream to holders). Keep the verifier, version, social, lens, holder-stream and owner tests (`test_governance_ownersAreFixed` drops `cto`) |
| `test/DeployFork.t.sol`, `test/TestnetFork.t.sol` | Drop `ctoRules`, the `d.cto` owner and council asserts, and `cto` from the fixed-owner list |
| `test/OracleLive.t.sol` | Keep (verifier only) |
| New tests | `CreatorVault` has no takeover entry point: only the recipient changes the recipient (already covered); routing to the coin is final (the adapted `test_holders_routingIsFinal`); `initialize` takes two addresses. A removal has no fails-before test; say so in FINDINGS |

## Off-chain code

- `keeper/keeper.mjs` and `keeper/README.md`: remove the `coins.cto` job (`CTOModule.execute`) and the `cto` ABI. Keep the holder-routed `claim` / `sweepToHolders` job (recipient = coin) and reword its comment ("whose takeover routed fees…" becomes "whose fees go to holders").
- `frontend/` (only when the testnet is redeployed with the new contracts: the live testnet still runs the old ones):
  - `scripts/abis.mjs`: drop `CTOModule` from `NAMES`; delete `src/abi/CTOModule.ts` and its export in `src/abi/index.ts`; refresh the `CreatorVault` ABI.
  - Drop the `ctoModule` rows from `src/lib/transparency.ts` and `src/pages/Docs.tsx`.
  - Until then the site keeps the old addresses and ABIs.
- `bots/`: nothing found; grep again.

## Docs

- `CTO-RULES.md`: delete. It was never pinned to IPFS, so nothing points to it.
- `ARCHITECTURE-v1.md`:
  - §5.2: remove the `CTOModule` block; keep the `CreatorVault` text and say the recipient alone decides, routing to holders included.
  - §5.6: remove the council / CTO rows ("Propose a CTO as the council…", "Cancel an attested CTO…").
  - §7: remove feature 4, "CTO arbitration".
  - Remove takeover mentions in §1 and §3 / §4 if any.
- `audit/THREAT-MODEL.md`:
  - §1: the Team Safe row loses "council"; the 7-day timelock row loses `CTOModule`.
  - Invariant 17: replace it with "Removed in D-82 (no takeover module)" to keep the numbering.
  - Invariants 6 and 19: check their takeover wording.
  - §3: remove the takeover lines (anyone may ask a question at +7 days; R1-A4-17 "retire one-way" keeps only the version fallback).
- `audit/README.md`: the A4 row loses `CTOModule` and `CTO-RULES.md`.
- `audit/jobs/A4-governance.md`:
  - FILES: drop `CTOModule.sol` and `CTO-RULES.md`.
  - FOCUS: rewrite without takeovers (verifier, `VersionRegistry`, `SocialRegistry`, `CreatorVault` recipient changes and holder routing, `PadConfig`, timelocks, Deploy).
  - Add "Changed since round 4 (D-82): `CTOModule` removed …".
  - Retitle the job ("Governance, versions and deployment").
- `audit/jobs/A1-core.md`: the D-79 line mentions `ctoSetRecipient`; add a D-82 line.
- `audit/FINDINGS.md`: keep every past takeover finding as it is; add a note under "Checks before a round" or the round-4 section that the module was removed (D-82). P4-1 to P4-3 then concern removed code.
- `HANDOFF.md`:
  - §1 (the swarm no longer "settles community takeovers"); §2 table (`CTOModule` row removed; `CreatorVault` and `SocialRegistry` rows reworded).
  - Tests counts; §5a (no `CTO_RULES`, transaction count); §6 keeper table (drop `CTOModule.execute`).
  - §7: drop "CTO rules: review and pin". In the oracle rows only the version question remains; R2-A4-4's chain pin then concerns `VersionRegistry` only.
- `DECISIONS.md`: D-82 implemented plus a change row. D-46 / D-51 / D-52 / D-78 / D-79 / D-80 / D-81: add a short "superseded by D-82 for takeovers" note where they decide takeover mechanics (don't rewrite them).
- `ROADMAP.md`: item 13 and anything listing takeovers (v1 feature lists).
- `SITE-COPY.md`: takeover banner, FAQ and the "settle community takeovers" lines.
- `frontend/src/docs/index.md`: "settle takeovers".
- `design/system/Pages.md` and the Notice / Badge component examples: drop the takeover banner and the CTO status on the coin page. `design/UX-RESEARCH.md` is research, so leave it.
- `contracts/README.md`: drop the `CTOModule` row; `CreatorVault` loses "CTO hook-in".
- `legal/`: grep for takeover wording.

## Checks before committing

- `grep -rni "cto\|takeover"` over `launchpad/` (excluding `audit/rounds/`, `FINDINGS.md` history, `DECISIONS.md` history, `PLAN.md` and `design/UX-RESEARCH.md`) finds nothing left behind.
- `forge build`, then all tests: local, mainnet fork, testnet fork.
- `python3 upstream/make_fork.py` / `make_staking.py` are unaffected (they don't touch these files).
- `make_jobs.py` refuses a round if an in-scope file is in no area, so the A4 FILES list must match the new `src/` set.
