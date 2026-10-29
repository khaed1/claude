#!/usr/bin/env bash
# PLEA's REAL Ethereum deployment (launch #2647 + the three deploy calls) on a local anvil fork, BEFORE the seed,
# for the site's tests at the real addresses. Nothing here touches a public chain: every write goes to the local anvil.
#   FORK_BLOCK=<a block after 26,294,113> tools/mainnet/real-fork.sh <port> <out dir>
# Starts anvil (dRPC archive with retries, as deploy.mjs), then: the owner 0x5BF3…9Bf0 impersonated (10 ETH,
# 30 IMD from an IMD holder); players p1..p8 with keys derived by live85.py (players.derive, label
# plea-eth-fork-p; FORK=1 without PONDPAD_TESTNET_KEY derives them from a dummy key, fork only), 2 ETH + 30 IMD
# each; identity.md seat #558 moved to p5; live85.py fork-init (the gate's and the Tribunal's oracleSigner = the
# test key 0xa11ce, the Intake writer impersonated). Writes <out>/addresses.json (fork-deployment.mjs's input and
# live85.py's ADDRS), <out>/state/ (live85.py's STATE_DIR), <out>/pre.hex (anvil_dumpState; reload it with
# FORK_BLOCK=<the same block> tools/mainnet/fork-load.sh <port> <out>/pre.hex). Prints the anvil pid; anvil keeps running.
# Upstream (2026-10-29): dRPC's free plan now refuses eth_getLogs over ~100 blocks, which breaks the site's history scan
# and an indexer's backfill on the fork: for history tests reload with FORK_URL=https://mainnet.gateway.tenderly.co
# (it answers 500-block ranges; it may 429 for a few minutes under bursts).
set -euo pipefail
PORT=${1:?port}; OUT=${2:?out dir}; R=http://127.0.0.1:$PORT
BLOCK=${FORK_BLOCK:?FORK_BLOCK: a block after the deploys}
HERE=$(cd "$(dirname "$0")" && pwd); LIVE85=$(cd "$HERE/../../../tools" && pwd)/live85.py
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
OWNER=0x5BF3597216f9019Cf10CF680783289Efc8639Bf0
IMD=0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7
WHALE=0xe54d6571aca515614927f3a70b8957c2b511603c
SEAT=0x0000ec93127baa929e58e97dd0095a2bfb38ec1d; SEAT_ID=558; SEAT_HOLDER=0xf98c3bf5f3544f64e60560304b58dca900a3c4db

anvil --fork-url "${FORK_URL:-https://eth.drpc.org}" --fork-block-number "$BLOCK" --port "$PORT" --chain-id 1 \
  --gas-limit 200000000 --retries 12 --fork-retry-backoff 1500 --compute-units-per-second 120 --silent > "/tmp/anvil-$PORT.log" 2>&1 &
APID=$!
for _ in $(seq 120); do cast block-number --rpc-url $R >/dev/null 2>&1 && break; sleep 1; done

cat > "$OUT/addresses.json" <<EOF
{
 "chainId": 1, "deployBlock": 26293890, "forkBlock": $BLOCK, "owner": "$OWNER",
 "PLEA": "0x1f158929496162b53fb232536468948e25170ab3", "CabalGate": "0x39ac882a1161ea19acb6fbdd7a5835d96cf876eb",
 "Seasons": "0xf7c024f7bc96cf152a572f6e184318ff6d380738", "PleaDistributor": "0x97face21c7a9f3b64d0f4e0bf21861721fbbfe3e",
 "PleaLaunch": "0x9e75eabf8d1c905a07a0c99bb9ec9430a065358f", "Letterbox": "0x00423EbaEd03445Fc1452d9A79A51E3C0DFdab5f",
 "Tribunal": "0x1aA665eB420F28103324daAAf034DE13EE6f53D9", "PleaHook": "0xf1122bc96AdeA8768CFf2badf02b6D4594f928Cc",
 "GATE": "0x39ac882a1161ea19acb6fbdd7a5835d96cf876eb", "SEASONS": "0xf7c024f7bc96cf152a572f6e184318ff6d380738",
 "DISTRIBUTOR": "0x97face21c7a9f3b64d0f4e0bf21861721fbbfe3e", "LAUNCH": "0x9e75eabf8d1c905a07a0c99bb9ec9430a065358f",
 "LETTERBOX": "0x00423EbaEd03445Fc1452d9A79A51E3C0DFdab5f", "TRIBUNAL": "0x1aA665eB420F28103324daAAf034DE13EE6f53D9",
 "HOOK": "0xf1122bc96AdeA8768CFf2badf02b6D4594f928Cc", "IMD": "$IMD", "ORACLE": "$IMD"
}
EOF
L85() { RPC=$R FORK=1 STATE_DIR="$OUT/state" ADDRS="$OUT/addresses.json" GAS_PRICE=5gwei PRIO=1gwei python3 -I "$LIVE85" "$@"; }

for a in $OWNER $WHALE $SEAT_HOLDER; do cast rpc anvil_impersonateAccount $a --rpc-url $R >/dev/null; cast rpc anvil_setBalance $a 0x8ac7230489e80000 --rpc-url $R >/dev/null; done
tx() { cast send "$@" --unlocked --rpc-url $R --gas-price 5gwei --priority-gas-price 1gwei --json | python3 -c "import json,sys; r=json.load(sys.stdin); assert int(r['status'],16)==1, r['transactionHash']"; }
tx --from $WHALE $IMD 'transfer(address,uint256)' $OWNER 30ether
mkdir -p "$OUT/state"; chmod 700 "$OUT/state"
[ -f "$OUT/state/players.json" ] || L85 derive-players 8 plea-eth-fork-p
for i in 1 2 3 4 5 6 7 8; do
  P=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['p$i'])" "$OUT/state/players.json")
  cast rpc anvil_setBalance $P 0x1bc16d674ec80000 --rpc-url $R >/dev/null
  tx --from $WHALE $IMD 'transfer(address,uint256)' $P 30ether
done
P5=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['p5'])" "$OUT/state/players.json")
tx --from $SEAT_HOLDER $SEAT 'transferFrom(address,address,uint256)' $SEAT_HOLDER $P5 $SEAT_ID
L85 fork-init
echo "owner IMD $(cast call $IMD 'balanceOf(address)(uint256)' $OWNER --rpc-url $R); seat #$SEAT_ID owner $(cast call $SEAT 'ownerOf(uint256)(address)' $SEAT_ID --rpc-url $R)" >&2
cast rpc anvil_dumpState --rpc-url $R | tr -d '"' > "$OUT/pre.hex"
echo "pre-seed state at block $(cast block-number --rpc-url $R): $OUT/pre.hex" >&2
echo "$APID"
