#!/usr/bin/env python3
"""PondPad airdrop snapshot (D-53, D-55, D-56). Python 3.9+, standard library only.

  capture  Run once, at the snapshot moment, without telling anyone (option A: the snapshot is announced only
           after it was taken). Reads everything live: each chain's block, the sIMD share price, the IMD worker
           API, seat NFT owners (ownerOf) and IMD / sIMD balances (Blockscout holder lists on Ethereum and Base,
           Transfer logs on Robinhood, whose RPC serves them). Saves it all in the folder.
  build    Any time later, offline (only contract checks at `latest`). Applies the rules and writes the list, a
           review file and the Merkle tree (OpenZeppelin StandardMerkleTree format, as AirdropDistributor
           expects). Rerunning it on the same capture gives the same root.
  selftest Checks the keccak implementation and the tree, and with --fixture writes a small tree that the
           Foundry test `AirdropTreeTest` verifies against the contract's leaf and proof format.

Rules (config.json):
  Workers pool (35M): seats with >= minAcceptedJobs accepted jobs that worked within activeWithinDays before
  the capture. Per seat: half of the pool equally, half by sqrt(accepted). Paid to the seat NFT's owner at capture.
  Holders pool (15M): wallets whose IMD on Ethereum + Base + Robinhood plus sIMD (at its IMD value) total
  >= holderMinImd. Weight sqrt(total).
  A wallet in both pools gets both. Cap per wallet overall (700k); what the cap cuts is shared out again in
  proportion to the uncapped amounts. Contracts (pools, bridges, vaults, Safes) are left out unless remapped
  to a Robinhood address in config.remap; addresses in config.exclude are left out.
"""
import argparse
import csv
import datetime as dt
import json
import math
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# ---------------------------------------------------------------------------------------------- keccak-256

_RC = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000, 0x000000000000808B,
    0x0000000080000001, 0x8000000080008081, 0x8000000000008009, 0x000000000000008A, 0x0000000000000088,
    0x0000000080008009, 0x000000008000000A, 0x000000008000808B, 0x800000000000008B, 0x8000000000008089,
    0x8000000000008003, 0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
]
_ROT = [[0, 36, 3, 41, 18], [1, 44, 10, 45, 2], [62, 6, 43, 15, 61], [28, 55, 25, 21, 56], [27, 20, 39, 8, 14]]
_M = (1 << 64) - 1


def _rol(v, n):
    return ((v << n) | (v >> (64 - n))) & _M if n else v


def _keccak_f(a):
    for rc in _RC:
        c = [a[x][0] ^ a[x][1] ^ a[x][2] ^ a[x][3] ^ a[x][4] for x in range(5)]
        d = [c[(x - 1) % 5] ^ _rol(c[(x + 1) % 5], 1) for x in range(5)]
        a = [[a[x][y] ^ d[x] for y in range(5)] for x in range(5)]
        b = [[0] * 5 for _ in range(5)]
        for x in range(5):
            for y in range(5):
                b[y][(2 * x + 3 * y) % 5] = _rol(a[x][y], _ROT[x][y])
        a = [[b[x][y] ^ ((~b[(x + 1) % 5][y]) & b[(x + 2) % 5][y]) for y in range(5)] for x in range(5)]
        a[0][0] ^= rc
    return a


