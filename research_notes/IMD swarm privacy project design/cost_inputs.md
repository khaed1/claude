# Cost-model price inputs for a 1,000-agent VPS privacy project on Ethereum mainnet (as of 8 Nov 2026)

Research date: 8 November 2026. All figures are quotes from the cited page on the stated date; nothing below is an estimate by the researcher. Where only a third-party tracker or secondary article could be reached (official page blocked with 403/404), the row says so. EUR prices are left in EUR (no FX conversion applied).

## Summary table

| # | Item | Value | Unit | Date | Source URL |
|---|---|---|---|---|---|
| 1a | ETH/USD spot | 2,225.29 | USD | 2026-11-08 17:19:59 UTC | https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd&include_market_cap=true&include_last_updated_at=true |
| 1a | ETH market cap | 271,932,026,777 | USD | 2026-11-08 17:19 UTC | same as above |
| 1b | IMD (Identity.md, 0xd34a…3b7) price | 2.60 (main Uniswap v4 pool); 2.59 / 2.58 on two smaller pools | USD | 2026-11-08 | https://api.dexscreener.com/latest/dex/tokens/0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7 |
| 1b | IMD market cap / FDV | 10,968,133 / 10,973,558 | USD | 2026-11-08 | same as above |
| 1b | IMD main-pool liquidity / 24h volume | 1,281,550.66 / 133,632.67 | USD | 2026-11-08 | same as above |
| 1c | ETH mainnet base fee (Etherscan gas tracker) | 0.068 (low 0.068 / avg 0.068 / high 0.069) | gwei | 2026-11-08 17:20:39 UTC | https://etherscan.io/gastracker |
| 1c | ETH mainnet base fee (Chaingate) | 0.058181 (Normal total 0.061464, High 0.183181) | gwei | 2026-11-08 | https://chaingate.dev/gas-tracker/ethereum |
| 1c | ETH 30-day average base fee (secondary article, source not named) | ~0.37 | gwei | article dated 2026-11-08 | https://icrypto24.com/article/ethereum-gas-fees-fell-58-percent-3-5-cents-eth-holders-catch-2026 |
| 1c | ETH 2026 Jan–Oct average base fee / avg gas price (same article) | 0.27 / ~0.196 | gwei | 2026-11-08 | same as above |
| 1c | ETH 7-day average gas | NOT FOUND (see not-found list) | – | – | – |
| 2 | Hetzner CX23 2 vCPU/4 GB/40 GB, 20 TB traffic | 5.99 (listed "currently unavailable") | EUR/mo excl. VAT | 2026-11-08 | https://www.hetzner.com/cloud/cost-optimized/ |
| 2 | Hetzner CX33 4 vCPU/8 GB/80 GB, 20 TB | 8.99 (listed "currently unavailable") | EUR/mo excl. VAT | 2026-11-08 | same |
| 2 | Hetzner CX43 8 vCPU/16 GB/160 GB, 20 TB (no 4/16 shape) | 16.49 (listed "currently unavailable") | EUR/mo excl. VAT | 2026-11-08 | same |
| 2 | Hetzner CPX22 2 vCPU/4 GB/80 GB, 20 TB (EU) | 19.99 (€0.0320/h) | EUR/mo excl. VAT | 2026-11-08 | https://www.hetzner.com/cloud/regular-performance/ |
| 2 | Hetzner CPX32 4 vCPU/8 GB/160 GB, 20 TB (EU) | 35.99 (€0.0577/h) | EUR/mo excl. VAT | 2026-11-08 | same |
| 2 | Hetzner CPX42 8 vCPU/16 GB/320 GB, 20 TB (EU) | 69.99 (€0.1122/h) | EUR/mo excl. VAT | 2026-11-08 | same |
| 2 | Hetzner traffic overage | 1.00 per TB (EU/US); 7.40 per TB (SIN) | EUR | 2026-11-08 | same |
| 2 | OVH VPS-1 2 vCPU/4 GB/40 GB NVMe, unlimited traffic @500 Mbps | 4.54 ("from") | USD/mo | 2026-11-08 | https://www.ovhcloud.com/en/vps/ |
| 2 | OVH VPS-2 4 vCPU/8 GB/75 GB, unlimited @1 Gbps | 8.50 ("from") | USD/mo | 2026-11-08 | same |
| 2 | OVH VPS-3 6 vCPU/12 GB/100 GB, unlimited @2 Gbps (no 4/16) | 12.32 ("from") | USD/mo | 2026-11-08 | same |
| 2 | DigitalOcean Basic 2 vCPU/4 GiB/80 GiB, 4,000 GiB transfer | 24.00 | USD/mo | 2026-11-08 | https://www.digitalocean.com/pricing/droplets |
| 2 | DigitalOcean Basic 4 vCPU/8 GiB/160 GiB, 5,000 GiB | 48.00 | USD/mo | 2026-11-08 | same |
| 2 | DigitalOcean Basic 8 vCPU/16 GiB/320 GiB, 6,000 GiB (no 4/16 basic) | 96.00 | USD/mo | 2026-11-08 | same |
| 2 | Vultr Regular 2 vCPU/4 GB/80 GB, 3,000 GB transfer (third-party listing; vultr.com returned 403) | 20.00 | USD/mo | page undated; trial 2024-06 | https://vpsbenchmarks.com/hosters/vultr/plans/regular_4gb_2cores |
| 2 | Vultr Regular 4 vCPU/8 GB/160 GB, 4,000 GB | 40.00 ($0.0550/h) | USD/mo | trial 2026-04-30 | https://vpsbenchmarks.com/hosters/vultr/plans/regular_8gb_4cores |
| 2 | Vultr High Performance 4 vCPU/8 GB/180 GB | 48.00 | USD/mo | undated listing | https://vpsbenchmarks.com/hosters/vultr |
| 2 | Vultr High Frequency 4 vCPU/16 GB/384 GB | 96.00 | USD/mo | undated listing | same |
| 2 | Contabo Cloud VPS 10 (4 vCPU/8 GB/75 GB NVMe, "unlimited" traffic; marked deprecated; contabo.com 403) | 4.50 (~$5.04) | EUR/mo | trial 2025-12-12 | https://www.vpsbenchmarks.com/hosters/contabo/plans/cloud-vps-10 |
| 2 | Contabo Cloud VPS 20 (6 vCPU/12 GB/100 GB, unlimited @300 Mbps; deprecated) | 7.00 (5.60 with 1-yr term) | EUR/mo | trial 2026-04-27 | https://www.vpsbenchmarks.com/hosters/contabo/plans/cloud-vps-20 |
| 2 | Netcup VPS 500 G12.5 2 vCPU/4 GB/64 GB, "traffic included" | 8.26 (9.50 incl. 19% VAT), 12-mo term | EUR/mo | 2026-11-08 | https://www.netcup.com/en/server/vps |
| 2 | Netcup VPS 1000 G12.5 4 vCPU/8 GB/128 GB | 14.50 (16.68 incl. VAT) | EUR/mo | 2026-11-08 | same |
| 2 | Netcup VPS 2000 G12.5 8 vCPU/16 GB/256 GB (no 4/16) | 26.92 (30.96 incl. VAT) | EUR/mo | 2026-11-08 | same |
| 2 | Phala Cloud tdx.large (Intel TDX CVM, 4 vCPU/8 GB) | 0.232 per hour while running (~$169/mo at 730 h) | USD/h | page "last updated Oct 6, 2026" | https://cloud.phala.com/about/pricing |
| 2 | Phala Cloud CVM storage | 0.000139 per GB-hour (~$0.10/GB-mo) | USD | 2026-10-06 | same |
| 2 | Google Cloud Confidential VM C3 Intel TDX (figure from search snippet of Google pricing page; direct fetch truncated) | 0.0033982 per vCPU-h; 0.0004555 per GiB-h | USD | undated snippet | https://cloud.google.com/confidential-computing/confidential-vm/pricing |
| 2 | Azure DCesv5/ECesv5 TDX hourly price | NOT FOUND | – | – | – |
| 2 | RunPod RTX 4090 Secure / Community | 0.89 / 0.34 | USD/h | 2026-11-08 | https://www.runpod.io/pricing |
| 2 | RunPod RTX 5090 Secure / Community | 1.19 / 0.69 | USD/h | 2026-11-08 | same |
| 2 | Vast.ai RTX 4090 cheapest single-GPU on-demand (tracker) | 0.363 | USD/GPU-h | tracker updated 2026-11-08 | https://computeprices.com/providers/vast/gpus/rtx4090 |
| 2 | Vast.ai RTX 5090 cheapest single-GPU on-demand (tracker) | 0.463 | USD/GPU-h | tracker updated 2026-11-08 | https://computeprices.com/providers/vast/gpus/rtx5090 |
| 3a | Spearbit/Cantina weekly team rate (3–5 researchers) | 32,500–48,000 per week; 2–6 weeks | USD | "as of mid-2026" | https://www.spark.money/tools/smart-contract-audit-firm-comparison |
| 3a | Cantina Managed review, Venus DAO proposal | 422,625 for 10.5 weeks (≈$40,250/wk) | USD | undated in result | https://www.spark.money/tools/smart-contract-audit-firm-comparison (proposal cited via search; see findings) |
| 3a | Trail of Bits | 80k–200k+; ~25,000 per engineer-week | USD | mid-2026 | https://www.spark.money/tools/smart-contract-audit-firm-comparison ; https://www.smartcontractaudit.com/guides/smart-contract-audit-pricing-2026 |
| 3a | OpenZeppelin | 50k–200k+ | USD | mid-2026 | https://www.spark.money/tools/smart-contract-audit-firm-comparison |
| 3a | Code4rena contest pool | 20k–200k+ (platform wound down May 2026; Immunefi absorbing clients) | USD | 2026-05-14 | https://www.kucoin.com/news/flash/immunefi-to-take-over-code4rena-s-bug-bounty-clients-after-platform-shuts-down |
| 3a | Sherlock contest pools (examples) | EF Fusaka max 2,000,000 (Sep–Oct 2025); Usual 209,000; Ripple 550,000 (Apr 2026) | USD | 2025–2026 | https://sherlock.xyz/case-studies/ethereumfoundation ; https://www.theblock.co/post/349204 ; https://www.theblock.co/press-releases/397376/ |
| 3b | ZK circuit audit price (zkSecurity/Veridise/Least Authority/ToB) | NOT FOUND (quote-only); unsourced third-party range 100k–500k+ | USD | – | https://www.chainscorelabs.com/blog/developer-ecosystem-tools-languages-and-grants/zk-circuit-development/the-hidden-tax-of-auditing-inscrutable-zk-circuits |
| 3c | Certora continuous FV for Aave (annual) | 2,700,000/yr (1,890,000 USDC + 810,000 in AAVE) | USD | proposal (Aave governance) | https://governance.aave.com/t/security-and-agility-of-aave-smart-contracts-via-continuous-formal-verification/10181 |
| 3c | Runtime Verification, Polkadot PVM formal spec (K Framework) | 371,875 | USD/USDC | 2024-08-13 | https://docs.google.com/document/d/1Mf8fEOmt4DpVxTNMVCHFKnZLHcH9vYAJLFPm-ClVmLI/export?format=pdf |
| 3d | Immunefi Standard: critical payout floor | ≥10% of funds at risk | % | undated blog | https://immunefi.com/blog/expert-insights/immunefi-standard/ |
| 3d | Immunefi own program critical | 10% of affected funds, max 50,000 | USD | current | https://immunefi.com/bug-bounty/immunefi/ |
| 3d | LayerZero critical | max(250,000, 10% VaR), hard cap 15,000,000 | USD | current | https://blockworks-editorial-git-feat-onthemargin-newsletter-blockworks.vercel.app/news/bug-bounty-15m-payout |
| 3d | Kamino critical | 10% funds at risk, min 150,000, max 1,500,000 | USD | current | https://kamino.com/docs/security/bug-bounty |
| 3e | Groth16 Phase-2 ceremony (p0tion) cost | NOT FOUND in USD; infra = AWS S3/Lambda/SNS/EC2 + Firebase Blaze; "AWS free tier will cover a good number of requests" | – | – | https://hackmd.io/@ctrlc03/HysyJzPgn |
| 4 | Waku RLN v2 membership price (spec, recommended mainnet params) | 0.05 USD per 1 msg/epoch for 180-day active period, paid in DAI; r_min 20, r_max 600 msg per 600 s epoch; grace 30 d; R_max 160,000 | USD | spec; "as of August 2024" Sepolia only | https://raw.githubusercontent.com/waku-org/specs/master/standards/core/rln-contract.md |
| 4 | Waku RLN Linea deployment price | NOT FOUND | – | – | – |
| 4 | Nym mixnet for dApps | "for the moment the Mixnet is free to use"; credential faucet planned | – | docs undated | https://nym.com/docs/developers/concepts/credentials |
| 4 | NymVPN subscription | 4.00/mo on 1-yr ($48/yr; full price $96); up to 75% off paying in NYM | USD | 2026-11-08 | https://nym.com/pricing |
| 4 | Tor advertised / consumed relay bandwidth | 1,221.5 (2026-11-05) / 492.2 (2026-11-04) | Gbit/s (Tor Metrics CSV columns advbw, bwhist) | 2026-11-04/05 | https://metrics.torproject.org/bandwidth.csv?start=2026-10-20&end=2026-11-08 |
| 4 | Pinata Free / Picnic | 0 (1 GB, 10 GB bw, 500 files) / 20 (1 TB, 500 GB bw) | USD/mo | 2026-11-08 | https://pinata.cloud/pricing |
| 4 | Filebase Free / Pro | 0 (5 GB, 10 GB IPFS egress) / 7.50 (500 GB, 250 GB egress; $0.015/GB overage) | USD/mo | 2026-11-08 | https://filebase.com/pricing/ |
| 4 | Storacha (now fil.one) pay-as-you-go | 5.99 per TB-month, $5.99 monthly minimum, no egress charge | USD | 2026-11-08 | https://fil.one/pricing |
| 4 | ENS .eth 5+ / 4 / 3 chars | 5 / 160 / 640 | USD/yr (paid in ETH) | docs "at time of writing" | https://docs.ens.domains/registry/eth |
| 4 | Automata DCAP on-chain verify | ~4–5M (4M with RIP-7212 precompile, 5M without) | gas | README v1.1 | https://github.com/automata-network/automata-dcap-attestation |
| 4 | Automata DCAP ZK path | RISC Zero Groth16 522k; SP1 Groth16 493k; SP1 Plonk 569k | gas | README v1.1 | same |
| 4 | Succinct Prover Network price per proof | dynamic: base fee (COMPRESS_FEE/GROTH16_FEE/PLONK_FEE, auctioneer-set) + auction price per PGU; no fixed $ | PROVE | 2026-11-08 | https://docs.succinct.xyz/docs/protocol/spn/parameters |
| 4 | Boundless median proving cost | 0.04 per billion cycles | USD | 2026-01-11 | https://boundlessfdn.org/blog/boundless-network-update |
| 5 | Groth16 verifier deployment gas | NOT FOUND; verification ≈207,700 + 7,160 × public inputs | gas | undated | https://hackmd.io/Fa4A8lVKRM2TwVh1dhUb1Q |
| 5 | Safe creation gas (web app, 1.4.1 era) | ~263k (2 owners), ~309k (3), ~331k (4) | gas | undated help article | https://help.safe.global/en/articles/40853-costs-of-creating-a-safe |
| 5 | Zodiac Roles v2 deployment gas | NOT FOUND (minimal proxy via ZodiacModuleProxyFactory) | – | – | https://github.com/gnosis/zodiac-modifier-roles |
| 5 | Tornado Cash deposit gas | 43,381 + 50,859 × tree_depth → 1,088,354 at depth 20; withdraw 301,233 | gas | tornado-core README | https://git.hackliberty.org/Git-Mirrors/tornado-core/commit/981325b1ff78cc17a418e2a2b983dabec1816623 |
| 5 | Poseidon T3 (2-input) on-chain hash | 49,858 (orig.) / 53,189 (circomlib 0.2.4) / 55,543 (circomlib 0.5.1) | gas | 2020-05-20 post + updates | https://ethresear.ch/t/gas-and-circuit-constraint-benchmarks-of-binary-and-quinary-incremental-merkle-trees-using-the-poseidon-hash-function/7446 |
| 5 | MiMCSponge 2-input hash | 59,840 | gas | 2020-05-20 | same |
| 5 | Incremental Merkle insert, binary Poseidon, depth 20 / 30 | 767,565 / 1,107,895 (incl. 21k base) | gas | 2020-05-20 | same |
| 5 | Incremental Merkle insert, binary MiMC, depth 20 / 30 | 969,498 / 1,410,634 | gas | 2020-05-20 | same |
| 5 | Keccak256 measured 2-to-1 hash (for comparison) | 418 | gas | 2026 thread | https://ethereum-magicians.org/t/is-there-appetite-for-a-cheaper-on-chain-ao-hash-ashlar-14-232-gas-vs-poseidons-18-229/29315 |
| 6 | Claude Pro / Max / Ultra | 20 ($17 annual) / 100 (5x) / 200 (10x) | USD/mo | 2026-11-08 | https://claude.com/pricing |
| 6 | ChatGPT Plus / Pro | 20 / 100 (5x Codex) and 200 (20x Codex) | USD/mo | 2026-04-12 (openai.com 403) | https://thenextweb.com/news/openais-new-100-chatgpt-pro-plan-targets-claude-max-with-five-times-the-codex-access |
| 6 | IMD seat NFT floor (OpenSea identitymd) | 0.74999999 ETH (≈$1,669 at $2,225.29); 1,999 items, 792 owners; 24h vol $13,858, 7d vol $79,366 | ETH | 2026-11-08 | https://opensea.io/collection/identitymd |
| 7 | Railgun fees = revenue (DefiLlama) 24h / 7d / 30d / all-time | 8,092 / 66,270 / 316,717 / 14,132,583 | USD | 2026-11-08 | https://api.llama.fi/summary/fees/railgun?dataType=dailyRevenue |
| 7 | Railgun TVL (DefiLlama, search snippet) | 79.5M | USD | 2026-11 | https://defillama.com/protocol/railgun |
| 7 | 0xbow (Privacy Pools) seed | 3,500,000, led by Starbloom Capital; no burn disclosed | USD | 2025-11-18 | https://www.theblock.co/post/379395/0xbow-raises-3-5-million-seed-round-ethereum-foundation-backed-privacy-pools |
| 7 | Tornado Cash DAO treasury (DefiLlama) | 26,433,253 (all own-token TORN) | USD | 2026-11-08 12:17 UTC | https://api.llama.fi/treasury/tornado-cash |
| 7 | Tornado Cash TVL (DefiLlama) | ~780.5M | USD | 2026-11 | https://defillama.com/protocol/tornado-cash |
| 7 | Railgun DAO treasury USD | NOT FOUND | – | – | – |
| 7 | Railgun broadcaster count / Tornado relayer count | NOT FOUND | – | – | – |

