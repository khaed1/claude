# Compute-pegged / compute-backed currencies and index-pegged token design patterns: prior art as of October 2026

Scope note: research conducted 2026-10-13 via web search and fetch of primary docs where available. Figures are dated inline. "Marketing claim" is flagged where the only source is the project itself. Several primary pages (Quai Qi tokenomics, Frax FPI overview, Reflexer "intro to reflex indexes", Hyperbolic PoSP deep-dive) returned 404/500 at fetch time; gaps are recorded per section.

---

## KQ1. Compute-backed or compute-pegged tokens: how each defines its unit, prices work, measures cost, and resists manipulation

### Takeaway
No production network in October 2026 pegs its token to a *compute* unit. The dominant pattern (Render, Helium, Akash, io.net) is the opposite: price work in **USD** via an external price oracle, burn the volatile native token at the oracle rate to mint a **non-transferable USD-denominated credit**, pay providers from a fixed emission schedule or by re-minting. Bittensor allocates emissions by **market price of subnet tokens** (speculative proxy for work), not measured work. Arweave and Filecoin price storage in native token with a hard-coded or market-set cost assumption, not a peg.

### Cited Findings

**Render (RENDER) — Burn-Mint Equilibrium (BME)**
- Render Foundation knowledge base: tasks "can now be priced in fiat currencies," users "pay in the equivalent amount of native RENDER token or fiat"; "Upon completion of work, creators pay for jobs by converting fiat to RENDER. The RENDER is subsequently burned in exchange for completion of the work." Emissions are "distributed on a predefined declining schedule"; epochs "typically spanning a week period"; schedule in RNP-001/RNP-003; RNP-006 Year-1 emissions 9,126,804 RENDER, RNP-018 Year-2 emissions 5,905,580 RENDER (page fetched 2026-10-13) — [Render Knowledge Base: BME](https://know.rendernetwork.com/basics/burn-mint-equilibrium)
- Secondary sources (2021-era Decrypt, exchange tokenomics pages) describe jobs priced in USD, creators burning RENDER equal to that price, non-transferable "Render Credits"/coupon tokens tracking completed jobs, and a 5% fee; the 5% fee attribution (network ops vs OTOY) is inconsistent across secondary sources and was not confirmed in primary docs — [Render basics](https://know.rendernetwork.com/basics); [Decrypt](https://decrypt.co/?p=120498); [MEXC tokenomics (low reliability)](https://www.mexc.com/price/RENDER/tokenomics)
- Unit: USD-priced job credits. Stable in USD, not in compute. Compute cost measurement: provider-set prices per job (OctaneBench-style tiers historically); the knowledge base page does not document the fiat/RENDER oracle. Node operator pay comes from the emission schedule, not directly from the burn — i.e., burn and mint are *decoupled* and only "equilibrate" in expectation — [Render Knowledge Base](https://know.rendernetwork.com/basics/burn-mint-equilibrium)

**Helium (HNT) — Data Credits (DC)**
- "One Data Credit equals $0.00001 USD." "At a network level, DCs are only generated through the conversion of HNT." "DCs are not transferable once created." Conversion uses the on-chain Pyth price feed. Mobile data costs $0.10/GB = 10,000 DC; IoT data billed in 24-byte increments. The page lists no explicit anti-manipulation measure beyond USD pegging (fetched 2026-10-13) — [Helium docs: Data Credit](https://docs.helium.com/tokens/data-credit)
- Oracle history: 2020 design used nine feed providers (incl. Helium Inc.) with median; later replaced by Pyth, whose aggregation "uses an exponentially weighted moving average, which smooths the price and reduces the effect of outliers" — [Helium price oracles](https://docs.helium.com/oracles/price-oracles); [2020 HNT Price Oracles devblog](https://docs.helium.com/devblog/2020/05/29/HNT-Price-Oracles)
- Supply response ("Net Emissions"): "DC is only produced by burning HNT"; design "intended to allow for the supply of HNT to respond to network usage trends." Net Emissions re-mint burned HNT up to a cap: daily cap 1,643.83561643 HNT (originally 34.24 HNT per 30-min epoch under HIP-20), "not affected by the two-year emissions halvings." Smoothing (HRP 2025-03, March 2025): target_today = yesterday_target × 6/7 + today_burn × 1/7; net_emissions_today = min(target, cap). Max supply 240,000,000 HNT (HIP-20); migration to Solana April 18, 2023 — [Helium docs: HNT token](https://docs.helium.com/tokens/hnt-token)
- Unit: USD-fixed DC. Stable in USD; the *quantity of service per DC* is set by governance (HIPs), not by a cost index.

**Akash (AKT) — AEP-23 stable payments → AEP-76 Burn-Mint Equilibrium with ACT**
- AEP-23 added stablecoin (USDC) pricing and settlement — [Akash AEP-23](https://akash.network/roadmap/aep-23/)
- AEP-76 (created 2025-09-21, Final, completed 2026-03-23, author Greg Osuri): stable payments "reduced demand for AKT, as the staking incentives proved insufficient to sustain the token's value"; "AKT's price instability compromises its utility as a payment mechanism." Introduces **ACT (Akash Compute Token)**: ~$1 peg, 6 decimals, non-transferable, tied to funding account, can only pay Akash lease invoices. Mint: AKT moved into a BME vault; ACT minted A = B × P_t at a **30-minute AKT/USD TWAP = median of Osmosis AKT/USDC TWAP (primary) and an external oracle (Pyth or Chainlink) (secondary)**, outliers beyond 1.5% from median ignored (another passage says 0.1%; inconsistent). Settlement burns invoiced ACT and pays providers AKT = A / P_settle, drawing first from vault "remint credits," minting only the shortfall; settlement per block or every five minutes. Unused ACT redeemable to AKT at current oracle price. Mint-side spread 0–25 bps (25 bps at launch), no per-lease take-rate. **Circuit breakers:** CR_warn at collateral ratio 0.95, CR_halt at 0.90 pauses new ACT mints. Worked example: $1,000 at $1.14 burns 877.19 AKT → 1,000 ACT; settle at $1.50 mints 666.67 AKT (net burn 210.53); settle at $0.90 mints 1,111.11 AKT (net +233.92) — [Akash AEP-76](https://akash.network/roadmap/aep-76/)
- Mainnet 17 activated BME and ACT on March 23, 2026 (secondary) — [Akash blog on BME](https://akash.network/blog/what-burn-mint-equilibrium-means-for-akash/)
- AEP-55 (draft) proposed a take-fee on USDC payments used to buy back and burn AKT via Osmosis — [Akash AEP-55](https://akash.network/roadmap/aep-55/)
- Unit: USD. Compute cost measured by reverse-auction provider bids per lease (market), not an index.

**io.net (IO) — Incentive Dynamic Engine (IDE)**
- Company claims (marketing): "at least 50% of post-payout network revenue in $IO is permanently burned"; "Supplier payouts are pegged to a stable USD value and buffered by reserves"; two counter-cyclical vaults; a CryptoEcon Lab review reportedly stress-tested a 55% demand drop and 50% token-price crash; 150 million $IO removed from circulation; payment in IO or USDC — [HackerNoon (io.net press)](https://hackernoon.com/ionet-launches-incentive-distribution-engine-ide-for-depins-long-term-growth-and-stability); [TradeInformer](https://www.tradeinformer.com/tech-news/io-net-token-burn-revenue-model); [madeonsol comparison](https://madeonsol.com/compare/aethir-vs-ionet)
- Unit: USD-stable payouts; same Helium/Render pattern.

**Aethir (ATH)** — only secondary comparison pages found; burn/deflation "TBA," revenue from enterprise ARR (a 2026 comparison page cites $147M ARR, unverified) — [madeonsol](https://madeonsol.com/compare/aethir-vs-ionet); [Renegades newsletter](https://therenegades-newsletter.beehiiv.com/p/aethir-vs-io-net)

**Nosana (NOS)** — GPU marketplace opened to the public January 14, 2025; pricing "dynamic and adjusts to market conditions," published in a USD price calculator on its site — [Nosana blog](https://nosana.io/blog/nosanas_gpu_marketplace_is_open_to_the_public); [QuickNode guide](https://www.quicknode.com/nl/builders-guide/tools/nosana)

**Gensyn** — a June 2026 comparison page says per-GPU-hour price is not clearly published and "expected to be market- or token-driven" — [Airframe comparison](https://www.airframe.ai/product/gensyn-ai/compare)

**Golem (GLM)** — pricing is per-task auction: "As a Requestor, you set a bid for an amount of GLM you are willing to pay"; providers "sell their computing power to the highest-bidding requester" — [CoinMarketCap Golem](https://coinmarketcap.com/currencies/golem). No USD or compute peg; GLM-denominated.

**Bittensor (TAO) — dTAO**
- dTAO whitepaper: emissions "derive[d] ... from the market prices of subnet-specific tokens that trade against TAO on Constant Product AMMs"; TAO divided among subnets "in proportion to their Alpha prices"; spot price p = τ/α; "all liquidity of Alpha and TAO tokens is provided by the emission process," no swap fees; Alpha split 41% validators / 41% miners / 18% subnet owners; the design treats "subnet tokens as being speculative instruments, such that their prices correlate with subnet performances"; "we do not discuss the consensus mechanism here" — [dTAO whitepaper](https://bittensor.com/dtao-whitepaper)
- Docs: subnet share proportional to EMA of alpha price (SubnetMovingPrice capped at 1.0); learnbittensor guide (updated Aug 2026) says as of June 2026 the network "reverted to a price-based model" after a period (Nov 2025 docs) using net TAO flows; Yuma Consensus converts validator weight matrices into per-neuron emission shares; global TAO weight 0.18; up to 128 validator permits — [Bittensor emissions docs](https://www.bittensor.com/docs/concepts/emissions); [learnbittensor emissions (Aug 2026)](https://guides.learnbittensor.org/learn/emissions); [learnbittensor (Nov 2025)](https://docs.learnbittensor.org/learn/emissions)
- Unit: TAO/alpha, floating. Work is measured by **validators' subjective scoring** (Yuma consensus), not an objective cost index; emission allocation is **market-price-driven**.

**Arweave (AR) — storage endowment**
- Secondary/ecosystem sources: the endowment model assumes storage cost declines only 0.5%/yr, versus historical ~30.5% (or ~38%) annual decline; endowment stays solvent "indefinitely" at 0.5%; Irys cites Arweave simulations of ≥10,000 years. HackMD analysis attributes the structure to yellow paper §3.2.2 (2019 draft) — [ArDrive](https://ardrive.io/articles/can-data-really-be-stored-forever/); [permaweb-journal: storage endowment](https://permaweb-journal.ar.io/reference/storage-endowment.html); [permaweb-journal: explained](https://permaweb-journal.ar.io/article/storage-endowment-explained.html); [HackMD analysis](https://hackmd.io/@YTnQkIXiSgyoU2Gnfq6BGg/ry5zORx7j); [Irys docs](https://docs.irys.xyz/overview/permanent-data)
- Pattern: not a peg; a **conservative hard-coded cost-decline assumption** inside a one-time-payment model. Relevant to any compute peg because it shows how to be robust to an unknown deflation rate (assume the slowest plausible decline).

**Filecoin (FIL)**
- Providers set asks in FIL per GiB per epoch (epoch ≈ 30s; Lotus example 0.0000001 FIL/GiB/epoch); portion of gas burned (f099 burn address); some demo providers quote in USDFC stablecoin — [Filecoin docs: FIL collateral](https://docs.filecoin.io/storage-providers/filecoin-economics/fil-collateral); [fitgap summary citing Lotus docs](https://us.fitgap.com/products/037071/filecoin)
- Pattern: FIL-denominated market pricing, no peg.

### Inferences
- Every live "compute network" with stable pricing converges on the **Helium pattern**: external USD oracle → burn volatile token → non-transferable USD credit → spend credit on work. Non-transferability is the anti-manipulation device: credits cannot be arbitraged on exchanges, so the oracle only has to be honest at mint/settle time and the 30-min TWAP/median-of-two-sources (Akash) limits short-term manipulation.
- Akash AEP-76 is the most fully specified 2026 design (oracle construction, outlier rejection, remint-vault, collateral-ratio circuit breakers) and is the closest template for an agent network's "compute credit."
- None of these measure *compute cost* endogenously; they all import the **USD** as the unit and let provider bids/governance set the compute-per-dollar rate. A true "compute dollar" would invert this: hold compute-per-unit fixed and let USD float.
- Bittensor demonstrates the failure mode of letting market price (speculation) stand in for measured work: emission allocation swung between price-based and flow-based models within one year (Nov 2025 to Jun 2026).

### Gaps
- Could not retrieve the primary RNP-001 text (hosted on GitHub rndr-network/RNPs); fiat→RENDER oracle and exact 5% fee recipient unverified.
- No primary data on Golem GLM per-hour prices, iExec RLC PoCo payment mechanics, Gensyn or Nosana token-economic specifics; search returned only aggregator pages.
- Arweave yellow paper §3.2.2 original wording not fetched (arweave.org/yellow-paper.pdf).
- Filecoin base-fee burn rules and a current FIL/TiB price not confirmed from official docs.

---

## KQ2. "Compute dollar" and AI-inference-indexed proposals; GPU-hour and inference price indices; measured inference price decline 2023–2026

### Takeaway
As of October 2026 there is **no live token pegged to a GPU-hour or to a fixed quantity of inference tokens**; the only "AI dollar" (USDai) is a plain PYUSD-backed dollar whose *yield* comes from GPU-collateralised loans. What has emerged instead is the **financial plumbing** for such a peg: a daily Bloomberg-listed H100 rental index (SDH100RT, since May 20, 2025) and CME/NYMEX cash-settled compute futures on it (announced for Oct 5, 2026, pending CFTC review). Inference prices at fixed capability fell roughly 10× per year (a16z) to 9×–900×/yr (Epoch), which makes a fixed-inference-quantity peg a violently deflationary unit of account.

### Cited Findings

**USD.AI / USDai (Permian Labs)**
- Official docs: USDai is a "fully-backed synthetic dollar collateralized by PYUSD," redeemable at any time, non-yielding. sUSDai is the staked yield token earning "interest paid by GPU borrowers on active loans" and T-bill yield on idle reserves; GPU loans are non-recourse, "secured by the operator's GPU fleet and its cashflows," with "springing recourse to the operator's corporate entity" on fraud (fetched 2026-10-13) — [USD.AI docs](https://docs.usd.ai/)
- Secondary: hardware tokenised via "CALIBER" standard (NFTs representing ownership/cashflows); $13M Series A led by Framework; Bullish $100M stablecoin debt facility announced 2026-08-28; >$100M active loans; yields reported variously 7.26%–25% (inconsistent); GPU depreciation estimated 15–20%/yr; a commentator argues GPU-backed stables "look very much like traditional securities under the Howey test" — [Munich Startup Insights](https://insights.munich-startup.de/news/feed/usd-ai-surpasses-100m-in-gpu-collateralized-stablecoin-loans-with-record-34m-deal); [Cryptometer](https://www.cryptometer.io/news/usd-ai-bridges-crypto-and-ai-stablecoins-now-fund-nvidia-gpu-loans/); [Parsec Weekly #129](https://parsec.substack.com/p/parsec-weekly-129); [Lex Sokolin Substack](https://lex.substack.com/p/ai-gpu-backed-stablecoins-blend-ai)
- Verdict: **USD-pegged, GPU-*collateralised* for yield**, not compute-pegged.

**Silicon Data H100 Rental Index (SDH100RT)**
- Launched May 20, 2025; Bloomberg ticker SDH100RT; "3.5 million global pricing data points from a variety of rental platforms"; methodology "standardizes a wide range of H100 GPU configurations" (GPU subtype, geolocation, platform conditions); distribution via Kaiko — [Silicon Data launch release](https://www.silicondata.com/news-room/silicon-data-launches-world-s-first-daily-gpu-rental-index-to-bring-transparency-to-the-ai-infrastructure-economy-copy)
- "Building a Robust GPU Index" (Carmen Li, 2026-03-12): ~150k verified daily pricing records from 50–100 platforms (hyperscalers, neoclouds, marketplaces), 40–50 countries; lease types On-Demand, Spot, Reserved (1–60 months) *not blended directly*; data from Sep 1, 2024; "proprietary framework to normalize the prices of heterogeneous physical units to a standard configuration"; tickers SDH100RT, SDA100RT, SDB200RT. Weighting, outlier handling and manipulation resistance **not disclosed** on the page — [Silicon Data methodology blog](https://www.silicondata.com/blog/building-a-robust-gpu-index)
- Product page: each record converted to per-GPU-hour, basis-adjusted for rental type, geography, CPU platform, GPU variant; weighted average across providers; USD per GPU-hour; neo-cloud reading carries SDH100RT, hyperscaler series separate — [Silicon Index H100](https://www.silicondata.com/products/silicon-index/h100)
- Levels: Aug 2025 range $2.22–$2.26 with ~1.7% volatility, mid-Sep 2025 low $2.13; third party: $2.00 (2025-12-09) → $2.20 (2026-01-06) — [Silicon Data Sept 2025 update](https://www.silicondata.com/blog/h100-rental-market-update-september-2025); [Xenospectrum](https://xenospectrum.com/en/nvidia-gpu-rental-depreciation/)
- Dispersion problem: same H100 rents for $1.79 to $10/hr across 13 providers; "network setup, location, and power reliability are not reflected in the label" — [Social Capital brief on compute financialization](https://thebrief.socialcapital.com/briefs/compute-financialization)

**CME Group compute futures**
- Announced 2026-08-11: Silicon Data H100 Rental Index Futures and B200 Rental Index Futures to list on NYMEX on October 5, 2026, pending CFTC review; each contract = one month of hourly GPU rent, cash-settled — [Finance Magnates](https://www.financemagnates.com/institutional-forex/cme-group-says-it-will-launch-first-regulated-compute-futures-contracts/); [CME press PDF](https://cmegroupinc.gcs-web.com/node/55686/pdf); [Simply Wall St](https://simplywall.st/stocks/us/diversified-financials/nasdaq-cme/cme-group/news/cme-group-cme-sets-october-5-2026-debut-for-compute-futures)
- As of 2026-10-13 I found **no post-launch confirmation** that trading began or CFTC approval was granted — gap.
- Ornn also publishes GPU indices on Bloomberg (per Social Capital brief) — [Social Capital brief](https://thebrief.socialcapital.com/briefs/compute-financialization)

**Inference price indices and decline rates**
- a16z "LLMflation" (Guido Appenzeller, 2024-11-12): "For an LLM of equivalent performance, the cost is decreasing by 10x every year"; MMLU-42 level fell ~1,000× in three years from $60 to $0.06 per 1M tokens (since GPT-3, Nov 2021); faster than PC-era compute or dotcom bandwidth deflation — [a16z LLMflation](https://a16z.com/llmflation-llm-inference-cost/)
- Epoch AI (Cottier, Snodin, Owen, Adamczewski, 2025-03-12): price to reach GPT-4-level on GPQA Diamond fell "40x per year"; across six benchmarks (MMLU, GPQA Diamond, MATH-500, MATH 5, HumanEval, Chatbot Arena) the decline ranges **9× to 900× per year**; data to Feb 2025; "the fastest price drops ... have occurred in the past year, so it's less clear that those will persist"; method: log-linear regression on lowest-priced model meeting a milestone, using Epoch + Artificial Analysis price data — [Epoch AI data insight](https://epoch.ai/data-insights/llm-inference-price-trends); [Epoch blog](https://epoch.ai/blog/llm-inference-price-trends)
- Conflicting lower estimate: NeurIPS 2025 workshop paper "The Price of Progress" estimates ~5×–10×/yr for frontier models on knowledge/reasoning/math/SWE benchmarks, with ~3×/yr attributable to algorithmic efficiency after controlling for hardware and competition — [arXiv 2511.23455](https://arxiv.org/html/2511.23455v1)
- Stanford AI Index 2025 (cited secondhand): ~280× drop in cost of GPT-3.5-level performance Nov 2022–Oct 2024 — [Sesamedisk (secondary)](https://sesamedisk.com/ai-inference-cost-trends-2026-3/)
- Artificial Analysis publishes "cost to run" its Intelligence Index (nine evals) folding in input/output/reasoning tokens — cost-per-task, not a time-series price index (secondary) — [letsdatascience](https://letsdatascience.com/news/ai-inference-pricing-faces-a-volume-reckoning-f4c9f706)
- OpenRouter publishes token-volume rankings; secondary claim of 25T tokens/week in May 2026 (unverified) — [Sesamedisk (secondary)](https://sesamedisk.com/ai-inference-cost-trends-2026-3/)
- No primary OpenRouter or Artificial Analysis *price index* time series found — gap.

**Per-token vs per-GPU-hour conversion (the unit problem)**
- cost per 1M tokens = cluster $/hr ÷ (tokens/sec × 3,600 ÷ 1,000,000); idle time must be amortised (40% utilisation example) — [Spheron](https://www.spheron.network/blog/cost-per-million-tokens/); same formula — [GMI Cloud](https://www.gmicloud.ai/ja/blog/gpu-price-performance-formula-inference)
- Per-token pricing puts utilisation risk on the provider; per-GPU-hour leaves it with the buyer — [Lyceum](https://lyceum.technology/magazine/per-token-vs-per-gpu-hour-which-inference/)
- Academic: token cost = GPU-seconds per token × hourly rental rate — [arXiv 2506.04645](https://arxiv.org/pdf/2506.04645)
- Critique: "A GPU-hour is a fake commodity" — proposes workload-specific units (tokens/sec for a specified model and latency budget) — [Medium essay](https://medium.com/@Elongated_musk/a-gpu-hour-is-a-fake-commodity-8781e6b43c86); Tim Davis argues the currency of AI is tokens, not GPU-hours — [timdavis.com](https://www.timdavis.com/blog/the-token-curve)
- Nvidia (GTC 2026) reframed metrics around tokens per watt (secondary) — [Spheron token factory](https://www.spheron.network/blog/token-factory-gpu-cloud-tokens-per-watt-guide/)

**Proposals to peg a token to "1M tokens of inference" or "one GPU-hour"**
- Searches for such a proposal returned none from any project or research firm; the closest is 0G's "compute finance" essay arguing the de-facto unit of account at the bottom of the AI stack is the **prepaid credit**, which is "contractually non-transferable, confers no property right, and often expires," and proposing "compute yield" (stakers paid in compute) with Venice as an early example — [0G: Compute Finance](https://0g.ai/blog/compute-finance)
- "The Economics of Proof-of-Useful-Work" (arXiv, June 2026) is the nearest academic treatment of useful-compute as block reward basis — [arXiv 2606.06700](https://arxiv.org/pdf/2606.06700) (not read in depth; title/abstract only)

### Inferences
- **Why the decline rate matters for a peg:** if a unit is defined as "1M tokens at GPT-4-class quality," its USD value falls ~10×/yr (a16z) to 40×/yr (Epoch GPQA) — i.e., the "compute dollar" would be a hyper-deflationary unit in USD terms (holding it = shorting AI progress). Conversely a unit defined as "one H100-hour" is far more stable (SDH100RT moved ~$2.00–$2.26 over Aug 2025–Jan 2026, ~1.7% monthly vol) but silently loses *capability* as newer chips arrive; both Arweave's 0.5% assumption and index-rebasing (Ampleforth/FPI) are the two known mitigations.
- A GPU-hour index needs heavy basis adjustment (rental type, geography, variant, hyperscaler vs neocloud) and even then exhibits 5× dispersion across providers — any on-chain oracle of "compute cost" inherits this ambiguity.
- The existence of a Bloomberg-listed index + regulated futures makes an **externally-oracled** compute-indexed token technically feasible in 2026 (Chainlink/Pyth could carry SDH100RT), but it would be a trusted-feed design, not endogenous.

### Gaps
- No post-Oct-5-2026 confirmation of CME compute futures trading.
- No 2025–2026 Epoch update quantifying whether the decline slowed; Epoch's own page warns the 2024 pace may not persist.
- No primary source found for any "inference-token-pegged" currency proposal; this appears to be genuinely novel ground.
- Silicon Data's weighting/outlier/manipulation methodology is proprietary and undisclosed.

---

## KQ3. Index-pegged token design patterns (Ampleforth, RAI, FPI, Nuon, SPOT, Terra, MakerDAO PSM, Helium BME, Quai) — which need an oracle, which are endogenous

### Takeaway
Every index-pegged design in production relies on an **external oracle** for the index (CPI via Chainlink/Truflation; USD price via Pyth/Chainlink/DEX TWAP). The only endogenous design identified is Quai's Qi, which uses proof-of-work difficulty/miner reward choice as the signal, but its primary documentation could not be fetched and secondary descriptions are inconsistent. Terra shows that a two-token mint/burn controller without exogenous collateral or a hard supply cap is reflexive and can hyperinflate the backing token.

### Cited Findings

**Ampleforth (AMPL) — supply rebase to CPI-adjusted dollar**
- Target = one 2019 US dollar adjusted by CPI; "the protocol does not intervene in markets"; rebase daily at 02:00 UTC only if deviation > threshold (5%); CPI supplied monthly via Chainlink — [Chainlink case study](https://chain.link/case-studies/ampleforth); [MixBytes security of algorithmic stablecoins](https://www.mixbytes.io/blog/security-of-algorithmic-stablecoins)
- Oracle: **external** (Chainlink CPI + market price). Pattern: supply rebase (unit-of-account changes, holder balance changes).

**SPOT (Ampleforth)** — "an algorithmic stablecoin collateralized by AMPL zero-coupon bonds" via tranching; CEO: "SPOT is a different kind of stablecoin that isn't pegged to anything," value tends toward CPI-adjusted dollar — [The Block](https://www.theblock.co/post/193230/ampleforth-developer-debuts-ethereum-based-inflation-resistant-token)

**Nuon** — Arbitrum "flatcoin" anchored to inflation, CPI feed from Truflation; current status not confirmed — [Transak flatcoin explainer](https://transak.com/blog/what-is-flatcoin-crypto)

**Frax Price Index (FPI)** — "The system will adjust every month according to an on-chain Consumer Price Index oracle so that holders of the FPI will increase their dollar-denominated value each month according to the reported CPI increase" — [Frax design analysis (Korean)](https://wikidocs.net/326781). FRAX itself used a PID controller on the collateral ratio with a "Growth Ratio" (FXS supply vs FRAX supply) as process variable, CR stepped 0.25% when FRAX > $1.01 or < $0.99 — [Incentivized Substack](https://incentivized.substack.com/p/how-to-print-money-without-printing). Primary FPI docs page 404'd — gap.

**RAI (Reflexer) — floating redemption price + PI(D) controller**
- "The redemption price almost always floats and it does not target any specific peg." "When RAI's market price > redemption price for a sustained period of time, the redemption rate will become negative" (and vice versa); redemption rate changes redemption price every second; controller bounded ("the OracleRelayer will have upper and lower bounds for the redemption rate"); fed by "market price data" (TWAP suggested); warnings: "If the controller is too slow it may be completely ineffective," and it "should not be set to its full force right when RAI is launched" — [Reflexer docs (llms-full)](https://docs.reflexer.finance/llms-full.txt)
- Also described as "a fork of DAI, an ETH backed stable-ish coin that uses an onchain PI controller to set interest rates automatically and emphasizes 'ungovernance'" (launched Feb 2020 per source; Reflexer mainnet actually Feb 2021 — source date may be off) — [Incentivized Substack](https://incentivized.substack.com/p/how-to-print-money-without-printing)
- Oracle: external (ETH/USD + RAI market price). Pattern: **controller adjusts the target itself** rather than supply.

**Terra UST/LUNA — two-token seigniorage**
- UST always redeemable for $1 of LUNA; arbitrageurs burn UST to mint LUNA or reverse; "the system had no outside asset to support the peg." Death spiral May 2022: burn UST → mint & sell LUNA → LUNA price falls → more UST exits; Anchor held ~75% of UST supply; Curve pool liquidity drained May 7; LUNA supply ~343M (May 8) → ~32.3B (May 12) after mint cap raised; ~$40B wiped — [arXiv 2207.13914](https://arxiv.org/pdf/2207.13914.pdf); [Decrypt](https://decrypt.co/100402/how-terra-ust-luna-imploded-crypto-crash?amp=1)
- Lesson for compute credits: Akash AEP-76 explicitly addresses this with a **vault of previously-burned AKT ("remint credits"), collateral-ratio circuit breakers (0.95 warn / 0.90 halt), and non-transferable credits** — [Akash AEP-76](https://akash.network/roadmap/aep-76/)

**Helium burn-and-mint with oracle** — see KQ1; USD oracle (Pyth EWMA), capped net emissions, 7-day smoothing — [Helium HNT docs](https://docs.helium.com/tokens/hnt-token)

**Quai Network — Qi "energy dollar" (endogenous candidate)**
- Secondary: Qi "gets its stability based on the constant principle of energy costs. PoW mining serves as an oracle for energy prices"; Quai marketing calls it "the first decentralized energy dollar"; altss profile says Qi is "not dollar-pegged but energy-anchored ... a flatcoin," and that the QUAI–QI conversion "adjusts every 4,000-block window via logistic regression with a cubic discount function penalizing arbitrage at scale," running "without oracles, DAO votes, or market makers" (single uncorroborated source); consensus is Proof-of-Entropy-Minima — [thecoding Substack](https://thecoding.substack.com/p/quai-network-entropy-energy-cash); [altss profile](https://altss.com/profile/quai-network); [Bitrue explainer](https://www.bitrue.com/blog/what-is-quai-network-everything-you-need-to-know-quai-coin)
- Primary docs at docs.qu.ai returned 404 on the two paths tried — **gap; must be verified from Quai's official docs/whitepaper**.

**MakerDAO PSM** — not researched in this pass (no tool budget remaining); well-known 1:1 USDC↔DAI swap module with fee; requires exogenous stablecoin, not an index — gap.

### Inferences
- Taxonomy of enforcement mechanisms found:
  1. **Supply rebase** (Ampleforth, FPI): oracle → change balances; no redemption; relies on market arbitrage to price the new supply.
  2. **Floating target with controller** (RAI): oracle → PI controller moves the redemption price/rate; no hard peg.
  3. **Burn-to-credit** (Helium, Render, Akash, io.net): oracle → burn volatile token → non-transferable fixed-USD credit redeemable only in *work*; peg enforced because the credit is only ever spent inside the network at a governance-set work price.
  4. **Two-token seigniorage** (Terra): no oracle beyond market price; failed because the backing token had no floor and no mint cap.
  5. **Endogenous PoW signal** (Quai Qi, per secondary sources): mining difficulty/miner token choice as the measurement of energy cost; no external oracle.
- For an agent network like IMD, patterns 3 + 5 are the transplantable ones: pattern 3 is proven in production (Helium since 2019; Akash since Mar 2026) but imports USD; pattern 5 is the only one that measures the network's *own* cost of work, but it has no AI-inference analogue to difficulty yet (see KQ4).
- Akash's vault + collateral-ratio breaker is a direct engineering answer to Terra's reflexivity and should be considered a baseline requirement for any mint/burn credit.

### Gaps
- Quai Qi conversion formula, adjustment window and "k Quai" units: primary documentation not retrieved.
- FPI primary mechanics (FPIS backing, AMO yield, under-inflation case) not retrieved.
- Current (2026) status of Nuon, SPOT, AMPL and RAI not verified.
- MakerDAO PSM not researched.

---

## KQ4. The oracle problem: can a network measure its own cost of AI work without a trusted key? Status of verifiable inference in 2026

### Takeaway
Proof-of-work difficulty is an objective, oracle-free measure because every node can verify the hash. No equivalent exists yet for AI inference: zkML proofs for 70B-class models still take hours to weeks; opML and sampling-based schemes (Hyperbolic PoSP, used by EigenLayer) are production-practical but give *probabilistic* correctness and tell you the result is right, not what it cost; GPU TEEs (H100/H200/B200 CC mode on Phala Cloud) are in production with <5% overhead but require trusting Nvidia/Intel/AMD root-of-trust. None of these yields a trustless *cost* measurement.

### Cited Findings
- Landscape: verification routes are ZKPs, TEEs, hashing, optimistic verification, random sampling; zkML "needs no trust in hardware makers"; Proof of Sampling and SVIP-style hashing "are the main industry approaches for decentralized inference" — [Equilibrium: State of Verifiable Inference](https://equilibrium.co/writing/state-of-verifiable-inference)
- zkML cost: "a single 70B-parameter inference proof currently takes hours" and proving cost grows super-linearly; Optimistic TEE-Rollups paper claims (simulated H100) 1400× speedup over zkML and 99% latency reduction vs opML — [arXiv 2512.20176](https://arxiv.org/pdf/2512.20176)
- Proof of Sampling paper (Berkeley/Columbia, 2024): zkML proof for a 1M-param nanoGPT ≈ 16 minutes; Llama2-70B "days or weeks"; concludes zkML impractical for decentralized inference networks at scale — [arXiv 2405.00295](https://arxiv.org/pdf/2405.00295)
- opML (Hyper Oracle/ORA, Jan 2024): optimistic fraud-proof approach for ML on chain — [arXiv 2401.17555](https://arxiv.org/pdf/2401.17555)
- zk-OPML hybrid (2026, Springer): ZKPs for selected ONNX operators inside an optimistic dispute game — [Springer](https://link.springer.com/article/10.1007/s44443-026-00573-1)
- "Seal, Then Sample" (Sept 2026): sampled layerwise proofs GPT-2 to 70B; authors state numbers used test parameters, no trusted setup, no ZK claim — [arXiv 2609.27367](https://arxiv.org/pdf/2609.27367)
- Attack literature: "Hollow-LLM Attack: Computationally Trivial Weights in Zero-Knowledge Verification of LLM Inference" (July 2026) — [arXiv 2607.28884](https://arxiv.org/pdf/2607.28884) (title-level only)
- Hyperbolic PoSP (announced May 2024): Asserter commits result; Orchestrator (random beacon) decides whether to sample validators to recompute; Nash-equilibrium argument that honesty is dominant given penalties; claimed <1% overhead; "best practices can raise inference costs by as much as 300%"; EigenLayer integrated PoSP; developed with UC Berkeley and Columbia researchers (all company sources) — [Hyperbolic announcement](https://hyperbolic.xyz/blog/hyperbolic-introduces-novel-practical-solution-to-the-problem-of-verification-in-decentralized-ai); [Hyperbolic × EigenLayer](https://hyperbolic.xyz/blog/eigen-layer-leverages-proof-of-sampling-by-hyperbolic); [EigenCloud blog](https://blog.eigencloud.xyz)
- GPU TEE production: Phala Cloud offers dedicated H100/H200/B200 (marketplace lists B300) in TEEs with CPU+GPU dual attestation, Nvidia local verification tools, public Trust Center; benchmark (co-authored by Phala staff) finds overhead "below 5% for most typical LLM queries," mostly PCIe transfer; H100 described as first production-grade GPU with CC mode/on-die root of trust — [Phala GPU TEE launch](https://phala.com/posts/gpu-tee-is-launched-on-phala-cloud-for-confidential-ai); [Phala deploy & verify docs](https://docs.phala.com/phala-cloud/confidential-ai/confidential-gpu/deploy-and-verify); [arXiv 2409.03992 benchmark](https://arxiv.org/html/2409.03992v2); [Phala GPU TEE marketplace](https://phala.com/nl/gpu-tee)
- Bittensor: work is scored subjectively by validators (Yuma consensus) and emissions are allocated by alpha-token EMA price — [dTAO whitepaper](https://bittensor.com/dtao-whitepaper); [Bittensor emissions docs](https://www.bittensor.com/docs/concepts/emissions)
- Quai (secondary): PoW mining "serves as an oracle for energy prices" — [thecoding Substack](https://thecoding.substack.com/p/quai-network-entropy-energy-cash)

### Inferences
- **Correctness ≠ cost.** All 2026 verifiable-inference schemes attest that an output is right (or probably right). None attest *how much it cost to produce*, which is what a cost-indexed unit needs. The only quantity analogous to PoW difficulty would be something like "verified FLOPs/joules consumed," which TEE attestation can report (hardware counters inside an attested enclave) but only under hardware-vendor trust.
- Practical 2026 production stack for an agent network: TEE attestation (Phala/Nvidia CC) for per-job metering + PoSP-style random re-execution for correctness + staking penalties; zkML remains research-stage for LLM scale.
- An **endogenous** cost signal for inference (Quai-style) would have to come from agents' *revealed choices* (e.g., which of two reward assets workers elect to be paid in, as Quai miners choose Quai vs Qi) rather than from measurement; this is the only oracle-free pattern found and it is unproven at scale (Quai mainnet is young and its docs were unreachable).
- Bittensor's experience (validator scoring gamed; emissions ultimately allocated by speculative price) is the cautionary case for subjective work measurement.

### Gaps
- Could not fetch Hyperbolic's PoSP deep-dive (HTTP 500) for the penalty/stake formula and production dates.
- No independent audit or benchmark of PoSP found; all claims are Hyperbolic's.
- Did not locate 2026 primary material from EZKL, Modulus, Ritual, or ORA on production deployments; Equilibrium's overview is the closest survey.
- No source found describing a TEE-based *cost metering* (FLOP/energy counter attestation) product.

---

## KQ5. Academic and industry writing on "compute as money" / inference-backed currency

### Takeaway
The idea exists mainly as remarks and essays, not as designs: Sam Altman's 2023 "compute is going to be the currency of the future" and 2024 "universal basic compute" (a slice of GPT-7), 0G's 2026 "compute finance" essay, Social Capital's compute-financialization brief, and critiques arguing the GPU-hour is a "fake commodity." I found **no** essay from a16z crypto, Paradigm, Delphi, Messari or Multicoin proposing a compute-pegged unit of account; a16z's LLMflation essay is about price deflation, not money.

### Cited Findings
- Altman, Lex Fridman Podcast (2023): "compute is going to be the currency of the future" and "maybe the most precious commodity in the world" — [sebdg summary](https://sebdg-ai-cookbook.hf.space/blog/posts/ai-compute-commodity.html)
- Altman, All-In Podcast (2024): "universal basic compute" — everybody gets "a slice of GPT-7's compute" to use, resell or donate; owning a share of productivity "could be worth more than money" — [Basic Income Canada](https://basicincomecanada.org/openais-sam-altman-has-a-new-idea-for-a-universal-basic-income/); [Cointelegraph](https://cointelegraph.com/news/sam-altman-slice-gpt-pay-ubi-artificial-intelligence)
- Critique: UBC amounts to "universal access to his product" / dependency on OpenAI — [Sadat Substack](https://sadat.substack.com/p/universal-basic-compute)
- Unverified: 2026 Reddit snapshot quoting Business Insider/The Atlantic that Altman "no longer believe[s] in universal basic income as much" — [Reddit snapshot (low reliability)](https://reddit.sentinel-team.org/posts/1t14fpg/snapshots/2026-05-08T18%3A51%3A06.49578Z)
- 0G "Compute Finance" (2026): compute lacks a financial layer; unit of account is the prepaid credit (non-transferable, no property right, expires); proposes compute yield; notes "one hour of compute is not another" — [0G blog](https://0g.ai/blog/compute-finance)
- Social Capital brief: Silicon Data and Ornn indices on Bloomberg; first futures Oct 5, 2026; H100 price dispersion $1.79–$10/hr — [Social Capital](https://thebrief.socialcapital.com/briefs/compute-financialization)
- Promotional/speculative: FourWeekMBA "Compute-as-Currency: When GPU Hours Become the New Global Money" (unsourced stats) — [FourWeekMBA](https://fourweekmba.com/compute-as-currency-when-gpu-hours-become-the-new-global-money/); Observer Theory essay testing "currency of intelligence" against the three functions of money — [Observer Theory](https://observertheory.substack.com/p/when-compute-becomes-currency-ethics)
- Academic: "The Economics of Proof-of-Useful-Work" (June 2026) — [arXiv 2606.06700](https://arxiv.org/pdf/2606.06700); "Money as a computational machine" (Cambridge) — [Cambridge PDF](https://www.cambridge.org/core/services/aop-cambridge-core/content/view/67B0F08B89B77178AC6A761B5D6E057D/S2059599900001199a.pdf/money-as-a-computational-machine.pdf)

### Inferences
- The intellectual lineage is "compute as commodity/UBI" (Altman) → "compute as collateral" (USD.AI) → "compute as indexed derivative" (Silicon Data/CME). The step to "compute as unit of account with an endogenous peg" has not been taken by any credible actor identified; IMD would be first-of-kind, and should expect the two objections every source raises: non-fungibility of compute (which GPU, where, what SLA) and hyper-deflation of capability-defined units.

### Gaps
- No a16z crypto / Paradigm / Delphi / Messari / Multicoin / Galaxy / Variant essay on compute-pegged money located; searching those firms' sites directly was not done within tool budget.
- Worldcoin-adjacent proposals not researched.
- Altman's exact Lex Fridman transcript not fetched; quote is via a secondary summary.
