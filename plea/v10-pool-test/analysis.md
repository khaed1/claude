### Phase 0: one 10,000 tIMD buy
- Trades: **1** (1 buys, 0 sells), 1 wallets, none reverted.
- Flow: **10,000 tIMD in**, **0 tIMD out** (net +10,000).
- Price: 5.783e-06 → 4.875e-05 tIMD/PLEA (**+742.9%**); market cap 5,783 → 48,745 tIMD (on 1B supply).
- Pool at the end: 308.3M PLEA + 9,880 tIMD; buy wall 68.6 tIMD (0 PLEA filled); inventory cap 899.45M.
- Price move per 100 tIMD traded: buys +7.43% (median)
- Fill vs the price just before each trade (fee + slippage): buys pay +195.41% (median, worst +195.41%)
- Fees: 147.78 tIMD hook fee (of which 0.00 to the prize pot), 49.26 tIMD cashback staked as sIMD, **1,467,097 PLEA burned** by trades.
- Hook events: 1 cap ratchets, 0 trims, 1 rebalances (1 keeper tips); walls deployed: 68.6000 IMD.
- Gas (Sepolia): buy median 1,773,366, sell median 0.

### Phase 1: buys exceed sells (75% buys, 50-500 tIMD)
- Trades: **100** (82 buys, 18 sells), 59 wallets, none reverted.
- Flow: **18,883 tIMD in**, **6,013 tIMD out** (net +12,870).
- Price: 4.875e-05 → 1.635e-04 tIMD/PLEA (**+235.5%**); market cap 48,745 → 163,538 tIMD (on 1B supply).
- Pool at the end: 168.3M PLEA + 22,380 tIMD; buy wall 192.1 tIMD (0 PLEA filled); inventory cap 899.45M.
- Price move per 100 tIMD traded: buys +0.83% (median)
  sells -0.80% (median)
- Fill vs the price just before each trade (fee + slippage): buys pay +2.69% (median, worst +4.66%)
  sells get -3.18% (median, worst -3.79%)
- Fees: 370.62 tIMD hook fee (of which 0.00 to the prize pot), 123.54 tIMD cashback staked as sIMD, **571,897 PLEA burned** by trades.
- Hook events: 5 cap ratchets, 0 trims, 5 rebalances (0 keeper tips); walls deployed: 93.0495 IMD, 116.2341 IMD, 137.7863 IMD, 162.4739 IMD, 192.1286 IMD.
- Gas (Sepolia): buy median 1,429,284, sell median 527,859.

### Phase 2: balanced (50/50, 50-500 tIMD)
- Trades: **100** (54 buys, 46 sells), 64 wallets, none reverted.
- Flow: **14,318 tIMD in**, **11,806 tIMD out** (net +2,512).
- Price: 1.635e-04 → 1.897e-04 tIMD/PLEA (**+16.0%**); market cap 163,538 → 189,718 tIMD (on 1B supply).
- Pool at the end: 156.3M PLEA + 24,501 tIMD; buy wall 322.6 tIMD (0 PLEA filled); inventory cap 899.45M.
- Price move per 100 tIMD traded: buys +0.71% (median)
  sells -0.72% (median)
- Fill vs the price just before each trade (fee + slippage): buys pay +2.68% (median, worst +3.58%)
  sells get -2.68% (median, worst -3.33%)
- Fees: 391.39 tIMD hook fee (of which 0.00 to the prize pot), 130.46 tIMD cashback staked as sIMD, **382,686 PLEA burned** by trades.
- Hook events: 7 cap ratchets, 0 trims, 5 rebalances (0 keeper tips); walls deployed: 217.5514 IMD, 245.3352 IMD, 271.2768 IMD, 299.5484 IMD, 322.5907 IMD.
- Gas (Sepolia): buy median 548,060, sell median 527,817.

### Phase 3a: sells exceed buys (25% buys, 50-500 tIMD)
- Trades: **60** (13 buys, 47 sells), 44 wallets, none reverted.
- Flow: **3,852 tIMD in**, **10,535 tIMD out** (net -6,683).
- Price: 1.897e-04 → 1.117e-04 tIMD/PLEA (**-41.1%**); market cap 189,718 → 111,683 tIMD (on 1B supply).
- Pool at the end: 203.7M PLEA + 17,600 tIMD; buy wall 395.0 tIMD (0 PLEA filled); inventory cap 899.45M.
- Price move per 100 tIMD traded: buys +0.78% (median)
  sells -0.79% (median)
- Fill vs the price just before each trade (fee + slippage): buys pay +3.07% (median, worst +3.68%)
  sells get -2.59% (median, worst -3.55%)
- Fees: 217.36 tIMD hook fee (of which 0.00 to the prize pot), 72.45 tIMD cashback staked as sIMD, **253,299 PLEA burned** by trades.
- Hook events: 3 cap ratchets, 0 trims, 3 rebalances (0 keeper tips); walls deployed: 350.2244 IMD, 372.2516 IMD, 395.0455 IMD.
- Gas (Sepolia): buy median 548,074, sell median 527,823.

### Phase 3b: pile of sells (300-1,000 tIMD each, at the round-start price)
- Trades: **56** (0 buys, 56 sells), 54 wallets, none reverted.
- Flow: **0 tIMD in**, **8,852 tIMD out** (net -8,852).
- Price: 1.117e-04 → 4.087e-05 tIMD/PLEA (**-63.4%**); market cap 111,683 → 40,871 tIMD (on 1B supply).
- Pool at the end: 336.7M PLEA + 8,613 tIMD; buy wall 440.0 tIMD (0 PLEA filled); inventory cap 899.45M.
- No buys.
  sells -1.25% (median)
  sells get -2.28% (median, worst -6.82%)
- Fees: 134.81 tIMD hook fee (of which 0.00 to the prize pot), 44.94 tIMD cashback staked as sIMD, **332,554 PLEA burned** by trades.
- Hook events: 3 cap ratchets, 0 trims, 3 rebalances (0 keeper tips); walls deployed: 425.3984 IMD, 434.9795 IMD, 439.9805 IMD.
- Gas (Sepolia): buy median 0, sell median 493,148.

### Whole test
- 317 swaps from 80 wallets, 17 rebalances, 1 plain transfer; every transaction succeeded.
- Price 5.783e-06 → 4.087e-05 tIMD/PLEA; peak 1.938e-04.
- PLEA burned: 14,542 → 3,022,074 (supply 999.98M → 996.98M).
- Buy wall 19.34 → 439.98 tIMD, never filled.
- Whale (wallet 1): bought 585,371,520 PLEA for 10,000 tIMD; sold 29,924,716 PLEA for 1,765 tIMD in the pile.
