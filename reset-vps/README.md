# RESET worker on an Ubuntu VPS

Runs the RESET Mine worker for wallet `851f5941…d230b9` as an always-on systemd service, using root's Claude
Code (Pro plan) for each round's claim decision. Tested on a fresh simulated Ubuntu root; the systemd step and
the headless Claude test run on the VPS itself and print their results.

**What it enforces in code**: total Mine deposit at most 1 RESET, no overclaiming (level 0–1000, never
`allow_over`), no transfer/unlock/withdraw tools for the agent, one decision per round, a $1.864 model budget
(the cloud worker already used $0.136 of the agreed $2) and an end date of 2026-10-24 07:46 UTC.

## Install

1. From your Mac, copy the wallet backup to the VPS (the password stays on your Mac):
   ```sh
   scp ~/Downloads/reset-keystore-851f5941.json root@YOUR_VPS_IP:/root/
   ```
2. On the VPS, as root, get this folder and run the installer. It installs its own Claude Code in
   `/opt/reset-claude` (separate from any other Claude Code on the VPS). The first time, it stops and asks you
   to sign root in with `PATH=/opt/node24/bin:$PATH /opt/reset-claude/bin/claude auth login --claudeai`;
   then run the same installer command again.
3. Installer command:
   ```sh
   git clone -q -b claude/friendly-bell-uureey https://github.com/khaed1/claude /root/reset-vps-src
   bash /root/reset-vps-src/reset-vps/install.sh /root/reset-keystore-851f5941.json
   ```
   When asked, paste the password from `reset-password-851f5941.txt` (it is not shown) and press Enter.
4. After it prints `Done`, delete the copied backup: `rm /root/reset-keystore-851f5941.json`.

The installer never overwrites an existing Node in `/opt/node24`, RESET checkout, wallet or password file;
it stops and says why. Running it again is safe.

## Use

```sh
resetctl check     # service state, budget, live balance/deposit/round
resetctl log 20    # last activity records (decisions, submissions, results, per-round snapshots)
resetctl pause     # keep running but do nothing      resetctl resume
resetctl stop      # stop and disable at boot          resetctl start
```

Dashboard (local to the VPS): `ssh -L 4747:127.0.0.1:4747 root@YOUR_VPS_IP`, then open http://127.0.0.1:4747.

Records: `/root/reset-agent/logs/activity.jsonl`. An accepted submission is not yet applied: `status` shows it
applied (deposit/claim changed); a payout is settled once the round's last height is counted and shows in the
next `round_snapshot`.

## Next to the IMD workers

No shared files, users, ports or services: IMD uses the `imd-worker` user, `/opt/imd-worker`,
`/home/imd-worker` and `imd-worker*.service`; this uses root, `/root/reset*`, `/opt/node24`,
`reset-*.service` and local port 4747. Both draw on the **same Claude Pro usage limits**: when IMD tasks use
them up, a RESET decision run fails and that round is skipped (no penalty), and RESET runs (about one short
run per round, within the budget above) leave a little less for IMD.

## Reboots and stopping for good

Both services start at boot. To leave the Mine: `resetctl stop`, then in a supervised Claude Code session use
the RESET `unlock` tool (144-block exit wait) and `withdraw` after pending claims settle. The unattended agent
cannot do either.
