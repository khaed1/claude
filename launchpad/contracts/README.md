# PondPad contracts

Foundry project for PondPad v1 on Robinhood Chain. Design: [`../ARCHITECTURE-v1.md`](../ARCHITECTURE-v1.md).

## Status

Core launch-and-trade path, tested end to end against a real Uniswap v4 PoolManager:

| Contract | Role |
| --- | --- |
| `PadToken` | The launched coin: 1B fixed supply, no owner, EIP-2612 permit, IMD dividends for holders (flash-borrow safe) |
| `BondingCurve` | IMD bonding curve (80% sold / 20% to the pool), fees, snipe tax, early max-buy, graduation |
| `PadHook` | Uniswap v4 hook: opens the pool at the curve's final price, owns locked full-range liquidity, charges fees through any router, rejects partial fills |
| `PadRouter` | Launch with dev buy, buy, sell, sell with permit, paying or receiving IMD or ETH (ETH ⇄ IMD through the IMD/ETH pool set in `PadConfig`); routes to the curve or the pool |
| `PadFactory` | Deploys coins with CREATE2 |
| `PadConfig` | Bounded launch settings, fee/growth addresses, IMD/ETH pool key, guardian pause of new launches |
| `FeeSplitter` | Protocol IMD → stakers 40% / workers 25% / growth 20% / treasury 15%, within fixed ranges |
| `CreatorVault` | Creator fees per coin, recipient changes, CTO hook-in |
| `SwarmBudget` | Per-coin escrow for swarm jobs, released by the Swarm Relay |

Not built yet: `PadLens`, `VersionRegistry` and `AttestationVerifier`, `CTOModule`, `SocialRegistry`, staking (`StakedPONDPAD`, `RewardDripper`, `PadBuyer`), `WorkerFund`/`GrowthFund`, the $PONDPAD sale and the POOL4 fork (`PadMarketHook`, `MarketController`), and deploy scripts.

## Build and test

```bash
git submodule update --init --recursive
forge build
forge test

# Against live Robinhood Chain (real PoolManager, IMD and IMD/ETH pool):
FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork -vv
```
