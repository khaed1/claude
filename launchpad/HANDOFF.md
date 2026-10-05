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

Last updated: 4 October 2026. Branch: `claude/bold-gauss-qhlw86` on `khaed1/claude`.

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
- `Fork.t.sol`: **5 fork tests** on live Robinhood Chain (real PoolManager, IMD, IMD/ETH and ETH/USDG pools): full lifecycle with ETH, USDG on the curve and after graduation, the $PONDPAD sale with ETH and USDG, the sale graduating into the market (cancun build, dynamic fee) with a buy and a trimmed sell, and an IMD depth report.

### Not built yet
See `ROADMAP.md` section 1. In short: timelock/Safe wiring, deploy scripts, frontend, Swarm Relay, indexer, X link service, keeper bot.

---

## 3. How to resume (environment)

```bash
cd launchpad/contracts
git submodule update --init --recursive        # forge-std v1.9.7, solady v0.1.9, v4-core @ 46c6834 (+ its solmate, openzeppelin)
forge build
forge test --no-match-contract Fork            # 90 local tests
FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork -vv   # 5 fork tests
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
7. Timelock + Safe wiring, deploy scripts (hook address mining for `PadHook` and `PadMarketHook`, $PONDPAD address above IMD's), fork rehearsal of a full deployment.
8. Swarm audit loop, then frontend, Swarm Relay, indexer, X link service.

## 6. Keepers (who calls the permissionless functions)

Every upkeep function is permissionless: anyone can call it, nothing depends on one operator. Many also run by themselves during normal trading. A plain script on a timer (cron + `cast` or viem, a hot wallet with a little ETH for gas) is enough; no AI agent is needed for this part. Not built yet (ROADMAP §1 item 15, "keeper bot").

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

## 7. Open items waiting on someone

| Item | Waiting on |
|---|---|
| Worker rewards address | IMD dev |
| Oracle attestations for consumer chain 4663 (requests name `consumer: {chainId: 4663, verifyingContract: AttestationVerifier}`), the signer address to approve (the live attester is `0x5598aa91…2982`), and confirmation that `questionHash` stays the canonical JSON of the request (D-49) | IMD dev |
| CTO rules: review the draft in `CTO-RULES.md`, then freeze and pin it to IPFS; its `ipfs://` link goes into `CTOModule` at deploy and can never change (D-51) | User |
| Swarm job payments on Robinhood | IMD dev (said "coming days") |
| POOL4 GitHub repo with tests | IMD dev (said "next week") |
| Official POOL4 IMD/ETH market on Robinhood | IMD dev (planned, not guaranteed) |
| Deepen IMD liquidity on Robinhood before the $PONDPAD sale | User + IMD dev / holders |
| Buy pondpad.fun, X and Telegram handles | User |
| Airdrop snapshot (D-56): rules decided and the tool is built (`airdrop/`, see its README). To do: pick the moment and run `capture` secretly, then `build`, review `review.csv` (exchange hot wallets, team wallets, contract wallets that want a Robinhood address), announce, root into the deploy | User |
| IMD on Base: both IMD OFTs name `0xab15…690a` as their Base peer, but it is an adapter for a "Fren Pet" token. Which contract is IMD on Base? (Base balances aren't counted until then) | IMD dev |
| Airdrop tweet checker (D-55): service that reads the initiation post (X API or link fetch), checks the phrase and `initiationCode`, signs the voucher; its key goes into `AirdropDistributor` at deploy | Us (backend) |
