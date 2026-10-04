# The Pad: v1 architecture

The Pad is an IMD-paired token launchpad on Robinhood Chain (chain ID 4663). The swarm builds and audits it, and fees flow to $PAD stakers, IMD workers, growth and the treasury.

Status: **v1 design, 4 October 2026.** This replaces the first draft in [`PLAN.md`](PLAN.md), which keeps the competitor analysis. Names (**the Pad**, **$PAD**, **sPAD**) are placeholders.

Items marked **[DEV]** depend on answers from the IMD / POOL4 developer. Section 12 lists each with its fallback.

---

## 1. What v1 does

1. Anyone launches a coin **paired with IMD**. It starts on a **bonding curve** and **graduates** into a Uniswap v4 pool run by the Pad's hook, with liquidity locked forever.
2. Every trade, on the curve or in the pool and through any router, pays a **1.5% base fee**, plus an optional **0–3% coin tax** chosen at launch.
3. Users pay with **ETH or IMD**. The router swaps ETH to IMD inside the same transaction.
4. The **IMD swarm** builds each graduated coin's website for free, decides community takeovers (CTO), must audit every launchpad version before it goes live, and can be paid from a coin's own "swarm budget".
5. Protocol fees go **40% to sPAD stakers, 25% to IMD workers, 20% to growth, 15% to the treasury**.
6. **$PAD** is paired with **IMD**, like every coin on the Pad. It is sold on its own IMD bonding curve (target ≈ 8,460 IMD, about 20 ETH) and graduates into **our own fork of POOL4's `CappedBurnHook`**, adapted for an IMD pair (section 5.4).
7. Creators can link their coin's **X account** and get a badge.

**Not in v1:** swap page, trading rewards and referrals, milestone bounties, scam flags, custom swarm-built coins, POOL4-style burn mode, dead-coin migration, other chains. See section 13.

---

## 2. System overview

```
                         ┌──────────────────────── Governance ────────────────────────┐
                         │  Safe multisig → Timelock → PadConfig (bounded settings)    │
                         │  Guardian (instant): pause NEW launches only                │
                         └──────────────────────────────┬─────────────────────────────┘
                                                        │ reads settings
 Users / creators ──► PadRouter ──┬──► BondingCurve (pre-graduation trades, all coins)
   (ETH or IMD)        │          │         │ graduate()
                       │          │         ▼
                       │          └──► Uniswap v4 PoolManager ◄──► PadHook (fees, locked LP)
                       │                    ▲
                       └── ETH⇄IMD leg ─────┘ (IMD/ETH pool; POOL4 market when live on RH)

 PadFactory ── deploys PadToken (fixed 1B supply) → BondingCurve
 VersionRegistry ── lists versions; activation needs a swarm audit attestation

 Fees (IMD) ─► CreatorVault (creator share + creator tax, CTO-able)
            ─► PadToken dividends (holder tax)
            ─► SwarmBudget (swarm-budget tax, per coin)
            ─► FeeSplitter ─┬─ 40% PadBuyer (IMD → $PAD) ─► RewardDripper ─► StakedPAD (sPAD, ERC-4626)
                            ├─ 25% WorkerFund ─► IMD worker rewards address [DEV]
                            ├─ 20% GrowthFund (graduation websites, oracle costs, grants)
                            └─ 15% Treasury (Safe)

 AttestationVerifier ◄── IMD oracle attestations (EIP-712) ── used by CTOModule, VersionRegistry
 SocialRegistry ◄── X-link vouchers (Pad verifier key)

 $PAD:  PadSale (IMD curve, ≈8,460 IMD) ─► PadMarketHook (CappedBurnHook fork) $PAD/IMD ◄─ MarketController (owner)
        AirdropDistributor (5%, Merkle), TeamVesting (2%), liquidity reserve (3%, treasury)

 Offchain: static frontend (IPFS + domain) · indexer · Swarm Relay · keeper bot ·
           token auto-verifier · X OAuth service
```

---

## 3. Coin lifecycle

```
launch ──► CURVE phase ──────────────────────────► GRADUATED (forever)
           • trades on BondingCurve                  • trades in v4 pool (PadHook)
           • snipe tax + max-buy window              • any router / aggregator
           • base fee + coin tax                     • base fee + coin tax
           • progress bar to target                  • free swarm website ordered
                    │ last buy fills the curve
                    ▼
           graduate(): seed pool with raised IMD + reserved tokens at the curve's final price,
           LP owned by PadHook (no remove function)
```

