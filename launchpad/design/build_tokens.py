#!/usr/bin/env python3
"""PondPad design tokens: the single source for colors, type, spacing and radii.

  python3 build_tokens.py          # writes system/tokens.json and tokens.css, checks contrast

`system/tokens.json` is the Design System artifact's format (lists, two themes: night first, day second).
`tokens.css` is what the frontend imports: night on :root (the site's default), day under
[data-theme="day"] and prefers-color-scheme: light. Every text pair named in CONTRAST must hold
4.5:1 (3:1 for large text and marks) in both themes, or the script fails. Standard library only.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# name: (night, day, usage)
COLORS = [
    # Water: surfaces, darkest to lightest in night.
    ("pond-deep", "#0a1719", "#eef5f1", "Page background (deep water at night, morning water by day)."),
    ("pond", "#0f2326", "#ffffff", "Cards, the trade box, panels on pond-deep."),
    ("pond-raised", "#163238", "#e3eee8", "Inputs, hovered rows, segmented controls, chips on pond."),
    ("reed", "#264a50", "#c5d8cf", "Hairlines, card borders, dividers, input borders at rest."),
    ("reed-strong", "#4f8189", "#7d978f", "Input border on hover; the empty part of the Leap meter."),
    # Ink.
    ("ink", "#e6f2ec", "#0d2624", "Primary text and numbers, on pond-deep, pond and pond-raised."),
    ("ink-muted", "#97b4ad", "#46635e", "Labels, metadata, timestamps, on pond-deep, pond and pond-raised."),
    ("ink-faint", "#6f8f88", "#5f7a75", "Placeholders and disabled text only (large or non-essential); 3:1 on pond."),
    # Lily: the brand green, primary actions and buys.
    ("lily", "#6fd08c", "#17784a", "Brand green. Primary button fill, buy side, positive change, links. As text on pond-deep, pond, pond-raised."),
    ("lily-soft", "#173d2b", "#d9f0e1", "Tinted ground behind lily text: selected chips, buy tab, positive pills."),
    ("on-lily", "#06210f", "#ffffff", "Text and icons on a lily fill (primary button)."),
    # Firefly: gold, the Leap, $PONDPAD, graduated frogs.
    ("firefly", "#ffd166", "#e8a400", "The Leap and $PONDPAD as a fill: Leap meter near 100%, $PONDPAD button, spotlight border. Text on it is on-firefly. Never text on the pond grounds (use firefly-ink)."),
    ("firefly-ink", "#ffd166", "#7d5200", "Gold as text: Frog chip, 'just leapt', early-bird tax. On pond-deep, pond and firefly-soft."),
    ("firefly-soft", "#3a3014", "#fbefcc", "Ground behind firefly text: 'About to Leap' spotlight, Frog chip."),
    ("on-firefly", "#2a1d00", "#2a1d00", "Text on a firefly fill."),
    # Lotus: pink, the Chorus (IMD swarm) and social.
    ("lotus", "#f2a6c8", "#a8336b", "The Chorus (IMD swarm): website and audit badges, swarm job links; X verified badge. As text on the pond grounds."),
    ("lotus-soft", "#3b1f2d", "#f8dcea", "Ground behind lotus text."),
    # Coral: sells, losses, errors.
    ("coral", "#ff8a80", "#b02a36", "Sell side, negative change, errors. Always with a word or arrow, never color alone."),
    ("coral-soft", "#3d1c1d", "#fadcdc", "Ground behind coral text: sell tab, error notice."),
    ("on-coral", "#2b0707", "#ffffff", "Text on a coral fill (sell button)."),
    # Water accent for the Leap meter fill and charts.
    ("ripple", "#4fb3bf", "#1f7480", "Leap meter water fill, chart line for IMD price, focus ring. Marks only (3:1)."),
    ("focus", "#ffd166", "#0d2624", "Keyboard focus ring: 2px solid, 2px offset, on every ground."),
]

# Pairs that must pass: (text token, ground token, min ratio)
CONTRAST = [
    *[("ink", g, 4.5) for g in ("pond-deep", "pond", "pond-raised")],
    *[("ink-muted", g, 4.5) for g in ("pond-deep", "pond", "pond-raised")],
    ("ink-faint", "pond", 3.0),
    *[("lily", g, 4.5) for g in ("pond-deep", "pond", "pond-raised", "lily-soft")],
    ("on-lily", "lily", 4.5),
    *[("firefly-ink", g, 4.5) for g in ("pond-deep", "pond", "firefly-soft")],
    ("on-firefly", "firefly", 4.5),
    *[("lotus", g, 4.5) for g in ("pond-deep", "pond", "lotus-soft")],
    *[("coral", g, 4.5) for g in ("pond-deep", "pond", "pond-raised", "coral-soft")],
    ("on-coral", "coral", 4.5),
    ("ripple", "pond", 3.0),
    ("reed-strong", "pond", 3.0),
    *[("focus", g, 3.0) for g in ("pond-deep", "pond", "pond-raised")],
]

FAMILIES = {
    "display": "\"Lilita One\", \"Arial Rounded MT Bold\", \"Trebuchet MS\", system-ui, sans-serif",
    "sans": "\"Nunito\", \"Segoe UI\", system-ui, -apple-system, sans-serif",
    "mono": "\"Martian Mono\", ui-monospace, \"SFMono-Regular\", Menlo, monospace",
}
GOOGLE_FONTS = ("https://fonts.googleapis.com/css2?family=Lilita+One&family=Nunito:wght@400;600;700;800"
                "&family=Martian+Mono:wght@400;500&display=swap")

# Self-hosted (fonts/fonts.css, latin subset, SIL OFL); the artifact copies these files to its fonts/.
FONTS = [{"family": "Lilita One", "file": "fonts/LilitaOne-400.woff2", "weight": "400"},
         {"family": "Nunito", "file": "fonts/Nunito-var.woff2", "weight": "400 800"},
         {"family": "Martian Mono", "file": "fonts/MartianMono-var.woff2", "weight": "400 500"}]

TYPE_GROUPS = [
    {"name": "Display", "family": "display", "styles": [
        {"name": "hero", "fontSize": "56px", "lineHeight": "60px", "fontWeight": 400, "letterSpacing": "0.5px",
         "sample": "Every frog starts as a tadpole.", "usage": "Homepage hero and the Leap modal only. Once per page."},
        {"name": "title", "fontSize": "36px", "lineHeight": "40px", "fontWeight": 400, "letterSpacing": "0.3px",
         "sample": "The Pond", "usage": "Page titles: Explore, Spawn, The Pond, coin name on the coin page."},
        {"name": "heading", "fontSize": "24px", "lineHeight": "30px", "fontWeight": 400,
         "sample": "Lay an egg", "usage": "Section headings and modal titles."},
    ]},
    {"name": "Text", "family": "sans", "styles": [
        {"name": "lead", "fontSize": "18px", "lineHeight": "28px", "fontWeight": 600,
         "sample": "Spawn a coin on Robinhood Chain, paired with IMD.", "usage": "Intro paragraph under a page title."},
        {"name": "body", "fontSize": "15px", "lineHeight": "24px", "fontWeight": 400,
         "sample": "Every buy brings the Leap closer.", "usage": "Running text, docs, descriptions."},
        {"name": "body-strong", "fontSize": "15px", "lineHeight": "24px", "fontWeight": 700,
         "sample": "Fee: 2.0% (1.5% base + 0.5% to holders)", "usage": "Emphasis in running text, table values, button labels."},
        {"name": "label", "fontSize": "13px", "lineHeight": "18px", "fontWeight": 700, "letterSpacing": "0.2px",
         "sample": "Market cap", "usage": "Field labels, card labels, tab labels."},
        {"name": "caption", "fontSize": "12px", "lineHeight": "16px", "fontWeight": 600,
         "sample": "3 min ago", "usage": "Timestamps, footnotes, chip text."},
        {"name": "number-xl", "fontSize": "32px", "lineHeight": "36px", "fontWeight": 800,
         "sample": "2,520 IMD", "usage": "The one key figure in a panel (curve raised, sPONDPAD value). Tabular numbers."},
    ]},
    {"name": "Data", "family": "mono", "styles": [
        {"name": "address", "fontSize": "12px", "lineHeight": "16px", "fontWeight": 400,
         "sample": "0x4b91…6821", "usage": "Addresses, tx hashes, ticker in tables. Shortened to 4…4."},
        {"name": "ticker", "fontSize": "13px", "lineHeight": "18px", "fontWeight": 500, "letterSpacing": "0.4px",
         "sample": "$RIBBIT", "usage": "Coin tickers on cards and in the ripple feed."},
    ]},
]

SPACING = [("space-1", "4px", "Icon-to-label gap, chip padding."),
           ("space-2", "8px", "Gap inside a row of chips or buttons."),
           ("space-3", "12px", "Card inner gap between rows; input padding."),
           ("space-4", "16px", "Card padding on phones; page side gutter on phones."),
           ("space-5", "24px", "Card padding on desktop; gap between cards in the grid."),
           ("space-6", "32px", "Gap between page sections."),
           ("space-7", "48px", "Top of page to title; hero padding.")]
RADIUS = [("radius-sm", "8px", "Chips, badges, inputs, small buttons."),
          ("radius-md", "14px", "Buttons, coin images, segmented controls."),
          ("radius-lg", "22px", "Cards, the trade box, modals. Lily-pad round."),
          ("radius-pill", "999px", "Leap meter, pills, avatar, tab bar.")]
SHADOW = [("shadow-card", "0 1px 0 rgba(255,255,255,0.04), 0 8px 24px rgba(0,0,0,0.28)", "0 1px 2px rgba(13,38,36,0.06), 0 8px 24px rgba(13,38,36,0.08)",
           "Floating things only: trade box on mobile (bottom sheet), menus, toasts. Cards at rest have a border, not a shadow.")]


def lum(hex_):
    h = hex_.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def main():
    byname = {n: (night, day) for n, night, day, _ in COLORS}
    fails = []
    for fg, bg, need in CONTRAST:
        for i, theme in enumerate(("night", "day")):
            r = ratio(byname[fg][i], byname[bg][i])
            if r < need:
                fails.append(f"{theme}: {fg} on {bg} = {r:.2f} < {need}")
    if fails:
        sys.exit("contrast failures:\n  " + "\n  ".join(fails))

    tokens = {
        "name": "PondPad", "version": 1,
        "meta": {"source": "launchpad/design/build_tokens.py", "fonts": GOOGLE_FONTS},
        "color": {"themes": [{"id": "night", "name": "Night pond"}, {"id": "day", "name": "Day pond"}],
                  "tokens": [{"name": n, "value": {"night": a, "day": b}, "usage": u} for n, a, b, u in COLORS]},
        "type": {"fonts": FONTS, "families": FAMILIES, "groups": TYPE_GROUPS},
        "spacing": {"tokens": [{"name": n, "value": v, "usage": u} for n, v, u in SPACING]},
        "radius": {"tokens": [{"name": n, "value": v, "usage": u} for n, v, u in RADIUS]},
        "shadow": {"tokens": [{"name": n, "value": {"night": a, "day": b}, "usage": u} for n, a, b, u in SHADOW]},
    }
    (HERE / "system" / "tokens.json").write_text(json.dumps(tokens, indent=2) + "\n")

    def block(i):
        lines = [f"  --{n}: {c[i]};" for n, *c, _ in [(n, a, b, u) for n, a, b, u in COLORS]]
        lines += [f"  --{n}: {(a, b)[i]};" for n, a, b, _ in SHADOW]
        return "\n".join(lines)

    css = ["/* Generated by build_tokens.py: do not edit. Fonts: fonts/fonts.css (self-hosted). */",
           ":root {", block(0), "  color-scheme: dark;",
           *[f"  --{n}: {v};" for n, v, _ in SPACING + RADIUS],
           *[f"  --font-{k}: {v};" for k, v in FAMILIES.items()], "}",
           "@media (prefers-color-scheme: light) {", "  :root:not([data-theme=\"night\"]) {",
           block(1).replace("\n", "\n  ").replace("  --", "    --", 1), "    color-scheme: light;", "  }", "}",
           ":root[data-theme=\"day\"] {", block(1), "  color-scheme: light;", "}"]
    for g in TYPE_GROUPS:
        for s in g["styles"]:
            decl = [f"font-family: var(--font-{g['family']})", f"font-size: {s['fontSize']}",
                    f"line-height: {s['lineHeight']}", f"font-weight: {s['fontWeight']}"]
            if "letterSpacing" in s:
                decl.append(f"letter-spacing: {s['letterSpacing']}")
            if g["family"] != "display":
                decl.append("font-variant-numeric: tabular-nums")
            css.append(f".t-{s['name']} {{ {'; '.join(decl)}; }}")
    (HERE / "tokens.css").write_text("\n".join(css) + "\n")
    worst = min(ratio(byname[f][i], byname[b][i]) / need for f, b, need in CONTRAST for i in (0, 1))
    print(f"ok: {len(COLORS)} colors × 2 themes, {len(CONTRAST)} pairs checked (tightest margin ×{worst:.2f})")


if __name__ == "__main__":
    main()
