# PondPad: v1 architecture

PondPad is an IMD-paired token launchpad on Robinhood Chain (chain ID 4663). The swarm builds and audits it, and fees flow to $PONDPAD stakers, IMD workers, growth and the treasury.

Status: **v1 design, 4 October 2026.** This replaces the first draft in [`PLAN.md`](PLAN.md), which keeps the competitor analysis. Name: **PondPad**, platform token **$PONDPAD**, staked **sPONDPAD**. Contract names keep the short `Pad` prefix.

Items marked **[DEV]** depend on answers from the IMD / POOL4 developer. Section 12 lists each with its fallback.

---

## 1. What v1 does

1. Anyone launches a coin **paired with IMD**. It starts on a **bonding curve** and **graduates** into a Uniswap v4 pool run by PondPad's hook, with liquidity locked forever.
2. Every trade, on the curve or in the pool and through any router, pays a **1.5% base fee**, plus an optional **0–3% coin tax** chosen at launch.
3. Users pay with **IMD, ETH or USDG** (more tokens can be approved later). The router swaps them to IMD inside the same transaction.
4. The **IMD swarm** builds each graduated coin's website for free, must audit every launchpad version before it goes live, and can be paid from a coin's own "swarm budget". (Community takeovers were removed from v1, D-82: only a coin's fee recipient changes its recipient.)
5. Protocol fees go **40% to sPONDPAD stakers, 25% to IMD workers, 20% to growth, 15% to the treasury**.
6. **$PONDPAD** is paired with **IMD**, like every coin on PondPad. It is sold on its own IMD bonding curve (target ≈ 8,460 IMD, about 20 ETH) and graduates into **our own fork of POOL4's `CappedBurnHook`**, adapted for an IMD pair (section 5.4).
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
   (IMD/ETH/USDG)      │          │         │ graduate()
                       │          │         ▼
                       │          └──► Uniswap v4 PoolManager ◄──► PadHook (fees, locked LP)
                       │                    ▲
                       └── ETH⇄IMD leg ─────┘ (IMD/ETH pool; POOL4 market when live on RH)

 PadFactory ── deploys PadToken (fixed 1B supply) → BondingCurve
 VersionRegistry ── lists versions; activation needs a swarm audit attestation

 Fees (IMD) ─► CreatorVault (creator share + creator tax; the recipient alone changes it, D-82)
            ─► PadToken dividends (holder tax)
            ─► SwarmBudget (swarm-budget tax, per coin)
            ─► FeeSplitter ─┬─ 40% PadBuyer (IMD → $PONDPAD) ─► RewardDripper ─► StakedPONDPAD (sPONDPAD, ERC-4626)
                            ├─ 25% WorkerFund ─► IMD worker rewards address [DEV]
                            ├─ 20% GrowthFund (graduation websites, oracle costs, grants)
                            └─ 15% Treasury (Safe)

 AttestationVerifier ◄── IMD oracle attestations (EIP-712) ── used by VersionRegistry
 SocialRegistry ◄── X-link vouchers (Pad verifier key)

 $PONDPAD:  PadSale (IMD curve, ≈8,460 IMD) ─► PadMarketHook (CappedBurnHook fork) $PONDPAD/IMD ◄─ MarketController (owner)
        AirdropDistributor (5%, Merkle), TeamVesting (2%), liquidity reserve (3%, LiquidityReserve → 48 h timelock once the market opens)

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
| Graduation target (E) | **4,000 IMD** of net raise (≈ $126k market cap at graduation, ≈ $7.9k at launch, at IMD ≈ $6.30; D-76) | Yes, 1,000–10,000 IMD, timelocked |
| Graduation fee | 1% of raised IMD → GrowthFund | Yes, 0–2% |
| Launch fee | 0.35 IMD → FeeSplitter (D-76) | Yes, 0–10 IMD |
| Snipe tax | 70% → 0% linear over 80 s from launch, buys only (D-76) | Yes, start ≤ 90%, duration ≤ 120 s |
| Max buy window | first 80 s (the Egg stage): ≤ 2% of supply per wallet (D-76) | Yes, bounded |
| Initial dev buy | Optional, atomic, exempt from snipe tax and max-buy | – |

### 3.2 Curve math (constant product with virtual reserves)

The curve is a constant product of a virtual IMD reserve `x` and a virtual token reserve `y`. With S sold on the curve, R reserved and target E, the curve is set so it **ends exactly at the pool's opening price** E/R:

```
y0 = S + S·R/(S−R)       = 800M + 266.67M = 1,066.67M   (virtual token reserve)
x0 = E/3                 (for S = 4R)                     (virtual IMD reserve)
k  = x0 · y0
price(t)  = x / y
start mcap = 1B · x0/y0  ≈ 0.3125 · E   (≈ 1,250 IMD ≈ $7.9k)
final price = E / R      → graduation mcap = 5 · E (≈ 20,000 IMD ≈ $126k)
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
| *(off the top, referred trades only)* Integrator | 15% of the protocol fee | 0–25% (timelock) | `IntegratorVault`, claimable in IMD by the registered app/bot that routed the trade |
| sPONDPAD stakers | 40% | 25–60% | `PadBuyer` buys $PONDPAD with it on the market; `RewardDripper` streams the $PONDPAD into the sPONDPAD vault |
| IMD workers | 25% | 15–35% | WorkerFund → IMD worker rewards address **[DEV]** |
| Growth | 20% | 0–30% | Graduation websites, oracle costs, capped grants. The "growth ↔ stakers" dial moves this toward stakers over time. |
| Treasury | 15% | 5–20% | Safe multisig |

Inflows: protocol fee (curve and hook) and launch fees. The coin snipe tax and graduation fees go straight to GrowthFund, not through the splitter (audit R2-A1-5: this line used to list the snipe tax as a splitter inflow; the code always sent it to GrowthFund). So does a coin's holder tax while nobody holds an eligible balance yet, e.g. on the first buy (D-79). `distribute()` is permissionless.

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
- **Holder stream (D-78, D-80):** IMD routed to a coin's holders as a lump (creator fees of a coin whose fees go to holders, its swept swarm budget, anything sent with `CreatorVault.fundHolders`) sits in the coin and is credited second by second over about 7 days to the balances held during each second. It is settled before every balance change (inside an unlock too), on claims and when funded, so a balance held for no time earns nothing from it, whatever moment a buyer picks (audit R3-A4-1). While nobody holds an eligible balance it waits (R3-A4-2). A new lump ends at the amount-weighted average of the running end and now + 7 days, so it still gets about a week and a tiny top-up can't stretch a running one (R3-A1-2, R2-A4-3). `holderStream()` shows what is left, when it ends and what is due now; no release call is needed.

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
function launchWith(LaunchParams calldata p, address tokenIn, uint256 amountIn, bool devBuy, uint256 minImd, uint256 minTokensOut) external payable returns (address, uint256);
function buyWith(address coin, address tokenIn, uint256 amountIn, uint256 minTokensOut, uint256 deadline, bytes32 ref) external payable returns (uint256);
function sellFor(address coin, address tokenOut, uint256 tokensIn, uint256 minOut, uint256 deadline, bytes32 ref) external returns (uint256);
function sellForWithPermit(..., uint8 v, bytes32 r, bytes32 s) external returns (uint256);
// every trading function also takes `address referrer` (registered integrator, or address(0))
```
- It routes automatically: curve before graduation, v4 pool after.
- `tokenIn` / `tokenOut` is IMD, native ETH (`address(0)`) or any **payment token approved in `PadConfig`**, which stores a swap path to IMD for each (ETH: the IMD/ETH pool; USDG: USDG → ETH → IMD). After graduation the payment path and the coin's pool run in one unlock.
- `ref` is recorded in events now and used by referrals in v1.1.
- The router holds no funds between transactions.

**`PadLens`** (view only): coin lists with pagination (from `BondingCurve.coinAt`), coin info, exact IMD quotes on the curve or in the pool (one `SwapMath` step over the single full-range position, hook fee on the IMD side), user positions, pending dividends and creator fees.

### 5.2 Creator side

**`CreatorVault`**: IMD balance per coin, `claim(coin)`, `setRecipient(coin, newRecipient)` (current recipient only, future earnings; the recipient alone decides, routing the fees to holders included). **Holder stream (D-78, D-80):** when a coin's recipient is the coin itself, its claimed creator fees, its swept swarm budget and anything sent with `fundHolders` go into the coin's own holder stream (`PadToken`, section 5.1), which pays them to holders second by second over about 7 days, so nobody can buy just before a payout, collect a share and sell (audits R1-A4-1, R3-A4-1). **Recipients (audit R5-A1-1):** a recipient can't be the vault itself, the curve, the hook, the hook's PoolManager or another registered coin, at launch (`feeRecipient`) or later (`InvalidRecipient`): anyone may call `claim`, which would hand the fees to a contract that never counts them (or to the other coin's holders) before the recipient could correct it, and the coin's swarm budget could never be spent, cancelled or swept. Any other address is the recipient's own choice.

**No takeovers (D-82):** v1 has no takeover module. Only a coin's current fee recipient changes its recipient (`setRecipient`), routing to the coin's holders included, which is final (the coin never calls `setRecipient`). The vault takes the curve and the hook once at deploy (`initialize(curve, hook)`), so coins launched on v1 can never be taken over; a later version could add takeovers for its own new coins only, with a new vault. A DexScreener-style community takeover (listing, socials) needs nothing from these contracts.

### 5.3 Fees and $PONDPAD economy

| Contract | Key functions | Notes |
|---|---|---|
| `FeeSplitter` | `distribute()`, `distributeToken($PONDPAD)` | Shares and recipients set by its owner (7-day timelock) within fixed ranges; IMD, and the market's $PONDPAD fees (only $PONDPAD, D-80) |
| `PadBuyer` | `buy()` | Permissionless and rate-limited: spends the stakers' IMD on $PONDPAD in the `PadMarketHook` pool in small chunks, with a price guard (block-lagged reference price, which also catches up over blocks without swaps, D-80, read as `referenceTick()` so the catch-up counts before the next swap applies it, audit R4-A3-3; max slippage), and sends the $PONDPAD to `RewardDripper`. Keeper tip capped. Settings by the 48 h timelock, with no expiry (D-43); `minChunk` at least 1 wei (R4-A3-7). Against the price before a pump held across an Ethereum block it pays at most the market's `maxRefStep` + `maxDeviationTicks` + `maxSlippageTicks` more: 100 + 100 + 100 ticks, ~3% per block, at the defaults (D-84, audit R2-A3-6). The 48 h owner keeps `maxRefStep` at or below `maxDeviationTicks`, so the bound stays near that. |
| `RewardDripper` | `drip()` | **Fork of POOL4's `RewardDripper`**, asset = $PONDPAD. Streams $PONDPAD into the vault with a self-adjusting release (D-44): each drip pays out a share of the waiting rewards proportional to the time since the last drip (default: all of it over ~7 days, ~0.6% per hour), so no one can stake just before a large payout, and it scales with volume without tuning. Drips only while the vault is open for rewards (at least one whole $PONDPAD staked), and time the vault was closed is forfeited, not banked (D-79), so rewards wait until staking opens. One drip releases at most 1/7 of the buffer (`1 h ≤ maxCatchup ≤ smoothing / 7`, `minDripAmount ≤ 100,000`, D-79; the minimum-drip floor is capped at 1/7 too, D-80), plus the rest when less than one $PONDPAD would remain. Also receives up to 30% of trimmed $PONDPAD from `PadMarketHook`. Its rescue can't touch the reward buffer or sPONDPAD parked at it (audit R5-A3-2). |
| `StakedPONDPAD` (sPONDPAD) | `deposit`, `redeem` (ERC-4626) | **Fork of POOL4's `StakedIMD`**, asset = $PONDPAD. Auto-compounding: rewards raise the $PONDPAD value of each sPONDPAD share; no claim step. One-block hold blocks same-block deposit → redeem. No lockup in v1. Counts its own assets (deposits, withdrawals and rewards taken in by `syncRewards`), not its raw balance, so a transfer into the vault can't move the share price (D-79). sPONDPAD has **24 decimals** (18 + the 6-decimal offset: 1 $PONDPAD ≈ 1e6 shares at the start); wallets and the site exit with `maxRedeem`, which is the balance less any shares that arrived this block (R3-A3-4, R3-A3-6). Shares can't be minted or sent to address(0) or to the vault itself, where nobody could redeem them but they would keep the vault open for rewards (audit R4-A3-1), and no exit pays either (R5-A3-3); shares parked at any other address nobody controls act like a staker that never exits. Only the dripper should send $PONDPAD to the vault: anything else sent straight to it is taken in as one lump at the next `syncRewards` (documented, R4-A3-2). Owner powers narrowed (D-42): 7-day timelock owner; pause at most 3 days at a time; rescue can never touch staked $PONDPAD or sPONDPAD itself (R4-A3-5); all powers expire 12 months after launch. |
| `WorkerFund` | `release()`, `releaseToken(token)` | Sends its whole IMD and $PONDPAD balance, as they are (D-45), to `workerRewards` (set by the 7-day timelock) **[DEV]**; accrues until it's set. Permissionless |
| `GrowthFund` | `payJob(amount, jobRef, reason)`, `grant(token, to, amount, ref, reason)` | Relay pays swarm jobs (≤ 100 IMD per 7-day epoch); the team Safe pays grants (≤ 1,000 IMD and 10M $PONDPAD per epoch; tokens without a cap can't be granted). Caps, relay and granter set by the 48 h timelock (D-47). Every payment emits a reference and reason |
| `SwarmBudget` | `requestSpend(coin, amount, specHash)`, `release(requestId)` | Per-coin escrow funded by the swarm-budget tax. Only the coin's fee recipient can request; the Relay releases to pay that job; per-request cap; job ID recorded onchain. |

### 5.4 $PONDPAD launch (one-time)

| Contract | Role |
|---|---|
| `PadSale` | Bonding curve in **IMD**: 600M $PONDPAD sold (60%), target **≈ 8,460 IMD** (≈ 20 ETH at 1 ETH ≈ 423 IMD; fixed in IMD at deploy), 300M reserved for the pool (30%). Same curve math with S = 2R: start market cap ≈ 7,050 IMD (~$44k), graduation market cap ≈ 28,200 IMD (~$178k), pool at graduation ≈ 8,460 IMD + 300M $PONDPAD (~$107k). Trades directly on `PadSale` (`buyWith`, `sellFor`, `sellForWithPermit`) in IMD, ETH or any approved payment token, through the same `PaymentSwapper` code as `PadRouter`. Two-way (sell back any time until it completes). **1% fee** on each trade → FeeSplitter, with a registered integrator's 15% off the top (D-36). **Anti-bot (D-35):** opens at a fixed start time; snipe tax **80% → 0 over the first 30 minutes** (to GrowthFund); **15M $PONDPAD (1.5%) per-wallet cap for the whole sale**, which sells don't free. No graduation fee: the completing buy hands the whole net raise and 300M $PONDPAD to `MarketController.launch(sqrtPriceX96, imd, tokens)` at the curve's final price; overshoot refunded in IMD. |
| `PadMarketHook` | **Fork of POOL4's `CappedBurnHook`** (MIT, verified on Etherscan at `0xc6c965bd…2840`), adapted for an **IMD pair** and deployed on Robinhood with the Robinhood PoolManager. $PONDPAD/IMD full-range market, **dynamic LP fee 3% → 1% over the first 7 days, then 1% (D-34)**, capped burn and IMD backstop. At graduation `PadSale` sends the raised IMD and 300M $PONDPAD to `MarketController.launch`, which initializes the pool at the curve's final price and calls `openMarket`. `MarketController` owns the hook from deployment. Details in section 5.4.1. |
| `MarketController` | The hook's owner. Limits what the owner can do (section 5.4.1). |
| `AirdropDistributor` | 5% (50M) Merkle claim: 70% to active IMD workers (seat owners), 30% to IMD holders with ≥ 7,000 IMD on Robinhood, Base and Ethereum (D-56; snapshot taken at one secret moment and announced only after it is taken; root fixed at deploy, no owner). **Initiation phase (D-55):** once the market is open (`MarketController.openedAt`), wallets on the list post "Initiating the airdrop phase for $PondPad" with their own code (`initiationCode(account)`, derived from the contract and the wallet) and register it with a voucher from PondPad's tweet checker; one wallet, one X account, one tweet each. The **100th** initiator activates the airdrop for **everyone** on the list (no bonus, no fallback date), so `Deploy.s.sol` refuses a claims list of fewer than 100 wallets (audit R4-A3-4). Each allocation then **vests linearly over 30 days** from activation. Claiming needs no X link. A wallet can name a **claim wallet** with a gasless EIP-712 signature (EOA, checked first, so a wallet with an EIP-7702 delegation works too, or ERC-1271, R4-A3-8); claims then always pay that wallet, and it can also initiate. **180 days** after activation anyone sweeps the rest to `RewardDripper` (stakers). Owner (48 h timelock) can only replace the tweet checker's key. D-53, D-55 |
| `TeamVesting` | 2% (20M) to the team Safe, from market open: **1-month cliff, linear to month 6** (1/6 at the cliff). Not revocable, no owner; `release()` permissionless; only the beneficiary can change itself. D-54 |
| `LiquidityReserve` | 3% (30M) liquidity reserve: held by `LiquidityReserve` until the market opens, so it can never be sold into the sale; then anyone calls `release()` and it goes to the 48 h timelock (D-79), only for adding $PONDPAD liquidity later through `fundInventory` (needs $PONDPAD and IMD in proportion) |

#### 5.4.1 The POOL4 fork for $PONDPAD

What we take from POOL4's verified source (`CappedBurnHook`, Solidity 0.8.30, solady, v4-core):

- **One hook per market.** The hook's token is fixed in the constructor, and the original hard-codes **native ETH** as the other side (`currency0 = address(0)`). A $PONDPAD/**IMD** market therefore needs the changes in the table below. Constructor: `owner, poolManager, token, burnSink, rewardsRecipient, rewardShareBps (≤ 30%), minTrimTokens, lpFee, tickSpacing`.
- **Hook permissions:** `beforeInitialize`, `beforeAddLiquidity` (both hook-only) and `afterSwap`. The hook address must be mined for these flags.
- **Fees:** a normal pool fee (1% on mainnet), collected on every swap into a fee ledger, in both the quote asset and the token, and paid out with `withdrawFees(recipient)` by the owner.
- **Burn:** after sells, tokens above `inventoryCap` are removed: at least 70% go to `burnSink`, up to 30% to `rewardsRecipient`. The removed quote asset (ETH in the original, IMD in ours) funds a backstop band above the price, rebalanced by a permissionless keeper.

**Changes for our fork:**

| Item | Our setting or change |
|---|---|
| **Quote asset: IMD instead of native ETH** | The math assumes quote = `currency0`, token = `currency1`. v4 sorts currencies by address, so we **mine the $PONDPAD token address to be above IMD's (`0x5F7B…7127`)**. IMD is then `currency0` and all price and amount math stays unchanged. We replace only the native-ETH plumbing with ERC-20 handling: `currency0 = IMD` in `poolKey()`; `openMarket`/`fundInventory` pull IMD with `transferFrom` instead of `msg.value`; settlements use `sync` + transfer + `settle` instead of `settle{value}`; payouts, keeper tips and the retained backstop pay IMD with `safeTransfer` instead of `safeTransferETH`; `receive()` is removed; `eth*` names become `quote*`. |
| **Fee: dynamic 3% → 1% over 7 days (D-34)** | Pool key uses v4's dynamic-fee flag (`0x800000`) instead of a fixed `lpFee`. A new `beforeSwap` (extra hook flag to mine) returns `currentFee() \| OVERRIDE_FEE_FLAG`, where `currentFee()` = 30,000 at market open, falling linearly to 10,000 (1%) at day 7, then 10,000 forever: a pure function of time, no owner setter. The keeper-tip ceiling (`_keeperRewardDue`) reads `currentFee()` instead of `lpFee`. Nothing else changes: each swap's LP fee is still realised into the fee ledger before the cap runs, so cap / trim / burn / backstop math never sees the fee level. A fuzz test checks the cap invariants at both 3% and 1% |
| ETH-sized constants | Retuned in IMD: rebalance threshold (0.1 ETH → ~40 IMD), keeper tip (0.002 ETH → ~1 IMD), max keeper tip (0.1 ETH → ~40 IMD) |
| Reference step (`maxRefStep`) | Default **100 ticks** per Ethereum block instead of POOL4's 200 (D-84, audit R2-A3-6): the reference (`refTick`, `referenceTick()`) that `PadBuyer` guards against moves at most 100 ticks (~1%) per block toward the last close, so `PadBuyer`'s overpay against the price before a pump is at most 100 + 100 + 100 ticks (~3%) per block at its defaults. The setter's range is unchanged (1–2,000, 48 h timelock); the owner keeps it at or below `PadBuyer.maxDeviationTicks`. A genuine move takes twice as many blocks to reach the reference (a 10% move ~10 blocks, ~2 minutes) |
| Tests | Own tests (`Market.t.sol`) and a Robinhood fork test with real IMD; port POOL4's tests when its repo is published |
| Compiler target | Rebuild with `evm_version = cancun`. The original is compiled for `osaka`, which Robinhood Chain may not support; Pepes runs `cancun` there. Fork tests must pass on Robinhood. |
| `burnSink` | `PadBurner`: calls `$PONDPAD.burn()` so supply really drops, instead of sending tokens to a dead address. The hook counts trimmed tokens in `totalBurned` when it trims; they leave the supply at the next `burn()`, which `MarketController.collectFees()` also calls (audit R4-A2-2) |
| `rewardsRecipient` | `RewardDripper` (section 5.3): 15% of trimmed $PONDPAD goes to stakers (allowed up to 30%) |
| Fee recipient | `MarketController.collectFees()` (permissionless) → both fee currencies to FeeSplitter: IMD split 40/25/20/15 as usual, and the $PONDPAD that sellers pay split **40/25/20/15 in $PONDPAD** (`distributeToken`, D-38) |
| Cap settings | Starting proposal: `capFloor` = 150M $PONDPAD (half the opening pool), `capDecayTokensPerDay` = 500k $PONDPAD (0.05% of supply). Both adjustable later through the timelock (`setCapDecay`, `setCapFloor`). Section 5.4.2 explains the effect. |
| Owner | `MarketController`, never an EOA |

**`MarketController`** wraps the owner powers, which POOL4 documents as trusted:

| Owner power in the hook | In MarketController |
|---|---|
| `withdrawFees` | Permissionless; always to the fixed fee route |
| Policy setters (cap floor, decay, ratchet, reference step, floor decay, keeper tip, rebalance, reward share ≤ 30%) | Timelock (48 h); cap floor never below the deploy floor (150M), decay at most 5× the deploy pace (2.5M/day) (D-80, audit R3-A2-1); reference step 1–2,000 ticks, kept at or below `PadBuyer`'s guard (D-84) |
| `setBurnSink`, `setRewardsRecipient` | `sinkAdmin` = the 7-day timelock, fixed at deploy (no `setSinkAdmin`, D-79) |
| `fundInventory` (add liquidity) | Timelock; only from the liquidity reserve (held by `LiquidityReserve` until the market opens, then the 48 h timelock's, D-79) + treasury; it refunds only what it pulled and didn't use (D-80); it adds only while the market's tick is within 100 ticks (~1%, the constant `MAX_FUND_DEVIATION_TICKS`) of the hook's `referenceTick()`, which nothing in the current block moves, so whoever executes the queued call can't run it inside a pump made in the same block (pump, add at the pumped price, dump) and take value from the position (audit R5-A2-1, D-86). A reverted execution stays executable, so the add waits until the price is back near its reference. A price held across blocks moves the reference (`maxRefStep` per block), so the proposal's maxima bound the rest: each within 2 × fee × pool liquidity / added liquidity of what the add needs at the proposal's price (1.2× for the 30M reserve against the opening pool), and the Safe cancels a queued add when the price leaves that band (owner rule, D-87, check before round 6 P6-1) |
| `closeMarket` (withdraw the **whole** position) | Only inside `migrate(newHook)` (D-40, D-78): approved by the 7-day timelock (`approveMigration`), run only by the team Safe (`migrator`), first 12 months only; everything reopens in the approved, unopened hook owned by this controller at the same price, fee clock, backstop placement floor, reference tick (the old market's `referenceTick()`, caught up to the migration block, audit R5-A2-2) and cap (floor and cap only raised); nothing to any wallet. Locked forever after 12 months |
| `withdrawRetainedQuote`, ownership transfer | **Not exposed** |
| `closeBackstop` | Timelock (48 h); the IMD it returns earns no keeper tip when redeployed (D-79) |
| `initializePool`, `openMarket` | Called once inside `MarketController.launch`, which only `PadSale` can call, at graduation |

The fork is unaudited code, so it is audited by the swarm together with our contracts (section 10), plus any audit the POOL4 developer has.

#### 5.4.2 How the burn behaves day to day

- **The cap:** the market starts with a cap equal to the $PONDPAD it opened with (300M).
- **Buys lower the cap:** when buyers take $PONDPAD out of the pool, the cap follows the pool's holdings down. It falls at most `capDecayTokensPerDay` on average, and never below `capFloor`.
- **Sells above the cap are trimmed:** after a sell, any $PONDPAD the pool holds above the cap is removed at an unchanged price: 85% burned, 15% to stakers. The IMD removed alongside it goes into the backstop, a buy wall below the market price.
- **Dumps into the backstop:** when price falls into the backstop, it buys $PONDPAD. The next keeper rebalance burns those tokens with the same 85/15 split.

So:
- With normal back-and-forth trading, **the burn runs at about `capDecayTokensPerDay`**: about 500k $PONDPAD a day (≈425k burned, ≈75k to stakers), roughly 15M a month. This limit applies only to the cap moving down after buys; sells that push the pool above the cap are always trimmed in full, as in the original POOL4.
- Quiet days save up their allowance, so the rate is an average, not a hard daily cap.
- Net selling above the cap is always trimmed, whatever the rate.
- Once the cap reaches the 150M floor (about 300 days at 500k/day with steady trading), the market behaves like a normal pool until sells push holdings back above the floor.

Both settings can be changed later through the timelock. The floor can only be set between 150M and the market's current cap: a floor above the cap would lift the cap to it, and only the slow ratchet lowers the cap again, so trims would stop (audit R4-A2-1). The check runs when the 48 h call executes, and any buy before then lets the ratchet lower the cap by the decay allowance banked since the cap last moved, so a floor proposal leaves at least that margin below the cap (a floor at the cap itself is reverted by a dust buy). To hold the cap where it is, set the decay to 0 (`setCapDecay(0)`): no buy can lower it then (audit R5-A2-3).

### 5.5 Governance, versions and swarm checks

**Where each setting lives** (audit R3-A4-14). Every owned contract is `FixedOwnable`: its timelock owner can't hand its powers to another address or renounce them (D-80), and both timelocks (`PondPadTimelock`) refuse a delay below their deploy value (48 h / 7 days). The timelocks' own roles stay as in OpenZeppelin (D-81, accepted): through a delayed operation of the timelock itself the Safe can raise its delay or change who proposes, and it can renounce its own role at once. That can freeze a timelock's powers, never speed them up, and it is the only way to ever replace the Safe as proposer.

| Contract (owner) | Settings | Applies to |
|---|---|---|
| `PadConfig` (48 h) | Launch fee, graduation target and fee, snipe tax and max-buy settings, payment tokens and their routes to IMD (≤ 3 hops), integrator share and registry (the guardian may register), guardian, launch pause. The fee splitter and growth fund are fixed at deploy (D-78) | Future launches (each coin keeps its saved settings); routes and integrators are live |
| `FeeSplitter` (7 days) | Shares within their ranges, recipients | Live |
| `WorkerFund` (7 days) | Worker rewards address | Live |
| `SwarmBudget` (48 h), `GrowthFund` (48 h) | Swarm Relay; GrowthFund caps and granter | Live |
| `AttestationVerifier` (7 days) | Oracle signers, minimum panel and agreement (an exact fraction, default 2/3) | Live |
| `MarketController` (48 h / 7 days), staking (48 h / 7 days), `PadBuyer` (48 h), `AirdropDistributor` (48 h) | See sections 5.3, 5.4 | Live |

**Guardian role** (multisig): may **pause new launches** instantly. It can never pause trading, touch liquidity or move user funds.

**`VersionRegistry`** (owner: 7-day timelock):
```solidity
function register(address factory, address router, address curve, address hook, address lens) external returns (uint256 version); // owner; code hash computed onchain
function activate(uint256 version, string calldata auditJobId, OracleAttestation calldata att, bytes calldata sig) external; // anyone, with an oracle "yes" to question(version, auditJobId)
function activateManually(uint256 version, string calldata auditLink) external; // owner, fallback until retired (D-46)
function setCurrent(uint256 version) external; // owner, rollback to an activated version
function current() external view returns (Version memory);
function all() external view returns (Version[] memory);
```
New launches go to `current()`. Coins from older versions trade forever on their own hook. The audit question names the audit job, the code hash and the five addresses. The verifier and all five addresses must have code (audits R5-A4-5, R5-A4-7).

**v1 activates versions manually only (D-86).** A live test on Robinhood (HANDOFF §6b) showed panels answer the activation question by the contracts' names, not their code: 25 of 35 members said "true" for code no audit covered. So v1 approves **no oracle signer** in `AttestationVerifier`: `activate` always reverts, and the manual fallback (`activateManually`, 7-day timelock) can't be retired (`retireManualActivation` needs a signer). Version 1 is activated at deploy with `AUDIT_LINK`. A reworded question panels can check (naming the audited commit, asking about the report and the contracts' source verification, with `definitions`), with R2-A4-4's evidence-chain pin, is v1.1 at the earliest.

**`AttestationVerifier`** (owner: 7-day timelock; no signer approved in v1, D-86): checks IMD oracle v2 attestations, EIP-712 `OracleAttestation(bytes32 requestId,uint256 chainId,bytes32 questionHash,uint8 answerType,bytes answer,uint256 figure,uint64 fromBlock,uint64 toBlock,bytes32 blockHash,bytes32 panelJobId,uint16 panelSize,uint16 quorum,uint16 agreed,uint64 issuedAt,uint64 expiresAt)` under domain `IdentityMD Oracle`, version `2`, chainId 4663, verifyingContract = this (the request's `consumer`) **[DEV: signer on Robinhood]**.
- Checks: approved signer; `questionHash` equals the hash of the consumer's exact question (canonical JSON of the request, rebuilt onchain from the attestation's window, D-49); bool answer; panel ≥ 51 and agreed ≥ 2/3 of the panel (an exact fraction, D-80) and ≥ the request's quorum (D-48); `issuedAt ≤ now ≤ expiresAt`. Consumers mark request ids used.
- Checked against a live attestation from `api.imd.fun` in the tests.

**`SocialRegistry`**: X badge, level 1 (owner: 48 h timelock).
- `link(coin, handleHash, deadline, voucher)`: the coin's fee recipient submits an EIP-712 voucher signed by PondPad's X link service key after X OAuth and a wallet signature (bound to coin, handle, account, per-coin nonce, deadline).
- `unlink(coin)` by the recipient, the verifier or the owner; a revocation by the verifier or the owner, or by the recipient of its own live link, uses up the nonce, so vouchers signed before it are void (D-80). One handle per coin; a handle linked to two coins is flagged on both (`badgeOf`), never blocked. A coin's link counts only while the account that made it is still the fee recipient: after any recipient change the old badge disappears and anyone can clear it (D-80, audit R3-A4-9); clearing a stale link doesn't use up the nonce, whoever clears it (a stranger, R4-A4-6; the new or the old recipient, R5-A4-3), so the new recipient's voucher stays valid. The duplicate flag counts every link not yet cleared, stale ones included, so the site clears stale links (anyone may) and computes its warning from live links (R5-A4-1). A coin whose fees go to its holders (recipient = the coin) has no badge and can never link one, since the coin never calls `link`; the creator's own wallet link stays on its profile (R5-A4-2). Vouchers are checked against the signer's own key first, then ERC-1271, so an X link key with an EIP-7702 delegation still works (R4-A3-8); the verifier key is never address(0) (R5-A4-6).
- `linkWallet(handle, deadline, voucher)`: any wallet links its own X account the same way; shown on the wallet's profile.

### 5.6 Admin powers, all of them

| Can do (timelocked unless noted) | Can never do |
|---|---|
| Change bounded settings for **future** launches | Change an existing coin's fees, tax, curve or target; change `PadConfig`'s fee splitter or growth fund (fixed at deploy, D-78); hand any owner power to another address, renounce it, or shorten a timelock's delay below 48 h / 7 days (D-80) |
| Change splitter shares within their ranges | Remove or move locked liquidity |
| Set payment-token routes, worker address, Relay, oracle signers | Pause trading, freeze tokens, mint |
| Register and activate versions (with swarm audit; in v1 manually only, no oracle signer approved, D-86); roll back to an activated version (owner only: an attested activation of an older version doesn't move `currentVersion` back, D-78). The registry is informational: launches don't consult it | Upgrade contracts (none are proxies) |
| Pause **new launches** (guardian, instant) | Take creator fees, dividends or staked funds |
| – | Change any coin's fee recipient: only the recipient itself can (no takeover module, D-82) |
| Tune the reward stream within `1 h ≤ maxCatchup ≤ smoothing / 7` and `minDripAmount ≤ 100,000` $PONDPAD (48 h timelock, D-79) | Release more than 1/7 of the reward buffer in one drip (plus the rest when less than one $PONDPAD would remain); move the 30M liquidity reserve before the market opens; hand the market's sink role to another address |
| Set the $PONDPAD market's cap floor (≥ 150M and never above the market's current cap) and decay (≤ 2.5M/day), ratchet, keeper tip, rebalance and reward share (≤ 30%) (48 h timelock) | Let trading trim the market position below the 150M floor (D-80); lift the cap with the floor and so stop the trims (audit R4-A2-1) |
| Add inventory from the liquidity reserve and treasury (`fundInventory`, 48 h timelock) | Add it at a price more than 100 ticks from the market's reference, so nobody can execute the queued add inside a pump and dump made in the same block (audit R5-A2-1); a price held across blocks moves the reference, and the proposal's maxima, kept close to what the add needs (owner rule, D-87), bound the rest |
| Approve a $PONDPAD market migration (7-day timelock), which only the team Safe can then run, first 12 months (D-40, D-78) | Migrate without both, or after 12 months. The new hook is checked only through its own answers (owner, pair, sinks; D-40), so the 7-day approval is when holders review its code |

---

## 6. Payments: IMD, ETH, USDG (more later)

- Every price (launch fee, graduation target, website fee) is set in **IMD**. Contracts only ever receive IMD.
- `PadConfig` keeps an approved list of **payment tokens**, each with a fixed swap path to IMD (at most 3 hops, validated on set, changed only through the timelock):
  - **ETH**: ETH → IMD through the hookless IMD/ETH pool (1% fee, tick spacing 100). Switch to a POOL4 market when one exists on Robinhood.
  - **USDG** (`0x5fc5…d168`): USDG → ETH through the ETH/USDG pool (dynamic fee, tick spacing 10, its own hook) → IMD.
  - Later: other stablecoins or stock tokens, added the same way.
- `PadRouter` swaps the payment to IMD (or IMD back to the payment token on sells) in the same transaction, with slippage limits. No backend touches user funds. Each extra pool adds its fee and price impact; the website shows the full cost.
- IMD approvals are for the exact amount; sells can use a permit signature.
- The **$PONDPAD sale** accepts the same payment tokens.
- **Live depth (fork test, Oct 2026):** Robinhood holds ~46.9k IMD; the IMD/ETH pool ~28.9k IMD + 70 ETH. Buying 2,091 IMD (one graduation) costs ~5.3 ETH (~5% above spot); buying 8,590 IMD (the full $PONDPAD raise) costs ~29.6 ETH (~42% above spot). Deepen IMD liquidity on Robinhood before the $PONDPAD sale.
- **Volume through outside pools:** anyone can open another pool for a coin and undercut our fee. On Robinhood today this is negligible (Pepes keeps >99% of volume in its own pool), but the indexer tracks it per coin and the transparency page publishes it. Fees stay the creator's choice.

---

## 7. Swarm integration in v1

| # | Feature | How it works | Paid from |
|---|---|---|---|
| 1 | **Audit-gated versions** | `VersionRegistry.activate` needs a swarm audit attestation for the exact `codeHash` with no open high or critical findings. **In v1 the 7-day timelock activates versions manually, citing the swarm audit (D-86):** no oracle signer is approved, since panels answered the activation question by contract names, not code (§5.5) | Treasury |
| 2 | **Free website at graduation** | On `Graduated`, the Relay orders a `build-website` job from a fixed template; published at `<symbol>.site.identitymd.eth`, linked on the coin page | GrowthFund |
| 3 | **Paid website before graduation** | Creator pays a website fee (default 5 IMD) at or after launch | Website fee → GrowthFund |
| 4 | **Swarm budget** | Coin tax share → `SwarmBudget`; the creator requests jobs (site updates, content, scheduled work) | That coin's budget |

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
| **Frontend** (static, IPFS + own domain) | Vite + React + TypeScript + viem/wagmi (D-66), styled with the PondPad design system (`design/`: tokens, `pp-` components, self-hosted fonts). Pages listed in section 9. ethers/viem pinned with SRI, CSP, HTML-escaped metadata, `https`/`ipfs` links only. Hosting sets `frame-ancestors 'none'`. |
| **Indexer** | Reads `CoinLaunched`, `Trade`, `Graduated`, fee and staking events for charts, lists, holders and dashboards. Blockscout API to start; own indexer when traffic grows. |
| **Swarm Relay** | Section 7.1 |
| **Keeper bot** | Calls `FeeSplitter.distribute`, `RewardDripper.drip`, `WorkerFund.release`, `flush`, and stuck `graduate` calls. Every one of these is permissionless, so anyone can run a keeper. |
| **Tweet checker** | Airdrop initiation (D-55): checks that a post by the X account contains the phrase and the wallet's `initiationCode`, then signs an `Initiation` voucher (account, handle hash, tweet hash, deadline) |
| **Token auto-verifier** | GitHub Action verifying each new `PadToken` on Sourcify and Blockscout, so scanners don't flag coins as unverified |
| **X link service** | X OAuth + wallet signature → signs a `SocialRegistry` voucher; re-checks links weekly |
| **Bots** | Telegram/X posts for new launches and graduations |

---

## 9. Frontend v1 pages

1. **Explore:** new, about to graduate, graduated, trending; filters for X-verified and has-website.
2. **Create:** form, coin tax and destinations, optional dev buy, optional website add-on, payment in IMD, ETH or USDG, total fee preview.
3. **Coin page:** **trade box** (buy/sell with IMD, ETH or USDG, quote, slippage, total fee), chart, curve progress bar, holders, dividends to claim, creator fees, website card, audit and X badges, swarm budget and its jobs.
4. **$PONDPAD sale:** curve progress, buy and sell, live snipe tax and countdown, wallet allowance left, airdrop eligibility before the Leap; after the Leap the airdrop initiation form (code, tweet link, signature, live count to 100), then the claim (vesting progress, optional claim wallet by signature, optional "I claimed" post).
5. **Stake:** stake $PONDPAD for sPONDPAD, redeem, the current $PONDPAD value per sPONDPAD, APR from the dripper rate, burn stats.
6. **Transparency:** splitter flows, WorkerFund payouts, GrowthFund spend with job links, treasury, current settings and pending timelock changes.
7. **Profile** (replaces the separate creator dashboard, D-66): holdings (every coin held, value, dividends), **created coins with a creator-fee claim section** (claim all, change recipient, link X, request swarm jobs), rewards (dividends, integrator earnings, airdrop), activity.
8. **Docs, inside the site** (same navigation): start here, how it works, $PONDPAD, safety, developers.

9. **Terms and Privacy:** every connected wallet accepts them (and confirms age and jurisdiction) before using the site; kept in a session cookie per wallet and text version (D-69).

No on-site comment threads in v1 (D-70). Layouts for every page: [`design/system/Pages.md`](design/system/Pages.md); brand and components: [`design/`](design/); the built site: [`frontend/`](frontend/).

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

1. **Contracts:** core (token, curve, hook, router, lens, vault, splitter, config, registry), then staking, funds and governance, then `PadSale` and adapters.
2. **Swarm testnet run:** `workflow.open` on Sepolia (contracts + adversarial review + site) for a public testnet.
3. **Audit loop** (section 10).
4. **Deploy** to Robinhood with `contracts/script/Deploy.s.sol` (one run: timelocks, everything wired, version 1 registered and activated with the audit link, supply split, all powers handed to the timelocks; HANDOFF §5a).
5. **$PONDPAD sale** opens and the airdrop snapshot is published. Coin launches can open at the same time, since the stakers' share waits in the dripper until staking opens.
6. **$PONDPAD graduates** into `PadMarketHook`, ownership moves to `MarketController`, staking opens, and the dripper starts streaming.
7. **Coin launches go public** (optionally a short allowlist beta first).

---

## 12. Dependencies on the IMD / POOL4 developer

| # | Question | Fallback if not ready |
|---|---|---|
| 1 | Official POOL4 IMD/ETH market on Robinhood (planned, not guaranteed) | Use the hookless IMD/ETH pool; switch the key via timelock later |
| 2 | ~~Launcher access for $PONDPAD~~ | **Solved:** we fork `CappedBurnHook` ourselves (section 5.4.1) |
| 3 | ~~Renouncing owner powers~~ | **Solved:** `MarketController` limits them |
| 4 | ~~Adding liquidity later~~ | **Solved:** `fundInventory`, via the timelock |
| 5 | Worker rewards address | WorkerFund accrues until set |
| 6 | Oracle attestations for consumer chain 4663, signer addresses, rotation | **Built with a fallback:** version activation by the timelock with the audit job link, retired one-way once a signer is approved (D-46). Takeovers, the other consumer, were removed (D-82). **v1 approves no signer (D-86):** panels can't yet check the activation question as worded (HANDOFF §6b), so v1 activates versions manually only; a reworded question is v1.1 at the earliest |
| 7 | Swarm job payments on Robinhood (and Base) | Relay pays from bridged mainnet IMD |
| 8 | POOL4 GitHub repo (tests, deploy scripts; promised next week) and any audits | Fork from the verified Etherscan source; our own tests and the swarm audit cover it |

---

## 13. After v1

| Version | Additions |
|---|---|
| **v1.1** | Swap page with coin → coin routing through IMD; referrals (via `ref`); "trade to earn sPONDPAD" (rewards always below the protocol fee paid, paid as locked sPONDPAD, weekly Merkle checked by the swarm); milestone bounties; scam flags; daily swarm health report; X badge level 2 (swarm-verified tweet) |
| **v2** | Custom coins built and audited by the swarm (bytecode-attested); swarm review of every settings change; POOL4-style burn mode per coin; boosted or locked sPONDPAD tiers |
| **Later** | Dead-coin migration (Pons-style); outside liquidity providers; Base and Ethereum deployments |
