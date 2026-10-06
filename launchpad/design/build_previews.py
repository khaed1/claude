#!/usr/bin/env python3
"""Writes each component's preview.html under system/components/ (the Design System artifact's live previews)
and design/preview-all.html (every preview on one page with tokens.css and bundle.css, for a local look).

  python3 build_previews.py

Previews are static HTML using the pp- classes from system/components/bundle.css; the coin images are small
generated SVGs. Example numbers are illustrative (curve target 4,000 IMD, fees 1.5% + tax, D-9, D-76).
"""
import base64
from pathlib import Path

HERE = Path(__file__).resolve().parent
COMP = HERE / "system" / "components"


def coin_img(bg, fg, glyph):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" fill="{bg}"/>'
           f'<circle cx="22" cy="24" r="9" fill="{fg}"/><circle cx="42" cy="24" r="9" fill="{fg}"/>'
           f'<circle cx="22" cy="24" r="4" fill="{bg}"/><circle cx="42" cy="24" r="4" fill="{bg}"/>'
           f'<path d="M14 46q18 10 36 0" stroke="{fg}" stroke-width="5" fill="none" stroke-linecap="round"/>'
           f'<text x="56" y="60" font-size="12" text-anchor="end" fill="{fg}" font-family="sans-serif" font-weight="800">{glyph}</text></svg>')
    return "data:image/svg+xml;base64," + base64.b64encode(svg.encode()).decode()


IMG = {
    "ribbit": coin_img("#2f6b4f", "#bff0cf", "R"),
    "lotus": coin_img("#6b2f4f", "#f8c9de", "L"),
    "moss": coin_img("#4d5a1e", "#e4f0a8", "M"),
    "gold": coin_img("#6b5320", "#ffe3a1", "G"),
}

ICON = {
    "clock": '<svg class="pp-ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 10.4 3.6 2.1-1 1.7-4.6-2.7V6h2z"/></svg>',
    "chorus": '<svg class="pp-ico" viewBox="0 0 24 24" aria-hidden="true"><circle cx="7" cy="8" r="3"/><circle cx="17" cy="8" r="3"/><path d="M2 20c0-4 3-7 10-7s10 3 10 7z"/></svg>',
    "alert": '<svg class="pp-ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2 1 21h22zm1 15h-2v-2h2zm0-4h-2V9h2z"/></svg>',
    "info": '<svg class="pp-ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-6h2zm0-8h-2V7h2z"/></svg>',
    "leap": '<svg class="pp-ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 20q4-14 18-16-3 3-4 7l3 1-5 2q-3 6-12 6z"/></svg>',
    "x": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M17.8 3h3.1l-6.8 7.8 8 10.2h-6.3l-4.9-6.4L5.3 21H2.2l7.3-8.3L1.8 3h6.4l4.4 5.9zm-1.1 16.2h1.7L7.4 4.7H5.6z"/></svg>',
    "web": '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm6.9 6h-3a15 15 0 0 0-1.3-3.9A8 8 0 0 1 18.9 8zM12 4c.8 1.1 1.5 2.5 1.9 4h-3.8c.4-1.5 1.1-2.9 1.9-4zM4.3 14a8 8 0 0 1 0-4h3.4a16 16 0 0 0 0 4zm.8 2h3a15 15 0 0 0 1.3 3.9A8 8 0 0 1 5.1 16zm3-8h-3a8 8 0 0 1 4.3-3.9A15 15 0 0 0 8.1 8zM12 20c-.8-1.1-1.5-2.5-1.9-4h3.8c-.4 1.5-1.1 2.9-1.9 4zm2.3-6H9.7a14 14 0 0 1 0-4h4.6a14 14 0 0 1 0 4zm.3 5.9c.6-1.2 1-2.5 1.3-3.9h3a8 8 0 0 1-4.3 3.9zm1.7-5.9a16 16 0 0 0 0-4h3.4a8 8 0 0 1 0 4z"/></svg>',
}


