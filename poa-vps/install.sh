#!/bin/bash
# Install the PoA (minepoa.com) worker on this VPS as an isolated user. Run as root.
# Usage: bash install.sh      (run it again after signing the worker user in to Claude)
# Needs /opt/node24 and /opt/reset-claude from the RESET installer. Never overwrites a wallet.
set -euo pipefail

BUNDLE="$(cd "$(dirname "$0")" && pwd)"
CLIENT_URL=https://minepoa.com/client/poa.mjs
CLIENT_SHA=89b8a10673333d5980f2b67d3e058aada530629ace12bcf2677ea6441f49c374   # reviewed v0.3
U=poa-worker
UH=/home/$U
NODE=/opt/node24/bin/node
CLAUDE=/opt/reset-claude/bin/claude

say() { printf '\n== %s\n' "$*"; }
die() { printf '\nSTOPPED: %s\n' "$*" >&2; exit 1; }

say "Checking this machine"
[ "$(id -u)" = 0 ] || die "run as root"
command -v systemctl >/dev/null || die "systemd is required"
[ -x $NODE ] || die "$NODE missing (install the RESET bundle first)"
[ -x $CLAUDE ] || die "$CLAUDE missing (install the RESET bundle first)"
echo "node $($NODE -v), claude $(PATH=/opt/node24/bin:$PATH $CLAUDE --version)"

say "Worker user $U (no sudo, no login shell needed)"
if ! id $U >/dev/null 2>&1; then useradd --create-home --shell /bin/bash $U; fi
chmod 700 $UH
install -d -m 700 -o $U -g $U $UH/poa $UH/poa-cache $UH/poa-agent $UH/poa-agent/logs $UH/poa-agent/work
cd $UH   # commands below run as $U, which cannot enter root's home

say "PoA client (pinned to the reviewed version)"
tmp="$(mktemp)"; curl -fsS --max-time 120 -o "$tmp" $CLIENT_URL || die "could not download $CLIENT_URL (site busy? run again later)"
got="$(sha256sum "$tmp" | cut -d' ' -f1)"
if [ "$got" != "$CLIENT_SHA" ]; then
  rm -f "$tmp"
  die "the site now serves a different client (sha256 $got). It has not been reviewed, so nothing was installed or changed."
fi
install -d -m 755 /opt/poa
install -m 644 "$tmp" /opt/poa/poa.mjs; rm -f "$tmp"
install -m 755 "$BUNDLE"/poa_worker.py /opt/poa/poa_worker.py
install -m 755 "$BUNDLE"/poactl /opt/poa/poactl
ln -sf /opt/poa/poactl /usr/local/bin/poactl
echo "client sha256 $CLIENT_SHA"

say "Limits (root-owned, the worker cannot change them)"
install -d -m 755 /etc/poa-worker
if [ ! -e /etc/poa-worker/config.json ]; then
  start="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"; end="$(date -u -d '+7 days' +%Y-%m-%dT%H:%M:%S+00:00)"
  cat > /etc/poa-worker/config.json <<EOF
{
 "budget_usd": 15.0,
 "per_run_max_usd": 0.15,
 "start": "$start",
 "end": "$end",
 "model": "sonnet"
}
EOF
  chmod 644 /etc/poa-worker/config.json
fi
cat /etc/poa-worker/config.json

say "Claude sign-in for $U (its own; root's sign-in does not count)"
if ! runuser -u $U -- env HOME=$UH PATH=/opt/node24/bin:/usr/bin:/bin $CLAUDE auth status 2>/dev/null | grep -q '"loggedIn": true'; then
  die "$U is not signed in to Claude yet. Run:
    runuser -u $U -- env HOME=$UH PATH=/opt/node24/bin:/usr/bin:/bin $CLAUDE auth login --claudeai
  open the link, sign in with your Claude MAX account, paste the code back, then run this installer again."
fi
echo "signed in"

say "Wallet (self-custody, kept in $UH/poa)"
if [ -e $UH/poa/wallet.json ]; then
  echo "existing wallet kept"
else
  runuser -u $U -- $NODE /opt/poa/poa.mjs init-wallet --dir $UH/poa >/dev/null
fi
chmod 600 $UH/poa/wallet.json
echo "address $(python3 -c 'import json;print(json.load(open("/home/poa-worker/poa/wallet.json"))["address"])')"

say "systemd service and hourly timer (random minute)"
cat > /etc/systemd/system/poa-worker.service <<EOF
[Unit]
Description=PoA worker cycle (join once, attest, answer the epoch challenge)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=$U
Group=$U
Environment=HOME=$UH
WorkingDirectory=$UH/poa-agent
ExecStart=/usr/bin/python3 /opt/poa/poa_worker.py
TimeoutStartSec=40min
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=tmpfs
BindPaths=$UH
ReadWritePaths=$UH
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictSUIDSGID=true
CPUQuota=50%
MemoryMax=1500M
EOF
cat > /etc/systemd/system/poa-worker.timer <<EOF
[Unit]
Description=Run the PoA worker hourly at a random minute

[Timer]
OnCalendar=hourly
RandomizedDelaySec=50min
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now poa-worker.timer

say "Test: one cycle now (the site is often busy; a 'node_busy' result is normal and retried hourly)"
systemctl start poa-worker.service || true
tail -n 6 $UH/poa-agent/logs/activity.jsonl 2>/dev/null || true
echo
poactl check
say "Done. Control it with: poactl check | log | run | pause | resume | stop | start"
echo "Back up $UH/poa/wallet.json (it holds the private key; there is no other way to recover the account)."
