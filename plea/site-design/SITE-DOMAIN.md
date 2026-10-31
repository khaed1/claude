# pleaimd.fun serves the PLEA site

`https://pleaimd.fun/` shows the site IMD hosts, under your own name: Caddy on the VPS (the one that
already serves `indexer.pleaimd.fun`) fetches each file from IMD's gateway and passes it on unchanged.
Visitors keep `pleaimd.fun` in the address bar, every link and the link card work, and when a new site
version lands under another IMD name only one line changes.

Why not Hostinger's own forwarding: a "masked" or "frame" forward puts the site in a frame, and IMD's
gateway forbids framing (`frame-ancestors 'none'`), so the page would stay blank; a plain redirect
works but shows the IMD address instead of yours.

Tested with Caddy 2.6.2 (Ubuntu's package, the VPS's version): on 2026-10-29 against `plea-a184.imd.site`,
and on 2026-10-30 against the current version `pleaimd-0cb8.imd.site`: all 29 files arrive byte for byte
equal to the site's own list (`imd-deployment.json`), IMD's security headers pass through, and
`caddy validate` accepts the Caddyfile below. Without the `header_up Host` line IMD's gateway answers 403.
IMD sends the files uncompressed (a first visit to Home is about 1.3 MB); the `encode` line makes Caddy
compress them for the visitor: all 29 files 1,739 KB → 767 KB sent, byte for byte the same once the browser
unpacks them (tested 2026-10-30). Repeat visits cost almost nothing (the browser checks its copy).

Paste one line at a time.

## 1. DNS (Hostinger)

hPanel → Domains → `pleaimd.fun` → DNS / Nameservers → DNS records:

- Edit the **A** record whose name is **@** (it points to Hostinger's parking page, `2.57.91.91`):
  change its value to **`186.241.26.207`** (the VPS, the same as `indexer`). TTL: leave it.
- Leave the **CNAME `www` → `pleaimd.fun`** as it is.
- If there is an **AAAA** record for `@` or `www`, delete it (there was none on 2026-10-29).

Check from your own computer (a few minutes, up to the old TTL):

```
nslookup pleaimd.fun
```

It must answer `186.241.26.207`.

## 2. Caddy (on the VPS, as root)

Add the block at the end of the Caddyfile (it keeps the indexer's block above it):

```
cat >> /etc/caddy/Caddyfile <<'EOF'

pleaimd.fun, www.pleaimd.fun {
	encode zstd gzip
	reverse_proxy https://pleaimd-0cb8.imd.site {
		header_up Host pleaimd-0cb8.imd.site
	}
}
EOF
```

```
caddy validate --config /etc/caddy/Caddyfile
```

It must end with `Valid configuration`. Then:

```
systemctl reload caddy
```

Caddy fetches the certificates for `pleaimd.fun` and `www.pleaimd.fun` by itself (ports 80 and 443
are already open for the indexer). If the reload fails, `journalctl -u caddy -n 30` says why.

## 3. Check

From your own computer:

```
curl -sI https://pleaimd.fun/
```

It must show `HTTP/2 200` and an `x-ipfs-cid:` line. Then open https://pleaimd.fun/ in a browser and
tell the session: it compares every file with the site's list from outside.

## 4. When a new site version is hosted

Each version gets its own IMD name: the label plus the start of its job id (`pleaimd-0cb8` now; the
label `pleaimd` was free, and IMD still added `-0cb8`). After the session confirms a new version is live
and gives you its name, point the block at it (both places; `NEW` is the new name, e.g. `pleaimd-1a2b`):

```
sed -i 's/pleaimd-0cb8\.imd\.site/NEW.imd.site/g' /etc/caddy/Caddyfile
```

```
caddy validate --config /etc/caddy/Caddyfile
```

```
systemctl reload caddy
```

Visitors see the new version within a minute (IMD's pages are cached for 60 seconds).

## Notes

- The VPS only passes the files on; it cannot change what IMD checked unless someone changes this
  Caddy block. The session's check compares every file's sha256 with the site's own list.
- If the VPS is down, `pleaimd.fun` is down; the IMD address (`https://pleaimd-0cb8.imd.site/`) keeps working.
- The site's link card and `og:url` say `pleaimd.fun` (since `pleaimd-0cb8`), so link previews on X show the
  card only once `pleaimd.fun` serves the site.
- The old version stays at `https://plea-a184.imd.site/` (IMD does not take it down).
