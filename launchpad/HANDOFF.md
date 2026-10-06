# PondPad: handoff and resume guide

**Read this first in a new session.** It says what PondPad is, what exists, how to run it, and what to do next.

Related files:

| File | What it holds |
|---|---|
| [`HANDOFF.md`](HANDOFF.md) | This file: current state, how to resume, next steps |
| [`DECISIONS.md`](DECISIONS.md) | Every decision and change, in order, with the reason |
| [`ROADMAP.md`](ROADMAP.md) | What is left in v1, then v1.1, v2 and later |
| [`ARCHITECTURE-v1.md`](ARCHITECTURE-v1.md) | The v1 design: contracts, fees, swarm integration, governance |
| [`SITE-COPY.md`](SITE-COPY.md) | Website copy, voice and vocabulary |
| [`CTO-RULES.md`](CTO-RULES.md) | Community takeover rules (draft; pinned to IPFS before deploy) |
| [`PLAN.md`](PLAN.md) | First plan, superseded; kept for the Pons / Pepes competitor analysis |
| [`contracts/`](contracts/) | Foundry project (Solidity) |
| [`airdrop/`](airdrop/) | Airdrop snapshot tool (`snapshot.py`, `config.json`, runbook) |
| [`keeper/`](keeper/) | Keeper script for the permissionless upkeep calls |
| [`audit/`](audit/) | Swarm audit loop: threat model, findings ledger, job templates, `make_jobs.py` |
| [`contracts/testnet/`](contracts/testnet/) | Robinhood testnet setup: test IMD / USDG with faucets, IMD/ETH and ETH/USDG pools (§5b) |
| [`bots/`](bots/) | Testnet trader bots with invariant checks after every round (§5b) |
| [`design/`](design/) | Site design: UX research, mood board, brand book, design system (tokens, `pp-` components, logos, fonts), page layouts (§5c) |
| [`frontend/`](frontend/) | The site (Vite + React + wagmi), running against the testnet; see its README (§5c) |
| [`legal/`](legal/) | Terms of Use and Privacy Policy drafts (D-69) |

Last updated: 6 October 2026. Branch: `claude/bold-gauss-qhlw86` on `khaed1/claude`.

---

## 1. The project in one paragraph

**PondPad** (token **$PONDPAD**, staked **sPONDPAD**, domain **pondpad.fun**, not bought yet) is a token launchpad on **Robinhood Chain** (chain ID 4663) where every coin is paired with **IMD**, the IMD swarm's token. A coin starts on a **bonding curve**, then **graduates** into a Uniswap v4 pool run by our hook with liquidity locked forever. Every trade pays a **1.5% base fee** (1% protocol, 0.5% creator) plus an optional **0–3% coin tax** the creator chooses (to creator, holders and/or a swarm budget). Protocol fees split **40% sPONDPAD stakers / 25% IMD workers / 20% growth / 15% treasury**. The **IMD swarm** builds each graduated coin's website, audits every launchpad version, settles community takeovers and can be paid from a coin's swarm budget. **$PONDPAD** is sold on its own IMD bonding curve and graduates into **our fork of POOL4's `CappedBurnHook`** (burns $PONDPAD on sells). Brand: frog / pond theme ("Every frog starts as a tadpole").

The owner of the project is the user (IMD ecosystem builder). The IMD / POOL4 developer is a separate person the user talks to.

---

## 2. Current state (what is built)

### Docs
- `ARCHITECTURE-v1.md`: full v1 design, kept up to date.
- `SITE-COPY.md`: taglines, page copy, microcopy, FAQ, social posts (PondPad naming).

### Contracts (`contracts/src/`), all tested

| Contract | Role | Status |
|---|---|---|
| `PadToken` | Launched coin: 1B fixed supply, no owner, permit, IMD dividends (flash-borrow safe) | Done |
| `BondingCurve` | IMD curve for coins (80% sold / 20% to pool), fees, snipe tax, max-buy, graduation | Done |
| `PadHook` | Uniswap v4 hook: creates pool at curve's final price, owns locked full-range LP, fee on IMD side through any router, rejects partial fills, blocks outside liquidity and pools | Done |
| `PadRouter` | `launchWith`, `buyWith`, `sellFor`, `sellForWithPermit`; pays/receives IMD, ETH or any approved payment token; optional `referrer` (registered integrator); curve before graduation, pool after | Done |
| `PadFactory` | Deploys coins with CREATE2, `predictAddress` | Done |
| `PadConfig` | Bounded launch settings, fee splitter / growth addresses, payment-token routes, integrator registry and share, guardian pause of new launches | Done |
| `FeeSplitter` | 40/25/20/15 split within fixed ranges | Done |
| `CreatorVault` | Creator fees per coin, recipient change, CTO entry point | Done |
| `SwarmBudget` | Per-coin escrow for swarm jobs, released by the Swarm Relay; swept to holders when a takeover routed the coin's fees to them | Done |
| `IntegratorVault` | Integrator (app/bot) earnings: 15% of the protocol fee on trades they route (coins and the $PONDPAD sale), claimable in IMD | Done |
| `PondPadToken` | $PONDPAD: 1B fixed supply, no owner, permit, `burn`; deployed at an address above IMD's | Done |
| `PadSale` | $PONDPAD IMD curve (600M sold / 300M to pool, target ≈ 8,460 IMD), pays/receives IMD, ETH or any payment token, 1% fee (integrator share off the top), 80% → 0 snipe tax over 30 min, 15M per-wallet cap, hands raise + 300M to `MarketController.launch` at graduation | Done |
| `PaymentSwapper` | Shared payment plumbing (routes to/from IMD in one unlock) used by `PadRouter` and `PadSale` | Done |
| `PadMarketHook` | $PONDPAD/IMD market: POOL4 `CappedBurnHook` fork (IMD quote as currency0, dynamic fee 3% → 1% over 7 days via `beforeSwap`, IMD-sized constants). Cap floor 150M, decay 500k/day, 15% of trims to stakers. Original source in `contracts/upstream/CappedBurnHook.sol` | Done |
| `MarketController` | Permanent owner of the market hook: opens it once from `PadSale` (records `openedAt`, the airdrop and vesting clock), permissionless `collectFees` (both fee tokens split 40/25/20/15), policy via 48 h timelock, sinks via 7-day timelock; the only exit is `migrate` into a new hook (7-day timelock, first 12 months, D-40), never to a wallet | Done |
| `PadBurner` | Burn sink: burns all $PONDPAD it holds, permissionless | Done |
| `StakedPONDPAD` | sPONDPAD ERC-4626 vault (POOL4 `StakedIMD` fork): one-block hold, 3-day max pause, can't rescue stake, powers expire after 12 months | Done |
| `RewardDripper` | Streams $PONDPAD into the vault (POOL4 fork), self-adjusting: waiting rewards pay out over ~7 days whatever the volume (D-44); fixed vault, can't rescue rewards, powers expire after 12 months | Done |
| `PadBuyer` | Stakers' 40%: buys $PONDPAD with IMD in small price-guarded chunks, forwards $PONDPAD to the dripper | Done |
| `WorkerFund` | Workers' 25%: accrues IMD and $PONDPAD until the worker rewards address is set (7-day timelock), then permissionless `release()` forwards both as they are (D-45) | Done |
| `GrowthFund` | Growth's 20% (+ graduation fees, snipe taxes, $PONDPAD fee share): relay `payJob` ≤ 100 IMD/week, Safe `grant` ≤ 1,000 IMD + 10M $PONDPAD/week, caps by 48 h timelock (D-47) | Done |
| `AttestationVerifier` | IMD oracle v2 EIP-712 attestations: approved signer (7-day timelock), panel ≥ 51, agreed ≥ 2/3 and ≥ quorum, expiry, exact question hash rebuilt onchain (D-48, D-49) | Done |
| `CTOModule` | Takeover by oracle "yes" for the exact coin, new recipient and X-verified proposer, or by the council (fallback, 7-day notice, D-46); recipient = multisig or the coin itself (fees to holders, D-52); coin ≥ 30 days, 90-day cooldown; 3-day notice, contest → +7 days and a ≥ 75-member confirming panel; 3-day execution window (D-51) | Done |
| `VersionRegistry` | Versions with an onchain code hash of factory/router/curve/hook/lens; activation by audit attestation (permissionless) or timelock fallback; rollback | Done |
| `SocialRegistry` | X badge level 1: coin links by fee recipient with a voucher from the X link service key, duplicate handles flagged; wallet X links (`linkWallet`) for takeover proposers | Done |
| `PadLens` | Coin lists (pagination), coin state, exact curve and pool quotes in IMD, wallet balances and dividends | Done |
| `AirdropDistributor` | 5% $PONDPAD airdrop: Merkle root fixed at deploy; after market open, 100 listed wallets initiate it with a coded X post checked by our tweet checker (voucher), then everyone on the list claims, vesting over 30 days from activation; claim wallet by gasless signature; unclaimed swept to `RewardDripper` 180 days after activation; owner (48 h timelock) can only replace the checker key (D-53, D-55) | Done |
| `TeamVesting` | 2% $PONDPAD to the team Safe: 1-month cliff, linear to month 6 from market open; not revocable (D-54) | Done |
| `FeeLib`, `Route` | Shared fee math and the `Hop` struct | Done |

