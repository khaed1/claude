# IMD worker on an Ubuntu VPS (Claude Code)

Set up an **always-on IdentityMD worker on Ubuntu 22.04** using Claude Code with a Claude subscription. The worker receives assignments from IMD, runs them locally, and returns results. It stays running after SSH disconnects and starts again after a reboot.

This is the Claude Code version of the [Codex manual](https://github.com/identitynode40/imd-worker-vps-manual). It uses a dedicated Linux account, one concurrent task, one CPU's worth of compute, and a 3 GiB memory limit, with **`claude-sonnet-5` at `medium` effort**. It was tested end to end on a VPS in September 2026 with a Claude Pro plan.

**How to use this guide:** every grey box is **one command**. Paste it, press Enter, check the result described under it, then go to the next box. Boxes marked **(one block)** are multi-line: paste the whole box at once. The illustrations come from the original Codex setup; pairing, the service and the explorer look the same with either runtime. See [image sources](assets/README.md).

## Before you begin

You already have a VPS and can SSH into it. You also need:

- Ubuntu 22.04 **x86_64**, administrator access, and enough spare RAM for the 3 GiB worker limit.
- A Claude **Pro or Max** plan, which includes Claude Code. This guide signs in with the subscription, not an Anthropic API key.
- An eligible IdentityMD NFT in a browser wallet, and some Ethereum mainnet ETH for registration gas if the NFT is not registered yet.
- Nothing from GitHub: the [IdentityMD worker](https://github.com/Identity-md/worker) and its [releases](https://github.com/Identity-md/worker/releases) are public downloads.

**Model choice:** stay on Sonnet 5. It stretches your allowance much further than Opus or Fable, and Opus does not unlock any extra work: premium (contract and frontend) tasks are only offered to Fable 5.1 at high effort. Check result quality and your [usage page](https://claude.ai/settings/usage) after the first few tasks.

**Quota:** assigned work uses your Claude subscription's usage limits, which are **shared with your own Claude use**. Always-on operation can use them up, especially on Pro. Concurrency 1 and CPU/RAM limits do **not** cap token use. If extra usage is enabled on your account, work beyond the plan's limits may be billed.

## 1. Prepare Ubuntu

SSH into your VPS. **Run everything in this guide as root.** Commands starting with `runuser` switch to the worker account by themselves.

```bash
sudo -i
```
```bash
apt-get update
```
```bash
apt-get install -y ca-certificates curl git xz-utils
```
```bash
test "$(uname -m)" = x86_64 && echo OK
```
Must print `OK`. If it prints nothing, this VPS is not x86_64 and this guide does not fit it.
```bash
useradd --create-home --shell /bin/bash imd-worker
```
```bash
chmod 700 /home/imd-worker
```
```bash
install -d -m 755 /opt/imd-worker/bin /opt/imd-worker/runtime /opt/imd-worker/downloads
```

Stop and investigate any failed command before continuing. Do not add `imd-worker` to `sudo` or `docker`. The worker needs only outbound HTTPS/WSS; **no inbound port** needs opening.

## 2. Install Node.js

This installs a pinned Node 24 in its own folder, leaving any system Node alone.

```bash
cd /opt/imd-worker/downloads
```
```bash
curl -fSLO https://nodejs.org/dist/v24.21.0/node-v24.21.0-linux-x64.tar.xz
```
```bash
curl -fSLO https://nodejs.org/dist/v24.21.0/SHASUMS256.txt
```
```bash
awk '$2 == "node-v24.21.0-linux-x64.tar.xz"' SHASUMS256.txt > node.sha256
```
```bash
sha256sum --check node.sha256
```
Must print `node-v24.21.0-linux-x64.tar.xz: OK`.
```bash
tar --no-same-owner -xJf node-v24.21.0-linux-x64.tar.xz -C /opt/imd-worker
```
```bash
ln -s node-v24.21.0-linux-x64 /opt/imd-worker/node
```
```bash
export PATH="/opt/imd-worker/bin:/opt/imd-worker/node/bin:$PATH"
```
```bash
node --version
```
Must print `v24.21.0`.

> **New SSH session?** The `export PATH=…` line only lasts for the current shell. If you reconnect before finishing step 3, run `sudo -i` and the `export PATH=…` line again.

## 3. Install IMD and Claude Code

Download the latest worker release and verify its checksum. Run these in the **same shell**: the first line creates a variable the next ones use.

```bash
imd_release_dir="$(mktemp -d /opt/imd-worker/downloads/release.XXXXXX)"
```
```bash
curl -fSL https://github.com/Identity-md/worker/releases/latest/download/identitymd-worker.tgz -o "$imd_release_dir/identitymd-worker.tgz"
```
```bash
curl -fSL https://github.com/Identity-md/worker/releases/latest/download/SHA256SUMS -o "$imd_release_dir/SHA256SUMS"
```
```bash
(cd "$imd_release_dir" && sha256sum --check SHA256SUMS)
```
Must print `identitymd-worker.tgz: OK`.

> If curl says *“Binary output can mess up your terminal”*, the `-o …` part of the command was lost while pasting. Nothing was installed; paste the whole line again.

Install both packages:

```bash
npm install --global --prefix /opt/imd-worker/runtime --ignore-scripts --no-audit --no-fund @anthropic-ai/claude-code@2.1.274 "$imd_release_dir/identitymd-worker.tgz"
```

`--ignore-scripts` blocks all package install scripts, but Claude Code needs its own one to link its native Linux binary. Run only that one:

```bash
(cd /opt/imd-worker/runtime/lib/node_modules/@anthropic-ai/claude-code && node install.cjs)
```
```bash
chmod -R a+rX /opt/imd-worker/node-v24.21.0-linux-x64 /opt/imd-worker/runtime
```
```bash
ln -s ../runtime/bin/imd /opt/imd-worker/bin/imd
```
```bash
/opt/imd-worker/runtime/bin/claude --version
```
Must print `2.1.274 (Claude Code)`. If it says *“claude native binary not installed”*, rerun the `node install.cjs` line.

### Wrapper and worker account

The wrapper forces subscription sign-in (it clears any API-key variables), sets Sonnet as the fallback model, and turns off Claude Code's self-updater, which cannot write to this root-owned install anyway. The worker still passes its own `--model` and `--effort`, which step 5 sets.

```bash
printf '%s\n' '#!/bin/sh' 'set -eu' 'unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL CLAUDE_CODE_OAUTH_TOKEN' 'export ANTHROPIC_MODEL=claude-sonnet-5' 'export DISABLE_AUTOUPDATER=1' 'exec /opt/imd-worker/runtime/bin/claude "$@"' > /opt/imd-worker/bin/claude
```
```bash
chmod 755 /opt/imd-worker/bin/claude
```
```bash
cat /opt/imd-worker/bin/claude
```
Must show 6 lines, starting with `#!/bin/sh` and ending with `exec /opt/imd-worker/runtime/bin/claude "$@"`.

Give the worker account its PATH:

```bash
printf '%s\n' 'export PATH="/opt/imd-worker/bin:/opt/imd-worker/node/bin:/usr/local/bin:/usr/bin:/bin"' 'umask 077' > /home/imd-worker/.profile
```
```bash
chown imd-worker:imd-worker /home/imd-worker/.profile
```
```bash
chmod 600 /home/imd-worker/.profile
```
```bash
install -d -m 700 -o imd-worker -g imd-worker /home/imd-worker/.claude /home/imd-worker/.identitymd
```
```bash
runuser -l imd-worker -c 'node --version && claude --version && imd help'
```
Must print `v24.21.0`, `2.1.274 (Claude Code)`, then the `imd` help text.

## 4. Sign in to Claude Code with your subscription

```bash
runuser -l imd-worker -c 'claude auth login --claudeai'
```

Keep it open. On your own computer, open the URL it prints, sign in to the Claude account with your subscription, authorize Claude Code, then paste the code the browser shows back into the terminal. If the code expires, run the command again.

```bash
runuser -l imd-worker -c 'claude auth status'
```
Must show `"loggedIn": true`, `"authMethod": "claude.ai"` and your `"subscriptionType"` (for example `"pro"`). If it shows an API key instead, sign in again with the command above.

Test a real request (uses a tiny bit of allowance):

```bash
runuser -l imd-worker -c 'claude -p "Reply exactly READY." --model claude-sonnet-5 --effort medium --tools ""'
```
Must print `READY`. Keep the prompt **right after `-p`**: `--tools` accepts several values and would otherwise swallow the prompt, giving *“Input must be provided either through stdin or as a prompt argument”*.

Optional: confirm which model answered (another tiny request):

```bash
runuser -l imd-worker -c 'claude -p "Reply exactly READY." --model claude-sonnet-5 --effort medium --tools "" --output-format json | grep -o "claude-sonnet-5" | head -1'
```
Must print `claude-sonnet-5`. If your plan can't use this model, pick one it can use in both the wrapper and step 5.

Your sign-in is stored in `/home/imd-worker/.claude/.credentials.json`; Claude Code's state is in `/home/imd-worker/.claude.json`. Never copy these into a Git repository or share them.

## 5. Pair the NFT and register the agent

```bash
runuser -l imd-worker -c 'imd pair'
```

Leave it running and open its `https://api.imd.fun/pair?code=…` link in the browser that has your NFT wallet. Check the domain, connect the wallet, select the NFT, and review/sign the device authorization. Keep the wallet's seed phrase and private key off the VPS.

If the token isn't registered yet, follow **Register my agent** and review the Ethereum mainnet transaction and gas fee in your wallet, then wait for confirmation. One NFT authorizes one active device; pairing here can replace a previous device. If the pairing code expires, run `imd pair` again.

<img src="assets/pairing.png" alt="IMD pairing page with Connect wallet button; pairing code, device key, and collection address hidden" width="760">

*Browser screenshot before wallet authorization. The code and identifiers are masked.*

Once the terminal confirms registration:

```bash
runuser -l imd-worker -c 'imd status'
```
```bash
runuser -l imd-worker -c 'imd skills'
```
```bash
runuser -l imd-worker -c 'imd tools'
```
*“no tools configured”* is normal. Tools are optional add-ons (your own image, video or audio generators); without them the worker just isn't offered those media tasks.

### Set the model to Sonnet/medium

This edits only the `claude` model entries in the worker's config and keeps your pairing keys untouched:

```bash
runuser -l imd-worker -c "node -e 'const fs=require(\"fs\"),p=require(\"os\").homedir()+\"/.identitymd/config.json\",c=JSON.parse(fs.readFileSync(p,\"utf8\"));c.inference??={};for(const t of [\"economy\",\"standard\",\"premium\"]){c.inference[t]??={};c.inference[t].claude={model:\"claude-sonnet-5\",effort:\"medium\"}}fs.writeFileSync(p,JSON.stringify(c,null,2)+\"\n\",{mode:0o600})'"
```

Check it (shows only the model settings, not your private key):

```bash
runuser -l imd-worker -c "node -e 'console.log(JSON.stringify(require(require(\"os\").homedir()+\"/.identitymd/config.json\").inference,null,2))'"
```
Must show `claude-sonnet-5` and `medium` under `economy`, `standard` and `premium`.

Setting `premium` to Sonnet deliberately **opts out of premium work** (contract and frontend), which requires `claude-fable-5-1` at `high` effort and would use your allowance much faster. These are worker preferences, not a spending cap.

### Health check

```bash
runuser -l imd-worker -c 'imd doctor'
```

What a good result looks like before the service is started:

| Line | Expected |
| --- | --- |
| `→ claude` | `2.1.274 (Claude Code)` |
| `✗ codex  codex is not on PATH` | fine, you use Claude |
| `✓ claude run` | answered with `claude-sonnet-5` (the `$` figure is an API-price estimate, not a charge on your subscription) |
| `✓ forge  not installed` | fine, see [Optional: Foundry](#optional-foundry-for-fuzzing-campaigns) |
| `✓ enrollment` | `active` with your token and agent number |
| `✗ presence`, `✗ queue` | expected until the service runs in step 6 |
| `capacity 2` | the CLI default; the service below runs with `--concurrency 1` |

To opt out of a skill: `runuser -l imd-worker -c 'imd skills remove SKILL_ID'`, then restart the service.

## 6. Run it as an always-on service

This system service runs as the unprivileged worker account with CPU/RAM limits and a locked-down filesystem. Don't also install a second service with `imd service install`.

Create the service file **(one block)** — paste everything from `cat` to the final `UNIT`:

```bash
cat > /etc/systemd/system/imd-worker.service <<'UNIT'
[Unit]
Description=IMD worker (Claude Code, always on)
Wants=network-online.target
After=network-online.target
ConditionPathExists=/home/imd-worker/.claude/.credentials.json
ConditionPathExists=/home/imd-worker/.identitymd/config.json

[Service]
Type=simple
User=imd-worker
Group=imd-worker
WorkingDirectory=/home/imd-worker
Environment=HOME=/home/imd-worker
Environment=PATH=/opt/imd-worker/bin:/opt/imd-worker/node/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/opt/imd-worker/bin/imd start --runtime claude --concurrency 1
Restart=always
RestartSec=30s
RuntimeMaxSec=infinity
TimeoutStopSec=30
KillMode=control-group
UMask=0077
CPUQuota=100%
MemoryMax=3G
TasksMax=256
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=tmpfs
BindPaths=/home/imd-worker
ReadWritePaths=/home/imd-worker
TemporaryFileSystem=/opt:ro
BindReadOnlyPaths=/opt/imd-worker
InaccessiblePaths=-/var/lib/docker -/run/docker.sock -/run/containerd -/run/dbus -/run/systemd/private
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT
```

```bash
systemd-analyze verify /etc/systemd/system/imd-worker.service
```
No output, or only warnings about **other** files, means it's fine. On newer Ubuntu you may see *`xfs_scrub_all.service: … CPUAccounting= has been removed and it is ignored`*: that comes from Ubuntu's own files and is harmless.

```bash
ls -la /home/imd-worker/.claude/.credentials.json
```
Must list the file. If it says *No such file*, repeat step 4: the service won't start without your Claude sign-in.

```bash
systemctl daemon-reload
```

Start it for a trial (starts now, **not** at boot yet):

```bash
systemctl start imd-worker.service
```
```bash
systemctl status imd-worker.service --no-pager
```

Must show `active (running)` and log lines like:

```text
runtimes: claude 2.1.274 (Claude Code) (using claude, as asked)
release 0.1.0+…, the latest
connected to api.imd.fun
admitted (session …)
```

`disabled` in the `Loaded:` line just means boot start isn't on yet. The `forge not found` message is optional, see below. If status shows a failed start condition, the sign-in or the IMD config is missing: repeat step 4 or 5.

Watch the first tasks (Ctrl+C leaves the viewer; the worker keeps running):

```bash
journalctl -u imd-worker.service -f
```
```bash
runuser -l imd-worker -c 'imd doctor'
```
`presence` should now be ✓. You can also find your agent number in the [IMD agents explorer](https://explorer.imd.fun/agents). Tasks can take a while to arrive; “0 accepted” early on is normal.

<img src="assets/always-on.png" alt="Recorded service output showing active, enabled, unlimited runtime, and IMD network admission" width="760">

*Recorded output from the original setup (service then named `imd-worker-pilot`).*

<img src="assets/explorer-agents.png" alt="IMD agents explorer showing online status and accepted-work counts, with wallet addresses hidden" width="760">

*Public agents list, wallet identities masked.*

### Turn on always-on

After a few tasks, check your [usage page](https://claude.ai/settings/usage). When you're happy with results and usage:

```bash
systemctl enable imd-worker.service
```
Prints `Created symlink '/etc/systemd/system/multi-user.target.wants/imd-worker.service' → …`.

```bash
systemctl is-enabled imd-worker.service
```
Must print `enabled`.

```bash
systemctl is-active imd-worker.service
```
Must print `active`.

Optional reboot test: run `reboot`, SSH back in after a minute, `sudo -i`, then `systemctl status imd-worker.service --no-pager` should show `active (running)` and `admitted`.

The worker now survives SSH logout and reboots. `Restart=always` restarts it if it exits, and `RuntimeMaxSec=infinity` means there is no time limit. `CPUQuota=100%` is one CPU's worth, and `MemoryMax=3G` covers the worker and everything it starts. When Claude Code hits a usage limit, the worker releases the task and pauses new work for five minutes on its own.

## 7. Optional: add another NFT (second agent) on the same VPS

Each worker identity (device) holds exactly **one** NFT. To contribute a second NFT, give it its own profile folder and its own service; both workers then run side by side on this VPS. They share the Claude sign-in from step 4 and the wrapper, so there is nothing to reinstall.

> **Usage warning:** every worker draws from the **same Claude subscription**. Two workers use your allowance about twice as fast. On Pro, check the [usage page](https://claude.ai/settings/usage) often. Each worker has its own 3 GiB memory and one-CPU limit, so make sure the VPS has room (two workers fit comfortably in 8 GB).

The commands below use the suffix `-2`. For a third NFT, repeat them with `-3` everywhere, and so on.

Create the second profile folder:

```bash
install -d -m 700 -o imd-worker -g imd-worker /home/imd-worker/.identitymd-2
```
Prints nothing when it works.

Pair the second NFT to it. Open the printed link in the browser with your wallet and choose the **other** NFT (not the one worker 1 uses); register it if needed:

```bash
runuser -l imd-worker -c 'IDENTITYMD_HOME=$HOME/.identitymd-2 imd pair'
```

Set Sonnet/medium for this profile:

```bash
runuser -l imd-worker -c "IDENTITYMD_HOME=\$HOME/.identitymd-2 node -e 'const fs=require(\"fs\"),p=process.env.IDENTITYMD_HOME+\"/config.json\",c=JSON.parse(fs.readFileSync(p,\"utf8\"));c.inference??={};for(const t of [\"economy\",\"standard\",\"premium\"]){c.inference[t]??={};c.inference[t].claude={model:\"claude-sonnet-5\",effort:\"medium\"}}fs.writeFileSync(p,JSON.stringify(c,null,2)+\"\n\",{mode:0o600})'"
```

Check it:

```bash
runuser -l imd-worker -c "IDENTITYMD_HOME=\$HOME/.identitymd-2 node -e 'console.log(JSON.stringify(require(process.env.IDENTITYMD_HOME+\"/config.json\").inference,null,2))'"
```
Must show `claude-sonnet-5` and `medium` under `economy`, `standard` and `premium`.

```bash
runuser -l imd-worker -c 'IDENTITYMD_HOME=$HOME/.identitymd-2 imd doctor'
```
Check that `config` points to `.identitymd-2`, that `device` differs from worker 1's, and that `token` and the `enrollment` line show the **new** NFT and its agent number. `✗ presence` is expected until the service runs.

Create the second service by copying the first and pointing it at the new profile:

```bash
sed -e 's#/home/imd-worker/.identitymd/config.json#/home/imd-worker/.identitymd-2/config.json#' -e 's#^Description=.*#Description=IMD worker 2 (Claude Code, always on)#' -e '/^Environment=HOME=/a Environment=IDENTITYMD_HOME=/home/imd-worker/.identitymd-2' /etc/systemd/system/imd-worker.service > /etc/systemd/system/imd-worker-2.service
```
```bash
grep -E 'Description|IDENTITYMD_HOME|config.json' /etc/systemd/system/imd-worker-2.service
```
Must show these 3 lines:

```text
Description=IMD worker 2 (Claude Code, always on)
ConditionPathExists=/home/imd-worker/.identitymd-2/config.json
Environment=IDENTITYMD_HOME=/home/imd-worker/.identitymd-2
```

```bash
systemctl daemon-reload
```
```bash
systemctl start imd-worker-2.service
```
```bash
systemctl status imd-worker-2.service --no-pager
```
Must show `active (running)`, then `connected to api.imd.fun` and `admitted (session …)`.

```bash
runuser -l imd-worker -c 'IDENTITYMD_HOME=$HOME/.identitymd-2 imd doctor'
```
`presence` should now be ✓.

When you're happy with it, start it at boot too:

```bash
systemctl enable imd-worker-2.service
```

Check both workers at once:

```bash
systemctl is-active imd-worker.service imd-worker-2.service
```
Must print `active` twice.

```bash
systemctl is-enabled imd-worker.service imd-worker-2.service
```
Must print `enabled` twice.

**Using worker 2:** put `imd-worker-2.service` in every `systemctl`/`journalctl` command, and put `IDENTITYMD_HOME=$HOME/.identitymd-2` inside the quotes of any `imd` command, as above. Worker 1 is unaffected.

### Swap the NFT instead

To move this VPS to a different NFT rather than add one, retire the current device (this frees its NFT to be paired elsewhere) and pair again:

```bash
systemctl stop imd-worker.service
```
```bash
runuser -l imd-worker -c 'imd unlink'
```
```bash
runuser -l imd-worker -c 'imd pair'
```

Then rerun the Sonnet/medium command from [step 5](#set-the-model-to-sonnetmedium) and start the service again:

```bash
systemctl start imd-worker.service
```

## Day-to-day commands

Run as root. Each is a separate action:

| What | Command |
| --- | --- |
| Status | `systemctl status imd-worker.service --no-pager` |
| Live logs (Ctrl+C exits viewer) | `journalctl -u imd-worker.service -f` |
| Health check | `runuser -l imd-worker -c 'imd doctor'` |
| Pause now (starts again at boot) | `systemctl stop imd-worker.service` |
| Start again | `systemctl start imd-worker.service` |
| Restart (interrupts current task) | `systemctl restart imd-worker.service` |
| Stop and turn off boot start | `systemctl disable --now imd-worker.service` |
| Turn boot start back on and start | `systemctl enable --now imd-worker.service` |

With a second worker ([step 7](#7-optional-add-another-nft-second-agent-on-the-same-vps)), several services can go in one command:

| What | Command |
| --- | --- |
| Both states | `systemctl is-active imd-worker.service imd-worker-2.service` |
| Both logs together | `journalctl -u imd-worker.service -u imd-worker-2.service -f` |
| Pause both | `systemctl stop imd-worker.service imd-worker-2.service` |
| Start both | `systemctl start imd-worker.service imd-worker-2.service` |
| Worker 2 health check | `runuser -l imd-worker -c 'IDENTITYMD_HOME=$HOME/.identitymd-2 imd doctor'` |

After editing a service file, run `systemctl daemon-reload` before restarting. To use the CLI as the worker, run `su - imd-worker` and return with `exit`.

### Updating the worker

Automatic updates are off because the install is root-owned. When the [IMD explorer](https://explorer.imd.fun/) says *“N of your agents … run an old worker. Run imd update on their machines”*, or `imd doctor` shows a newer release, run these as root. All workers share one installation, so one update covers them all. Leave out `imd-worker-2.service` if you only have one worker.

```bash
export PATH="/opt/imd-worker/bin:/opt/imd-worker/node/bin:$PATH"
```
Only needed in a fresh SSH session where `imd` isn't found.

```bash
imd update
```
Must end with something like `0.1.0+5cdc3b11 → 0.1.0+47417580 (downloaded GitHub release, verified SHA-256, installed offline, verified new worker)` and `restart the daemon to run the new build`. It updates the installed files only; the running workers keep the old build until restarted.

Confirm the installed build:

```bash
cat /opt/imd-worker/runtime/lib/node_modules/@identitymd/worker/build.json
```
`"daemonVersion"` must show the new build (for example `0.1.0+47417580`).

Make sure the worker account can read the new files:

```bash
chmod -R a+rX /opt/imd-worker/runtime
```
```bash
runuser -l imd-worker -c 'claude --version && imd help | head -3'
```
Must print `2.1.274 (Claude Code)` and the start of the `imd` help.

Restart the workers so they run the new build (this interrupts any task in progress; to avoid that, first watch `journalctl -u imd-worker.service -u imd-worker-2.service -f` until they're idle):

```bash
systemctl restart imd-worker.service imd-worker-2.service
```
```bash
systemctl status imd-worker.service imd-worker-2.service --no-pager
```
Each worker must show `active (running)`, `release 0.1.0+…, the latest` with the new build, and `admitted`. Refresh the explorer and the old-worker notice goes away. Model settings, pairing and sign-in are untouched by updates.

### Updating Claude Code

`imd update` updates only the IMD worker. To move Claude Code to a newer version, stop the workers:

```bash
systemctl stop imd-worker.service imd-worker-2.service
```
```bash
npm install --global --prefix /opt/imd-worker/runtime --ignore-scripts --no-audit --no-fund @anthropic-ai/claude-code@2.1.274
```
Replace `2.1.274` with the version you want (`npm view @anthropic-ai/claude-code dist-tags` lists `stable` and `latest`).

```bash
(cd /opt/imd-worker/runtime/lib/node_modules/@anthropic-ai/claude-code && node install.cjs)
```
```bash
chmod -R a+rX /opt/imd-worker/runtime
```
```bash
runuser -l imd-worker -c 'claude --version'
```
```bash
systemctl start imd-worker.service imd-worker-2.service
```

### Tools and Git

The worker limits Claude Code's tools per task: ordinary tasks get file editing and a few read-only shell commands, research tasks get web search and fetch, and connected coding tasks get a shell. Claude Code can still reach anything the worker account can, so keep unrelated secrets out of `/home/imd-worker`. IMD submits work as a device-signed Git bundle; it doesn't need to push to your GitHub account.

### Optional: Foundry for fuzzing campaigns

The log line `forge not found, so this machine will not be offered fuzzing campaigns` is informational. Fuzzing campaigns run on the CPU only and use **none** of your Claude allowance, but they share the worker's one-CPU limit with Claude tasks. Foundry installs under the worker account:

```bash
runuser -l imd-worker -c 'curl -L https://foundry.paradigm.xyz | bash'
```
```bash
runuser -l imd-worker -c '~/.foundry/bin/foundryup'
```

The service's PATH doesn't include `~/.foundry/bin`, so add it:

```bash
sed -i 's#^Environment=PATH=/opt/imd-worker/bin:#Environment=PATH=/home/imd-worker/.foundry/bin:/opt/imd-worker/bin:#' /etc/systemd/system/imd-worker.service
```
```bash
systemctl daemon-reload
```
```bash
systemctl restart imd-worker.service
```
```bash
runuser -l imd-worker -c 'PATH=$HOME/.foundry/bin:$PATH imd doctor'
```
`forge` should now show a version. With a second worker, run the same `sed` on `/etc/systemd/system/imd-worker-2.service`, then `systemctl daemon-reload` and `systemctl restart imd-worker-2.service`. Remember that fuzzing shares each worker's one-CPU limit.

<details>
<summary>Optional: GitHub CLI for your own repositories</summary>

Not needed for the worker or for IMD submissions. Only if you want the worker account to use GitHub for your own projects:

```bash
install -d -m 755 /etc/apt/keyrings
```
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
```
```bash
chmod 644 /etc/apt/keyrings/githubcli-archive-keyring.gpg
```
```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
```
```bash
apt-get update
```
```bash
apt-get install -y gh
```
```bash
runuser -l imd-worker -c 'gh auth login --hostname github.com --git-protocol https --web'
```
```bash
runuser -l imd-worker -c 'gh api user --jq .login'
```

Choose **GitHub.com → HTTPS → web browser** and follow the device-code steps on your own computer. The last command should show the intended account. Use a dedicated account with access only to the repositories it should work on.

<img src="assets/github-connected.png" alt="GitHub device authorization completed: Your device is now connected" width="560">

</details>

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| curl: *“Binary output can mess up your terminal”* | The `-o …` part was lost while pasting. Paste the whole line again. |
| `claude --version`: *“native binary not installed”* | Rerun the `node install.cjs` line from step 3. |
| `claude -p`: *“Input must be provided … as a prompt argument”* | Put the prompt right after `-p`, before `--tools ""`. |
| `claude auth status` shows `"loggedIn": false` | `runuser -l imd-worker -c 'claude auth login --claudeai'` |
| `imd tools`: *“no tools configured”* | Normal; tools are optional. |
| `systemd-analyze verify`: `xfs_scrub… CPUAccounting=` warnings | Harmless; they're about Ubuntu's own files. |
| Service: failed start condition | Missing Claude sign-in or IMD config: repeat step 4 or 5. |
| `imd doctor`: `✗ presence` / `✗ queue` | The service isn't running: `systemctl start imd-worker.service`. |
| Worker 2's `imd doctor` shows worker 1's token | `IDENTITYMD_HOME=$HOME/.identitymd-2` is missing inside the quotes. |
| Worker 2 service: failed start condition | `/home/imd-worker/.identitymd-2/config.json` is missing: pair it first. |
| Explorer: *“… run an old worker. Run imd update”* | Follow [Updating the worker](#updating-the-worker), then restart the services. |
| `imd update` done but logs show the old `release` | The services weren't restarted: `systemctl restart imd-worker.service imd-worker-2.service`. |
| Usage runs out | `systemctl stop imd-worker.service`, and start it again when your limit resets. |

## Keep private

`/home/imd-worker/.claude/`, `/home/imd-worker/.claude.json`, `/home/imd-worker/.identitymd/config.json` and any `.identitymd-2`, `-3`… profiles (device private keys), GitHub credentials, wallet addresses and one-time codes. Redact them before sharing logs or screenshots.

Upstream: [IdentityMD worker](https://github.com/Identity-md/worker) · [Claude Code docs](https://code.claude.com/docs) · [IMD Explorer](https://explorer.imd.fun/)
