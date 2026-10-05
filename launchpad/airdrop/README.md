# PondPad airdrop snapshot

Builds the 5% $PONDPAD airdrop list and its Merkle root for `AirdropDistributor` (decisions D-53, D-55, D-56). `snapshot.py` uses only the Python standard library (3.9+), including its own keccak-256, so anyone can rerun it and check the root.

## Rules (from `config.json`)

| | |
|---|---|
| Total | 50M $PONDPAD: **workers 30M**, **IMD holders 20M** |
| Workers | Seats of the IdentityMD seat NFT (`0x0000eC93…ec1D`, Ethereum) with **≥ 100 accepted jobs** that **worked in the 30 days** before the capture (`api.imd.fun/seats/records`). Per seat: half of the pool split equally, half by √(accepted jobs). Paid to the NFT's **owner** at the snapshot block (not the worker device wallet) |
| Holders | Wallets whose **IMD on Ethereum + Base + Robinhood plus sIMD** (at its IMD value) total **≥ 7,000 IMD**, on one chain or summed. Weight √(total) |
| Both | A wallet in both pools gets both parts |
| Cap | **700k per wallet overall**; what the cap cuts is shared out again in proportion to everyone else's amount |
| Left out | Contracts (pools, bridges, vaults, exchanges' contracts, Safes) unless remapped; anything in `exclude` (team wallets, exchange hot wallets). The IMD inside the sIMD vault counts for its stakers, not for the vault |

## Snapshot method (option A)

The snapshot is a single moment that is **announced only after it is taken**, so nobody can buy or borrow IMD just before it.

1. **Capture (secretly, at a moment you pick):**
   ```bash
   python3 snapshot.py capture snapshots/2026-xx-xx
   ```
   Records each chain's current block, the live sIMD share price and the worker API data. Public RPCs don't keep old state, so this must run *at* the snapshot moment. Keep the folder private until you announce.
2. **Build (any time later):**
   ```bash
   python3 snapshot.py build snapshots/2026-xx-xx
   ```
   Rebuilds balances and seat owners at the captured blocks from Transfer logs (public RPCs serve those) and writes:
   - `list.csv`: every wallet, amount, worker and holder parts, seats, IMD total, capped or not
   - `review.csv`: everything left out or remapped, with the reason (check it by hand: contracts, exchanges, team)
   - `claims.json`: root, total and each wallet's amount and proof (for the website)
   - `tree.json`: OpenZeppelin `StandardMerkleTree` dump (`StandardMerkleTree.load` in JS can read it)
   - `summary.json`: root, counts, total and what stays in the contract
3. **Review:** add exchange hot wallets and team wallets to `exclude`; for contract wallets that asked, add `remap` entries (`"<ethereum address>": "<robinhood address>"`). Rerun `build` (the captured blocks don't change).
4. **Announce:** publish the capture time and blocks, `config.json`, `list.csv` and the root. Anyone can rerun `build` on the same capture and get the same root.
5. **Deploy:** the root goes into `AirdropDistributor` at deploy and can never change.

`python3 snapshot.py selftest` checks keccak and the tree; with `--fixture ../contracts/test/fixtures/airdrop-tree.json` it writes the small tree that `AirdropTreeTest` verifies against the contract's leaf format.

## Open

- **IMD on Base:** Ethereum's and Robinhood's IMD both name `0xab15…690a` as their Base peer, but that contract is an adapter for a token called "Fren Pet". Confirm the Base IMD address with the IMD dev and fill `chains.base.imd` (until then Base balances are not counted).
- RPCs: free Ethereum endpoints mostly refuse old logs (publicnode wants a key for them, drpc's free tier limits ranges). `rpc.mevblocker.io` worked in the dry run (5 Oct 2026, 20k-block ranges); any keyed RPC also works. The script retries and shrinks ranges by itself. `capture` only needs `latest` calls, so any RPC works for it.

## Dry run (5 Oct 2026, not the real snapshot)

A full capture + build against live data ran in about 10–20 minutes and allocated the whole 50M to **350 wallets**: 578 seats in 243 worker wallets, 125 holder wallets (≥ 7,000 IMD), 18 in both pools, 12 at the 700k cap. Median 99k $PONDPAD per wallet (worker-only 57k, holder-only 148k), smallest 37k. Things it showed:
- Most "contracts" are **EIP-7702 wallets** (code `0xef0100…`): plain keys that control the same address on Robinhood, so the script counts them as normal wallets.
- The rest of `review.csv` (14 rows: 13 seats, the Robinhood PoolManager) are real contracts: Uniswap v4 PoolManagers (correctly left out), a couple of Safes and a few other contracts holding seats or IMD. Each needs a decision: `remap` to a Robinhood address the owner gives us, or leave out.
