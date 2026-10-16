#!/usr/bin/env python3
"""Claim PLEA from PleaDistributor for other wallets.

`PleaDistributor.claim(index, account, amount, proof)` is permissionless and pays `account`,
so anyone (a dev, a keeper, wallet A) can push the claims of a set of wallets; the caller only pays
gas and can never redirect the PLEA (the leaf binds account and amount). Input = the root.json that
distributor_root.py writes (claims[] with index / account / amount / proof).

  python3 -I claim_for.py --claims root.json --distributor 0x... --rpc https://... \
      --accounts 0xaaa,0xbbb            # or --all
  add --send to broadcast; without it the script only prints what it would do.
The key comes from the environment (default PONDPAD_TESTNET_KEY) and is never printed.
"""
import argparse, json, os, subprocess, sys


def cast(*args):
    r = subprocess.run(["cast", *args], capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f"cast {' '.join(args[:2])} failed: {r.stderr.strip()[:300]}")
    return r.stdout.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--claims", required=True, help="root.json from distributor_root.py")
    ap.add_argument("--distributor", required=True)
    ap.add_argument("--rpc", required=True)
    ap.add_argument("--accounts", help="comma-separated wallets to claim for")
    ap.add_argument("--all", action="store_true", help="claim for every unclaimed leaf")
    ap.add_argument("--send", action="store_true", help="broadcast (default: dry run)")
    ap.add_argument("--key-env", default="PONDPAD_TESTNET_KEY")
    ap.add_argument("--gas-price", default="0.02gwei")
    ap.add_argument("--priority", default="0.01gwei")
    a = ap.parse_args()

    data = json.load(open(a.claims))
    claims = data["claims"]
    if a.accounts:
        want = {w.strip().lower() for w in a.accounts.split(",") if w.strip()}
        claims = [c for c in claims if c["account"].lower() in want]
        missing = want - {c["account"].lower() for c in claims}
        for w in sorted(missing):
            print(f"not on the list: {w}")
    elif not a.all:
        raise SystemExit("give --accounts or --all")

    root_onchain = cast("call", "--rpc-url", a.rpc, a.distributor, "merkleRoot()(bytes32)")
    if root_onchain.lower() != data["root"].lower():
        raise SystemExit(f"root mismatch: chain {root_onchain} file {data['root']}")

    key = os.environ.get(a.key_env) if a.send else None
    if a.send and not key:
        raise SystemExit(f"{a.key_env} is not set")

    done = sent = 0
    for c in claims:
        if cast("call", "--rpc-url", a.rpc, a.distributor, "isClaimed(uint256)(bool)", str(c["index"])) == "true":
            done += 1
            print(f"already claimed: index {c['index']} {c['account']}")
            continue
        proof = "[" + ",".join(c["proof"]) + "]"
        args = ["--rpc-url", a.rpc, a.distributor, "claim(uint256,address,uint256,bytes32[])",
                str(c["index"]), c["account"], c["amount"], proof]
        amount_plea = int(c["amount"]) / 1e18
        if not a.send:
            print(f"would claim index {c['index']} {c['account']} {amount_plea:,.0f} PLEA")
            continue
        out = cast("send", "--private-key", key, "--gas-price", a.gas_price,
                   "--priority-gas-price", a.priority, *args)
        tx = next((l.split()[-1] for l in out.splitlines() if l.startswith("transactionHash")), "?")
        status = next((l.split(None, 1)[1] for l in out.splitlines() if l.startswith("status")), "?")
        print(f"claimed index {c['index']} {c['account']} {amount_plea:,.0f} PLEA tx {tx} {status}")
        sent += 1
    print(f"{len(claims)} leaves: {done} already claimed, {sent} sent, {len(claims) - done - sent} pending")


if __name__ == "__main__":
    main()