def leap(pct, raised, near=False, done=False, pads=True):
    cls = "pp-leap" + (" is-near" if near else "") + (" is-done" if done else "")
    pad_html = '<div class="pp-leap-pads"><i style="left:25%"></i><i style="left:50%"></i><i style="left:75%"></i></div>' if pads else ""
    label = "Leapt" if done else f"{pct}% to the Leap"
    return (f'<div class="{cls}" role="progressbar" aria-valuenow="{pct}" aria-valuemin="0" aria-valuemax="100" aria-label="Progress to the Leap">'
            f'<div class="pp-leap-track">{pad_html}<div class="pp-leap-fill" style="width:{pct}%"></div><div class="pp-leap-head" style="left:{pct}%"></div></div>'
            f'<div class="pp-leap-row"><span><b>{raised}</b> / 4,000 IMD</span><span>{label}</span></div></div>')


def coin(name, ticker, img, stage, desc, mcap, change, pct=None, raised=None, badges="", spotlight=False, near=False, fee="1.5%"):
    up = change.startswith("+")
    stage_html = {"egg": '<span class="pp-stage pp-stage-egg">Egg</span>',
                  "tadpole": '<span class="pp-stage pp-stage-tadpole">Tadpole</span>',
                  "frog": '<span class="pp-stage pp-stage-frog">Frog</span>'}[stage]
    meter = leap(pct, raised, near=near) if pct is not None else ""
    return (f'<a class="pp-coin{" is-spotlight" if spotlight else ""}" href="#">'
            f'<img class="pp-coin-img" src="{IMG[img]}" alt="">'
            f'<div class="pp-coin-body"><div class="pp-coin-top"><span class="pp-coin-name">{name}</span><span class="pp-coin-ticker">${ticker}</span><span class="pp-spacer"></span>{stage_html}</div>'
            f'<div class="pp-coin-desc">{desc}</div>'
            f'<div class="pp-coin-stats"><span>MC <b>{mcap}</b></span><span class="{"pp-up" if up else "pp-down"}">{"▲" if up else "▼"} {change[1:]}</span><span>Fee {fee}</span><span>12 min ago</span></div>'
            f'{meter}<div class="pp-coin-badges">{badges}</div></div></a>')


BADGES = (f'<span class="pp-badge pp-badge-x">{ICON["x"]}X verified</span>'
          f'<span class="pp-badge pp-badge-chorus">{ICON["web"]}Site by the Chorus</span>')
ALL_BADGES = BADGES + '<span class="pp-badge pp-badge-tax">Tax 0.5% → holders</span>'

