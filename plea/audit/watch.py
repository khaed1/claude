#!/usr/bin/env python3
"""Polls IMD jobs every 60 s and exits on any change (state, a node's state/attempt/seat, a launch id).
usage: python3 plea/audit/watch.py <job id> [<job id> ...]   (free GETs; standard library only)"""
import json, os, ssl, sys, time, urllib.request
API = "https://api.imd.fun"
CA = os.environ.get("SSL_CERT_FILE") or "/root/.ccr/ca-bundle.crt"
ctx = ssl.create_default_context()
if os.path.exists(CA):
    ctx.load_verify_locations(CA)

def get(path):
    with urllib.request.urlopen(urllib.request.Request(API + path), timeout=60, context=ctx) as r:
        return json.load(r)

def snapshot(job):
    nodes = {n.get("key"): (n.get("state"), n.get("attempt"), (n.get("seat") or {}).get("tokenId")) for n in job.get("nodes", [])}
    launch = job.get("launch") or {}
    return {"state": job.get("state"), "blockedReason": job.get("blockedReason"), "nodes": nodes,
            "launch": (launch.get("id"), launch.get("status"))}

def main(ids):
    last = {}
    while True:
        changed = False
        for i in ids:
            try:
                s = snapshot(get(f"/jobs/{i}"))
            except Exception as e:  # a failed poll is not a change
                print(time.strftime("%H:%M:%S"), i[:8], "poll failed:", e); continue
            if last.get(i) != s:
                print(time.strftime("%H:%M:%S"), i[:8], json.dumps(s, default=str))
                if i in last:
                    changed = True
                last[i] = s
        if changed:
            return
        time.sleep(60)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
