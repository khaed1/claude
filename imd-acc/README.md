# imd/acc: trading cashback in staked IMD

Status: **idea / design, 2026-10-09.** Waiting on the IMD dev's answers about custom launches and hooks (see `plea/launch-spec.md`). Working name, inspired by TokenWorks' [btc/acc](https://www.token.works/archive/btcacc).

## The idea

Every trade in a participating IMD-ecosystem project sends **0.5% of the trade back to the trader as sIMD**. sIMD is the IMD staking vault's share token. The cashback is deposited straight into the vault in the trader's name. Next time the trader opens the staking page or their wallet, their sIMD balance has gone up, and it keeps earning the vault's yield.

- **No new token.** IMD is the token.
- **No custody.** imd/acc never holds the cashback; the vault mints the shares directly to the trader.
- **No extra fee.** Projects fund the 0.5% out of fees they already charge. That fixes btc/acc's adoption problem: apps wouldn't add 1% on top for users.

## How it works

1. A trader trades in a participating pool, for example PLEA/IMD.
2. The project's hook takes 0.5% of the trade **on the IMD side**, so no swap is needed on IMD-paired pools.
3. The hook calls `sIMD.deposit(cashback, trader)`. This is standard ERC-4626: `receiver` gets the shares.
4. The trader's sIMD balance grows. They can unstake at any time, apart from the vault's one-block hold.

## Building blocks

| Part | What it does |
|---|---|
| `Stacker` (shared contract) | `credit(trader, imdAmount)`: pulls IMD from the caller and calls `sIMD.deposit(amount, trader)`. Tracks totals per trader and per project, and emits `Stacked(project, trader, imd, shares)`. Optional batching: hooks accrue cashback per trader, and anyone can call `flush()` to deposit in bulk and save gas. |
| Drop-in hook | For IMD pools without their own hook. Takes X% in IMD in `afterSwap` and calls `credit`. Includes the `afterSwap` logic that Uniswap's frontend whitelisting needs (a btc/acc lesson). |
| Trader identity | The router passes the real trader in `hookData`. Fall back to `sender`; never use `tx.origin`. |
| Site | "Your stack" (sIMD from cashback, per project, and its IMD value now), plus leaderboards for top stackers and top projects. |

## Projects whose fees are in ETH

The first projects (PLEA, PondPad) collect their fees in IMD, so they can deposit straight into the vault. Projects paired with ETH, or with fees in ETH, use a batched route instead:

1. **On each trade**, the hook takes the 0.5% in ETH and calls `creditETH(trader)`. The ETH is recorded as the trader's `pendingETH`. Nothing is swapped yet, so it costs little gas.
2. **`flush()`** can be called by anyone, for a small tip like POOL4's keepers get. It:
   - swaps the pooled ETH to IMD in one trade through **POOL4**, IMD's main IMD/ETH pool
   - deposits that IMD into sIMD
   - gives each trader shares in proportion to their `pendingETH`
3. The trader's sIMD goes up after each flush.

Safety rules:
- **Price guard:** the swap must return at least a minimum amount of IMD, measured against a recent average price (TWAP) rather than the price at that moment.
- **Maximum batch size** per flush, so one flush can't move POOL4's price much.
- **Pending ETH can't go anywhere else.** It can only be swapped and credited to the trader it was recorded for.
- The order is fixed: the swap happens first, then shares are split, with rounding in the vault's favour.

Why not swap on every trade: a second swap inside each trade roughly doubles gas on Ethereum, and small swaps made mid-trade are easy to sandwich. One guarded batch avoids both.

Side benefit: POOL4 burns a cut of IMD on its trades, so every flush also burns some IMD.

## Facts checked

- sIMD vault: `0x9efa934d9fad4ae28c998a40195646b965a97247` (Ethereum). ERC-4626, so anyone can deposit for a `receiver`.
- `owner()` returns `0x0` (ownership renounced) and `paused()` returns `false`, both read on-chain on 2026-10-09. The owner's pause and rescue powers are gone.
- The vault has a one-block hold: shares can't be redeemed in the block they arrive. That's harmless for cashback.
- The vault is on **Ethereum only**.

## First projects

| Project | Chain | Plan | Status |
|---|---|---|---|
| **PLEA** | Ethereum | 0.5% of every PLEA/IMD trade deposited as sIMD for the trader. It comes out of PLEA's own fee if our hook sets the fee; otherwise it's an extra 0.5% (pending the IMD dev's answer). | Designing |
| **PondPad** | Robinhood Chain | IMD-paired launchpad; cashback as its trading-rewards feature, funded from existing fees. The sIMD vault is on Ethereum only, so this needs an sIMD vault on Robinhood Chain, a bridge, or plain-IMD cashback there. | Planned |

## Points now, token maybe later

v1 has **no token**:
- The product is IMD, and a second token would compete with it.
- imd/acc takes no cut, so a token would have nothing behind it.
- Projects adopt a neutral tool more easily.

What v1 does keep is a full **points record** from day one. Every `Stacked(project, trader, imd, shares)` event counts:
- **Trader points**: the IMD stacked for them, all-time, across all projects.
- **Project points**: the IMD its traders stacked.

This history already drives the leaderboards. If imd/acc takes off, it's the basis for a later token, launched through the IMD swarm and **airdropped to early stackers and integrating projects**. Nothing is promised: points are a record, not a claim. A token would only make sense if imd/acc adds something for it to back, such as a small protocol cut, an integration-incentive budget, or a vote on featured projects.

## Open questions

1. Is an sIMD vault planned on Robinhood Chain?
2. Gas: deposit on every trade, or accrue and batch with `flush()`? Batching is likely on Ethereum.
3. Should sells get cashback too, or buys only?
4. Should the Stacker have an owner at all? Preferably none, with immutable sIMD and IMD addresses.
5. Should it be built as an IMD `evm_contracts` job (contracts only) after PLEA ships?

## Lessons from btc/acc

- Make the hook pass Uniswap's whitelisting (the `afterSwap` logic) and support router `msgSender` and `hookData`.
- Own the main buying path. Each project's site swaps through its own hooked pool.
- Warn users about copycat v2/v3 pools.
- Fund the cashback from existing fees. Don't charge extra.
