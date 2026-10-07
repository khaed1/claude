# Algorithmic Stablecoins on IMD

Oct 7, 2026 · Mirrors the shareable page; the detailed per-project history is in [background-report.md](background-report.md).

The designs that survived all use outside collateral, a $1 redemption floor and a paid risk layer; the best fit for IMD is a Liquity-style stablecoin whose peg is defended inside a Uniswap V4 hook.

## The five families

Only the overcollateralised and synthetic families have a decent survival record; in 2026 algorithmic and synthetic designs are under 2% of a roughly $312B stablecoin market.

| Family | How the peg holds | Who absorbs volatility | Examples | Record |
| --- | --- | --- | --- | --- |
| Rebase (elastic supply) | Every wallet's balance grows or shrinks toward a target price | All holders | Ampleforth AMPL, Yam | Never truly stable in wallet value |
| Seigniorage (multi-token) | Mint when above $1; sell bonds or shares when below | Share and bond holders | Basis Cash, Empty Set Dollar, Terra UST, Neutrino USDN | Nearly all failed in death spirals |
| Fractional | Part real collateral, part the protocol's own token | Share token plus collateral | Frax v1, Iron Finance, Fei | Iron collapsed, Fei closed, Frax went fully collateralised |
| Overcollateralised CDP with algorithmic controls | Over 100% outside collateral, redemptions, automatic rates, soft liquidation | Borrowers, stability pool, leveraged side | Liquity, RAI, crvUSD, Djed, Gyroscope, f(x) | Best record |
| Synthetic (delta-neutral) | Long spot plus short perpetuals of equal size | Insurance fund or junior tranche | Ethena USDe, Resolv USR, StandX DUSD | Scales fast; depends on exchanges and funding rates |

A death spiral: when the backing token is the protocol's own, it crashes exactly when the peg needs it, which mints more of it, which crashes it further.

## Track record

Most shut down or broke; the history before 2024 is from public post-mortems and should be re-checked before building on it.

| Year | Project | Mechanism | What happened | Lesson |
| --- | --- | --- | --- | --- |
| 2025 | Elixir deUSD | Delta-neutral, backing lent out | Stream Finance lost about $93M; deUSD wound down in November | Backing is only as safe as its most hidden counterparty |
| 2025 | Liquity v2 BOLD | Liquity with liquid staking collateral, user-set rates | Live | Let the market price the borrowing rate |
| 2024 | Ethena USDe | Spot long plus perp short | Peak about $14B in 2025, about $4.5B now | Depends on exchanges and positive funding |
| 2024 | Resolv USR | Delta-neutral with a junior tranche (RLP) | Live | Make the risk split visible and priced |
| 2023 | crvUSD | Soft liquidation (LLAMMA) plus PegKeepers | Live | Liquidation can be a gradual AMM, not a cliff |
| 2023 | Gyroscope GYD | Reserve plus a redemption curve (PAMM) | Live | A curved redemption slows bank runs |
| 2023 | Ampleforth SPOT | Senior tranche of AMPL | Live | Tranching makes a volatile asset calm |
| 2022 | Terra UST | Mint and burn against LUNA, 19.5% Anchor yield | About $18B went to near zero in May | Reflexive backing and rented yield fail together |
| 2022 | Beanstalk | Credit-based stable | About $182M flash-loan governance attack | Never allow same-block voting power |
| 2021 | Iron Finance | 75% USDC, 25% TITAN | TITAN went to about zero in one day in June | Slow oracles are an attack surface |
| 2021 | Fei | Protocol-owned reserve plus sell penalties | Penalties dropped; closed in 2022 and redeemed holders | Penalising exits destroys trust |
| 2021 | Liquity LUSD | ETH only, 110% minimum ratio, $1 redemption | Live, no governance | Redemption plus immutability earns trust |
| 2021 | RAI | ETH only, floating target set by a controller | Live, small | Control loops can replace governance |
| 2020 | Frax | Fractional, then fully collateralised | Moved to 100% collateral after Terra | Bounded treasury strategies (AMOs) last |
| 2020 | Basis Cash, Empty Set Dollar | Coupons and bonds | Spent most of their life below $1 | Debt that pays only if growth returns is not support |
| 2019 | Ampleforth AMPL | Daily rebase to a CPI-adjusted dollar | Live, volatile | Rebasing is not stability |
| 2018 | Basis | Bonds and shares | Returned about $133M and shut down over securities law | Regulators read bonds plus shares as securities |
| 2014 | NuBits | Share token funds buy walls | Broke in 2016 and for good in 2018 | Share tokens only hold value while growth is expected |

## Design rules

Every idea below is checked against these ten rules.

