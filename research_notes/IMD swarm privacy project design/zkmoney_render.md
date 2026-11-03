# What launch.zk.money actually is (headless-browser render, 2026-11-03)

## Bottom line

**`https://launch.zk.money/` is just a redirect into the live, relaunched zk.money wallet.** It 302s (CloudFront function) to `https://wallet.zk.money/`, and the single-page app then client-side-routes to **final URL `https://wallet.zk.money/claim`**, which renders the wallet's logged-out landing page ("Money that moves privately"). There is no token claim, airdrop, or "launch event" page. The `/claim` route name is an app-internal route (the app loads a `claim_fpc` JS chunk and its config has a `claimFpc` contract that gates "name claims", i.e. @tag registration), but the visible content is the ordinary wallet landing with "Create Account" / "Log in".

The product behind it is the **new zk.money (v6 / "prod-v6" profile) built by Obsidion Labs on Aztec mainnet (chain 1, Aztec Tierra / Alpha v6, rollupVersion 2070860440)**, a self-custodial private-payments wallet (DAI, with a Sky sUSDS "Savings" account), with an "Oxide" AWS-Nitro-enclave co-signing layer, sponsored fees via a fee-paying contract (FPC), passkey login, @tag handles, and paylinks. It is explicitly *not* the 2021-2023 zk.money on Aztec Connect; the docs say "the original zk.money was a private DeFi app on Aztec Connect, which stopped accepting deposits in 2023" and shut down in March 2024, with no carry-over of accounts or funds.

`https://zk.money/` itself is a stub whose only content is "Please follow this link if you are not redirected automatically" pointing at `https://launch.zk.money` (so the chain is zk.money -> launch.zk.money -> wallet.zk.money -> /claim).

## Method

Rendered with the pre-installed Playwright 1.63.0 (`chromium.launch()`, 1280x900, deviceScaleFactor 1, waited for `networkidle` + 6 s). Scripts and raw dumps are in `/tmp/claude-0/-home-user-claude/d80905a0-7eed-5ac6-af1c-2d3cf5ee442a/scratchpad/zkmoney/` (`render.js`, `render2.js`, `launch.png`, `launch.txt`, `launch_meta.json`, `launch_log.json`, `launch_full.html`, `step1.txt`/`step1.png` (Log in), `step2.txt`/`step2_create.png` (Create Account), `step3.txt`/`step3_endpoints.png` (Endpoints), `apps.txt`/`apps.png`/`apps_meta.json`, and `bundle/` with the downloaded JS chunks + `current.json` + `releases.json`). No rendering errors occurred; the only console error was one `ERR_BLOCKED_BY_RESPONSE ... COEP` for a third-party resource (the page uses cross-origin isolation for WASM threads).

Observed redirect chain (from `launch_log.json` and `curl -I`):

```
302 https://launch.zk.money/   (server: CloudFront, x-cache: FunctionGeneratedResponse, location: https://wallet.zk.money/)
200 https://wallet.zk.money/
 -> client-side route to https://wallet.zk.money/claim
```

Page `<title>`: `zk.money`. Meta description / og:description: **"Join zk.money to send or receive crypto privately. Open source, self-custodial, built on Ethereum."** og:image:alt: **"zk.money, your money is your business"**. theme-color `#49087e`, color-scheme dark. Only one script tag: `https://wallet.zk.money/assets/index-Cw1j47jH.js` (Vite/rolldown bundle). Console boot line: `[boot] commit 1b2c74009387c588b608318253ba9b7cf5e96a80`, `activeNetwork mainnet`, `Started PXE connected to chain 1 version 2070860440`.

## Exact innerText of the landing page (`launch.txt`, final URL https://wallet.zk.money/claim)

