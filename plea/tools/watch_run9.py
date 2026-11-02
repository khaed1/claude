#!/usr/bin/env python3
"""Run 9 outsider watch (read only): exits as soon as a transaction that touches run 9's contracts
(hook, gate, Letterbox, Tribunal, Seasons, distributor) or its pool comes from a wallet that is not
ours (wallet A, the test players) or IMD's Intake writer. Meant for a background job: its exit wakes
the session.

  python3 -I watch_run9.py --players <STATE_DIR>/players.json --from-block N [--minutes 115] [--every 60]
"""
import argparse, json, subprocess, sys, time

CAST = "/root/.local/bin/cast"
RPC = "https://ethereum-sepolia-rpc.publicnode.com"
WALLET_A = "0x4b91078b2374c956a65f7af0999cae0a935e6821"
WRITER = "0x3d3c0df7c1a17d384545e9d7c8228897bd9625cb"
POOL_MANAGER = "0xe03a1074c86cfedd5c142c4f04f1a1536e203543"
SWAP = "0x40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f"


def cast(*a):
    p = subprocess.run([CAST, *a, "--rpc-url", RPC], capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip()[-300:])
    return p.stdout.strip()


def logs(flt):
    return json.loads(cast("rpc", "eth_getLogs", json.dumps(flt)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--players", required=True)
    ap.add_argument("--addrs", default="plea/live-run9/addresses.json")
    ap.add_argument("--from-block", type=int, required=True)
    ap.add_argument("--minutes", type=float, default=115)
    ap.add_argument("--every", type=int, default=60)
    a = ap.parse_args()
    ours = {WALLET_A, WRITER} | {v.lower() for v in json.load(open(a.players)).values()}
    ad = json.load(open(a.addrs))
    watched = [ad[k] for k in ("HOOK", "GATE", "LETTERBOX", "TRIBUNAL", "SEASONS", "DISTRIBUTOR")]
    pool_id = cast("call", ad["HOOK"], "poolId()(bytes32)")
    seen, nxt, end = set(), a.from_block, time.time() + a.minutes * 60
    while time.time() < end:
        try:
            head = int(cast("block-number"))
            if head >= nxt:
                found = logs({"address": watched, "fromBlock": hex(nxt), "toBlock": hex(head)})
                found += logs({"address": POOL_MANAGER, "topics": [SWAP, pool_id], "fromBlock": hex(nxt), "toBlock": hex(head)})
                for lg in found:
                    tx = lg["transactionHash"]
                    if tx in seen:
                        continue
                    seen.add(tx)
                    frm = cast("tx", tx, "from").lower()
                    if frm not in ours:
                        print(f"OUTSIDER {frm} tx {tx} block {int(lg['blockNumber'], 16)} contract {lg['address']}")
                        sys.exit(0)
                nxt = head + 1
        except (RuntimeError, ValueError) as e:
            print(f"(read error, retrying: {e})", file=sys.stderr)
        time.sleep(a.every)
    print(f"quiet: no outsider through block {nxt - 1}")


if __name__ == "__main__":
    main()
