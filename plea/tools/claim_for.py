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
Fees: by default cast prices each transaction from the chain (EIP-1559); the run stops before a send
when the base fee is above --max-base-fee (default 1gwei). --gas-price / --priority set them by hand.
It refuses to start while the wallet has a pending transaction (other sessions share wallet A).
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
    ap.add_argument("--gas-price", help="max fee per gas, e.g. 0.5gwei (default: priced by cast from the chain)")
    ap.add_argument("--priority", help="priority fee per gas, e.g. 0.01gwei (default: priced by cast)")
    ap.add_argument("--max-base-fee", default="1gwei", help="stop before a send while the base fee is above this")
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

    root_file = data.get("merkleRoot") or data.get("root")  # distributor_root.py writes merkleRoot
    if not root_file:
        raise SystemExit("the claims file has no merkleRoot")
    root_onchain = cast("call", "--rpc-url", a.rpc, a.distributor, "merkleRoot()(bytes32)")
    if root_onchain.lower() != root_file.lower():
        raise SystemExit(f"root mismatch: chain {root_onchain} file {root_file}")

    key = os.environ.get(a.key_env) if a.send else None
    if a.send and not key:
        raise SystemExit(f"{a.key_env} is not set")
    fees = []
    if a.gas_price:
        fees += ["--gas-price", a.gas_price]
    if a.priority:
        fees += ["--priority-gas-price", a.priority]
    cap = int(cast("to-unit", a.max_base_fee, "wei"))
    if a.send:
        sender = cast("wallet", "address", "--private-key", key)
        if cast("nonce", "--rpc-url", a.rpc, "--block", "latest", sender) != cast("nonce", "--rpc-url", a.rpc, "--block", "pending", sender):
            raise SystemExit(f"{sender} has a pending transaction; wait for it")

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
        base = int(cast("base-fee", "--rpc-url", a.rpc))
        if base > cap:
            print(f"base fee {base / 1e9:.3f} gwei is above --max-base-fee {cap / 1e9:.3f} gwei: stopped")
            break
        out = cast("send", "--private-key", key, *fees, *args)
        tx = next((l.split()[-1] for l in out.splitlines() if l.startswith("transactionHash")), "?")
        status = next((l.split(None, 1)[1] for l in out.splitlines() if l.startswith("status")), "?")
        print(f"claimed index {c['index']} {c['account']} {amount_plea:,.0f} PLEA tx {tx} {status}")
        sent += 1
    print(f"{len(claims)} leaves: {done} already claimed, {sent} sent, {len(claims) - done - sent} pending")


if __name__ == "__main__":
    main()