1. Back the coin with outside collateral (ETH, staking tokens), never mainly with a token the protocol mints.
2. Keep a $1 redemption that anyone can use at any time; no pause or admin key may block it.
3. Sell the volatility to someone paid to hold it: a junior tranche, a stability pool or a leveraged token.
4. Prefer gradual exits (soft liquidation, curved redemption) to cliffs.
5. Use automatic control loops (deviation-based rates) instead of slow governance votes.
6. Make contracts immutable, or bound every parameter tightly.
7. Read prices from several sources with time averages and a circuit breaker.
8. Do not rent demand with subsidised yield.
9. Prove reserves on-chain, with no hidden lending of the backing.
10. Plan an orderly wind-down, as Fei did.

## Deep dive 1: Hooked Liquity

Hooked Liquity is Liquity v2 plus a Uniswap V4 hook that makes the stablecoin's own trading pool push the price back to $1, instead of being the place where a run starts (as Curve was for UST).

### The core, borrowed from Liquity

- **Borrowing:** you lock ETH or a staking token in a "trove" and mint the stablecoin, up to 1 coin per $1.10 of collateral (110% minimum ratio). You pick your own interest rate.
- **Redemption floor:** anyone can hand in 1 coin and receive $1 of collateral, taken from the troves paying the lowest interest. If the coin trades at $0.98, buying and redeeming earns 2%, so traders buy until it is back near $1.
- **Ceiling:** if the coin trades above $1, borrowing at 110% and selling is profitable, so supply grows until the price falls.
- **Stability pool:** depositors hold the coin and absorb liquidations, receiving the liquidated collateral at a discount. In this design the stability pool is an ERC-4626 vault like sIMD; IMD can be accepted only as a junior, first-loss deposit, never as collateral.

### What the hook adds

A V4 hook is a contract that Uniswap calls before and after every swap in a pool. It can set the fee per swap and run extra logic. Ours does three things:

1. **Asymmetric fees.** Below $1, a trade that buys the coin (toward $1) pays almost nothing, for example 0.01%; a trade that sells it (away from $1) pays more, rising with the distance, for example 0.3% at $0.995 and 1% at $0.98. Above $1 the rule flips. Arbitrage toward the peg is cheap; dumping is expensive. This is not a sell penalty like Fei's, because the fee is small, known in advance and only applies off-peg.
2. **Buy wall.** Part of every fee goes to a reserve. When the price is under a threshold, for example $0.995, the reserve buys the coin in the pool and burns it or sends it to redemption. This is IMD's POOL4 buy-wall pattern.
3. **Health-aware redemption fee.** Liquity already raises the redemption fee after heavy redemption volume. We also tie it to system health: when the total collateral ratio is high, redemption stays near $1; when it falls and redemptions surge, the fee rises smoothly (the Gyroscope idea). A run then drains the reserve slowly instead of all at once.

### A run, step by step

1. ETH falls 25% in a day and people sell the coin; the pool price drops to $0.985.
2. Sellers now pay about 0.8% in fees; buyers pay 0.01%. Arbitrageurs buy at $0.985 and redeem for $1 of ETH, a 1.5% gain.
3. The buy wall spends reserve funds below $0.995.
4. Redemptions hit the lowest-rate troves first, so borrowers raise their rates or repay. Repaying means buying the coin.
5. If the collateral ratio keeps falling, the redemption fee rises gradually, so the remaining holders are not raced to the exit.

### Hard rules for the contracts

- Redemption lives in the core contracts, never in the hook; no hook bug, pause or admin key can block it.
- The hook can never charge more than its maximum fee, and never reverts a swap that moves the price toward $1.
- Prices come from Chainlink plus a pool time average, with a bound on how much they may move per update.

### Main risks

- Hook bugs: V4 hooks are new code with permission flags encoded in the contract address.
- Too-high fees could slow arbitrage; the fee curve needs simulation.
- The coin must still find real demand without subsidised yield.

## Deep dive 2: soft liquidation as a V4 hook

Instead of selling a borrower's whole position at once when the price crosses a line, the borrower's collateral is sold a little at a time as the price falls, and bought back as it recovers. crvUSD calls this LLAMMA; the idea is to rebuild it inside a Uniswap V4 pool.

### The problem it fixes

In a normal lending protocol (Aave, Maker, Liquity), a position has one liquidation price. Cross it by a cent and a liquidator takes a large chunk of your collateral at a 5–10% discount. Many positions crossing at once means a wave of forced selling, which pushes the price down further: a liquidation cascade, like October 2025.

### How it works, with numbers

1. You deposit 1 ETH when ETH is $2,000 and borrow 1,000 coins.
2. Your ETH is not left in a vault. It is spread across price "bands", here 4 bands of $50 each between $1,400 and $1,200. Think of each band as a small limit order: "sell this quarter of my ETH for coins between $1,400 and $1,350".
3. While ETH is above $1,400 nothing happens; you hold 1 ETH.
4. ETH falls to $1,375. Traders buy the ETH in your top band with coins. You now hold about 0.875 ETH plus about 172 coins.
5. ETH falls to $1,300. Two bands have converted; you hold about 0.5 ETH plus about 675 coins.
6. ETH bounces back to $1,450. Traders sell ETH back into your bands; you hold about 1 ETH again, minus a small loss.
7. Only if ETH falls below $1,200 and your position has no margin left is it fully liquidated. By then most of the collateral is already coins, so the debt is covered without a fire sale.

