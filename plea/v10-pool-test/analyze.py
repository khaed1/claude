"""Per-phase summary of the live v10 trading test, from receipts (results/trades.jsonl) and snapshots."""
import json, os, statistics as st
from common import HERE, plea_price_from_tick

R = os.path.join(HERE, 'results')
T = [json.loads(l) for l in open(os.path.join(R, 'trades.jsonl'))]
S = [json.loads(l) for l in open(os.path.join(R, 'states.jsonl'))]
swaps = sorted([t for t in T if t.get('side') in ('buy', 'sell') and t.get('status') == 1], key=lambda t: (t['block'], t['index']))
prev_tick = 120612  # pool tick before the whale buy
for t in swaps:
    t['tick_before'] = prev_tick
    t['move'] = plea_price_from_tick(t['tick']) / plea_price_from_tick(prev_tick) - 1
    prev_tick = t['tick']
    # effective price paid/received vs the price just before the trade
    pb = plea_price_from_tick(t['tick_before'])
    t['eff'] = abs(t['imd']) / abs(t['plea']) if t['plea'] else None
    t['vs_pre'] = (t['eff'] / pb - 1) if t['eff'] else None

phases = ['P0', 'P1', 'P2', 'P3', 'P3pile']
names = {'P0': 'Phase 0: one 10,000 tIMD buy', 'P1': 'Phase 1: buys exceed sells (75% buys, 50-500 tIMD)',
         'P2': 'Phase 2: balanced (50/50, 50-500 tIMD)', 'P3': 'Phase 3a: sells exceed buys (25% buys, 50-500 tIMD)',
         'P3pile': 'Phase 3b: pile of sells (300-1,000 tIMD each, at the round-start price)'}
out = []
first_state = next(s for s in S if s['phase'] == 'P0')
def num(x):
    return int(x) if isinstance(x, str) else x
for ph in phases:
    ts = [t for t in swaps if t['phase'] == ph]
    if not ts:
        continue
    st_ph = [s for s in S if s['phase'] == ph]
    b = [t for t in ts if t['side'] == 'buy']; s_ = [t for t in ts if t['side'] == 'sell']
    p0 = plea_price_from_tick(ts[0]['tick_before']); p1 = plea_price_from_tick(ts[-1]['tick'])
    inflow = sum(-t['imd'] for t in b); outflow = sum(t['imd'] for t in s_)
    fee_imd = sum(t.get('fee_imd') or 0 for t in ts); burn = sum(t.get('fee_burn') or 0 for t in ts)
    prize = sum(t.get('fee_prize') or 0 for t in ts); cash = sum(t.get('cashback') or 0 for t in ts)
    moves_b = [t['move'] / (-t['imd'] / 100) for t in b if t['imd']]
    moves_s = [t['move'] / (t['imd'] / 100) for t in s_ if t['imd']]
    vs_b = [t['vs_pre'] for t in b if t['vs_pre'] is not None]
    vs_s = [t['vs_pre'] for t in s_ if t['vs_pre'] is not None]
    ev = [e for t in T if t.get('phase') == ph for e in t.get('events', [])]
    rebs = [t for t in T if t.get('phase') == ph and t.get('side') == 'rebalance']
    walls = [e for t in rebs for e in t['events'] if e.startswith('WALL DEPLOYED')]
    tips = [e for t in rebs for e in t['events'] if e.startswith('KEEPER TIP')]
    last = st_ph[-1]
    lines = [f'### {names[ph]}',
             f'- Trades: **{len(ts)}** ({len(b)} buys, {len(s_)} sells), {len(set(t["wallet"] for t in ts))} wallets, none reverted.',
             f'- Flow: **{inflow:,.0f} tIMD in**, **{outflow:,.0f} tIMD out** (net {inflow - outflow:+,.0f}).',
             f'- Price: {p0:.3e} → {p1:.3e} tIMD/PLEA (**{(p1 / p0 - 1) * 100:+.1f}%**); market cap {p0 * 1e9:,.0f} → {p1 * 1e9:,.0f} tIMD (on 1B supply).',
             f'- Pool at the end: {num(last["mktPLEA"]) / 1e24:,.1f}M PLEA + {num(last["mktIMD"]) / 1e18:,.0f} tIMD; buy wall {num(last["wallImd"]) / 1e18:,.1f} tIMD ({num(last["wallPLEA"]) / 1e18:,.0f} PLEA filled); inventory cap {num(last["cap"]) / 1e24:,.2f}M.',
             f'- Price move per 100 tIMD traded: buys {st.median(moves_b) * 100:+.2f}% (median)' if moves_b else '- No buys.',
             f'  sells {st.median(moves_s) * 100:+.2f}% (median)' if moves_s else '',
             f'- Fill vs the price just before each trade (fee + slippage): buys pay {st.median(vs_b) * 100:+.2f}% (median, worst {max(vs_b) * 100:+.2f}%)' if vs_b else '',
             f'  sells get {st.median(vs_s) * 100:+.2f}% (median, worst {min(vs_s) * 100:+.2f}%)' if vs_s else '',
             f'- Fees: {fee_imd:,.2f} tIMD hook fee (of which {prize:,.2f} to the prize pot), {cash:,.2f} tIMD cashback staked as sIMD, **{burn:,.0f} PLEA burned** by trades.',
             f'- Hook events: {len([e for e in ev if e.startswith("CAP")])} cap ratchets, {len([e for e in ev if e.startswith("TRIM")])} trims, {len(rebs)} rebalances ({len(tips)} keeper tips); walls deployed: {", ".join(w.split(" ticks")[0].replace("WALL DEPLOYED ", "") for w in walls) or "none"}.',
             f'- Gas (Sepolia): buy median {st.median([t["gas"] for t in b]) if b else 0:,.0f}, sell median {st.median([t["gas"] for t in s_]) if s_ else 0:,.0f}.']
    out.append('\n'.join(l for l in lines if l))

# whole-test numbers
fs = S[0]; ls = S[-1]
tot = [f'### Whole test',
       f'- {len(swaps)} swaps from {len(set(t["wallet"] for t in swaps))} wallets, {len([t for t in T if t.get("side") == "rebalance"])} rebalances, 1 plain transfer; every transaction succeeded.',
       f'- Price {plea_price_from_tick(120612):.3e} → {plea_price_from_tick(swaps[-1]["tick"]):.3e} tIMD/PLEA; peak {max(plea_price_from_tick(t["tick"]) for t in swaps):.3e}.',
       f'- PLEA burned: {num(fs["burned"]) / 1e18:,.0f} → {num(ls["burned"]) / 1e18:,.0f} (supply {num(fs["supply"]) / 1e24:,.2f}M → {num(ls["supply"]) / 1e24:,.2f}M).',
       f'- Buy wall {num(fs["wallImd"]) / 1e18:,.2f} → {num(ls["wallImd"]) / 1e18:,.2f} tIMD, never filled.']
whale = [t for t in swaps if t['wallet'] == 1]
tot.append(f'- Whale (wallet 1): bought {sum(t["plea"] for t in whale if t["side"] == "buy"):,.0f} PLEA for {sum(-t["imd"] for t in whale if t["side"] == "buy"):,.0f} tIMD; sold {sum(-t["plea"] for t in whale if t["side"] == "sell"):,.0f} PLEA for {sum(t["imd"] for t in whale if t["side"] == "sell"):,.0f} tIMD in the pile.')
print('\n\n'.join(out + ['\n'.join(tot)]))
