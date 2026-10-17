#!/usr/bin/env bash
# Close run-2 season $1 (default 1) if nobody has yet (lists its unrecorded approved pleas), then report.
set -uo pipefail
export PATH=$HOME/.foundry/bin:$PATH
R=https://ethereum-sepolia-rpc.publicnode.com
G=0xe3717b69977d73b68aa2af798ddd4eec3609a4ed; S=0xde8334d251c65a9007f290a7cb71f0c98887bc54; P=0x2f4ad5c8b4cd47a80356e07ef47d8ae875e9c795
A=0x4b91078b2374c956a65f7af0999cae0a935e6821; SEASON=${1:-1}
c(){ cast call "$@" --rpc-url $R | awk '{print $1}' | tr '\n' ' '; }
log(){ echo "$(date -u +%H:%M:%S) $*"; }
start=$(c $G 'startedAt()(uint64)'); n=$(c $G 'nextId()(uint256)')
log "season $SEASON closed=$(c $S 'closed(uint256)(bool)' $SEASON) nextToClose=$(c $S 'nextToClose()(uint256)') rollover=$(c $S 'rollover()(uint256)') seasonFees=$(c $S 'seasonFees(uint256)(uint256)' $SEASON) bonusBurned=$(c $S 'bonusBurned()(uint256)') seasonsPLEA=$(c $P 'balanceOf(address)(uint256)' $S)"
ids=()
for ((i=1;i<${n// /};i++)); do
  read seller score ok vat <<<"$(cast call $G 'result(uint256)(address,uint8,bool,uint64)' $i --rpc-url $R | awk '{print $1}' | tr '\n' ' ')"
  [ "$vat" = "0" ] && continue
  s=$(( (vat - ${start// /}) / 18000 ))
  rec=$(c $S 'recorded(uint256)(bool)' $i)
  log "plea $i seller $seller score $score approved $ok season $s recorded $rec"
  [ "$ok" = "true" ] && [ "$s" = "$SEASON" ] && [ "$rec" = "false " ] && ids+=($i)
done
if [ "$(c $S 'closed(uint256)(bool)' $SEASON)" = "false " ]; then
  arg="[$(IFS=,; echo "${ids[*]:-}")]"; log "closeSeason($arg)"
  for i in $(seq 1 30); do [ "$(cast nonce $A --block latest --rpc-url $R)" = "$(cast nonce $A --block pending --rpc-url $R)" ] && break; log "nonce: a tx from A is pending, waiting"; sleep 4; done
  est=$(cast estimate --from $A $S 'closeSeason(uint256[])' "$arg" --rpc-url $R 2>&1) || { log "estimate fails: ${est:0:160}"; exit 1; }
  cast send --private-key "$PONDPAD_TESTNET_KEY" --gas-limit $((est*13/10)) --gas-price 0.02gwei --priority-gas-price 0.01gwei $S 'closeSeason(uint256[])' "$arg" --rpc-url $R --json | jq -c '{tx:.transactionHash,status:.status,gas:.gasUsed,block:.blockNumber}'
fi
log "after: closed=$(c $S 'closed(uint256)(bool)' $SEASON) rollover=$(c $S 'rollover()(uint256)') bonusBurned=$(c $S 'bonusBurned()(uint256)') seasonsPLEA=$(c $P 'balanceOf(address)(uint256)' $S) A_PLEA=$(c $P 'balanceOf(address)(uint256)' $A)"
cast call $S 'topOf(uint256)((address,uint16,uint64)[10])' $SEASON --rpc-url $R | cut -c1-400
