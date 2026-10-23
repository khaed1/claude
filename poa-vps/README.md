# PoA (minepoa.com) worker on the VPS

Runs a **Proof of Agent** worker as its own locked-down user `poa-worker`, next to the RESET worker and the
IMD workers without touching them. Once an hour, at a random minute (the site asks clients not to poll), one
cycle: join once, countersign new transactions in code ("mining"), and answer the current 6-hour epoch's
challenge once per epoch. Only the answer text comes from Claude (your **Max** account, signed in for this user),
run **with no tools**.

**What it never does:** referrals or recruiting, forum posts, votes, swaps, linking chain wallets or an Emblem
Vault. The coin POA has no promised value; the site's own terms say it may never have any.

**Limits** (`/etc/poa-worker/config.json`, root-owned so the worker cannot change them): $15 of Claude usage
over 7 days, at most $0.15 per answer (a test answer cost $0.011, so a week of 4 answers a day is ~$0.30).

**Pinned client:** `https://minepoa.com/client/poa.mjs` v0.3, sha256
`89b8a10673333d5980f2b67d3e058aada530629ace12bcf2677ea6441f49c374` (reviewed: plain readable code, Node
built-ins only, talks only to minepoa.com and the public Solana RPC, writes only its wallet and ledger folders).
If the site serves anything else, the installer stops and changes nothing.

## Install (as root, after the RESET bundle, which provides /opt/node24 and /opt/reset-claude)

```sh
git -C /root/reset-vps-src pull -q
bash /root/reset-vps-src/poa-vps/install.sh
```

The first time it stops and asks you to sign the `poa-worker` user in to Claude:

```sh
runuser -u poa-worker -- env HOME=/home/poa-worker PATH=/opt/node24/bin:/usr/bin:/bin /opt/reset-claude/bin/claude auth login --claudeai
```

Open the link, sign in with the **Max** account, paste the code back, then run the installer again. It creates
the self-custody wallet, starts the hourly timer and runs one cycle as a test. `node_busy` in that test is normal:
the site is often overloaded and the next hourly cycle retries.

## Hosted fallback (off by default)

The self-custody client downloads the whole ledger (`/api/snapshot`), which the site often refuses ("origin
busy"). If the self-custody wallet has never joined and you turn the fallback on, the worker registers **once**
through the site's hosted API (at most one attempt per day) and from then on each cycle: fetches the challenge,
has Claude answer it (it gets only the 3 words and this worker's own task text, never the site's instructions),
requests `mine`, and reads the balance. **The site's node holds that account's key**; the `pk_` key is stored in
`/home/poa-worker/poa/hosted.json` (0600), never logged, and can be exported to self-custody later
(`/api/hosted/export`). It is a new address; the self-custody wallet stays unused.

```sh
poactl enable-hosted          # optional label: poactl enable-hosted my-label
poactl run                    # start a cycle now
poactl log 10                 # expect: self_custody_busy, hosted_registered, answer_submitted, mined, balance
poactl hosted-key             # show the key ONCE and save it offline (password manager); never share it
```

## Use

```sh
poactl check     # timer, last cycle, address, model spend, last balance
poactl log 20    # activity records: joined, attested, answer_submitted (with the text), balance, node_busy, errors
poactl run       # start one cycle now
poactl pause | resume | stop | start
```

**Back up `/home/poa-worker/poa/wallet.json`** (private key; nothing else can recover the account).
Rewards vest over ~100 epochs per the site; low grades never reduce balances.
