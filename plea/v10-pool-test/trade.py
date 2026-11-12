"""Live trading phases on the old v10 pool after the Cabal died. One transaction per wallet per round;
every trade, its receipt events and the pool state after each round are appended to results/.

  python3 trade.py whale                       # wallet 1 buys 10,000 tIMD, then a plain transfer to wallet 2
  python3 trade.py round <phase> <pBuy> <lo> <hi> <n> [sellonly]   # one round of n trades sized lo..hi IMD
  python3 trade.py rebalance <phase>          # a trader calls rebalance() if pending
"""
import json, os, random, sys, time
from concurrent.futures import ThreadPoolExecutor
from common import *

W = wallets()
TRADERS = list(range(4, len(W)))
WHALE = 1
RES = os.path.join(HERE, 'results')
os.makedirs(RES, exist_ok=True)
SWAP_GAS = 4_000_000
TRANSFER = None

def log(name, obj):
    with open(os.path.join(RES, name), 'a') as f:
        f.write(json.dumps(obj) + '\n')

def bal(token, addr):
    return u(call(token, 'balanceOf(address)(uint256)', addr))

def transfers(rc, trader):
    """Net tIMD and PLEA moved for the trader in this receipt."""
    t = topic('Transfer(address,address,uint256)')
    d = {'imd': 0, 'plea': 0}
    for lg in rc.get('logs', []):
        if lg['topics'][0].lower() != t or len(lg['topics']) < 3:
            continue
        tok = lg['address'].lower()
        key = 'imd' if tok == IMD.lower() else 'plea' if tok == PLEA.lower() else None
        if not key:
            continue
        frm = '0x' + lg['topics'][1][-40:]
        to = '0x' + lg['topics'][2][-40:]
        v = int(lg['data'], 16)
        if to.lower() == trader.lower():
            d[key] += v
        if frm.lower() == trader.lower():
            d[key] -= v
    return d

def trade(phase, rnd, i, buy, amount_wei, price_before):
    w = W[i]
    h = send_async(w['key'], ST, SIG, *swap_args(buy, amount_wei, w['address']), gas=SWAP_GAS)
    rc = receipt(h)
    p = parse(rc)
    d = transfers(rc, w['address'])
    rec = {'phase': phase, 'round': rnd, 'wallet': i, 'side': 'buy' if buy else 'sell', 'amount': amount_wei / 1e18,
           'tx': h, 'status': p['status'], 'gas': p['gas'], 'block': p['block'], 'index': p['index'],
           'imd': d['imd'] / 1e18, 'plea': d['plea'] / 1e18, 'tick': p.get('tick'), 'price_after': p.get('price'),
           'price_before_round': price_before, 'fee_imd': p.get('fee_imd'), 'fee_burn': p.get('fee_burn'),
           'fee_prize': p.get('fee_prize'), 'cashback': p.get('cashback'), 'events': p['events'], 't': time.time()}
    log('trades.jsonl', rec)
    return rec

def snapshot(phase, label):
    s = state()
    s['phase'] = phase; s['label'] = label; s['t'] = time.time()
    log('states.jsonl', {k: (str(v) if isinstance(v, int) and abs(v) > 2**53 else v) for k, v in s.items()})
    print(f'[{phase}] {label}: {fmt_state(s)}', flush=True)
    return s

def cmd_whale():
    snapshot('P0', 'before the whale buy')
    r = trade('P0', 0, WHALE, True, int(10_000e18), None)
    print('whale buy', r['status'], f"paid {-r['imd']:,.2f} IMD got {r['plea']:,.0f} PLEA", r['events'], r['tx'], flush=True)
    s = snapshot('P0', 'after the whale buy')
    h = send_async(W[WHALE]['key'], PLEA, 'transfer(address,uint256)', W[2]['address'], cast('to-wei', '1000'), gas=500000)
    rc = receipt(h)
    log('trades.jsonl', {'phase': 'P0', 'side': 'transfer', 'wallet': WHALE, 'to': 2, 'amount': 1000, 'tx': h,
                         'status': int(rc['status'], 16), 'gas': int(rc['gasUsed'], 16)})
    print('plain transfer 1,000 PLEA whale -> wallet 2: status', int(rc['status'], 16), h, flush=True)

def cmd_round(phase, p_buy, lo, hi, n, sellonly=False, extra_sellers=()):
    s = snapshot(phase, 'round start')
    price = s['price']
    rnd = int(time.time())
    holders = {}
    pool = TRADERS + list(extra_sellers)
    with ThreadPoolExecutor(16) as ex:
        bals = list(ex.map(lambda i: (i, bal(PLEA, W[i]['address']), bal(IMD, W[i]['address'])), pool))
    plea_bal = {i: p for i, p, _ in bals}
    imd_bal = {i: m for i, _, m in bals}
    used, jobs = set(), []
    for _ in range(n):
        value = random.uniform(lo, hi)
        want_sell = sellonly or random.random() >= p_buy
        if want_sell:
            cands = [i for i in pool if i not in used and plea_bal[i] * price / 1e18 >= 0.5 * value]
            cands = cands or [i for i in pool if i not in used and plea_bal[i] > 0]
            if cands:
                i = random.choice(cands)
                amt = min(int(value / price * 1e18), plea_bal[i])
                used.add(i); jobs.append((i, False, amt)); continue
            if sellonly:
                continue
        cands = [i for i in TRADERS if i not in used and imd_bal[i] >= value * 1e18]
        if not cands:
            continue
        i = random.choice(cands)
        used.add(i); jobs.append((i, True, int(value * 1e18)))
    with ThreadPoolExecutor(20) as ex:
        recs = list(ex.map(lambda j: trade(phase, rnd, j[0], j[1], j[2], price), jobs))
    ok = [r for r in recs if r['status'] == 1]
    b = [r for r in ok if r['side'] == 'buy']; sl = [r for r in ok if r['side'] == 'sell']
    print(f"[{phase}] round: {len(b)} buys ({sum(-r['imd'] for r in b):,.0f} IMD in), {len(sl)} sells ({sum(r['imd'] for r in sl):,.0f} IMD out),"
          f" failed {len(recs) - len(ok)}; events: {[e for r in ok for e in r['events']]}", flush=True)
    snapshot(phase, 'round end')

def cmd_rebalance(phase):
    if call(HOOK, 'pendingRebalance()(bool)') != 'true':
        print(f'[{phase}] rebalance not pending', flush=True); return
    i = random.choice(TRADERS)
    h = send_async(W[i]['key'], HOOK, 'rebalance()', gas=3_000_000)
    rc = receipt(h); p = parse(rc)
    log('trades.jsonl', {'phase': phase, 'side': 'rebalance', 'wallet': i, 'tx': h, 'status': p['status'], 'gas': p['gas'],
                         'block': p['block'], 'events': p['events'], 't': time.time()})
    print(f'[{phase}] rebalance by wallet {i}: status {p["status"]} {p["events"]} {h}', flush=True)
    snapshot(phase, 'after rebalance')

if __name__ == '__main__':
    c = sys.argv[1]
    if c == 'whale':
        cmd_whale()
    elif c == 'round':
        ph, pb, lo, hi, n = sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]), int(sys.argv[6])
        so = len(sys.argv) > 7 and sys.argv[7] == 'sellonly'
        extra = [WHALE] if len(sys.argv) > 8 and sys.argv[8] == 'whale' else []
        cmd_round(ph, pb, lo, hi, n, so, extra)
    elif c == 'rebalance':
        cmd_rebalance(sys.argv[2])
