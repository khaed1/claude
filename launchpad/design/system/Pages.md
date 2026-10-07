# Pages

The sitemap and the layout of every v1 page. Build pages from the components in this system; copy comes from `launchpad/SITE-COPY.md`; the reasoning is in `launchpad/design/UX-RESEARCH.md`.

## Sitemap

| Path | Page | In the nav |
|---|---|---|
| `/` | **Explore** (home) | Top bar, tab bar |
| `/c/<coin>` | **Coin page** | from cards, search, ripples |
| `/spawn` | **Spawn** (create a coin) | Spawn button (top bar, tab bar) |
| `/pondpad` | **$PONDPAD**: the sale before the Leap, the market after it, and the airdrop | Top bar, tab bar |
| `/pond` | **The Pond** (stake) | Top bar, tab bar |
| `/u/<address>` (`/me` for the connected wallet) | **Profile**: holdings, created coins with creator-fee claims, rewards, activity | Wallet menu, tab bar |
| `/transparency` | **Transparency**: where every IMD goes | Wallet menu, footer |
| `/docs/…` | **Docs** | Top bar, footer |

Footer on every page: Contracts · Audits · Docs · Risks · Transparency · X · the risk line "Coins here are made by anyone. Do your own research. Ribbit responsibly."

Global: the ripple feed under the top bar (desktop; Explore only on phones); wrong-network notice; theme toggle in the wallet menu; search with ⌘K (coins by name or ticker, creators by address).

## Explore `/`

```
[top bar]
[ripples ─────────────────────────────────────────────]
Every frog starts as a tadpole.                  (hero, one line + one sentence, no image block)
Spawn a coin on Robinhood Chain, paired with IMD.   [Spawn a coin]  [How it works →docs]

About to Leap                                     (spotlight row: ≥ 75% of target, gold cards, scrolls sideways)
[card][card][card][card] →

[tabs: New · About to Leap · Frogs · Trending]   [filters: X verified · Has website · Max tax ▾]  [sort ▾]
[card][card][card]
[card][card][card]       (3 / 2 / 1 columns; infinite list, 24 at a time)
```
- **New:** newest first, Eggs and Tadpoles.
- **About to Leap:** by % to the Leap.
- **Frogs:** graduated, by market cap.
- **Trending:** by 1h volume.
- Sort options on every tab: recent buys, newest, market cap, volume, % to the Leap; time window All / 24h / 7d.
- Empty: "Quiet pond today. Be the first to spawn something." with Pip.

## Coin page `/c/<coin>`

```
[img] Ribbit Republic $RIBBIT  [Tadpole · 63%]  [X verified] [Site by the Chorus]   [share] [copy address]
MC 10,440 IMD ($65.8k) · ▲ 18.2% 24h · Fee 2.0% · created by 0x4b91…6821 · 12 min ago

┌ left (2/3) ─────────────────────────────┐ ┌ right (1/3, sticky) ───────┐
│ [Chorus notice, if any]                 │ │ [early-bird tax notice]     │
│ Leap meter (tadpoles) / "Leapt 3d ago"  │ │ TRADE BOX                    │
│ chart (price in IMD; 5m 1h 4h 1d)       │ │ Buy|Sell · IMD|ETH|USDG      │
│ [tabs] Trades · Holders · Creator ·     │ │ amount · presets · quote     │
│        Chorus · About                   │ │ fee line · [Buy $RIBBIT]     │
│  Trades: live list (wallet, side,       │ ├─────────────────────────────┤
│   amount, paid with, time, tx)          │ │ Your position: balance,      │
│  Holders: top 20 with %, labels for     │ │ value, dividends to collect  │
│   curve / pool / creator / burn         │ │ [Collect your IMD]           │
│  Creator: fee recipient, creator fees   │ ├─────────────────────────────┤
│   earned, tax split, swarm budget       │ │ Website card                 │
│  Chorus: website job, swarm budget jobs │ │ Coin facts: supply, curve,   │
│  About: description, links, contract    │ │ tax, contract, pool          │
└─────────────────────────────────────────┘ └─────────────────────────────┘
```
- Phone: header, Leap meter, chart, tabs; a fixed **Buy / Sell bar** at the bottom opens the trade box as a sheet.
- **No comment thread in v1** (spam and moderation cost); the coin's verified X account is linked instead. *Proposal: confirm.*
- **Gas:** after the Leap, trades in a coin's pool send with normal headroom; trades on the **$PONDPAD market** and keeper-type calls add **50%** to the gas estimate (D-64).

## Spawn `/spawn`

One page in four short steps (not a multi-page wizard), with a live preview card on the right:

1. **Name it:** name, ticker, image (square, ≤ 2 MB), description, socials (optional).
2. **Coin tax (optional):** 0–3%, split between you / holders / swarm budget; default 0.5% to holders. "You can't change this after launch."
3. **Buy first? (optional):** dev buy, pay with IMD / ETH / USDG.
4. **Website now? (optional):** 5 IMD website add-on.

