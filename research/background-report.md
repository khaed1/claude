# Algorithmic stablecoins: research report and project ideas for the IMD swarm

> Original long-form background report (October 7, 2026). The current plan, risk ratings and protocol options live in [algorithmic-stablecoins.md](algorithmic-stablecoins.md), which mirrors the shareable page.

*Prepared October 2026. Chosen track: Idea A plus Idea E; the shareable page has step-by-step deep dives on both. This is a starting brief for re-running the research, specs, contracts and audits through the IMD (identity.md) agent swarm. Figures from 2024–2026 come from the sources linked at the end; older history is from public post-mortems and protocol docs and should be re-verified by the swarm before anything is built on it.*

---

## 1. Executive summary

- **The record is mostly failures.** Almost every design that held its peg *only through reflexive incentives* (its own governance or share token) broke: NuBits, Basis Cash, Empty Set Dollar, Iron Finance, Terra UST, Neutrino USDN, Fei. The common failure is a **death spiral**: the asset that absorbs volatility loses value at the exact moment the peg needs it.
- **The survivors share three properties:** (1) exogenous collateral the protocol does not mint itself (ETH, LSTs, hedged positions), (2) a **hard redemption floor** that arbitrageurs can always use, and (3) a **separate risk-absorbing layer** (junior tranche, stability pool, leveraged token, insurance fund) that is paid to take the volatility.
  Examples: Liquity LUSD/BOLD, RAI, crvUSD, f(x) Protocol, Ethena USDe, Resolv USR, Ampleforth SPOT.
- **Market context (2026):** algorithmic/synthetic designs are under 2% of a roughly $312B stablecoin market. The only post-UST design to reach real scale is Ethena USDe (peak ~$14B in 2025, ~$4.5B now). The October 2025 liquidation cascade and the November 2025 Stream Finance / Elixir deUSD losses are recent reminders that hidden counterparty risk still kills "algorithmic" dollars.
- **Where the room is:** not "a better Terra", but
  (a) **peg mechanics built natively into Uniswap V4 hooks**, which IMD already specialises in,
  (b) **non-USD units of account**, like an inflation-tracking flatcoin or a compute-priced unit for paying AI agents, and
  (c) **automated risk operations**, with agents as keepers, monitors and auditors rather than as price oracles.
- **Recommended first project:** a Liquity-style, immutable, ETH/LST-backed stablecoin whose peg is defended by a **V4 hook with asymmetric dynamic fees and a reserve-ratio-aware redemption curve**, with IMD/sIMD used only as *junior* insurance capital, never as primary collateral. Details and five alternative tracks are in §6.

---

## 2. Taxonomy: the five families

| Family | How the peg holds | Who absorbs volatility | Examples | Track record |
|---|---|---|---|---|
| **Rebase / elastic supply** | Supply in every wallet expands or contracts toward a price target | All holders (balances change) | Ampleforth AMPL, Yam, Base Protocol | Never truly stable; AMPL survives as a volatile "unit of account" asset |
| **Seigniorage / multi-token** | Mint stable when above peg, sell bonds/shares when below | Share and bond holders | Basis (never launched), Basis Cash, ESD, DSD, Terra UST + LUNA, USDN, USDD (original) | Near-universal failure via death spirals |
| **Fractional-algorithmic** | Part collateral, part algorithmic share token | Share token + collateral pool | Frax v1/v2, Iron Finance (IRON/TITAN), Fei (PCV) | Iron collapsed; Frax moved to full collateral; Fei shut down |
| **Overcollateralised CDP + algorithmic controls** | Exogenous collateral at >100%, redemptions, rate controllers, soft liquidation | Borrowers, stability-pool depositors, leveraged side | Liquity LUSD and v2 BOLD, RAI / HAI, crvUSD, Djed / SigUSD, Gyroscope GYD, f(x) fxUSD | Best survival record |
| **Synthetic / delta-neutral** | Long spot + short perp of the same size; funding rate is the yield | Insurance fund / junior tranche, exchange counterparties | Ethena USDe, Resolv USR (+RLP), StandX DUSD, Elixir deUSD (failed) | Scales fast; depends on CEX and funding-rate regime |

Two adjacent ideas worth knowing even though they are not stablecoins:

