#!/usr/bin/env bash
# One season-3 slot for wallet A on PLEA run 2: wait until START, plead 10% of the balance with
# text file $2; if denied, appeal once with text file $3; if approved, sell within the window and
# record. A plea cleared with no verdict is re-sent once. Every send is gas-estimated first.
set -uo pipefail
export PATH=$HOME/.foundry/bin:$PATH
R=https://ethereum-sepolia-rpc.publicnode.com
G=0xe3717b69977d73b68aa2af798ddd4eec3609a4ed; S=0xde8334d251c65a9007f290a7cb71f0c98887bc54; P=0x2f4ad5c8b4cd47a80356e07ef47d8ae875e9c795
A=0x4b91078b2374c956a65f7af0999cae0a935e6821
START=$1; PT=$(cat "$2"); AT=$(cat "$3")
log(){ echo "$(date -u +%H:%M:%S) $*"; }
num(){ awk '{print $1}'; }
send(){ local est; est=$(cast estimate --from $A "$@" --rpc-url $R 2>&1) || { log "estimate fails for $2: ${est:0:200}"; return 1; }
  log "send $2 est $est"
  cast send --private-key "$PONDPAD_TESTNET_KEY" --gas-limit $((est*13/10)) --gas-price 0.02gwei --priority-gas-price 0.01gwei "$@" --rpc-url $R --json \
    | jq -c '{tx:.transactionHash,status:.status,gas:.gasUsed,block:.blockNumber}'; }
st(){ cast call $G 'getPlea(uint256)((address,uint8,uint8,uint8,uint8,bool,bool,uint128,uint64,uint64,uint64,bytes32,string))' $1 --rpc-url $R \
  | python3 -c "import sys;f=[x.split(' [')[0].strip() for x in sys.stdin.read().strip('()\n').split(', ')];print(f[1],f[2],f[3],f[4],f[9])"; }
# wait for verdict: echoes "score status verdictAt"; status 1 = still pending after 22 min
wait_verdict(){ local id=$1 f n sc s v; for i in $(seq 1 132); do read f n sc s v <<<"$(st $id)"; [ "$s" != "1" ] && break; sleep 10; done; echo "$sc $s $v"; }
sell_record(){ local id=$1 vat=$2 out
  out=$(cast call --from $A $G 'executeSell(uint256)(uint256)' 0 --rpc-url $R | num); log "preview $out"
  send $G 'executeSell(uint256)' $(python3 -c "print($out*99//100)") || return 1
  send $S 'record(uint256)' $id
  log "season $(( (vat - $(cast call $G 'startedAt()(uint64)' --rpc-url $R | num)) / 18000 )) bestOf(3,A) $(cast call $S 'bestOf(uint256,address)(uint8[3])' 3 $A --rpc-url $R)"
  log "DONE approved plea $id; cooldown ends $(date -u -d @$(( $(cast call $G 'lastExecutedAt(address)(uint256)' $A --rpc-url $R | num) + 14400 )) +%H:%M:%S)"; }
# plead (or appeal) and handle a cleared-without-verdict request by re-sending once
ask(){ local kind=$1 tries=0 id r sc s v
  while [ $tries -lt 2 ]; do tries=$((tries+1))
    if [ $kind = plea ]; then send $G 'submitSell(uint256,string)' $AMT "$PT" || return 1
    else send $G 'appeal(uint256,uint256,string)' $ORIG $AMT "$AT" || return 1; fi
    id=$(cast call $G 'pendingOf(address)(uint256)' $A --rpc-url $R | num); read f n _ _ _ <<<"$(st $id)"; log "$kind id $id fact $f need $n"
    read sc s v <<<"$(wait_verdict $id)"; log "$kind $id status $s score $sc verdictAt $v"
    if [ "$s" = "1" ]; then send $G 'expire(uint256)' $id; continue; fi
    [ "$s" = "6" ] && continue
    LAST=$id; LASTS=$s; LASTV=$v; return 0
  done; return 1; }
while [ "$(date -u +%s)" -lt "$START" ]; do sleep 5; done
BAL=$(cast call $P 'balanceOf(address)(uint256)' $A --rpc-url $R | num); AMT=$(python3 -c "print($BAL//10)")
log "start: balance $BAL amount $AMT plea bytes $(printf '%s' "$PT" | wc -c) appeal bytes $(printf '%s' "$AT" | wc -c)"
ask plea || { log "DONE failed: plea not answered"; exit 1; }
[ "$LASTS" = "2" ] && { sell_record $LAST $LASTV; exit 0; }
ORIG=$LAST; log "denied; appealing plea $ORIG"
ask appeal || { log "DONE failed: appeal not answered"; exit 1; }
[ "$LASTS" = "2" ] && { sell_record $LAST $LASTV; exit 0; }
log "DONE denied twice (plea $ORIG, appeal $LAST)"