## Not found (after searching)

- Ethereum 7-day average gas price in gwei for the week to 8 Nov 2026 (Etherscan chart is JS-rendered, CSV needs browser; Owlracle API 401; The Block/YCharts pages 404/empty). Only a 30-day base-fee average (~0.37 gwei) from a secondary article with no named source.
- IMD on CoinGecko (contract lookup 404) and CoinMarketCap; only DEX Screener figures obtained.
- Vultr and Contabo official pricing pages (both 403); third-party listings used instead.
- Google Cloud Confidential VM pricing page could not be read directly (content truncated); a per-vCPU/per-GiB figure came only from a search snippet of that page and should be verified in the GCP calculator.
- Azure DCesv5/ECesv5 (Intel TDX) hourly price (no official or tracker page reachable; cloudprice.net 404).
- Vast.ai live marketplace prices (vast.ai/pricing renders client-side); a tracker updated 8 Nov 2026 used instead.
- Published rate cards for Zellic, Nethermind, zkSecurity, Veridise, Least Authority, Trail of Bits ZK audits; all are quote-based. No 2025–2026 governance proposal with a ZK-circuit audit price was found.
- Primary source for the "$25,000 per engineer-week" Trail of Bits / OpenZeppelin rate (attributed to an Arbitrum ARDC proposal by a 2026 guide; not located in ARDC forum threads).
- Typical/median Code4rena or Sherlock contest pool size (only examples).
- Certora or Runtime Verification one-off engagement price for a small protocol (only the Aave annual contract and the RV Polkadot grant).
- Dollar cost of running a p0tion Phase-2 ceremony (PSE docs only list the AWS/Firebase components).
- Waku RLN membership price/tiers on the Linea (or Linea Sepolia) deployment; only the spec's recommended mainnet parameters and the Aug-2024 Sepolia deployment status.
- Nym current status of the developer credential faucet / dApp pricing (docs say mixnet free "for the moment").
- Groth16 verifier (snarkjs Verifier.sol) deployment gas; Semaphore v4 gas report values (published only as an image); Zodiac Roles v2 deployment gas; Safe 1.4.1 bare `createProxyWithNonce` gas (only web-app totals by owner count).
- Succinct per-proof USD price (fees are dynamic; need `GetProofRequestParams` RPC or explorer); Boundless ZKC per-proof price.
- Railgun DAO treasury USD value (DefiLlama treasury endpoint exceeded fetch size; no other source).
- Count of Railgun broadcasters and of registered/active Tornado Cash relayers (L2BEAT privacy page exists for Railgun but no count was retrieved; the Oct-2025 UZH study has no relayer counts).
- Netcup included traffic volume (page says "Traffic included", no TB figure).
- Spearbit/Cantina official price list (only third-party weekly range and one DAO proposal).