### Tests (`contracts/test/`)
- `PondPad.t.sol` + `Base.t.sol`: **31 local tests** (90 local in total with `PadSale.t.sol`, `Market.t.sol`, `Staking.t.sol`, `Governance.t.sol`, `Funds.t.sol`, `Distribution.t.sol` and `AirdropTree.t.sol`) against a real v4 PoolManager with mock IMD and USDG and local IMD/ETH and ETH/USDG pools. Covers launch, fee splits, snipe tax, max-buy, dev buy, dividends, swarm budget, graduation in both currency orderings, locked liquidity, third-party router fees, the exact `PartialFill` revert, ETH and USDG paths before and after graduation, payment-route validation, integrator share (curve, pool, unregistered, spoofing through other routers, bounds), a 512-run solvency fuzz.
- `PadSale.t.sol`: **11 local tests** for the $PONDPAD sale: setup and start price, bad setup, closed before start / until funded, snipe tax decay to growth, fee and integrator share, whole-sale wallet cap (sells don't free it), sell round trip, ETH and USDG round trips, graduation at the curve's final price (sqrt price checked), completing-buy refund, solvency fuzz.
- `Market.t.sol`: **12 local tests** for the $PONDPAD market: opens at the sale's final price when the sale graduates, fee 3% → 2% → 1% (both fee currencies), trims above the cap burned and 15% shared, ratchet no faster than 500k/day, fee split 40/25/20/15 in IMD and $PONDPAD, controller power limits, outsiders can't initialize or add liquidity, keeper rebalance deploys the backstop, cap-invariant fuzz at 3% and at 1%, migration into a new hook (same price, inventory, backstop IMD, fee clock and policy; guards; 12-month expiry), fee clock can only move earlier.
- `Staking.t.sol`: **12 local tests**: vault deposit / one-block hold / redeem, short pause and cooldown, no stake rescue, powers expire; dripper streams trim rewards at 1/168 of the buffer per hour, never into an empty vault, a long gap releases at most a day's share, a lump drains ~63% in 7 days and ~95% in 3 weeks, small buffers still sweep, bounded settings, no reward rescue; buyer turns splitter IMD into $PONDPAD for the dripper, refuses after a price pump until the reference catches up, forwards the $PONDPAD fee share, bounded settings; end to end from a coin trade to a higher sPONDPAD value.
- `Governance.t.sol`: **13 local tests**: the verifier against a **live IMD attestation** (our EIP-712 hash recovers the real signer, our question hash matches), accept/reject cases (signer, question, panel, agreement, quorum, answer type, validity window), bounded settings; CTO by attestation to a multisig (notice, recipient rotation doesn't cancel, accrued fees to the old recipient, no replay, no cancel, 90-day cooldown), guards (no X account, coin too young, plain wallet, someone else's attestation, "no", overlap, expired window), contest needing a ≥ 75-member confirmation, fees routed to holders (creator fees and swarm budget become dividends), council fallback with 7-day notice, contest and one-way retirement, ipfs-only rules; version register / manual and attested activation / rollback / retirement; social links, nonces, duplicates, revoke, expiry; lens lists and quotes equal to real trades on the curve and in the pool.
- `Funds.t.sol`: **2 local tests**: WorkerFund accrues IMD and $PONDPAD from real coin and market fees until the address is set, then releases both; GrowthFund relay and grant caps per epoch, uncapped tokens refused, caps reset each epoch.
- `Distribution.t.sol`: **8 local tests**: initiation closed before market open, market open alone starts nothing, 99 initiators don't activate, the 100th does, no more initiations after; everyone (initiator or not) claims over 30 days from activation, no bonus; initiation guards (stranger, wrong checker key, voucher for another wallet or tweet, expired, wrong amount, repeat wallet, reused X account or tweet, not on the list, claim wallet initiates, distinct codes); only the timelock replaces the checker key; claim guards (strangers, wrong amount or proof); claim wallet set by a gasless signature and claimed in one transaction (main wallet never transacts, later claims still pay the claim wallet, used nonce, expired signature, direct re-pointing); claims end 180 days after activation and the rest is swept to the dripper; team vesting nothing before day 30, 1/6 at the cliff, half at day 90, all at day 180, permissionless release, only the beneficiary moves it. `Market.t.sol` also checks that a migration leaves `openedAt` unchanged.
- `AirdropTree.t.sol`: **1 local test**: the Merkle tree built by `airdrop/snapshot.py` (fixture) verifies with the contract's leaf and proof format.
- `DeployFork.t.sol`: **3 fork tests**, the deployment rehearsal: runs `script/Deploy.s.sol`'s `deploy()` exactly as the broadcast does on live Robinhood state, then checks every owner and route (nothing left with the deployer; supply split 900M / 50M / 20M / 30M), the mined hook flags and $PONDPAD > IMD; the Safe changing a setting only through the 48 h timelock (anyone executes after the delay; splitter shares need 7 days); and a lifecycle: coin launch with ETH, sale closed before its start, sale graduating into the market at `openedAt`, market fees → splitter → treasury, workers and `PadBuyer`, which buys $PONDPAD for the dripper once the price reference catches up, airdrop waiting for initiators, team vesting 1/6 at day 30.
- `TestnetFork.t.sol`: **2 testnet fork tests** on live Robinhood Chain Testnet (46630), skipped unless `TESTNET_RPC` is set: runs `testnet/TestnetSetup.s.sol`'s `setup()` and then `Deploy.deploy` with the testnet values, exactly as the two broadcasts do; checks test IMD below $PONDPAD, the faucet and its cooldown, the IMD/ETH pool price (~411 IMD per ETH), 10 / 30-minute timelocks with the mainnet owners, a Safe change through the 10-minute timelock; lifecycle: coin launch with ETH, USDG buy, curve filled with test IMD, ETH buy after the Leap, the sale graduating into the market, market fees reaching `PadBuyer` and the treasury.
- `Fork.t.sol`: **5 fork tests** on live Robinhood Chain (real PoolManager, IMD, IMD/ETH and ETH/USDG pools): full lifecycle with ETH, USDG on the curve and after graduation, the $PONDPAD sale with ETH and USDG, the sale graduating into the market (cancun build, dynamic fee) with a buy and a trimmed sell, and an IMD depth report.

### Audit package (`audit/`, D-60, D-61)
Ready to run, not run yet. `THREAT-MODEL.md` (actors, trust, 22 invariants, deliberate behaviour that is not a finding, severity scale), `FINDINGS.md` (ledger, empty), `jobs/` (four areas), `make_jobs.py` (pins a pushed commit, checks scope coverage and size, writes each area's objective for the explorer's Audit form and its API body; `--check` runs IMD's free check). Each job is IMD's native audit template (4 specialists + judge, 0.5 IMD). Runbook in `audit/README.md`. `rounds/1/` is generated for the commit that added the package.

### Design (`design/`, D-66)
Done before any layout, as the user asked: UX research of Pump.fun and Pons, a mood board, a brand book, a design system and the layout of every page (§5c). Approved by the user (D-70).

### Frontend (`frontend/`, D-70)
Built against the testnet: Explore, Coin (trade box with IMD / ETH / USDG), Spawn, Profile (holdings, Claim all creator fees, rewards, activity), **$PONDPAD** (sale → market → airdrop, D-72; market traded through Uniswap's Universal Router with IMD / ETH / USDG, D-77), **the Pond** (stake / leave, drip, D-73), **Transparency** (fee flows, buckets, timelock queue, owners, settings, D-74), Docs (first pages + $PONDPAD sale, market, staking, airdrop), Terms, Privacy, faucet, and the wallet's legal acceptance gate (D-69). Tested on the live testnet with the testnet wallet (faucet, buys, sell, dividends, spawn with a dev buy, claim all) and, for $PONDPAD and the Pond, with listed test wallets (airdrop claim, market buy and sell, gasless claim wallet, stake, leave, drip). `npm run dev` in `frontend/`. **Public testnet link: https://khaed1.github.io/claude/** (GitHub Pages, rebuilt on every push to the branch that touches the site; `.github/workflows/pondpad-site.yml`, D-73).

### Not built yet
See `ROADMAP.md` section 1. In short: frontend extras (more Docs, WalletConnect, image upload, indexer, IPFS deploy), Swarm Relay, indexer, X link service, airdrop tweet checker.

---

## 3. How to resume (environment)

```bash
cd launchpad/contracts
git submodule update --init --recursive        # forge-std v1.9.7, solady v0.1.9, v4-core @ 46c6834 (+ its solmate, openzeppelin)
forge build
forge test --no-match-contract Fork            # 90 local tests
FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork -vv   # 8 fork tests (incl. the deployment rehearsal)
TESTNET_RPC=https://rpc.testnet.chain.robinhood.com forge test --match-contract TestnetFork -vv   # 2 testnet fork tests
```

**Installing Foundry in the cloud sandbox:** `foundryup` fails there (its attestation download is blocked). Install the release binaries directly:

```bash
mkdir -p ~/.foundry/bin && curl -sSL -o /tmp/foundry.tgz \
  https://github.com/foundry-rs/foundry/releases/download/stable/foundry_stable_linux_amd64.tar.gz \
  && tar -xzf /tmp/foundry.tgz -C ~/.foundry/bin && export PATH=$HOME/.foundry/bin:$PATH
```

Build settings (`foundry.toml`): Solidity 0.8.26, `evm_version = cancun`, `via_ir = true`, optimizer 200, `bytecode_hash = none`, lint on build off.

Test gotchas found so far:
- Under via-IR, `block.timestamp` read after `vm.warp` in the same test can be stale. Save `t0` and warp to absolute times. Worse: a local like `uint256 t0 = block.timestamp` may be re-read after a warp, so warps compound; use constants (e.g. `START + 30 minutes`). Same for `block.number` after `vm.roll`: use `_nextBlock()` from `Base.t.sol`.
- The PoolManager holds every pool's tokens; measure balance deltas, not totals.
- Uniswap test helpers refund spare ETH to the test contract, so the test base has `receive()`.
- Some Robinhood RPCs cap log queries at 10M blocks per request.
- Public RPCs rate-limit long fork runs (Cloudflare `HTTP error 403`, drpc `400`). That is not a test failure: rerun the failed test alone, or on another RPC from §4 (`--match-test <name>`).

---

## 4. Key addresses and live numbers (Robinhood Chain, 4663)

| Thing | Address / value |
|---|---|
| Uniswap v4 PoolManager | `0x8366a39CC670B4001A1121B8F6A443A643e40951` |
| v4 StateView | `0xf3334192d15450cdd385c8b70e03f9a6bd9e673b` |
| v4 Quoter | `0x8Dc178eFB8111BB0973Dd9d722ebeFF267c98F94` |
| IMD (LayerZero OFT) | `0x5F7Bb59365ce557C26dbcAa4EE9d39A4b95B7127` |
| IMD/ETH pool | currency0 ETH, currency1 IMD, fee 10000, tick spacing 100, no hook; id `0xd2fc01ee…8f02` |
| USDG (6 decimals) | `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` |
| ETH/USDG pool | currency0 ETH, currency1 USDG, fee `0x800000` (dynamic), tick spacing 10, hook `0x06a889870C8f83640D6816319f72e2aA579b6080`; id `0xbac3aa3b…e551` |
| Public RPCs | `https://rpc.mainnet.chain.robinhood.com`, `https://robinhood-rpc.publicnode.com`, `https://robinhood.drpc.org` |
| Explorer | `https://robinhoodchain.blockscout.com` |
| v4 PositionManager | `0x58daec3116aae6d93017baaea7749052e8a04fa7` (also on the testnet) |
| Universal Router | `0x8876789976decbfcbbbe364623c63652db8c0904` (also on the testnet, same PoolManager; the site's $PONDPAD market router, D-77); Universal Router 2.1.2 `0x204FAca1764B154221e35c0d20aBb3c525710498` (mainnet only). Source: Uniswap's v4 deployments page, checked onchain 6 Oct 2026 |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |

Live numbers (4 Oct 2026):
- IMD supply on Robinhood: **~46,900**. IMD/ETH pool: **~28,900 IMD + 70 ETH**, ~411 IMD per ETH.
- Buying 2,091 IMD costs ~5.3 ETH (~5% over spot). Buying 8,590 IMD costs ~29.6 ETH (~42% over spot).
- Pepes keeps >99% of its volume in its own pool (outside pools are tiny).

POOL4 on Ethereum (source we fork): `CappedBurnHook` `0xc6c965bd164c483e87d0b550671798e9a3602840`, `StakedIMD` `0x9efa934d9fad4ae28c998a40195646b965a97247`, `RewardDripper` `0xe6D3De6daEAf327fCA42745f1998FcD989e00884`, `RewardDistributor` `0x9046739E1535B40EfBe6AB3f45d0024b690eCA30`, `BurnExecutor` `0xe29386719C155B6847aD5a4E97C6674f10ffc750`. All MIT, verified; source readable via `https://eth.blockscout.com/api/v2/smart-contracts/<address>`. Live mainnet settings: `capFloor` 9,000 IMD, `capDecayTokensPerDay` 3,000 IMD, reward share 15%.

IMD swarm API: `https://api.imd.fun` (`/requests/capabilities`, `/openapi.json`); jobs cost 0.5 IMD on Ethereum mainnet via x402 + Permit2 today; the dev says Robinhood and Base payments are coming.

---

## 5. Next steps (in order)

1. ~~Integrator fee share~~ (done, D-31 / D-33).
2. ~~`PadSale`~~ (done, D-35 to D-37).
3. ~~`PadMarketHook` + `MarketController` + `PadBurner`~~ (done, D-34, D-38, D-39). The upstream POOL4 source is in `contracts/upstream/`; `diff upstream/CappedBurnHook.sol src/PadMarketHook.sol` shows every change, and `python3 upstream/make_fork.py` (from `contracts/`) regenerates the hook from POOL4's source; edit the script, not the hook. Migration added after (D-40).
4. ~~Staking~~ (done, D-42, D-43). `python3 upstream/make_staking.py` regenerates the vault and dripper from POOL4's sources. At deploy: market hook `rewardsRecipient` = `RewardDripper`, splitter `stakers` = `PadBuyer`, `powersExpireAt` = market open + 12 months.
5. ~~`WorkerFund`, `GrowthFund`, `AttestationVerifier`, `VersionRegistry`, `CTOModule`, `SocialRegistry`, `PadLens`~~ (done, D-45 to D-50). Owners at deploy: `AttestationVerifier`, `CTOModule`, `VersionRegistry`, `WorkerFund` = 7-day timelock; `GrowthFund`, `SocialRegistry` = 48 h timelock; `CTOModule.council` and `GrowthFund.granter` = team Safe; `GrowthFund.relay` = Swarm Relay wallet; `SocialRegistry.verifier` = X link service key. Deploy `SocialRegistry` and `CTOModule` (needs the curve, social registry, verifier and the `ipfs://` rules link) before `CreatorVault.initialize` (the vault takes its address once). Splitter `workers` = `WorkerFund`, `growth` = `GrowthFund`; `PadConfig.growthFund` = `GrowthFund`. `PadLens` is registered with each version.
6. ~~`AirdropDistributor` (5% Merkle) + `TeamVesting` (2%)~~ (done, D-53 to D-55). At deploy: both take `market` = `MarketController` (vesting clock = `openedAt`; the airdrop only opens initiation then); airdrop owner = 48 h timelock, `verifier` = tweet checker key, `unclaimedSink` = `RewardDripper` and the final Merkle root (OZ `StandardMerkleTree` leaves for `(address, uint256)`, built from the snapshot after contract-wallet holders name Robinhood addresses); vesting `beneficiary` = team Safe; fund them with 50M and 20M from the deployer's $PONDPAD in the same script.
7. ~~Timelock + Safe wiring, deploy script, fork rehearsal~~ (done, D-57). See §5a.
8. ~~Keeper script~~ (done, D-58): `keeper/` (§6).
9. **Swarm audit loop**: package built (D-60, `audit/`). Next: the user submits round 1's four jobs in the explorer's Audit form (2 IMD; `audit/README.md`), we fix findings with a failing test each and rerun until the judge says CLEAN.
10. **Robinhood testnet run** (D-62, D-63): setup script, deploy change, testnet rehearsal and trader bots built and passing on a fork (§5b). **Live on 46630** (5 Oct 2026): full run done and reported (`bots/reports/2026-10-05/REPORT.md`): healthy, no contract bug, POOL4 12/12, 46/46 attacks refused; findings in §5b step 8. THREAT-MODEL `block.number` note added (D-65). Audit round 1 is regenerated at `d5991b7` (after D-76; free check: no blockers on all four jobs). Regenerate again if `src/`, `script/` or `upstream/` change before submitting. Next: the frontend against the testnet (with gas headroom on market swaps).
11. **Frontend**: design done (D-66), first pages built and tested on the testnet (D-70, `frontend/README.md`); **$PONDPAD page (D-72), the Pond (D-73) and Transparency (D-74) built and tested: every page in `Pages.md` exists; public link on GitHub Pages**. Next: more Docs; then WalletConnect, IPFS image upload, an indexer, an IPFS deploy.
12. Swarm Relay, indexer, X link service, airdrop tweet checker.
13. ~~New coin launch settings for the mainnet deployment~~ (**done**, D-76): launch fee 0.35 IMD, Leap target 4,000 IMD, early-bird tax 70% over 80 s, max-buy window (Egg) 80 s. `Deploy.s.sol` takes them from the `Network`: `launchForMainnet()` on 4663 (covered by the mainnet check), `launchForTestnet()` (the old values) elsewhere; fork tests check both. Docs, copy, design examples and audit job A1 updated. **The live testnet keeps its settings.** Audit round 1 regenerated at `d5991b7`.
14. ~~$PONDPAD market router~~ (**done**, D-77): the site trades the market through Uniswap's Universal Router (`0x8876…0904`, mainnet and testnet) with IMD, ETH or USDG, minimum-out and Permit2 approvals; tested live on the testnet.

## 5a. Deploying

`contracts/script/Deploy.s.sol` deploys and wires everything in one run (48 transactions, ~57.6M gas, ~0.0023 ETH at 0.04 gwei on 5 Oct 2026; largest transaction 7.5M gas):

```bash
cd launchpad/contracts
export SAFE=0x…            # team Safe on Robinhood: timelock proposer, council, granter, guardian, treasury, team vesting
export RELAY=0x…           # Swarm Relay hot wallet
export X_LINK_KEY=0x…      # X link service signing key (SocialRegistry)
export TWEET_CHECKER=0x…   # airdrop tweet checker key (AirdropDistributor)
export AIRDROP_ROOT=0x…    # from airdrop/snapshot.py build
export SALE_START=…        # unix time the $PONDPAD sale opens
export CTO_RULES=ipfs://…  # frozen CTO-RULES.md
export AUDIT_LINK=…        # optional: clean swarm audit report (audit/), activates version 1 at deploy (D-59)
export WORKER_REWARDS=0x…  # optional: IMD worker rewards address (else set later by the 7-day timelock)
export POWERS_EXPIRE_AT=…  # optional: staking owner powers end (default SALE_START + 365 days)
forge script script/Deploy.s.sol --rpc-url robinhood --sender <deployer>             # simulate
forge script script/Deploy.s.sol --rpc-url robinhood --sender <deployer> --broadcast --account <keystore>
```

Order: timelocks → $PONDPAD (CREATE2, address above IMD) → funds, splitter, config (+ ETH and USDG routes) → vaults, curve, `PadHook` (CREATE2, mined flags), factory, router, lens → verifier, social registry, CTO module → initializers → version 1 (registered; activated if `AUDIT_LINK`) → burner, controller, staking, `PadMarketHook` (CREATE2, mined flags), sale, buyer → airdrop, vesting → final splitter recipients and ownership handoff → supply: 900M to the sale, 50M airdrop, 20M vesting, 30M liquidity reserve to the 48 h timelock. The script fails if the deployer keeps any $PONDPAD. Hooks are mined for the standard CREATE2 factory (`0x4e59…956C`, live on Robinhood). Owners: D-57 (defaults confirmed in D-59).

The broadcast writes every address to `contracts/deployments/4663.json` (commit it; the keeper reads it). After deploy: verify every contract on Blockscout/Sourcify; start the keeper; create and fund the Safe's first proposals as needed (e.g. `AttestationVerifier.setSigner` once the IMD dev gives the signer, via the 7-day timelock).

## 5b. Robinhood testnet (D-62)

Chain 46630, RPC `https://rpc.testnet.chain.robinhood.com` (`robinhood_testnet` in `foundry.toml`), explorer `explorer.testnet.chain.robinhood.com`. The PoolManager (same address as mainnet), the CREATE2 factory, Permit2, Multicall3 and the Safe contracts are there; IMD and USDG are not, so `contracts/testnet/` makes stand-ins. That folder is outside the audit scope (`make_jobs.py` covers `src/`, `script/`, `upstream/`) and is never used on mainnet.

**Live on the testnet since 5 Oct 2026** (addresses in `contracts/deployments/46630.json` and `46630-setup.json`). Test IMD `0x003B…40a7`, test USDG `0x3961…F28F`, IMD/ETH pool 2 ETH, ETH/USDG pool 0.5 ETH; PadRouter `0x43B3…Ba1a`, PadSale `0x600a…6682` (opens **11:20 UTC, 5 Oct 2026**), $PONDPAD `0x0132…7eeA`, timelocks 600 s / 1,800 s, `PadConfig` owned by the 10-minute timelock, 900M $PONDPAD in the sale, none with the deployer, version 1 active. Setup + deploy cost ~2.48 ETH (mostly pool liquidity). 24 bots funded (0.1 ETH, 20k tIMD, 50k tUSDG each); bots and the keeper (every 2 min, the testnet wallet) running from the session container, which stops when the session ends: restart with §5b steps 4–5 (`MASTER_KEY=$PONDPAD_TESTNET_KEY`). Earlier checks: `TestnetFork.t.sol` on live testnet state and both broadcasts on an anvil fork.

1. **Testnet ETH:** Sepolia ETH from a faucet, then the Arbitrum bridge in testnet mode (Sepolia → Robinhood Chain Testnet). About 1 ETH covers the pools (0.7 ETH by default) and the deploy (~0.003 ETH); 2–3 ETH with the bots.
2. **Setup** (test IMD at an address below 2^152, test USDG with 6 decimals, both with a public `faucet()`: 500 tIMD / 5,000 tUSDG per address per hour, owner mints freely; hookless IMD/ETH pool, 1%, tick spacing 100, ~411 IMD/ETH; hookless ETH/USDG pool, 0.05%, tick spacing 10, ~2,590 USDG/ETH; plus a v4 test liquidity router and swap router for bots):
   ```bash
   cd launchpad/contracts
   export IMD_POOL_ETH=500000000000000000 USDG_POOL_ETH=200000000000000000   # optional, in wei; the defaults
   forge script testnet/TestnetSetup.s.sol --rpc-url robinhood_testnet --sender <wallet> --account <keystore> --broadcast
   ```
   Writes `deployments/46630-setup.json` (commit it).
3. **Deploy:** the same command and env as §5a with `--rpc-url robinhood_testnet`. Off mainnet, `Deploy.s.sol` takes the PoolManager, IMD, USDG and the ETH/USDG pool from `deployments/<chainId>-setup.json` and the delays from `FAST_DELAY` / `SLOW_DELAY` (default 600 / 1800 s). On 4663 it always uses the mainnet constants and 48 h / 7 days (`deploy()` reverts otherwise). For testnet, `SAFE` can be a plain wallet the operator controls so timelock proposals can be scripted; `AIRDROP_ROOT` and `CTO_RULES` can be placeholders. Writes `deployments/46630.json` (commit it).
4. **Keeper:** `DEPLOYMENT=../contracts/deployments/46630.json RPC_URL=https://rpc.testnet.chain.robinhood.com node keeper.mjs`.
5. **Trader bots** (`bots/`, D-63): `MASTER_KEY=<testnet key> node bots.mjs roles` prints `SAFE`, `RELAY`, `X_LINK_KEY`, `TWEET_CHECKER` (wallets derived from the testnet key, so Claude can script timelock proposals and later the testnet X link service and tweet checker); `node bots.mjs fund` mints 20k tIMD + 50k tUSDG to each bot and tops up 0.1 ETH; `node bots.mjs run` trades in rounds. Profiles: launcher, retail, flipper, whale (pushes coins to the Leap), sale buyer, staker, ETH user, USDG user; mostly coins past their max-buy window, sometimes fresh ones. Every action is simulated first; reverts from normal limits (max-buy, sale not started, slippage, …) are counted as expected, anything else is reported. After each round: curve IMD ≥ IMD raised by trading coins and curve tokens + sold = 1B (I1), coin supply ≤ 1B, curve quote = trade output (I4), router holds no IMD / USDG / ETH (I9), sale solvent and ≤ 600M sold, ≤ 15M per bot (I10), sPONDPAD value per share never falls (I13). Log: `bots/runs/*.jsonl` (not committed). Rehearsed on an anvil fork of the testnet: 16 bots, 12 rounds, a coin's curve filled past 2,000 IMD, 0 unexpected reverts, 0 violations.
6. **Testnet wallet (Claude runs it, user's go-ahead 5 Oct 2026):** `0x4b91078b2374c956A65F7Af0999CaE0a935E6821`, testnet only. The key is not in the repo; the user keeps it as the environment variable `PONDPAD_TESTNET_KEY` so later sessions can use it. The user sent 7 ETH (received 5 Oct 2026). Plan: `IMD_POOL_ETH` 2 ETH, `USDG_POOL_ETH` 0.5 ETH, 24 bots × 0.1 ETH, the rest kept for gas and top-ups; `SALE_START` = deploy + 2 h.
7. **Test suites** (all in `bots/`, all `MASTER_KEY=… node <file>`; results in `bots/runs/`, read by `report.mjs`):
   - `pool4.mjs`: the $PONDPAD market's POOL4 mechanics (fee schedule, ratchet limit, trim 85/15, claim settlement, burn, backstop deploy / fill / settle, keeper tip, fee collection, outsider guards). Needs the market open; gathers $PONDPAD from the sale-crowd wallets to sell above the cap.
   - `attacks.mjs coins|sale|market|market-m4|all`: attacker wallet against the coin core, sale, owner powers and the market (run `market-m4` with the bots stopped: it needs the inventory to sit at the cap).
   - `staking.mjs`: flash stake, hold through transfers, drip sniping, donation, owner calls, reward flow.
   - `airdrop.mjs`: deploys a test-only `AirdropDistributor` with a real 104-wallet Merkle list and runs initiation (99 → nothing, 100th activates), vesting, claim wallet by signature and every attack.
   - `report.mjs`: full report + health table from the logs and onchain state at one block.
   Hook gas depends on pending work: every script sends with 50% gas headroom (the keeper too).
8. **Run of 5 Oct 2026: healthy, no contract bug** (`bots/reports/2026-10-05/REPORT.md`): 110 rounds, 2,693 transactions, 167 coins (45 graduated), the sale filled in ~24 min and opened the market, 36 min of market trading; every invariant held in 111 snapshots; POOL4 12/12; 46/46 attacks refused or bounded. Findings: `block.number` is Ethereum's block on Robinhood (all "one block" rules = ~12 s; kept on purpose and noted in the THREAT-MODEL, D-65); market swaps and keeper calls need ~50% gas headroom (keeper fixed; frontend must too); the thin testnet ETH route drifted 411 → 1,820 IMD/ETH (confirms D-32); the sale needs ≥ 40 buyers (D-35); trims start only above the opening inventory (cap falls ≤ 500k/day, D-21). Leftover: two test-only airdrop distributors (`0xD184…48Bb` and one from a failed first attempt) hold ~7.4M testnet $PONDPAD until their 180-day sweep.
9. **Keeper restarted 6 Oct 2026** (user's go-ahead) from a wallet derived from the testnet key (`pondpad-testnet:keeper-ui` → `0x5eE6…bc4F`, 0.01 ETH), every 2 min, so the stakers' IMD waiting at PadBuyer (~1,520 IMD) is bought in 25-IMD chunks and dripped into the Pond. A small market trade first refreshed the market's reference tick: PadBuyer refuses to buy (`PriceOutOfRange`) while $PONDPAD is > 1% above it, and the reference only moves on swaps. Finding: on the thin testnet market a 25-IMD PadBuyer chunk moves $PONDPAD ~1.06%, just past its 1% guard, and the reference tick only moves on the *next* swap, so with no other trading PadBuyer blocks itself after every chunk (`PriceOutOfRange`). A testnet-only helper in the session scratchpad makes a 0.01-IMD swap when that happens. **Testnet settings changed (D-75):** PadBuyer 100 IMD every 60 s with a ~5% guard, drip smoothing 1 day (mainnet defaults unchanged); the keeper now runs every 60 s and follows PadBuyer's own interval. It runs from the session container and stops with it (background jobs there also stop after 2 hours). **Next (not built):** later AI adversarial agents. Bots are stopped; restart with steps 4–5 if needed. The testnet can't show the 7-day fee decay, vesting, the 180-day sweep or the 12-month expiries quickly; the fork tests cover those.

Audit note: round 1 was regenerated on 6 Oct 2026 at `d5991b7` (D-76 launch settings in `Deploy.s.sol`; 36 files, 8,896 lines; IMD's free check: 5 steps per job, no blockers). Repository address for the Audit form: `https://github.com/khaed1/claude/tree/d5991b7f3d44f76a0f5949ef8ede378c2fd8b187`. Regenerate if anything in scope changes before you submit. The user chose to delay the audit for now (5 Oct 2026).

## 5c. Design (D-66)

Everything in `launchpad/design/` (index: `design/README.md`). Published for review: mood board https://claude.ai/artifact/NRkqRuNW7edMkJnt8zGsVL, design system https://claude.ai/artifact/B4narVLex3zGLPzLa5zbmi (private until the user shares them).

- **Look:** "a pond at night, lit by fireflies". Night theme by default, day theme for light-mode devices. Water surfaces; lily green = brand and buys, firefly gold = the Leap and $PONDPAD, lotus pink = the Chorus and X verified, coral = sells. Lilita One (display), Nunito (text), Martian Mono (data), self-hosted. Lily pad mark; mascot Pip for moments only.
- **Pages** (`design/system/Pages.md`): Explore (About to Leap spotlight, tabs, filters), Coin (trade box with fee and route always visible, Trades / Holders / Creator / Chorus / About), Spawn (one page, four steps), $PONDPAD (sale → market → airdrop), the Pond, Profile (holdings, created coins with a creator-fee claim section, rewards, activity), Transparency, Docs inside the site.
- **Frontend stylesheet:** `design/tokens.css` + `design/fonts/fonts.css` + `design/system/components/bundle.css` (`pp-` classes). Regenerate with `build_tokens.py` (fails on low contrast) and `build_previews.py`.
- **Review bar:** the impeccable.style checklist (the user's suggestion). The plugin itself isn't installed in this sandbox; the user can add it in their own Claude Code with `/plugin marketplace add pbakaus/impeccable`.

## 6. Keepers (who calls the permissionless functions)

Every upkeep function is permissionless: anyone can call it, nothing depends on one operator. Many also run by themselves during normal trading. **Built:** `keeper/keeper.mjs` (Node + viem, a hot wallet with a little ETH): checks a view, simulates, sends only what would succeed; cadences and conditions in `keeper/README.md`. No AI agent is needed for this part.

| Call | When | Runs by itself? | Pays the caller |
|---|---|---|---|
| `PadBuyer.buy()` | every 10 min while it holds ≥ 1 IMD | no | 0.5% of the IMD spent |
| `RewardDripper.drip()` | hourly (`canDrip()`) | no | 10 $PONDPAD |
| `PadMarketHook.rebalance()` | when `pendingRebalance()` | no | up to 1 IMD |
| `PadMarketHook.settleClaims()` | after trims | yes, on the next swap in a later block | – |
| `PadBurner.burn()` | after claims settle | no | – |
| `MarketController.collectFees()` | daily | no | – (also runs `FeeSplitter.distribute` / `distributeToken`) |
| `FeeSplitter.distribute()` | daily | no | – |
| `PadHook.flush(coin)` | for trades through outside routers | yes for `PadRouter` trades | – |
| `BondingCurve.graduate(coin)` | only if the completing buy couldn't graduate | yes, normally inline | – |
| `PadSale.graduate()` | same, once | yes, normally inline | – |
| `WorkerFund.release()` | weekly, once the worker rewards address is set | no | – |
| `CTOModule.execute(coin)` | when a takeover's notice has passed (3-day window) | no | – |
| `CreatorVault.claim(coin)` + `SwarmBudget.sweepToHolders(coin)` | weekly, for coins whose fees go to holders | no | – |
| `TeamVesting.release()` | monthly from day 30 after market open (always pays the team Safe) | no | – |
| `AirdropDistributor.sweep()` | once, 180 days after activation (`claimDeadline()`) | no | – |

## 6b. Discussed, not decided (5 Oct 2026)

Nothing below is built. Each needs the user's go-ahead.

- **Audit submission:** the user submits the four jobs in `audit/rounds/<n>/` through the explorer's web form (explorer.imd.fun/launch → Audit). Repository address: `https://github.com/khaed1/claude/tree/<full commit>`. Description: the area's `<ID>.objective.txt`. Then Check (free), then Pay, 0.5 IMD each. The user shares the job links; each report is at `api.imd.fun/jobs/<id>/report.md`.
- **Mainnet deploy: by the user with `Deploy.s.sol`, not through the swarm.**
  - A swarm token launch gives 10% of the token to the swarm and opens its own 1.25% pool, which breaks the supply split and PadSale's path to the market.
  - The swarm's contracts-only launch (`evm_contracts`) allows 1 to 8 contracts, simple constructor arguments and no calls after deployment. Our deploy is ~40 contracts in 48 transactions, with mined hook addresses and setup calls.
  - ~~Swarm deploys run only on Sepolia today.~~ Since 6 Oct 2026 the swarm launches on **Ethereum mainnet and Robinhood (4663)** too (`/requests/capabilities`: all four kinds incl. `evm_contracts`; IMD and ETH pairings on 4663). Payment is still IMD on Ethereum mainnet only (`eip155:1`, 0.5 IMD per action). `evm_contracts` is still 1–8 contracts with static constructor arguments, so the two reasons above still hold.
  - The swarm's role stays auditing, oracle-checked version activation and coin websites.
- **Multi-chain (later; Base first):**
  - The contracts take every chain-specific address at deploy; only `Deploy.s.sol` hard-codes Robinhood. Each chain needs Uniswap v4, IMD with liquidity (Ethereum and Base have it; other chains need the IMD dev to bridge it), the IMD oracle signing for that chain, and its own Safe and timelocks.
  - $PONDPAD, staking and the burn market stay on Robinhood. A new bridge contract sends the stakers' IMD share (and maybe the workers' and growth shares) back over IMD's LayerZero bridge.
  - Ethereum mainnet is too expensive for curve trading.
  - ROADMAP still lists Base and Ethereum under "Later" until the user decides.
- **Can start before the audit ends:** frontend, indexer, X link service, tweet checker and Swarm Relay. They don't change contracts; an audit fix may need small frontend updates.
- **Robinhood testnet run:** *go-ahead given and steps 1–2 built (D-62, §5b); the text below is the original proposal.*
  - Testnet: chain 46630, RPC `https://rpc.testnet.chain.robinhood.com`, explorer `explorer.testnet.chain.robinhood.com`, gas ~0.05 gwei. Already there: the v4 PoolManager (same address as mainnet), the CREATE2 factory, Permit2, Multicall3 and the Safe contracts. Not there: IMD, USDG and their pools.
  - Plan:
    1. `script/TestnetSetup.s.sol`: deploy test IMD and test USDG with public faucets, then create and fill the IMD/ETH pool (~411 IMD per ETH) and an ETH/USDG pool.
    2. A small `Deploy.s.sol` change to read the PoolManager, IMD and USDG addresses and the timelock delays from settings (mainnet unchanged).
    3. Scripted trader bots: many funded wallets with different behaviours, checking the invariants after each round.
    4. The frontend, built against the testnet.
    5. Later, AI adversarial agents with their own testnet wallets.
  - Testnet ETH: Sepolia faucets, then the Arbitrum bridge in testnet mode (Sepolia → Robinhood Chain Testnet). About 2–3 ETH covers the pool and the bots; the deploy itself is ~0.004 ETH.
  - Things the testnet can't show quickly (7-day fee decay, vesting, 180-day sweep, 12-month expiries) stay covered by the fork tests.
  - Open questions for the user:
    1. ~~Go-ahead for the testnet setup.~~ Given (5 Oct 2026).
    2. ~~Testnet timelocks at 10 and 30 minutes?~~ Used as the defaults (D-62); `FAST_DELAY` / `SLOW_DELAY` change them.
    3. ~~Who broadcasts?~~ Claude, with a testnet-only wallet it created (§5b step 6); the user funds it with 7 ETH.
- **$PONDPAD page (D-72), open for mainnet:** (1) which router trades the $PONDPAD market. *Decided 6 Oct 2026 (D-77): Uniswap's Universal Router (see §4), built and tested on the testnet. POOL4 on Ethereum has no router of its own: its site trades through Uniswap's Universal Router (`0x66a9…a8af`, with Permit2 and the v4 Quoter), and on 6 Oct 2026 the latest ~5,000 Ethereum blocks showed 1,042 swaps in its pool from many callers (Uniswap routers, aggregator adapters, bots).* (Before D-77 the testnet page used Uniswap's v4 test swap router, IMD only with no minimum-out; the other option was a market route in `PadRouter`, a contract change.) (2) The claims file for the real list (`frontend/public/airdrop-4663.json` from `snapshot.py build`'s `claims.json` + the distributor address); if the list is large, split it by address prefix. (3) The tweet checker (`POST /voucher`) for the wake step.
- **PadBuyer chunk vs. price guard (testnet finding, 6 Oct 2026, not decided):** a chunk only buys if $PONDPAD is within `maxDeviationTicks` (100 ≈ 1%) of the market's reference tick, which updates on swaps. If one chunk moves the price more than that, PadBuyer can't buy again until someone else trades. At the opening depth (~8,460 IMD) a 25-IMD chunk moves the price ~0.6%, so mainnet is fine while trading is normal; if the pool's IMD falls below ~5,000 or trading goes quiet, buys slow down (they never lose money, they just wait). If it happens: lower `maxChunk` or raise `maxDeviationTicks` through the 48 h timelock (bounds 500 IMD / 500 ticks; no code change), or let the keeper make a dust swap first.
- **Future versions (D-71):** v2 mechanics menu starting with POOL4-style burn per coin, custom hooks after that behind swarm audits; holder rewards in other tokens (stocks, gold) at v3+ or on demand; no delegate.xyz rule for the airdrop.
- **Decided 5 Oct 2026 (D-70):** Pond wording "a few seconds after joining" (the hold stays in code: it stops flash-loan reward capture); no coin page comments in v1; keep the Egg stage.
- **Timelocks need no activating:** `Deploy.s.sol` creates both and hands them ownership in the same run. A change is `schedule` by the Safe, then the delay, then anyone calls `execute`. A small helper that turns a setting change into a ready Safe transaction was offered, not built.

## 7. Open items waiting on someone

| Item | Waiting on |
|---|---|
| Worker rewards address | IMD dev |
| Oracle attestations for consumer chain 4663 (requests name `consumer: {chainId: 4663, verifyingContract: AttestationVerifier}`), the signer address to approve (the live attester is `0x5598aa91…2982`), and confirmation that `questionHash` stays the canonical JSON of the request (D-49) | IMD dev |
| CTO rules: review the draft in `CTO-RULES.md`, then freeze and pin it to IPFS; its `ipfs://` link goes into `CTOModule` at deploy and can never change (D-51) | User |
| Swarm job payments on Robinhood (launches on 4663 are live since 6 Oct 2026; payments are still Ethereum-only per `/requests/capabilities`) | IMD dev |
| POOL4 GitHub repo with tests | IMD dev (said "next week") |
| Official POOL4 IMD/ETH market on Robinhood | IMD dev (planned, not guaranteed) |
| Deepen IMD liquidity on Robinhood before the $PONDPAD sale | User + IMD dev / holders |
| Buy pondpad.fun, X and Telegram handles | User |
| Airdrop snapshot (D-56): rules decided and the tool is built (`airdrop/`, see its README). To do: pick the moment and run `capture` secretly, then `build`, review `review.csv` (exchange hot wallets, team wallets, contract wallets that want a Robinhood address), announce, root into the deploy | User |
| Testnet: save the testnet wallet's key as the environment variable `PONDPAD_TESTNET_KEY`, so later sessions can restart the bots and keeper (§5b). In the environment settings the line must be `PONDPAD_TESTNET_KEY=0x…` (one `NAME=value` line). On 5 Oct 2026 the user gave the key in the session instead; it was kept in the session's scratchpad only, never in the repo | User |
| Legal: have counsel review `legal/TERMS.md` and `legal/PRIVACY.md` and fill the operator name, governing law, restricted jurisdictions and contact before mainnet (D-69) | User |
| Swarm audit round 1 (D-61): submit `audit/rounds/1/A1`–`A4` at explorer.imd.fun/launch → Audit (2 IMD on Ethereum mainnet), then share the four job links | User |
| Airdrop tweet checker (D-55): service that reads the initiation post (X API or link fetch), checks the phrase and `initiationCode`, signs the voucher; its key goes into `AirdropDistributor` at deploy | Us (backend) |