- **Olympus OHM range-bound stability (RBS):** treasury-run "walls" and "cushions" that defend a price *band* rather than a point.
- **IMD's own POOL4 CappedBurnHook:** caps pool inventory, trims excess after sells, and redeploys recovered ETH as a standing buy wall. It is effectively a one-sided RBS done inside a V4 hook, a pattern a stablecoin can borrow.

---

## 3. Project-by-project review

### 3.1 Early and seigniorage era

**NuBits (2014).** The first well-known algorithmic stable. "Custodians" defended the peg with parking rates and buy walls funded by NuShares sales. It broke in 2016, recovered, then broke permanently in 2018 when nobody wanted the share token.
*Lesson:* a share token is only worth something while people expect growth.

**Basis (2018, never launched).** Three-token design (stable, bonds, shares) by Robert Sams' paper lineage. It raised about $133M, then shut down in December 2018 over securities-law concerns and returned the capital.
*Lesson:* bonds plus shares look like securities to regulators, and the design was copied endlessly anyway.

**Basis Cash, Empty Set Dollar, Dynamic Set Dollar (2020–21).** Permissionless forks of the Basis idea using coupons and bonds with time-weighted average price (TWAP) epochs. All spent most of their life below peg. Coupons expire worthless when nobody believes in re-expansion.
*Lesson:* "debt that only pays if we grow again" is not peg support.

**Terra UST (2020–May 2022).** Mint/burn arbitrage against LUNA, with the Anchor protocol paying about 19.5% to drive demand and the Luna Foundation Guard holding a BTC reserve. Large withdrawals from Anchor and Curve's 4pool started a run. Redemptions minted trillions of LUNA, the reserve was too small, and about $18B of UST went to near zero.
*Lessons:*
- reflexive collateral fails exactly when you need it;
- subsidised yield is demand you rent, not demand you own;
- mint/burn capacity limits only slow the spiral down.

**Neutrino USDN (Waves) and USDD (Tron).** Both were UST-shaped. USDN de-pegged repeatedly in 2022. USDD survived by moving to overcollateralisation, with centralised backstops.

### 3.2 Fractional and controlled-supply era

**Iron Finance (June 2021).** IRON was about 75% USDC and 25% TITAN. A TITAN sell-off plus a lagging TWAP oracle let redemptions mint TITAN faster than the market could absorb it, and TITAN went to about zero within a day.
*Lessons:*
- oracle lag is an attack surface;
- partial reflexive backing is still reflexive.

**Frax (Dec 2020 →).** Fractional-algorithmic with a collateral ratio (CR) that moved with market confidence, plus algorithmic market operations (AMOs) that deploy collateral into Curve and lending markets without breaking the peg. After UST, the community voted to move toward 100% CR. The AMO concept (programmatic, bounded treasury strategies) is the lasting contribution.

**Fei Protocol (April 2021–2022).** A protocol-controlled value (PCV) reserve plus "direct incentives" that penalised selling below peg. The launch trapped users, and the penalties were dropped. Fei merged with Rari, suffered the Rari Fuse exploit (about $80M), and wound down in 2022, redeeming holders from the PCV.
*Lessons:*
- PCV is a good idea;
- penalising exits destroys trust instantly.

**Ampleforth (2019 →).** A daily rebase toward a CPI-adjusted 2019 dollar. Balances change but each wallet's share of supply stays constant. It is not stable in wallet value. It is valuable as a non-correlated, credit-free base asset.
In 2023 Ampleforth launched **SPOT**, a "flatcoin" built by tranching AMPL into senior (stable-ish) and junior (leveraged) parts.
*Lesson:* tranching turns a volatile elastic asset into a low-volatility one without a share token.

### 3.3 Overcollateralised "algorithmic" designs that work

**Liquity LUSD (2021) and Liquity v2 BOLD (2025).**
- Immutable contracts with no governance.
- ETH-only (v1) and LST collateral (v2), with a 110% minimum collateral ratio.
- **Hard floor:** anyone can redeem 1 LUSD for $1 of ETH against the riskiest troves.
- **Soft ceiling:** minting at 110% CR.
- A **Stability Pool** absorbs liquidations in exchange for discounted collateral.
- v2 adds user-set borrowing rates, which lets the market price the peg instead of governance.
- Many forks across chains.