The band prices follow an oracle price, set so that the pool always offers traders a slightly better price than the market. That reward is what makes traders do the conversion for you.

*(Drawing on the shareable page: the same 1 ETH shown at $1,450 — all ETH; at $1,300 — top two bands sold, 0.5 ETH + 675 coins; below $1,200 — all four bands sold, about 1,300 coins covering the 1,000-coin debt; and back to ETH if the price recovers.)*

Each band sells only as the price passes through it, so there is never a single moment where the whole position is dumped.

### Why build it as a V4 hook

- A V4 hook can replace a pool's normal pricing with its own curve, so the band logic can run as a Uniswap pool.
- Every aggregator and trading bot that routes through Uniswap then supplies the arbitrage that soft liquidation needs, without a special integration.
- It combines with Deep dive 1: the same coin keeps its $1 redemption floor and peg hook, while borrowers get gradual instead of cliff liquidation.

### Costs and risks

- **Chop losses:** if the price swings up and down inside your bands, you sell low and buy back slightly higher each time. crvUSD borrowers have taken these losses in choppy markets.
- **MEV:** bots compete to capture the band discount; the oracle and fee design decide how much borrowers lose to them.
- **Oracle risk:** a manipulated oracle would convert bands at the wrong price.
- **Gas and complexity:** many bands per borrower means more state per swap. This is premium contract work and needs heavy fuzzing.

## Risks of Hooked Liquity and the fixes

Three risks can lose user funds and are critical: a bug in our hook, bad debt from a fast ETH crash, and a wrong oracle price. Weak demand is critical for the project but loses no funds. Uniswap V4 itself is solid; the risk is in our own code.

