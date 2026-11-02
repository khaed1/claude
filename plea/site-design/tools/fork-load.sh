#!/usr/bin/env bash
# Starts a local anvil fork of Sepolia (block 11,962,600, ethpandaops archive) on <port> and loads a dumped state into it
# (fork-base.sh's base.hex, or any later anvil_dumpState you saved). Prints the anvil pid.
#   plea/site-design/tools/fork-load.sh <port> <state.hex>
# Save a state:  curl -s -X POST -H 'content-type: application/json' \
#   -d '{"jsonrpc":"2.0","id":1,"method":"anvil_dumpState","params":[]}' http://127.0.0.1:<port> | jq -r .result > my.hex
set -euo pipefail
PORT=${1:?port}; HEX=${2:?state hex file}; R=http://127.0.0.1:$PORT
anvil --fork-url https://rpc.sepolia.ethpandaops.io --fork-block-number 11962600 --port "$PORT" --silent > "/tmp/anvil-$PORT.log" 2>&1 &
APID=$!
for _ in $(seq 60); do cast block-number --rpc-url $R >/dev/null 2>&1 && break; sleep 1; done
python3 -c "import json,sys; json.dump({'jsonrpc':'2.0','id':1,'method':'anvil_loadState','params':[open(sys.argv[1]).read().strip()]}, open(sys.argv[2],'w'))" "$HEX" "/tmp/anvil-$PORT-load.json"
curl -sS -X POST -H 'content-type: application/json' --data @"/tmp/anvil-$PORT-load.json" $R | grep -q '"result":true' || { echo "load failed"; kill $APID; exit 1; }
rm -f "/tmp/anvil-$PORT-load.json"
echo "$APID"
