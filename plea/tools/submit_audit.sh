#!/usr/bin/env bash
# Submits audit jobs from wallet A on Ethereum (the user's go-ahead first; 0.5 IMD each).
# usage: plea/tools/submit_audit.sh <khaed1/plea checkout>/audit/rounds/<n> A1 [A2 A3]
# Key: env PONDPAD_TESTNET_KEY (never printed). Bodies: the `input` of each <area>.request.json, compact JSON.
# Job ids: GET https://api.imd.fun/intake/1/<tx> -> entries[0].admission.result.jobId (a minute or two later).
set -euo pipefail
DIR=$1; shift
R=https://ethereum-rpc.publicnode.com
IMD=0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7; INTAKE=0xa43e6F75ee006411F79Ac1C84120606C2330DE82
FROM=0x4b91078b2374c956A65F7Af0999CaE0a935E6821
ACTION=$(cast format-bytes32-string "job.open@job-1")
send() {
  local g; g=$(cast estimate --rpc-url $R --from $FROM "$@")
  cast send --rpc-url $R --private-key "$PONDPAD_TESTNET_KEY" --gas-limit $((g * 13 / 10)) --json "$@" | jq -r '"\(.transactionHash) status \(.status)"'
}
echo "approve: $(send $IMD 'approve(address,uint256)' $INTAKE $(( $# * 500000000000000000 )))"
for a in "$@"; do
  BODY=0x$(python3 -c "import json,sys;print(json.dumps(json.load(open(sys.argv[1]))['input'],separators=(',',':')).encode().hex())" "$DIR/$a.request.json")
  echo "$a: $(send $INTAKE 'request(bytes32,bytes,(address,bytes4),address,uint256)' $ACTION $BODY '(0x0000000000000000000000000000000000000000,0x00000000)' $IMD 500000000000000000)"
done