| Risk | Severity | Why this rating | Fix |
| --- | --- | --- | --- |
| Bug in our hook | Critical | Can lose funds directly; hooks have been drained: [Cork Protocol](https://www.halborn.com/blog/post/explained-the-cork-protocol-hack-may-2025) lost about $12M in May 2025 (no caller check in `beforeSwap`), Bunni about $8.4M in September 2025 (rounding bug) | Keep the hook small and unable to touch redemption; check the caller is the PoolManager; round against the user; invariant and fuzz tests; [Trail of Bits' hook checklist](https://blog.trailofbits.com/2026/07/30/building-secure-uniswap-v4-hooks/); two outside audits and a bug bounty; a supply cap that rises slowly over the first months |
| Fast ETH crash leaves bad debt | Critical | The classic way a lending stablecoin goes insolvent | Start with a conservative minimum ratio; keep the stability pool large compared with supply; spread leftover debt across troves (Liquity's fallback); a first-loss insurance layer; supply cap at launch |
| Wrong oracle price | Critical | A bad price triggers wrong liquidations or wrong redemptions, even with correct code | Median of several sources, cap per update, reject stale prices, smoothed price for liquidations, pause new borrowing (never redemption) when sources disagree |
| No natural demand | Critical | Loses no funds, but the project fails without users | Real uses: IMD job payments, launchpad pairs, lending markets; never subsidised yield |
| Liquidity sits in pools without our hook | Medium | The $1 floor and ceiling still work in any pool; only the extra defense weakens | Protocol-owned liquidity in the hooked pool; route protocol fees to its LPs so it stays deepest |
| A staking token loses its peg to ETH | Medium | Collateral is worth less than assumed | Price staking tokens with their own market price; cap each one's share of collateral; higher minimum ratio for them |
| Legal treatment | Medium | Unknown until reviewed; can block a launch | Legal review per jurisdiction before mainnet (US GENIUS Act, EU MiCA) |
| Fee curve too steep | Low | Slows arbitrage but breaks nothing; capped | Simulate first; cap the maximum fee; never charge trades toward $1; start at 0.3% at most |
| Fee gaming within one block | Low | Small gains for a trader, no loss for the protocol | Fee from the price before the swap plus a short time average |

## Risks of soft liquidation and the fixes

Chop losses can be cut by paying borrowers back the value that traders now keep; MEV is a cost, not a collapse risk; and an audit cannot remove oracle risk, only careful oracle design can.

### Chop losses: ideas to test

The loss comes from one thing: each time the price crosses a band, the borrower sells slightly cheap or buys back slightly dear, and the trader keeps the difference. Every idea below either makes fewer crossings or hands that difference back to the borrower.

1. **Return the profit to borrowers (new).** Let the hook auction the right to rebalance the bands each block, and pay the auction proceeds to the borrowers in those bands. The trading profit stops leaking out and comes back as a rebate. This builds on research into auction-managed AMMs; crvUSD does not do it.
2. **Volatility-scaled band fee to borrowers (new).** In choppy markets the hook raises the fee traders pay to swap against bands, and the fee goes to the band owners. More chop then means more fee income, which offsets the loss.
3. **Hysteresis (a gap between sell and buy-back).** Sell a band when the price falls through it, but buy back only once the price is a set margin above it, for example 1%. Small wiggles no longer cause round trips. Trade-off: in a real recovery the borrower buys back a bit later.
4. **Bands close to the end only (hybrid with Hooked Liquity).** Keep the position as plain ETH most of the time and place the bands only in the last stretch before hard liquidation. Fewer days spent inside bands means less chop.
5. **Wider bands and an honest preview.** Let borrowers choose fewer, wider bands, and show the expected chop cost from past price data before they borrow.

Test all five in the simulation job: replay ETH price history from 2021 to 2026 and measure each design's borrower loss and bad debt.

### Ranking the chop-loss fixes

Start with the simple fixes that cut the most time spent inside bands; add the auction later, because it is the strongest fix but the hardest to build.

| Rank | Fix | Cuts chop loss | Build difficulty | Trade-off | When |
| --- | --- | --- | --- | --- | --- |
| 1 | Bands only near the end | Large | Easy | Protection starts later, closer to full liquidation | Version 1 |
| 2 | Buy-back spread (hysteresis) | Medium | Easy | Buys ETH back a little late in a real recovery | Version 1 |
| 3 | Volatility fee to band owners | Medium | Medium | Must never slow conversions during a real crash | Version 1, merged with rank 2 |
| 4 | Wider bands and a cost preview | Small | Easy | Mostly better choices, not a mechanism | Version 1 |
| 5 | Auction of rebalancing rights | Large | Hard | Needs active bidders and a fallback | Version 2 |

**How the auction works.** Bots bid for the exclusive right to trade against the bands for a period. The winner pays rent every block to the borrowers whose bands it trades, and anyone can outbid it. Because the winner keeps all the band trading profit, competition pushes the rent up toward that profit, so most of it returns to borrowers. The idea comes from research on auction-managed AMMs (am-AMM, 2024); Bunni v2 shipped a version. If the winner stops trading for a set number of blocks, the bands reopen to everyone, so a lazy or offline winner cannot block liquidations.

### The combined package: Chop Shield

Fixes 1 to 4 fit together as one version 1 design, with the auction as the version 2 upgrade.

1. **Bands only in the last zone** before full liquidation. The position is plain ETH the rest of the time.
2. **One fee that merges ranks 2 and 3:** a buy-back spread that widens with volatility and is paid to band owners. Selling ETH out of a band (the crash direction) stays cheap, so conversions never stall in a crash. Only buying ETH back pays the spread.
3. **Simple volatility measure,** to keep the code safe: the gap between a fast and a slow average of the oracle price. Spread = base + k × gap, capped, for example between 0.1% and 1%. There are no complex statistics on-chain.
4. **Borrower chooses band width,** and the app shows the chop cost those bands would have had over past price data.
5. **Version 2: the auction** on top, with the reopen fallback.

The simulation job should compare plain bands, Chop Shield version 1 and version 2 on the same 2021–2026 price history.

### MEV: a cost, not a collapse risk

MEV is the profit bots make by choosing the order of transactions in a block. Here, bots race to do the band conversions and keep the discount, so borrowers pay more than they need to. It cannot break the peg or drain the protocol; it makes the product more expensive and less competitive. Fixes: price bands tightly against the oracle so the discount is small, and use the auction in idea 1 so the bots' profit goes to borrowers.

### Oracle: audits do not remove it

An audit checks that the code does what it says; it cannot stop correct code from receiving a wrong price. In October 2022 Mango Markets lost about $114M with no code bug: the attacker pumped a thin market that the oracle read. On October 10, 2025, a price on one exchange briefly showed USDe far below $1 and triggered liquidations there.

- Read Chainlink plus a Uniswap time average, and take the median.
- Cap how far the price may move per update, and reject stale prices.
- Convert bands against a smoothed price, so a one-block spike converts almost nothing.
- Accept only deep-market collateral (ETH), which is expensive to manipulate.
- If sources disagree, pause new borrowing, but never redemption.

### Gas and complexity

- Share bands across borrowers: each band holds one total, and borrowers own shares of it, so a swap updates a few bands, not thousands of positions (crvUSD already does this).
- Find active bands with a bitmap, like Uniswap's tick bitmap, and cap how many bands one swap may cross.
- Limit band count per borrower, for example 4 to 20.
- Run it on cheaper chains IMD supports (Base, Robinhood Chain) once mainnet is approved.
- Ship Hooked Liquity first, and add soft liquidation as version 2 once the first hook has run safely.

## Why ETH backs the coin, not IMD

The coin must stay solvent even if IMD goes to zero; that rules out IMD as the main collateral but leaves it several useful roles. "Ethereum" here means ETH the asset; the contracts can still run on any chain IMD supports.

### Why not IMD as collateral

- **It falls at the worst moment.** A crisis that makes people sell the stablecoin also makes them sell IMD. Liquidations then sell IMD into its own market, pushing it lower and triggering more liquidations. That loop is exactly how Terra (LUNA) and Iron Finance (TITAN) died.
- **The market is too thin.** IMD peaked near a $39M market cap with about $2.1M peak daily volume. Liquidating a few million dollars of IMD in a crash would move its price sharply and leave bad debt. ETH trades billions a day.
- **Thin markets are cheap to manipulate.** Pushing IMD's price to fool the oracle would cost far less than doing the same to ETH (the Mango Markets pattern).
- **It clashes with POOL4.** Liquidation sales would hit IMD's own burn-hook pool, mixing two systems' risks.
- **Trust.** A stablecoin backed by its own ecosystem token reads as "another Terra" to users and regulators.

### Where IMD fits instead

- **Value flows to IMD:** part of protocol fees buys and burns IMD or pays sIMD stakers, so IMD benefits from the coin's growth without the coin depending on IMD.
- **Small first-loss insurance:** IMD stakers can take the first loss in exchange for yield, sized so the system stays safe even if that layer is wiped out.
- **Payments and pairs:** the coin pays for IMD swarm jobs and pairs with IMD on the launchpad.
- **Builder:** the swarm writes, audits and runs the protocol, which is IMD's real advantage here.

## Protocol options

Chosen: launch as Option 3 (Dual Vault), built from branch A (Option 1) and branch B (Option 2) minting one coin, with swarm agents as the risk team. Later branches are added through a narrow, timelocked registry, without changing deployed contracts.

| Option | What it is | Novelty | Risk to funds | Build effort | Time to testnet | Fit with IMD |
| --- | --- | --- | --- | --- | --- | --- |
| 1. Peg Hook Liquity | Liquity v2-style troves plus the peg hook (asymmetric fees, buy wall, health-aware redemption) | Medium | Low | Medium | Short | High |
| 2. Soft Floor | Option 1, but the last stretch before liquidation is converted gradually in Chop Shield bands instead of all at once | High | Medium | High | Medium | High |
| 3. Dual Vault (chosen start) | One coin, two branches at launch: branch A (Option 1) and branch B (Option 2); borrowers pick one, and both share the redemption floor, stability pools and peg hook | High | Medium | High | Medium | High |
| 4. Full Band | A pure crvUSD-style design in V4 with Chop Shield versions 1 and 2, no troves | High | High | Very high | Long | Medium |
| 5. Peg Hook as a service | No coin of our own at first: a reusable V4 peg-defense hook that existing stablecoins plug into their pools, earning part of the fees | Medium | Low | Low to medium | Shortest | High |

### What each option is good for

- **Option 1** is the safest real stablecoin. Everything in it is proven (Liquity) except the hook, and the hook can never block redemption.
- **Option 2** is the most original protocol with a manageable risk. Bands only near the end means borrowers rarely sit in bands, so chop losses stay small while cascades are softened.
- **Option 3** is the chosen start: branches A and B side by side give borrowers a choice of normal or soft liquidation for little more work than building Option 2, since Option 2 already contains Option 1.
- **Option 4** has the most moving parts and the longest time spent in bands, so chop, MEV and oracle risks are all at their largest.
- **Option 5** has no coin to lose its peg, and builds a track record and fee income. Its weakness is that it depends on other teams adopting it.

### Suggested path

1. Simulate branch A and branch B on the same 2021–2026 ETH price history, including the first-loss vault and the fee split.
2. Build the shared core (coin, branch registry, redemption router, stability pools, first-loss vault), branch A and the peg hook on Sepolia.
3. In parallel, build branch B (Soft Floor bands with Chop Shield version 1); register it on Sepolia once its simulation looks good. A plus B is the Dual Vault launch.
4. Stand up the swarm risk team on testnet: monitoring, keepers and weekly reports; research whether agents should also liquidate.
5. Offer the peg hook to other stablecoins (Option 5).
6. Only after A and B have run safely: Chop Shield version 2 (auction) and a full-band branch (Option 4) through the registry.

### How the options connect without upgrades

Deployed contracts are never changed; each new option is added beside the old ones as a new branch or module.

- **Immutable core.** The coin, redemption and each branch's troves have no proxy and no upgrade key. Admin upgrade keys are a common way stablecoins get drained or captured.
- **Branches.** As in Liquity v2, where several collateral branches all mint the same BOLD coin. Branch A is Option 1 (normal liquidation); branch B is Option 2 (Soft Floor bands). Both mint the same coin and share redemption.
- **Option 3 comes free.** Branches A and B side by side already are the Dual Vault: borrowers pick one.
- **Adding a branch later (Option 4).** Liquity v2 fixes its branches at deployment. Chosen: a registry that can only add new branches, after a long timelock (for example 7 days) and with a small starting debt cap; it can never change, pause or remove existing branches or redemption. That registry is a governance power and must stay this narrow: a new branch is proposed by vote-locked IMD holders (see the yield section), waits out the timelock, then starts with a small debt cap that rises over months.
- **Option 5 needs nothing.** The peg hook is a separate contract that other stablecoins pair with in their own pools.
- **New hook versions.** A V4 pool's hook is fixed when the pool is created. A new hook version means a new pool; protocol-owned liquidity moves over and the old pool keeps working.
- **A bug in an immutable contract.** It cannot be patched. Each branch therefore has a shutdown path, like Liquity v2: if its collateral or oracle fails, it closes to new debt and redemptions wind it down. A fixed branch is then deployed and users move to it.

### Modules to add to whichever option is chosen

- A supply cap that rises slowly after launch.
- An IMD first-loss vault, sized so the system is safe if it is wiped out.
- Part of protocol fees buys and burns IMD or pays sIMD stakers.
- Included at launch: swarm agents as the risk team (details below).

## Protocol structure

One immutable core serves both launch branches, and every branch shares the same redemption floor, oracle, stability pools, first-loss vault and peg pool.

| Layer | Components |
| --- | --- |
| Core: immutable, no upgrade keys | Coin (one stablecoin for all branches) · Branch registry (add-only, 7-day timelock, debt caps) · Redemption router ($1 floor across all branches) · Oracle module (median of sources, caps, stale checks) |
| Branches: borrowers pick one (the Dual Vault) | Branch A: Option 1 (troves, normal liquidation) · Branch B: Option 2 (troves + band hook, Chop Shield) |
| Safety and fees | Stability pools (absorb liquidations; earn 60% of interest) · IMD first-loss vault (takes bad debt first; earns 15% of interest) · Fee splitter (15% gauges, 10% treasury, half of which buys and burns IMD) |
| Markets and incentives | Peg hook pool on Uniswap V4 (asymmetric fees, buy wall) · Gauges and IMD vote-lock (lockers steer the 15% gauge budget) |
| Off-chain | Swarm risk team (monitors, keepers, weekly reports; only public, condition-checked actions) |

Read it top down: the core mints and redeems for the branches; the branches send interest and any bad debt to the safety layer; the fee splitter funds the pool and the gauges; the risk team watches all of it from outside. (The shareable page draws this as a diagram.)

## The IMD first-loss vault

IMD holders deposit into a vault that earns a fixed share of protocol revenue, paid in the stablecoin, and in return their IMD is the first money used if the protocol ever has bad debt. All numbers below are illustrative assumptions for the simulation to test, not promises.

### How it works

- **Deposit:** IMD or sIMD. Accepting sIMD lets stakers keep their normal sIMD rewards and earn vault yield on top.
- **Earn:** a fixed share of protocol revenue (borrow interest, redemption fees, part of hook fees), paid in the stablecoin, not in new tokens.
- **Withdraw:** a 14-day cooldown, so depositors cannot leave the moment trouble appears.
- **Cap:** the vault holds at most 10% of coin supply in value. The system must stay safe even if the vault goes to zero; it is a cushion, not the foundation.
- **Slash limit:** one bad event can take at most 30% of the vault, so a single crash cannot wipe out every depositor.

### Who pays when there is bad debt

Bad debt is when a liquidated borrower's collateral is worth less than their debt. The loss is taken in this order:

1. The borrower's own collateral, as usual.
2. **The first-loss vault.** The stability pool covers the gap at once and is paid back as the vault's IMD is sold gradually over several days, so the vault never dumps IMD into its own thin market in one go.
3. The stability pool of that branch.
4. Spread across the other troves of that branch (Liquity's fallback).

Redemption at $1 is never reduced at any step.

### Example yields

Assumptions: average borrow rate 6% a year; 15% of interest goes to the vault; hook and redemption fees left out. Vault APR = 15% × 6% × coin supply ÷ vault size.

| Vault size | Coin supply $20M | Coin supply $50M | Coin supply $100M |
| --- | --- | --- | --- |
| $1M of IMD | 18% | 45% | 90% |
| $2.5M of IMD | Over the 10% cap | 18% | 36% |
| $5M of IMD | Over the 10% cap | 9% | 18% |

The pattern: yield is high when the vault is small compared with the coin's supply, and falls as more IMD joins. It moves with the market until the vault fills to its cap. On top, depositors carry IMD's price risk and the chance of losing up to 30% per bad-debt event, which is why this yield should sit well above the stability pool's.

### Why it helps IMD

- It creates steady demand to hold and lock IMD, paid from real revenue.
- It adds a cushion for coin holders without making the coin depend on IMD's price.
- Combined with the treasury's IMD buy-and-burn, IMD gains from the coin's growth in two ways.

## Yield farming

Yes: farmers get Curve-style gauges and vote-locking, but paid from real protocol revenue instead of printing a new token, and the votes are made with locked IMD.

### How Curve does it, and what we change

Curve pays liquidity providers in newly minted CRV. Holders lock CRV for up to 4 years as veCRV, which lets them vote each week on which pools get the CRV, boosts their own rewards and earns fees. Other protocols then pay lockers "bribes" to vote for their pools: the Curve wars. The high yields came mostly from CRV inflation, which kept selling pressure on CRV.

IMD's supply can never grow, so there is nothing to print, and printing would also be rented demand (design rule 8). Instead:

- **The budget is real revenue.** Proposed split of borrow interest: 60% stability pools, 15% first-loss vault, 15% liquidity gauges, 10% treasury (half of it buys and burns IMD). For comparison, Liquity v2 sends 75% of interest to its stability pools.
- **Lock IMD to vote.** Lock IMD or sIMD for 1 week to 2 years; longer locks get more votes. Each week, lockers decide how the 15% gauge budget is split across pools.
- **Lockers earn too:** part of the treasury share, plus bribes from protocols that want liquidity for the coin in their own pools.
- **Boost:** LPs who also lock IMD can earn up to 2.5 times the base gauge rewards, as on Curve.
- **Narrow powers:** locker votes control the gauge budget and propose registry branches; they can never touch redemption, existing branches or collateral rules.

### Ways to farm the protocol

| Route | Earns | Main risk |
| --- | --- | --- |
| Stability pool (branch A or B) | Interest share plus liquidation gains (collateral bought at a discount) | Losses only after the first-loss vault is used up |
| LP in the peg hook pool | Swap fees (higher when off-peg) plus gauge rewards | Low: a stable-to-stable pool moves little |
| IMD first-loss vault | Revenue share in the coin, high when the vault is small | First to lose in bad debt; IMD price |
| Lock IMD | Votes, a treasury share and bribes | IMD price; locked until the lock ends |
| Loop: borrow the coin at a low rate, deposit it in a pool | The gap between the borrow rate and the pool's yield | Liquidation and redemption of the loan |
| Partner pools on other DEXs | Gauge rewards if lockers vote for them | That DEX's own risks |

### Will yields be high?

Early on, yes for some routes: revenue is fixed by the coin's borrowing while TVL is still small, so APRs can reach tens of percent, as the vault table shows. They fall as TVL grows, which is what real yield looks like. Curve-level numbers that last for years would need a new inflationary token; that is not recommended. A fixed, time-limited launch bonus funded by the treasury or by partners is a safer way to attract first farmers.

## Game layer: the Stability Grid

Stability pool depositors play a no-loss grid game with the interest their deposits earn, in crews, and anyone who cashes out rewards early pays those who stay; principal is never at risk. The mechanics are adapted from [SLVR](https://slvr.fun/about) and ORE, minus the real-money lottery.

### 1. No-loss grid on the stability pool

- Each round (for example every hour) has a 5×5 grid of 25 squares.
- Depositors assign their deposit's weight to one or more squares. They never move or risk the deposit itself.
- The interest the whole pool earned that round is the prize. A public random beacon (drand, as SLVR uses) picks the winning square after choices close.
- Depositors on the winning square split the round's interest in proportion to their weight; a small, fixed part always goes to everyone, so nobody earns zero over a long run.
- Choices are hidden until the round closes (commit, then reveal), so bots cannot pile onto the emptiest square at the last second.

This is prize-linked savings, like PoolTogether, with a faster, social game on top. Average yield is the same as plain interest; the game changes how it is shared and makes holding the coin fun.

### 2. Refining fee on rewards

Cashing out rewards immediately costs 10%, which is paid to everyone who keeps their rewards in the pool. ORE and SLVR use this. Leaving is always possible; staying simply pays more. It applies to rewards only, never to deposits or redemption.

### 3. Crews on the grid

- Up to 12 depositors form a crew, led by a captain who holds an IMD NFT seat.
- A crew picks squares together and shares any win across its members.
- The crew's boost grows with how long its members stay deposited, and grows faster through stress events; a member leaving during stress cuts the whole crew's boost, never anyone's deposit.
- Seasons add a leaderboard, plus a shared goal (for example total pool size) that pays a bonus to every crew when reached.

### Rules and open questions

- Never a real-money lottery on the coin: only interest is played, and the stability pool's job (absorbing liquidations) always comes first.
- Legal review: prize-linked savings is allowed in some places and restricted in others.
- Simulation: check that rounds, crews and the refining fee keep the stability pool larger and steadier than plain interest would.

## Swarm risk team

Agents watch the protocol, run its keeper jobs and publish reports, but can only call public functions whose conditions the contracts check themselves; if every agent went offline, anyone could call the same functions.

| Role | What agents do | Limit | Status |
| --- | --- | --- | --- |
| Monitoring | Track collateral ratios, oracle gaps, pool depth, staking-token pegs and vault size; raise alerts | Read only | Launch |
| Keepers | Trigger the buy wall, update redemption fees, reopen bands if an auction winner goes idle | Public functions; the contract checks the condition | Launch |
| Circuit breaker | Pause new borrowing in a branch when the oracle sources disagree | Only when the contract confirms the disagreement; never redemption | Launch |
| Reports and reviews | Weekly public risk report; simulate parameter changes; review branch proposals before the registry vote | Advice only | Launch |
| Liquidations | Possibly act as a backstop liquidator | Same rules as any liquidator | Research |

**The open question on liquidations.** Professional MEV bots liquidate within the same block; agents take seconds to minutes, so they would usually lose that race. They may still be useful as a backstop: small or unprofitable positions that bots skip, or moments when gas spikes and bots step back. The testnet game day should measure how often a liquidation goes untaken and how quickly agents would fill that gap.

Agents are paid per job from the treasury through IMD's job rail, so the protocol becomes steady paid work for the swarm.

## Other ideas and what to avoid

The two deep dives are the main track; the rest are add-ons or parked.

| Idea | Status | Note |
| --- | --- | --- |
| Two-tranche split (stable senior + leveraged junior token) | Add-on | Like f(x), Resolv RLP and Ampleforth SPOT; the junior token could list on the IMD launchpad |
| Agents as the risk team | Add-on | Swarm agents run liquidations and monitoring and publish risk reports; they can trigger only bounded, pre-coded actions and can never block redemptions |
| Compute dollar (pegged to AI inference cost) | Watching | Another team is reportedly building one; compare once its GitHub is found |
| Inflation-tracking stablecoin | Dropped | Not pursued |

Avoid:

- seigniorage or share-token designs, including "IMD is the share token";
- IMD or sIMD as main collateral (Terra and Iron reflexivity);
- subsidised yield to attract deposits;
- off-chain delta-neutral backing without on-chain proof;
- penalties on selling;
- agent oracle panels as live market price feeds (they suit slow, judgement-type data only).

## Building it on IMD

Each step is one swarm job with one deliverable and clear acceptance tests; per the user, IMD now deploys to Ethereum and Robinhood Chain mainnet as well as Sepolia, with Base and Solana expected next, but this project's jobs should stay on Sepolia until step 11, and contract and frontend jobs are premium tier (top model at high effort).

| # | Job | Tier | Deliverable |
| --- | --- | --- | --- |
| 1 | Re-verify this history against primary sources | Standard | Verified history with citations |
| 2 | Turn each past failure into a stress scenario | Standard | Stress-scenario list |
| 3 | Spec for Hooked Liquity with soft liquidation: states, invariants, parameters | Standard | Spec document |
| 4 | Python simulation of the peg and the bands under the stress scenarios | Standard | Simulation code, charts, parameter sweep |
| 5 | Core contracts in Foundry (troves, redemption, stability vault) | Premium | Contracts plus invariant and fuzz tests |
| 6 | Peg hook (asymmetric fees, buy wall) | Premium | Hook plus fork tests on Sepolia |
| 7 | Soft-liquidation band hook | Premium | Hook plus fork tests on Sepolia |
| 8 | Adversarial audit by several independent seats | Standard | Findings and fixes, per round |
| 9 | Frontend on IPFS | Premium | Borrow, redeem and vault interface |
| 10 | Testnet game day: price crash, oracle shock, pool drain | Standard | Post-mortem |
| 11 | Outside the swarm: professional audit, bug bounty, legal review | People | Go or no-go for mainnet |

Invariants every spec should state:

- Total coin supply is never more than total collateral value divided by the minimum ratio.
- Redemption is always callable while supply is above zero.
- The hook never charges above its maximum fee and never reverts a swap toward $1.
- A stale oracle switches the system to safe mode: minting off, redemption on.
- The junior or insurance layer always takes losses before regular holders.

## Sources

- [Bankless: Inside IMD, Ethereum's new AI swarm experiment](https://www.bankless.com/read/inside-imd-ethereum-s-new-ai-swarm-experiment)
- [KuCoin: What Is IMD Token?](https://www.kucoin.com/blog/imd-token-community-owned-ai-agents)
- [IMD Explorer](https://explorer.imd.fun/)
- [Stablecoin Insider: algorithmic stablecoin guide 2026](https://stablecoininsider.org/what-is-an-algorithmic-stablecoin-full-guide-2026/)
- [LI.FI: algorithmic stablecoins, how they work and the risks](https://li.fi/knowledge-hub/algorithmic-stablecoins-how-they-work-the-risks-and-where-to-find-them)
- [Eco: top algorithmic stablecoins 2026](https://eco.com/support/en/articles/12257457-top-algorithmic-stablecoins-2026)

History before 2024 and the protocol mechanics are from memory of public docs and post-mortems (approximate); job 1 re-checks them.
