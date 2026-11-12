"""Check "Plead your case" entries. Input: a JSON list of {handle, wallet, plea, time?} (time ISO UTC). Usage: python3 -I check_entries.py entries.json
Checks: address format; code now (plain / EIP-7702 / other contract = check by hand for a smart wallet); nonce >= 20 at block 26,307,302 (Tenderly serves old state);
one wallet per handle and per entry; time after END; copied pleas (difflib ratio > 0.8 on text without addresses, tags and links). Writes checked.json in the current directory."""
import json, sys, re, subprocess, difflib
from collections import Counter
RPC = "https://mainnet.gateway.tenderly.co"   # serves old state
BLOCK = 26307302
END = "2026-11-05T18:15:44Z"
def rpc(m, p):
    r = subprocess.run(["curl","-sS","-m","30","-X","POST","-H","content-type: application/json","--data",json.dumps({"jsonrpc":"2.0","id":1,"method":m,"params":p}),RPC],capture_output=True,text=True)
    d = json.loads(r.stdout)
    if "error" in d: raise RuntimeError(d["error"])
    return d["result"]
def norm(t): return re.sub(r"[^a-z0-9 ]","",re.sub(r"0x[0-9a-fA-F]{40}|@\w+|https?://\S+","",t.lower())).split()
entries = json.load(open(sys.argv[1]))
out = []
wallet_count = Counter(e.get("wallet","").lower() for e in entries if e.get("wallet"))
handle_wallets = {}
for e in entries: handle_wallets.setdefault(e["handle"].lower(), set()).add((e.get("wallet") or "").lower())
for i, e in enumerate(entries):
    why = []
    w = e.get("wallet") or ""
    if not re.fullmatch(r"0x[0-9a-fA-F]{40}", w): why.append("no or bad wallet")
    else:
        code = rpc("eth_getCode", [w, hex(BLOCK)]); code_now = rpc("eth_getCode", [w, "latest"])
        nonce = int(rpc("eth_getTransactionCount", [w, hex(BLOCK)]), 16)
        e["nonce_at_block"] = nonce
        kind = "plain" if code_now == "0x" else ("eip7702" if code_now.startswith("0xef0100") else "contract")
        e["code_kind"] = kind
        if kind == "contract": why.append("contract: check if smart wallet")
        if nonce < 20 and kind != "contract": why.append(f"nonce {nonce} < 20 at block {BLOCK}")
        if wallet_count[w.lower()] > 1: why.append("wallet used more than once")
    if len(handle_wallets[e["handle"].lower()]) > 1: why.append("several wallets for one account")
    if e.get("time") and e["time"] > END: why.append("after the end")
    e["problems"] = why
    out.append(e)
# copied pleas: pairwise similarity of normalized text
for i in range(len(out)):
    for j in range(i):
        a, b = " ".join(norm(out[i].get("plea",""))), " ".join(norm(out[j].get("plea","")))
        if a and b:
            r = difflib.SequenceMatcher(None, a, b).ratio()
            if r > 0.8: out[i]["problems"].append(f"similar to entry {j} ({out[j]['handle']}) {r:.2f}")
json.dump(out, open("checked.json","w"), indent=1)
for i, e in enumerate(out):
    print(i, e["handle"], e.get("wallet"), e.get("code_kind"), e.get("nonce_at_block"), "OK" if not e["problems"] else e["problems"])
print("valid", sum(1 for e in out if not e["problems"]), "of", len(out))
