# PondPad keeper

Calls PondPad's permissionless upkeep functions on a timer (HANDOFF §6). Anyone can run one; nothing depends on a single operator. Each job checks a cheap view, **simulates** the call and sends it only if the simulation succeeds, so a keeper never pays for a call that would revert.

## Run

```bash
npm install
export RPC_URL=https://rpc.mainnet.chain.robinhood.com
export KEEPER_KEY=0x…          # hot wallet with a little ETH (gas on Robinhood is ~0.04 gwei)
node keeper.mjs --once --dry   # simulate everything, send nothing
node keeper.mjs                # loop every 5 minutes (INTERVAL_SECONDS)
```

or from cron: `*/5 * * * * cd /path/to/keeper && node keeper.mjs --once >> keeper.log 2>&1`.

Addresses come from `../contracts/deployments/4663.json`, which `script/Deploy.s.sol` writes (override with `DEPLOYMENT`). The last run of each job is kept in `state.json` (`STATE`).

## Jobs

| Job | Cadence | Runs when |
|---|---|---|
| `PadSale.graduate()` | 1 min | the sale is full but the completing buy couldn't graduate it |
| `MarketController.collectFees()` | daily | the market is open (also runs the splitter for both fee tokens) |
| `FeeSplitter.distribute()` | daily | the splitter holds IMD |
| `PadBuyer.buy()` | its own `interval()` (10 min by default) | the market is open, the buyer holds ≥ 1 IMD and its interval has passed (pays the keeper 0.5%) |
| `RewardDripper.drip()` | hourly | `canDrip()` (pays the keeper 10 $PONDPAD) |
| `PadMarketHook.rebalance()` | 5 min | `pendingRebalance()` (pays the keeper up to 1 IMD) |
| `PadMarketHook.settleClaims()` | hourly | trims left claims to settle |
| `PadBurner.burn()` | hourly | the burner holds $PONDPAD |
| `WorkerFund.release()` | weekly | the worker rewards address is set and the fund holds IMD or $PONDPAD |
| `TeamVesting.release()` | daily | something is releasable (always pays the team Safe) |
| `LiquidityReserve.release()` | hourly, once | the market is open and the reserve still holds $PONDPAD (sends all 30M to the 48 h timelock; D-79) |
| `AirdropDistributor.sweep()` | daily | the claim window is over and tokens are left (to stakers) |
| `BondingCurve.graduate(coin)` | 5 min | a coin's curve is full but not graduated |
| `PadHook.flush(coin)` | hourly | a graduated coin has pending fees (trades through outside routers) |
| `CTOModule.execute(coin)` | hourly | a takeover's notice has passed and its window is open |
| `CreatorVault.claim(coin)` + `SwarmBudget.sweepToHolders(coin)` | weekly | the coin's fees go to its holders (D-52); both feed the coin's holder stream (D-78), which pays out second by second by itself (D-80) |

A job whose condition is false is checked again on the next pass; once it has tried to send, it waits for its cadence. Per-coin reads are batched through Multicall3 (newest `MAX_COINS_PER_PASS` coins, default 500).

## Tested

On an anvil fork of Robinhood Chain (5 Oct 2026): `forge script script/Deploy.s.sol --broadcast` into the fork, sale bought out by 86 wallets, then keeper passes: fees collected and split, `PadBuyer.buy`, `RewardDripper.drip` after a stake, `settleClaims`, `TeamVesting.release` after 30 days, per-coin reads with a launched coin; nothing sent before the sale (all conditions false).
