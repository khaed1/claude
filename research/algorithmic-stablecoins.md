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

Chosen: start with Options 1 and 2 as two branches of one coin. The other options can be added later as new branches or modules, without changing deployed contracts.

| Option | What it is | Novelty | Risk to funds | Build effort | Time to testnet | Fit with IMD |
| --- | --- | --- | --- | --- | --- | --- |
| 1. Peg Hook Liquity | Liquity v2-style troves plus the peg hook (asymmetric fees, buy wall, health-aware redemption) | Medium | Low | Medium | Short | High |
| 2. Soft Floor | Option 1, but the last stretch before liquidation is converted gradually in Chop Shield bands instead of all at once | High | Medium | High | Medium | High |
| 3. Dual Vault | One coin, two vault types: the borrower picks a normal trove or a full soft-band vault; both share the redemption floor, stability pool and peg hook | High | Medium to high | Very high | Long | High |
| 4. Full Band | A pure crvUSD-style design in V4 with Chop Shield versions 1 and 2, no troves | High | High | Very high | Long | Medium |
| 5. Peg Hook as a service | No coin of our own at first: a reusable V4 peg-defense hook that existing stablecoins plug into their pools, earning part of the fees | Medium | Low | Low to medium | Shortest | High |

### What each option is good for

- **Option 1** is the safest real stablecoin. Everything in it is proven (Liquity) except the hook, and the hook can never block redemption.
- **Option 2** is the most original protocol with a manageable risk. Bands only near the end means borrowers rarely sit in bands, so chop losses stay small while cascades are softened.
- **Option 3** gives borrowers a choice but doubles the code and the audits. It is a later merge of Options 1 and 4, not a starting point.
- **Option 4** has the most moving parts and the longest time spent in bands, so chop, MEV and oracle risks are all at their largest.
- **Option 5** has no coin to lose its peg, and builds a track record and fee income. Its weakness is that it depends on other teams adopting it.

### Suggested path

1. Simulate branch A (Option 1) and branch B (Option 2) on the same 2021–2026 ETH price history.
2. Build the shared core (coin, redemption, stability pools), branch A and the peg hook on Sepolia.
3. In parallel, build branch B (Soft Floor bands with Chop Shield version 1); add it to Sepolia once its simulation looks good.
4. Offer the peg hook to other stablecoins (Option 5).
5. Only after A and B have run safely: Chop Shield version 2 (auction) and a full-band branch (Option 4).

### How the options connect without upgrades

Deployed contracts are never changed; each new option is added beside the old ones as a new branch or module.

- **Immutable core.** The coin, redemption and each branch's troves have no proxy and no upgrade key. Admin upgrade keys are a common way stablecoins get drained or captured.
- **Branches.** As in Liquity v2, where several collateral branches all mint the same BOLD coin. Branch A is Option 1 (normal liquidation); branch B is Option 2 (Soft Floor bands). Both mint the same coin and share redemption.
- **Option 3 comes free.** Branches A and B side by side already are the Dual Vault: borrowers pick one.
- **Adding a branch later (Option 4).** Liquity v2 fixes its branches at deployment. We could add a registry that can only add new branches, after a long timelock (for example 7 days) and with a small starting debt cap; it can never change, pause or remove existing branches or redemption. That registry is a governance power and must stay this narrow. The alternative is no registry, and a new coin version for big changes.
- **Option 5 needs nothing.** The peg hook is a separate contract that other stablecoins pair with in their own pools.
- **New hook versions.** A V4 pool's hook is fixed when the pool is created. A new hook version means a new pool; protocol-owned liquidity moves over and the old pool keeps working.
- **A bug in an immutable contract.** It cannot be patched. Each branch therefore has a shutdown path, like Liquity v2: if its collateral or oracle fails, it closes to new debt and redemptions wind it down. A fixed branch is then deployed and users move to it.

### Modules to add to whichever option is chosen

- A supply cap that rises slowly after launch.
- An IMD first-loss vault, sized so the system is safe if it is wiped out.
- Part of protocol fees buys and burns IMD or pays sIMD stakers.
- Swarm agents as the risk team: keepers, monitors and weekly risk reports, with only bounded actions.

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