*Lesson:* redemption plus immutability equals trust.

**RAI by Reflexer (2021) and HAI.** ETH-only and deliberately *not* pegged to $1. A PI controller moves a **redemption rate** so that the market price chases a floating redemption price. Low volatility, low scale.
*Lesson:* control theory works for stability; a non-USD target limits adoption, but that is also a niche.

**crvUSD (2023).**
- LLAMMA (lending-liquidating AMM) converts collateral gradually as price falls, a "soft liquidation" with no cliff.
- PegKeepers mint and burn into Curve pools within bounds.
- The borrow rate is a function of the peg deviation.

*Lesson:* liquidation-as-AMM-band is a strong primitive, and it maps naturally to concentrated-liquidity ranges.

**Djed (IOG, 2021) and SigUSD on Ergo.** A formally specified overcollateralised design. A reserve coin absorbs volatility and minting or redeeming is blocked outside a reserve-ratio band. It is simple and verifiable.
*Lesson:* minimal state machines are auditable.

**Gyroscope GYD (2023).** A diversified reserve in vaults plus a **Primary-market AMM (PAMM)**: the redemption price falls smoothly as outflows grow, which prevents bank runs from draining the reserve at par.
*Lesson:* curve-shaped redemption is a strong run-defence tool and fits a V4 hook well.

**f(x) Protocol (AladdinDAO).** Splits ETH or stETH into **fETH/fxUSD** (low-volatility) and **xETH** (leveraged long). The stability mode rebalances when the collateral ratio falls.
*Lesson:* "sell the volatility to people who want leverage" is the cleanest way to fund stability.

**Celo Mento (cUSD).** A reserve-backed stable with a virtual-AMM mint/redeem. Diversified reserve.

### 3.4 Synthetic / delta-neutral era (2024–2026)

**Ethena USDe.**
- Backed by spot ETH, BTC or LSTs plus short perpetuals on centralised exchanges, custodied off-exchange.
- Yield comes from funding and staking, with an insurance reserve.
- Reached about $14B in 2025, then contracted after the October 2025 cascade, including a sharp venue-specific dislocation.

*Risks:* negative funding, exchange or custody failure, and basis blowouts.

**Resolv USR + RLP.** Delta-neutral like Ethena, but with an explicit **junior tranche (RLP)** that takes the losses and the excess yield. That makes the risk split visible and priced.

**StandX DUSD.** A delta-neutral dollar with automatic yield from staking plus perp funding.

**Elixir deUSD (wound down Nov 2025).** A large part of its backing was lent to Stream Finance, which reported about $93M of losses. deUSD lost its peg and was wound down.
*Lesson:* "delta-neutral" backing is only as good as the most opaque counterparty in the chain, so on-chain proof of reserves matters.

### 3.5 Exploits and governance failures worth studying

- **Beanstalk (April 2022):** a credit-based stable (Pods and Soil). A flash-loan governance attack drained about $182M.
  *Lesson:* never allow same-block voting power.
- **Iron Finance:** TWAP lag (above).
- **Rari / Fei:** reentrancy in Fuse pools.
- **Terra:** the Curve pool imbalance as the trigger.
  *Lesson:* monitor your main liquidity venue as a risk signal.

---

## 4. Design lessons, condensed

1. **Exogenous collateral first.** Never let the asset you mint be the main backing of the stable.
2. **A redemption floor anyone can hit, always.** Without one there is no peg, only a hope.
3. **Price the risk with a tranche.** Volatility must be *sold* to someone (junior tranche, leverage token, stability pool) who is paid for it. Do not socialise it.
4. **Curve-shaped exits beat cliffs.** Use soft liquidation (LLAMMA) and declining redemption curves (Gyroscope PAMM) instead of liquidation cliffs and fixed-par bank runs.
5. **Control loops beyond governance.** PI controllers (RAI) and deviation-based rates (crvUSD, Liquity v2) react in hours. DAO votes take days.
6. **Immutability or tightly bounded parameters.** Every admin key is a depeg vector.
7. **Oracles: robust, multi-source, with circuit breakers.** Use TWAP plus Chainlink plus a deviation pause. No single-block spot price.
8. **Rented demand is not demand.** Anchor-style subsidised yield ends in a run.
9. **Proof of reserves on-chain, with no hidden rehypothecation** (the Elixir and Stream lesson).
10. **Plan the wind-down.** Fei's orderly PCV redemption is the model for a graceful failure.

