#!/usr/bin/env bash
# usage: run_suite.sh <repo dir> <log dir>   — the whole suite in groups; plain grep FAIL; totals summed
# Layouts: test/*.t.sol (default profile skips fork/invariant/adversarial), or the light layout with the
# suite in test/full/ (skipped by the default profile: every group then runs under FOUNDRY_PROFILE=full).
set -u
export PATH=/root/.local/bin:$PATH
export SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com MAINNET_RPC_URL=https://ethereum-rpc.publicnode.com
cd "$1"; L=$2; mkdir -p "$L"; rm -f "$L/no-result.txt" "$L"/*.log
if [ -d test/full ]; then
  plainprof=full
  files=$( (ls test/*.t.sol test/full/*.t.sol) 2>/dev/null )
else
  plainprof=default
  files=$(ls test/*.t.sol)
fi
plain=$(echo "$files" | grep -vE 'Invariant|Adversarial')
heavy=$(echo "$files" | grep -E 'Invariant|Adversarial')
run() { # name profile glob
  local n=$1 prof=$2 glob=$3
  echo "== $n ($(date -u +%H:%M:%S))"
  FOUNDRY_PROFILE=$prof forge test --match-path "$glob" > "$L/$n.log" 2>&1
  if ! grep -qE "^Ran [0-9]+ test suites?" "$L/$n.log"; then
    echo "NO RESULT (compile error or crash): $(grep -m1 -E '^Error' "$L/$n.log")"
    echo "$n" >> "$L/no-result.txt"
  fi
  grep -E "^Ran [0-9]+ test suites?" "$L/$n.log" | tail -1
  grep FAIL "$L/$n.log" | head -20
}
group() { # name-prefix profile size file-list
  local pre=$1 prof=$2 size=$3 list=$4 i=0
  for dir in $(echo "$list" | xargs -n1 dirname | sort -u); do
    local names; names=$(echo "$list" | grep "^$dir/[^/]*$" | xargs -n1 basename | sed 's/\.t\.sol$//')
    for chunk in $(echo "$names" | xargs -n$size | tr ' ' ','); do
      i=$((i+1)); case "$chunk" in *,*) run "$pre$i" $prof "$dir/{$chunk}.t.sol";; *) run "$pre$i" $prof "$dir/$chunk.t.sol";; esac
    done
  done
}
group plain $plainprof 9 "$plain"
group heavy full 6 "$heavy"
run forkSepolia full "test/fork/ForkTestnet.t.sol"
run forkMainnet full "test/fork/ForkMainnet.t.sol"
echo "== totals"
cat "$L"/*.log | grep -E "^Ran [0-9]+ test suites?" | awk '{s+=$2; p+=$(NF-9); f+=$(NF-6)} END {print "suites", s, "passed", p, "failed", f}'
if [ -s "$L/no-result.txt" ]; then
  echo "GROUPS WITHOUT A RESULT (their tests did not run): $(tr '\n' ' ' < "$L/no-result.txt")"
  exit 1
fi
