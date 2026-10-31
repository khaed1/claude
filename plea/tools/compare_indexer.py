#!/usr/bin/env python3
# Compares the indexer's rawLogs (the site's exact query) with eth_getLogs for the same range.
#   python3 -I compare.py <graphql url> <rpc url> <from> <to|meta>
import json, subprocess, sys
gql, rpc, frm, to = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
Q = 'query Logs($from: BigInt!, $to: BigInt!, $after: String) { rawLogs(where: { blockNumber_gte: $from, blockNumber_lte: $to }, orderBy: "id", orderDirection: "asc", limit: 1000, after: $after) { items { blockNumber blockHash blockTimestamp transactionHash transactionIndex logIndex address topic0 topic1 topic2 topic3 data } pageInfo { hasNextPage endCursor } } _meta { status } }'
def post(url, body, extra=()):
    out = subprocess.run(["curl","-sS","-m","60","-H","content-type: application/json",*extra,"-d",json.dumps(body),url],capture_output=True,text=True).stdout
    return json.loads(out)
ADDRS = ["0x1f158929496162b53fb232536468948e25170ab3","0x39ac882a1161ea19acb6fbdd7a5835d96cf876eb","0xf7c024f7bc96cf152a572f6e184318ff6d380738","0x97face21c7a9f3b64d0f4e0bf21861721fbbfe3e","0x9e75eabf8d1c905a07a0c99bb9ec9430a065358f","0x00423ebaed03445fc1452d9a79a51e3c0dfdab5f","0x1aa665eb420f28103324daaaf034de13ee6f53d9","0xf1122bc96adea8768cff2badf02b6d4594f928cc"]
STACKER = ("0x06909f672301f28a810f78cfe7a754851269f4f0", ["0x7fbd7b0bc9aac1aa6f42ea64666fad17288ea759411a11f4231a958bc31838c6","0x000000000000000000000000f1122bc96adea8768cff2badf02b6d4594f928cc"])
items, after, meta = [], None, None
while True:
    r = post(gql, {"query": Q, "variables": {"from": str(frm), "to": "999999999" if to == "meta" else to, "after": after}})
    if "errors" in r: sys.exit(f"graphql error: {r['errors']}")
    page = r["data"]["rawLogs"]; meta = meta or r["data"]["_meta"]["status"]
    items += page["items"]
    if not page["pageInfo"]["hasNextPage"]: break
    after = page["pageInfo"]["endCursor"]
print("_meta.status", json.dumps(meta))
indexed = int(list(meta.values())[0]["block"]["number"])
hi = indexed if to == "meta" else min(int(to), indexed)
items = [x for x in items if int(x["blockNumber"]) <= hi]
def gl(p):
    r = post(rpc, {"jsonrpc":"2.0","id":1,"method":"eth_getLogs","params":[p]})
    if "error" in r: sys.exit(f"rpc error {r['error']}")
    return r["result"]
want = []
step = 2000
for a in range(frm, hi + 1, step):
    b = min(hi, a + step - 1)
    want += gl({"fromBlock":hex(a),"toBlock":hex(b),"address":ADDRS})
    want += gl({"fromBlock":hex(a),"toBlock":hex(b),"address":STACKER[0],"topics":STACKER[1]})
want.sort(key=lambda l:(int(l["blockNumber"],16),int(l["logIndex"],16)))
got = sorted(items, key=lambda x:(int(x["blockNumber"]),int(x["logIndex"])))
bad = 0
if len(got) != len(want): print(f"COUNT differs: indexer {len(got)} eth_getLogs {len(want)}"); bad += 1
blk = {}
for g, w in zip(got, want):
    t = [g[f"topic{i}"] for i in range(4) if g[f"topic{i}"] is not None]
    pairs = [("blockNumber", int(g["blockNumber"]), int(w["blockNumber"],16)), ("logIndex", g["logIndex"], int(w["logIndex"],16)),
             ("blockHash", g["blockHash"], w["blockHash"]), ("transactionHash", g["transactionHash"], w["transactionHash"]),
             ("transactionIndex", g["transactionIndex"], int(w["transactionIndex"],16)), ("address", g["address"], w["address"].lower()),
             ("topics", t, w["topics"]), ("data", g["data"], w["data"])]
    if "blockTimestamp" in w: pairs.append(("blockTimestamp", int(g["blockTimestamp"]), int(w["blockTimestamp"],16)))
    else: blk.setdefault(w["blockNumber"], []).append((g, w))
    for k, x, y in pairs:
        if x != y: print(f"DIFF {g['blockNumber']}-{g['logIndex']} {k}: {x} vs {y}"); bad += 1
    if g["address"] != g["address"].lower(): print("address not lowercase", g["address"]); bad += 1
for bn, lst in blk.items():
    ts = int(post(rpc, {"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":[bn, False]})["result"]["timestamp"],16)
    for g, w in lst:
        if int(g["blockTimestamp"]) != ts: print(f"DIFF {g['blockNumber']} blockTimestamp {g['blockTimestamp']} vs {ts}"); bad += 1
print(f"range {frm}..{hi}: indexer {len(got)} logs, eth_getLogs {len(want)} logs, {'EQUAL' if not bad else str(bad)+' differences'}")
sys.exit(1 if bad else 0)
