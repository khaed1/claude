#!/usr/bin/env bash
# usage: run_suite.sh <repo dir> <log dir>   — the whole suite in groups; plain grep FAIL; totals summed
set -u
export PATH=/root/.local/bin:$PATH
export SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com MAINNET_RPC_URL=https://ethereum-rpc.publicnode.com
cd "$1"; L=$2; mkdir -p "$L"
plain=$(ls test/*.t.sol | grep -vE 'Invariant|Adversarial' | xargs -n1 basename | sed 's/\.t\.sol$//')
heavy=$(ls test/*.t.sol | grep -E 'Invariant|Adversarial' | xargs -n1 basename | sed 's/\.t\.sol$//')
run() { # name profile glob
  local n=$1 prof=$2 glob=$3
  echo "== $n ($(date -u +%H:%M:%S))"
  FOUNDRY_PROFILE=$prof forge test --match-path "$glob" > "$L/$n.log" 2>&1
  grep -E "^Ran [0-9]+ test suites?" "$L/$n.log" | tail -1
  grep FAIL "$L/$n.log" | head -20
}
i=0; for chunk in $(echo "$plain" | xargs -n9 | tr ' ' ','); do i=$((i+1)); run "plain$i" default "test/{$chunk}.t.sol"; done
i=0; for chunk in $(echo "$heavy" | xargs -n6 | tr ' ' ','); do i=$((i+1)); run "heavy$i" full "test/{$chunk}.t.sol"; done
run forkSepolia full "test/fork/ForkTestnet.t.sol"
run forkMainnet full "test/fork/ForkMainnet.t.sol"
echo "== totals"
cat "$L"/*.log | grep -E "^Ran [0-9]+ test suites?" | awk '{s+=$2; p+=$(NF-9); f+=$(NF-6)} END {print "suites", s, "passed", p, "failed", f}'
