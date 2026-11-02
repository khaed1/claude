#!/usr/bin/env python3
"""Watches One Dollar Audit jobs: prints every status or stage change (every 5 minutes) and exits when
one of them ends (complete, declined, cancelled, reassigned) or after ~115 minutes, printing the state
to pass back in. usage: watch_oda.py <id,id,...> ['<state json from the last run>']"""
import json, ssl, sys, time, urllib.request
ctx = ssl.create_default_context(); ctx.load_verify_locations("/root/.ccr/ca-bundle.crt")
IDS = [int(x) for x in sys.argv[1].split(",")]
END = {"complete", "declined", "cancelled", "reassigned"}
state = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
t0 = time.time()
while time.time() - t0 < 6900:
    for j in IDS:
        try:
            with urllib.request.urlopen(f"https://www.onedollaraudit.com/api/jobs/{j}", timeout=60, context=ctx) as r:
                d = json.load(r)
        except Exception:
            continue
        s = f"{d.get('status')}|{d.get('stage')}"
        if state.get(str(j)) != s:
            print(time.strftime("%H:%M:%S"), j, d.get("status"), "|", d.get("stage"), "| report", d.get("reportUrl"), flush=True)
            state[str(j)] = s
            if d.get("status") in END:
                print("STATE", json.dumps(state), flush=True)
                sys.exit(0)
    time.sleep(300)
print("STATE", json.dumps(state), flush=True)
