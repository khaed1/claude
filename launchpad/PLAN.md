# IMD launchpad on Robinhood Chain: competitor analysis and build plan

> **Superseded:** the current design is [`ARCHITECTURE-v1.md`](ARCHITECTURE-v1.md). This file is kept for the competitor analysis (section 1).

Working name: **the Pad**, launchpad token **$PAD** (placeholders, rename freely).

Research date: 2 October 2026. Sources: [docs.ponsfamily.com](https://docs.ponsfamily.com/) (v1 and v2), [pepesfamily.fun](https://www.pepesfamily.fun/) and its source ([github.com/0xtenang/PepesFamily](https://github.com/0xtenang/PepesFamily)), the [IMD swarm audit of PepesFamily](https://explorer.imd.fun/jobs/a3e708e2-fb57-43ea-a163-d93b916694a2), [imd.fun/docs](https://imd.fun/docs/), [pool4.imd.fun/docs](https://pool4.imd.fun/docs), and the live IMD API (`api.imd.fun/requests/capabilities`, `/openapi.json`).

---

## 0. Short version

- **Pepes Family** is a near-copy of Pons v1 mechanics, rebuilt on Uniswap v4, with **IMD or ETH** pairs, a **4% hook fee** (1% protocol, 3% to holders as IMD/ETH dividends), and audits done by the IMD swarm. It has no staking, no burn, no creator income, and no swarm-built websites.
- **Pons** is the bigger, ETH-first launchpad on the same chain. v1 is direct-to-pool, v2 uses a bonding curve inside a v4 hook, with snipe tax, creator fees, buybacks, CTO and dead-token migration. It allows only whitelisted pair assets.
- **The gap you can own:** an IMD-only launchpad where the swarm builds each token's **website**, and later its **logo, audit and weekly updates**. Platform fees flow to **$PAD stakers, IMD workers, $PAD burns and treasury**. The launchpad itself is **built and audited by the swarm**, end to end and in public.
- **POOL4 caveat:** POOL4 runs today on **Ethereum mainnet only**, for **ETH/token** pairs, and is **unaudited**. On Robinhood Chain the IMD/ETH pool is a **plain hookless Uniswap v4 pool** (1% fee, tick spacing 100). Tokens can't sit "inside" POOL4 there yet. Section 4 gives three ways to plug into it anyway. The recommended one routes every ETH-side trade through the IMD/ETH pool, so the IMD/ETH pool can be swapped to a POOL4 pool as soon as one exists on Robinhood.
- **Swarm caveat:** swarm jobs are paid in **IMD on Ethereum mainnet** (0.5 IMD per action, x402 + Permit2). The swarm's own `launch.open` deploys only to **Sepolia** today. So the Pad deploys tokens itself on Robinhood and **orders websites with `job.open`**, paying from a backend wallet holding mainnet IMD that is refilled by bridging Robinhood IMD over LayerZero.

---

## 1. Competitor analysis

### 1.1 Pons Family (ponsfamily.com)

| | v1 (live, legacy) | v2 (new; public launches whitelisted, audits pending) |
|---|---|---|
| Launch model | Token goes straight into a **Uniswap v3** pool vs WETH. No curve, no migration. | Token starts on a **constant-product bonding curve** inside a v4 hook. A v4 pool is created at graduation, and its LP is locked forever. |
| Supply | 1,000,000,000 fixed | Fixed; a reserved share becomes pool liquidity at graduation |
| Pair asset | WETH | ETH plus **pons-approved** assets only (no permissionless pairs) |
| Trade fee | 1% pool fee | Base fee (protocol → buyback → creator) + optional capped **creator tax**. The v4 pool's LP fee is 0 and the hook takes the fee. |
| Fee split | Creator 70% / protocol 30% (legacy launches 90/10) | Configurable; buyback share optional |
| Launch fee | 0.0005 ETH | – |
| Protocol revenue | 80% TWAP buyback, 20% team/infra | Buybacks go to a **5-year linear vesting vault**, not burned |
| Anti-snipe | First 2 blocks: max 5% held / 5.5% bought per wallet | **Snipe tax decaying from 99% to 0% over 5 s**, with up to 32 exempt addresses. Tax goes back to the launch. |
| Graduation | 4.2 ETH reached (label only) | Curve sells out → pool created atomically; permissionless `createGraduatedPool()` fallback; 7-day rescue valve |
| Extras | CTO form, onchain metadata, analytics page | CTO with 3+3-day public timelock, **migration of dead non-pons tokens** (epoch deposits, vesting claims, refunds), metadata incl. socials and a pinned economics hash |
| Staking | None | None |
| Websites | None | None |

**Takeaways:** Pons is strong on launch safety (snipe tax, graduation safety, CTO, migration) and creator income. It has no staking, no holder yield, no website builder and no IMD angle. Pair assets need their approval, so IMD may never become a first-class pair there.

### 1.2 Pepes Family (pepesfamily.fun)

Read from the public repo (v3, deployed at block 77,210,723):

| Item | Detail |
|---|---|
| Chain | Robinhood Chain (4663, an Arbitrum Orbit L2), **Uniswap v4** (PoolManager `0x8366a39CC670B4001A1121B8F6A443A643e40951`) |
| Pairs | **ETH or IMD** (`0x5F7Bb59365ce557C26dbcAa4EE9d39A4b95B7127`, LayerZero OFT) |
| Launch | `PadToken`, 1B fixed supply, **100% single-sided** into a v4 position from the start price to the end of the curve. The start market cap is about 1.5 ETH or about 635 IMD (≈ $4k). No curve and no graduation. |
| Liquidity | Owned by the launchpad/hook contract, which has no remove function, so it is locked forever. The hook blocks outside pools and liquidity adds. |
| Fee | **4% of the quote side of every swap**, through any router (LP fee 0; hook flags `beforeSwap`/`afterSwap` + return-delta). **1% protocol, 3% to holders** pro rata, in IMD/ETH, claimable via `claim()` (O(1) dividend accounting). |
| Routers | `Router` (buy/sell/launch with initial buy, permit sells) and `EthRouter` (ETH ⇄ IMD ⇄ token in one tx through the **hookless IMD/ETH v4 pool**, pool id `0xd2fc01ee…8f02`) |
| Admin | Owner can change only the fee recipient and future start tick. Tokens have `owner() = 0`; contracts are not upgradeable. |
| Frontend | A single static HTML file, ethers v6 with SRI, onchain USD pricing (ETH/USDG + IMD/ETH pools), and a GitHub Action that auto-verifies every token on Sourcify/Blockscout |
| Audits | Two IMD swarm jobs (4 auditors + judge): launchpad 1 med / 3 low / 3 info; Pepes token 1 high (flash-borrowed tokens capture dividends, fixed in v3). **The medium is still open:** partial fills through third-party routers with tight price limits pay 4% of the requested amount. |
| Gaps | No creator income (so little incentive for creators to promote), no staking, no buyback or burn, no launch protection beyond an optional atomic dev buy, no website builder, no CTO, no platform token. The 4% fee is high for traders. The protocol fee goes to a single EOA. |

**Takeaways:** Pepes proved the **IMD-paired v4 hook** pattern on Robinhood and the "audited by the swarm" story. It did not use the swarm to *build* anything, and it has no flywheel for a platform token.

### 1.3 Other IMD-side players to watch

- **imd.fun "Launch" (swarm `launch.open`)**: the swarm writes the token, contracts and site. Supply split: 10% to the swarm (2% workers, 8% seats), the rest to the requester and pool. Trading fee 1.25% (1% requester, 0.25% network). Today it runs on **Sepolia only** and is ETH-paired. Once it reaches mainnet chains it is the closest substitute, so position the Pad as **complementary**: instant, IMD-paired, Robinhood-native launches, with swarm add-ons on top.
- **"Community Coins"**, mentioned on imd.fun/token as IMD-priced launches where "every sell burns supply". It isn't documented in the API docs. **Ask the IMD team** whether this is a planned official launchpad before committing. If it is, consider proposing the Pad *as* that product.

---

## 2. Positioning

> "Launch an IMD-paired coin on Robinhood Chain in one transaction. The IMD swarm builds its website. Every trade pays $PAD stakers, IMD workers, and burns $PAD."

Differentiators vs Pepes/Pons:

1. **Swarm-built website per token**, hosted on IPFS at `<label>.site.identitymd.eth`, with source in a public GitHub repo.
2. **Real yield for $PAD stakers**, paid in IMD.
3. **Direct income for IMD workers**, and IMD buy pressure, from every trade on the Pad.
4. **Creator income** (Pepes has none), plus CTO for abandoned coins.
5. **Pons-grade launch protection** (snipe tax) on an IMD pair.
6. **Built and audited by the swarm in public**, with every job link shown in the UI.

---

## 3. Core protocol spec

### 3.1 Launch model (recommended: single-sided v4 range, like Pepes)

Recommended: **all supply goes single-sided into a hook-owned Uniswap v4 position from day one.** This behaves like a bonding curve but needs no graduation or migration code, which is the riskiest part of Pons v2. The pattern is already live and swarm-audited on this exact chain.

| Parameter | Proposed value | Notes |
|---|---|---|
| Supply | 1,000,000,000 fixed, 18 decimals, no mint, no owner | Same as both competitors |
| Pair | **IMD only** (Robinhood IMD `0x5F7B…7127`) | ETH UX via an ETH router (section 4) |
| Start market cap | ~**600–700 IMD** (≈ $4k), owner-tunable for *future* launches only | Set by start tick; check against the v4 per-tick liquidity cap (Pepes audit low finding: very low ticks brick launches) |
| Pool | v4, LP fee 0, tick spacing 200, hook = the Pad | Hook rejects outside `initialize`/`addLiquidity` |
| Liquidity | Owned by the Pad, no remove function | Locked forever |
| Initial dev buy | Optional, atomic in the launch tx | Stops launch-block snipes of the creator |
| Launch fee | Default **1 IMD** (tunable), sent to the fee splitter | Discourages spam |
| Milestones (instead of graduation) | Badges at e.g. 5k / 25k / 100k IMD market cap | Can trigger the swarm add-ons in section 5 |

Alternative: a **Pons-v2-style curve that graduates into a v4 pool**. Choose it only if you want a "graduation" moment for marketing. It adds migration code, a rescue valve, and audit surface.

### 3.2 Launch protection

- **Snipe tax:** extra fee on **buys only**, decaying from **50% to 0% over the first ~10 blocks** (Robinhood blocks are sub-second, so use blocks or timestamps). Tax revenue goes to the token's creator fee balance or the fee splitter, never to the sniper. Creator and their initial buy are exempt.
- **Max-wallet in the first N blocks**, as in Pons v1 (e.g. 2% of supply), enforced in `beforeSwap` on buys.
- Launch and initial buy in **one transaction** via the router.

### 3.3 Trade fee

Taken by the hook on the **IMD side of every swap, through any router**, as Pepes does. Fix Pepes' open medium finding: charge on the **actual** filled amount, computing it in `afterSwap` for exact-in buys and exact-out sells, so partial fills are never overcharged.

**Recommended total: 2%** (half of Pepes' 4%, double Pons v1's 1%):

| Slice | % of trade | Paid in | Destination |
|---|---|---|---|
| Creator | **0.8%** | IMD | Creator fee balance, `claim()` anytime; recipient changeable, CTO-able |
| Protocol | **1.2%** | IMD | `FeeSplitter` (section 3.4) |

Options to offer instead:

| Variant | Total | Creator | Protocol | Holders | Good for |
|---|---|---|---|---|---|
| A. Lean | 1.5% | 0.5% | 1.0% | – | Volume, undercutting Pepes |
| **B. Recommended** | **2%** | **0.8%** | **1.2%** | – | Balance |
| C. Holder yield | 3% | 0.5% | 1.0% | 1.5% dividend in IMD | Matching Pepes' "paid to holders" story, with v3 flash-capture fix |
| D. Creator-chosen | 1.5% base + creator tax 0–3% (capped, fixed at launch) | | | | Pons v2 style; more complexity |

### 3.4 Protocol fee split (what you asked for)

All protocol IMD goes to a `FeeSplitter`. Anyone can call `distribute()`, and the shares are constants or timelocked:

| Bucket | Share | Mechanism |
|---|---|---|
| **$PAD stakers** | **40%** | Streamed into the `sPAD` staking vault in IMD, through a dripper (section 3.5) |
| **IMD workers** | **25%** | `WorkerFund`, paid out as described in section 3.6 |
| **Buy & burn $PAD** | **20%** | `BuybackBurner` swaps IMD → $PAD in the $PAD/IMD pool in small TWAP chunks with a price guard, then calls `burn()` (real supply reduction, not a dead-address send) |
| **Treasury** | **15%** | Multisig (Safe) |

The launch fee and website add-on fees also go to the splitter. Website fees go to the WorkerFund first, because they pay swarm jobs.

Changing shares: limit each bucket to a range (e.g. stakers 25–60%), allow changes only through a **7-day timelock**, and emit events. Never allow a change that sends 100% to treasury.

### 3.5 $PAD token and staking

**$PAD** is the platform token. Recommended: launch it **on the Pad itself**, paired with IMD, as launch #1. This dogfoods the product, gives it the same locked liquidity as every user coin, and $PAD's own trades also feed the splitter.

- No presale. Optional team allocation (≤ 5–10%) in a public vesting contract, bought with the dev buy at launch rather than minted. Keep the cap table simple.
- **`sPAD` vault:** stake $PAD and earn **IMD**.
  - Reward accounting is standard `rewardPerToken` (Synthetix style), funded by a **`RewardDripper`** that releases incoming IMD linearly (e.g. over 7 days), as POOL4's dripper does. A big fee spike then can't be sniped by staking right before `distribute()`.
  - **Anti flash-stake:** rewards accrue only to stake that is at least 1 block old. Disallow stake and unstake in the same block. No unstake lock, or an optional 3–7-day cooldown for a boosted tier.
  - Optional: **auto-compound vault** (IMD rewards are swapped to $PAD and restaked; ERC-4626 like sIMD).
  - Optional: a **veToken-style boost** (lock 1–12 months for up to 2.5× weight).
- Optional **holder perks**: stakers get discounted launch and website fees, early access to the swarm add-ons, and governance over the splitter ranges.

### 3.6 The IMD workers bucket: how money reaches workers

IMD workers are identified on **Ethereum mainnet** (ERC-8004 seat NFTs) and are paid by the swarm per accepted job. On Robinhood you can't pay them directly without a mapping. Three options, best first:

1. **Fund swarm work (recommended default).** The WorkerFund pays for the swarm jobs the Pad orders: token websites, audits and updates (section 5). Every job pays the network, which pays the workers who did the work. This is the most honest form of "fees go to workers", and it also subsidises the website feature. Mechanics: the WorkerFund on Robinhood periodically **bridges IMD to Ethereum** with the IMD OFT `send()` (LayerZero). It lands in an ops wallet that pays x402 job quotes (0.5 IMD per action).
2. **Direct worker rewards (ask the IMD team).** Send surplus to the official node/worker reward channel. POOL4 already tracks an NFT-node reserve (`heldNft`) "pending the payout contract". Ask the team for an intake address or contract so the Pad tops up the same pool that pays inference nodes. This gives the strongest alignment with the IMD ecosystem.
3. **Your own Merkle airdrop to seat holders**, weighted by accepted work from `GET /seats/records` or `GET /contributors`, paid on Ethereum via a Merkle distributor. It's flexible, but you own the data integrity and the gas.

Suggested policy: the WorkerFund keeps a runway of N months of expected job spend; anything above that goes to option 2, or option 3 until option 2 exists.

### 3.7 Creator features

- Creator fee balance in IMD, `claim()` anytime, changeable recipient.
- **CTO (community takeover)**, as in Pons v2: the protocol proposes a new fee recipient for an abandoned coin with a **3-day public notice and a 3-day execution window**. It is visible onchain, and a creator moving fees mid-notice does not cancel it.
- Onchain metadata: name, symbol, logo (`ipfs://` or `https://` only), description, socials, and **website URL, filled in automatically when the swarm site goes live** (one-time `setWebsite` by creator or protocol, or an offchain registry to keep the token immutable).

### 3.8 Contracts

| Contract | Role |
|---|---|
| `Pad` (launcher + v4 hook + LP owner) | Deploys tokens, owns locked positions, charges fees, snipe tax, max-wallet window. Address mined for hook flags (`beforeInitialize`, `beforeAddLiquidity`, `beforeSwap`, `afterSwap`, plus return-delta flags). |
| `PadToken` | Fixed-supply ERC-20 with EIP-2612 `permit`, no owner, no exemptions. Add dividend logic only for fee variant C. |
| `PadRouter` | Launch with initial buy, buy, sell (with permit), exact amounts, deadlines |
| `PadEthRouter` | ETH ⇄ IMD ⇄ token in one tx through the IMD/ETH pool. The IMD/ETH pool key is **settable behind a timelock** so it can be moved to POOL4 later (section 4). |
| `FeeSplitter` | Protocol IMD → four buckets, permissionless `distribute()` |
| `StakedPAD` + `RewardDripper` | Staking vault and linear IMD streaming |
| `BuybackBurner` | Permissionless, rate-limited TWAP buy of $PAD and burn; keeper tip capped (POOL4 uses ≤ 0.002 ETH / ≤ 1%) |
| `WorkerFund` | Holds worker IMD; `bridge()` to an allowlisted Ethereum address via the IMD OFT; spend caps per epoch |
| `CreatorFees` / CTO module | Creator balances, recipient changes, timelocked takeovers |
| `Timelock` + Safe multisig | All admin powers |

Admin powers allowed: start tick for future launches, splitter shares within ranges, IMD/ETH pool key for the ETH router, CTO execution, pausing **new launches** only. **Not allowed:** touching liquidity, changing fees of existing tokens, pausing trading, upgrades.

Build settings, as Pepes: Solidity 0.8.26, `via_ir`, EVM `cancun` (transient storage), Foundry, v4-core pinned, verified on Sourcify and Blockscout.

Lessons to carry over from the Pepes audit:
- Charge fees on the **filled** amount (their open medium).
- Never distribute rewards while the PoolManager is unlocked by an outside caller (their high; matters for staking and any dividend variant).
- Guard against **zero-cost price displacement** in empty pools (their low): e.g. reject sells that fill 0, or ignore market cap until the first buy.
- Bound `setStartTick` to valid liquidity ranges (their low).
- Make `permit` accept `value >= amount` (their low).
- Emit the real trader (`msg.sender` of the router call, passed as hookData), not `tx.origin` (their info).

---

## 4. Using POOL4

**What POOL4 is today:** a Uniswap v4 hook (`CappedBurnHook`) on **Ethereum mainnet** that is the exclusive LP of a full-range **ETH/IMD** pool with a 1% fee. It trims excess IMD after sells (85% burned on Base, 15% to stakers, bonding and NFT nodes), keeps an ETH buy wall, and streams rewards to sIMD. Its permissionless launcher takes **"an ERC-20 and some ETH"**, so its pairs are **ETH/token**. It is **unaudited**, and the owner can re-seed or close a market.

**On Robinhood Chain today**, the IMD/ETH pool that Pepes routes through is a plain v4 pool with no hook (`fee 10000, tickSpacing 100, hooks 0x0`).

So "tokens using POOL4" can mean three things:

| Option | What it means | Feasible now? |
|---|---|---|
| **1. IMD leg via POOL4 (recommended)** | Every ETH-paying user buys IMD as part of the trade. Route that leg through POOL4's hooked IMD/ETH pool so each Pad trade feeds POOL4's burn and rewards. | On Robinhood: **only once POOL4 is deployed there.** Until then route through the existing hookless pool, and keep the pool key switchable behind a timelock. **Ask the IMD team** about a Robinhood POOL4 deployment; the token page says all IMD liquidity is moving to v4/POOL4. |
| **2. Deploy a POOL4 market on Robinhood yourself** | Use the POOL4 launcher design to deploy a CappedBurnHook IMD/ETH market on Robinhood, with IMD team approval and the hook source. | Needs the POOL4 source and the team's blessing. It is also unaudited, and running it adds owner powers to your trust surface. |
| **3. POOL4-style mechanics inside the Pad hook** | Add an optional "capped burn + buy wall" mode per token: after sells, the hook trims part of the token side and burns it, building an IMD buy wall. | Possible as **v2 of the Pad**. It needs a fresh swarm audit; do not ship it at launch. |

Recommendation: ship v1 with **option 1 wiring** (switchable IMD/ETH pool key), pitch the IMD team on a Robinhood POOL4 market, and keep option 3 as a roadmap item.

---

## 5. Swarm features ("the swarm builds your coin")

### 5.1 How it works technically

- API: `https://api.imd.fun`, flow `POST /requests/quote` → `POST /requests/{id}/submit` (402 challenge) → sign **Permit2 + EIP-712 QuoteApproval** → resubmit → poll `GET /requests/{id}` → read `GET /jobs/:id/result` and `GET /sites/:id`.
- Price: **0.5 IMD per action**, paid on **Ethereum mainnet** (`eip155:1`) via x402 "exact". A payment buys **admission, not a guaranteed result**, and unused runs are not refunded.
- Site hosting: `job.open` with skill `build-website` and `"ipfs": "<label>"` publishes to IPFS under **`<label>.site.identitymd.eth`**. Code goes to GitHub under `identity-md-launches` (`"github": true`).
- Swarm `launch.open` / `workflow.open` (token + contracts + site) deploy only to **Sepolia** today, so on Robinhood the Pad deploys the token and the swarm only builds around it.

### 5.2 Feature: "Build my website" (MVP)

1. At launch, or later from the token page, the creator ticks **Build my website** and pays a **website fee in IMD on Robinhood** (default **5 IMD**: 0.5 IMD per job, a buffer for a `job.continue` revision, bridging gas, with the remainder going to the WorkerFund).
2. The Pad backend (the "Swarm Relay") builds the `objective` **from structured fields only**: name, symbol, contract, pair, logo, description, socials, chosen theme or template, and short creator notes with a length limit and filtering. This prevents prompt injection and stops people ordering phishing sites under the Pad's name.
3. The relay pays the quote from its **mainnet ops wallet**, funded by the WorkerFund bridge. It tracks status and posts the job link on the token page live.
4. When the site is published, the token page shows **Website: `<symbol>.site.identitymd.eth`** (plus an eth.limo gateway link), the GitHub repo and the explorer job link.
5. Safety: the relay **checks the output** before linking it, with an automated scan for wallet-drainer patterns or any `eth_sendTransaction` to unknown contracts. The Pad links only to sites that pass; others are flagged.
6. Refunds: if the job fails, retry once (`job.continue`), then refund in IMD on Robinhood from the WorkerFund.

Template idea: give the swarm a **fixed website starter** (a repo imported via `POST /requests/import`) with a token stats widget, buy button wired to `PadRouter`/`PadEthRouter`, chart, socials and a "Built by the IMD swarm" badge. The swarm then only customises it. That makes the output consistent, cheaper, and safer.

### 5.3 More swarm add-ons (pick per phase)

| Add-on | Swarm action | Trigger | Value |
|---|---|---|---|
| Logo / banner / meme pack | Image job | At launch, paid | Creators without design skills |
| Token page audit badge | Code audit of the exact `PadToken` bytecode (one job covers all tokens, since they're identical) | Once per Pad version | "Audited by the IMD swarm" on every coin |
| Custom-feature coins | Contracts job (e.g. vesting, airdrop contract, game) | Paid premium | Upsell |
| Weekly update / site refresh | `schedule.create` heartbeat | Creator subscribes (N runs prepaid) | Living sites, recurring worker income |
| Milestone unlock | Free site upgrade or promo video at 25k / 100k IMD market cap, paid by the WorkerFund | Onchain milestone | Gamifies growth |
| Copycat / scam check | `oracle.request` (panel 5–100) on "Is this token impersonating X?" | Flag button or on new launches | Moderation without a central team |
| Launch recap / research | Research job | Daily/weekly | Content for the Pad's socials |

### 5.4 Building the Pad itself with the swarm (your story vs Pepes)

Pepes only *audited* with the swarm. To claim "built by the swarm":

1. **Spec → contracts:** `job.open` with a contract skill, giving it this plan's section 3 as the objective, GitHub publication on. Premium contract and frontend work is done by top-tier workers.
2. **Testnet run:** `workflow.open` on **Sepolia** with the `univ4_hook` kind gives contracts, an **adversarial review**, deployment and a site in one pipeline. This is a public testnet.
3. **Independent audit:** a separate `job.open` audit (4 auditors + judge) on the exact commit you will deploy (import via `POST /requests/import`). Repeat it after fixes. Add fuzz campaigns (1k to 10M runs) on the fee math and the staking vault.
4. **Frontend:** a swarm `build-website` job for the Pad's own app, pinned to IPFS (`pad.site.identitymd.eth`), plus your own domain.
5. Publish every job link on the site, as Pepes does with its audits.
6. Get at least one **human audit** before large TVL; the swarm reports say so too.

---

## 6. Frontend and backend

**Frontend** (static, IPFS + your own domain): explore (new, trending, milestones, "has swarm website"), token page (chart from onchain `Trade` events, buy/sell in IMD or ETH, holders, creator fees, website card, audit badge, CTO status), create (form + initial buy + website add-on), staking (stake/unstake, APR from the dripper rate), burn dashboard (total burned, buyback history), WorkerFund dashboard (jobs paid, IMD bridged, sites built), and admin/keeper pages. Copy the good parts from Pepes: SRI-pinned ethers, CSP, HTML-escaping of metadata, `https`/`ipfs` only, exact-amount IMD approvals, onchain USD pricing (ETH/USDG and IMD/ETH pools).

**Backend** (small): an indexer (Blockscout API or your own subgraph-like service), the Swarm Relay (quotes, payments, status, safety scan), keepers (`FeeSplitter.distribute`, `BuybackBurner`, `WorkerFund.bridge`), a token auto-verifier (GitHub Action, as Pepes does), and a Telegram/X bot for new launches and milestones.

**Integrations:** DexScreener and GMGN listings for Robinhood, wallets (add-chain helper; RPC `https://rpc.mainnet.chain.robinhood.com`, explorer `robinhoodchain.blockscout.com`), and a paid RPC for production reads.

---

## 7. Fee flow

```
Trade on any Pad coin (2% of IMD side, via any router)
├── 0.8% → Creator balance (claim / CTO)
└── 1.2% → FeeSplitter ── + launch fees
            ├── 40% → RewardDripper → sPAD stakers (IMD)
            ├── 25% → WorkerFund ── + website fees
            │          ├── bridge IMD → Ethereum → pay swarm jobs (sites, audits, updates)
            │          └── surplus → IMD node/worker rewards (official intake) or Merkle to seats
            ├── 20% → BuybackBurner → buy $PAD (TWAP) → burn()
            └── 15% → Treasury (Safe multisig)

ETH users:  ETH ⇄ [IMD/ETH pool: hookless today → POOL4 market when live] ⇄ IMD ⇄ [Pad hook] ⇄ coin
```

---

## 8. Roadmap

| Phase | Scope | Exit criteria |
|---|---|---|
| **0. Alignment (1–2 wks)** | Talk to the IMD team: POOL4 on Robinhood, official worker-reward intake, Community Coins plans, possible "official IMD launchpad" status, Robinhood IMD liquidity. Pick name and fee variant. | Written answers; final parameters |
| **1. Build (3–5 wks)** | Contracts via the swarm and in-house, Foundry tests (unit, fuzz, fork against live Robinhood PoolManager and IMD), Sepolia workflow run | 100% of fee/staking paths tested; testnet live |
| **2. Audit (2–4 wks)** | IMD swarm audit (repeat until clean), fuzz campaigns, a human audit if budget allows, public bug bounty | No open high/medium findings |
| **3. Mainnet beta** | Deploy on Robinhood; launch $PAD as coin #1; whitelisted creators; "Build my website" on with manual review | Live fees flowing; first swarm sites live |
| **4. Public** | Permissionless launches, staking, buyback-burn keeper, WorkerFund bridge, CTO, bots | Stable keepers; dashboards |
| **5. Expansion** | Logo/meme add-ons, heartbeat updates, milestones, oracle moderation, POOL4 routing switch, optional POOL4-style per-token burn mode, dead-token migration (Pons v2 style), referral fees | Per-feature audits |

---

## 9. Risks and open questions

- **Unaudited dependencies:** POOL4 is unaudited. IMD is a LayerZero OFT whose owner controls bridge config. Your contracts inherit both risks.
- **Swarm payments are cross-chain and non-refundable:** price the website fee with a buffer and keep a mainnet IMD float. Bridge fees and LayerZero delays are operational costs.
- **Quality and safety of swarm sites:** template-driven objectives, an output scan, and no free-text prompts.
- **Staking reward capture:** the dripper plus 1-block stake age; never distribute during an outside PoolManager unlock.
- **Dividend/fee sniping, MEV, launch snipes:** snipe tax, max-wallet window, atomic dev buy.
- **Competition:** Pepes can copy features quickly, and the swarm's own `launch.open` may reach mainnet chains. Your moat is the swarm integration depth, the fee flywheel to IMD workers, and alignment with the IMD team.
- **Regulatory:** a token whose stakers receive protocol revenue can look like a security in some jurisdictions. Get legal advice before marketing yield. Robinhood Chain is a public L2, but check any terms for apps using its brand. Don't imply Robinhood endorsement.
- **Open questions for the IMD team:** (1) a POOL4 deployment on Robinhood, and its pool key? (2) an official address or contract for worker/node rewards? (3) will `launch.open` support Robinhood, and could the Pad be the launch backend? (4) bulk or discounted pricing, or a sponsored relay, for site jobs? (5) is "Community Coins" a separate product?
