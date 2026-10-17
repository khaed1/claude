# Old PLEA v10 (#1242) after the Cabal died: live pool test (Sepolia, 2026-10-12 12:54–13:15 UTC)

User request: after the v10 Cabal dies, "strengthen the pool" with one 10,000 tIMD buy, then trade from many different wallets with 50–500 tIMD trades: first buys exceeding sells, then balanced, then sells exceeding buys and a pile of 300–1,000 tIMD sells. Record how the POOL4-style hook (`PleaHook` `0x3d4CcAc329010b8beA3b14498d9a45EAB00c68Cc`, a fork of POOL4's CappedBurnHook) reacts.

## Setup
- **Death confirmed (read only, 12:55):** `CabalGate.cabalAlive()` false, `diedAt` 1791809664 (12:54:24 UTC), `PLEA.restricted()` false, a plain transfer from wallet A simulates fine. The old site https://plea-make-your-case.sites.imd.fun/ shows "The Cabal is dead. PLEA trades freely forever.", the live price and burned total, 0 console errors.
- **Wallets:** 104 new throwaway Sepolia wallets (keys only in the session scratchpad, never committed): a distributor `0x6dD7…6965`, a whale `0xBfC3…F50B` (wallet 1), and 100 traders (wallets 4–103; 2–3 spare). Wallet A sent the distributor 0.025 ETH (tx `0xeea8073d…4bb2`); the distributor sent each wallet 0.0002 ETH. Each wallet took **10,000 tIMD from the TestIMD faucet** and approved tIMD and PLEA to Uniswap's `PoolSwapTest` (309 txs, 0 failed). Gas was almost free (base fee ~21 wei).
- **Sepolia gotcha:** an ETH transfer to a brand-new address now needs ~207k gas (Sepolia charges new state heavily); the first funding round with 21,000 gas reverted for all 103 wallets (cost ~nothing).
- **Trades:** `PoolSwapTest.swap`, exact input, hookData `abi.encode(trader)`; one transaction per wallet per round, ~20 per round in parallel; a random trader called `rebalance()` after each round. Data: `trades.jsonl` (every receipt: tIMD/PLEA moved, pool tick after, hook events, fees), `states.jsonl` (pool after each round; a few snapshots were served stale by the load-balanced RPC, the analysis uses receipts), `analysis.md` (per-phase numbers), scripts `common.py`, `fund.py`, `trade.py`, `analyze.py`.

## What the pool did

**Start:** 895.2M PLEA + 27.76 tIMD in the market band, buy wall 19.34 tIMD, price 5.78e-6 tIMD/PLEA (market cap ~5,783 tIMD), inventory cap 899.86M.

| Phase | Trades | tIMD in / out | Price change | Market cap after | PLEA burned |
|---|---|---|---|---|---|
| 0: one 10,000 tIMD buy | 1 | 10,000 / 0 | **×8.4** | 48.7k | 1,467,097 |
| 1: buys > sells (75% buys) | 100 (82 B / 18 S) | 18,883 / 6,013 | **+236%** | 163.5k | 571,897 |
| 2: balanced | 100 (54 / 46) | 14,318 / 11,806 | +16% | 189.7k | 382,686 |
| 3a: sells > buys (25% buys) | 60 (13 / 47) | 3,852 / 10,535 | **−41%** | 111.7k | 253,299 |
| 3b: pile of 300–1,000 sells | 56 (0 / 56) | 0 / 8,852 | **−63%** | 40.9k | 332,554 |

317 swaps from 80 wallets + 17 rebalances + 1 plain transfer: **every transaction succeeded**. Peak price 1.94e-4 (×33.5 the start). (One planned phase-3a round was skipped after an RPC connection error.)

1. **The launch pool is extremely thin.** At a 5,783 tIMD market cap the market band held only 27.76 tIMD. One 10,000 tIMD buy took **585M PLEA (58% of the supply)**, moved the price ×8.4 and paid 195% over the pre-trade price on average. On mainnet the same shape means the first large buyer can take most of the float.
2. **Once deep, trades move the price smoothly and symmetrically.** With ~15–25k tIMD in the pool, a 100 tIMD buy moved the price about **+0.7–0.8%** and a 100 tIMD sell about **−0.7–0.8%** (medians, phases 1–3a). Fills vs the price just before the trade: buys paid **+2.7%** (median; worst +4.7%), sells got **−2.6 to −3.2%** (worst −6.8% in the pile), i.e. the 1.75% fee plus slippage; 0.5% of every trade comes back to the trader as staked sIMD.
3. **Fees behave as specified, and the prize share goes to the pool after death.** The hook fee was 1.5% of the IMD side (1,262 tIMD in all) and 0.25% of the PLEA side was burned. `toPrize` was **0** on every trade: after the Cabal dies there are no seasons, so the 0.25% prize share joins the pool share (`_payFees`: `if (_alive()) toPrize = …`). Cashback 420 tIMD staked as sIMD for the traders through imd/acc's Stacker.
4. **Burn:** **3.0M PLEA burned** in 20 minutes (supply 999.98M → 996.98M), all from the 0.25% per-trade burn (half of it from the single whale buy, since the burn is on the PLEA leg). No trims.
5. **The capped burn (trim) never fired, and can't soon.** The inventory cap only ratchets down by ~300k PLEA a day (each trade logged `CapRatcheted` of a few hundred PLEA), so it stayed at **899.45M** while the pool held 156–337M PLEA. A trim (remove the excess PLEA from the pool and burn it) needs the pool to hold more than the cap: only a near-total dump of the whale's 555M PLEA would get there.
6. **The buy wall grows from fees but lags far below a fast pump.** Every `rebalance()` closed and redeployed the wall with the retained 0.5% pool share: **19.3 → 68.6 → … → 440 tIMD**. It is an IMD-only band from the reference tick down, and the reference tick moves at most **200 ticks (~2%) per block** toward the price (`MAX_REF_STEP`, an anti-manipulation guard). After the ×8 pump the wall's top stayed ~5× below the market and only climbed ~3,600 ticks in the 20 minutes, so it **never filled** (0 PLEA bought) and gave no support during the −63% pile. Keeper tip 0.01 tIMD was paid once (it needs ≥ 100 tIMD of work and at most once an hour).
7. **Whale overhang.** The whale sold 29.9M PLEA for 1,765 tIMD in the pile and still holds ~555M PLEA (≈55% of the supply), "worth" ~22.7k tIMD at the last price while the pool holds only ~8.6k tIMD + the 440 tIMD wall: it cannot exit without driving the price toward the wall.
8. **Gas (Sepolia's new schedule):** a wallet's first buy ~1.4–1.8M gas (new storage: buy basis, Stacker credit for a new trader), later buys ~548k, sells ~528k, rebalance under 3M. `PoolSwapTest` swaps need a ~2.5M+ gas limit because the hook requires `creditGas + 1M` left at `beforeSwap`.

## Takeaways for PLEA mainnet
- **Seed depth matters most.** A 5,700 IMD market cap with only the hook's PLEA as liquidity lets one buyer take most of the supply. Consider a launch window max buy that still applies after 90 minutes, a larger IMD side at seed, or a lower first-buy cap (v10 had `LAUNCH_MAX_BUY` 5M only in the first 90 min).
- **The wall's 2%-per-block reference makes it slow after pumps** (good against manipulation, but no support on the way down after a fast rise). The fee-funded wall grew ~22× in 20 minutes of active trading.
- **Trims are a slow, end-game mechanism** with this cap schedule: they matter only when the pool refills close to the cap.
