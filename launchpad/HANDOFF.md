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
| [`PLAN.md`](PLAN.md) | First plan, superseded; kept for the Pons / Pepes competitor analysis |
| [`contracts/`](contracts/) | Foundry project (Solidity) |

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
| `SwarmBudget` | Per-coin escrow for swarm jobs, released by the Swarm Relay | Done |
| `IntegratorVault` | Integrator (app/bot) earnings: 15% of the protocol fee on trades they route (coins and the $PONDPAD sale), claimable in IMD | Done |
| `PondPadToken` | $PONDPAD: 1B fixed supply, no owner, permit, `burn`; deployed at an address above IMD's | Done |
| `PadSale` | $PONDPAD IMD curve (600M sold / 300M to pool, target ≈ 8,460 IMD), pays/receives IMD, ETH or any payment token, 1% fee (integrator share off the top), 80% → 0 snipe tax over 30 min, 15M per-wallet cap, hands raise + 300M to `MarketController.launch` at graduation | Done |
| `PaymentSwapper` | Shared payment plumbing (routes to/from IMD in one unlock) used by `PadRouter` and `PadSale` | Done |
| `PadMarketHook` | $PONDPAD/IMD market: POOL4 `CappedBurnHook` fork (IMD quote as currency0, dynamic fee 3% → 1% over 7 days via `beforeSwap`, IMD-sized constants). Cap floor 150M, decay 500k/day, 15% of trims to stakers. Original source in `contracts/upstream/CappedBurnHook.sol` | Done |
| `MarketController` | Permanent owner of the market hook: opens it once from `PadSale`, permissionless `collectFees` (both fee tokens split 40/25/20/15), policy via 48 h timelock, sinks via 7-day timelock; the only exit is `migrate` into a new hook (7-day timelock, first 12 months, D-40), never to a wallet | Done |
| `PadBurner` | Burn sink: burns all $PONDPAD it holds, permissionless | Done |
| `FeeLib`, `Route` | Shared fee math and the `Hop` struct | Done |

### Tests (`contracts/test/`)
- `PondPad.t.sol` + `Base.t.sol`: **31 local tests** (54 local in total with `PadSale.t.sol` and `Market.t.sol`) against a real v4 PoolManager with mock IMD and USDG and local IMD/ETH and ETH/USDG pools. Covers launch, fee splits, snipe tax, max-buy, dev buy, dividends, swarm budget, graduation in both currency orderings, locked liquidity, third-party router fees, the exact `PartialFill` revert, ETH and USDG paths before and after graduation, payment-route validation, integrator share (curve, pool, unregistered, spoofing through other routers, bounds), a 512-run solvency fuzz.
- `PadSale.t.sol`: **11 local tests** for the $PONDPAD sale: setup and start price, bad setup, closed before start / until funded, snipe tax decay to growth, fee and integrator share, whole-sale wallet cap (sells don't free it), sell round trip, ETH and USDG round trips, graduation at the curve's final price (sqrt price checked), completing-buy refund, solvency fuzz.
- `Market.t.sol`: **12 local tests** for the $PONDPAD market: opens at the sale's final price when the sale graduates, fee 3% → 2% → 1% (both fee currencies), trims above the cap burned and 15% shared, ratchet no faster than 500k/day, fee split 40/25/20/15 in IMD and $PONDPAD, controller power limits, outsiders can't initialize or add liquidity, keeper rebalance deploys the backstop, cap-invariant fuzz at 3% and at 1%, migration into a new hook (same price, inventory, backstop IMD, fee clock and policy; guards; 12-month expiry), fee clock can only move earlier.
- `Fork.t.sol`: **5 fork tests** on live Robinhood Chain (real PoolManager, IMD, IMD/ETH and ETH/USDG pools): full lifecycle with ETH, USDG on the curve and after graduation, the $PONDPAD sale with ETH and USDG, the sale graduating into the market (cancun build, dynamic fee) with a buy and a trimmed sell, and an IMD depth report.

### Not built yet
See `ROADMAP.md` section 1. In short: staking (`StakedPONDPAD`, `RewardDripper`, `PadBuyer`), `WorkerFund`, `GrowthFund`, `VersionRegistry`, `AttestationVerifier`, `CTOModule`, `SocialRegistry`, `PadLens`, timelock wiring, deploy scripts, frontend, Swarm Relay, indexer.

---

## 3. How to resume (environment)

```bash
cd launchpad/contracts
git submodule update --init --recursive        # forge-std v1.9.7, solady v0.1.9, v4-core @ 46c6834 (+ its solmate, openzeppelin)
forge build
forge test --no-match-contract Fork            # 54 local tests
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
- Under via-IR, `block.timestamp` read after `vm.warp` in the same test can be stale. Save `t0` and warp to absolute times.
- The PoolManager holds every pool's tokens; measure balance deltas, not totals.
- Uniswap test helpers refund spare ETH to the test contract, so the test base has `receive()`.
- Some Robinhood RPCs cap log queries at 10M blocks per request.

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
4. **Staking**: `StakedPONDPAD` + `RewardDripper` (forks of POOL4's `StakedIMD` / `RewardDripper`, asset $PONDPAD; sources at the addresses in §4) and `PadBuyer` (buys $PONDPAD with the stakers' IMD in the `PadMarketHook` pool, and forwards the $PONDPAD fee share it receives from the splitter, D-38). The market hook's `rewardsRecipient` becomes the `RewardDripper` (set at deploy).
5. `WorkerFund`, `GrowthFund` (both also receive $PONDPAD from market fees, D-38), `AttestationVerifier`, `VersionRegistry`, `CTOModule`, `SocialRegistry`, `PadLens`.
6. Timelock + Safe wiring, deploy scripts (hook address mining), fork rehearsal of a full deployment.
7. Swarm audit loop, then frontend, Swarm Relay, indexer, X link service.

## 6. Open items waiting on someone

| Item | Waiting on |
|---|---|
| Worker rewards address | IMD dev |
| Oracle attestations on chain 4663, signer set | IMD dev |
| Swarm job payments on Robinhood | IMD dev (said "coming days") |
| POOL4 GitHub repo with tests | IMD dev (said "next week") |
| Official POOL4 IMD/ETH market on Robinhood | IMD dev (planned, not guaranteed) |
| Deepen IMD liquidity on Robinhood before the $PONDPAD sale | User + IMD dev / holders |
| Buy pondpad.fun, X and Telegram handles | User |