```
ENDPOINTS
GET PAID
Paylinks
A link, a QR code or your @tag. Anyone can pay you without ever seeing an address.
SAVINGS UP TO
3.8% APY
Rewards tick into your balance every day. Move funds back to your spending account any time.
WITHDRAW
Privately
GET PAID
Paylinks
A link, a QR code or your @tag. Anyone can pay you without ever seeing an address.
SAVINGS UP TO
3.8% APY
Rewards tick into your balance every day. Move funds back to your spending account any time.
zk.
money
zk.money
Money that moves privately

Pay, get paid and save onchain. Your balance and transactions are private by default.

Create Account

I already have an account Log in

TERMS AND CONDITIONS
PRIVACY POLICY
```

(The feature cards repeat because it is a looping carousel.) Links on the page: logo -> `https://wallet.zk.money/`, "TERMS AND CONDITIONS" -> `https://docs.zk.money/terms`, "PRIVACY POLICY" -> `https://docs.zk.money/privacy-policy`. Buttons: `ENDPOINTS`, `Previous feature`, `Next feature`, `Create Account`, `Log in`.

Keyword hits in the visible landing text: only "WITHDRAW" (the "Withdraw Privately" card). The words token, claim, launch, deposit, fee, relayer, Aztec, alpha, mainnet, testnet, Ignition, Tierra do **not** appear in the logged-out landing copy. "Aztec", "mainnet", "old network", "fee" and "claim" appear once you open the Endpoints dialog, create an account, or read the JS bundle/config (see below).

## UI description (from launch.png)

Dark purple/black gradient background. Left half: a vertical carousel of three glassy feature cards with a small up/down scroll indicator: (1) "GET PAID / Paylinks" showing a QR code with a sample tag `@honkthg00se.zk.money` and URL `wallet.zk.money/pay/honkthg00se`; (2) "SAVINGS UP TO / 3.8% APY" with a bar chart labelled "Today" to "8 years"; (3) "WITHDRAW / Privately" with two rows of logos labelled "Cards" (Kraken-style K, a second card logo, a green radial logo, a dollar-sign logo) and "Exchanges" (a teal logo, Coinbase, Kraken, Gemini-like logo) plus a chain-icon cluster captioned "21 Available Chains". Right half: zk.money app icon + wordmark, headline "Money that moves privately", sub-copy "Pay, get paid and save onchain. Your balance and transactions are private by default.", a full-width purple-to-blue gradient "Create Account" button, and "I already have an account Log in". Top-right pill button "ENDPOINTS". Footer: "TERMS AND CONDITIONS  PRIVACY POLICY". No wallet-connect prompt and no "connect wallet" gate: the app does not need an Ethereum wallet to show the landing or to create an account.

## Click-through states

### Step 1: "Log in" (URL becomes https://wallet.zk.money/enter)

A modal "Type your @tag" with a "Your tag" input (`@ tag ... .zk.money`), a "Login" button, "Can't find your account? Show passkeys", and "Using your own node? Endpoints". Login is passkey-based (the HTML head contains an inline `lockNativePasskeyApi` script that pins `navigator.credentials.create/get` and `PublicKeyCredential` to native implementations, defending against injected passkey shims such as 1Password).

### Step 2: "Create Account" (URL becomes https://wallet.zk.money/)

Clicking "Create Account" immediately creates a local account (no wallet, no email) and shows the logged-in shell. Exact text:

```
Home / Savings / Deposit / Send / Requests / Withdraw / Activity / Settings / Log out
.zk.money
Hi, you're
@ate-reader
Shuffle tag
Choose your own · $5

Complete these 2 steps to use private payments.

STEP 1 OF 2
Save your account
No password, syncs across your devices.
Add passkey
Used zk.money before?
Verify your old wallet and choose your own tag for free.
Verify
Deposit funds
Activate your account with a $1 deposit.
```

