#!/usr/bin/env python3 -I
"""Builds PleaDistributor's one-time Merkle root: the swarm's 10% (equal share per seat that has
submitted work, paid to the seat's owner wallet; a wallet with several seats gets several shares) plus
the 2% airdrop (equal share per listed wallet). Leaf = keccak256(abi.encodePacked(index, account,
amount)), OpenZeppelin sorted-pair hashing, so `PleaDistributor.claim(index, account, amount, proof)`
verifies it.

  python3 -I distributor_root.py --records records.json --owners owners.json --airdrop airdrop.json --out root.json
  records.json = GET https://api.imd.fun/seats/records ; owners.json = GET https://api.imd.fun/seats/owners
  airdrop.json = ["0x…", …]   (the dev's list)   --swarm / --airdrop-amount override the wei amounts
"""
import argparse, json, sys

# ---------------------------------------------------------------- keccak-256 (FIPS 202 permutation, pad 0x01)
_RC = [0x0000000000000001,0x0000000000008082,0x800000000000808A,0x8000000080008000,0x000000000000808B,0x0000000080000001,
       0x8000000080008081,0x8000000000008009,0x000000000000008A,0x0000000000000088,0x0000000080008009,0x000000008000000A,
       0x000000008000808B,0x800000000000008B,0x8000000000008089,0x8000000000008003,0x8000000000008002,0x8000000000000080,
       0x000000000000800A,0x800000008000000A,0x8000000080008081,0x8000000000008080,0x0000000080000001,0x8000000080008008]
_ROT = [[0,36,3,41,18],[1,44,10,45,2],[62,6,43,15,61],[28,55,25,21,56],[27,20,39,8,14]]
_M = (1 << 64) - 1
def _rol(x, n): return ((x << n) | (x >> (64 - n))) & _M if n else x
def _f(st):
    for rc in _RC:
        c = [st[x][0]^st[x][1]^st[x][2]^st[x][3]^st[x][4] for x in range(5)]
        d = [c[(x-1)%5] ^ _rol(c[(x+1)%5], 1) for x in range(5)]
        st = [[st[x][y] ^ d[x] for y in range(5)] for x in range(5)]
        b = [[0]*5 for _ in range(5)]
        for x in range(5):
            for y in range(5):
                b[y][(2*x+3*y)%5] = _rol(st[x][y], _ROT[x][y])
        st = [[b[x][y] ^ ((~b[(x+1)%5][y]) & b[(x+2)%5][y]) for y in range(5)] for x in range(5)]
        st[0][0] ^= rc
    return st
def keccak256(data: bytes) -> bytes:
    rate = 136
    msg = bytearray(data) + b"\x01" + b"\x00" * ((rate - (len(data) + 1) % rate) % rate)
    msg[-1] |= 0x80
    st = [[0]*5 for _ in range(5)]
    for off in range(0, len(msg), rate):
        blk = msg[off:off+rate]
        for i in range(rate // 8):
            st[i % 5][i // 5] ^= int.from_bytes(blk[8*i:8*i+8], "little")
        st = _f(st)
    out = b"".join(st[i % 5][i // 5].to_bytes(8, "little") for i in range(4))
    return out

assert keccak256(b"").hex() == "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"

# ---------------------------------------------------------------- tree
def leaf(index, account, amount):
    return keccak256(index.to_bytes(32, "big") + bytes.fromhex(account[2:]) + amount.to_bytes(32, "big"))

def pair(a, b):
    return keccak256(a + b) if a < b else keccak256(b + a)

def build(leaves):
    layers = [leaves[:]]
    while len(layers[-1]) > 1:
        prev = layers[-1]
        nxt = [pair(prev[i], prev[i+1]) if i + 1 < len(prev) else prev[i] for i in range(0, len(prev), 2)]
        layers.append(nxt)
    return layers

def proof(layers, i):
    out = []
    for layer in layers[:-1]:
        j = i ^ 1
        if j < len(layer):
            out.append(layer[j])
        i //= 2
    return out

def verify(root, lf, pf):
    h = lf
    for p in pf:
        h = pair(h, p)
    return h == root

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--records", required=True)
    ap.add_argument("--owners", required=True)
    ap.add_argument("--airdrop", help="JSON list of wallets for the 2% airdrop")
    ap.add_argument("--swarm", type=int, default=100_000_000 * 10**18)
    ap.add_argument("--airdrop-amount", type=int, default=20_000_000 * 10**18)
    ap.add_argument("--min-accepted", type=int, default=0, help="seats need this many accepted works (0 = any submitted work)")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    records = json.load(open(a.records))["seats"]
    owners = json.load(open(a.owners))["owners"]
    seats = [s for s in records if int(s.get("accepted", 0)) >= a.min_accepted]
    alloc = {}
    skipped = 0
    for s in seats:
        tid = int(s["tokenId"])
        owner = owners[tid] if tid < len(owners) else None
        if not owner or int(owner, 16) == 0:
            skipped += 1
            continue
        owner = owner.lower()
        alloc[owner] = alloc.get(owner, 0) + a.swarm // len(seats)
    drop = []
    if a.airdrop:
        drop = sorted({w.lower() for w in json.load(open(a.airdrop))})
        for w in drop:
            alloc[w] = alloc.get(w, 0) + a.airdrop_amount // len(drop)
    accounts = sorted(alloc)
    leaves = [leaf(i, w, alloc[w]) for i, w in enumerate(accounts)]
    layers = build(leaves)
    root = layers[-1][0]
    claims = []
    for i, w in enumerate(accounts):
        pf = proof(layers, i)
        assert verify(root, leaves[i], pf)
        claims.append({"index": i, "account": w, "amount": str(alloc[w]), "proof": ["0x" + p.hex() for p in pf]})
    total = sum(alloc.values())
    out = {"merkleRoot": "0x" + root.hex(), "accounts": len(accounts), "seats": len(seats), "seatsWithoutOwner": skipped,
           "airdropWallets": len(drop), "swarmWei": str(a.swarm), "airdropWei": str(a.airdrop_amount),
           "totalWei": str(total), "dustWei": str(a.swarm + (a.airdrop_amount if drop else 0) - total), "claims": claims}
    json.dump(out, open(a.out, "w"), indent=1)
    print(f"root {out['merkleRoot']}  accounts {len(accounts)}  seats {len(seats)} (no owner: {skipped})  airdrop {len(drop)}  total {total/1e18:,.0f} PLEA  dust {int(out['dustWei'])/1e18:.6f}")

if __name__ == "__main__":
    main()
