# PondPad: roadmap

What is left in v1, then everything discussed for later versions. Details of the v1 design are in [`ARCHITECTURE-v1.md`](ARCHITECTURE-v1.md); decisions are in [`DECISIONS.md`](DECISIONS.md).

## 1. v1: remaining work

Built so far: coin token, bonding curve, v4 hook, router (IMD / ETH / USDG), factory, config, fee splitter, creator vault, swarm budget, integrator vault, $PONDPAD token and sale, $PONDPAD market (POOL4 fork) and its controller, staking, worker and growth funds, oracle attestation verifier, CTO module, version registry, social registry, lens, airdrop and team vesting, with local and Robinhood fork tests. See `HANDOFF.md` §2.

| # | Item | Notes |
|---|---|---|
| 1 | ~~Integrator fee share~~ | **Done** (D-31, D-33): 15% of the protocol fee to registered integrators via `IntegratorVault` |
| 2 | ~~`PadSale` ($PONDPAD sale)~~ | **Done** (D-35 to D-37): IMD curve, S = 600M, R = 300M, target ≈ 8,460 IMD, all payment tokens, 80% → 0 snipe tax over 30 min, 15M per-wallet cap, hands the raise to the market launcher at graduation. `PondPadToken` done too |
| 3 | ~~`PadMarketHook` + `MarketController` + `PadBurner`~~ | **Done** (D-34, D-38, D-39): POOL4 `CappedBurnHook` fork for $PONDPAD/IMD with dynamic fee 3% → 1% over 7 days; floor 150M, decay 500k/day, 15% of trims to stakers; no pool-withdrawal power; migrate-only emergency exit for 12 months (D-40); sell-side $PONDPAD fees split 40/25/20/15 |
| 4 | ~~`StakedPONDPAD` + `RewardDripper` + `PadBuyer`~~ **Done** (D-42, D-43) | Forks of `StakedIMD` / `RewardDripper` with asset $PONDPAD; `PadBuyer` turns stakers' IMD into $PONDPAD in small, price-guarded chunks **and forwards the $PONDPAD fee share it receives (D-38)** |
| 5 | ~~`AirdropDistributor`, `TeamVesting`~~ | **Done** (D-53 to D-55): 5% Merkle airdrop, activated after market open by 100 listed wallets posting a coded tweet, then 30-day vesting, gasless claim wallet, unclaimed to stakers after 180 days; 2% team vesting, 1-month cliff, linear to month 6. **Before deploy:** the airdrop snapshot rules (which seats / sIMD, weights, snapshot block) and the Merkle root |
| 6 | ~~`WorkerFund`, `GrowthFund`~~ | **Done** (D-45, D-47): WorkerFund forwards IMD and $PONDPAD to the worker rewards address once the IMD dev gives it; GrowthFund pays relay jobs (100 IMD/week) and Safe grants (1,000 IMD + 10M $PONDPAD/week) |
| 7 | ~~`AttestationVerifier`, `VersionRegistry`~~ | **Done** (D-46, D-48, D-49, D-50): IMD oracle v2 attestations (panel ≥ 51, 2/3 agreement, exact question rebuilt onchain); version activation by audit attestation, timelock fallback until retired. Needs from the IMD dev: the signer on Robinhood and support for consumer chain 4663 |
| 8 | ~~`CTOModule`~~ | **Done** (D-46, D-50 to D-52): X-verified proposer + oracle "yes" (or council fallback, 7-day notice, until retired) → 3-day notice (contest: +7 days and a ≥ 75 panel) → 3-day window; new recipient a multisig or the holders. **Before launch:** finalize `CTO-RULES.md`, pin it to IPFS, deploy with that link |
| 9 | ~~`SocialRegistry`~~ | **Done** (D-50): voucher-signed handle links, duplicates flagged. The X link service that signs vouchers is backend work (item 15) |
| 10 | ~~`PadLens`~~ | **Done** (D-50): coin lists, coin state, exact curve and pool quotes in IMD, wallet positions. ETH/USDG legs quoted with the v4 Quoter |
| 11 | Governance wiring | OpenZeppelin `TimelockController` (48 h / 7 days) owned by a Safe; guardian for launch pause |
| 12 | Deploy scripts | CREATE2 salt mining for both hooks and for $PONDPAD's address (> IMD); full deployment rehearsal on a Robinhood fork |
| 13 | Audit loop | Swarm audit (4 auditors + judge) until clean; swarm fuzz campaigns; human audit before large TVL; bug bounty |
| 14 | Frontend | Pages in `ARCHITECTURE-v1.md` §9; copy in `SITE-COPY.md`; trade box on the coin page (no separate swap page in v1) |
| 15 | Backend | Indexer (incl. outside-pool volume tracking), Swarm Relay (site jobs with output scan), keeper bot, token auto-verifier, X link service, airdrop tweet checker (D-55), launch/graduation bots |
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
