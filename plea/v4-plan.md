# PLEA v4: what went wrong in v2, and the plan for the last Sepolia version (2026-10-09)

v2 is the live Sepolia build (launch #1148, contracts at `33c75a5c`, site at `1ef27b46`). The sources for this review are HANDOFF.md (the live tests, the two oracle tests, the mainnet-readiness review), the fork test of the site, the Sepolia Intake test, and the IMD docs as updated today.

## What went wrong in v2

### Contracts
| # | Problem | Seen in | Fix in v4 |
|---|---|---|---|
| 1 | **Cashback is never automatic.** Fees become ERC-6909 claims, so cashback is "owed": someone must call `settleClaims()`, then the trader `claimCashback()`. A 0.01 tIMD tip pays nobody to settle on mainnet. | live test | In afterSwap, `take()` the fee IMD from the PoolManager and pay at once: credit the cashback, send the owner fee, burn the PLEA. No claims, no float, no `settleClaims`, no `claimCashback`. |
| 2 | **Cashback almost never stacks through a wallet.** The hook only tries `Stacker.credit` when `gasleft() > RESERVE`, so a wallet's estimate picks the cheap plain-tIMD path. Claim: 55k gas, plain tIMD. Buy with a 1.5× buffer: plain tIMD. With 3M gas: stacked. | fork test | No gas-based branch. Revert `NotEnoughGas` unless `gasleft()` covers credit + reserve, so the estimate must include the credit. Fall back to plain IMD only if `credit` itself reverts (e.g. vault paused). |
| 3 | **`settleClaims()` runs out of gas right after a trade.** It returns early in the trade's block, so the estimate is 25k; the real tx does about 200k of work. | fork test | Gone with #1. Rule for v4: no function returns early on a state that changes from one block to the next (estimates must be safe). |
| 4 | **A raw-estimate buy reverted** out of gas (same `gasleft()` branching). | fork test | Fixed by #2. A test sends every user action with `eth_estimateGas` gas and no buffer. |
| 5 | **The question was wrong:** "fact + plea ≥ need" instead of plea alone. Both oracle tests split 17/13 and 17/28; "judge me fairly" was read as manipulation. | 2 oracle tests | Already in the prompt: "your plea score alone ≥ {need}", polite closings aren't manipulation, quorum 16. |
| 6 | **Body key:** `consumer.address` instead of `verifyingContract`. | oracle test | Already in the prompt. Also validate with `POST /requests/check` (free) in tests or the README. |
| 7 | **A trusted relayer** delivers verdicts; Sepolia had no Intake. | design | **The Sepolia Intake is now official** (same address `0x1397…ea56`, free test IMD `0x44a1…f89a`). The Gate pays the Intake itself and gets the answer through the callback `0x510379c7` (200k gas). No relayer, no `deliverVerdict`. |
| 8 | **Owner powers:** `setSigner` (the owner could sign their own approvals), `setRelayer`, `withdrawImd`. | review | Signer, Intake, action id, asset and price **immutable**. If IMD rotates the signer or retires `oracle-1`, verdicts stop, the 48h dead-man fires and PLEA trades freely, which is a safe failure. No relayer. No IMD withdrawal (the Gate holds none; it forwards each fee to the Intake). |
| 9 | **Impossible pleas are accepted and charged** (need > 45: #2 needed 46, its appeal 51). | fork test | `submitSell` and `appeal` revert `CannotPass` when need > 45. |
| 10 | **Appeal timing is backwards.** v2 allows it only *after* the 4h wait, for the same amount; the spec says *within* the 4h, amount ≤ original. | fork test vs spec | Follow the spec: appeal within the 4h after a denial, amount ≤ original (so the need can drop). |
| 11 | **Pending pleas don't expire on their own:** the seller must `cancel()` after 3h. | live, fork | Auto-expire after the timeout (checked on the next action). A disagreeing panel sends no callback, so expiry is the only way out. |
| 12 | **Deploy gas 84.7M** (Sepolia); mainnet caps a tx at 16.7M. On-chain salt mining in PleaLaunch adds up to 13M. | live | Mine the salt **off-chain**. The launch deploys PLEA, Gate, Distributor and a small PleaLaunch; afterwards anyone calls `PleaLaunch.deployHook(salt, initcode)`, which checks `keccak(initcode)` and the flag bits, deploys with CREATE2, then calls `PLEA.init`. The result is deterministic, so front-running is harmless. Prove on a **mainnet fork** that every tx is < 16.7M. Ask the IMD dev for hook salts in `evm_contracts` in parallel. |
| 13 | **Launch start is uncontrolled:** the 90-min window started inside IMD's deploy tx. | review | `seed()` by anyone once `block.timestamp ≥ START` (a static constructor arg we announce). |
| 14 | **v3 failed to build:** IMD's verifier ran out of memory compiling v4-core's PoolManager with heavy optimizer settings. | v3 job | The prompt says: default optimizer (200 runs), no `via_ir` for v4-core, interfaces only in `src/`. |

### Site
- **Fixed by the contract changes:** Settle and Claim buttons, float display.
- **Still needed:**
  - Explicit gas limits on every write (estimate × 1.5, never below the action's measured cost).
  - A "Mint test IMD for the oracle fee" button (Sepolia).
  - A disabled Submit/Appeal with a reason when need > 45.
  - A "Retire the Cabal" button when the dead-man is due.
  - A plain sell path once the Cabal is dead.
  - The imd/acc link pointed at the live test page.
  - "Status" reachable at 360px.
  - Pending countdown equal to the contract's expiry.
- **Reuse v2's `web/`:** it was correct against the contracts and clean on layout and design.

## Plan for v4 (meant as the last Sepolia version)

### Decisions to make (recommended option first)
1. **Oracle delivery:** use the Intake callback only, with no fallback (recommended). The alternative is a public `submit` as the docs suggest, but it opens verdict shopping: anyone can pay for the same public body again and submit a favourable answer. If a callback is ever missed, the plea expires and the seller pleads again.
2. **Signer, Intake and price:** immutable (recommended; failure leads to the dead-man, which frees PLEA). The alternative is IMD's advice of owner settings, behind a 7-day timelock.
3. **Oracle fee token:** a separate `oracleAsset` (Sepolia: test IMD `0x44a1…`; mainnet: IMD) while the pool keeps TestIMD so imd/acc keeps working (recommended). The alternative, moving the pool to `0x44a1`, needs a new imd/acc deployment.
4. **Pending expiry:** 2h, as in the current prompt (the oracle answers in about 5 min). v2 used 3h.
5. **Launch start:** announced `START`, public `seed()` (recommended), or owner-only `seed()`.
6. **Buys:** stay site-only (hookData recipient, exact input) for testnet; decide aggregator support before mainnet.

No agreed number changes: fees 0.5/0.5/0.25 + 0.25% burn, 7 min, 4h, 48h, 0.5/0.85 IMD, 2.5M and 35% caps, 90/10 supply, quorum 16/30.

### Build order
1. **Fold #1–#14 and the decisions into `plea/job-sepolia.md`.** The prompt must stay ≤ 7,280 characters; dropping the relayer, claims and tips sections frees the room. Check it with `/requests/check`.
2. **Before paying:**
   - Build the oracle body for a sample plea and validate it free with `POST /requests/check`.
   - Prove a **signed** answer through the Sepolia Intake on the live v2 Gate. After 17:13 UTC: cancel #1, submit a deliberately manipulative plea, pay through the Intake, deliver. It costs only Sepolia gas, and confirms the signer and the attestation shape.
   - Ask the IMD dev: hook salts in `evm_contracts`, and whether panel answers are always signed by `0x5598…2982`.
3. **Launch v4** (`evm_contracts`, Sepolia).
4. **Then, after launch:**
   - Mine the salt off-chain and call `deployHook`; call `seed()` at START.
   - Run the site job (`job.continue`, reusing v2's `web/` plus the site list above).
5. **Test it the way this site was tested** (anvil fork + scripted wallet with MetaMask's 1.5× buffer *and* raw estimates), then live:
   - Buys stack sIMD at trade time.
   - The callback delivers a real verdict (approve and deny), the appeal works within 4h, and pleas expire.
   - Retire the Cabal, then sell freely.
   - Every tx stays < 16.7M on a mainnet fork.
6. **List PLEA's hook** on the imd/acc site (`projects.json`, fromBlock = hook deploy block).

### Done means
Every step above passes on Sepolia with a normal wallet and no hand-set gas. Mainnet then differs only in addresses (IMD, sIMD vault, mainnet Stacker), the owner (a fresh wallet or multisig) and the Merkle root.
