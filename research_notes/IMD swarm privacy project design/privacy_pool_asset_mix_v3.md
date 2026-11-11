# Which assets privacy pools hold, and stablecoin supply (v3 note, fetched 11 Nov 2026, about 00:15 UTC)

Question from the owner: are the stablecoins in the asset list needed, and do other protocols carry them?

Source: DefiLlama protocol API, Ethereum token breakdown (`tokensInUsd`, last entry dated 2026-11-10), and DefiLlama
stablecoins API. Plain GETs; nothing was sent to anyone.
- https://api.llama.fi/protocol/railgun
- https://api.llama.fi/protocol/tornado-cash
- https://api.llama.fi/protocol/privacy-pools
- https://stablecoins.llama.fi/stablecoins?includePrices=false

## Balances on Ethereum by asset

| Asset | Railgun ($103.4M) | Privacy Pools ($9.2M) | Tornado Cash ($664.3M) |
|---|---|---|---|
| ETH (WETH) | $42.47M, 41.1% | $1.45M, 15.7% | $649.95M, 97.8% |
| USDT | $32.66M, 31.6% | $6.60M, 71.7% | $0.04M |
| USDC | $17.42M, 16.8% | $0.38M, 4.1% | $0.03M |
| DAI | $5.02M, 4.9% | not in the top ten | $8.10M, 1.2% |
| USDS / sUSDS | $0.05M (sUSDS) | not in the top ten | none |
| WBTC | $2.60M, 2.5% | none | $6.15M, 0.9% |
| Other | NEAR $3.00M | Aave deposit tokens $0.63M, wstETH $0.07M, BOLD $0.05M | cDAI $0.03M |

- Stablecoins are 53.3% of Railgun's Ethereum balance (USDT + USDC + DAI) and about 76% of Privacy Pools' (USDT + USDC).
- USDT is the most-shielded stablecoin on both screened pools by a wide margin.
- Tornado Cash is almost all ETH. Its USDC was frozen by Circle in 2022 (earlier notes); DAI is the stablecoin that remains.

## Stablecoin supply

| Stablecoin | On Ethereum | All chains |
|---|---|---|
| USDT | $66.82B | $175.79B |
| USDC | $42.16B | $70.05B |
| USDS | $5.31B | $5.32B |
| DAI | $4.09B | $4.67B |

## Not verified here

- Token-contract behaviours of USDT (no return value on transfer, owner pause, blocklist, a fee switch that is off) and
  of USDS (upgradeable). These are stated from general knowledge and belong in the audit brief's assumptions; the
  contracts were not re-read for this note.
- DefiLlama's attribution of balances to protocols.