UI (step2_create.png): left sidebar nav (Home, Savings, Deposit, Send, Requests, Withdraw, Activity, Settings, Log out), top "Search @tag ... .zk.money" bar, and a card greeting the auto-generated handle `@ate-reader` with "Shuffle tag" and "Choose your own · $5" chips. Step 1 is "Add passkey"; step 2 "Deposit funds — Activate your account with a $1 deposit." A side card "Used zk.money before? Verify your old wallet and choose your own tag for free." (so old-zk.money users get a free custom tag, but not migrated funds). `/deposit` and `/withdraw` routes render this same onboarding shell when the account is not activated; `/about`, `/faq`, `/terms` on wallet.zk.money are 404 ("ERROR 404 Page not found ... Go to wallet").

### Step 3: "ENDPOINTS" dialog (exact text)

```
Endpoints
Leave a field empty to use the default.
Aztec node URL
How the wallet reads the Aztec Network and sends transactions. Any node serving the same network works.
The node's operator sees your IP address and can tell which transactions your wallet sends and receives, but not what is in them.
Switching starts a fresh sync of your history for this node. Your history on the default node is kept.
Aztec node API key
Only needed if the node above asks for one.
Old network node URL
Only used to upgrade funds from the old network: how the wallet reads the version being retired. Any node serving that network works.
Switching starts a fresh sync of your history on the old network for this node.
Ethereum RPC URL
How the wallet reads Ethereum. Any provider's endpoint works, including one you pay for.
Enclave URL
The Oxide enclave that co-signs your sends and withdrawals. Any registered enclave works.
Save & reload
Cancel
```

Placeholder for Aztec node URL: `Default: mainnet-v6.rpc2.aztec-labs.com`. "Old network" here means the previous Aztec rollup generation (Aztec v5; config key `previousGenerationProfile` -> `.../profiles/v5/0.44.0.json`), not Aztec Connect.

## What the app's runtime config reveals (https://cdn.zk.money/profiles/v6/current.json, https://v6-prod.oxide.zk.money/v6/v6-prod/releases.json)

- `profileId: "prod-v6"`, `network: "mainnet"`, `l1ChainId: 1`, `rollupVersion: "2070860440"`, `current: "0.7.0"`, `publishedAt: 2026-11-03T12:24:29Z` (deployed the same day as the Aztec Tierra release), `previousGenerationProfile: https://dsp2gadnqihit.cloudfront.net/profiles/v5/0.44.0.json`.
- `nodeUrl: https://mainnet-v6.rpc2.aztec-labs.com`, `l1RpcUrl: https://ethereum-rpc.publicnode.com` (browser actually hit an Alchemy mainnet key), `accountServiceUrl: https://account.zk.money`, `paylinkDomain: https://paylink.zk.money`, `zkmoneyApiUrl: https://api.zk.money`.
- Oxide: `manifestUrl` above, `portal 0xCB99C58Fe81Ae6b2cB4835e46F7b703745879042` (Ethereum), `enclaveUrl https://flt-v6.v6-prod.oxide.zk.money/rpc`, `teeRegistry 0x8b705c35...`, `nitroValidator 0x13114c5c...`, a `pcr0` enclave measurement, `deployedAt 2026-10-26`.
- Bridges: `dai` -> L2 token "Oxide DAI" (OXDAI) and `susds` -> "Oxide sUSDS" (OXSUSDS), both with `maxNoteAmount 5166 * 1e18` (~$5,000 cap); each bridge has `fpcFunder`, `proverSubsidy`, `withdrawalSubsidy`, `depositSubsidy`, `frozenNotesRefundVerifier`, `frozenDepositsRefundVerifier`, `unprocessedDepositRefundVerifier` contracts (the three post-freeze refund routes).
- L2 contracts: `paylinkDirect`, `paylinkEmail`, `obsidionAccountAlpha`, `linkLocator`, `adminAccount`, `sponsorFPC` (0x1083fec7...), `oidcKeyRegistry` (+ a `zkJwtVkeyHash`, i.e. zk-JWT/OIDC login support), `claimFpc` (0x15cd6b14...) with a `policyManifest` of rails `registration-broadcast` (gate `nameClaim`), `registered` (gate `registration`), `voucher` (gate `none`), and `passwordFPC`.
- Bundle strings confirm Aztec v6: `aztec_version: "6.0.0"`, `@aztec-foundation/l1-artifacts`, `ClaimFPC::_gate_name_claim`, `ClaimFPC::gift_voucher`, `ClaimFPC::subscribe`, `ClaimFPC::sponsor`, `ClaimFPC::refuel`; errors like `"Gas settings exceed whitelist max_fee"`, `"msg_sender must be none for sponsored calls"`, `"fee payer must be elected during the setup phase"`.
- User-facing strings in the bundle: `"This transaction was not sent. Aztec network fees are too high for transactions to go through. Your funds are safe, and full functionality will be available when network fees stabilize."`; `"Amount must exceed the deposit fee ({fee} {symbol})"`; `"Your upgrade is paused. Open it to continue."` / `"Your upgrade needs another approval..."` (v5->v6 fund migration flow, chunk `upgradeFreeze`); activity labels `Deposit`, `Payment request paid`, `Name registration`, `Upgrade in`, `Savings withdrawal`; paylink claim states `Receiving / Received / Claim failed / Waiting for your paylink claim to finish`; a registration note that a user can sweep their own deposit: "...sends it on from your Ethereum wallet, the same transaction a relayer would send: the funds continue into your private balance and the deposit fee comes back to your wallet as the network tip."

