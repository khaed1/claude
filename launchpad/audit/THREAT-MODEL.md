# PondPad v1: threat model for auditors

Read this before the code. It says who can do what, what must always hold, and which behaviours are **deliberate** (reporting them wastes a round). Design: [`../ARCHITECTURE-v1.md`](../ARCHITECTURE-v1.md); every decision with its reason: [`../DECISIONS.md`](../DECISIONS.md) (cited as D-n).

Chain: Robinhood Chain (4663), Uniswap v4 PoolManager `0x8366…0951`, IMD `0x5F7B…7127` (LayerZero OFT, 18 decimals), USDG `0x5fc5…d168` (6 decimals). Solidity 0.8.26, cancun, via-IR. No proxies (D-6).

**Block numbers (D-65).** Robinhood Chain is an Arbitrum Orbit chain: `block.number` returns the **Ethereum** block number (about every 12 s), not Robinhood's own block (several per second); `block.timestamp` is Robinhood's. Checked on mainnet and testnet (5 Oct 2026). So every "block" in the code is an Ethereum block shared by many Robinhood blocks:
- `PadMarketHook` `refTick` (used by `PadBuyer`'s price guard and the backstop placement) moves at most `maxRefStep` per Ethereum block toward the close of the last block that had a swap, the same real-time pace as POOL4 on Ethereum. Since D-80 (audit R3-A3-2) it counts every block elapsed since that close, not only blocks with a swap, so after quiet blocks it catches up with the price that stood. The "close" of an Ethereum block is the last swap before `block.number` changes, which many Robinhood transactions can reach.
- `lastClaimBlock`: trim claims are redeemed in a later Ethereum block (≤ ~12 s later).
- `StakedPONDPAD` hold: a deposit can't be redeemed until `block.number` changes (0–12 s). One drip releases at most 1/7 of the dripper's buffer (D-79), which bounds what a stake held across one block can capture.
Keeping Ethereum blocks is deliberate (D-65): Robinhood's own block number would let `refTick` move 50–100× faster in real time. In scope: any way to exploit the shared block (e.g. capturing the last swap before the number changes to drag `refTick`, or anything that assumes one block = one transaction batch). Known and accepted: if the reported Ethereum block number stalls, `refTick` freezes (PadBuyer may refuse to buy), claims wait and new deposits can't be redeemed until it moves; no funds are at risk. Fork tests advance blocks with `vm.roll`, which does not model this.

## 1. Actors and what they can do

| Actor | Powers | Trust |
|---|---|---|
| Traders, creators, sale buyers, stakers | Trade through `PadRouter` / `PadSale` / any v4 router (after graduation), launch coins, stake | Untrusted. Assume flash loans, MEV, many wallets, contracts as wallets |
| Outside routers and hooks callers | Swap in graduated coin pools and the $PONDPAD market through the PoolManager | Untrusted. May unlock the PoolManager and call anything in the callback |
| Keepers | Every upkeep call (HANDOFF §6) is permissionless | Untrusted; may call in any order, at any time, repeatedly, or never |
| Team Safe | Proposes to both timelocks (whose delays can never go below the deploy values, `PondPadTimelock`, D-80); guardian (pause **new** launches, register integrators); council (CTO fallback until retired; 90-day per-coin wait after a cancel; an attested proposal replaces its pending one); granter (GrowthFund, capped); treasury; team-vesting beneficiary; `MarketController.migrator` (runs a migration only into the hook the 7-day timelock approved, D-78) | Semi-trusted: powers must stay inside the bounds in code. A finding is anything that lets it exceed them |
| 48 h timelock | Owner of `PadConfig` (launch settings, routes, integrator share; **not** the fee splitter or growth fund, which are fixed, D-78), `SwarmBudget`, `SocialRegistry`, `GrowthFund`, `MarketController` (policy; cap floor never below 150M, decay at most 2.5M/day, D-80), `RewardDripper` (within `1 h ≤ maxCatchup ≤ smoothing / 7`, `minDripAmount ≤ 100,000`, D-79), `PadBuyer`, `AirdropDistributor`; receives the 30M liquidity reserve from `LiquidityReserve` once the market is open (D-79) | Same as the Safe, delayed. Every owned contract is `FixedOwnable`: no owner can transfer, renounce or hand over its powers (only the deployer's one handoff at deploy, D-80) |
| 7-day timelock | Owner of `FeeSplitter`, `AttestationVerifier`, `CTOModule`, `VersionRegistry`, `WorkerFund`, `StakedPONDPAD`; `MarketController.sinkAdmin` (sinks, migration approval; fixed, it can't hand the role on, D-79) | Same as the Safe, delayed |
| Swarm Relay hot wallet | `GrowthFund.payJob` ≤ 100 IMD / 7 days; `SwarmBudget` job releases | Assume the key can leak: damage must stay within its caps |
| X link service key | Signs `SocialRegistry` vouchers | Can leak: it can link handles, never move funds |
| Tweet checker key | Signs `AirdropDistributor` initiation vouchers | Can leak: it must not be able to activate the airdrop alone (needs 100 distinct **listed** wallets) |
| IMD oracle signer | Signs attestations checked by `AttestationVerifier` | Trusted for its answer; the contracts must bind each answer to one exact question and use it once |
| Deployer | Runs `script/Deploy.s.sol` once | Must end with **no** power and **no** $PONDPAD |

Trusted externals: the v4 PoolManager, IMD and USDG tokens, the ETH/USDG pool's own hook, the IMD/ETH pool.

## 2. Invariants (each one broken is at least High)

**Coins (curve, hook, router)**
1. A coin's curve always holds enough IMD to pay every seller; it never pays out more than it holds (rounding favours the curve).
2. Graduation opens the pool at the curve's final price (± rounding). Nobody can initialize a pool with `PadHook` except the hook itself, so graduation can't be blocked or front-run.
3. Locked liquidity can never be removed; nobody else can add liquidity to a `PadHook` pool.
4. Every trade, through any router, pays exactly the coin's fee bps on the **filled** IMD amount. A swap with IMD as the specified side that fills only partly reverts (`PartialFill`).
5. A coin's saved settings (fees, tax split, target, curve) never change after launch. Admin settings apply to future launches only.
6. Dividends and staking rewards can't be captured with flash-borrowed tokens or within one block. Dividends are never paid while the PoolManager is unlocked by an outside caller; curve trades revert inside an outside unlock. Lumps routed to a coin's holders (creator fees, swept swarm budget) are released through `CreatorVault`'s holder stream over ~7 days, at most one day's share per release (D-78); funding the stream is refused inside an outside unlock, and a top-up never lowers its rate (D-79). Since D-80 the holder stream lives in the coin (`PadToken`): it credits holders second by second, settled before every balance change (inside an unlock too), so a balance held for no time earns nothing from it (audit R3-A4-1); while nobody is eligible it waits (R3-A4-2); a new lump ends at the amount-weighted average of the running end and now + 7 days (R3-A1-2). A holder tax is never parked on a coin with nobody eligible, nor credited back to a trader who is the only eligible holder (curve trades and PadRouter pool trades: it goes to the growth fund, D-79, D-80), so no buyer is credited its own tax beyond its pro-rata share of what it already held (accepted, R1-A1-3).
7. Snipe tax and max-buy can't be bypassed (curve trades only through `PadRouter`).
8. The integrator share goes only to registered integrators named in `PadRouter`'s hook data, comes only out of the protocol fee, and never touches the creator share or coin tax.
9. Routers and the sale never keep user funds between transactions; slippage limits and refunds (ETH, overshoot IMD) are exact. `buyWith` on the router (curve buys) and the sale also bounds the IMD the payment swap must deliver (`minImd`, D-79), since a completing buy gets the same tokens whatever IMD arrives.

**$PONDPAD sale and market**
10. `PadSale`: curve solvency as in (1); the 15M cap counts every buy over the whole sale (sells don't free it); graduation happens once and hands the exact net raise and 300M $PONDPAD to `MarketController.launch` (with anything sent to the sale outside `buyWith` / `fund`, which the controller sends to the splitter or burns, D-79). The 30M liquidity reserve can't move until the market is open, so it can't be sold into the sale (D-79).
11. The market opens once, only from the sale, at the sale's final price. No path ever sends pool liquidity, backstop IMD or inventory to a wallet; IMD returned by an owner `closeBackstop` or seeded by a migration earns no keeper tip (D-79). The owner can't set the cap floor below the deploy floor (150M) or the decay above 5× the deploy pace (D-80, audit R3-A2-1), so owner settings can't let trading trim the position away. `fundInventory` refunds only what it pulled and didn't use (R3-A2-5). Matured claims are not realised inside a swap while the swapper has IMD or $PONDPAD synced, so a pay-first router works (R3-A2-3). A closed hook can't be reopened. `migrate` is only by the team Safe (`migrator`) into the hook the 7-day timelock approved, only within 12 months of `openedAt`, only into an unopened hook for the same pair owned by the same controller, at the same price, fee clock, backstop placement floor, reference tick and cap (floor and cap only raised, D-78). `openedAt` never changes. Exception, a listed power: `sinkAdmin` can point the burn sink and rewards recipient at any address (ARCHITECTURE §5.4.1).
12. `PadMarketHook` behaves like POOL4's `CappedBurnHook` except for the listed changes (`upstream/make_fork.py` is the exact diff). The dynamic fee (3% → 1% over 7 days) never enters cap, trim, burn or backstop math.

**Staking and funds**
13. Staked $PONDPAD and the dripper's reward buffer can never be rescued. Pauses last ≤ 3 days with ≥ 4 unpaused days between. All staking owner powers end at `powersExpireAt`.
14. `StakedPONDPAD.totalAssets` is the vault's own count (deposits, withdrawals, rewards taken in by `syncRewards`), never its raw balance, so a transfer can't move the share price; rewards are taken in only while at least 1e18 shares and 1 $PONDPAD are staked, and the dripper releases nothing for time the vault was closed (D-79). One drip releases at most 1/7 of the buffer (the `minDripAmount` floor included, D-80, audit R3-A3-1), or a remainder under one $PONDPAD. The vault's one-block hold applies only to shares that arrived in the current block; `PadBuyer` can only send $PONDPAD to the dripper and refuses to buy after a price pump (its overpay bound against the pre-pump price is `maxRefStep + maxDeviation + maxSlippage` ticks per Ethereum block, ~4% at the defaults, D-79; the reference catches up over blocks without swaps too, D-80, R3-A3-2).
15. `FeeSplitter` outputs equal its inputs; shares stay in their ranges; besides IMD it splits only $PONDPAD (D-80, R3-A3-8). `WorkerFund` pays only the worker rewards address. `GrowthFund` pays only within its per-epoch caps, only capped tokens.

**Governance**
16. An attestation is accepted only from the approved signer, for the consumer's exact rebuilt question hash, with panel ≥ 51, agreed ≥ 2/3 (an exact fraction, whatever the panel size, D-80) and ≥ quorum, inside its validity window, with `fromBlock ≤ toBlock`, and once; consumers log its evidence chain and window (D-79).
17. `CTOModule`: all guards hold (coin ≥ 30 days, 90-day cooldown, contract recipient that is not an EIP-7702 delegated wallet, X-verified proposer, notice periods, contest → +7 days and a ≥ 75 panel answering after the contest about the X account stored at proposal, its question naming the time of the contest). The recipient is checked again at execute (same code), and execute is refused inside an outside PoolManager unlock. A coin whose fees go to its holders can't be taken over again (D-79). The rules link is at most 256 characters. Attested takeovers can't be cancelled, and replace a pending council proposal; the council waits 90 days per coin after a cancel, or after its contested proposal lapsed unconfirmed (D-80, R3-A4-7). A valid "no" can be recorded by anyone: a "yes" to the same question issued in the 90 days after a recorded "no" doesn't count, a pending attested takeover whose "yes" came after it ends, a confirmation "no" ends a contested takeover unless an earlier "yes" confirmed it, and a takeover ended by a "no" blocks the coin for 90 days (D-80, R3-A4-8). Fallbacks (council CTO, manual version activation) retire one-way; a council proposal pending at retirement can't execute.
18. `VersionRegistry`: activation needs an attestation for the exact code hash and addresses, or the owner fallback until retired. An activation moves `currentVersion` only above the highest version ever activated; only the owner rolls back or chooses among older versions (D-80, R3-A4-6). The registry is informational (no launch path reads it).
19. `SocialRegistry` vouchers can't be replayed, used after their deadline, or used by anyone but the coin's fee recipient (or the wallet itself for `linkWallet`); a revocation voids every voucher signed before it; a coin's badge counts only while the account that linked it is the fee recipient (D-80, R3-A4-5, R3-A4-9).

**Distribution**
20. `AirdropDistributor`: total claims ≤ 50M (enforced by the token balance; `Deploy.s.sol` adds up the listed claims, refuses a total over 50M and rebuilds the root from the claims, D-79, D-80); one X account counts once (`handleHash` is keccak256 of the numeric X user id, `tweetHash` of the tweet id, R3-A3-7); only listed (address, amount) leaves; activation needs 100 distinct listed wallets, each with its own X account and tweet, after market open; vesting runs 30 days from activation; claim-wallet signatures (EIP-712 / ERC-1271) can't be replayed; `sweep` only after 180 days and only to `RewardDripper`; the owner can only replace the checker key.
21. `TeamVesting`: nothing before day 30 after `openedAt`, linear to day 180, always to the beneficiary.

**Deployment**
22. After `Deploy.s.sol`, every owner is as in D-57 and fixed (`FixedOwnable`), both timelocks refuse a delay below 48 h / 7 days (`PondPadTimelock`), launches were paused until fee routing was final, the deployer holds no role and no $PONDPAD, the supply is 900M sale / 50M airdrop / 20M vesting / 30M `LiquidityReserve` (for the 48 h timelock once the market opens), both hooks have the right flags and $PONDPAD's address is above IMD's.

## 3. Deliberate behaviour: do not report

- Anyone can open another pool for a coin and avoid our fee (D-29).
- The sale's per-wallet cap can be split across wallets; it is a speed bump (D-35). Humans buying in the first 30 minutes also pay the snipe tax.
- The airdrop has **no fallback** if 100 wallets never initiate (D-55).
- Sells above the market cap are trimmed in full and burned, as in POOL4 (D-21). The 3% fee band in week one invites arbitrage (D-34).
- The guardian registers integrators without a timelock; registration only redirects protocol revenue (D-33).
- Admin powers listed in `ARCHITECTURE-v1.md` §5.6 exist on purpose. Report only ways to **exceed** them.
- The council CTO and manual version activation exist until retired (D-46); version 1 is activated manually at deploy when an audit link is given (D-57, D-59).
- `PadBuyer` accepts up to ~2% sandwich loss on one small chunk relative to its reference, ~4% relative to the pre-pump price (D-43, D-79).
- Accepted by the project owner (D-79): pool buyers share a little of their own holder tax (R1-A1-3); a stake held across one Ethereum block earns its pro-rata share of a drip (R1-A3-3, bounded to 1/7 of the buffer); a requester can cancel a swarm request before the relay releases it (R1-A1-5); GrowthFund caps per fixed epoch (R1-A3-9); a version's code hash covers five contracts (R1-A4-7); a migration hook is checked only through its answers (R1-A2-7); the 7-day owner can change the verifier and signers, so "retire one-way" binds the council path, not the owner (R1-A4-17); `PadLens.quoteBuy` doesn't know the wallet's max-buy (R1-A1-7).
- The `PadHook` address is a sink: tokens sent to it go to growth or are burned at the next graduation (R2-A1-4). The `PadMarketHook` address is a sink too: tokens sent straight to it stay there (R3-A2-4).
- sPONDPAD has 24 decimals (18 + the 6-decimal offset); after a stranger's dust deposit a holder exits with `maxRedeem`, not the full balance, for that block (R3-A3-4, R3-A3-6).
- A migration hook's audit is a process rule, not enforced onchain (D-40).
- `WorkerFund` forwards $PONDPAD without swapping it (D-45).
- POOL4 code we did not change: report it only if it breaks one of our invariants on Robinhood with an IMD quote.

## 4. Severity

| Severity | Meaning |
|---|---|
| Critical | Anyone can steal or permanently freeze user or protocol funds, remove locked liquidity, or mint / inflate supply |
| High | Loss or theft under realistic conditions; breaks an invariant in §2; lets an admin, key or keeper exceed its bounds |
| Medium | Bounded loss, griefing that costs the attacker less than the victim, wrong accounting with a limited effect, DoS of a non-critical path |
| Low | Edge cases with no realistic loss, missing checks with no impact today |
| Info | Style, gas, docs |

A round is **clean** when all four jobs' judges report no open Critical or High. Every Medium is fixed or accepted by the project owner in writing in `FINDINGS.md`.
