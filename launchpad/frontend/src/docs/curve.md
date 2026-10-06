# The curve and the Leap

A new coin trades on a **bonding curve**: a constant-product curve of virtual IMD and token reserves. Each buy raises the price; each sell lowers it. The curve always holds enough IMD to pay every seller.

When the IMD raised reaches the **graduation target** (4,000 IMD on mainnet; 2,060 IMD on the testnet), the coin makes **the Leap**:

1. 1% of the raise goes to growth, and a matching 1% of the reserved tokens is burned so the price doesn't jump.
2. A Uniswap v4 pool opens at the curve's final price, with the raised IMD and the 200M reserved tokens.
3. The liquidity belongs to PondPad's hook, which has **no function to remove it**: it is locked forever.
4. The Chorus starts on the coin's free website.

After the Leap the coin trades in its pool through PondPad or any v4 router, with the same fees.

**Graduation only means the curve filled. It is not a quality signal.**
