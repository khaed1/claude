#!/usr/bin/env bash
# Submits one launch job from wallet A on Ethereum (the user's go-ahead first; 0.5 IMD).
# usage: plea/tools/submit_launch.sh <request.json>   ({action: "launch.open", input: {...}}; free-check it first)
# Key: env PONDPAD_TESTNET_KEY (never printed). Body: the `input`, compact JSON.
# Job id: GET https://api.imd.fun/intake/1/<tx> -> entries[0].admission.result.jobId (a minute or two later).
set -euo pipefail
REQ=$1
R=https://ethereum-rpc.publicnode.com
IMD=0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7; INTAKE=0xa43e6F75ee006411F79Ac1C84120606C2330DE82
FROM=0x4b91078b2374c956A65F7Af0999CaE0a935E6821
[ "$(jq -r .action "$REQ")" = "launch.open" ] || { echo "not a launch.open request"; exit 1; }
ACTION=$(cast format-bytes32-string "launch.open@launch-1")
send() {
  local g; g=$(cast estimate --rpc-url $R --from $FROM "$@")
  cast send --rpc-url $R --private-key "$PONDPAD_TESTNET_KEY" --gas-limit $((g * 13 / 10)) --json "$@" | jq -r '"\(.transactionHash) status \(.status)"'
}
echo "approve: $(send $IMD 'approve(address,uint256)' $INTAKE 500000000000000000)"
BODY=0x$(python3 -c "import json,sys;print(json.dumps(json.load(open(sys.argv[1]))['input'],separators=(',',':')).encode().hex())" "$REQ")
echo "launch: $(send $INTAKE 'request(bytes32,bytes,(address,bytes4),address,uint256)' $ACTION $BODY '(0x0000000000000000000000000000000000000000,0x00000000)' $IMD 500000000000000000)"
