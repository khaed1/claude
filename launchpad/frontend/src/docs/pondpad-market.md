# The $PONDPAD market

After the Leap, $PONDPAD trades against IMD in its own Uniswap v4 pool, run by **PadMarketHook**, PondPad's fork of POOL4's capped-burn hook. Nobody can withdraw its liquidity.

## The fee

**3%** when the market opens, falling evenly to **1%** at day 7, then 1% for good. It's split like every protocol fee: 40% to the Pond (stakers), 25% to IMD workers, 20% growth, 15% treasury.

## The cap and the burn

The pool may only hold so much $PONDPAD: **the cap**. When sells push the pool above it, the extra is **trimmed**: 85% is burned and 15% goes to the Pond. Buys lower the cap, by at most 500,000 a day and never below 150,000,000. So burns only start once sells push the pool above where it opened.

## The backstop

The IMD from trims goes back into the pool as a buy wall a little above the price. Anyone can place it by calling the public `rebalance()` (and is paid a small tip). When sellers fill it, the $PONDPAD it bought is burned and shared the same way.

## Gas

Market swaps can need more gas than the estimate (the hook may settle trims and claims on the way), so the site adds 50% to the estimate. You only pay for the gas actually used.

## Testnet note

On the testnet the site trades through Uniswap's v4 test swap router, which has no minimum-out: your slippage is turned into a price limit, so if the price moves past it the swap stops there and the rest of your input stays in your wallet.
