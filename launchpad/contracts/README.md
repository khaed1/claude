# PondPad contracts

Foundry project for PondPad v1 on Robinhood Chain. Design: [`../ARCHITECTURE-v1.md`](../ARCHITECTURE-v1.md).

## Status

Core launch-and-trade path and the $PONDPAD sale and market, tested end to end against a real Uniswap v4 PoolManager:

| Contract | Role |
| --- | --- |
| `PadToken` | The launched coin: 1B fixed supply, no owner, EIP-2612 permit, IMD dividends for holders (flash-borrow safe) |
| `BondingCurve` | IMD bonding curve (80% sold / 20% to the pool), fees, snipe tax, early max-buy, graduation |
| `PadHook` | Uniswap v4 hook: opens the pool at the curve's final price, owns locked full-range liquidity, charges fees through any router, rejects partial fills |
| `PadRouter` | Launch with dev buy, buy, sell, sell with permit, paying or receiving IMD, ETH, USDG or any payment token approved in `PadConfig` (swapped to and from IMD along its route); routes to the curve or the pool |
| `PadFactory` | Deploys coins with CREATE2 |
| `PadConfig` | Bounded launch settings, fee/growth addresses, payment tokens and their routes to IMD, integrator registry and share, guardian pause of new launches |
| `IntegratorVault` | Integrator (app/bot) earnings: 15% of the protocol fee on trades they route |
| `FeeSplitter` | Protocol IMD (and the $PONDPAD market's sell-side fees) → stakers 40% / workers 25% / growth 20% / treasury 15%, within fixed ranges |
| `CreatorVault` | Creator fees per coin, recipient changes, CTO hook-in |
| `SwarmBudget` | Per-coin escrow for swarm jobs, released by the Swarm Relay |
| `PaymentSwapper` | Payment plumbing shared by `PadRouter` and `PadSale` |
| `PondPadToken` | $PONDPAD: 1B fixed supply, no owner, permit, burn |
| `PadSale` | $PONDPAD IMD bonding curve (600M sold / 300M to the pool), snipe tax, per-wallet cap; opens the market at graduation |
| `PadMarketHook` | $PONDPAD/IMD market: fork of POOL4's `CappedBurnHook` with an IMD quote and a 3% → 1% dynamic fee. Original in `upstream/` (`diff upstream/CappedBurnHook.sol src/PadMarketHook.sol`) |
| `MarketController` | Permanent owner of the market hook; opens it once, sends fees to the splitter, no way to withdraw the position |
| `PadBurner` | Burns the $PONDPAD the market trims |

Not built yet: `PadLens`, `VersionRegistry` and `AttestationVerifier`, `CTOModule`, `SocialRegistry`, staking (`StakedPONDPAD`, `RewardDripper`, `PadBuyer`), `WorkerFund`/`GrowthFund`, `AirdropDistributor`/`TeamVesting`, and deploy scripts.

## Build and test

```bash
git submodule update --init --recursive
forge build
forge test

# Against live Robinhood Chain (real PoolManager, IMD and IMD/ETH pool):
FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork -vv
```
