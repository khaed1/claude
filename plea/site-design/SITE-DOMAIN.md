# pleaimd.fun serves the PLEA site

`https://pleaimd.fun/` shows the site IMD hosts, under your own name: Caddy on the VPS (the one that
already serves `indexer.pleaimd.fun`) fetches each file from IMD's gateway and passes it on unchanged.
Visitors keep `pleaimd.fun` in the address bar, every link and the link card work, and when a new site
version lands under another IMD name only one line changes.

Why not Hostinger's own forwarding: a "masked" or "frame" forward puts the site in a frame, and IMD's
gateway forbids framing (`frame-ancestors 'none'`), so the page would stay blank; a plain redirect
works but shows the IMD address instead of yours.

Tested on 2026-10-29 with Caddy 2.6.2 (Ubuntu's package, the VPS's version) against the live site
`plea-a184.imd.site`: all 28 files arrive byte for byte equal to the site's own list
(`imd-deployment.json`), IMD's security headers pass through, and `caddy validate` accepts the
Caddyfile below. Without the `header_up Host` line IMD's gateway answers 403.

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
	reverse_proxy https://plea-a184.imd.site {
		header_up Host plea-a184.imd.site
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

Each version gets its IMD name from the hosting job (`plea-a184` now; the next one is meant to be
`pleaimd`). After the session confirms the new version is live, point the block at it (both places):

```
sed -i 's/plea-a184\.imd\.site/pleaimd.imd.site/g' /etc/caddy/Caddyfile
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
- If the VPS is down, `pleaimd.fun` is down; the IMD address (`https://plea-a184.imd.site/`, later
  `https://pleaimd.imd.site/`) keeps working.
- The site's link card and `og:url` say `pleaimd.fun` from the next version on.
