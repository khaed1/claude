"""Step 1: wallet A sends one ETH transfer to the distributor; the distributor funds 103 wallets.
Step 2: every wallet takes 10,000 tIMD from the TestIMD faucet and approves tIMD and PLEA to PoolSwapTest."""
import os, sys, time
from common import *

W = wallets()
D = W[0]
step = sys.argv[1]

if step == 'a2d':
    amount = sys.argv[2]  # ether
    for _ in range(12):
        if nonce(A) == nonce(A, 'pending'):
            break
        print('wallet A has a pending transaction, waiting'); time.sleep(5)
    else:
        sys.exit('wallet A busy')
    h = send_async(os.environ['PONDPAD_TESTNET_KEY'], D['address'], None, value=cast('to-wei', amount))
    rc = receipt(h)
    print('A -> distributor', amount, 'ETH', h, 'status', int(rc['status'], 16))

elif step == 'spread':
    amount = cast('to-wei', sys.argv[2])
    n0 = nonce(D['address'])
    hs = [send_async(D['key'], w['address'], None, value=amount, nonce=n0 + j, gas=300000) for j, w in enumerate(W[1:])]
    bad = [h for h in hs if int(receipt(h)['status'], 16) != 1]
    print('funded', len(hs) - len(bad), 'wallets;', len(bad), 'failed')

elif step == 'setup':
    from concurrent.futures import ThreadPoolExecutor
    idx = [int(x) for x in sys.argv[2].split(',')] if len(sys.argv) > 2 else range(1, len(W))
    def one(i):
        w = W[i]
        n = nonce(w['address'])
        out = [(i, 'faucet', send_async(w['key'], IMD, 'faucet()', nonce=n, gas=800000))]
        out.append((i, 'approve tIMD', send_async(w['key'], IMD, 'approve(address,uint256)', ST, MAXU, nonce=n + 1, gas=300000)))
        out.append((i, 'approve PLEA', send_async(w['key'], PLEA, 'approve(address,uint256)', ST, MAXU, nonce=n + 2, gas=300000)))
        return [(i, what, h, int(receipt(h)['status'], 16)) for i, what, h in out]
    MAXU = cast('max-uint')
    with ThreadPoolExecutor(16) as ex:
        res = [r for rs in ex.map(one, idx) for r in rs]
    fails = [r for r in res if r[3] != 1]
    print('setup txs', len(res), 'failed', fails)
