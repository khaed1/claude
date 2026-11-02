"""Shared helpers for the old v10 (#1242) post-death live trading test on Sepolia.

Throwaway testnet wallets only (wallets.json, mode 600). Never print a key.
"""
import json, os, subprocess, time, math

CAST = '/root/.foundry/bin/cast'
RPC = os.environ.get('R', 'https://ethereum-sepolia-rpc.publicnode.com')
HOOK = '0x3d4CcAc329010b8beA3b14498d9a45EAB00c68Cc'
PLEA = '0x9b8d9aae44e81b1205e227911db279bde6edead9'
GATE = '0x758b8300c62563591950f32717be44a5140a20f9'
IMD = '0x2B69099E59b05901faA1DD164fabf098bf831E82'
ST = '0x9b6b46e2c869aa39918db7f52f5557fe577b6eee'
PM = '0xE03A1074c86CFeDd5C142C4F04F1a1536e203543'
A = '0x4b91078b2374c956a65f7af0999cae0a935e6821'
SIG = 'swap((address,address,uint24,int24,address),(bool,int256,uint160),(bool,bool),bytes)'
KEY = f'({IMD},{PLEA},0,60,{HOOK})'
MINP = 4295128740
MAXP = 1461446703485210103287273052203988822378723970341
PRIO = '1000000'      # 0.001 gwei tip
MAXFEE = '10000000'   # 0.01 gwei max fee (base fee is ~21 wei)
HERE = os.path.dirname(os.path.abspath(__file__))

def wallets():
    return json.load(open(os.path.join(HERE, 'wallets.json')))

def cast(*args, check=True, timeout=120):
    r = subprocess.run([CAST, *args], capture_output=True, text=True, timeout=timeout)
    if check and r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout).strip()[-400:])
    return r.stdout.strip()

def call(to, sig, *args):
    out = cast('call', to, sig, *args, '-r', RPC)
    return out.split()[0] if out else out

def u(x):
    return int(str(x).split()[0])

def nonce(addr, block='latest'):
    return int(cast('nonce', addr, '-r', RPC, '--block', block))

def send_async(key, to, sig, *args, nonce=None, gas=None, value=None):
    cmd = ['send', '--async', '--private-key', key, '-r', RPC, '--priority-gas-price', PRIO, '--gas-price', MAXFEE]
    if nonce is not None:
        cmd += ['--nonce', str(nonce)]
    if gas is not None:
        cmd += ['--gas-limit', str(gas)]
    if value is not None:
        cmd += ['--value', str(value)]
    cmd += [to]
    if sig:
        cmd += [sig, *args]
    return cast(*cmd).splitlines()[-1].strip()