### 3.1 Coin parameters (v1 defaults, saved per coin at launch)

| Parameter | Default | Adjustable for future launches |
|---|---|---|
| Total supply | 1,000,000,000 (18 decimals), no mint, no owner | No (fixed per version) |
| Sold on curve (S) | 800,000,000 (80%) | No |
| Reserved for pool (R) | 200,000,000 (20%) | No |
| Graduation target (E) | **2,060 IMD** of net raise (≈ $65k market cap at graduation, ≈ $4k at launch, at IMD ≈ $6.30) | Yes, 1,000–10,000 IMD, timelocked |
| Graduation fee | 1% of raised IMD → GrowthFund | Yes, 0–2% |
| Launch fee | 1 IMD → FeeSplitter | Yes, 0–10 IMD |
| Snipe tax | 50% → 0% linear over 20 s from launch, buys only | Yes, start ≤ 90%, duration ≤ 120 s |
| Max buy window | first 60 s: ≤ 2% of supply per wallet | Yes, bounded |
| Initial dev buy | Optional, atomic, exempt from snipe tax and max-buy | – |

### 3.2 Curve math (constant product with virtual reserves)

The curve is a constant product of a virtual IMD reserve `x` and a virtual token reserve `y`. With S sold on the curve, R reserved and target E, the curve is set so it **ends exactly at the pool's opening price** E/R:

```
y0 = S + S·R/(S−R)       = 800M + 266.67M = 1,066.67M   (virtual token reserve)
x0 = E/3                 (for S = 4R)                     (virtual IMD reserve)
k  = x0 · y0
price(t)  = x / y
start mcap = 1B · x0/y0  ≈ 0.3125 · E   (≈ 644 IMD ≈ $4k)
final price = E / R      → graduation mcap = 5 · E (≈ 10,300 IMD ≈ $65k)
```

- Buy `dx` IMD (after fees): `dy = y − k/(x+dx)`. Sell `dy` tokens: `dx = x − k/(y+dy)`.
- **Last buy** is capped at the tokens left. Any excess IMD is refunded in the same transaction, and graduation runs right away.
- Rounding always favours the curve, so it can never owe more IMD than it holds (invariant tested).

### 3.3 Graduation

`graduate(coin)` runs inside the buy that completes the curve. If that fails, for example on gas, anyone can call it.

1. Take the graduation fee: `g = 1%·E` → GrowthFund. To keep the price continuous, **burn `1%·R` tokens**.
2. Initialize the v4 pool `{IMD, coin, fee 0, tickSpacing 200, hooks: PadHook}` at `sqrtPrice(E/R)`. Only PadHook can initialize pools that use it.
3. Add a full-range position with `0.99E` IMD and `0.99R` tokens. **PadHook owns it and has no remove function.**
4. Mark the coin graduated. The curve rejects any further trades.
5. Emit `Graduated`. The Swarm Relay orders the free website (section 7.2).

No one can block graduation by creating the pool first, because the hook rejects any `initialize` it didn't start. A pool someone else creates elsewhere (e.g. a v3 coin/IMD pool) can't affect it.

---

## 4. Fees

### 4.1 Fee schedule (per coin, fixed at launch)

