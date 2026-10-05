# PondPad frontend

The PondPad site: Vite + React + TypeScript + wagmi/viem (D-66), styled with the design system in `../design/` (tokens, `pp-` components, self-hosted fonts). Static build, hash routes, so it can be served from IPFS. Runs against Robinhood Chain Testnet (`../contracts/deployments/46630.json`).

```bash
cd launchpad/frontend
npm install
npm run dev          # http://localhost:5173 ; /rpc is proxied to the testnet RPC
npm run build        # dist/ (typecheck + build); VITE_RPC_URL sets the RPC of a build
npm run abis         # after `forge build`: refresh src/abi/*.ts from ../contracts/out
```

## Pages

| Route | Page | State |
|---|---|---|
| `/` | Explore: About to Leap spotlight, New / About to Leap / Frogs / Trending, X-verified and no-tax filters, sort | Built |
| `/c/<coin>` | Coin: header, Leap meter, chart, Trades / Holders / Creator / About, trade box (IMD / ETH / USDG, quote, route, impact, slippage, fee line), position and dividends, creator claim; phone: Buy / Sell bar + sheet | Built |
| `/spawn` | Spawn: name, links, coin tax and split, dev buy, pay with IMD / ETH / USDG | Built |
| `/me`, `/u/<address>` | Profile: holdings, created coins with **Claim all** creator fees, rewards (dividends, integrator earnings), activity | Built |
| `/docs/…` | Docs inside the site (Markdown in `src/docs/`, contracts table from the deployment file) | First pages |
| `/terms`, `/privacy` | Legal texts from `../legal/` | Built |
| `/faucet` | Testnet faucet for test IMD and USDG | Built (testnet only) |
| `/pondpad`, `/pond`, `/transparency` | $PONDPAD sale / market / airdrop, staking, transparency | Next |

## How it reads the chain

- **PadLens** for coin lists, coin state, curve and pool quotes and wallet positions; the **v4 Quoter** for the ETH and USDG legs (`src/lib/quote.ts`).
- **Logs** (`src/lib/chain.ts`) for trades, launches (creator, metadata), graduations and holders, scanned from the deploy block in 2M-block chunks. The testnet RPC returns `blockTimestamp = 0` in logs, so times are interpolated from sampled block headers. An indexer replaces the scans later.
- **Transactions** (`src/lib/tx.ts`): exact-amount approvals, simulate, estimate, send with +20% gas (+50% for $PONDPAD market swaps and keeper-type calls, D-64), wait, toast; reverts decoded to the copy in `SITE-COPY.md`.
- **Legal gate** (`src/components/LegalGate.tsx`): a connected wallet must accept the Terms and Privacy Policy (and confirm age and jurisdiction) before using the site; the acceptance is a session cookie per wallet and `LEGAL_VERSION` (D-69).
- **Coin metadata** (untrusted): https / ipfs links only, text rendered as text. On the testnet, Spawn inlines the metadata as a `data:` URI (D-68); mainnet pins it to IPFS through the upload service.

Tested on 5 Oct 2026 against the live testnet with the testnet wallet through a scripted browser: faucet, buy with IMD, buy with ETH, sell for USDG, collect dividends, spawn with an ETH dev buy, claim all creator fees, legal gate (shown, accepted, kept across reloads in the session), desktop and phone widths, night and day themes.
