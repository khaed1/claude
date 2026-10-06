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
| 5 | ~~`AirdropDistributor`, `TeamVesting`~~ | **Done** (D-53 to D-55): 5% Merkle airdrop, activated after market open by 100 listed wallets posting a coded tweet, then 30-day vesting, gasless claim wallet, unclaimed to stakers after 180 days; 2% team vesting, 1-month cliff, linear to month 6. Snapshot tool built (`airdrop/`, D-56). **Before deploy:** run the secret capture, build and review the list, announce, put the root in the deploy; confirm IMD's Base address |
| 6 | ~~`WorkerFund`, `GrowthFund`~~ | **Done** (D-45, D-47): WorkerFund forwards IMD and $PONDPAD to the worker rewards address once the IMD dev gives it; GrowthFund pays relay jobs (100 IMD/week) and Safe grants (1,000 IMD + 10M $PONDPAD/week) |
| 7 | ~~`AttestationVerifier`, `VersionRegistry`~~ | **Done** (D-46, D-48, D-49, D-50): IMD oracle v2 attestations (panel ≥ 51, 2/3 agreement, exact question rebuilt onchain); version activation by audit attestation, timelock fallback until retired. Needs from the IMD dev: the signer on Robinhood and support for consumer chain 4663 |
| 8 | ~~`CTOModule`~~ | **Done** (D-46, D-50 to D-52): X-verified proposer + oracle "yes" (or council fallback, 7-day notice, until retired) → 3-day notice (contest: +7 days and a ≥ 75 panel) → 3-day window; new recipient a multisig or the holders. **Before launch:** finalize `CTO-RULES.md`, pin it to IPFS, deploy with that link |
| 9 | ~~`SocialRegistry`~~ | **Done** (D-50): voucher-signed handle links, duplicates flagged. The X link service that signs vouchers is backend work (item 15) |
| 10 | ~~`PadLens`~~ | **Done** (D-50): coin lists, coin state, exact curve and pool quotes in IMD, wallet positions. ETH/USDG legs quoted with the v4 Quoter |
| 11 | ~~Governance wiring~~ | **Done** (D-57): OpenZeppelin `TimelockController` 48 h and 7 days, Safe proposes, anyone executes, no admin; guardian = Safe |
| 12 | ~~Deploy scripts~~ | **Done** (D-57): `script/Deploy.s.sol` (salt mining for both hooks and $PONDPAD > IMD, full wiring and supply split); rehearsal `DeployFork.t.sol` on a Robinhood fork; `forge script` simulation ~57.6M gas |
| 13 | Audit loop | **Package ready** (D-60, D-61): `audit/` (threat model, findings ledger, four area jobs on IMD's native audit template, `make_jobs.py`). **To do:** pay and run round 1 (4 × 0.5 IMD, web form or API), fix, repeat until clean; then swarm fuzz campaigns; human audit before large TVL; bug bounty |
| 13a | Testnet run | **Setup built** (D-62): `contracts/testnet/` (test IMD / USDG with faucets, IMD/ETH and ETH/USDG pools), `Deploy.s.sol` reads testnet values (mainnet locked), `TestnetFork.t.sol` passing. Trader bots built (D-63, `bots/`). **Run done 5 Oct 2026: healthy, no contract bug** (D-64, `bots/reports/2026-10-05/`); POOL4, attack, staking and airdrop suites built. THREAT-MODEL `block.number` note added (D-65). **To do:** gas headroom in the frontend, frontend against the testnet, later AI adversarial agents |
| 14 | Frontend | **Design done** (D-66). **Built against the testnet** (D-70, `frontend/`): Explore, Coin with trade box, Spawn, Profile with Claim all, **$PONDPAD (sale → market → airdrop, D-72)**, **the Pond (D-73)**, **Transparency (D-74)**, Docs (first pages + $PONDPAD, staking); public testnet link on GitHub Pages (D-73), Terms / Privacy with the wallet acceptance gate (D-69), faucet. **To do:** more Docs, WalletConnect, image upload (IPFS), indexer instead of log scans, IPFS deploy; a mainnet router for the $PONDPAD market with minimum-out and ETH / USDG (D-72, needs a decision); the real airdrop claims file; legal texts reviewed by counsel |
| 15 | Backend | ~~Keeper bot~~ (done, D-58: `keeper/`). Indexer (incl. outside-pool volume tracking), Swarm Relay (site jobs with output scan), token auto-verifier, X link service, airdrop tweet checker (D-55; the $PONDPAD page calls it at `POST /voucher`, D-72), launch/graduation bots |
| 15a | New mainnet launch settings (D-76) | **To do:** launch fee 0.35 IMD, Leap target 4,000 IMD, early-bird tax 70% over 80 s, in `Deploy.s.sol` (mainnet deploy; testnet unchanged) and in docs / copy / design examples; regenerate the audit (HANDOFF §5 step 13) |
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

- **Coin mechanics menu** (D-71): a `PadHook` v2 with audited add-ons the creator picks at launch, the first being **POOL4-style burn on sells**, then e.g. buybacks, time-based fees, anti-sniper rules. Each add-on is approved through the timelock; the core hook keeps enforcing the fee, locked liquidity and the right to sell. Ships as a new curve + hook version via `VersionRegistry`; v1 coins are unchanged.
- **Custom coins** built by the swarm, accepted only with a bytecode-hash audit attestation (after the mechanics menu; each custom hook must also collect our fee and block liquidity removal).
- **Swarm review** published for every timelocked settings change.
- **POOL4-style burn mode per coin** (needs IMD-quoted, one-sided POOL4 variant): the first add-on of the mechanics menu above.
- **Boosted / locked sPONDPAD tiers**.
- **Outside LPs into our pools** (earn an LP fee in the canonical pool instead of opening rival pools).
- Optional lower post-graduation fee schedules if outside-pool leakage grows (the user prefers leaving fees to creators; revisit only with data).

## 4. Later

- **Holder rewards in other tokens** (v3+, or sooner only if people ask; D-71): the creator picks at launch a reward token from a timelock-approved list (e.g. tokenized stocks, gold) instead of IMD; the holders' share builds up in IMD and a permissionless, price-guarded `convert()` swaps it in chunks (like `PadBuyer`), paid by a new `PadToken` template. Before building: each token's transfer restrictions, route liquidity, and a legal review (stock tokens as "dividends").

- **Dead-coin migration** (Pons-style epochs, vesting claims, refunds).
- **Base and Ethereum** deployments (IMD exists on both; same contracts, deterministic addresses).
- Switch the ETH route to an **official POOL4 IMD/ETH market** on Robinhood when it exists.
