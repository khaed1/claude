# imd/acc: trading cashback in staked IMD

Status: **Sepolia job ready, 2026-10-09.** imd/acc ships **first**, on Sepolia, as an IMD smart-contracts (`evm_contracts`) launch. PLEA then plugs into it as the **first integration**, so the PLEA Sepolia run doubles as imd/acc's first real test. Working name, inspired by TokenWorks' [btc/acc](https://www.token.works/archive/btcacc).

## Launch order

1. **imd/acc on Sepolia** (`imd-acc/job-sepolia.md`). Deploys TestIMD (with a faucet), TestSIMD (a fork of StakedIMD) and the Stacker, plus a small test page. Its README lists the three addresses.
2. **PLEA on Sepolia** (`plea/job-sepolia.md`). Reuses those three addresses instead of deploying its own. Its hook pays the 0.5% cashback through `stacker.credit`.
3. **Mainnet**: the Stacker is deployed against the real IMD and sIMD (`0x9efa…7247`), then PLEA mainnet points at it.

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
| `Stacker` (shared contract) | `credit(trader, imdAmount)`: pulls IMD from the caller and calls `sIMD.deposit(amount, trader)`. The caller is the project. Tracks totals (points) per trader and per project, and emits `Stacked(project, trader, imd, shares)`. No owner; the IMD and sIMD addresses are immutable. v1 deposits on every credit; batching with `flush()` comes with the ETH route in v2. |
| Integration rule | The project wraps `credit` in `try/catch`. If it fails (vault paused, anything else), the hook sends the cashback to the trader as plain IMD instead, so **a trade never reverts because of imd/acc**. |
| Drop-in hook | For IMD pools without their own hook. Takes X% in IMD in `afterSwap` and calls `credit`. Includes the `afterSwap` logic that Uniswap's frontend whitelisting needs (a btc/acc lesson). |
| Trader identity | The router passes the real trader in `hookData`. Fall back to `sender`; never use `tx.origin`. |
| Site | "Your stack" (sIMD from cashback, per project, and its IMD value now), plus leaderboards for top stackers and top projects. |

## Projects whose fees are in ETH

**This is v2; the Sepolia v1 job leaves it out.** The first projects (PLEA, PondPad) collect their fees in IMD, so they can deposit straight into the vault. Projects paired with ETH, or with fees in ETH, use a batched route instead:

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
| **PLEA** | Ethereum (Sepolia first) | First integration. 0.5% of every PLEA/IMD trade goes through `stacker.credit` as sIMD for the trader, out of PLEA's own fee (its hook sets the fees under `evm_contracts`). Falls back to plain IMD if credit fails. | Sepolia, after imd/acc |
| **PondPad** | Robinhood Chain | IMD-paired launchpad; cashback as its trading-rewards feature, funded from existing fees. The sIMD vault is on Ethereum only, so this needs an sIMD vault on Robinhood Chain, a bridge, or plain-IMD cashback there. | Planned |

## Points now, token maybe later

v1 has **no token**:
- The product is IMD, and a second token would compete with it.
- imd/acc takes no cut, so a token would have nothing behind it.
- Projects adopt a neutral tool more easily.

What v1 does keep is a full **points record** from day one. Every `Stacked(project, trader, imd, shares)` event counts:
- **Trader points**: the IMD stacked for them, all-time, across all listed projects.
- **Project points**: the IMD its traders stacked.

This history already drives the leaderboards. If imd/acc takes off, it's the basis for a later token, launched through the IMD swarm and **airdropped to early stackers and integrating projects**. Nothing is promised: points are a record, not a claim. A token would only make sense if imd/acc adds something for it to back, such as a small protocol cut, an integration-incentive budget, or a vote on featured projects.

## Sepolia launch settings

| Field | Value |
|---|---|
| Launch type | Smart contracts (`evm_contracts`) |
| `chainId` | `11155111` (Sepolia) |
| `owner` | your wallet (becomes TestSIMD's owner, who can pause it to test the fallback) |
| Contracts, in order | `TestIMD`, `TestSIMD`, `Stacker` |
| `ipfs` | `"imd-acc-test"` |
| `github` | `true` |
| `references` | `evm-contracts-launch`, `defi-native`, `eth-security`, `eth-testing`, `eth-frontend-ux`, `better-interface`, `pashov-skill`, `solidity-security-review` |

## Decided

- **Owner:** the Stacker has none, and its IMD and sIMD addresses are immutable. TestSIMD keeps an owner on Sepolia only, so integrators can pause it and test their fallback; mainnet uses the real, renounced sIMD.
- **Gas:** v1 deposits on every credit. Batching comes in v2 with the ETH route.
- **Build:** an IMD `evm_contracts` job, shipped **before** PLEA.
- **Points start at listing:** a listed project's credits earn points only from the block it was listed, never retroactively, so nobody can build fake history and then get approved. Each `projects.json` entry carries a `fromBlock`; PLEA's is its hook's deploy block.

## Open questions

1. Is an sIMD vault planned on Robinhood Chain?
2. Should sells get cashback too, or buys only? (PLEA's Sepolia job pays it on every trade.)

## Which projects earn points

Anyone can call `credit` with their own IMD. That is just staking for someone, and it can't be blocked without giving the Stacker an owner. So points are counted, not gated: the Stacker records everything, and only credits from **listed projects** earn points. Every `Stacked` event names its project, so the list can be applied at any time.

**v1 (decided): a project list in the site.** The test page ships a `projects.json` (`{address, name, fromBlock}`), starting empty. PLEA's hook is added with a site update once it is deployed. Credits from anything else show as "direct, no points". Real trading points already cost money (fees paid to trade), so the only cheap attack was a fake project, and this closes it.

**Later: the IMD panel decides the list.** The site file is replaced by a small `ProjectRegistry` contract with no owner:
1. **Apply.** A project calls `apply(project, name, sourceUrl)` and pays the oracle fee (0.5 IMD, plus any application fee we decide).
2. **The panel votes.** The registry sends an IMD oracle request (`answerType: bool`, a panel like PLEA's) asking: "Is this contract a real trading project that pays imd/acc cashback out of fees its traders pay? Its source must be verified; reject wallets, contracts that just call `credit` with their own IMD, and wash-trading setups."
3. **Listed.** The verdict comes back signed. The registry checks it the same way PLEA's gate does (EIP-712, the oracle signer, the recomputed `questionHash`), then sets `listed[project] = true` and emits `Listed`.
4. **Delisting.** Anyone can challenge a listed project for a fee. The panel votes again, and a lost vote emits `Delisted`.
5. **Points** count credits from listed projects, from the listing block until any delisting, never before.

The Stacker never changes. The site and any future token snapshot read the registry instead of `projects.json`, and PLEA's gate code already contains the verifier the registry needs. It would ship as its own small `evm_contracts` job, once more than one or two projects want in.

## Lessons from btc/acc

- Make the hook pass Uniswap's whitelisting (the `afterSwap` logic) and support router `msgSender` and `hookData`.
- Own the main buying path. Each project's site swaps through its own hooked pool.
- Warn users about copycat v2/v3 pools.
- Fund the cashback from existing fees. Don't charge extra.
