ID: A1
TITLE: Coin trading core
FILES:
contracts/src/BondingCurve.sol
contracts/src/PadHook.sol
contracts/src/PadRouter.sol
contracts/src/PaymentSwapper.sol
contracts/src/PadToken.sol
contracts/src/PadFactory.sol
contracts/src/PadConfig.sol
contracts/src/FeeLib.sol
contracts/src/Route.sol
contracts/src/CreatorVault.sol
contracts/src/SwarmBudget.sol
contracts/src/IntegratorVault.sol
contracts/src/FeeSplitter.sol
contracts/src/PadLens.sol
FOCUS:
Context: coins launch on an IMD bonding curve (80% sold, 20% to the pool, graduation at 4,000 IMD on mainnet, D-76) and graduate into a Uniswap v4 pool run by PadHook with full-range liquidity locked forever. Fees: 1% protocol + 0.5% creator + optional 0-3% coin tax, always on the IMD side, through any router. Users pay with IMD, ETH or USDG (PaymentSwapper routes up to 3 hops).
Changed since round 1 (D-78): curve buy/sell revert while the PoolManager is unlocked; completing-buy quote; no curve allowance to the hook; PadHook.flush does nothing inside any unlock; CreatorVault holder stream (fundHolders / releaseToHolders: ~7 days, at most one day's share per release) fed by claims to the coin and SwarmBudget.sweepToHolders; PadConfig fee splitter and growth fund fixed.
Look hardest at:
- Curve math and rounding: can any buy/sell sequence (incl. the completing buy and its refund, dev buy, snipe tax) make the curve insolvent or move graduation off the final price?
- Graduation: front-running pool init, inline vs. permissionless graduate() under an outside PoolManager unlock, the 1% fee / 1% reserve burn.
- PadHook v4 accounting: beforeSwap/afterSwap return deltas for exact-in and exact-out in both currency orderings, fee on the actually filled amount, PartialFill, empty-pool pushes, ERC-6909 claims and flush(), liquidity add/remove guards, hookData trust (trader and referrer).
- PadToken dividends: flash-borrow and same-block capture, transfers to/from the pool and curve, distribute() while the PoolManager is unlocked.
- PaymentSwapper/PadRouter: leftover funds, ETH refunds, permit, slippage, malicious payment routes within PadConfig bounds, reentrancy through tokens or ETH receivers.
- Integrator share (registered only, protocol fee only), CreatorVault recipient changes, SwarmBudget releases, FeeSplitter sums, PadLens quotes vs. real trades.
