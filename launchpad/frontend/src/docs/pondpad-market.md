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

## Trading it

The site trades the market through **Uniswap's Universal Router**, the same router POOL4 uses on Ethereum, in one transaction: pay with IMD, or with ETH or USDG (swapped to IMD through the same pools PondPad uses), and receive any of the three when you sell. Your slippage sets a **minimum out**: if the price moves past it, nothing is swapped. Tokens are pulled through **Permit2**, Uniswap's approval contract: the first time, your wallet approves Permit2 for the token, then each trade gives the router an exact allowance that expires after 30 minutes. $PONDPAD already lets Permit2 move it, so selling skips the first step.

Any other v4 router or aggregator can trade the pool too; the fee and the cap work the same whichever route you take.