---

## 5. What IMD gives you (and its limits)

What the swarm offers, from public reporting as of late September 2026:

- **2,000 NFT seats** run agents (Claude or Codex) on operators' machines.
- A **lead orchestrator** posts tasks.
- A **verifier rebuilds** each submission in a sealed container.
- **Other seats review it adversarially**, and accepted work is logged on-chain (ERC-8004 reputation).
- About 86% of submissions are accepted.

Outputs today:

- Uniswap V4 hooks (testnet)
- IPFS websites
- **multi-agent oracle panels** (several agents answer independently)
- audits, reports, images

**Contract and frontend work is premium-tier**, routed only to seats running a top model at high effort.

IMD primitives you can build on or reuse as patterns:

- **POOL4 CappedBurnHook:** inventory cap, post-swap trim, standing ETH buy wall, a ratcheting cap.
- **sIMD:** ERC-4626 staking vault, with rewards streamed from burns.
- **Launchpad:** bonding-curve coins priced in IMD.
- **x402 payment rail:** paid jobs at 0.5 IMD per request.

Limits to plan around:

- **Deployments:** as of early October 2026 (per the user), IMD deploys to Ethereum mainnet and Robinhood Chain mainnet as well as Sepolia, with Base and Solana expected next. Keep this project's jobs on Sepolia anyway; plan mainnet as a separate, later, human-reviewed step.
- **An agent oracle panel is a good fit for slow, off-chain, judgement-type data** (CPI figures, a compute-price index, incident reports). It is **not** a substitute for a manipulation-resistant market price feed.
- Swarm audits are useful but are **not** a substitute for an independent professional audit and a bug bounty before real money is involved.
- **Using IMD or sIMD as primary collateral would recreate the Terra/Iron reflexivity problem.** Use them only as junior or insurance capital, or as fee and reward sinks.

---

## 6. Project ideas (ranked)

Each idea lists its core mechanism, what it borrows, what is new, the main risk, and how to split it into swarm jobs.

### Idea A (recommended first): "Hooked Liquity", an immutable CDP stable with V4-hook peg defence

- **Mechanism:**
  - Liquity v2-style troves backed by ETH and LSTs, with user-set rates and a $1 redemption floor.
  - The stable's main ETH/stable and USDC/stable pools use a **V4 hook** that:
    1. charges **asymmetric dynamic fees**: low on trades that move price toward $1, high on trades that push it away;
    2. runs a **Gyroscope-style redemption curve** whose discount widens if the system collateral ratio falls, so runs drain value slowly;
    3. keeps a **POOL4-style standing buy wall** funded by protocol fees below $0.995.
- **Insurance:** an sIMD-like ERC-4626 "stability vault" earns fees and absorbs liquidations first. IMD can be a *junior* deposit option there.
- **Borrows from:** Liquity (redemptions, immutability), Gyroscope (PAMM), crvUSD (deviation-aware rates), POOL4 (buy wall).
- **New:** peg defence *inside the trading venue itself*. The pool is no longer a passive victim of a run (as Curve was for UST); it is an active stabiliser.
- **Main risk:** hook complexity and V4 hook-permission bugs. The hook must never be able to block redemptions.

### Idea B: tranche-split stable ("f(x) on hooks")

- **Mechanism:** deposit ETH or stETH to receive a **senior stable unit** plus a **junior leveraged unit**. The senior unit is redeemable at $1 while the junior equity is above zero.
  - A rebalancing controller mints or burns junior units to keep the senior collateral ratio above a target.
  - A stability mode activates below a threshold, with fees routed to junior holders.
- **Borrows from:** f(x), Resolv RLP, Ampleforth SPOT.
- **New:** both tranches trade in one V4 pool family, with a hook that enforces the ratio and routes fees. The junior token is a natural "community coin" for the IMD launchpad to list against IMD.
- **Main risk:** in a fast crash the junior equity can be wiped out, so it needs a robust, graceful emergency mode.

