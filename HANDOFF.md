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
Both Sepolia prompts are final and ready to paste. Nothing has been launched yet.

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

## Next steps
1. **Decide the hook deploy.** Proposal: drop PleaHook from the launch list and add a last contract, `PleaLaunch`, whose constructor mines a CREATE2 salt for PleaHook's flag bits (about 16,000 tries on average), deploys the hook, then calls `PLEA.init`. Ask the IMD dev whether the gas ceiling allows it, or whether hook mining for `evm_contracts` is coming in the upgrade.
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
- **Launch page limit:** the request, context and draft together must fit **8,000 characters**, so keep a prompt at or under about 5,000.
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
