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