### Idea C: inflation-indexed flatcoin with an agent-panel CPI oracle (dropped)

- **Mechanism:**
  - The target price drifts with an inflation index, like Ampleforth's CPI target or RAI's floating redemption price.
  - The peg is held by Idea A or B mechanics.
  - The *index* (not the market price) comes from an **IMD multi-agent oracle panel**: N agents independently fetch official CPI releases and compute the update. The median wins, outliers are slashed or lose reputation, and updates are monthly, bounded (for example ±1%) and timelocked.
- **Borrows from:** Ampleforth (CPI target), RAI (floating target), Frax's FPI concept.
- **New:** a credibly decentralised, slow-moving index oracle is exactly what agent panels are good at.
- **Main risk:** oracle collusion. Mitigate with bounded per-update change, a timelock with challenge windows, and fallback to the last value.

### Idea D: "Compute dollar", a stable unit pegged to AI inference cost (watching: another team is reportedly building one)

- **Mechanism:** a CDP or tranche stable whose target is the price of a basket of AI inference, for example "1 unit = the cost of 1M output tokens across a basket of public model price lists".
  - The basket index is maintained by an IMD oracle panel (as in Idea C).
  - It is used as the unit of account for x402 swarm jobs, so job buyers get predictable compute pricing and operators get paid in something tied to their real costs.
- **Borrows from:** RAI (non-USD target), basket-pegged Float Protocol.
- **New:** to my knowledge, no live stable is pegged to AI compute cost. It fits IMD's economy natively.
- **Main risk:** compute prices fall fast (deflationary target), so holders gain while borrowers face rising real debt. It needs a careful rate design. Thin demand outside the agent economy.

### Idea E: soft-liquidation stable as a V4 hook ("LLAMMA-in-a-hook")

- **Mechanism:** port crvUSD's LLAMMA band logic into a Uniswap V4 hook plus concentrated-liquidity ranges. Collateral is converted to the stable gradually across bands as price falls, and back as it recovers.
- Combine it with Idea A's redemption floor.
- **New:** reuses V4's native tick and range machinery, and composes with the rest of the V4 ecosystem.
- **Main risk:** loss-versus-rebalancing (LVR) and MEV extraction in the bands. Research oracle-anchored band pricing.

### Idea F: agent-operated risk layer (works with any of A to E)

- **Mechanism:** the swarm continuously runs:
  - keepers (liquidations, redemptions, rebalancing);
  - risk monitors (collateral concentration, venue liquidity, funding-rate regime, oracle deviation);
  - weekly public risk reports.
- Agents can **trigger only bounded, pre-coded actions**, such as raising a fee within a band or pausing minting (never redemptions). They have no discretionary control.
- **Borrows from:** Frax AMOs, Gauntlet and Chaos-style risk management, Olympus RBS.
- **New:** risk ops performed and cross-checked by a reputation-scored agent network, logged on-chain.
- **Main risk:** liveness (agents offline). Design every safety action to be callable by anyone when its on-chain condition is true.

### Ideas to avoid

- Any **seigniorage/share-token stable** (Basis or Terra family), including "the share token is IMD".
- **Subsidised-yield demand** (Anchor-style).
- **Off-chain delta-neutral backing** without real-time on-chain proofs (the Elixir and Stream failure).
- **Sell penalties** (the Fei mistake).

---

## 7. Suggested research path (one by one on IMD)

Each step is a separate swarm job. Keep jobs small and verifiable: one deliverable, explicit acceptance criteria, an allowed-files list.

| # | Job | Tier | Deliverable |
|---|---|---|---|
| 1 | Re-verify this report: facts, dates, figures, primary sources | Standard (report) | `research/verified-history.md` with citations |
| 2 | Failure-mode catalogue: each failure as a reusable stress scenario | Standard | `research/stress-scenarios.md` |
| 3 | Pick Idea A or B; write a spec covering state machine, invariants, parameters | Standard | `specs/<idea>.md` with listed invariants |
| 4 | Simulation: agent-based model (Python) of the peg under the stress scenarios | Standard | `sim/` with plots, parameter sweep |
| 5 | Oracle-panel design (only for Ideas C or D) | Oracle panel + report | Sample index updates, disagreement stats |
| 6 | Core contracts (Foundry), Sepolia only | **Premium** (contracts) | `src/`, `test/`, invariant/fuzz tests passing |
| 7 | V4 hook (fees, redemption curve, buy wall) | **Premium** | Hook plus fork tests against Sepolia PoolManager |
| 8 | Adversarial audit by multiple independent seats | Standard / audit | `audits/round-N.md` with findings and fixes |
| 9 | Frontend (IPFS) | **Premium** (frontend) | Mint/redeem/stability-vault UI |
| 10 | Testnet game-day: scripted run, oracle shock, venue drain | Standard | Post-mortem report |
| 11 | Human gate: external audit, bug bounty, legal review before any mainnet | — | Out of swarm scope |