## Q1. Prices: ETH/USD, IMD token, Ethereum gas

### Takeaway
ETH traded at $2,225.29 at 17:19 UTC on 8 Nov 2026; IMD traded at $2.60 with ~$11.0M market cap (DEX Screener, Uniswap v4); mainnet base fee was 0.058–0.068 gwei, with a 30-day average base fee of ~0.37 gwei reported by a secondary source and no 7-day figure found.

### Cited Findings
- ETH/USD 2225.29, market cap $271,932,026,777, last updated unix 1794158399 (= 2026-11-08 17:19:59 UTC) — [CoinGecko simple price API](https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd&include_market_cap=true&include_last_updated_at=true)
- IMD (Identity.md) main Uniswap v4 pool: priceUsd 2.60, FDV 10,973,558, marketCap 10,968,133, liquidity $1,281,550.66, 24h volume $133,632.67; two further pools at $2.59 (liquidity $109k) and $2.58 (Uniswap v3, liquidity $16k). 14 pairs total on Ethereum, all Uniswap — [DEX Screener token API](https://api.dexscreener.com/latest/dex/tokens/0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7)
- A DropsTab snapshot showed IMD at ~$7.19 and ~$51M market cap (undated, conflicts with DEX Screener's live quote) — [DropsTab](https://dropstab.com/coins/Identity-imd)
- Etherscan gas tracker snapshot 11/8/2026 5:20:39 PM UTC: base fee 0.068 gwei; Low 0.068 / Average 0.068 / High 0.069 gwei; Rapid = base 0.068 + 0.001 priority. Historical/7-day sections were empty — [Etherscan Gas Tracker](https://etherscan.io/gastracker)
- Etherscan gas tracker snapshot Nov 7, 2026 8:05 PM UTC: Low 0.035 / Avg 0.036 / High 0.04 gwei — [Etherscan Gas Tracker (search snippet)](https://etherscan.io/gastracker)
- Chaingate, 8 Nov 2026: base fee 0.058181 gwei; Low 0.058181, Normal 0.061464 (tip 0.003283), High 0.183181 (tip 0.125), Max 2.058181 gwei; 21,000-gas transfer ≈ $0.0027–0.0029 — [Chaingate](https://chaingate.dev/gas-tracker/ethereum)
- Etherscan average-gas-price chart page header showed 0.062 gwei (chart data is JS-rendered; CSV at `?output=csv` not retrievable) — [Etherscan chart](https://etherscan.io/chart/gasprice)
- Article dated 8 Nov 2026: 30-day average base fee ~0.37 gwei; Jan–Oct 2026 average base fee 0.27 gwei vs 2.00 gwei in 2025; 2026 average gas price ~0.196 gwei with lows near 0.055; median tx fee 3.5 cents in 2026 vs 35 cents in 2025; cites Ethereum Institutional "State of the Ledger" (5 Nov 2026), Coin Metrics and ultrasound.money but not for the 30-day figure specifically — [icrypto24](https://icrypto24.com/article/ethereum-gas-fees-fell-58-percent-3-5-cents-eth-holders-catch-2026)
- Milk Road gas page showed 0.06 gwei (no timestamp) — [Milk Road](https://milkroad.com/ethereum/gas/)

### Inferences
- IMD market cap ≈ FDV implies nearly all supply is circulating per DEX Screener's figures.
- At 0.06–0.07 gwei base fee and ETH $2,225, 1M gas costs about $0.13–0.16; at the reported 30-day average of 0.37 gwei, about $0.82 per 1M gas (arithmetic on cited figures, not a quoted price).

### Gaps
- No 7-day average gas figure from a primary tracker; Etherscan CSV, Owlracle (401), YCharts (empty), The Block (404) all failed.
- CoinGecko/CoinMarketCap listing for IMD not reachable (404 on contract endpoint).

## Q2. VPS hosting, confidential-VM and GPU rental prices

### Takeaway
2 vCPU/4 GB ranges from €5.99 (Hetzner CX23, currently unavailable) / $4.54 (OVH VPS-1) to $24 (DigitalOcean, Vultr HP); 4 vCPU/8 GB from €8.99 (Hetzner CX33) / $8.50 (OVH) to $48 (DO, Vultr HP); a 4 vCPU/16 GB shape exists only at Vultr HF ($96) and Netcup/Hetzner/DO offer 8 vCPU/16 GB instead (€16.49–€69.99, $96). Intel TDX CVMs: Phala tdx.large 4 vCPU/8 GB $0.232/h (~$169/mo). RTX 4090 from $0.34/h (RunPod Community) and $0.363/h (Vast.ai), RTX 5090 from $0.463/h (Vast.ai) / $0.69/h (RunPod Community).

### Cited Findings
- Hetzner Cost-Optimized (all EUR excl. VAT, 20 TB traffic, NVMe): CX23 2 vCPU/4 GB/40 GB €5.99; CAX11 (Arm) 2/4 €6.49; CX33 4/8/80 GB €8.99; CAX21 4/8 €10.99; CX43 8/16/160 GB €16.49; CAX31 8/16 €21.49; CX53 16/32 €29.99. Every plan displayed "This product is currently unavailable. Please check back later." — [Hetzner cost-optimized](https://www.hetzner.com/cloud/cost-optimized/)
- Hetzner Regular Performance (EUR excl. VAT, EU locations, 20 TB traffic): CPX22 2 vCPU/4 GB/80 GB €19.99 (€0.0320/h); CPX32 4/8/160 GB €35.99 (€0.0577/h); CPX42 8/16/320 GB €69.99 (€0.1122/h). US: CPX21 3/4 €32.49, CPX31 4/8 €62.99 (US traffic 2–3 TB). Overage €1.00/h per TB (EU/US) — [Hetzner regular performance](https://www.hetzner.com/cloud/regular-performance/)
- Hetzner overview: Cost-Optimized from €5.99, Regular Performance from €6.49, General Purpose (dedicated vCPU) from €43.49, all excl. VAT — [Hetzner cloud](https://www.hetzner.com/cloud/)
- OVH VPS (USD, "from" prices, unlimited traffic): VPS-1 2 vCPU/4 GB/40 GB NVMe, 500 Mbps $4.54; VPS-2 4/8/75 GB, 1 Gbps $8.50; VPS-3 6/12/100 GB, 2 Gbps $12.32; VPS-4 8/24/200 GB, 3 Gbps $23.37 — [OVHcloud VPS](https://www.ovhcloud.com/en/vps/)
- DigitalOcean Basic Droplets: 2 vCPU/4 GiB/80 GiB SSD, 4,000 GiB transfer $24.00/mo ($0.03571/h); 4 vCPU/8 GiB/160 GiB, 5,000 GiB $48.00; 8 vCPU/16 GiB/320 GiB, 6,000 GiB $96.00; no 4 vCPU/16 GiB Basic shape — [DigitalOcean Droplet pricing](https://www.digitalocean.com/pricing/droplets)
- Vultr Regular 4GB 2 cores: 2 vCPU/4 GB/80 GB, 3,000 GB transfer, $20.00/mo (vultr.com/pricing returned 403) — [VPSBenchmarks](https://vpsbenchmarks.com/hosters/vultr/plans/regular_4gb_2cores)
- Vultr Regular 8GB 4 cores: 4 vCPU/8 GB/160 GB, 4,000 GB transfer, $40.00/mo ($0.0550/h); latest trial 30 Apr 2026 — [VPSBenchmarks](https://vpsbenchmarks.com/hosters/vultr/plans/regular_8gb_4cores)
- Vultr lineup: High Performance 4GB 2 vCPU $24, HP 8GB 4 vCPU/180 GB $48, High Frequency 16GB 4 vCPU/384 GB $96, VX1 GP 4C/16G/240S $110.16; overage $0.010/GB — [VPSBenchmarks Vultr](https://vpsbenchmarks.com/hosters/vultr)
- Better Stack review: Vultr High Performance (AMD) 2 vCPU/4 GB/100 GB NVMe $24/mo — [Better Stack](https://betterstack.com/community/guides/web-servers/vultr-review.md)
- Contabo Cloud VPS 10: 4 vCPU/8 GB/75 GB, unlimited traffic, €4.50 (~$5.04); marked deprecated; Contabo's own snippet lists 3 vCPU, 200 Mbit/s port, 32 TB traffic for VPS 10 (contabo.com returned 403) — [VPSBenchmarks Contabo VPS 10](https://www.vpsbenchmarks.com/hosters/contabo/plans/cloud-vps-10); [Contabo US page (snippet)](https://contabo.com/en-us/locations/united-states)
- Contabo Cloud VPS 20: 6 vCPU/12 GB/100 GB, unlimited @300 Mbps, €7.00/mo (€5.60 with 1-yr term); deprecated — [VPSBenchmarks Contabo VPS 20](https://www.vpsbenchmarks.com/hosters/contabo/plans/cloud-vps-20)
- Netcup G12.5 (12-month term, EUR): VPS 500 2 vCPU/4 GB/64 GB €8.26 (€9.50 incl. 19% VAT); VPS 1000 4/8/128 GB €14.50 (€16.68); VPS 2000 8/16/256 GB €26.92 (€30.96); "Traffic included", volume not stated — [Netcup VPS](https://www.netcup.com/en/server/vps)
- Phala Cloud (page last updated 6 Oct 2026): tdx.large 4 vCPU/8 GB $0.232/h running; storage $0.000139/GB-h (~$0.10/GB-mo), min 20 GB; example tdx.large + 100 GB ≈ $0.246/h running, $0.014/h stopped; GPU TEE H200 $5.50/h on-demand — [Phala Cloud pricing](https://cloud.phala.com/about/pricing)
- Phala instance-types page: Compute Rate = CU × $0.058/h, CU = max(vCPU, memory_GB/2); tdx.small 1 vCPU/2 GB $0.058/h; other Phala pages quote $0.069/CU-h — [Phala instance types](https://cloud.phala.com/about/instance-types); [Phala pricing (marketing)](https://phala.network/pricing)
- Google Cloud Confidential VM C3 Intel TDX: on-demand vCPU $0.0033982/h, memory $0.0004555/GiB-h (search snippet of the pricing page; direct fetch truncated; appears to be the confidential premium, not total instance price) — [GCP Confidential VM pricing](https://cloud.google.com/confidential-computing/confidential-vm/pricing)
- Azure: Microsoft docs say CVM pricing depends on size, refer to Pricing Calculator; cloudprice lists DC96eds_v5 at $3,959.52/mo (not a DCesv5 size) — [Azure CVM overview](https://learn.microsoft.com/azure/confidential-computing/confidential-vm-overview); [cloudprice DC96eds_v5](https://cloudprice.net/vm/Standard_DC96eds_v5)
- RunPod on-demand: RTX 4090 $0.89/h Secure, $0.34/h Community; RTX 5090 $1.19/h Secure, $0.69/h Community — [RunPod pricing](https://www.runpod.io/pricing)
- Vast.ai RTX 4090 cheapest single-GPU on-demand $0.363/GPU-h (multi-GPU $0.389–0.534), updated 8 Nov 2026 — [computeprices Vast 4090](https://computeprices.com/providers/vast/gpus/rtx4090)
- Vast.ai RTX 5090 from $0.463/GPU-h (range $0.463–0.853 across configs), updated 8 Nov 2026 — [computeprices Vast 5090](https://computeprices.com/providers/vast/gpus/rtx5090)

### Inferences
- The cheapest reachable 2 vCPU/4 GB quotes (OVH $4.54, Hetzner €5.99 if available, Contabo €4.50) are 4–5x cheaper than DigitalOcean/Vultr at the same shape; hosting-cost sensitivity in the model is dominated by provider mix, not shape.
- Hetzner's "currently unavailable" flag on all cost-optimized plans on 8 Nov 2026 means CX23/CX33 prices may not be procurable at scale right now.

### Gaps
- Official Vultr and Contabo pages blocked; Azure TDX price not found; GCP figure unverified against the live table.

## Q3. Security costs: audits, ZK audits, formal verification, bounties, trusted setup

### Takeaway
Top-tier Solidity audits are quoted at roughly $32.5k–48k per team-week (Spearbit/Cantina) or ~$25k per engineer-week (Trail of Bits/OpenZeppelin), with small-protocol engagements of $50k–200k; ZK-circuit audit prices are quote-only with no published rates; the only hard formal-verification prices are Aave's $2.7M/yr Certora contract and a $371,875 RV grant; Immunefi's standard is ≥10% of funds at risk for criticals with project-set caps ($50k to $15M); no USD cost for a p0tion ceremony is published.

### Cited Findings
- Spearbit $32.5K–$48K/week for a 3–5 researcher team, 2–6 weeks; Trail of Bits $80K–$200K+ (~$25K/engineer-week), 4–8 weeks; OpenZeppelin $50K–$200K+, 4–8 weeks; Consensys Diligence $30K–$150K+; Halborn $20K–$80K ($400–600/auditor-hour); CertiK $10K–$150K+; Code4rena pools $20K–$200K+; figures "based on publicly available information as of mid-2026", no pricing sources cited — [Spark comparison](https://www.spark.money/tools/smart-contract-audit-firm-comparison)
- Trail of Bits ~$25,000 per engineer per week and OpenZeppelin at the same rate "according to the ARDC proposal" — [smartcontractaudit.com 2026 guide](https://www.smartcontractaudit.com/guides/smart-contract-audit-pricing-2026); 7blocklabs page with the same claim was paywalled (402) — [7blocklabs](https://www.7blocklabs.com/blog/smart-contract-audit-cost-range-2026-and-trail-of-bits-smart-contract-audit-cost-benchmarks)
- Venus community proposal: Cantina Managed review of 10.5 weeks at a discounted $422,625 (≈$40,250/week) — [search result referencing Venus proposal; Cantina docs](https://docs.cantina.xyz/for-organizations/security-solutions/how-audits-work)
- Balancer BIP-713 funded a Spearbit/Cantina audit competition (amount not captured) — [Balancer forum](https://forum.balancer.fi/t/bip-713-spearbit-cantina-audit-competition-funding/6034)
- Trail of Bits reports 300+ blockchain reviews (30 engineer-years), 200+ engineer-weeks on Arbitrum components — [Arbitrum forum ARDC v2](https://forum.arbitrum.foundation/t/election-application-thread-v2-arbitrum-research-development-collective/27267/16)
- Code4rena wind-down reported 14 May 2026; Immunefi to absorb its bounty clients and researchers; Code4rena had been acquired by Zellic in 2024 — [KuCoin news](https://www.kucoin.com/news/flash/immunefi-to-take-over-code4rena-s-bug-bounty-clients-after-platform-shuts-down); [AMBCrypto](https://ambcrypto.com/immunefi-takes-over-code4renas-wardens-can-defi-survive-2026-exploit-surge/)
- Sherlock: Ethereum Foundation Fusaka contest 15 Sep–13 Oct 2025, max prize pool $2,000,000 — [Sherlock case study](https://sherlock.xyz/case-studies/ethereumfoundation); Usual contest $209,000 pool — [The Block](https://www.theblock.co/post/349204); Ripple $550K contest, Apr 2026 — [The Block press release](https://www.theblock.co/press-releases/397376/)
- Zellic 2022 post on Code4rena contests (context only) — [Zellic](https://www.zellic.io/blog/code4rena-free-contests)
- ZK circuit audit third-party ranges: $100,000–$500,000+ and $50k–$500k+ (ChainScore; unsourced marketing) — [ChainScore](https://www.chainscorelabs.com/blog/developer-ecosystem-tools-languages-and-grants/zk-circuit-development/the-hidden-tax-of-auditing-inscrutable-zk-circuits)
- Veridise: pricing quote-based (audit request form); 55% of its ZK audits contained a critical vs 27.5% of other DeFi audits — [Veridise audits](https://veridise.com/audits/); [The Block](https://www.theblock.co/post/306331/blockchain-security-veridise-zk-audits-critical-issues)
- PSE engaged Veridise to review RLN circuits (2023; no price) — [Veridise](https://veridise.com/?p=12207)
- Aave–Certora continuous formal verification: $1,890,000 USDC + $810,000 in AAVE per annum, vested linearly, 30-day termination — [Aave governance](https://governance.aave.com/t/security-and-agility-of-aave-smart-contracts-via-continuous-formal-verification/10181)
- Runtime Verification Polkadot PVM formal spec proposal, 13 Aug 2024: 371,875 USD/USDC — [Proposal PDF](https://docs.google.com/document/d/1Mf8fEOmt4DpVxTNMVCHFKnZLHcH9vYAJLFPm-ClVmLI/export?format=pdf)
- ChainScore FV estimates $50,000–$200,000 (mid-complexity) vs "$500k+ per engagement" elsewhere on same site (conflicting, unsourced) — [ChainScore FV budgeting](https://www.chainscorelabs.com/guides/guides-test-2026/formal-verification/how-to-budget-and-resource-a-formal-verification-project)
- Immunefi Standard: projects with scaling rewards must pay at least 10% of funds at risk for criticals — [Immunefi Standard](https://immunefi.com/blog/expert-insights/immunefi-standard/)
- Immunefi's own program: critical = 10% of funds directly affected, max $50,000 — [Immunefi program](https://immunefi.com/bug-bounty/immunefi/)
- LayerZero: critical min $250,000 or 10% of value at risk, hard cap $15,000,000 — [Blockworks](https://blockworks-editorial-git-feat-onthemargin-newsletter-blockworks.vercel.app/news/bug-bounty-15m-payout)
- Kamino: 10% of funds at risk, min $150,000, max $1,500,000 — [Kamino](https://kamino.com/docs/security/bug-bounty); Aurigami: capped at 10% of damage, min $50,000 — [Aurigami](https://docs.aurigami.finance/public/resources/bug-bounty); Wombat: max $100,000 critical — [Wombat](https://docs.wombat.exchange/developers/bug-bounty); Euler $1M program — [Euler](https://www.euler.finance/blog/euler-launches-1m-immunefi-bug-bounty-programme)
- p0tion coordinator guide: infra = AWS S3 (one bucket per ceremony), Lambda, SNS, EC2 (Amazon Linux 2), Terraform, Firebase Cloud Functions V2 + Firestore on Blaze pay-as-you-go plan, GitHub OAuth; "AWS free tier will cover a good number of requests for ceremonies" but costs may apply by circuit size; claim a newcomer can deploy a ceremony "in under an hour"; no dollar figures — [p0tion coordinator guide](https://hackmd.io/@ctrlc03/HysyJzPgn)
- PSE retrospective on Trusted Setups and p0tion published 15 Jan 2025; tooling adapted to stand-alone with minimal infrastructure — [PSE blog](https://pse.dev/blog/retrospective-trusted-setups-and-p0tion-project); Semaphore V4 Phase-2 ceremony run via ceremony.pse.dev (browser + GitHub login) — [Semaphore docs](https://docs.semaphore.pse.dev/trusted-setup); p0tion repo — [GitHub](https://github.com/privacy-ethereum/p0tion)

### Inferences
- For a 5–10 contract protocol, cited weekly rates imply roughly $65k–$145k for a 2–3 week Spearbit team or $50k–$150k for a 2–3 engineer × 1–2 week Trail of Bits review; these are derived from the cited rates, not quotes.
- Code4rena's May-2026 wind-down leaves Sherlock and Cantina as the main competitive-audit venues for 2026 budgeting.

### Gaps
- No primary source confirms the $25k/engineer-week figure; no published ZK-audit rate from any named firm; no p0tion cost in USD; no typical contest pool statistic.

## Q4. Network services: Waku RLN, Nym, Tor, IPFS pinning, ENS, Automata DCAP, proving networks

### Takeaway
Waku's RLN v2 spec prices membership at $0.05 per message-per-epoch (600 s) for a 180-day period in DAI with 20–600 msg/epoch tiers (so $1–$30 per 180 days), but the live Linea price was not confirmed; Nym mixnet is "free to use for the moment" for developers; Tor is free with ~1,221 Gbit/s advertised capacity; 1 GB IPFS pinning is free at Pinata/Filebase or $5.99/mo minimum at Storacha/fil.one; ENS costs $5/$160/$640 per year for 5+/4/3-char names; Automata DCAP costs ~4–5M gas on-chain or ~493–569k gas via SNARK; Succinct fees are dynamic and Boundless reports $0.04 per billion cycles.

### Cited Findings
- Waku RLN contract spec (recommended initial mainnet parameters): r_min 20 and r_max 600 messages per epoch, epoch 600 s; price p_u = 0.05 USD per 1 message/epoch for active period A = 180 days, token DAI; grace period 30 days; R_max 160,000 msg/epoch; pricing linear in rate limit; "as of August 2024" deployed on Sepolia testnet only; editor Sergei Tikhomirov — [waku-org/specs rln-contract.md](https://raw.githubusercontent.com/waku-org/specs/master/standards/core/rln-contract.md)
- Vac forum proposal: ~$0.05 per message of rate limit, i.e. $5 for 100 msgs/10 min, membership lasting ~1 month (earlier proposal) — [Vac forum](https://forum.vac.dev/t/the-cost-of-rln-memberships-diversifying-the-entrypoints/448)
- RLN v2 contract owner can set min/max rate limit, active/grace periods, token and price via a price calculator contract (LinearPriceCalculator in the logos-messaging fork) — [waku-rlnv2-contract](https://github.com/waku-org/waku-rlnv2-contract); [logos-delivery-rlnv2-contract](https://github.com/logos-messaging/logos-delivery-rlnv2-contract)
- Nym developer docs: "for the moment the Mixnet is free to use"; developers will get a credential faucet once zk-nym is enabled on mainnet; specifics of developer credentials still being worked out — [Nym credentials concept](https://nym.com/docs/developers/concepts/credentials); [Nym required architecture](https://nym.com/docs/developers/concepts/required-architecture)
- NymVPN: 1-year plan $4.00/mo ($48.00 total, vs $96.00 full price); 6-month 25% off; "Save up to 75% with the $NYM token"; 7-day card trial — [NymVPN pricing](https://nym.com/pricing)
- Tor Metrics bandwidth.csv rows: 2026-11-04 advbw 1224.81, bwhist 492.22; 2026-11-05 advbw 1221.46 (bwhist blank); 2026-11-03 advbw 1243.84, bwhist 507.10 (CSV columns are Tor's advertised bandwidth and consumed bandwidth history, reported in Gbit/s on the Tor Metrics graphs) — [Tor Metrics CSV](https://metrics.torproject.org/bandwidth.csv?start=2026-10-20&end=2026-11-08); [Tor Metrics bandwidth page](https://metrics.torproject.org/bandwidth.html)
- Pinata: Free $0 (1 GB storage, 10 GB bandwidth, 500 files, 10K requests); Picnic $20 (1 TB, 500 GB bw, 5M files); Fiesta $100 (5 TB, 2.5 TB bw) — [Pinata pricing](https://pinata.cloud/pricing)
- Filebase: Free $0 (5 GB shared storage, 10 GB IPFS egress); Pro $7.50 (500 GB, 250 GB IPFS egress; $0.015/GB extra storage and bandwidth) — [Filebase pricing](https://filebase.com/pricing/)
- Storacha (storacha.network/pricing 301-redirects to fil.one): pay-as-you-go $5.99 per TB per month with $5.99 monthly minimum; no egress charge (reasonable use); 30-day trial 1 TB — [fil.one pricing](https://fil.one/pricing)
- ENS .eth: 5+ chars $5/yr, 4 chars $160/yr, 3 chars $640/yr, USD-denominated via StablePriceOracle, paid in ETH (send 3–5% premium, excess refunded); note "new .eth registrations through these ENSv1 controllers are permanently disabled", renewals via ETHRenewerV1 — [ENS docs](https://docs.ens.domains/registry/eth)
- Automata DCAP attestation README (v1.1): on-chain verification ~4–5M gas (~4M with RIP-7212 precompile, ~5M without); RISC Zero Groth16 522k; SP1 Groth16 493k; SP1 Plonk 569k; supports SGX V3, SGX/TDX V4 and V5 quotes; ToB audit Feb 2025, OpenZeppelin audit Oct 2025 — [GitHub README](https://github.com/automata-network/automata-dcap-attestation)
- Automata engineering post: ~3M gas single DCAP quote on-chain, 350K with RISC Zero; v1.1 note: EIP-7951 cuts ECDSA verify from ~330,000 to ~6,000 gas, reducing total by nearly 1M gas — [HackMD](https://hackmd.io/@Automataintern/HJ8NNvSdR); [Automata v1.1 blog](https://blog.ata.network/automatas-release-of-dcap-attestation-v1-1-for-agentic-systems-84ae98900370)
- Succinct Prover Network: cost = PROVE base fee (COMPRESS_FEE / GROTH16_FEE / PLONK_FEE, all "Dynamic", set by auctioneer) + auction-determined PROVE per PGU, capped by requester max; current values via `GetProofRequestParams` RPC; example requester max 100 PROVE, winning bid 60 PROVE — [Succinct parameters](https://docs.succinct.xyz/docs/protocol/spn/parameters); [Succinct auction](https://docs.succinct.xyz/docs/protocol/spn/auction)
- Succinct FAQ example: 0.2 PROVE base fee for compressed mode; PROVE spot ~$0.19, market cap $37.8M (undated snapshot) — [Succinct FAQ](https://docs.succinct.xyz/docs/sp1/prover-network/faq); [The Block PROVE price](https://www.theblock.co/price/succinct)
- Boundless network update, 11 Jan 2026: median proving cost $0.04 per billion cycles, ~73% lower than at mainnet launch; capacity 400 trillion cycles/day; fully proving Base estimated ~$750,000/yr — [Boundless Foundation blog](https://boundlessfdn.org/blog/boundless-network-update)

### Inferences
- Under the RLN spec parameters, a minimum 20 msg/epoch membership costs $1.00 per 180 days and the maximum 600 msg/epoch costs $30.00 per 180 days (arithmetic on spec values; actual deployment price not verified).
- At 0.37 gwei (30-day avg) and $2,225 ETH, Automata's on-chain DCAP path (~4.5M gas) costs about $3.70 per attestation vs ~$0.41 for the ~500k-gas SNARK path, before proving fees (derived, not quoted).

### Gaps
- Linea RLN deployment price and tiers; Nym developer-credential status in 2026; Succinct/Boundless current per-proof USD; Tor CSV unit label not printed in the file itself.

## Q5. Deployment and per-operation gas references

### Takeaway
Measured references found: Groth16 verification ≈207.7k + 7.16k gas per public input (deployment gas not found); Safe creation via the web app ~263k–331k gas for 2–4 owners; Tornado deposit = 43,381 + 50,859 × depth (≈1.09M at depth 20), withdraw ~301k; Poseidon T3 ≈50–56k gas per 2-input hash vs MiMC ≈60k vs SHA256 precompile ≈23k and keccak ≈0.4k; incremental Merkle insert at depth 20 ≈768k (Poseidon) / 969k (MiMC), at depth 30 ≈1.11M / 1.41M. Zodiac Roles v2, Semaphore v4 and verifier deployment gas were not found.

### Cited Findings
- Groth16 verification gas ≈ 207,700 + 7,160 × l (l = public signals); pairing check 34,000 × k + 45,000 per EIP-1108 → 181,000 for k = 4 — [HackMD analysis](https://hackmd.io/Fa4A8lVKRM2TwVh1dhUb1Q)
- huff-snark-verifier: Solidity verifier ~207k gas with one input, Huff ~189k (experimental, unaudited) — [GitHub](https://github.com/whitenois3/huff-snark-verifier)
- HFIPay paper: Groth16/BN254 on-chain verify ≈241,000 gas (Foundry) — [arXiv 2603.26970](https://arxiv.org/pdf/2603.26970)
- Safe help center: "A Safe with 2 owners requires about 263k gas. A Safe with 3 owners requires about 309k gas. A Safe with 4 owners requires about 331k gas" (via web interface) — [Safe help: costs of creating a Safe](https://help.safe.global/en/articles/40853-costs-of-creating-a-safe)
- Safe docs: SafeProxy deployment saves gas vs full bytecode (no figure) — [Safe SafeProxy reference](https://docs.safe.global/reference-smart-account/deployment/SafeProxy)
- Zodiac modules deploy as minimal proxies via ZodiacModuleProxyFactory pointing at a mastercopy; Roles v2 "completely rewrote the module, applying significant gas optimizations" (no numbers) — [zodiac-core README](https://cdn.jsdelivr.net/npm/@gnosis-guild/zodiac-core@4.0.0-alpha.0/README.md); [Gnosis Guild Roles v2](https://gnosisguild.mirror.xyz/oQcy_c62huwNkFS0cMIxXwQzrfG0ESQax8EBc_tWwwk); [zodiac-modifier-roles repo](https://github.com/gnosis/zodiac-modifier-roles)
- tornado-core README: deposit gas 43381 + 50859 × tree_depth (→ 1,088,354 at depth 20); withdraw 301233 (an older revision lists 692133 and 888,054) — [tornado-core mirror](https://git.hackliberty.org/Git-Mirrors/tornado-core/commit/981325b1ff78cc17a418e2a2b983dabec1816623)
- "Pay Less for Your Privacy" (AFT 2023): Tornado Cash deposit on Ethereum ≈1.1M gas, mostly the Merkle-tree commitment insertion — [IACR ePrint 2023/1222](https://eprint.iacr.org/2023/1222.pdf)
- ethresear.ch benchmark (weijiekoh, 20 May 2020, circomlib on-chain hashers): per-hash gas MiMCSponge 59,840; Poseidon T3 49,858 (53,189 with circomlib v0.2.4, 55,543 with v0.5.1); Poseidon T6 (5 inputs) 109,166–125,425; SHA256 23,179. Insertion incl. 21k base: binary MiMC depth 10 528,298 / depth 20 969,498 / depth 30 1,410,634; binary Poseidon 427,238 / 767,565 / 1,107,895; quinary Poseidon depth 20 2,422,729 — [ethresear.ch](https://ethresear.ch/t/gas-and-circuit-constraint-benchmarks-of-binary-and-quinary-incremental-merkle-trees-using-the-poseidon-hash-function/7446)
- AMR paper: deposit ≈ 43,000 + 51,000 × h (MiMC) or 43,000 + 41,000 × h (Poseidon) — [arXiv 2010.01056](https://arxiv.org/pdf/2010.01056)
- Ethereum Magicians (2026): Poseidon 2-to-1 ≈14k–30k gas depending on optimizer ("Poseidon's 18,229"), Keccak-256 418 gas in the same benchmark — [Ethereum Magicians](https://ethereum-magicians.org/t/is-there-appetite-for-a-cheaper-on-chain-ao-hash-ashlar-14-232-gas-vs-poseidons-18-229/29315)
- Semaphore Noir report: SemaphoreNoir.verifyProof ~1.86–1.92M gas (depths 1–11); Semaphore.sol validateProof ~285.6k gas; a large UltraHonk verifier exceeded the 24 KB contract size limit — [HashCloak benchmarks](https://hashcloak.github.io/semaphore-noir-final-report/benchmarks.html); [HashCloak progress report](https://hashcloak.github.io/semaphore-noir-progress-report/print.html)
- Semaphore V4 docs publish a gas report only as an image (values unreadable); benchmarks run from semaphore-protocol/semaphore; `yarn test:report-gas` reproduces — [Semaphore benchmarks](https://docs.semaphore.pse.dev/benchmarks); [contracts README 4.9.2](https://unpkg.com/@semaphore-protocol/contracts@4.9.2/README.md)

### Inferences
- A depth-32 Poseidon insert is not benchmarked in the sources; extrapolating the cited ~41k gas/level slope from the depth-30 figure (1,107,895) gives ~1.19M gas, consistent with the 300k–1.2M range the task mentioned (derived, not measured).
- Groth16 verifier deployment gas (1.5–2.5M) remains unsupported by any located source and should be measured with `forge create`/hardhat-gas-reporter.

### Gaps
- Verifier, Zodiac Roles v2, Semaphore v4 and bare SafeProxyFactory deployment gas; MiMC/Poseidon library deployment gas.

## Q6. LLM subscriptions and IMD seat NFT floor

### Takeaway
Claude Pro is $20/mo ($17 annual), Max $100 (5x) and Ultra $200 (10x); ChatGPT Plus $20, Pro $100 (5x Codex) and $200 (20x Codex); the identitymd OpenSea floor is 0.75 ETH (≈$1,669) with 1,999 items and 792 owners on 8 Nov 2026.

### Cited Findings
- Claude: Free $0; Pro $17/mo annual ($200 billed up front) or $20 monthly; Max $100 (5x Pro usage); Ultra $200 (10x Pro usage); Team $20 standard seat annual / $25 monthly, premium $100/$125; Enterprise $20/seat annual, 20-seat minimum plus API-rate usage — [claude.com/pricing](https://claude.com/pricing)
- ChatGPT (TNW, 12 Apr 2026; openai.com pricing returned 403): Plus $20/mo; Pro $100/mo launched 9 Apr 2026 with 5x Plus Codex usage (10x promo through 31 May 2026); Pro $200/mo with 20x Codex and GPT-5.4 Pro access — [The Next Web](https://thenextweb.com/news/openais-new-100-chatgpt-pro-plan-targets-claude-max-with-five-times-the-codex-access)
- Tech-insider.org (Oct 2026) reports Claude Pro, ChatGPT Plus and Perplexity Pro at $20/mo; ChatGPT Plus monthly-only — [tech-insider.org](https://tech-insider.org/ie/chatgpt-plus-vs-claude-pro-vs-perplexity-pro-2026/)
- OpenSea identitymd: floor 0.74999999 ETH; total supply 1,999; owners 792; 24h volume $13,858.48; 7d volume $79,366.04; top offer not shown — [OpenSea identitymd](https://opensea.io/collection/identitymd)
- Cached OpenSea snapshots (undated) showed floor ~$470.78 and "0.02" (unit cut off); collection launched May 2026 with 2,000 items; each NFT = one seat in the AI swarm, one active device; 4.5% of trimmed IMD goes to NFT seats — [OpenSea explore (cached)](https://opensea.io/collection/identitymd/explore)

### Inferences
- 0.75 ETH × $2,225.29 ≈ $1,669 per seat at the time of the quote (arithmetic on two cited values).

### Gaps
- openai.com pricing page unreachable; Claude pricing naming ("Ultra" at $200) differs from third-party articles describing "Max 20x" at $200; use the claude.com page as authoritative for 8 Nov 2026.

## Q7. Comparable protocol run-rates and scale

### Takeaway
Railgun collects ~$66k/week and ~$317k/30-days in fees (all routed to its treasury; $14.1M all-time) on ~$79.5M TVL; Tornado Cash DAO treasury is ~$26.4M (all TORN) on ~$780M TVL; 0xbow raised $3.5M seed on 18 Nov 2025 with no disclosed burn; Railgun DAO treasury USD and relayer/broadcaster counts were not found.

### Cited Findings
- Railgun (DefiLlama fees API, 8 Nov 2026): total24h $8,092; total7d $66,270; total30d $316,717; totalAllTime $14,132,583; daily 2026-11-06 $4,607, 2026-11-07 $4,642, 2026-11-08 $8,092; fees = revenue ("All deductions paid by users ... are collected by Railgun treasury contracts"); 4.2% of treasury goes to the claiming mechanism every two weeks (up from 2% before 29 Jul 2026) — [DefiLlama fees API (revenue)](https://api.llama.fi/summary/fees/railgun?dataType=dailyRevenue); [DefiLlama fees API (fees)](https://api.llama.fi/summary/fees/railgun?dataType=dailyFees)
- Railgun TVL $79.5M (DefiLlama, search snippet) — [DefiLlama Railgun](https://defillama.com/protocol/railgun)
- Railgun broadcasters: paid in gas via notes matching advertised rate × estimated gas; anyone with a 0x address, a micro Node.js app and a Waku connection can run one; no count published — [Railgun docs: Community Relayers](https://docs.railgun.org/wiki/learn/privacy-system/community-relayers); Railgun moved to a dedicated RAILGUN Waku subtopic — [Railgun Medium](https://medium.com/@Railgun_Project/refactors-relayers-and-reliability-railgun-update-b78b84364a40); L2BEAT privacy page exists — [L2BEAT Railgun](https://l2beat.com/privacy/projects/railgun)
- Cambridge report (via Decrypt): Railgun now the most-used mixing protocol; Tornado Cash ~25% of 2025 transactions — [Decrypt](https://decrypt.co/es/359321/mezcladores-cripto-maximo-2022-railgun-tornado-cash-cambridge?amp=1)
- 0xbow $3.5M seed announced 18 Nov 2025, led by Starbloom Capital with Coinbase Ventures, BOOST VC, Status Research & Development; funds for expansion beyond mainnet and new features; pre-seed Mar 2024 with Vitalik Buterin — [The Block](https://www.theblock.co/post/379395/0xbow-raises-3-5-million-seed-round-ethereum-foundation-backed-privacy-pools); [The Defiant](https://thedefiant.io/news/defi/0xbow-raises-usd3-5-million-to-expand-privacy-pools); [GlobeNewswire via FinancialContent](https://markets.financialcontent.com/clarkebroadcasting.mymotherlode/article/gnwcq-2025-11-18-0xbow-closes-35m-round-for-compliant-crypto-privacy-technology-following-ethereum-foundation-integration)
- Tornado Cash treasury (DefiLlama API): totalLiquidityUSD $26,433,253 at unix 1794140231 (2026-11-08 12:17 UTC), entirely Ethereum-OwnTokens — [DefiLlama treasury API](https://api.llama.fi/treasury/tornado-cash); DefiLlama page snippet: treasury $32.56M ($32.54M own tokens), TVL ~$780.54M, TORN $5.65, 3.81M circulating of 10M — [DefiLlama Tornado Cash](https://defillama.com/protocol/tornado-cash); [DefiLlama TORN](https://defillama.com/token/torn)
- Tornado DAO original allocation 55% (5.5M TORN) vesting linearly over 5 years to 18 Dec 2025 — [Token Terminal vesting](https://bb-bugfix-table-csv.preview.tokenterminal.com/terminal/projects/tornado-cash/vesting-schedule); French report of ~$23M treasury and a malicious proposal, 25 Jun 2026 (unverified) — [Cryptoactu](https://cryptoactu.com/tornado-cash-dao-proposition-malveillante/)
- Tornado relayer registry: 300 TORN listing stake, 40 TORN minimum to stay active, 0.3% registry fee per withdrawal (dated docs); >75% of withdrawals via relayers (op-ed, undated) — [Tornado docs mirror](https://git.hackliberty.org/TornadoCash/docs/raw/branch/en/general/token/staking.md); [Nasdaq op-ed](https://www.nasdaq.com/articles/how-to-stop-illegal-activity-on-tornado-cash-without-using-sanctions)
- UZH study (arXiv 2510.09443v2, 13 Oct 2025) on post-sanction Tornado activity contains no relayer counts — [arXiv](https://arxiv.org/html/2510.09443v2)

### Inferences
- Railgun's 30-day fee take ($316.7k) annualises to ~$3.8M (arithmetic), i.e. roughly the size of 0xbow's entire seed round per year.
- The DefiLlama treasury API figure ($26.4M) and page snippet ($32.6M) differ because TORN price moved between snapshots; use the API timestamped value.

### Gaps
- Railgun DAO treasury USD (DefiLlama treasury endpoint too large to fetch; no other source); number of Railgun broadcasters; number of active Tornado relayers; 0xbow burn rate (not disclosed).
