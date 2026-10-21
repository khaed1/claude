#!/bin/sh
# Launch the RESET local MCP signer. The wallet password is read from a 0600 file,
# so it never appears in agent config files, process arguments or logs.
PWFILE="${RESET_PASSWORD_FILE:-/root/.config/reset/signer-password}"
[ -r "$PWFILE" ] || { echo "reset-mcp: password file missing: $PWFILE" >&2; exit 78; }
RESET_SIGNER_PASSWORD="$(cat "$PWFILE")"
export RESET_SIGNER_PASSWORD
exec /opt/node24/bin/node /root/reset/signer/bin/reset-signer.mjs mcp "$@"
