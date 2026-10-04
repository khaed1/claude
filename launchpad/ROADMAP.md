# PondPad: roadmap

What is left in v1, then everything discussed for later versions. Details of the v1 design are in [`ARCHITECTURE-v1.md`](ARCHITECTURE-v1.md); decisions are in [`DECISIONS.md`](DECISIONS.md).

## 1. v1: remaining work

Built so far: coin token, bonding curve, v4 hook, router (IMD / ETH / USDG), factory, config, fee splitter, creator vault, swarm budget, integrator vault, $PONDPAD token and sale, $PONDPAD market (POOL4 fork) and its controller, with local and Robinhood fork tests. See `HANDOFF.md` §2.

| # | Item | Notes |
|---|---|---|
| 1 | ~~Integrator fee share~~ | **Done** (D-31, D-33): 15% of the protocol fee to registered integrators via `IntegratorVault` |
| 2 | ~~`PadSale` ($PONDPAD sale)~~ | **Done** (D-35 to D-37): IMD curve, S = 600M, R = 300M, target ≈ 8,460 IMD, all payment tokens, 80% → 0 snipe tax over 30 min, 15M per-wallet cap, hands the raise to the market launcher at graduation. `PondPadToken` done too |
| 3 | ~~`PadMarketHook` + `MarketController` + `PadBurner`~~ | **Done** (D-34, D-38, D-39): POOL4 `CappedBurnHook` fork for $PONDPAD/IMD with dynamic fee 3% → 1% over 7 days; floor 150M, decay 500k/day, 15% of trims to stakers; no pool-withdrawal power; migrate-only emergency exit for 12 months (D-40); sell-side $PONDPAD fees split 40/25/20/15 |
| 4 | ~~`StakedPONDPAD` + `RewardDripper` + `PadBuyer`~~ **Done** (D-42, D-43) | Forks of `StakedIMD` / `RewardDripper` with asset $PONDPAD; `PadBuyer` turns stakers' IMD into $PONDPAD in small, price-guarded chunks **and forwards the $PONDPAD fee share it receives (D-38)** |
| 5 | `AirdropDistributor`, `TeamVesting` | 5% Merkle airdrop to IMD seats + sIMD; 2% team vesting |
| 6 | `WorkerFund`, `GrowthFund` | Worker rewards address from the IMD dev; growth pays graduation websites, oracle costs, capped grants. Both must also handle the $PONDPAD share of market fees (D-38) |
| 7 | `AttestationVerifier`, `VersionRegistry` | IMD oracle EIP-712 attestations; version activation needs a swarm audit attestation |
| 8 | `CTOModule` | Swarm-approved takeover → 3-day notice → 3-day execution window |
| 9 | `SocialRegistry` | X badge level 1 (OAuth + wallet signature voucher) |
| 10 | `PadLens` | Read-only quotes and lists for the frontend |
| 11 | Governance wiring | OpenZeppelin `TimelockController` (48 h / 7 days) owned by a Safe; guardian for launch pause |
| 12 | Deploy scripts | CREATE2 salt mining for both hooks and for $PONDPAD's address (> IMD); full deployment rehearsal on a Robinhood fork |
| 13 | Audit loop | Swarm audit (4 auditors + judge) until clean; swarm fuzz campaigns; human audit before large TVL; bug bounty |
| 14 | Frontend | Pages in `ARCHITECTURE-v1.md` §9; copy in `SITE-COPY.md`; trade box on the coin page (no separate swap page in v1) |
| 15 | Backend | Indexer (incl. outside-pool volume tracking), Swarm Relay (site jobs with output scan), keeper bot, token auto-verifier, X link service, launch/graduation bots |
| 16 | Pre-launch | Buy pondpad.fun + handles; deepen IMD liquidity on Robinhood; $PONDPAD sale over days |

## 2. v1.1

- **Swap page**: coin → coin through IMD in one transaction, plus ETH / USDG / IMD ↔ any coin.
- **Trade to earn sPONDPAD**: weekly rewards paid as locked sPONDPAD, funded from the growth bucket, always below the protocol fee the trader paid (no profitable wash trading), filters for round trips and creator wallets, payout checked by a swarm oracle panel.
- **Referral tiers and dashboards** for integrators; open referral links for individuals (needs a design that prevents self-referral discounts).
- **Milestone bounties** for creators (holders / market-cap milestones, not volume).
- **Scam / impersonation flags** by swarm oracle (UI warning and no growth perks; never blocks trading).
- **Daily swarm health report** (solvency, fee flows, suspicious launches).
- **X badge level 2**: swarm-verified tweet.
- More **payment tokens** (other stablecoins, stock tokens) via the timelock.

## 3. v2

- **Custom coins** built by the swarm, accepted only with a bytecode-hash audit attestation.
- **Swarm review** published for every timelocked settings change.
- **POOL4-style burn mode per coin** (needs IMD-quoted, one-sided POOL4 variant).
- **Boosted / locked sPONDPAD tiers**.
- **Outside LPs into our pools** (earn an LP fee in the canonical pool instead of opening rival pools).
- Optional lower post-graduation fee schedules if outside-pool leakage grows (the user prefers leaving fees to creators; revisit only with data).

## 4. Later

- **Dead-coin migration** (Pons-style epochs, vesting claims, refunds).
- **Base and Ethereum** deployments (IMD exists on both; same contracts, deterministic addresses).
- Switch the ETH route to an **official POOL4 IMD/ETH market** on Robinhood when it exists.