def keccak(data: bytes) -> bytes:
    rate = 136
    msg = bytearray(data) + b"\x01"
    msg += b"\x00" * (-len(msg) % rate)
    msg[-1] |= 0x80
    a = [[0] * 5 for _ in range(5)]
    for off in range(0, len(msg), rate):
        block = msg[off:off + rate]
        for i in range(rate // 8):
            x, y = i % 5, i // 5
            a[x][y] ^= int.from_bytes(block[8 * i:8 * i + 8], "little")
        a = _keccak_f(a)
    out = b"".join(a[i % 5][i // 5].to_bytes(8, "little") for i in range(4))
    return out


# ---------------------------------------------------------------------------------------------- Merkle tree


def leaf_hash(account: str, amount: int) -> bytes:
    enc = bytes(12) + bytes.fromhex(account[2:]) + amount.to_bytes(32, "big")
    return keccak(keccak(enc))


def _hash_pair(a: bytes, b: bytes) -> bytes:
    return keccak(min(a, b) + max(a, b))


def build_tree(entries):
    """entries: list of (address, amount). Returns an OpenZeppelin StandardMerkleTree dump plus proofs."""
    hashed = sorted(((leaf_hash(a, v), i) for i, (a, v) in enumerate(entries)), key=lambda t: t[0])
    n = len(hashed)
    if n == 0:
        raise SystemExit("empty list")
    tree = [b""] * (2 * n - 1)
    values = [None] * n
    for k, (h, i) in enumerate(hashed):
        idx = len(tree) - 1 - k
        tree[idx] = h
        values[i] = idx
    for i in range(len(tree) - 1 - n, -1, -1):
        tree[i] = _hash_pair(tree[2 * i + 1], tree[2 * i + 2])

    def proof(idx):
        p = []
        while idx > 0:
            sib = idx - 1 if idx % 2 == 0 else idx + 1
            p.append("0x" + tree[sib].hex())
            idx = (idx - 1) // 2
        return p

    dump = {
        "format": "standard-v1",
        "leafEncoding": ["address", "uint256"],
        "tree": ["0x" + h.hex() for h in tree],
        "values": [{"value": [a, str(v)], "treeIndex": values[i]} for i, (a, v) in enumerate(entries)],
    }
    claims = {a: {"amount": str(v), "proof": proof(values[i])} for i, (a, v) in enumerate(entries)}
    return "0x" + tree[0].hex(), dump, claims


def verify(root: str, account: str, amount: int, proof) -> bool:
    h = leaf_hash(account, amount)
    for p in proof:
        h = _hash_pair(h, bytes.fromhex(p[2:]))
    return "0x" + h.hex() == root


# ---------------------------------------------------------------------------------------------- RPC

TRANSFER = "0x" + keccak(b"Transfer(address,address,uint256)").hex()
UA = {"Content-Type": "application/json", "User-Agent": "pondpad-airdrop-snapshot/1"}


def http_json(url, payload=None, tries=6):
    data = json.dumps(payload).encode() if payload is not None else None
    for t in range(tries):
        try:
            req = urllib.request.Request(url, data=data, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            body = e.read()
            if e.code not in (403, 429) and e.code < 500:
                try:
                    return json.loads(body)  # a JSON-RPC error sent with HTTP 400: let the caller handle it
                except ValueError:
                    pass
            if t == tries - 1:
                raise
            time.sleep(2 ** t)
        except Exception:  # timeouts, resets
            if t == tries - 1:
                raise
            time.sleep(2 ** t)


def rpc(url, method, params):
    r = http_json(url, {"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
    if "error" in r:
        raise RuntimeError(f"{method}: {r['error']}")
    return r["result"]


def call(url, to, data, block="latest"):
    tag = hex(block) if isinstance(block, int) else block
    return rpc(url, "eth_call", [{"to": to, "data": data}, tag])


def selector(sig):
    return "0x" + keccak(sig.encode()).hex()[:8]


def logs(url, address, from_block, to_block, max_range):
    """All Transfer logs of `address` in [from_block, to_block], with an adaptive block range."""
    out, start, step, fails = [], from_block, max_range, 0
    while start <= to_block:
        end = min(start + step - 1, to_block)
        try:
            res = rpc(url, "eth_getLogs", [{"address": address, "topics": [TRANSFER],
                                            "fromBlock": hex(start), "toBlock": hex(end)}])
        except Exception:
            fails += 1
            if fails % 4:  # load-balanced public RPCs fail now and then: retry the same range first
                time.sleep(fails % 4)
                continue
            if step <= 1:
                raise
            step = max(1, step // 4)  # then assume the range is too large (too many logs)
            continue
        fails = 0
        out.extend(res)
        start = end + 1
        step = min(max_range, step * 2)
        print(f"  {address[:10]}… block {end:,} / {to_block:,}: {len(out):,} transfers", file=sys.stderr, end="\r")
    print(file=sys.stderr)
    return out


def erc20_balances(transfers):
    bal = {}
    for lg in transfers:
        if len(lg["topics"]) != 3:
            continue  # an ERC-721 Transfer has 4 topics
        frm = "0x" + lg["topics"][1][26:]
        to = "0x" + lg["topics"][2][26:]
        v = int(lg["data"], 16)
        bal[frm] = bal.get(frm, 0) - v
        bal[to] = bal.get(to, 0) + v
    bal.pop("0x" + "0" * 40, None)
    return {a: v for a, v in bal.items() if v > 0}


# ---------------------------------------------------------------------------------------------- capture


def rpc_batch(url, calls, size=50):
    """eth_call batches at `latest`: calls = [(to, data)]. Returns results in order (None on error)."""
    out = []
    for i in range(0, len(calls), size):
        chunk = calls[i:i + size]
        payload = [{"jsonrpc": "2.0", "id": j, "method": "eth_call", "params": [{"to": t, "data": d}, "latest"]}
                   for j, (t, d) in enumerate(chunk)]
        res = {r["id"]: r.get("result") for r in http_json(url, payload)}
        out.extend(res.get(j) for j in range(len(chunk)))
    return out


def explorer_holders(explorer, token, floor_wei):
    """Current holders of `token` from a Blockscout explorer, largest first, down to `floor_wei`."""
    out, params = {}, None
    while True:
        url = f"{explorer}/api/v2/tokens/{token}/holders"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        d = http_json(url)
        items = d.get("items", [])
        for it in items:
            out[it["address"]["hash"].lower()] = out.get(it["address"]["hash"].lower(), 0) + int(it["value"])
        print(f"  {token[:10]}… {len(out):,} holders", file=sys.stderr, end="\r")
        params = d.get("next_page_params")
        if not params or not items or int(items[-1]["value"]) < floor_wei:
            print(file=sys.stderr)
            return {a: v for a, v in out.items() if v >= floor_wei}


def capture(cfg, out_dir):
    """Everything the list needs, read live at one moment: blocks, sIMD price, worker data, seat owners and
    balances. Nothing here needs old state, so any RPC and the public explorers are enough."""
    os.makedirs(out_dir, exist_ok=True)
    now = dt.datetime.now(dt.timezone.utc)
    chains, tokens = cfg["chains"], cfg["tokens"]
    blocks = {name: int(rpc(ch["rpc"], "eth_blockNumber", []), 16) for name, ch in chains.items()}

    print("worker data…", file=sys.stderr)
    seats = http_json(cfg["workerApi"])
    with open(os.path.join(out_dir, "seats_records.json"), "w") as f:
        json.dump(seats, f)

    print("seat owners…", file=sys.stderr)
    nft = tokens["seatNft"]
    ids = sorted({int(x["tokenId"]) for x in seats["seats"]})
    res = rpc_batch(chains[nft["chain"]]["rpc"],
                    [(nft["address"], selector("ownerOf(uint256)") + f"{i:064x}") for i in ids])
    owners = {str(i): "0x" + r[-40:] for i, r in zip(ids, res) if r and len(r) >= 66}

    simd = tokens["sImd"]
    srpc = chains[simd["chain"]]["rpc"]
    total_assets = int(call(srpc, simd["address"], selector("totalAssets()")), 16)
    total_supply = int(call(srpc, simd["address"], selector("totalSupply()")), 16)

    floor = units(cfg["listFloorImd"])
    balances = {}
    for chain, tok in tokens["imd"].items():
        print(f"IMD holders ({chain})…", file=sys.stderr)
        ch = chains[chain]
        if ch.get("explorer"):
            balances[chain] = explorer_holders(ch["explorer"], tok["address"], floor)
        else:
            transfers = logs(ch["rpc"], tok["address"], tok.get("fromBlock", 0), blocks[chain], tok["maxRange"])
            balances[chain] = {a: v for a, v in erc20_balances(transfers).items() if v >= floor}
    print("sIMD holders…", file=sys.stderr)
    balances["sImd"] = explorer_holders(chains[simd["chain"]]["explorer"], simd["address"],
                                        floor * total_supply // total_assets)

    with open(os.path.join(out_dir, "owners.json"), "w") as f:
        json.dump(owners, f)
    with open(os.path.join(out_dir, "balances.json"), "w") as f:
        json.dump({k: {a: str(v) for a, v in b.items()} for k, b in balances.items()}, f)
    cap = {"capturedAt": now.isoformat(), "blocks": blocks,
           "sImd": {"totalAssets": str(total_assets), "totalSupply": str(total_supply)},
           "seatCount": len(seats["seats"]), "seatOwners": len(owners),
           "holders": {k: len(b) for k, b in balances.items()}}
    with open(os.path.join(out_dir, "capture.json"), "w") as f:
        json.dump(cap, f, indent=2)
    print(json.dumps(cap, indent=2))


# ---------------------------------------------------------------------------------------------- build


def units(x):
    return int(str(x)) * 10**18


def is_contract(url, addr, cache):
    if addr not in cache:
        code = rpc(url, "eth_getCode", [addr, "latest"])
        # An EIP-7702 wallet (code 0xef0100 + delegate) is still a plain key that controls the address everywhere.
        cache[addr] = code not in ("0x", "0x0") and not code.startswith("0xef0100")
    return cache[addr]


def cap_water_fill(amounts, cap):
    amounts = dict(amounts)
    capped = set()
    while True:
        over = [a for a, v in amounts.items() if v > cap]
        if not over:
            return amounts, capped
        excess = sum(amounts[a] - cap for a in over)
        for a in over:
            amounts[a] = cap
            capped.add(a)
        free = {a: v for a, v in amounts.items() if a not in capped}
        base = sum(free.values())
        if base == 0:
            return amounts, capped  # everyone capped: the rest stays in the contract (swept to stakers)
        for a, v in free.items():
            amounts[a] = v + excess * v // base


def build(cfg, in_dir):
    cap = json.load(open(os.path.join(in_dir, "capture.json")))
    seats = json.load(open(os.path.join(in_dir, "seats_records.json")))["seats"]
    owners = {int(k): v for k, v in json.load(open(os.path.join(in_dir, "owners.json"))).items()}
    balances = json.load(open(os.path.join(in_dir, "balances.json")))
    captured = dt.datetime.fromisoformat(cap["capturedAt"])
    chains = cfg["chains"]
    exclude = {a.lower() for a in cfg.get("exclude", [])}
    remap = {k.lower(): v.lower() for k, v in cfg.get("remap", {}).items()}
    code_cache = {}
    review = []

    def resolve(addr, chain, why):
        """Final Robinhood recipient for `addr`, or None if it is left out."""
        if addr in exclude:
            review.append((addr, chain, why, "excluded (config)"))
            return None
        if addr in remap:
            review.append((addr, chain, why, f"remapped to {remap[addr]}"))
            return remap[addr]
        if is_contract(chains[chain]["rpc"], addr, code_cache):
            review.append((addr, chain, why, "contract: left out unless remapped"))
            return None
        return addr

    # Workers ------------------------------------------------------------------------------------------
    cutoff = captured - dt.timedelta(days=cfg["activeWithinDays"])
    eligible = []
    for s in seats:
        last = s.get("lastWorkedAt")
        if s["accepted"] < cfg["minAcceptedJobs"] or not last:
            continue
        if dt.datetime.fromisoformat(last.replace("Z", "+00:00")) < cutoff:
            continue
        tid = int(s["tokenId"])
        if tid not in owners:
            review.append((f"seat {tid}", "ethereum", "worker", "no owner found at capture"))
            continue
        to = resolve(owners[tid], "ethereum", f"worker seat {tid}")
        if to is not None:
            eligible.append((tid, s["accepted"], to))
    worker_pool = units(cfg["workersPool"])
    equal = worker_pool // 2 // max(1, len(eligible))
    sqrt_total = sum(math.isqrt(a * 10**18) for _, a, _ in eligible)
    worker_amt, worker_seats = {}, {}
    for tid, acc, to in eligible:
        amt = equal + (worker_pool - worker_pool // 2) * math.isqrt(acc * 10**18) // sqrt_total
        worker_amt[to] = worker_amt.get(to, 0) + amt
        worker_seats.setdefault(to, []).append(tid)

    # Holders ------------------------------------------------------------------------------------------
    holdings = {}  # address -> {chain or "sImd": IMD wei}
    ta, ts = int(cap["sImd"]["totalAssets"]), int(cap["sImd"]["totalSupply"])
    for source, bals in balances.items():
        for a, v in bals.items():
            v = int(v) * ta // ts if source == "sImd" else int(v)
            holdings.setdefault(a, {}).setdefault(source, 0)
            holdings[a][source] += v
    # The IMD inside the sIMD vault belongs to its stakers, counted above.
    holdings.pop(cfg["tokens"]["sImd"]["address"].lower(), None)

    minimum = units(cfg["holderMinImd"])
    holder_w, holder_total = {}, {}
    for a, parts in holdings.items():
        total = sum(parts.values())
        if total < minimum:
            continue
        chain = max(parts, key=parts.get)
        to = resolve(a, cfg["tokens"]["sImd"]["chain"] if chain == "sImd" else chain, f"holder {total / 1e18:,.0f} IMD")
        if to is None:
            continue
        holder_total[to] = holder_total.get(to, 0) + total
    for to, total in holder_total.items():
        holder_w[to] = math.isqrt(total)
    holder_pool = units(cfg["holdersPool"])
    wsum = sum(holder_w.values())
    holder_amt = {a: holder_pool * w // wsum for a, w in holder_w.items()} if wsum else {}

    # Combine, cap, tree -------------------------------------------------------------------------------
    combined = {}
    for a in set(worker_amt) | set(holder_amt):
        combined[a] = worker_amt.get(a, 0) + holder_amt.get(a, 0)
    final, capped = cap_water_fill(combined, units(cfg["walletCap"]))
    total = sum(final.values())
    assert total <= units(cfg["airdropTotal"]), "allocations exceed the airdrop"

    entries = sorted((addr_checksumless(a), v) for a, v in final.items() if v > 0)
    root, dump, claims = build_tree(entries)
    for a, v in entries[:: max(1, len(entries) // 20)]:
        assert verify(root, a, v, claims[a]["proof"])

    with open(os.path.join(in_dir, "list.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["address", "amount", "workers_part", "holders_part", "capped", "seats", "imd_total"])
        for a, v in sorted(final.items(), key=lambda t: -t[1]):
            w.writerow([a, f"{v / 1e18:.6f}", f"{worker_amt.get(a, 0) / 1e18:.2f}", f"{holder_amt.get(a, 0) / 1e18:.2f}",
                        a in capped, " ".join(map(str, sorted(worker_seats.get(a, [])))),
                        f"{holder_total.get(a, 0) / 1e18:.2f}"])
    with open(os.path.join(in_dir, "review.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["address", "chain", "why listed", "outcome"])
        w.writerows(review)
    with open(os.path.join(in_dir, "tree.json"), "w") as f:
        json.dump(dump, f)
    with open(os.path.join(in_dir, "claims.json"), "w") as f:
        json.dump({"root": root, "total": str(total), "claims": claims}, f)
    summary = {
        "root": root, "wallets": len(final), "total": total / 1e18,
        "left_in_contract": (units(cfg["airdropTotal"]) - total) / 1e18,
        "seats": len(eligible), "worker_wallets": len(worker_amt), "holder_wallets": len(holder_amt),
        "capped_wallets": len(capped), "review_rows": len(review),
    }
    with open(os.path.join(in_dir, "summary.json"), "w") as f:
        json.dump(summary, f, indent=2)
    print(json.dumps(summary, indent=2))


def addr_checksumless(a):
    return a.lower()


# ---------------------------------------------------------------------------------------------- selftest


def selftest(fixture):
    assert keccak(b"").hex() == "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
    assert keccak(b"abc").hex() == "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"
    assert keccak(b"a" * 200).hex() == "96ea54061def936c4be90b518992fdc6f12f535068a256229aca54267b4d084d"  # 2 blocks
    assert keccak(b"b" * 136).hex() == "121b76d0b19f3c2c7632310b92c54cddd59d16a6b5aafe84696426f10e5733bf"  # full block
    assert TRANSFER == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    entries = [("0x" + f"{i + 1:040x}", (i + 1) * 1000 * 10**18) for i in range(7)]
    root, dump, claims = build_tree(entries)
    for a, v in entries:
        assert verify(root, a, v, claims[a]["proof"])
    assert not verify(root, entries[0][0], entries[0][1] + 1, claims[entries[0][0]]["proof"])
    capped, _ = cap_water_fill({"a": 900, "b": 100, "c": 100}, 700)
    assert capped["a"] == 700 and sum(capped.values()) <= 1100
    if fixture:
        with open(fixture, "w") as f:
            json.dump({"root": root, "accounts": [a for a, _ in entries], "amounts": [str(v) for _, v in entries],
                       "proofs": [claims[a]["proof"] for a, _ in entries]}, f, indent=2)
    print("selftest ok, root", root)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["capture", "build", "selftest"])
    ap.add_argument("dir", nargs="?", help="snapshot folder (capture writes it, build reads and writes it)")
    ap.add_argument("--config", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json"))
    ap.add_argument("--fixture", help="selftest: write a small tree for the Foundry test")
    args = ap.parse_args()
    if args.command == "selftest":
        return selftest(args.fixture)
    cfg = json.load(open(args.config))
    if not args.dir:
        ap.error("dir is required")
    (capture if args.command == "capture" else build)(cfg, args.dir)


if __name__ == "__main__":
    main()
