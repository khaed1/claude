# PLEA raw-log indexer (reference)

The table the site's history adapter (`plea-site` `web/src/indexer.ts`) reads: every event of PLEA's eight contracts, raw, in one Ponder table `rawLog`, served over GraphQL at `/graphql` with CORS open.

```sh
npm install
node gen.mjs <khaed1/plea mainnet build>/out <addresses.json> <Ethereum RPC>   # abis/ and ponder.config.ts
npm start                                                                    # Ponder 0.18.1, embedded PGlite
```

Checked on 2026-10-26 against an anvil fork of Ethereum with PLEA's mainnet build (`../deploy.mjs`, `ethereum-fork-trade.mjs`): the adapter's logs equal `eth_getLogs` for the same blocks, log for log (40 of 40: order, topics, data, block and transaction hashes and indexes). The Stacker's `Stacked` events for the hook are not in this reference yet (one more contract entry with an event filter on `project`).
