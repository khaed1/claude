#!/usr/bin/env bash
# Builds the run 9 "base" fork state for site tests and dumps it, so a tester starts from a seeded court in seconds.
#   plea/site-design/tools/fork-base.sh <port> <out dir>
# A local anvil fork of Sepolia at block 11,962,600 (before run 9's seed; ethpandaops is an archive node, so the fork
# never decays), then through plea/tools/live85.py on the fork only (FORK=1: wallet A and IMD's writer impersonated,
# the gate's and the Tribunal's oracleSigner set to a test key so `fork-answer` signs verdicts):
#   seed by wallet A, A's 2 imdTEST opening buy, 8 throwaway players p1..p8 (keys in <out>/state/players.env),
#   1 ETH + 10 imdTEST each (balance slot written), every approval, a distributor root giving p1..p8 2,500,000 PLEA each
#   and A 20,000,000 (claimed), the 90-minute launch window warped past, then 1.25 imdTEST buys by p1..p4 (a buy record),
#   and an IMD seat (test NFT) for p5.
# Writes <out>/base.json (anvil_dumpState), <out>/state/ (players, tree.json, log.jsonl), <out>/base.env (time, block).
# Reload:  anvil --fork-url https://rpc.sepolia.ethpandaops.io --fork-block-number 11962600 --port <p> --silent &
#          cast rpc anvil_loadState "$(cat <out>/base.json)" --rpc-url http://127.0.0.1:<p>   (see FORK-KIT.md)
set -euo pipefail
PORT=${1:?port}; OUT=${2:?out dir}
HERE=$(cd "$(dirname "$0")" && pwd); TOOLS=$HERE/../../tools
mkdir -p "$OUT"; R=http://127.0.0.1:$PORT
anvil --fork-url https://rpc.sepolia.ethpandaops.io --fork-block-number 11962600 --port "$PORT" --silent > "$OUT/anvil.log" 2>&1 &
APID=$!; for _ in $(seq 60); do cast block-number --rpc-url $R >/dev/null 2>&1 && break; sleep 1; done
export STATE_DIR=$OUT/state RPC=$R FORK=1 ADDRS=$HERE/../../live-run9/addresses.json
P() { python3 -I "$TOOLS/live85.py" "$@"; }
IMD=0x56bcf2a5F47710649A4091219Ef0b56e2d1B58BF
give() { # $1 address, $2 wei: writes the imdTEST balance (mapping at slot 0)
  cast rpc anvil_setStorageAt $IMD "$(cast index address "$1" 0)" "$(cast to-uint256 "$2")" --rpc-url $R >/dev/null; }
P fork-init
P seed | tail -1
P buy a 2 | tail -1
P new-players 8 >/dev/null
P fund 1 p1 p2 p3 p4 p5 p6 p7 p8 >/dev/null
for n in p1 p2 p3 p4 p5 p6 p7 p8; do give "$(python3 -c "import json;print(json.load(open('$STATE_DIR/players.json'))['$n'])")" 10000000000000000000; done
P approve p1 p2 p3 p4 p5 p6 p7 p8 >/dev/null
P tree 2500000 20000000 >/dev/null
P set-root | tail -1
P claim a p1 p2 p3 p4 p5 p6 p7 p8 a | tail -9
P fork-warp 5460 >/dev/null     # 91 minutes: the launch window is over
for n in p1 p2 p3 p4; do P buy $n 1.25 | tail -1; done
P seat p5 99005 | tail -1
cast rpc anvil_dumpState --rpc-url $R | tr -d '"' > "$OUT/base.hex"
echo "BASE_BLOCK=$(cast block-number --rpc-url $R)" > "$OUT/base.env"
echo "BASE_TIME=$(cast block latest --field timestamp --rpc-url $R)" >> "$OUT/base.env"
P state | head -3
kill $APID
echo "base state: $OUT/base.hex ($(wc -c < "$OUT/base.hex") bytes), $(cat "$OUT/base.env" | tr '\n' ' ')"