PREVIEWS = {
    "Button": ("Actions", 120, '<div class="pp-demo">'
               '<button class="pp-btn pp-btn-primary">Spawn it</button>'
               '<button class="pp-btn pp-btn-buy">Buy $RIBBIT</button>'
               '<button class="pp-btn pp-btn-sell">Sell $RIBBIT</button>'
               '<button class="pp-btn pp-btn-leap">Buy $PONDPAD</button>'
               '<button class="pp-btn">Connect wallet</button>'
               '<button class="pp-btn pp-btn-ghost">Cancel</button>'
               '<button class="pp-btn pp-btn-sm">Max</button>'
               '<button class="pp-btn pp-btn-primary" disabled>Laying your egg…</button></div>'),
    "StageChip": ("Lifecycle", 64, '<div class="pp-demo"><span class="pp-stage pp-stage-egg">Egg</span>'
                  '<span class="pp-stage pp-stage-tadpole">Tadpole · 63%</span><span class="pp-stage pp-stage-frog">Frog · leapt 3d ago</span></div>'),
    "LeapMeter": ("Lifecycle", 200, '<div class="pp-demo-col">' + leap(8, "320") + leap(63, "2,520") + leap(94, "3,760", near=True) + leap(100, "4,000", done=True) + "</div>"),
    "Badge": ("Status", 64, '<div class="pp-demo">' + ALL_BADGES + '<span class="pp-badge pp-badge-warn">Takeover notice</span><span class="pp-badge">Paid in ETH</span></div>'),
    "Notice": ("Status", 260, '<div class="pp-demo-col">'
               '<div class="pp-notice pp-notice-tax">'+ICON["clock"]+'<div><b>Early-bird tax is on for 14 more seconds.</b> It\'s there to keep bots honest.</div></div>'
               '<div class="pp-notice pp-notice-chorus">'+ICON["chorus"]+'<div><b>Takeover in progress.</b> The swarm agreed this coin was abandoned. Creator fees move to the community\'s wallet in 2 days unless something changes.</div></div>'
               '<div class="pp-notice pp-notice-danger">'+ICON["alert"]+'<div><b>You\'re in the wrong pond.</b> Switch to Robinhood Chain.</div></div>'
               '<div class="pp-notice">'+ICON["info"]+'<div>Coins here are made by anyone and can go to zero. Read the risks before you trade.</div></div></div>'),
    "Toast": ("Status", 150, '<div class="pp-demo-col"><div class="pp-toast is-ok">It\'s alive. Your tadpole is swimming. <a href="#">View</a></div>'
              '<div class="pp-toast is-error">That didn\'t go through. Nothing was lost except a bit of gas.</div></div>'),
    "CoinCard": ("Coins", 560, '<div class="pp-demo-col" style="max-width:440px">'
                 + coin("Ribbit Republic", "RIBBIT", "ribbit", "tadpole", "A frog-run state. Every holder gets a vote, nobody reads the constitution.", "10,440 IMD", "+18.2%", 63, "2,520", BADGES, fee="2.0%")
                 + coin("Golden Croak", "CROAK", "gold", "tadpole", "One croak away from the Leap.", "9,710 IMD", "+41.0%", 94, "1,936", '<span class="pp-badge pp-badge-x">' + ICON["x"] + 'X verified</span>', spotlight=True, near=True)
                 + coin("Lotus Lounge", "LOTUS", "lotus", "frog", "Leapt last week. Site built by the Chorus.", "48,200 IMD", "-6.4%", badges='<span class="pp-badge pp-badge-chorus">' + ICON["web"] + 'Site by the Chorus</span>')
                 + "</div>"),
    "RippleFeed": ("Coins", 64, '<div class="pp-ripples" aria-label="Live trades">'
                   '<span class="pp-ripple is-buy is-new">0x4b9…21 <b>bought</b> 12.5 IMD of <span class="pp-coin-ticker">$RIBBIT</span></span>'
                   '<span class="pp-ripple is-leap">'+ICON["leap"]+'<span class="pp-coin-ticker">$CROAK</span> just leapt</span>'
                   '<span class="pp-ripple is-sell">0x91a…0c <b>sold</b> 3.1 IMD of <span class="pp-coin-ticker">$LOTUS</span></span>'
                   '<span class="pp-ripple is-buy">0x77e…b4 <b>bought</b> 0.02 ETH of <span class="pp-coin-ticker">$MOSS</span></span>'
                   '<span class="pp-ripple">0xc0f…9e <b>spawned</b> <span class="pp-coin-ticker">$PIP</span></span></div>'),
    "Segmented": ("Trading", 120, '<div class="pp-demo-col"><div class="pp-seg is-trade" role="group" aria-label="Side"><button data-side="buy" aria-pressed="true">Buy</button><button data-side="sell" aria-pressed="false">Sell</button></div>'
                  '<div class="pp-seg" role="group" aria-label="Pay with"><button aria-pressed="true">IMD</button><button aria-pressed="false">ETH</button><button aria-pressed="false">USDG</button></div>'
                  '<div class="pp-tabs" role="tablist"><button role="tab" aria-selected="true">Trades</button><button role="tab" aria-selected="false">Holders</button><button role="tab" aria-selected="false">Creator</button><button role="tab" aria-selected="false">Chorus</button></div></div>'),
    "AmountInput": ("Trading", 150, '<div class="pp-demo-col"><div class="pp-field"><label for="amt">You pay</label>'
                    '<div class="pp-amount"><input id="amt" inputmode="decimal" value="25"><button class="pp-token"><i></i>IMD ▾</button></div>'
                    '<div class="pp-presets"><button>5</button><button>10</button><button>25</button><button>50</button><button>Max</button></div></div></div>'),
    "TradeBox": ("Trading", 560, '<div class="pp-demo-col"><div class="pp-trade">'
                 '<div class="pp-seg is-trade" role="group" aria-label="Side"><button data-side="buy" aria-pressed="true">Buy</button><button data-side="sell" aria-pressed="false">Sell</button></div>'
                 '<div class="pp-field"><label for="tb-amt">You pay</label><div class="pp-amount"><input id="tb-amt" inputmode="decimal" value="0.05"><button class="pp-token"><i></i>ETH ▾</button></div>'
                 '<div class="pp-presets"><button>0.01</button><button>0.05</button><button>0.1</button><button>Max</button></div></div>'
                 '<div class="pp-quote"><div><span>You get (at least)</span><b>2,912,400 $RIBBIT</b></div><div><span>Route</span><b>ETH → IMD → $RIBBIT</b></div>'
                 '<div><span>Price impact</span><b>0.8%</b></div><div><span>Slippage</span><b>1% ▾</b></div>'
                 '<div class="pp-fee"><span>Fee</span><b>2.0% (1.5% base + 0.5% to holders)</b></div></div>'
                 '<button class="pp-btn pp-btn-buy pp-btn-block">Buy $RIBBIT</button></div></div>'),
    "Stat": ("Data", 140, '<div class="pp-demo" style="display:block"><div class="pp-stats">'
             '<div class="pp-stat"><span>Your sPONDPAD</span><b>12,400</b><small>≈ 13,018 $PONDPAD</small></div>'
             '<div class="pp-stat"><span>Dripping in now</span><b>~41,000</b><small>$PONDPAD a day</small></div>'
             '<div class="pp-stat"><span>Burned so far</span><b>4,212,880</b><small>$PONDPAD</small></div></div></div>'),
    "TopBar": ("Navigation", 72, '<header class="pp-top"><a class="pp-logo" href="#"><svg viewBox="0 0 96 96" aria-hidden="true"><path fill="var(--lily)" d="M50 46L71.95 20.39A42 36 0 1 1 61.58 15.40Z"/></svg>pondpad</a>'
               '<nav class="pp-nav"><a href="#" aria-current="page">Explore</a><a href="#">$PONDPAD</a><a href="#">The Pond</a><a href="#">Docs</a></nav>'
               '<div class="pp-search">Search coins, tickers, creators</div><span class="pp-spacer"></span>'
               '<button class="pp-btn pp-btn-primary pp-btn-sm">Spawn</button><button class="pp-btn pp-btn-sm">0x4b9…6821</button></header>'),
    "TabBar": ("Navigation", 72, '<nav class="pp-tabbar" style="max-width:420px">'
               '<a href="#" aria-current="page"><span><svg viewBox="0 0 24 24"><path d="M12 3 2 12h3v8h5v-5h4v5h5v-8h3z"/></svg></span><span>Explore</span></a>'
               '<a href="#"><span><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/></svg></span><span>$PONDPAD</span></a>'
               '<a href="#" class="is-spawn"><span>+</span><span>Spawn</span></a>'
               '<a href="#"><span><svg viewBox="0 0 24 24"><path d="M2 15q5-5 10 0t10 0v5H2z"/></svg></span><span>Pond</span></a>'
               '<a href="#"><span><svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0z"/></svg></span><span>Profile</span></a></nav>'),
}


