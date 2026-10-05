# PondPad v1: threat model for auditors

Read this before the code. It says who can do what, what must always hold, and which behaviours are **deliberate** (reporting them wastes a round). Design: [`../ARCHITECTURE-v1.md`](../ARCHITECTURE-v1.md); every decision with its reason: [`../DECISIONS.md`](../DECISIONS.md) (cited as D-n).

Chain: Robinhood Chain (4663), Uniswap v4 PoolManager `0x8366…0951`, IMD `0x5F7B…7127` (LayerZero OFT, 18 decimals), USDG `0x5fc5…d168` (6 decimals). Solidity 0.8.26, cancun, via-IR. No proxies (D-6).

## 1. Actors and what they can do

| Actor | Powers | Trust |
|---|---|---|
| Traders, creators, sale buyers, stakers | Trade through `PadRouter` / `PadSale` / any v4 router (after graduation), launch coins, stake | Untrusted. Assume flash loans, MEV, many wallets, contracts as wallets |
| Outside routers and hooks callers | Swap in graduated coin pools and the $PONDPAD market through the PoolManager | Untrusted. May unlock the PoolManager and call anything in the callback |
| Keepers | Every upkeep call (HANDOFF §6) is permissionless | Untrusted; may call in any order, at any time, repeatedly, or never |
| Team Safe | Proposes to both timelocks; guardian (pause **new** launches, register integrators); council (CTO fallback until retired); granter (GrowthFund, capped); treasury; team-vesting beneficiary | Semi-trusted: powers must stay inside the bounds in code. A finding is anything that lets it exceed them |
| 48 h timelock | Owner of `PadConfig`, `SwarmBudget`, `SocialRegistry`, `GrowthFund`, `MarketController` (policy), `RewardDripper`, `PadBuyer`, `AirdropDistributor`; holds the 30M liquidity reserve | Same as the Safe, delayed |
| 7-day timelock | Owner of `FeeSplitter`, `AttestationVerifier`, `CTOModule`, `VersionRegistry`, `WorkerFund`, `StakedPONDPAD`; `MarketController.sinkAdmin` (sinks, migration) | Same as the Safe, delayed |
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
6. Dividends and staking rewards can't be captured with flash-borrowed tokens or within one block. Dividends are never paid while the PoolManager is unlocked by an outside caller.
7. Snipe tax and max-buy can't be bypassed (curve trades only through `PadRouter`).
8. The integrator share goes only to registered integrators named in `PadRouter`'s hook data, comes only out of the protocol fee, and never touches the creator share or coin tax.
9. Routers and the sale never keep user funds between transactions; slippage limits and refunds (ETH, overshoot IMD) are exact.

**$PONDPAD sale and market**
10. `PadSale`: curve solvency as in (1); the 15M cap counts every buy over the whole sale (sells don't free it); graduation happens once and hands the exact net raise and 300M $PONDPAD to `MarketController.launch`.
11. The market opens once, only from the sale, at the sale's final price. No path ever sends pool liquidity, backstop IMD or inventory to a wallet. `migrate` is only by the 7-day timelock, only within 12 months of `openedAt`, only into an unopened hook for the same pair owned by the same controller, at the same price. `openedAt` never changes.
12. `PadMarketHook` behaves like POOL4's `CappedBurnHook` except for the listed changes (`upstream/make_fork.py` is the exact diff). The dynamic fee (3% → 1% over 7 days) never enters cap, trim, burn or backstop math.

**Staking and funds**
13. Staked $PONDPAD and the dripper's reward buffer can never be rescued. Pauses last ≤ 3 days with ≥ 4 unpaused days between. All staking owner powers end at `powersExpireAt`.
14. The dripper never drips into an empty vault; `PadBuyer` can only send $PONDPAD to the dripper and refuses to buy after a price pump.
15. `FeeSplitter` outputs equal its inputs; shares stay in their ranges. `WorkerFund` pays only the worker rewards address. `GrowthFund` pays only within its per-epoch caps, only capped tokens.

**Governance**
16. An attestation is accepted only from the approved signer, for the consumer's exact rebuilt question hash, with panel ≥ 51, agreed ≥ 2/3 and ≥ quorum, inside its validity window, and once.
17. `CTOModule`: all guards hold (coin ≥ 30 days, 90-day cooldown, contract recipient, X-verified proposer, notice periods, contest → +7 days and a ≥ 75 panel). Attested takeovers can't be cancelled. Fallbacks (council CTO, manual version activation) retire one-way.
18. `VersionRegistry`: activation needs an attestation for the exact code hash and addresses, or the owner fallback until retired.
19. `SocialRegistry` vouchers can't be replayed, used after their deadline, or used by anyone but the coin's fee recipient (or the wallet itself for `linkWallet`).

**Distribution**
20. `AirdropDistributor`: total claims ≤ 50M; only listed (address, amount) leaves; activation needs 100 distinct listed wallets, each with its own X account and tweet, after market open; vesting runs 30 days from activation; claim-wallet signatures (EIP-712 / ERC-1271) can't be replayed; `sweep` only after 180 days and only to `RewardDripper`; the owner can only replace the checker key.
21. `TeamVesting`: nothing before day 30 after `openedAt`, linear to day 180, always to the beneficiary.

**Deployment**
22. After `Deploy.s.sol`, every owner is as in D-57, the deployer holds no role and no $PONDPAD, the supply is 900M sale / 50M airdrop / 20M vesting / 30M 48 h timelock, both hooks have the right flags and $PONDPAD's address is above IMD's.

## 3. Deliberate behaviour: do not report

- Anyone can open another pool for a coin and avoid our fee (D-29).
- The sale's per-wallet cap can be split across wallets; it is a speed bump (D-35). Humans buying in the first 30 minutes also pay the snipe tax.
- The airdrop has **no fallback** if 100 wallets never initiate (D-55).
- Sells above the market cap are trimmed in full and burned, as in POOL4 (D-21). The 3% fee band in week one invites arbitrage (D-34).
- The guardian registers integrators without a timelock; registration only redirects protocol revenue (D-33).
- Admin powers listed in `ARCHITECTURE-v1.md` §5.6 exist on purpose. Report only ways to **exceed** them.
- The council CTO and manual version activation exist until retired (D-46); version 1 is activated manually at deploy when an audit link is given (D-57, D-59).
- `PadBuyer` accepts up to ~2% sandwich loss on one small chunk (D-43).
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

A round is **clean** when the judge confirms no open Critical or High. Every Medium is fixed or accepted by the project owner in writing in `FINDINGS.md`.
