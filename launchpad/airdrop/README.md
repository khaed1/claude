# PondPad airdrop snapshot

Builds the 5% $PONDPAD airdrop list and its Merkle root for `AirdropDistributor` (decisions D-53, D-55, D-56). `snapshot.py` uses only the Python standard library (3.9+), including its own keccak-256, so anyone can rerun it and check the root.

## Rules (from `config.json`)

| | |
|---|---|
| Total | 50M $PONDPAD: **workers 35M (70%)**, **IMD holders 15M (30%)** |
| Workers | Seats of the IdentityMD seat NFT (`0x0000eC93…ec1D`, Ethereum) with **≥ 100 accepted jobs** that **worked in the 30 days** before the capture (`api.imd.fun/seats/records`). Per seat: half of the pool split equally, half by √(accepted jobs). Paid to the NFT's **owner** at the snapshot block (not the worker device wallet) |
| Holders | Wallets whose **IMD on Ethereum + Base + Robinhood plus sIMD** (at its IMD value) total **≥ 7,000 IMD**, on one chain or summed. Weight √(total). On Base, IMD is `0xFF0C…E105` (the dev's earlier token, merged into IMD; its OFT adapter `0xab15…690a` holds the bridged supply and is left out as a contract) |
| Both | A wallet in both pools gets both parts |
| Cap | **700k per wallet overall**; what the cap cuts is shared out again in proportion to everyone else's amount |
| Left out | Contracts (pools, bridges, vaults, exchanges' contracts, Safes) unless remapped; anything in `exclude` (team wallets, exchange hot wallets). The IMD inside the sIMD vault counts for its stakers, not for the vault |

## Snapshot method (option A)

The snapshot is a single moment that is **announced only after it is taken**, so nobody can buy or borrow IMD just before it.

1. **Capture (secretly, at a moment you pick):**
   ```bash
   python3 snapshot.py capture snapshots/2026-xx-xx
   ```
   Reads everything live, in about 3 minutes: each chain's block, the sIMD share price, the worker API, every seat's owner (`ownerOf`), and IMD / sIMD balances (Blockscout holder lists on Ethereum and Base, Transfer logs on Robinhood). Free public RPCs and explorers are enough, because nothing reads old state. Keep the folder private until you announce.
2. **Build (any time later, offline):**
   ```bash
   python3 snapshot.py build snapshots/2026-xx-xx
   ```
   Applies the rules (only contract checks go online) and writes:
   - `list.csv`: every wallet, amount, worker and holder parts, seats, IMD total, capped or not
   - `review.csv`: everything left out or remapped, with the reason (check it by hand: contracts, exchanges, team)
   - `claims.json`: root, total and each wallet's amount and proof (for the website)
   - `tree.json`: OpenZeppelin `StandardMerkleTree` dump (`StandardMerkleTree.load` in JS can read it)
   - `summary.json`: root, counts, total and what stays in the contract
3. **Review:** add exchange hot wallets and team wallets to `exclude`; for contract wallets that asked, add `remap` entries (`"<ethereum address>": "<robinhood address>"`). Rerun `build` (the captured blocks don't change).
4. **Announce:** publish the capture time and blocks, `config.json`, `list.csv` and the root. Anyone can rerun `build` on the same capture and get the same root.
5. **Deploy:** the root goes into `AirdropDistributor` at deploy and can never change.

`python3 snapshot.py selftest` checks keccak and the tree; with `--fixture ../contracts/test/fixtures/airdrop-tree.json` it writes the small tree that `AirdropTreeTest` verifies against the contract's leaf format.

## Dry run (5 Oct 2026, not the real snapshot)

Capture ~2.5 minutes, build ~1.5 minutes. **428 wallets**: 578 seats in 243 worker wallets, 204 holder wallets (≥ 7,000 IMD across the three chains and sIMD), 19 in both pools, 14 at the 700k cap. Median ~73k $PONDPAD per wallet (worker-only ~70k, holder-only ~72k), smallest ~44k. The whole 50M is allocated. 100 initiators would be ~23% of the list.
- **EIP-7702 wallets** (code `0xef0100…`) are plain keys that control the same address on Robinhood, so they count as normal wallets.
- `review.csv` had 24 real contracts: 9 seat holders and 15 IMD holders (bridge adapters, pool managers, a few Safes and other contracts). Each needs a decision: `remap` to a Robinhood address the owner gives us, or leave out.
