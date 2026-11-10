# Railgun mainnet activity sample: how much relaying is there to do, and what does it pay? (v2)

Measured 10 Nov 2026, about 00:20 UTC. Read-only JSON-RPC against public endpoints (`https://rpc.mevblocker.io`, `https://rpc.flashbots.net`, `https://ethereum-rpc.publicnode.com`, rotated). No transaction was sent. This note exists because the 4 Nov spec priced the broadcaster mesh off Railgun's 0.25% protocol fee, which broadcasters do not receive (see `railgun_broadcaster_kohaku_v2.md`, section 5).

## Method

- `eth_getLogs` for every log emitted by the Railgun proxy `0xFA7093CDD9EE6932B4eb2c9e1cde7CE00B1FA4b9` over the last 21,600 blocks (3.0 days): blocks 26,359,282 to 26,380,882.
- Logs grouped by transaction hash; `eth_getTransactionReceipt` for every transaction (sender, `to`, `gasUsed`, `effectiveGasPrice`).
- A "spend" is a transaction that emits `Nullified(uint16,bytes32[])`, topic0 `0x781745c57906dc2f175fec80a9c691744c91c48a34a83672c41c2604774eb11f` (hash recomputed locally with Keccak-256). Spends are private transfers, unshields and RelayAdapt calls, the transactions a broadcaster exists to send. Shields are sent from the user's own public address and need no broadcaster.
- ETH price used for dollar figures: $2,130 (CoinGecko, 10 Nov 2026 00:13 UTC, from `ethereum_roadmap_v2.md`).

## Results

| Measure | Value |
|---|---|
| Transactions touching the Railgun proxy | 1,169 in 3.0 days, about 390 per day |
| Logs | 4,014 |
| Distinct sending addresses, all transactions | 279 |
| Spend transactions (`Nullified`) | 857, about 286 per day |
| Distinct senders of spends | 77 |
| Top 7 senders' share of spends | 690 of 857, 80.5% |
| Senders with 5 or more spends | 15 addresses, 760 spends, 88.7% |
| Gas used per spend | median 1,171,048; mean 1,217,511 |
| Effective gas price paid, spends | median 0.078 gwei; mean 0.216 gwei |
| Gas paid by the 15 repeat senders | 0.2171 ETH in 3 days, 0.0723 ETH per day, about $154 per day |
| All transactions: gas used | median 1,160,358; p10 753,390; p90 1,313,007 |
| All transactions: cost | median 0.000082 ETH ($0.18); mean 0.00027 ETH ($0.58) |

Top spend senders (count in 3 days): `0xccef06b2e82a184e34b118ed81f5ded120f8136c` 154; `0xc1d0dd9315d0f877cbca9ffa2f95e2b66f798fda` 139; `0x1f4ea7622197e0ee3a05aa93f351aff34a51befc` 100; `0xa38ef04abe070a33798e42114f289db5863f8fb5` 100; `0x9b2d5b96764bca81d448456d4a3a4017b71e3ae8` 77; `0x3859754554e57ce7099cb0da804e8fd19b8e6021` 62; `0x9be7bc1243a5a6967f52e3ea625f4de21d895809` 58. The next address has 12.

`to` address of spends: `0x0b8f88509466a28cd8bbdcf06131774f02af1cca` 327 (not identified here), the Railgun proxy itself 246, `0xe2e45ada2155bae566193777439ef8669d6e830d` 47, `0xac9f360ae85469b27aeddeafc579ef2d052ad405` 18.

## What the numbers mean

1. **Demand is small.** About 286 spends per day is one transaction every five minutes. A single broadcaster with a handful of gas wallets could carry all of it.
2. **Supply is already concentrated.** Seven sending addresses carry 80% of spends. That fits Railway Wallet's allowlist of four trusted fee signers, each of which may run several gas wallets (`railgun_broadcaster_kohaku_v2.md`, section 3). Which address belongs to which operator was not established.
3. **The whole market's margin is a few hundred dollars a month.** The broadcaster's quote works out to about 1.104 times the estimated gas cost, a margin of roughly 10% (`railgun_broadcaster_kohaku_v2.md`, section 6). Ten percent of 0.0723 ETH per day is about 0.0075 ETH per day, about $16 per day or about $480 per month, for every broadcaster on mainnet together. That is before the 0.25% unshield fee a broadcaster pays to turn shielded fee notes back into gas ETH, and before any gap between estimated and actual gas. At the 30-day mean base fee of 0.418 gwei the same arithmetic gives roughly $900 per month; at 2 gwei, roughly $4,000.
4. **A 100-seat mesh cannot be paid for by relay fees at current gas prices.** One hundred broadcasters each need at least 0.15 ETH per gas wallet (15 ETH, about $32,000 locked) to share a margin of about $480 per month, and they would only see traffic from wallets that list them.

## Limits

- Three days is a short window. It includes no day like 29 October 2026, when the base fee spiked to 253 gwei.
- "Repeat sender" is a proxy for "broadcaster". Some repeat senders may be bots or power users relaying for themselves, and some broadcasters may have sent fewer than five spends in the window.
- The 10% margin is the software default (`profitMargin: 0.15` with the price and gas buffers in the same file); operators can change it within the client's fee band.
- The contract at `0x0b8f…1cca` that received 327 of the spends was not identified.
- Layer 2 deployments of Railgun were not sampled.
