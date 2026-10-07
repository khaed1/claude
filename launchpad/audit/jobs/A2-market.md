ID: A2
TITLE: $PONDPAD sale and market
FILES:
contracts/src/PondPadToken.sol
contracts/src/PadSale.sol
contracts/src/PaymentSwapper.sol
contracts/src/IntegratorVault.sol
contracts/src/PadMarketHook.sol
contracts/upstream/CappedBurnHook.sol
contracts/upstream/make_fork.py
contracts/src/MarketController.sol
contracts/src/PadBurner.sol
contracts/src/LiquidityReserve.sol
contracts/src/FeeSplitter.sol
FOCUS:
$PONDPAD (1B fixed supply) is sold on PadSale, an IMD bonding curve (600M sold, 300M to the pool, target ~8,460 IMD, 1% fee, snipe tax 80% -> 0 over 30 min, 15M per-wallet cap). At graduation the raise and 300M go to MarketController.launch, which opens PadMarketHook: our fork of POOL4's CappedBurnHook (upstream/CappedBurnHook.sol is the original; upstream/make_fork.py generates PadMarketHook.sol from it, so every change is in that script). Changes: IMD is currency0 ($PONDPAD address mined above IMD), ERC-20 quote instead of native ETH, dynamic LP fee 3% -> 1% over 7 days returned from beforeSwap, IMD-sized constants (cap floor 150M, decay 500k/day, 15% of trims to stakers). MarketController owns the hook forever; the only exit is migrate() (approved by the 7-day timelock, run by the team Safe, first 12 months).
Changed since round 1 (D-78): MarketController.launch measures what openMarket took; migration needs approveMigration (7-day sinkAdmin) and is run only by the migrator (team Safe), and the new hook inherits the placement floor, reference tick and cap (inheritGuards in make_fork.py; floor and cap only raised).
Changed since round 2 (D-79): IMD returned by an owner closeBackstop or a migration seed earns no keeper tip (untippedQuote, make_fork.py); a closed hook can't be reopened; migrate clears the old hook's allowances; sinkAdmin is immutable (no setSinkAdmin); PadSale.buyWith takes minImd, quoteBuy charges a completing buy only on the IMD it needs, graduation hands stray balances to the controller; new LiquidityReserve holds the 30M reserve until the market opens.
Changed since round 3 (D-80): MarketController refuses a cap floor below the deploy floor and a decay above 5x the deploy pace; fundInventory refunds only what it pulled (other balances to the splitter / burner); make_fork.py: refTick steps maxRefStep per block elapsed since the last swap, and matured claims are not realised inside a swap while IMD or $PONDPAD is synced; owners are fixed (FixedOwnable); FeeSplitter.distributeToken only $PONDPAD.
Look hardest at:
- Did make_fork.py change anything beyond its listed changes? Does the ETH -> ERC-20 quote conversion keep every settle/take/sync correct? Does the dynamic fee leak into cap, trim, burn, backstop or keeper-tip math?
- PadSale solvency, cap accounting across buyWith/sellFor and payment tokens, snipe tax timing, the completing buy's refund, graduation exactly once with the exact amounts and sqrt price.
- MarketController: can launch, collectFees, fundInventory, policy setters or migrate ever send pool assets to a wallet, open twice, change openedAt, or migrate into a hostile or already-open hook?
- Trim/burn/settleClaims/rebalance under adversarial keepers and outside routers (ordering, same block, partial settlement), PadBurner.
- Sell-side $PONDPAD fees and their split (collectFees -> FeeSplitter.distributeToken).
