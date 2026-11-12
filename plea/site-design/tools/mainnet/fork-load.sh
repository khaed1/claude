#!/usr/bin/env bash
# Starts a local anvil fork of Ethereum (block 26,278,700, dRPC archive with retries) on <port> and loads a dumped
# state into it (base.mjs's base.hex). Prints the anvil pid.   tools/mainnet/fork-load.sh <port> <state.hex>
set -euo pipefail
PORT=${1:?port}; HEX=${2:?state hex}; R=http://127.0.0.1:$PORT
anvil --fork-url "${FORK_URL:-https://eth.drpc.org}" --fork-block-number "${FORK_BLOCK:-26278700}" --port "$PORT" --chain-id 1 \
  --gas-limit 200000000 --retries 12 --fork-retry-backoff 1500 --compute-units-per-second 120 --silent > "/tmp/anvil-$PORT.log" 2>&1 &
APID=$!
for _ in $(seq 120); do cast block-number --rpc-url $R >/dev/null 2>&1 && break; sleep 1; done
python3 -c "import json,sys; json.dump({'jsonrpc':'2.0','id':1,'method':'anvil_loadState','params':[open(sys.argv[1]).read().strip()]}, open(sys.argv[2],'w'))" "$HEX" "/tmp/anvil-$PORT-load.json"
curl -sS -X POST -H 'content-type: application/json' --data @"/tmp/anvil-$PORT-load.json" $R | grep -q '"result":true' || { echo "load failed"; kill $APID; exit 1; }
rm -f "/tmp/anvil-$PORT-load.json"
echo "$APID"
