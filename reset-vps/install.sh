#!/bin/bash
# Install the RESET participation worker on an Ubuntu VPS (run as root).
# Usage: bash install.sh /path/to/reset-keystore-851f5941.json
# It never overwrites an existing Node, RESET checkout, wallet or password; it stops instead.
set -euo pipefail

KEYSTORE_SRC="${1:-}"
BUNDLE="$(cd "$(dirname "$0")" && pwd)"
RESET_REPO=https://github.com/Trac-Systems/reset
RESET_COMMIT=6c2afd48d8a61198878004d30f7c420b5eeb8788
NODE_V=v24.22.0
NODE_SHA=cc2f601cee82d9a5a233302fe307abc600727035fd7d2c3a3571755989e95008
ADDR=851f5941652918bd2db0b7749d8d4c1480c9bffed46635f7d463cc8b46d230b9
H=/root/reset-agent
PWFILE=/root/.config/reset/signer-password
NODE=/opt/node24/bin/node
CLAUDE_V=2.1.300

say() { printf '\n== %s\n' "$*"; }
die() { printf '\nSTOPPED: %s\n' "$*" >&2; exit 1; }

say "Checking this machine"
[ "$(id -u)" = 0 ] || die "run as root"
[ "$(uname -m)" = x86_64 ] || die "this installer is for x86_64"
command -v systemctl >/dev/null || die "systemd is required"
missing=""
for t in git curl python3 xz; do command -v $t >/dev/null || missing="$missing $t"; done
if [ -n "$missing" ]; then
  say "Installing missing tools:$missing"
  apt-get update -qq && apt-get install -y -qq git curl python3 xz-utils
fi

say "Node.js $NODE_V"
if [ -x $NODE ]; then
  [ "$($NODE -v)" = "$NODE_V" ] || die "/opt/node24 holds $($NODE -v), not $NODE_V; leaving it alone"
  echo "already installed"
else
  tmp="$(mktemp -d)"; f=node-$NODE_V-linux-x64.tar.xz
  curl -fsSL -o "$tmp/$f" https://nodejs.org/dist/$NODE_V/$f
  echo "$NODE_SHA  $tmp/$f" | sha256sum -c - || die "Node download failed its checksum"
  mkdir -p /opt/node24 && tar -xJf "$tmp/$f" -C /opt/node24 --strip-components=1 && rm -rf "$tmp"
  $NODE -v
fi

say "Claude Code for the RESET worker"
# Its own copy in /opt/reset-claude, so other setups on this VPS (and their updates) are not touched.
CLAUDE=/opt/reset-claude/bin/claude
if [ -x $CLAUDE ]; then
  echo "already installed: $(PATH=/opt/node24/bin:$PATH $CLAUDE --version)"
else
  PATH=/opt/node24/bin:$PATH npm install -g --prefix /opt/reset-claude --no-audit --no-fund @anthropic-ai/claude-code@$CLAUDE_V
  PATH=/opt/node24/bin:$PATH $CLAUDE --version
fi
# The worker runs as root, so root's own sign-in is needed (other users' sign-ins do not count).
if ! PATH=/opt/node24/bin:$PATH $CLAUDE auth status 2>/dev/null | grep -q '"loggedIn": true'; then
  die "root's Claude Code is not signed in yet. Run:
    PATH=/opt/node24/bin:\$PATH $CLAUDE auth login --claudeai
  open the link it prints, sign in with your Claude Pro account, paste the code back,
  then run this installer again (everything done so far is kept)."
fi
echo "signed in"

say "RESET signer at $RESET_COMMIT"
if [ -d /root/reset/.git ]; then
  [ "$(git -C /root/reset rev-parse HEAD)" = "$RESET_COMMIT" ] || die "/root/reset is at another commit; leaving it alone"
  echo "already checked out"
else
  [ ! -e /root/reset ] || die "/root/reset exists and is not a git checkout"
  git clone -q $RESET_REPO /root/reset && git -C /root/reset checkout -q $RESET_COMMIT
fi
if [ ! -d /root/reset/signer/node_modules ]; then
  (cd /root/reset/signer && PATH=/opt/node24/bin:$PATH npm ci --ignore-scripts --no-audit --no-fund)