**Template for a job prompt** (adapt to IMD's submission format):

> **Goal:** <one sentence>.
> **Context:** <link to spec / previous outputs>.
> **Deliverables:** <exact files>.
> **Allowed files:** <paths>.
> **Acceptance:**
> - `forge test` passes, including invariant tests X, Y and Z;
> - no admin function can block redemptions;
> - every external price read goes through `OracleGuard`.
>
> **Out of scope:** mainnet deployment, new tokens.

Invariants worth writing into every spec from day one:

- Total stable supply ≤ Σ collateral value / MCR (system-level).
- Redemption is always callable when supply > 0. No pause, hook or admin key can block it.
- The hook can never take more than its configured maximum fee, and never reverts a swap that moves price toward peg.
- Oracle updates are bounded per interval; a stale oracle switches the system to a safe mode (mint off, redeem on).
- The junior/insurance tranche takes losses before senior holders, always.

---

## 8. Open questions to research next

- How should asymmetric dynamic fees in a V4 hook interact with external arbitrage (CEX ↔ pool) so that the peg is restored quickly rather than discouraged?
- What redemption-curve shape (Gyroscope PAMM parameters) minimises run losses without making $1 redemption feel unreliable in calm markets?
- Can an agent-panel oracle be made economically secure (staking or reputation slashing) for low-frequency indices? What is the cost of corrupting it versus the value it secures?
- Is a compute-cost peg (Idea D) stable enough, given how fast inference prices fall? Should it target a *fixed-quality* basket?
- What is the regulatory position of each design in your jurisdiction? Payment-stablecoin laws (for example the US GENIUS Act of 2025, and EU MiCA) treat algorithmic designs differently from reserve-backed ones. Get counsel before mainnet.

---

## Sources

- IMD / identity.md: [Bankless, "Inside IMD, Ethereum's new AI swarm experiment"](https://www.bankless.com/read/inside-imd-ethereum-s-new-ai-swarm-experiment), [KuCoin, "What Is IMD Token?"](https://www.kucoin.com/blog/imd-token-community-owned-ai-agents), [IMD Explorer](https://explorer.imd.fun/), [IdentityMD worker](https://github.com/Identity-md/worker)
- 2026 market state: [Stablecoin Insider, algorithmic stablecoin guide 2026](https://stablecoininsider.org/what-is-an-algorithmic-stablecoin-full-guide-2026/), [LI.FI knowledge hub](https://li.fi/knowledge-hub/algorithmic-stablecoins-how-they-work-the-risks-and-where-to-find-them), [Eco, top algorithmic stablecoins 2026](https://eco.com/support/en/articles/12257457-top-algorithmic-stablecoins-2026), [BingX, top algorithmic stablecoins 2026](https://bingx.com/en/learn/article/what-are-the-top-algorithmic-stablecoins-to-know), [ForkLog on USDe](https://forklog.com/en/delta%e2%80%91neutral-synthetic-dollars-why-the-usde-stablecoin-matters/)
- Protocol primary sources to give the swarm in job 1: Ampleforth and SPOT docs, the Liquity v1/v2 whitepapers, the Reflexer RAI whitepaper, the Curve crvUSD/LLAMMA paper, the Djed paper (IOG, 2021), Gyroscope docs (PAMM), f(x) Protocol docs, Ethena docs, Resolv docs, Frax docs (AMOs), Olympus RBS docs, the Terra/UST post-mortems (e.g. Jump/Nansen on-chain analyses), the Iron Finance post-mortem, the Beanstalk exploit post-mortem.
