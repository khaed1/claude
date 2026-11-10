#!/usr/bin/env python3
"""
Can a third party profit by sandwiching one buyback step?

Model: one Uniswap-v3 range position with constant liquidity L, which inside the range behaves as a constant-product
pool on virtual reserves (x = L/sqrtP tokens, y = L*sqrtP IMD). Fee f is taken from the input of every swap.
Sequence in one block: attacker buys tokens with X IMD, the protocol buys with B IMD, the attacker sells the tokens back.
The script searches X for the attacker's best profit, for B expressed as a multiple of f * y.

Run:  python3 buyback_sandwich_bound.py
"""

def swap_in(reserve_in, reserve_out, amount_in, fee):
    a = amount_in * (1 - fee)
    out = reserve_out * a / (reserve_in + a)
    return reserve_in + a, reserve_out - out, out          # fee stays outside reserves (paid to the position)

def attacker_profit(y, x, B, X, fee):
    y1, x1, tok = swap_in(y, x, X, fee)                    # front-run: IMD -> token
    y2, x2, _ = swap_in(y1, x1, B, fee)                    # protocol buyback: IMD -> token
    x3, y3, imd_back = swap_in(x2, y2, tok, fee)           # back-run: token -> IMD
    return imd_back - X

def best(y, x, B, fee):
    lo, hi, bestp, bestx = 0.0, 50 * y, 0.0, 0.0
    for i in range(1, 20001):                              # log-spaced grid search
        X = y * 10 ** (-6 + 7.7 * i / 20000)
        p = attacker_profit(y, x, B, X, fee)
        if p > bestp: bestp, bestx = p, X
    return bestp, bestx

if __name__ == "__main__":
    y, x = 12_000.0, 250_000_000.0                         # virtual reserves at the starting price: 12,000 IMD, 25% of a 1e9 supply
    print("| Fee tier | Buyback step as a multiple of fee x IMD reserves | Step, IMD | Best sandwich profit, IMD | Profit as share of step |")
    print("|---|---|---|---|---|")
    for fee in (0.003, 0.01):
        for mult in (0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 5.0, 10.0):
            B = mult * fee * y
            p, X = best(y, x, B, fee)
            print(f"| {fee*100:.1f}% | {mult:.1f} | {B:,.1f} | {p:,.4f} | {p/B*100:.2f}% |")