def doc(name, group, height, body):
    return (f'<!-- @dsCard group="{group}" height={height} -->\n<!doctype html>\n<html lang="en">\n<head><meta charset="utf-8">'
            f'<title>{name}</title></head>\n<body>\n{body}\n</body>\n</html>\n')


def main():
    for name, (group, height, body) in PREVIEWS.items():
        d = COMP / name
        d.mkdir(parents=True, exist_ok=True)
        (d / "preview.html").write_text(doc(name, group, height, body))
    tokens = (HERE / "tokens.css").read_text()
    bundle = (COMP / "bundle.css").read_text()
    sections = "".join(f'<section style="border-bottom:1px solid var(--reed)"><h3 style="margin:0;padding:12px 16px 0;font:700 12px var(--font-sans);color:var(--ink-muted);text-transform:uppercase;letter-spacing:.6px">{n}</h3>{b}</section>'
                       for n, (_, _, b) in PREVIEWS.items())
    (HERE / "preview-all.html").write_text(f"<!doctype html><html><head><meta charset='utf-8'><title>PondPad components</title><link rel='stylesheet' href='fonts/fonts.css'><style>{bundle}\n{tokens}</style></head><body>{sections}</body></html>")
    print(f"wrote {len(PREVIEWS)} previews")


if __name__ == "__main__":
    main()