def receipt(h, timeout=300):
    t0 = time.time()
    while time.time() - t0 < timeout:
        r = subprocess.run([CAST, 'receipt', h, '--json', '-r', RPC, '--async'], capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip() and r.stdout.strip() != 'null':
            try:
                d = json.loads(r.stdout)
                if d and d.get('blockNumber'):
                    return d
            except json.JSONDecodeError:
                pass
        time.sleep(3)
    raise TimeoutError(h)

def swap_args(buy, amount_wei, trader):
    p = f'(true,-{amount_wei},{MINP})' if buy else f'(false,-{amount_wei},{MAXP})'
    hd = cast('abi-encode', 'f(address)', trader)
    return [KEY, p, '(false,false)', hd]

def plea_price_from_tick(tick):
    return 1.0001 ** (-tick)  # IMD per PLEA (IMD is currency0)

TOPIC = {}
def topic(sig):
    if sig not in TOPIC:
        TOPIC[sig] = cast('keccak', sig).lower()
    return TOPIC[sig]

def s128(x):
    x = int(x, 16) if isinstance(x, str) else x
    return x - (1 << 128) if x >= 1 << 127 else x

def s24(x):
    x &= (1 << 24) - 1
    return x - (1 << 24) if x >= 1 << 23 else x

def words(data):
    d = data[2:]
    return [int(d[i:i + 64], 16) for i in range(0, len(d), 64)]

def parse(rc):
    """Pool and hook events of one receipt."""
    out = {'status': int(rc['status'], 16), 'gas': int(rc['gasUsed'], 16), 'block': int(rc['blockNumber'], 16),
           'index': int(rc['transactionIndex'], 16), 'events': []}
    for lg in rc.get('logs', []):
        addr = lg['address'].lower()
        t0 = lg['topics'][0].lower()
        w = words(lg['data'])
        if addr == PM.lower() and t0 == topic('Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)'):
            out['amount0'] = s128(w[0]); out['amount1'] = s128(w[1])
            out['tick'] = s24(w[4]); out['liquidity'] = w[3]
            out['price'] = plea_price_from_tick(out['tick'])
        elif addr == HOOK.lower():
            if t0 == topic('FeesTaken(address,bool,uint256,uint256,uint256,uint256)'):
                out['fee_basis'] = w[1] / 1e18; out['fee_imd'] = w[2] / 1e18; out['fee_burn'] = w[3] / 1e18; out['fee_prize'] = w[4] / 1e18
            elif t0 == topic('Trimmed(uint128,uint256,uint256)'):
                out['events'].append(f'TRIM burn {w[1]/1e18:.0f} PLEA, keep {w[2]/1e18:.4f} IMD')
            elif t0 == topic('WallSettled(uint128,uint256,uint256)'):
                out['events'].append(f'WALL SETTLED burn {w[1]/1e18:.0f} PLEA, back {w[2]/1e18:.4f} IMD')
            elif t0 == topic('WallDeployed(int24,int24,uint128,uint256)'):
                out['events'].append(f'WALL DEPLOYED {w[3]/1e18:.4f} IMD ticks {s24(w[0])}..{s24(w[1])}')
            elif t0 == topic('CapRatcheted(uint256,uint256)'):
                out['events'].append(f'CAP {w[0]/1e18:,.0f} -> {w[1]/1e18:,.0f}')
            elif t0 == topic('KeeperTipPaid(address,uint256)'):
                out['events'].append(f'KEEPER TIP {w[0]/1e18:.4f} IMD')
            elif t0 == topic('CashbackStacked(address,uint256)'):
                out['cashback'] = w[0] / 1e18
    return out

def state():
    s = {}
    for k, sig in [('tick', 'currentTick()(int24)'), ('mktPLEA', 'pleaInMarket()(uint256)'), ('mktIMD', 'imdInMarket()(uint256)'),
                   ('wallPLEA', 'pleaInWall()(uint256)'), ('wallImd', 'wallImd()(uint256)'), ('cap', 'inventoryCap()(uint256)'),
                   ('retained', 'retainedImd()(uint256)'), ('claims', 'retainClaims()(uint256)'), ('burned', 'totalBurned()(uint256)'),
                   ('pendRebal', 'pendingRebalance()(bool)')]:
        v = call(HOOK, sig)
        s[k] = v if k == 'pendRebal' else int(v)
    s['supply'] = u(call(PLEA, 'totalSupply()(uint256)'))
    s['restricted'] = call(PLEA, 'restricted()(bool)')
    s['price'] = plea_price_from_tick(s['tick'])
    s['mcap'] = s['price'] * s['supply'] / 1e18
    return s

def fmt_state(s):
    return (f"tick {s['tick']} price {s['price']:.4e} IMD/PLEA mcap {s['mcap']:,.0f} IMD | pool {s['mktPLEA']/1e24:,.1f}M PLEA + {s['mktIMD']/1e18:,.2f} IMD"
            f" | wall {s['wallImd']/1e18:,.2f} IMD ({s['wallPLEA']/1e18:,.0f} PLEA filled) | cap {s['cap']/1e24:,.2f}M"
            f" | retained {(s['retained']+s['claims'])/1e18:,.3f} IMD | burned {s['burned']/1e18:,.0f} | supply {s['supply']/1e24:,.2f}M | rebalance {s['pendRebal']}")
