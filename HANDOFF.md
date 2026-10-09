# Handoff: PLEA + imd/acc (2026-10-09)

Repo `khaed1/claude`, branch **`claude/adoring-goodall-pn3jyz`**. Develop and push on this branch only.

## The two projects

**PLEA** is a relaunch of TokenWorks' CabalCoin (2025) through the IMD swarm. Buying is open to everyone. Selling needs a plea (up to 280 characters) approved by the IdentityMD oracle panel, "the Cabal": 30 judges, with 20 needing to agree.
- **Score:** 55 points come from facts the contract computes; the plea earns up to 45; 70 passes.
- **After a verdict:** an approval opens a 7-minute window to sell. A denial starts a 4h wait, with one appeal for 0.85 IMD (TestIMD on Sepolia).
- **Dead-man rule:** if there's no verdict for 48h, the Cabal dies and PLEA trades freely.
- **Token:** transfer-restricted. Holders can only send PLEA to the gate, which blocks selling through other pools.
- **Hook:** one hook, a fork of POOL4's `CappedBurnHook` converted to the IMD side. It is the only liquidity provider, its liquidity is locked forever, and it includes cap/trim burns and an IMD buy wall.
- **Fees:** 0.5% cashback to the trader as sIMD, 0.5% to the owner, 0.25% to pool liquidity, plus 0.25% of the PLEA burned.
- **Supply:** 90% into the pool, 10% to a swarm Merkle distributor.
- **Launch type:** IMD `evm_contracts` (smart contracts), **Sepolia first**, after imd/acc.
- **Cashback:** paid through imd/acc's `stacker.credit` in try/catch; if it fails, the trader gets plain IMD, so a trade never reverts on cashback.

**imd/acc** is trading cashback in staked IMD, inspired by TokenWorks' btc/acc. Participating projects send 0.5% of each trade, taken from their existing fees, to the trader as sIMD. They do it through the shared **Stacker**: `credit(trader, imdAmount)` pulls the IMD and calls `sIMD.deposit(amount, trader)`.
- The Stacker has no owner, and its IMD and sIMD addresses are immutable. v1 deposits on every credit.
- No token in v1; points are tracked instead (see Decisions).
- The ETH-fee batch route (through POOL4) is planned for v2.
- The first projects are PLEA (Ethereum) and PondPad (Robinhood Chain, planned).

