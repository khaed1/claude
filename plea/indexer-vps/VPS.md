# Running the PLEA indexer on a VPS (draft: step 3 names the delivered code after IMD's job)

For Ubuntu 22.04 or later on x86_64, run as root, on the same machine as the keeper. The indexer
reads PLEA's events from Ethereum into a Postgres database and answers the site's queries over
HTTPS. It holds no key and sends no transaction. It needs about 0.5 GB of memory (Ponder ~0.3 GB,
Postgres ~0.2 GB) and well under 1 GB of disk for years of PLEA's events.

What you need first:
- **An Ethereum RPC URL with your own key** (Alchemy, Infura, QuickNode or dRPC; a free plan is
  enough with the 12-second polling below). It may be the same URL as the keeper's `RPC_URL`.
- **A hostname for the HTTPS address.** Either a name under a domain you own (add an `A` record,
  e.g. `indexer.yourdomain.com` → the VPS's IP address), or, without a domain, the free name
  `<ip with dashes>.sslip.io` (for IP 203.0.113.7: `203-0-113-7.sslip.io`; it changes if the VPS's
  IP ever changes). Find the IP with `curl -4 ifconfig.me`.

## 1. A user and Node.js 22

```
useradd --system --create-home --home-dir /opt/plea-indexer --shell /usr/sbin/nologin plea-indexer
cd /opt/plea-indexer
curl -fSLO https://nodejs.org/dist/v22.22.0/node-v22.22.0-linux-x64.tar.xz
curl -fSLO https://nodejs.org/dist/v22.22.0/SHASUMS256.txt
grep ' node-v22.22.0-linux-x64.tar.xz$' SHASUMS256.txt | sha256sum --check
tar --no-same-owner -xJf node-v22.22.0-linux-x64.tar.xz && ln -s node-v22.22.0-linux-x64 node
rm node-v22.22.0-linux-x64.tar.xz SHASUMS256.txt
/opt/plea-indexer/node/bin/node --version
```

The check must print `node-v22.22.0-linux-x64.tar.xz: OK`, and the last line `v22.22.0`.

## 2. Postgres

```
apt-get install -y postgresql
PW=$(openssl rand -hex 24)
runuser -u postgres -- psql -qc "CREATE USER plea_indexer PASSWORD '$PW';" -c "CREATE DATABASE plea_indexer OWNER plea_indexer;"
```

Keep this shell open for step 4 (it holds the password in `$PW`; it is never printed). Postgres
listens only on the machine itself.

## 3. The code

```
apt-get install -y git
git clone <the delivered repository> /opt/plea-indexer/app
cd /opt/plea-indexer/app && git checkout <the checked commit>
PATH=/opt/plea-indexer/node/bin:$PATH npm ci --omit=dev --ignore-scripts --no-audit --no-fund
chown -R plea-indexer:plea-indexer /opt/plea-indexer/app
git config --global --add safe.directory /opt/plea-indexer/app
```

## 4. Settings

```
cd /opt/plea-indexer/app
umask 077
printf 'DATABASE_URL=postgresql://plea_indexer:%s@localhost:5432/plea_indexer\nPONDER_RPC_URL_1=\n' "$PW" > .env.local
chown plea-indexer:plea-indexer .env.local
unset PW
nano .env.local
```

Put your RPC URL after `PONDER_RPC_URL_1=` and save. Keep a copy of `.env.local` somewhere safe.

## 5. Check it

```
cd /opt/plea-indexer/app
set -a; . ./.env.local; set +a
runuser -u plea-indexer -- /opt/plea-indexer/node/bin/node node_modules/.bin/ponder start --schema plea_v1 --hostname 127.0.0.1 --port 42069
```

Within a minute it prints `Completed backfill indexing` and `Started returning 200 responses
endpoint=/ready`. In a second terminal, `curl -s http://127.0.0.1:42069/status` prints the last
block it has, e.g. `{"mainnet":{"id":1,"block":{"number":26294278,…}}}`. Stop it with Ctrl+C (it
keeps what it indexed).

## 6. Run it as a service

```
cp /opt/plea-indexer/app/<path of plea-indexer.service> /etc/systemd/system/plea-indexer.service
systemctl daemon-reload
systemctl enable --now plea-indexer
journalctl -u plea-indexer -f
```

It restarts by itself after a crash or a reboot and carries on from the last block it had.

## 7. HTTPS with Caddy

Ubuntu 24.04: `apt-get install -y caddy`. Ubuntu 22.04: Caddy's own package repository
(https://caddyserver.com/docs/install, "Debian, Ubuntu, Raspbian").

```
cp /opt/plea-indexer/app/<path of Caddyfile> /etc/caddy/Caddyfile
nano /etc/caddy/Caddyfile          # replace indexer.example.com with your hostname
systemctl reload caddy
```

Ports 80 and 443 must be open: `ufw status`; if it is active, `ufw allow 80/tcp` and
`ufw allow 443/tcp` (and in your VPS provider's firewall, if it has one). Caddy fetches a free
certificate and renews it by itself. The indexer's own port 42069 stays closed to the outside.

Check from your own computer:

```
curl -s https://<your hostname>/status
```

It must print the same kind of line as in step 5. Then send the address `https://<your hostname>/graphql` to the session: it
checks it against the chain and puts it into the site.

## Updating

```
cd /opt/plea-indexer/app && git fetch && git checkout <new commit>
PATH=/opt/plea-indexer/node/bin:$PATH npm ci --omit=dev --ignore-scripts --no-audit --no-fund
chown -R plea-indexer:plea-indexer /opt/plea-indexer/app
systemctl restart plea-indexer
```

If the update changes the indexer's code or settings, Ponder refuses the old `--schema` name: change
`plea_v1` to `plea_v2` in `/etc/systemd/system/plea-indexer.service`, `systemctl daemon-reload`,
`systemctl restart plea-indexer`. It builds a fresh index in a few minutes (its RPC answers are kept
in Postgres, so this costs little); the site keeps working meanwhile from the chain directly. The old
schema can be dropped afterwards: `runuser -u postgres -- psql -d plea_indexer -c 'DROP SCHEMA plea_v1 CASCADE;'`.

Nothing here needs a backup: everything in the database can be rebuilt from the chain.