| Part | Rate | Paid in | Goes to |
|---|---|---|---|
| Protocol | **1.0%** | IMD | FeeSplitter |
| Creator base | **0.5%** | IMD | CreatorVault (coin's fee recipient) |
| Coin tax (optional) | **0–3%**, chosen at launch, never changes | IMD | Any split the creator picks between **creator**, **holders** (dividends), and **swarm budget** |

- The create page's default is **0.5% tax to holders**, so a default coin costs 2% per trade.
- Fees are taken on the **IMD side**: from the input on buys, from the output on sells. This applies on the curve (BondingCurve) and in the pool (PadHook).
- The total fee is shown on every coin page and in the trade box, and can be read onchain (`coinInfo`).

### 4.2 Fee collection in the hook (after graduation)

- Pool LP fee is 0, so all fees go through the hook. Hook permissions: `beforeInitialize`, `beforeAddLiquidity`, `beforeRemoveLiquidity` (both reject outsiders), `beforeSwap`, `afterSwap`, `beforeSwapReturnDelta`, `afterSwapReturnDelta`. The hook address is mined to match these flags.
- **Fixes carried over from the Pepes audit:**
  - The fee is computed on the **actual filled amount**. When a price limit cuts a trade short, the fee is settled in `afterSwap` from the real delta, so partial fills are never overcharged (Pepes' open medium finding).
  - **Dividends are never paid out while the PoolManager is unlocked by an outside caller** (Pepes' high finding: flash-borrowed tokens could capture dividends).
  - Sells that fill nothing are rejected, so empty pools can't be pushed to extreme prices for free.
  - `permit` accepts `value >= amount`.
  - Events carry the real trader passed by the router in `hookData`, falling back to `sender`, never `tx.origin`.
- Fees are held as PoolManager ERC-6909 claims and flushed to their destinations. Anyone can flush; the router flushes on its own trades.

### 4.3 Where protocol IMD goes (FeeSplitter)

| Bucket | Share | Allowed range (timelocked) | v1 use |
|---|---|---|---|
| sPAD stakers | 40% | 25–60% | `PadBuyer` buys $PAD with it on the market; `RewardDripper` streams the $PAD into the sPAD vault |
| IMD workers | 25% | 15–35% | WorkerFund → IMD worker rewards address **[DEV]** |
| Growth | 20% | 0–30% | Graduation websites, oracle costs, capped grants. The "growth ↔ stakers" dial moves this toward stakers over time. |
| Treasury | 15% | 5–20% | Safe multisig |

Inflows: protocol fee (curve and hook), launch fees, snipe tax. Graduation fees go straight to GrowthFund. `distribute()` is permissionless.

---

## 5. Contracts

Solidity 0.8.26, `via_ir`, EVM `cancun` (transient storage), Foundry, Uniswap v4-core pinned. **No proxies.** Every contract is verified on Sourcify and Blockscout.

### 5.1 Launch and trading (one set per version, immutable)

**`PadFactory`**
```solidity
struct LaunchParams {
    string name; string symbol; string metadataURI;   // logo, description, socials (ipfs/https only)
    address feeRecipient;                              // creator fee recipient
    uint16 taxBps;                                     // 0..300
    uint16 taxToCreatorBps; uint16 taxToHoldersBps; uint16 taxToSwarmBps; // sum = 10_000 (if taxBps > 0)
    bytes32 salt;
}
function launch(LaunchParams calldata p) external returns (address coin); // called via PadRouter
event CoinLaunched(address indexed coin, address indexed creator, LaunchParams p, CoinSnapshot snap);
```
It deploys a `PadToken` with full bytecode, not a minimal proxy, because scanners flag proxies. The whole supply is minted to `BondingCurve`, and the coin's settings snapshot is saved.

**`PadToken`**: ERC-20 + EIP-2612 permit, fixed supply, no owner, no exemptions.
- Holder dividends in IMD: O(1) "reward per share" accounting, `claim()`, `pendingDividends(addr)`.
- The curve, PoolManager, PadHook and `0xdead` are excluded from the eligible supply.
- `distribute()` does nothing while the PoolManager is unlocked by an outside caller.

**`BondingCurve`**: one contract holding the state of every coin's curve.
```solidity
function buy(address coin, uint256 imdIn, uint256 minOut, address to) external returns (uint256 out);
function sell(address coin, uint256 tokensIn, uint256 minImdOut, address to) external returns (uint256 out);
function graduate(address coin) external;            // permissionless once full
function quoteBuy(address coin, uint256 imdIn) external view returns (uint256 out, uint256 fee);
function quoteSell(address coin, uint256 tokensIn) external view returns (uint256 out, uint256 fee);
function progress(address coin) external view returns (uint256 raised, uint256 target);
```
Trading functions accept calls only from `PadRouter`, so snipe tax and max-buy apply cleanly. **Selling is never restricted.**

**`PadHook`** (Uniswap v4 hook + owner of locked LP): pool initialization and seeding (called only by `BondingCurve.graduate`), fee logic (section 4.2), `flush(coin)`. It has **no** liquidity-removal function.

**`PadRouter`**: the single entry point for the website.
```solidity
function launch(LaunchParams calldata p, uint256 devBuyImd, uint256 minOut) external payable returns (address, uint256);
function buy(address coin, uint256 amountIn, bool payEth, uint256 minOut, uint256 deadline, bytes32 ref) external payable;
function sell(address coin, uint256 amountIn, bool receiveEth, uint256 minOut, uint256 deadline, bytes32 ref) external;
function sellWithPermit(..., uint8 v, bytes32 r, bytes32 s) external;
```
- It routes automatically: curve before graduation, v4 pool after.
- `payEth` / `receiveEth` adds the ETH ⇄ IMD hop through the **IMD/ETH pool key stored in `PadConfig`** (the hookless pool today, the POOL4 market on Robinhood when live).
- `ref` is recorded in events now and used by referrals in v1.1.
- The router holds no funds between transactions.

**`PadLens`** (view only): coin lists with pagination, coin info, quotes across curve and pool, user positions, pending dividends and creator fees.

### 5.2 Creator side

**`CreatorVault`**: IMD balance per coin, `claim(coin)`, `setFeeRecipient(coin, newRecipient)` (current recipient only, future earnings).

**`CTOModule`**: community takeover, decided by the swarm.
1. `propose(coin, newRecipient, attestation)` needs an **IMD oracle attestation** answering "yes" to the takeover question for this coin. The protocol multisig or a holder-backed requester can submit it.
2. A **3-day public notice** follows, then a **3-day execution window**. Anyone executes. The creator moving fees during the notice does not cancel it.
3. Execution calls `CreatorVault` to change the recipient. Fees already accrued stay with the old recipient.

### 5.3 Fees and $PAD economy

| Contract | Key functions | Notes |
|---|---|---|
| `FeeSplitter` | `distribute()` | Shares read from `PadConfig`; IMD only |
| `PadBuyer` | `buy()` | Permissionless and rate-limited: spends the stakers' IMD on $PAD in the `PadMarketHook` pool in small chunks, with a price guard (block-lagged reference price, max slippage), and sends the $PAD to `RewardDripper`. Keeper tip capped. |
| `RewardDripper` | `drip()` | **Fork of POOL4's `RewardDripper`**, asset = $PAD. Streams $PAD into the vault at a bounded rate (rate ceiling and per-call cap), so no one can stake just before a large payout. Never drips into an empty vault, so rewards wait until staking opens. Also receives up to 30% of trimmed $PAD from `PadMarketHook`. |
| `StakedPAD` (sPAD) | `deposit`, `redeem` (ERC-4626) | **Fork of POOL4's `StakedIMD`**, asset = $PAD. Auto-compounding: rewards raise the $PAD value of each sPAD share; no claim step. One-block hold blocks same-block deposit → redeem. No lockup in v1. The original's owner powers (pause, rescue of any balance including staked funds) sit behind the 7-day timelock and are renounced once the vault has run safely for a set period. |
| `WorkerFund` | `release()` | Sends its balance to `workerRewardsAddress` (set by timelock) **[DEV]**; accrues until it's set |
| `GrowthFund` | `payJob(…)`, `grant(…)` | Pays swarm jobs via the Relay and grants via the multisig; per-epoch spending cap; every payment emits a reason and reference |
| `SwarmBudget` | `requestSpend(coin, amount, specHash)`, `release(requestId)` | Per-coin escrow funded by the swarm-budget tax. Only the coin's fee recipient can request; the Relay releases to pay that job; per-request cap; job ID recorded onchain. |

### 5.4 $PAD launch (one-time)

| Contract | Role |
|---|---|
| `PadSale` | Bonding curve in **IMD**: 600M $PAD sold (60%), target **≈ 8,460 IMD** (≈ 20 ETH at 1 ETH ≈ 423 IMD; fixed in IMD at deploy), 300M reserved for the pool (30%). Same curve math with S = 2R: start market cap ≈ 7,050 IMD (~$44k), graduation market cap ≈ 28,200 IMD (~$178k), pool at graduation ≈ 8,460 IMD + 300M $PAD (~$107k). Buyers can pay with ETH through `PadRouter` (ETH → IMD in the same transaction). Two-way (sell back any time). 1% sale fee → FeeSplitter. |
| `PadMarketHook` | **Fork of POOL4's `CappedBurnHook`** (MIT, verified on Etherscan at `0xc6c965bd…2840`), adapted for an **IMD pair** and deployed on Robinhood with the Robinhood PoolManager. $PAD/IMD full-range market, 1% LP fee, capped burn and IMD backstop. At graduation `PadSale` initializes it at the final curve price and calls `openMarket` with the raised IMD and 300M $PAD, then hands ownership to `MarketController`. Details in section 5.4.1. |
| `MarketController` | The hook's owner. Limits what the owner can do (section 5.4.1). |
| `AirdropDistributor` | 5% (50M) Merkle claim for IMD seat holders and sIMD stakers (snapshot published in advance) |
| `TeamVesting` | 2%: 6-month cliff, 18-month linear |
| Liquidity reserve | 3% held by the treasury Safe behind the timelock, only for adding $PAD liquidity later through `fundInventory` (needs $PAD and IMD in proportion) |

#### 5.4.1 The POOL4 fork for $PAD

What we take from POOL4's verified source (`CappedBurnHook`, Solidity 0.8.30, solady, v4-core):

- **One hook per market.** The hook's token is fixed in the constructor, and the original hard-codes **native ETH** as the other side (`currency0 = address(0)`). A $PAD/**IMD** market therefore needs the changes in the table below. Constructor: `owner, poolManager, token, burnSink, rewardsRecipient, rewardShareBps (≤ 30%), minTrimTokens, lpFee, tickSpacing`.
- **Hook permissions:** `beforeInitialize`, `beforeAddLiquidity` (both hook-only) and `afterSwap`. The hook address must be mined for these flags.
- **Fees:** a normal pool fee (1% on mainnet), collected on every swap into a fee ledger, in both the quote asset and the token, and paid out with `withdrawFees(recipient)` by the owner.
- **Burn:** after sells, tokens above `inventoryCap` are removed: at least 70% go to `burnSink`, up to 30% to `rewardsRecipient`. The removed quote asset (ETH in the original, IMD in ours) funds a backstop band above the price, rebalanced by a permissionless keeper.

**Changes for our fork:**

| Item | Our setting or change |
|---|---|
| **Quote asset: IMD instead of native ETH** | The math assumes quote = `currency0`, token = `currency1`. v4 sorts currencies by address, so we **mine the $PAD token address to be above IMD's (`0x5F7B…7127`)**. IMD is then `currency0` and all price and amount math stays unchanged. We replace only the native-ETH plumbing with ERC-20 handling: `currency0 = IMD` in `poolKey()`; `openMarket`/`fundInventory` pull IMD with `transferFrom` instead of `msg.value`; settlements use `sync` + transfer + `settle` instead of `settle{value}`; payouts, keeper tips and the retained backstop pay IMD with `safeTransfer` instead of `safeTransferETH`; `receive()` is removed; `eth*` names become `quote*`. |
| ETH-sized constants | Retuned in IMD: rebalance threshold (0.1 ETH → ~40 IMD), keeper tip (0.002 ETH → ~1 IMD), max keeper tip (0.1 ETH → ~40 IMD) |
| Tests | Port POOL4's tests (repo due next week) to the IMD pair, plus fork tests on Robinhood with real IMD |
| Compiler target | Rebuild with `evm_version = cancun`. The original is compiled for `osaka`, which Robinhood Chain may not support; Pepes runs `cancun` there. Fork tests must pass on Robinhood. |
| `burnSink` | `PadBurner`: calls `$PAD.burn()` so supply really drops, instead of sending tokens to a dead address |
| `rewardsRecipient` | `RewardDripper` (section 5.3): 15% of trimmed $PAD goes to stakers (allowed up to 30%) |
| Fee recipient | `MarketController.collectFees()` (permissionless) → IMD fees straight to FeeSplitter; $PAD fees burned or sent to stakers |
| Cap settings | Starting proposal: `capFloor` = 150M $PAD (half the opening pool), `capDecayTokensPerDay` = 500k $PAD (0.05% of supply). Both adjustable later through the timelock (`setCapDecay`, `setCapFloor`). Section 5.4.2 explains the effect. |
| Owner | `MarketController`, never an EOA |

**`MarketController`** wraps the owner powers, which POOL4 documents as trusted:

| Owner power in the hook | In MarketController |
|---|---|
| `withdrawFees` | Permissionless; always to the fixed fee route |
| Policy setters (cap floor, decay, ratchet, keeper tip, rebalance, reward share ≤ 30%) | Timelock (48 h) |
| `setBurnSink`, `setRewardsRecipient` | Timelock (7 days) |
| `fundInventory` (add liquidity) | Timelock; only from the liquidity reserve + treasury |
| `closeMarket` (withdraw the **whole** position) and `withdrawRetainedEth` | **Not exposed.** Optional emergency path only with a 7-day timelock **and** a swarm audit attestation that names a defect, with funds sent only to a new `PadMarketHook` |
| `initializePool`, `openMarket` | Called once by `PadSale` at graduation, before ownership moves |

The fork is unaudited code, so it is audited by the swarm together with our contracts (section 10), plus any audit the POOL4 developer has.

#### 5.4.2 How the burn behaves day to day

- **The cap:** the market starts with a cap equal to the $PAD it opened with (300M).
- **Buys lower the cap:** when buyers take $PAD out of the pool, the cap follows the pool's holdings down. It falls at most `capDecayTokensPerDay` on average, and never below `capFloor`.
- **Sells above the cap are trimmed:** after a sell, any $PAD the pool holds above the cap is removed at an unchanged price: 85% burned, 15% to stakers. The IMD removed alongside it goes into the backstop, a buy wall below the market price.
- **Dumps into the backstop:** when price falls into the backstop, it buys $PAD. The next keeper rebalance burns those tokens with the same 85/15 split.

So:
- With normal back-and-forth trading, **the burn runs at about `capDecayTokensPerDay`**: about 500k $PAD a day (≈425k burned, ≈75k to stakers), roughly 15M a month. This limit applies only to the cap moving down after buys; sells that push the pool above the cap are always trimmed in full, as in the original POOL4.
- Quiet days save up their allowance, so the rate is an average, not a hard daily cap.
- Net selling above the cap is always trimmed, whatever the rate.
- Once the cap reaches the 150M floor (about 300 days at 500k/day with steady trading), the market behaves like a normal pool until sells push holdings back above the floor.

Both settings can be changed later through the timelock.

### 5.5 Governance, versions and swarm checks

**`PadConfig`**: every adjustable setting, each with hard min/max limits enforced in code:
- launch fee, graduation target, graduation fee
- snipe tax and max-buy settings
- splitter shares and the growth ↔ stakers dial
- IMD/ETH pool key, worker rewards address, Relay address, oracle signers

Changes go through **Timelock** (48 h for fees and launch settings, **7 days** for splitter shares, oracle signers, worker address and pool key). Changes apply only to **future** launches; each coin keeps its saved settings.

**Guardian role** (multisig): may **pause new launches** instantly. It can never pause trading, touch liquidity or move user funds.

**`VersionRegistry`**:
```solidity
function register(uint16 version, address factory, address router, address lens, bytes32 codeHash) external; // timelock
function activate(uint16 version, Attestation calldata swarmAudit) external; // needs IMD audit attestation for codeHash
function current() external view returns (VersionInfo memory);
function all() external view returns (VersionInfo[] memory);
```
New launches go to `current()`. Coins from older versions trade forever on their own hook.

**`AttestationVerifier`**: checks IMD oracle EIP-712 attestations (domain `IdentityMD Oracle`, version `2`, chainId 4663, verifyingContract = this) **[DEV]**.
- It checks the signer against an approved signer list (changed by timelock), the question hash, the answer, the expiry, and that the request ID hasn't been used before.

**`SocialRegistry`**: X badge, level 1.
- `link(coin, handleHash, voucher)`: the creator submits a voucher signed by the Pad's verifier key after X OAuth and a wallet signature.
- `revoke(coin)` by the verifier. One handle per coin; a handle claimed twice is flagged.

### 5.6 Admin powers, all of them

| Can do (timelocked unless noted) | Can never do |
|---|---|
| Change bounded settings for **future** launches | Change an existing coin's fees, tax, curve or target |
| Change splitter shares within their ranges | Remove or move locked liquidity |
| Set the IMD/ETH pool key, worker address, Relay, oracle signers | Pause trading, freeze tokens, mint |
| Register and activate versions (with swarm audit) | Upgrade contracts (none are proxies) |
| Pause **new launches** (guardian, instant) | Take creator fees, dividends or staked funds |
| Execute a CTO (only with a swarm attestation and after the 3-day notice) | Change a CTO outcome without a new attestation |

---

## 6. Payments: ETH or IMD

- Every price (launch fee, graduation target, website fee) is set in **IMD**. Contracts only ever receive IMD.
- The website shows prices in ETH and lets users pay with ETH. `PadRouter` swaps ETH → IMD in the same transaction through the configured IMD/ETH pool, with slippage limits. No backend touches user funds.
- Selling to ETH works the same way in reverse. IMD approvals are for the exact amount; sells use a permit signature.

---

## 7. Swarm integration in v1

| # | Feature | How it works | Paid from |
|---|---|---|---|
| 1 | **Audit-gated versions** | `VersionRegistry.activate` needs a swarm audit attestation for the exact `codeHash` with no open high or critical findings | Treasury |
| 2 | **Free website at graduation** | On `Graduated`, the Relay orders a `build-website` job from a fixed template; published at `<symbol>.site.identitymd.eth`, linked on the coin page | GrowthFund |
| 3 | **Paid website before graduation** | Creator pays a website fee (default 5 IMD) at or after launch | Website fee → GrowthFund |
| 4 | **CTO arbitration** | Oracle panel (default 9 agents) answers the takeover question; `CTOModule` needs the attestation | Requester pays the oracle fee (refunded on "yes") |
| 5 | **Swarm budget** | Coin tax share → `SwarmBudget`; the creator requests jobs (site updates, content, scheduled work) | That coin's budget |

### 7.1 Swarm Relay (backend)
- Builds job objectives **only from structured fields**: name, symbol, contract, logo, description, socials, chosen template, short notes with length limits. No free-text prompts, so nobody can inject instructions or order phishing sites.
- Pays quotes with x402 (Permit2 + EIP-712 quote approval), from a hot wallet topped up per job by GrowthFund or SwarmBudget. Payments in IMD on Robinhood once the swarm supports it there **[DEV]**; bridged mainnet IMD until then.
- Tracks status and records job IDs onchain (in `GrowthFund` / `SwarmBudget` events) and in the UI.
- **Checks every site before linking it**: static scan for wallet-drainer patterns, unexpected transaction calls and outside script sources. A site that fails is not linked, and the job is retried once.

### 7.2 Website template
A fixed starter repo, imported via `POST /requests/import`, contains:
- coin stats read from `PadLens`
- a buy button wired to `PadRouter`
- chart, socials, and the "Built by the IMD swarm" badge with the job link

The swarm customizes design and content only. This keeps cost, quality and safety predictable.

---

## 8. Offchain components

| Component | Role |
|---|---|
| **Frontend** (static, IPFS + own domain) | Pages listed in section 9. ethers/viem pinned with SRI, CSP, HTML-escaped metadata, `https`/`ipfs` links only. Hosting sets `frame-ancestors 'none'`. |
| **Indexer** | Reads `CoinLaunched`, `Trade`, `Graduated`, fee and staking events for charts, lists, holders and dashboards. Blockscout API to start; own indexer when traffic grows. |
| **Swarm Relay** | Section 7.1 |
| **Keeper bot** | Calls `FeeSplitter.distribute`, `RewardDripper.drip`, `WorkerFund.release`, `flush`, and stuck `graduate` calls. Every one of these is permissionless, so anyone can run a keeper. |
| **Token auto-verifier** | GitHub Action verifying each new `PadToken` on Sourcify and Blockscout, so scanners don't flag coins as unverified |
| **X link service** | X OAuth + wallet signature → signs a `SocialRegistry` voucher; re-checks links weekly |
| **Bots** | Telegram/X posts for new launches and graduations |

---

## 9. Frontend v1 pages

1. **Explore:** new, about to graduate, graduated, trending; filters for X-verified and has-website.
2. **Create:** form, coin tax and destinations, optional dev buy, optional website add-on, ETH or IMD payment, total fee preview.
3. **Coin page:** **trade box** (buy/sell with ETH or IMD, quote, slippage, total fee), chart, curve progress bar, holders, dividends to claim, creator fees, website card, audit and X badges, CTO status, swarm budget and its jobs.
4. **$PAD sale:** curve progress, buy and sell, airdrop claim.
5. **Stake:** stake $PAD for sPAD, redeem, the current $PAD value per sPAD, APR from the dripper rate, burn stats.
6. **Transparency:** splitter flows, WorkerFund payouts, GrowthFund spend with job links, treasury, current settings and pending timelock changes.
7. **Creator dashboard:** claim fees, change recipient, link X, request swarm jobs.
8. **Docs:** mechanics, fees, risks, contract addresses, audit links.

There is no separate swap page in v1; trading happens on coin pages.

---

## 10. Security

**Key invariants (each fuzz- or invariant-tested):**
- The curve's IMD balance always covers what sellers are owed, and the curve can't pay out more than it holds.
- Graduation opens the pool at the curve's final price, within rounding.
- Locked liquidity can never be removed, and no one else can add liquidity or initialize a pool with PadHook.
- The fee charged is exactly the bps of the filled IMD amount, for every swap type and router.
- The splitter's outputs add up to its inputs. Dividends and staking rewards can't be captured with flash-borrowed tokens or same-block staking.
- Admin cannot change any saved coin setting.

**Testing:**
- Foundry unit tests and fuzz/invariant suites.
- Fork tests against the live Robinhood PoolManager (`0x8366a39CC670B4001A1121B8F6A443A643e40951`), IMD (`0x5F7Bb59365ce557C26dbcAa4EE9d39A4b95B7127`) and the IMD/ETH pool.
- Attack tests: flash holders, partial fills, empty-pool price pushes, snipe bypass attempts, last-buy overshoot.

**Audits:**
- Swarm audit (4 auditors + judge) on the exact commit, repeated until clean, plus swarm fuzz campaigns.
- A human audit before large amounts of money flow through it.
- A public bug bounty from the treasury.

---

## 11. Build and launch order

1. **Contracts:** core (token, curve, hook, router, lens, vault, splitter, config, registry), then staking, funds and CTO, then `PadSale` and adapters.
2. **Swarm testnet run:** `workflow.open` on Sepolia (contracts + adversarial review + site) for a public testnet.
3. **Audit loop** (section 10).
4. **Deploy** to Robinhood: config, timelock and Safe first; then version 1 with its swarm audit attestation; then funds and staking.
5. **$PAD sale** opens and the airdrop snapshot is published. Coin launches can open at the same time, since the stakers' share waits in the dripper until staking opens.
6. **$PAD graduates** into `PadMarketHook`, ownership moves to `MarketController`, staking opens, and the dripper starts streaming.
7. **Coin launches go public** (optionally a short allowlist beta first).

---

## 12. Dependencies on the IMD / POOL4 developer

| # | Question | Fallback if not ready |
|---|---|---|
| 1 | Official POOL4 IMD/ETH market on Robinhood (planned, not guaranteed) | Use the hookless IMD/ETH pool; switch the key via timelock later |
| 2 | ~~Launcher access for $PAD~~ | **Solved:** we fork `CappedBurnHook` ourselves (section 5.4.1) |
| 3 | ~~Renouncing owner powers~~ | **Solved:** `MarketController` limits them |
| 4 | ~~Adding liquidity later~~ | **Solved:** `fundInventory`, via the timelock |
| 5 | Worker rewards address | WorkerFund accrues until set |
| 6 | Oracle attestations for chain 4663, signer addresses, rotation | CTO stays multisig + 3-day notice; version activation uses the audit job link, not an onchain attestation |
| 7 | Swarm job payments on Robinhood (and Base) | Relay pays from bridged mainnet IMD |
| 8 | POOL4 GitHub repo (tests, deploy scripts; promised next week) and any audits | Fork from the verified Etherscan source; our own tests and the swarm audit cover it |

---

## 13. After v1

| Version | Additions |
|---|---|
| **v1.1** | Swap page with coin → coin routing through IMD; referrals (via `ref`); "trade to earn sPAD" (rewards always below the protocol fee paid, paid as locked sPAD, weekly Merkle checked by the swarm); milestone bounties; scam flags; daily swarm health report; X badge level 2 (swarm-verified tweet) |
| **v2** | Custom coins built and audited by the swarm (bytecode-attested); swarm review of every settings change; POOL4-style burn mode per coin; boosted or locked sPAD tiers |
| **Later** | Dead-coin migration (Pons-style); outside liquidity providers; Base and Ethereum deployments |