## Status
- **imd/acc is LIVE on Sepolia** (launch #1129, block 11,874,601, tx `0x9512b5df4f5711989f0436343d14bf30cd2e9d664d43aedfc6a4c1845fe4c0f0`, after the IMD dev unparked it; the transaction used 23,509,044 gas):
  - TestIMD `0x2b69099e59b05901faa1dd164fabf098bf831e82`
  - TestSIMD `0xf9e2eec3b610ec6781f7438ac5fb4bc049d81cc1` (owner `0x4b91…6821`, not paused)
  - Stacker `0x293c7134ab8f6bf1d8ff44ed806575f8f1baf477`
  - Verified on-chain: the runtime code equals our build (TestIMD exactly; TestSIMD and Stacker once their immutables are masked), the immutables point at the right contracts, and the Stacker's max allowance to the vault is set.
  - These addresses and the owner wallet are now filled into `plea/job-sepolia.md`.
  - **Test page live:** https://imd-acc-sepolia-test-run.site.identitymd.eth.limo (continuation job `5530dde0-f0f2-45c2-b18d-ea718fc458de`, skill `build-website`, PR #2, commit `7de7d635`, CID `bafybeic2skjuhsi5le5kt4sfya7sitdbn4g2jpctfzosxjdvt45iuxwyr4`). IMD named it `imd-acc-sepolia-test-run`, not `imd-acc-test`. Source is now Vite + TypeScript in `site/`, built into `dist/`; `projects.json` sits next to `index.html`.
  - **Tested end to end (2026-10-09)** on a local Sepolia fork with the delivered `dist/` and a scripted wallet: connect, faucet, the 24h cooldown, approve + credit, then the stack, tsIMD and its value, recent stacks and vault totals all updated. A listed project's credit earns points; self-stacks show "direct, no points"; a `fromBlock` after the credit gives 0 points. All 19 hard-coded selectors match the contracts. No page errors, and no horizontal scroll at 360px.
  - **Live Sepolia test (2026-10-09)** with the owner wallet `0x4b91…6821`:
    - faucet tx `0x23a62183…94bb`: 10,000 tIMD, and a second call reverts with `FaucetCooldown`
    - approve + `credit(self, 100 tIMD)` tx `0xaabe6a70…3252`: 100 tsIMD minted to the trader, a correct `Stacked` event and totals, the Stacker left holding 0 tIMD and 0 tsIMD, and the one-block hold confirmed (redeemable 2 blocks later)
    - a second credit of 1 tIMD (tx `0x73580d51…0705`)
    - the published `dist/`, run against real Sepolia RPCs, shows 101 stacked as "direct, no points", the right balances, both events and the faucet cooldown, with no errors
  - **Sepolia gas is unusually high for new storage.** The first `credit` for a new trader used 1,161,856 gas, the second only 182,644; the faucet used 349,871 and an approve 128k. Creating new storage entries costs far more on Sepolia today, which also explains the 23.7M deploy estimate. **For PLEA:** each trader's first cashback adds about 1M gas to their first swap on Sepolia, so the hook's try/catch must keep enough gas back to finish the trade if `credit` runs out.
  - **The owner wallet's key was shared in chat for this test.** Keep this wallet testnet-only, and use a fresh wallet as PLEA's mainnet owner.
  - **To list PLEA later:** add `{address, name, fromBlock}` to `projects.json` with another `job.continue` (the parent is now `5530dde0-…`).
- **History, imd/acc job done, launch first parked** (job `640b4951-f512-4415-ab2e-944462a2f5ba`, launch #1129 `8e1fcd97-a3ff-4f90-adb8-3dc15b2dc2f1`). All 8 steps were accepted: build, tests, manifest, four audits and the judge, plus an independent review and reproducible bytecode. Code: https://github.com/identity-md-launches/launch-1129-build-imd-acc-sepolia-test (commit `934fb404`). Owner `0x4b91078b2374c956A65F7Af0999CaE0a935E6821` (confirmed as the user's owner wallet; also use it as `<OWNER_WALLET>` for PLEA), set as TestSIMD's owner. Jobs are paid from `0xf8ad3f88b0e0d177aa8c5e6be1e13410fd41cdc7`.
- **Why it's parked:** "preflight failed: the launch needs 23701870 gas and one transaction may use at most 16777216 (EIP-7825)". This is IMD's Sepolia deploy path, not our code: the three contracts are only 13,977 bytes of creation code. Launch #1073 (Sepolia, one 10,269-byte contract) was parked for 18.6M gas, while #1076 (mainnet) went live with the **identical** bytecode, and mainnet launches with 184 KB of code (#1067, #1095) went live. Every recent Sepolia launch that reached deployment was parked the same way (#1069, #1073, #1129).
- **Review of the delivered code:** it matches the spec. TestSIMD is the verified StakedIMD source with only the name and symbol changed. The Stacker has no owner, is immutable and uses a reentrancy guard; it adds a `ZeroShares` revert. The site (`site/`) is built but not hosted: it needs the addresses in `site/config.json` and an IPFS pin.
- **Independent check (2026-10-09), all clean:**
  - Rebuilt with forge 1.8.3 (the verifier's version): all three contracts reproduce the attested creation and deployed bytecode exactly (keccak).
  - All 76 tests pass, including invariants and fuzzing.
  - The TestSIMD logic is identical to the live StakedIMD; only the name, symbol and pragma differ. The vendored Solady files are byte-identical to the vault's verified sources, and the 13 OpenZeppelin files are identical to the official v5.1.0 release.
  - Slither's 7 results are all expected: strict equalities (the vault's one-block hold and the faucet's never-used check), timestamps (the 24h faucet), and state written after the vault call in `credit`, which `nonReentrant` and the fixed, trusted token and vault cover.
  - **A real deploy of all three costs 3,082,437 gas,** against IMD's preflight estimate of 23,701,870. Use this when reporting the Sepolia bug.
- **The PLEA prompt is final but on hold:** it needs the imd/acc addresses, and the hook-address question below.

## Order (decided 2026-10-09)
1. **imd/acc on Sepolia first** (`imd-acc/job-sepolia.md`, 2,201 characters): TestIMD (faucet: 10,000 tIMD per address per 24h), TestSIMD (StakedIMD fork; the owner keeps pause so the fallback can be tested), Stacker, and a test page (your stack, leaderboards, faucet). Its README delivers the three addresses.
2. **PLEA on Sepolia** (`plea/job-sepolia.md`, 5,114 characters) reuses those three addresses: fill in the `<TEST_IMD>`, `<TEST_SIMD>` and `<STACKER>` placeholders. PLEA is imd/acc's first integration test.
3. **Mainnet:** the Stacker is deployed against the real IMD and sIMD, then PLEA mainnet points at it.

## Decisions (2026-10-09)
- **PLEA deploy wiring:** `evm_contracts` deploys in order, in one transaction, and calls nothing afterwards. The order is PLEA → PleaHook → CabalGate → PleaDistributor (the name `MerkleDistributor` is reserved by IMD). PLEA's constructor sets a transient-storage flag (EIP-1153). The distributor's constructor calls `PLEA.init(hook, gate, this)` once, while the flag is set: it records the addresses, mints 90%/10% and calls `hook.seed()` to create the pool. Nobody, the owner included, can call `init` later. If any step fails, the whole launch reverts. A permissionless `init` was rejected because it could be front-run. Details are in `plea/launch-spec.md`.
- **Points count only listed projects.** Anyone can call `credit` with their own IMD, so points are counted, not gated. The imd/acc site has a `projects.json` (`{address, name, fromBlock}`), starting empty. Only `Stacked` events from listed projects earn points; everything else shows as "direct, no points". The Stacker is unchanged.
- **Points start at listing,** never retroactively. PLEA's `fromBlock` is its hook's deploy block.
- **Later: an IMD panel decides the list.** An ownerless `ProjectRegistry`: a project applies and pays the oracle fee, a panel votes true/false, and the verdict is verified like PLEA's gate does it. Anyone can challenge a listed project. Build it once more than one or two projects want to join. The plan is in `imd-acc/README.md`.
- **References:** imd/acc uses `evm-contracts-launch`, `defi-native`, `eth-security`, `eth-testing`, `eth-frontend-ux`, `better-interface`, `pashov-skill`, `solidity-security-review`. PLEA uses `evm-contracts-launch`, `uniswap-v4-hooks`, `uniswap-v4-security`, `oracle-consumer`, `eth-security`, `eth-frontend-ux`, `pashov-skill`, `better-interface`. `impeccable` was dropped (not in IMD's catalog) and saved for the full website job.

## Launch-page settings (both jobs)
Type: smart contracts (`evm_contracts`). Chain: Sepolia `11155111`. Owner: the user's wallet, the same for both jobs. GitHub on. IPFS labels: `imd-acc-test` and `plea-test`.

## Worker release 0.1.0+53e0802f (checked 2026-10-09)
- **`MerkleDistributor` is a reserved contract name**, in `evm_contracts` launches too. PLEA's distributor is renamed `PleaDistributor`.
- **No hook-address mining in `evm_contracts`.** Its `launch.json` is just `{contract, constructorArgs}` with no salt or hook permissions; the hook placeholders (`$poolManager`, …) belong to the `univ4_hook` kind only. PLEA's hook can't get a flag-matching address as the prompt stands. See the proposal in the next steps.
- **Launch limits:** each contract's creation code is at most 49,152 bytes, and the factory links no libraries (library functions must be internal).
- Worker operations: `imd doctor` now checks the runtime by running one shell command, `"selfTest": false` turns the self-test off, and `imd launch check` checks a repository before submitting. Update the VPS with the manual's update section (on `main`), then run `imd doctor`.

## PLEA Sepolia job
- Submitted 2026-10-09: job `384418e6-52b6-4be4-aa41-05526cc3c5a3`. **Blocked** at the manifest step (needs_input): the evm_contracts factory deploys each launch.json contract with **CREATE2 salted by the launch number**, so PleaHook can't land on its flag bits (0x28cc), and its constructor reverts `HookAddressNotValid`. The build and the permissions audit had been accepted, but a blocked job delivers no code (launch-1140 repo is empty), and a continuation can't deploy. So: **fresh launch with a rewritten DEPLOY/WIRING section.**
- **Resubmitted 2026-10-09:** job `cbf3e59e-d5a7-4820-aabe-f6e7e2265ca9` (executing), with the PleaLaunch fix, RESERVE and the live imd/acc addresses. Its text is a 5,642-character version, between the 5,690 draft and the trimmed 5,420 file; the substance is the same. The old job `384418e6-…` stays blocked and is abandoned.
- **The old job's audits** (before the judge): 1 critical and 6 high findings, mostly repeats, which come down to four issues:
  - **Sell-gate bypass:** a router mints ERC-6909 PLEA claims instead of `take()`, then sells them in a hookless pool or transfers them.
  - **Stuck pending plea:** a plea with no verdict stays pending forever, locking the wallet out of selling.
  - **Keeper tip drain:** `settleClaims` pays its tip from wall capital, so dust trades can drain the wall.
  - **Launch blocker:** IMD rehearses constructors on an empty chain, where calls to PoolManager, TestIMD or Stacker revert, which parks the launch.
  - **Mediums and lows:** the verdict isn't bound to plea id and trader; `appeal()` accepts a stale plea; PLEA parked at the Gate is swept to the next seller; `hookData` can write another wallet's cost basis; spot-price fact scores can be bought in the same tx; missing Bidi characters; an unfillable gated sell; only one token orientation tested.
- **PLEA is LIVE on Sepolia** (v2 job `cbf3e59e`, launch #1148, block 11,877,100, tx `0x655579bd…9525`; code https://github.com/identity-md-launches/launch-1148-build-plea-sepolia-test, commit `33c75a5c`). All admission checks passed: 8 nodes accepted, no unresolved blocking findings, independent review, 6 contracts clean and reproducible, invariants.
  - PLEA `0x76b4e4ead394a71668e3e97f30f9072bbaa8a861`
  - CabalGate `0x29bfb82df72d839bed5e4f79b3528af85f1a2e2e`
  - PleaDistributor `0x514bf74301de943d0db83e6f5bdc0aa0d0ad435e`
  - PleaLaunch `0xc43405eb24a776669e4a78d22164d55593cd61bf`
  - PleaHook `0x37337cd25f09a1cb77bba55d12358c9d00e2e8cc` (low 14 bits 0x28cc ✓)
  - **Verified on-chain:** owner `0x4b91…6821` everywhere; hook wired to TestIMD and the Stacker; pool **seeded in the launch tx** at tick 120,720 (about 5.7e-6 IMD per PLEA, the 5,700 IMD cap); 100,000,000 PLEA in the distributor; 899,999,100 in the pool (about 900 PLEA of rounding dust missing from the supply); the 90-min launch window started at deploy.
  - **Relayer set** to the owner wallet `0x4b91…6821` (tx `0x800fc18b…e484`), so only that address can deliver verdicts.
  - **Live test, 2026-10-09, owner wallet:** buys go through Uniswap's Sepolia `PoolSwapTest` `0x9b6b46e2c869aa39918db7f52f5557fe577b6eee` with `hookData = abi.encode(buyer)`, exact-input, zeroForOne=true (IMD is currency0).
    - **Buy 1, 20 tIMD** (tx `0x6088fb91…6225`): 2,371,340 PLEA delivered as ERC-20 straight to the buyer, with the swapper's PLEA delta 0, so the bypass fix works. The launch fee was about 46%; the fill was 13.64 tIMD; cost basis recorded.
    - **Fees and cashback became claims, not transfers:** `CashbackOwed` 0.0682 tIMD (0.5% of the fill), PLEA burn claim 5,943, IMD fee claims.
    - **`settleClaims()`** (tx `0x2426f6fa…7b8f`): burned 5,943.2 PLEA (supply fell), paid the owner 0.0682 and a 0.01 tip, and funded the cashback float.
    - **`claimCashback()`** (tx `0xed339cc5…9eea`): `Stacked(project = hook, trader = buyer, 0.0682)`, so the buyer's tsIMD went up. Two more 5 tIMD buys gave the same result (owed, then settle, then claim); 0.1026 tIMD stacked in total through the hook.
  - **Gap vs the imd/acc design:** cashback is **never deposited at trade time.** It's always `CashbackOwed`, and the trader must call `claimCashback()` after anyone runs `settleClaims()`; the float only fills from settled claims. **Fix for the next version:** in afterSwap, `take()` the cashback IMD from the PoolManager, which holds the pool's IMD, and `credit` it right away, falling back to owed only when that's short. The test site also needs Settle and Claim cashback buttons.
  - **No PLEA site is hosted:** `plea-test` isn't registered, and the repo's `site/index.html` is only an info page. `plea/job-continue-site.md` (4,406 characters) is a job.continue on parent `cbf3e59e`, skill `frontend-for-contract`, references `better-interface` and `eth-frontend-ux`, IPFS `plea-test`, covering Buy via PoolSwapTest with hookData, Cashback settle and claim, Plead, Wall and Status. Its DESIGN section writes out Impeccable 4.5.2's rules (Operate mode, the craft floor, the refuse list), because `impeccable` still isn't in IMD's skill catalog. `/requests/check` passed with no blockers; pay from `0xf8ad…cdc7`.
  - **Transfer restrictions tested (2026-10-09; read-only eth_call on Sepolia, plus a local fork for multi-step cases), owner wallet holding 3.56M PLEA, not allowlisted:**
    - **Blocked with `CabalIsWatching`:** transfers to a random wallet, the PoolManager, the hook, the distributor or yourself; `burn()`; a 0-amount transfer; `transferFrom` by an approved third party (to a wallet or the PoolManager, which also covers Permit2, since PLEA has no permit).
    - **Blocked by the hook through v4's `WrappedError`:** a direct PLEA→IMD sell via PoolSwapTest (`SellsOnlyViaGate`, also when settling with claims); a buy without hookData (`RecipientRequired`); an exact-output buy (`ExactOutputBuyRefused`).
    - **A buy with `takeClaims=true`** succeeds but mints **0** ERC-6909 PLEA claims to the buyer or the router; the hook delivers ERC-20.
    - **Allowed by design:** distributor → anyone; `from` = hook, Gate or PoolManager; anyone → Gate. The Gate only sells the exact `p.amount` it pulls and has no PLEA withdraw, so stray PLEA sent to it is locked forever (a burn, not a transfer path).
    - **Trust point:** `allow(addr)` is add-only by the owner, and any allowlisted address can send freely. The allowlist is empty today.
  - **Oracle prep (2026-10-09):** plea #1 submitted (tx `0xa54df344…3cc2`, 500,000 PLEA, fact score 37, need 33). Two bugs in the live Gate:
    - **Question bug (logic):** the text says "answer true only if FACT SCORE plus your plea score is at least {need}", but `need` = 70 − fact score is the plea-only threshold. As written, almost any non-manipulative plea passes. It's immutable in this build; fix it in the next version ("only if your plea score is at least {need}", or "the sum is at least 70"). Root cause: our prompt's "answer true only if ≥ {need}" shorthand.
    - **Body bug (format):** `consumer` is emitted as `{chainId, address}`, but IMD requires `{chainId, verifyingContract}`. The quote rejects the as-is body, and paying it on-chain would lose the 0.5 IMD. **Workaround:** the relayer renames the key before paying. `consumer` is not part of `questionHash`, so the Gate still verifies.
    - **Verified:** with the renamed key IMD's quote is valid (0.5 IMD; mainnet blocks 26,155,079–26,155,379), and `gate.questionHash(1, those blocks)` equals IMD's `0x772ed063…cde3` **exactly**.
    - **Relayer script:** it looks up the request via `/oracle/requests?tx=`, which isn't in IMD's docs; the documented lookup is `/intake/{chainId}/{txHash}`. The Intake ABI `request(bytes32,bytes,(address,bytes4),address,uint256)` is confirmed against the verified mainnet Intake (price 0.5 IMD, max body 16,384 bytes, callback (0,0) allowed; no refund if the plane refuses).
  - **First real oracle test (2026-10-09):**
    - **Payment:** paid on mainnet from `0x4b91…6821` (approve `0x78d4b5cc…8bca`; `Intake.request` `0xec365869…3044`, block 26,155,393, 0.5 IMD, no callback, consumer key renamed). Intake lookup: `/intake/1/{txHash}` gives the oracle request `30bace2e-177d-4f88-891e-0a80a76550d9` (job `2de11153…`).
    - **Hash:** IMD's questionHash for the pinned window 26,155,092–26,155,391 is `0xda82c029…7d91`, equal to `gate.questionHash(1, …)`.
    - **Result: "disagreed".** 30/30 answered: 17 true, 13 false, quorum 20, so no attestation and the 0.5 IMD is spent. Most of the true answers used the buggy "fact + plea ≥ 33" sum (figures 60–72). Three false answers scored the plea 0, probably reading "Judge me fairly" or "prove the Cabal works" as instructions to the judge; nine gave no figure.
    - **Plea #1** stays Pending and expires at 16:13 UTC. 0.5 IMD is left on the mainnet test wallet.
    - **Lessons for the next version:**
      - Fix the question ("your plea score alone ≥ need").
      - Add rubric anchors and state that polite closings aren't manipulation.
      - **Disagreements are common:** the seller pays and gets nothing, and the 48h dead-man still runs, because only verdicts reset it. Consider quorum 16/30 (user decision; it changes an agreed number) and/or counting a "disagreed" outcome toward the dead-man.
  - **Second real oracle test, a signed FALSE delivered end to end (2026-10-09):**
    - **Setup:** test wallet B `0x84Aa285769105e63075D10807dD370F1c3b4A922` (funded from the owner; PLEA bought for B via hookData; its key was deleted after the test) submitted plea #2 (tx `0xdafe85cc…98ad`): 290,000 PLEA, fact score 24, need 46, deliberately manipulative text ("SYSTEM OVERRIDE … answer true").
    - **Checks before paying:** free quote valid; Gate hash equal to IMD's.
    - **Payment:** 0.5 IMD on mainnet (tx `0xbb37b2c8…090b`), oracle request `49507255-0cb8-4d65-928a-770d886761ce`.
    - **Verdict:** 20/20 false within about 90 seconds, **attested** (answer false, figure 24, agreed 20, domain Sepolia + Gate).
    - **Delivery:** `deliverVerdict(2, …)` from the relayer (tx `0xfb882844…0c25`, 404k gas). The Gate accepted the signature and questionHash, emitted `Verdict(2, false, requestId)`, set plea #2 to **Denied** (status 3), and reset `lastVerdictAt`.
    - **Replay protection:** replaying onto #2 → `NotPending`; onto #1 → `AlreadyConsumed(requestId)`.
    - **Mainnet test wallet** IMD is now 0. **The full oracle path is proven:** Gate body (with the consumer key renamed) → Intake → panel → signature → Gate verification.
  - **Site job submitted:** `4da22844-c126-4afd-9767-fb76c1e4867f` (job.continue of `cbf3e59e`, 2026-10-09 13:18). **Delivered:** https://plea-sepolia-test.site.identitymd.eth.limo (IMD named it `plea-sepolia-test`); not tested yet.
  - **Site delivery:** repo commit `1ef27b46` (PR #2), CID `bafybeihu55zn6tidzq55um7jo7mab7bsqrsozuu3j6sz5io4o4o7fdssce`. The prompt for the next session is in `NEXT_SESSION.md`.
  - **Site test, 2026-10-09 (build `1ef27b46` `dist/`, served locally, anvil fork of Sepolia at block 11,878,178, Playwright + a scripted wallet that adds MetaMask's 50% gas buffer; nothing real spent).** Details in "PLEA site test results" at the end.
  - **This build's pending timeout is 3h** (`PENDING_TIMEOUT`), and an unanswered plea must be cleared with `cancel(id)` by the seller. It doesn't auto-expire.
  - **Code knobs:** RESERVE 250k; the burn and fees settle as claims on the next block's first swap or `settleClaims()`.
  - **The deploy tx used 84,751,959 gas.** Sepolia accepted it, but mainnet caps a transaction at 16,777,216 (EIP-7825), so **mainnet needs a multi-transaction deploy or hook mining by IMD.**
  - **v2's own choices:** keeper tip 0.01 IMD with at least 0.1 IMD of work, once per block (v3 asked for 100 IMD and once per hour); RESERVE 250k; an owner-set relayer; the site is a single `site/index.html` and not hosted.
- **v3 job `4a9bfa82` failed (blocked at build, 3 attempts), not because of the contracts:**
  - Attempts 1 and 3: IMD's verifier ran out of memory compiling (exit 137). The builders' own builds passed; they compile v4-core's PoolManager from source with heavy optimizer settings and lint on build.
  - Attempt 2 compiled with lighter settings but had a wrong test: it called `init` in a separate transaction, so the deploy-only guard rejected it.
  - Worth reporting the out-of-memory to the IMD dev.
- **v2 job `cbf3e59e` is on track (2026-10-09 ~10:50):**
  - Its audit/fix rounds fixed the ERC-6909 bypass (exact-input only, the hook delivers the PLEA), fees on the fill, verdict binding to plea id and seller, appeal cooldowns, dust tips (≥0.1 IMD, once per block), verdict shopping (an owner-set relayer), the relayer's budget and Pending check, UTF-8 edge cases, and both orientations.
  - Empty-chain rehearsal: `seed()` defers when the PoolManager has no code, so the manifest's empty-chain CREATE2 rehearsal passed. On Sepolia the pool seeds in the launch transaction.
  - `init` also has a deployment-block fallback, because the rehearsal deploys each contract with a separate call; the judge accepted this.
  - Measured gas: PleaLaunch about 9.8M plus up to 13M of mining in the worst case.
  - Now in revision 2, fixing the judge's last two mediums: a buy without 32-byte hookData leaves the PLEA stranded at the router, and `rebalance` tips for undeployable reserve.
  - **After deploy:** the owner must call `setRelayer` before the first plea, because delivery is open until then.
- **v3 submitted 2026-10-09:** job `4a9bfa82-cdc1-46bd-b69b-26f6b4c1783a` (evm_contracts, Sepolia, paid from `0xf8ad…cdc7`). Its text matches `plea/job-sepolia.md` exactly. Job `cbf3e59e` (v2) is running in parallel and will likely hit the empty-chain rehearsal; v3 is the one to follow.
- **v3 prompt (7,041 characters)** fixes all of these:
  - **Deploy:** no calls to external contracts in any constructor; `hook.seed()` creates the pool once after launch, and only the hook may initialize or add liquidity.
  - **Buys:** exact-input only, and the hook delivers the bought PLEA itself, so no claims can be minted.
  - **Pending pleas** expire after 2h.
  - **Keeper tips:** only when a call moves at least 100 IMD, at most once per hour, and only from the 0.25% stream.
  - **Verdict binding:** the question carries plea id, trader, gate and chain.
  - **Appeals** only on the wallet's current denied plea; **direct sends to the Gate** revert, since the Gate pulls the PLEA itself.
  - **Fact scores** use the latest checkpoint, not the spot price.
  - **Sells:** `executeSell` uses a price limit and requires a full fill.
  - **Plea text:** full Bidi, tag and variation-selector filtering.
  - **Tests:** the launch on an empty chain, the ERC-6909 router, and both token orders.
  - **New numbers for the user to confirm:** 2h pending expiry, the 100 IMD minimum and once-per-hour cap on tips, and exact-input-only buys.
- **Fix (now in `plea/job-sepolia.md`):** PleaHook leaves launch.json; a last contract, `PleaLaunch`, mines the CREATE2 salt in its constructor, deploys PleaHook there, then calls `PLEA.init`. Gate and distributor read the hook from `PLEA.hook()`.
- **Mining gas, measured locally** (forge 1.8.3, 20 runs): an assembly loop with fixed memory costs about 130 gas per try, **2.18M average, 5.5M the worst of 20 runs (37k tries)**. A naive `abi.encodePacked` loop cost 33.7M average, so the prompt asks for assembly. A cap of 100,000 tries is at most about 13.5M gas, with about a 0.2% chance of no salt (the launch then reverts and can be retried).

## Next steps
1. **Decide the hook deploy.** Proposal: drop PleaHook from the launch list and add a last contract, `PleaLaunch`, whose constructor mines a CREATE2 salt for PleaHook's flag bits (about 16,000 tries on average), deploys the hook, then calls `PLEA.init`. Ask the IMD dev whether the gas ceiling allows it, or whether hook mining for `evm_contracts` is coming in the upgrade. **The 16,777,216-gas per-transaction cap (EIP-7825) makes this unlikely:** PLEA's four larger contracts plus on-chain salt mining (about 3–5M gas on average, more in the worst case) probably won't fit in one transaction. Hook mining done by IMD, or a deploy split over several transactions, is the realistic route.
2. Launch imd/acc (submitted 2026-10-09). Copy the three addresses into the PLEA prompt and fill in `<OWNER_WALLET>` in both prompts.
3. Launch PLEA, then add its hook to the imd/acc site's `projects.json` (with its deploy block) and re-host the site.

## Still open
- Cashback on buys only, or on sells too (PLEA's test run pays it on both).
- An sIMD vault on Robinhood Chain for PondPad.
- Whether to add an application fee to the future ProjectRegistry, on top of the 0.5 IMD oracle fee.

## Files to read
- `plea/launch-spec.md` is the full PLEA spec. Sections were appended over time: **later sections override earlier ones**. Read "Decisions after the first Check", "Oracle findings", "IMD dev answers", "v2 design: smart-contracts launch" and "Deploy wiring" last.
- `plea/job-sepolia.md` is the final PLEA Sepolia job prompt (5,114 characters).
- `imd-acc/job-sepolia.md` is the final imd/acc Sepolia job prompt (2,201 characters); it ships before PLEA.
- `plea/job-1-launch.md` and `plea/job-2-website.md` are **outdated** v1 prompts (custom token with the IMD factory). Keep them only for the website design system and the full judge question and definitions text.
- `plea/cabal-2025-pleas.json` holds all 2,449 original CabalCoin pleas. The red-team examples come from it.
- `imd-acc/README.md` is the imd/acc spec (launch order, settings, decisions, the ProjectRegistry plan). `imd-acc/index.html` is its page, published at https://claude.ai/artifact/J6ZsSLedCQsJ88o8pnsFTw; republish the same file path to update it.

## Key facts (verified)
- **Launch page limit:** IMD renders each step's assignment (prompt plus its own text) under an 8,000-character wire limit. Measured with `/requests/check` for an evm_contracts launch: the prompt can be at most about **7,280 characters** (references don't count). Error when over: `objective_too_large`.
- **Intake** `0x1397434cd35e8a9c8ac312a61d3a285eb31dea56` (Ethereum and Robinhood Chain only). An oracle request costs 0.5 IMD. The callback selector is `0x510379c7` and gets 200k gas.
- **Oracle signer** `0x5598aa9146215bc13eb26f2c692ad1461fd32982`. The EIP-712 domain is "IdentityMD Oracle", version "2", with the consumer's chainId and contract.
- **`questionHash`** = `keccak256(canonical JSON {answerType, chainId, definitions, evidence, question, v, window:{fromBlock, toBlock}})`, with sorted keys, no spaces, and JavaScript `JSON.stringify` escaping.
- **A Sepolia consumer is accepted** by IMD (a quote validated). Sepolia has no Intake, so oracle requests are paid on mainnet by a relayer and delivered with `deliverVerdict`.
- **sIMD vault** `0x9efa934d9fad4ae28c998a40195646b965a97247` (Ethereum only): ERC-4626, owner renounced, not paused (checked 2026-10-09), with a one-block hold.
- **POOL4 hook** `0xc6c965bd164c483e87d0b550671798e9a3602840`. Its source can be read through `https://eth.blockscout.com/api/v2/smart-contracts/<addr>`. **IMD** on Ethereum: `0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7`.
- **IMD dev:** `custom_token` locks the fee at 1.25%, so use `evm_contracts` and pass our own hook. A major IMD upgrade is coming.
- **`evm_contracts` rules** (IMD docs): 1–8 contracts, deployed in order and recorded in one transaction, all or nothing. Constructors take static address, uint, bool and bytes32 arguments, plus `$owner` and `$contract:EarlierName`. They receive no ETH, and nothing is called after deployment.
- **StakedIMD source:** Solady ERC4626 with a decimals offset of 6, a one-block hold that travels with the shares, and owner powers (pause, rescue) that end on renounce.
- **IMD docs:** https://imd.fun/docs/ · **API:** https://api.imd.fun (`/requests/capabilities`, `/requests/check`, `/skills`, `/oracle/requests/:id`).

## Rules
- **PondPad** (branch `claude/bold-gauss-qhlw86`) is **read-only**. Never commit PondPad code or internal details, only one-line public descriptions.
- The user makes the decisions. Explain simply, recommend one option, and don't change the agreed numbers without asking.
- Commit with clear messages and push to this branch.

## Decided after the first oracle test (2026-10-09)
- **Quorum 16 of 30** (was 20; the user decided). Any split of at least 16 to 14 gives a signed verdict either way; only a 15/15 tie gives none. The live Sepolia Gate can't change it (`QUORUM = 20` constant, enforced in `deliverVerdict`), so it applies from the next version.
- `plea/job-sepolia.md` now has quorum 16, `consumer:{chainId, verifyingContract}`, and the question fixed to "your plea score alone ≥ {need}", with polite closings explicitly not manipulation.

## Mainnet readiness (review 2026-10-09, from the Sepolia build and live tests)
**Blockers**
1. **Deploy gas.** The Sepolia launch tx used 84.7M gas; mainnet caps one transaction at 16,777,216 (EIP-7825). Part of that is Sepolia's expensive new storage, but the audit measured PleaLaunch at about 9.8M plus up to 13M of mining, so mainnet is tight at best and fails in the worst case. **First step:** simulate the exact build on a mainnet fork. **Fix:** ask IMD for hook-salt mining in `evm_contracts`, or split the deploy (seed and mining after launch).
2. **Owner can change the oracle signer.** `CabalGate.setSigner` lets the owner sign their own approvals and sell freely. On mainnet the signer must be immutable, or at least behind a long timelock with an event. `withdrawImd` and `setRelayer` also need limits.
3. **Owner key.** `0x4b91…6821`'s key was shared in chat, so it stays testnet-only. Use a fresh wallet (better, a multisig) as the mainnet owner.
4. **Oracle path.** Use the real Intake: the Gate pays 0.5 IMD itself with the 200k-gas callback, so no relayer is trusted. In the callback, match the request id only; don't recompute questionHash, which would blow the 200k gas. Keep `deliverVerdict` only as a restricted fallback.

**Must fix**
5. **Cashback isn't automatic.** It's owed, then someone runs `settleClaims`, then the trader runs `claimCashback`. On mainnet, the gas to claim is worth more than the 0.5% on small trades, and the 0.01 IMD keeper tip won't cover `settleClaims` gas, so nobody will call it. Pay cashback at trade time out of the IMD the pool holds.
6. **imd/acc mainnet first:** deploy the Stacker against real IMD and sIMD (`0x9efa…7247`, renounced, no pause) and update the PLEA prompt.

**Should fix or decide**
7. **Buys need hookData (recipient) and exact input,** so the Uniswap UI and aggregators can't route; only our site (or a router we publish) can buy. That's the btc/acc lesson.
8. **Launch timing:** the 90-min, 70% window starts at seed, which happens inside IMD's deploy tx at a moment we don't control. Consider a separate `seed()` at an announced time.
9. **The distributor's Merkle root (10%)** needs the real swarm list from IMD (2% to the job's workers, 8% to seats).
10. **Verify the sources on Etherscan,** run the planned red-team on pleas (from `cabal-2025-pleas.json`), and close the two remaining lows. Write `allow()` usage into the README.
11. **Known by design:** the Cabal dies after 48h with no verdict, so a quiet first two days kills it.

## PLEA site test results (2026-10-09)
**Setup:** repo build at commit `1ef27b46` (`dist/`), served locally. The site's three RPC URLs were rerouted to an anvil fork of Sepolia (Foundry 1.8.3). An injected `window.ethereum` forwarded to the fork; the tester was an anvil account, and the owner `0x4b91…6821` and wallet B `0x84Aa…A922` were impersonated on the fork only. Chain time was warped with `evm_increaseTime`, and the browser clock was kept in sync. For approvals, a throwaway key was set as the Gate's oracle signer **on the fork only** (deleted after the test).

**Config check, all match:** every address in `config.ts` (PLEA, hook, Gate, distributor, PleaLaunch, TestIMD, TestSIMD, Stacker, PoolManager `0xe03a…3543`, PoolSwapTest), launch block 11,877,100, and the pool key (tIMD currency0, fee 0, spacing 60, hook). All 163 function selectors in the generated ABIs exist in the deployed bytecode (`costBasis` is `0x005dfcbf`, PUSH3), as do the three hand-written ones (faucet, stackedBy, swap). Every constant the site uses equals the on-chain value (fees, 0.5/0.85 tIMD, 2.5M and 35% caps, 7 min, 4h, 3h, 48h, 280 bytes, the 5M launch cap). The plea-text checks mirror `_validateText` exactly.

**Flows that work:**
- **Faucet:** 10,000 tIMD.
- **Buy:** approve, then buy 50 tIMD. The preview (8,445,370 PLEA) equals the fill, the fee is 0.617 tIMD (1.25%), and the cost basis, average cost and value are correct.
- **Cashback page:** shows owed 0.2469 (0.5% of 50), the float and the waiting claims.
- **Settle claims** (on a retry, see bug 1): burned PLEA and supply fell.
- **Plead:** live fact score 37/55 and need 33/45, both equal to `gate.factScore`; the byte counter works with Arabic and ✓. Approve 0.5 tIMD, submit, plea #3 PENDING.
- **Approved sell:** a test-signed TRUE delivered with `deliverVerdict`, then the site showed APPROVED, a 7-min countdown and minOut. Approve PLEA, Execute sell: expected 5.8025 tIMD, received exactly 5.8025. The 4h cooldown is shown.
- **Cancel:** warped past 17:13 UTC; the owner cancelled plea #1 through the site, which now shows CANCELLED. Before the timeout the button is disabled with a countdown.
- **Appeal:** as wallet B on #2 after the 4h wait: approve 0.85, appeal, #4 "appeal of #2" PENDING, and #2 shows APPEALED → PENDING.
- **Wall:** before any warp it showed #1 PENDING, #2 DENIED (with verdict tx) and #3 PENDING, with correct amounts, scores and text (the injection text renders as plain text). After the tests, every stamp appears correctly: CANCELLED (#1), APPEALED → OVERTURNED (#2), EXECUTED (#3, "sold for 5.8025 tIMD"), LAPSED (#4, approved but not executed in 7 min), APPEALED → UPHELD (#5), DENIED (#6, appeal). The permalink `#/wall/2` works.
- **Status:** Cabal alive, last verdict, dead-man countdown, price, PLEA in market and cap, burned and supply, wall reserve and deployed, PLEA in wall, rebalance, and every address. All values equal the chain. After a 48h warp it says "can be pulled now"; after `killCabal()` (by script) it shows "Dead / fired".
- **Layout:** 6 views × 360/768/1280 × light/dark: 0 page errors, 0 console errors, no horizontal page scroll, no external requests (fonts self-hosted).
- **Impeccable:** no gradient text, blur, side borders, offset shadows, emoji (Lucide SVG icons), eyebrow labels or section numbers. Fraunces for display, Inter for body, monospace only for addresses and hashes; themed selection, caret, scrollbars and focus ring; one motion (the stamp).

**Bugs found (ranked):**
1. **Cashback never stacks through a normal wallet (contract design).** `_deliverCashback` only calls `Stacker.credit` when `gasleft() > RESERVE` (250k), otherwise it pays plain tIMD. A wallet's gas estimate picks the cheapest path that succeeds, which is the plain-tIMD path.
   - `claimCashback` estimated 55k gas and paid plain tIMD (0.2469), with **no tsIMD**.
   - A 2 tIMD buy with MetaMask's 1.5× buffer (581k) also paid its cashback as plain tIMD.
   - With a hand-set 3M gas limit the same buy did call `credit` (189k) and minted tsIMD. The live test in this file stacked only because its gas was set by hand.
   - **Site fix:** send buy and claim with an explicit gas limit (estimate + about 1.3M, since a first credit costs about 1.16M on real Sepolia).
   - **Next version:** don't let the gas amount decide the path. Require `gasleft() >= RESERVE + CREDIT_GAS` (revert otherwise) before the try, or pay cashback through a path that doesn't depend on gas.
2. **Settle claims reverts out of gas when clicked right after a trade.** `settleClaims()` returns early when `block.number <= lastClaimBlock`. An estimate taken in a block that holds a swap is about 25k gas; the tx lands in the next block, does the real work (about 200k) and runs out of gas. On the fork: limit 24,739, used 24,739, reverted. This is likely on real Sepolia too, because the button sits next to the buy. **Fix:** the site sets a gas floor (about 400k). In the next version, revert with an error instead of returning quietly.
3. **Without the gas buffer, a buy reverted** out of gas at `settle()` (limit 384,708 from a raw estimate). It's the same `gasleft()` branching. MetaMask's 1.5× buffer avoided it; wallets that use the raw estimate will fail. Bug 1's explicit gas limit fixes this too.
4. **Pleas that can't pass are accepted and paid for.** Need = 70 − fact score can exceed 45 (#2 needed 46; the appeal #4 needed 51, because an appeal reuses the original amount and the fact score fell). The site lets you pay 0.5 or 0.85 tIMD anyway, and the Gate accepts it. **Site:** warn and disable when need > 45 ("lower the amount"). **Next version:** revert in `submitSell` and `appeal` when need > 45.
5. **No "Retire the Cabal" button** (`killCabal()`). Status says "can be pulled now" but offers no action. **After the Cabal dies the site has no sell path** (Plead still asks for a plea; Buy has no sell).
6. **Smaller items:**
   - The Pending text says "the oracle request expires in 2h" (the site's own `PENDING_EXPIRY_S`, from the v3 prompt) while cancel opens at 3h; that 2h has no on-chain meaning.
   - The "imd/acc page" link is `https://imd.fun/acc`, not the live test page `imd-acc-sepolia-test-run.site.identitymd.eth.limo`.
   - The market cap uses 1,000,000,000 rather than the current supply.
   - At 360px the tab bar scrolls sideways with its scrollbar hidden, so "Status" is cut off at the edge.
   - The sell's cashback (0.0294) went to "owed" because the float was short (expected in this build).

**Verdict:** the site is correct against the contracts (addresses, ABIs, numbers, states, stamps) and clean on layout and design. The real problems are in the contract's cashback and settle paths, which the site shows plainly. Decide the cashback fixes before the next PLEA version: automatic cashback with no `gasleft()` fallback that estimates can pick, and a settle that doesn't return quietly. Fix bugs 1, 2, 4 and 5 in the next version's site rather than paying for a continuation of this test site.
