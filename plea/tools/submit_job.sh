#!/usr/bin/env bash
# Submits one job.open or job.continue from wallet A on Ethereum (the user's go-ahead first; 0.5 IMD).
# usage: plea/tools/submit_job.sh <request.json>   ({action: "job.continue", input: {...}}; free-check it first)
# Key: env PONDPAD_TESTNET_KEY (never printed). Body: the `input`, compact JSON.
# A job.continue must come from the wallet that paid for the parent (else payer_not_owner, payment spent).
# Job id: GET https://api.imd.fun/intake/1/<tx> -> entries[0].admission.result.jobId (a minute or two later).
set -euo pipefail
REQ=$1
R=https://ethereum-rpc.publicnode.com
IMD=0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7; INTAKE=0xa43e6F75ee006411F79Ac1C84120606C2330DE82
FROM=0x4b91078b2374c956A65F7Af0999CaE0a935E6821
KIND=$(jq -r .action "$REQ")
case "$KIND" in job.open|job.continue) ;; *) echo "not a job.open or job.continue request"; exit 1 ;; esac
[ "$(cast nonce --rpc-url $R --block latest $FROM)" = "$(cast nonce --rpc-url $R --block pending $FROM)" ] \
  || { echo "wallet A has a pending transaction; wait for it"; exit 1; }
ACTION=$(cast format-bytes32-string "$KIND@job-1")
send() {
  local g; g=$(cast estimate --rpc-url $R --from $FROM "$@")
  cast send --rpc-url $R --private-key "$PONDPAD_TESTNET_KEY" --gas-limit $((g * 13 / 10)) --json "$@" | jq -r '"\(.transactionHash) status \(.status)"'
}
echo "approve: $(send $IMD 'approve(address,uint256)' $INTAKE 500000000000000000)"
# The public RPC is load-balanced: a node may not have the approve yet, and the request's estimate then
# reverts ERC20InsufficientAllowance (seen 2026-10-20). Read the allowance until it shows.
for _ in $(seq 60); do
  [ "$(cast call --rpc-url $R $IMD 'allowance(address,address)(uint256)' $FROM $INTAKE | cut -d' ' -f1)" -ge 500000000000000000 ] && break
done
BODY=0x$(python3 -c "import json,sys;print(json.dumps(json.load(open(sys.argv[1]))['input'],separators=(',',':')).encode().hex())" "$REQ")
echo "request: $(send $INTAKE 'request(bytes32,bytes,(address,bytes4),address,uint256)' $ACTION $BODY '(0x0000000000000000000000000000000000000000,0x00000000)' $IMD 500000000000000000)"