## zk.money docs (https://docs.zk.money/docs and subpages)

- Overview (https://docs.zk.money/docs): Aztec is "a fully private, fully programmable network on top of Ethereum." Deposits from Ethereum are public and cost Ethereum gas; payments inside zk.money do not. Self-custodial, no admin role; losing the passkey loses the wallet. Oxide is "a separate protocol that runs alongside the Aztec Network" adding "an independent security layer against vulnerabilities in Aztec's proving system", built on AWS Nitro Enclaves; anyone can run an enclave or resolver. "Every deposit, payment, and withdrawal will initially be restricted to be below $5,000."
- FAQ (https://docs.zk.money/docs/faq): "zk.money runs on the Aztec Network, a privacy-focused Layer 2 on Ethereum." "Is this the same zk.money as before? No." "The original zk.money was a private DeFi app on Aztec Connect, which stopped accepting deposits in 2023", shut down March 2024, accounts/funds don't carry over. Fees: deposit $0.35, withdrawal $0.20; tag $5 + $0.60 registration; first deposit min $10 ($5 with waiver); in-app transactions free "up to 100 transactions a day". "Initially, the system supports DAI"; USDC/USDT deposits are swapped to DAI. "Withdrawals go back to Ethereum mainnet." "Portals can be frozen by anyone if the Aztec Network migrates to a new rollup instance." Paylink claim windows 1/7/30 days.
- Trust model (https://docs.zk.money/docs/trust): Ethereum contracts "cannot be changed once they are deployed... There is no upgrade function." Oxide enclaves "co-sign every token operation"; any enclave proving approved software on AWS Nitro is accepted. "Fee-paying contract: It pays your network fees. If it runs empty, your transactions stop, and you cannot pay fees from your own balance instead." Relayer "can only delay you." Screening service "can block withdrawal addresses." Contract-address publisher: "nothing signs that list today." Freeze is permanent, stops new deposits; funds exit via pending withdrawal or three refund routes.
- Limits (https://docs.zk.money/docs/limits): "below $5,000" per transaction; v5 withdrawals/refunds "$2,500 per transaction"; deposits share "one limit of $100,000 per day, across all users"; caps fixed in the portal contract, "cannot be raised without a new portal contract."
- Relayer (https://docs.zk.money/docs/run-a-relayer): a relayer "moves a deposit into the network and releases a withdrawal back out to Ethereum, paying the Ethereum gas for both"; modes `l1-operations`, `fpc-funding`, `epoch-proofs`; paid in DAI; screens against OFAC SDN (optionally Predicate); `FPCFunder` collects deposit/withdrawal fees which the relayer swaps into fee juice and bridges to the FPC on Aztec; image `azteclabs/oxide-relayer:1.0.0`.
- Savings (https://docs.zk.money/docs/savings): "Savings is a second account inside your wallet that earns the Sky Savings Rate"; holds sUSDS shares privately on Aztec; move takes ~40 minutes via single-use escrow; "Nobody along the way learns who owns the funds."
- Exit (https://docs.zk.money/docs/exit): four routes: normal withdrawal; send the last Ethereum tx yourself if relayer stops; zk.money Desktop (requires Chrome) pointing at own node/RPC/enclave; register your own enclave with the portal.
- Terms (https://docs.zk.money/terms): operator "Obsidion Labs Limited", BVI law, "Last updated: 13 October 2026"; "non-custodial, permissionless software infrastructure"; "FPC Funding Fee" funds sponsorship of network fees; US$5,000 per transaction, US$100,000 aggregate daily deposits; UK residents and New York State excluded; "You may lose some or all of your funds."
- Desktop download (https://docs.zk.money/): "zk.money Desktop is a version of zk.money that runs locally... served directly from your own device, rather than from the zk.money web domain." "Requires Chrome."

## aztec.network/apps (rendered; https://aztec.network/apps)

Title "Apps on Aztec | Aztec". Headline "EXPLORE THE APPS THAT SET YOU FREE. Pay, trade, play, and take part without broadcasting everything." Counts: EVERYTHING 13, APPS 9, WALLETS 1, BRIDGES 2, BLOCK EXPLORERS 1. Footer banner: **"The network is Alpha software. Check the network status before you move anything of value."** FAQ: "The apps page lists what is running now, including private payments, a private exchange, a wallet, a bridge, a block explorer, and a game. The network is Alpha software..."

Featured: **Nyx** (Alpha, "Aztec Tierra", checked 21.09.2026): "a private Aztec account controlled by your existing Ethereum wallet and a passkey... Funding it from Ethereum and withdrawing back are public on Ethereum, so the entry and exit are visible even when everything between them is not." -> https://www.nyx.money/

Directory (all tagged "AZTEC TIERRA"):
- Aztecscan (Block explorer, Available): "The block explorer for Aztec..."
- Dark Forest Aztec (App, Available): strategy game "with the fog enforced by private state."
- Galactica (App, Available): "Private Inference is a private AI chat and API... Pay privately with cUSDC on Aztec or Zcash and keep prompts encrypted in a secure enclave."
- Nemi (App, Alpha): "A decentralised exchange that keeps the trader private."
- Nulo (Wallet, Available): "free, open source wallet for Aztec... proving happens locally in your browser."
- Nyx (App, Alpha): as above.
- Olla (App, Available): "pooled staking for AZTEC holders who cannot stake natively. There is no 200,000 AZTEC minimum... receive stAztec".
- RavenHouse (App, Available): "privacy-first NFT platform on Aztec".
- RollingChat (App, Available): "Private, onchain message board".
- Shield (Bridge, Alpha): "The bridge between Ethereum and Aztec. Moves assets in and out and converts the fee asset along the way."
- Xochi (Bridge, "Check current availability"): "private intents... Sign a gasless intent, let solvers compete to fill it, and settle without the trade ever touching the mempool".
- **zk.money (App, Available): "Self-custodial wallet for sending and receiving crypto privately"** -> https://aztec.network/projects/zk-money (project page: "What stays private: Private transactions, balances, and activity"; Status Available; Network "Aztec Tierra"; website https://zk.money/, docs https://docs.zk.money/).
- ZKPassport (App, Available): compliance/eligibility proofs on-device.

Nav links of note: https://aztec.network/token, /token/governance, /token/where-to-buy, https://stake.aztec.network/, /roadmap, /network/status, https://docs.aztec.network/.

Network status page (https://aztec.network/network/status): "The current release is Aztec Tierra (v6.0.0), on the Alpha network, Aztec's mainnet." Roadmap (https://aztec.network/roadmap): Ignition Chain Nov 2025; Alpha Network 31 March 2026 ("Transactions switch on"); Alpha V5 21 July 2026 ("a fully private transfer for under $0.05", 6 s blocks); **Aztec Tierra = Alpha V6, 3 November 2026**; Alpha V7 Q1 2027; Beta V1 ~Q2 2027 ("The hardened, production-ready version of the network"). So "Tierra" is the codename of the v6 release of the Alpha network, which Aztec also calls its mainnet.

## Aztec blog posts (WebFetch)

### History of Aztec (https://aztec.network/blog/history-of-aztec-pioneering-privacy-in-web3, published 22 April 2025)
- zk.money launched 2021 as a private payments network; Aztec Connect launched 2022 as a private DeFi rollup; both run by the Aztec team 2021-2023; "at peak, the rollups had over $20 million in TVL."
- Sunset because the team "could not fully decentralize the networks without massive architectural changes": centralized sequencer, all programs on shared state so third-party programs could not compose. Zac and Joe reject "Progressive Decentralization". "In 2023, zk.money and Aztec Connect were officially shut down." The team "decided to build a new network from scratch"; Noir ("a Rust-like programming language for writing zero-knowledge circuits") developed in parallel. The post does not say what happened to user funds (the zk.money FAQ says the old app stopped deposits in 2023 and shut down March 2024).

### How gas works on Aztec (https://aztec.network/blog/how-gas-works-on-aztec)
- "Gas on Aztec is known as Fee Juice and is used to pay for transaction costs." Obtained by bridging $AZTEC from L1; bridges like Shield can convert part of a bridged amount into Fee Juice. Browser wallets "will not be able to send transactions without it."
- Fee Juice can be public or private: public gas means "the gas you spend to execute that transaction could still be visible"; "Private Fee Juice keeps your entire transaction footprint hidden."
- "Aztec has native fee abstraction": apps "may choose to cover part or all of a user's transaction costs"; in most apps you "will most likely never see Fee Juice." (zk.money's sponsorFPC/claimFpc/FPCFunder design is exactly this: users never hold Fee Juice; the relayer converts DAI deposit/withdrawal fees into Fee Juice and tops up the FPC.)

### The Aztec TGE vote (https://aztec.network/blog/the-aztec-tge-vote-what-you-need-to-know, 22 Jan 2026)
- "The TGE is a governance vote that decides when to unlock these tokens." Phase 1: "Once 600 out of 1,000 sequencers signal, the proposal moves to a community vote." Phase 2: "Anyone who participated in the token sale can participate." "At least 100M tokens must participate"; "66% of votes must be in favor." Token sale concluded 6 Dec 2025; "TGE can go live as early as February 12, 2026, at 7am UTC"; fallback 13 Nov 2026. Labs/Foundation/investors "cannot participate in staking or governance for 12 months"; team/investor tokens locked 1 year then vest 2 years. Tokens were withdrawn to personal Token Vault contracts on Ethereum; trading via a Uniswap v4 pool after the vote.

### Ignition chain update (https://aztec.network/blog/aztec-ignition-chain-update, 30 Jan 2026)
- Ignition Chain went live Nov 2025 as "the first decentralized L2 on Ethereum", launched "to prove the stability of the consensus layer before the execution environment ships, which will enable privacy-preserving smart contracts" (i.e. no user transactions/apps yet). "more than 185 operators across 5 continents", "3,400+ sequencers", "50+ provers", block height 75k "with zero downtime", "99%+ attestation rate". TGE proposal passed 26 Jan 2026; Uniswap pool earliest 11 Feb 2026. Rewards per epoch (32 blocks), 70% sequencers / 30% provers; 200k $AZTEC to run or delegate; Labs/Foundation "are not running any sequencers on the network or participating in governance."

### Alpha network security (https://aztec.network/blog/alpha-network-security-what-to-expect, Joe Andrews, 10 Mar 2026)
- Alpha goal: "Enable transactions at 1TPS, ~6s block times"; each Alpha deployment is separate and state does not carry over between releases (hence zk.money's "old network" v5 -> v6 upgrade flow and portal freeze design).
- Security: re-execution committee, "33 out of 48 attestations" per checkpoint; attacking the AVM needs ~55% of validators (~332M AZTEC); the network can "reasonably secure value up to around 332M AZTEC", practical ceiling ~$6.5M. The AVM "has not yet completed its internal and external audits"; main bug bounty not live yet; fixes expected in v5. Users "should not deposit more value than they are willing to lose"; apps may cap deposits; portals holding >332M AZTEC without withdrawal limits/delays/pause would be attractive targets, so per-user caps, pause functions or delays are recommended (zk.money's $5k/tx, $100k/day, freezable portal match this guidance). Beta requires >10 TPS, 99.9% uptime, no critical bug-bounty bugs for 3 months.

## Takeaways relevant to a privacy-project design

1. launch.zk.money is a marketing/vanity entry URL, not a token launch. The real artifact is wallet.zk.money, a production Aztec v6 app that went live on Aztec Tierra the day it shipped (3 Nov 2026).
2. Its architecture is a useful reference: passkey-derived keys; client-side proving (barretenberg WASM + OPFS SQLite PXE in the browser); sponsored fees via FPC funded by DAI deposit/withdrawal fees converted to Fee Juice by relayers; TEE (AWS Nitro) co-signature as a second factor against prover soundness bugs; immutable portal with hard caps and anyone-can-freeze + three refund verifiers; OFAC/Predicate screening at the relayer, not the contract; desktop app and self-run enclave as escape hatches.
3. Aztec's own framing: Alpha is "mainnet" but "Alpha software"; expect vulnerabilities; cap exposure.

## URLs used

- https://launch.zk.money/ (302 -> https://wallet.zk.money/ -> client route https://wallet.zk.money/claim)
- https://wallet.zk.money/enter, https://wallet.zk.money/deposit, https://wallet.zk.money/withdraw, https://wallet.zk.money/about (404), /faq (404), /terms (404)
- https://wallet.zk.money/assets/index-Cw1j47jH.js, main-DUMfDvmV.js, walletBoot-CaUSfdN5.js, claim_fpc-BPJtz3zS.js, deposit_refund_eligibility-ClnGqRoG.js, login-UP3DZBGS-CaoZ1sv9.js, upgradeFreeze-mU1qZwDM.js
- https://cdn.zk.money/profiles/v6/current.json
- https://v6-prod.oxide.zk.money/v6/v6-prod/releases.json
- https://zk.money/
- https://docs.zk.money/, https://docs.zk.money/docs, https://docs.zk.money/docs/faq, https://docs.zk.money/docs/trust, https://docs.zk.money/docs/limits, https://docs.zk.money/docs/run-a-relayer, https://docs.zk.money/docs/exit, https://docs.zk.money/docs/savings, https://docs.zk.money/terms
- https://aztec.network/apps, https://aztec.network/projects/zk-money, https://aztec.network/network/status, https://aztec.network/roadmap
- https://aztec.network/blog/history-of-aztec-pioneering-privacy-in-web3
- https://aztec.network/blog/how-gas-works-on-aztec
- https://aztec.network/blog/the-aztec-tge-vote-what-you-need-to-know
- https://aztec.network/blog/aztec-ignition-chain-update
- https://aztec.network/blog/alpha-network-security-what-to-expect