Summary box: launch fee (0.35 IMD), dev buy, website add-on, total, paid with, fee per trade for this coin ("Traders will pay 2.0%"). Button: **Spawn it** → "Laying your egg…" → toast "It's alive. Your tadpole is swimming." → the coin page.

## $PONDPAD `/pondpad`

The same address all the time; the page changes with the phase:

- **Before the sale opens:** countdown to `SALE_START`, how the sale works (curve, ~8,460 IMD target, 60/30/5/3/2 split), "Am I on the airdrop list?" checker.
- **Sale live:** Leap meter (sale target), the trade box (Buy / Sell, IMD / ETH / USDG, gold button), the **live early-bird tax** (80% → 0 over 30 minutes, countdown), **your allowance left** (15M per wallet, "sells don't free it"), buyers so far.
- **After the Leap:** the market's trade box (fee today, e.g. "2.4%, falling to 1% by day 7"), burn stats ("Burned so far"), cap and backstop explained in one paragraph each, with "burns start when sells push the pool above its cap" (testnet finding). Gas +50%.
- **Airdrop, after the Leap:** "Wake the pond": your code, the post to copy, tweet link field, sign, live count "{n} / 100 frogs awake"; then the claim (vested so far, claim, claim wallet by signature, share).

## The Pond `/pond`

- Stats: your sPONDPAD (≈ $PONDPAD value), value per share now, dripping in now (per day), total staked, burned so far.
- Stake / Leave the pond (amount input, one lily button).
- **After a stake, show a short wait before the withdrawal button works** (the vault blocks a withdrawal in the same Ethereum block, D-65): "Ready in a few seconds", then the button enables.
- Small print: "Rewards depend on how much trading happens. We don't promise a number."

## Profile `/me`, `/u/<address>`

```
[avatar from address] 0x4b91…6821  [X @handle linked]  [copy] [explorer]
Holdings value 3,240 IMD · Creator fees to claim 42.8 IMD · Dividends to collect 6.1 IMD · sPONDPAD 12,400

[tabs: Holdings · Created · Rewards · Activity]
```
- **Holdings:** every PondPad coin held (coin card row: balance, value in IMD, 24h change, dividends to collect per coin, Buy / Sell). Plus $PONDPAD and sPONDPAD.
- **Created** (only if the wallet launched coins or is a fee recipient):
  - a **claim section** at the top: "Creator fees to claim: 42.8 IMD across 3 coins", with **[Claim all]** (one transaction per coin through `CreatorVault.claim`, batched where the wallet supports it)
  - then one row per coin: fees earned, claimable now, tax split, swarm budget balance and its jobs, [Claim] [Change recipient] [Link X] [Request a swarm job]
  - coins whose fees now go to holders (the recipient routed them there, final) show "Fees go to holders" instead of Claim
- **Rewards:** dividends to collect per coin ([Collect all]), integrator earnings if the wallet is a registered integrator (`IntegratorVault`, [Claim]), airdrop vesting and claim.
- **Activity:** trades, spawns, claims, stakes, with tx links.
- Someone else's profile (`/u/<address>`) is read-only: the same tabs without the claim buttons.

## Transparency `/transparency`

Read from the chain: protocol fees in, the 40/25/20/15 split (and integrator share), PadBuyer purchases, WorkerFund releases, GrowthFund payments with job links and reasons, treasury balance, $PONDPAD burned, current settings, **settings changes waiting in the timelocks** (with when they can execute). "Nobody can change the rules overnight. Every change waits here first, in public."

## Docs `/docs`

Inside the site, same nav and style, a left sidebar (a drawer on phones), "On this page" on wide screens, search, and an "Edit on GitHub" link. Written for people first, then developers.

- **Start here:** What is PondPad · Your first trade · Spawn a coin · Glossary (Spawn, Egg, Tadpole, Leap, Frog, Pond, Chorus)
- **How it works:** Bonding curve and the Leap · Fees and where they go · Coin tax · Paying with IMD, ETH or USDG · Early-bird tax and max-buy · Dividends · Creator fees · Swarm budget and websites · X badge
- **$PONDPAD:** The sale · The market (fee schedule, cap, burns, backstop) · Staking (the Pond) · Airdrop (who is on the list, waking the pond, vesting) · Team vesting and supply
- **Safety:** Risks · Admin powers and timelocks (what we can and can never do) · Audits (swarm rounds, `FINDINGS.md`) · Contracts and addresses · Bug reports
- **Developers:** Contracts and ABIs · Reading state with PadLens · Events · Trading through PadRouter · Integrator programme (15% of the protocol fee) · Keepers (permissionless upkeep) · Gas notes (+50% on market swaps)

Every number in Docs that the chain knows (fees, targets, splits, addresses) is read live or generated from the deployment file, never typed by hand.
