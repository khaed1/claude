#!/usr/bin/env python3
"""Prints each change of the given IMD jobs (state, node states) every 60 s; exits when all are terminal."""
import json, ssl, sys, time, urllib.request
ctx = ssl.create_default_context(); ctx.load_verify_locations("/root/.ccr/ca-bundle.crt")
def get(p):
    with urllib.request.urlopen(urllib.request.Request("https://api.imd.fun" + p), timeout=60, context=ctx) as r: return json.load(r)
END = {"completed", "failed", "cancelled", "rejected"}
last = {}
while True:
    done = 0
    for jid in sys.argv[1:]:
        try: j = get(f"/jobs/{jid}")
        except Exception as e: print(time.strftime("%H:%M:%S"), jid[:8], "poll failed", str(e)[:80], flush=True); continue
        nodes = j.get("nodes") or (j.get("workflow") or {}).get("nodes") or []  # IMD moved them under workflow
        launch = j.get("launch") or {}
        s = f"{j.get('state')} {j.get('blockedReason') or ''} " + " ".join(f"{n['key']}:{n.get('state')}" for n in nodes)
        if launch.get("id") or launch.get("status"): s += f" launch:{launch.get('id')}:{launch.get('status')}"
        if last.get(jid) != s:
            print(time.strftime("%H:%M:%S"), jid[:8], s, flush=True); last[jid] = s
        if j.get("state") in END or j.get("blockedReason"): done += 1
    if done == len(sys.argv) - 1: sys.exit(0)
    time.sleep(60)
