# PLEA on an Ethereum fork (for the site's mainnet version)

`npm install` here (viem 2.57.7, the site's version), then:

- `ARTIFACTS=<khaed1/plea mainnet build>/out FORK_BLOCK=<block> node deploy.mjs <port> <out dir>`: an anvil fork of Ethereum (Tenderly's archive gateway, so it never decays) with PLEA's `mainnet` build deployed as the launch will (the five launch contracts in one block, then `deployLetterbox`, `deployTribunal`, `deployHook` with a mined salt), the real IMD, PoolManager, imd/acc Stacker, identity.md seat NFT and Intake v2, the real owner address impersonated (no key), a test attestation signer (key 0xa11ce, fork only), START 1795532400. Writes `addresses.json` and `state.hex`; anvil keeps running.
- `node ur-buy.mjs <port> <addresses.json> <router> <minHop 0|1> <buyer> <IMD in> [seed]`: a buy through Uniswap's Universal Router: `V4_SWAP` (`SWAP_EXACT_IN_SINGLE` with hookData `abi.encode(buyer)` and `amountOutMinimum` 0, `SETTLE_ALL` IMD through Permit2, `TAKE_ALL` PLEA 0) then `BALANCE_CHECK_ERC20` on the buyer's PLEA (`MIN_OUT` env). `seed` lets the owner seed first.
- `node ur-sell.mjs <port> <addresses.json> <router> <minHop 0|1> <seller> <PLEA|all>`: after the Cabal's death, a sell the same way (`TAKE_ALL` IMD with the minimum).

Routers (2026-10-26): v2.1.2 `0x23617e59a5925b2a4bf75d73ff6711cd0b29de85` and v2.1.1 `0x4c82d1fbfe28c977cbb58d8c7ff8fcf9f70a2cca` take the swap struct with `minHopPriceX36` (pass 1); v2 `0x66a9893cc07d91d95644aedd05d03f95e1dba8af` the older struct (pass 0). Results on block 26,278,700: the owner's seed + 2 IMD opening buy → ~82,700 PLEA (gas ~0.78M); after the death, 5 IMD → 347,371 PLEA → sold back for 4.78 IMD, on both struct versions. sIMD (`Stacker.SIMD()`) is `0x9efa934d9fad4ae28c998a40195646b965a97247`, 24 decimals.

## A seeded court on the fork (base state), like `../fork-base.sh` for Sepolia

- `FORK_URL=https://eth.drpc.org FORK_BLOCK=26278700 node deploy.mjs <port> <dir>` (public archive RPCs rate-limit a fork's burst of reads; deploy.mjs retries with backoff and paces requests; Tenderly's gateway and MEV Blocker refused bursts on 2026-10-26, dRPC worked), then `node base.mjs <port> <dir>` (it imports the site's `web/src/universal-router.ts`: point its import at your plea-site checkout): the owner seeds and makes the 2 IMD opening buy through the Universal Router; players p1..p8 = `0xa111…`..`0xa118…` (fixed addresses, impersonated) get 1 ETH + 30 IMD; a distributor root gives each 2,500,000 PLEA and the owner 20,000,000, all claimed (`claims.json` holds the list the site's Claim page can load); the launch window is warped past; p1..p4 buy 5 IMD each; identity.md seat #558 moves to p5. Writes `base.json` (addresses, players, block, time) and `base.hex`.
- `fork-load.sh <port> <dir>/base.hex` reloads it (~10 s; dRPC archive, block 26,278,700).
- Built on 2026-10-26: opening buy 82,508 PLEA; p1..p4 ~347,000 PLEA each for 5 IMD; base block 26,278,741.