fi

say "Wallet"
if [ -e /root/.reset-signer/keystore.json ]; then
  echo "existing wallet kept"
else
  [ -n "$KEYSTORE_SRC" ] && [ -f "$KEYSTORE_SRC" ] || die "give the keystore backup file: bash install.sh /root/reset-keystore-851f5941.json"
  install -d -m 700 /root/.reset-signer
  install -m 600 "$KEYSTORE_SRC" /root/.reset-signer/keystore.json
fi
got="$(python3 -c 'import json; print(json.load(open("/root/.reset-signer/keystore.json"))["address"])')"
[ "$got" = "$ADDR" ] || die "wallet address is $got, expected $ADDR"
echo "address $got"

say "Wallet password"
if [ -s $PWFILE ]; then
  echo "existing password file kept"
else
  install -d -m 700 /root/.config/reset
  read -rsp "Paste the RESET wallet password (from reset-password-851f5941.txt), then Enter: " pw || true; echo
  [ ${#pw} -ge 12 ] || die "that password is shorter than 12 characters"
  (umask 077; printf '%s' "$pw" > $PWFILE); unset pw
fi

say "Worker files in $H"
install -d -m 700 $H $H/logs $H/work
install -m 600 "$BUNDLE"/worker.py "$BUNDLE"/guard-mcp.mjs "$BUNDLE"/call.mjs $H/
install -m 700 "$BUNDLE"/reset-mcp.sh "$BUNDLE"/resetctl $H/
ln -sf $H/resetctl /usr/local/bin/resetctl
if [ ! -e $H/config.json ]; then
  # The owner's limits: 1 RESET lock cap, no overclaiming, $2 model budget over 3 days
  # ($0.136 of it was already used by the cloud worker), ending 2026-10-24 07:46 UTC.
  (umask 077; cat > $H/config.json <<'EOF'
{
 "max_lock": "1",
 "allow_over": false,
 "budget_usd": 1.864,
 "per_run_max_usd": 0.25,
 "start": "2026-10-21T07:46:09+00:00",
 "end": "2026-10-24T07:46:09+00:00",
 "model": "sonnet",
 "tick_seconds": 30
}
EOF
  )
fi

say "Checking the password unlocks the wallet"
if ! $NODE $H/call.mjs address | grep -q "$ADDR"; then
  rm -f $PWFILE
  die "the wallet did not unlock: wrong password (the password file was removed; run the installer again)"
fi
echo "unlocked"

if [ "${SKIP_SYSTEMD:-}" = 1 ]; then say "SKIP_SYSTEMD=1: stopping before services"; exit 0; fi

say "systemd services"
cat > /etc/systemd/system/reset-worker.service <<EOF
[Unit]
Description=RESET participation worker
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment=HOME=/root
Environment=PATH=/opt/node24/bin:/opt/reset-claude/bin:/usr/local/bin:/usr/bin:/bin
Environment=DISABLE_AUTOUPDATER=1
WorkingDirectory=$H
ExecStart=/usr/bin/python3 $H/worker.py
Restart=on-failure
RestartSec=120
NoNewPrivileges=true
PrivateTmp=true
StandardOutput=append:$H/logs/worker.log
StandardError=append:$H/logs/worker.log

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/reset-dashboard.service <<EOF
[Unit]
Description=RESET local dashboard (127.0.0.1:4747, read-only)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment=HOME=/root
WorkingDirectory=/root/reset/signer
ExecStart=$NODE /root/reset/signer/bin/reset-signer.mjs dashboard
Restart=always
RestartSec=30
NoNewPrivileges=true
PrivateTmp=true
StandardOutput=append:$H/logs/dashboard.log
StandardError=append:$H/logs/dashboard.log

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

say "Test 1: one worker pass (status + headers, no model)"
python3 $H/worker.py --once
tail -n 2 $H/logs/activity.jsonl

say "Test 2: one headless Claude decision run (uses a little of your Pro usage)"
python3 $H/worker.py --test-agent
tail -n 1 $H/logs/activity.jsonl

say "Starting services"
systemctl enable --now reset-worker reset-dashboard
sleep 5
resetctl check
say "Done. Control it with: resetctl check | pause | resume | stop | start | log"
