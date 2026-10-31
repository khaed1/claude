#!/usr/bin/env python3
"""Builds plea/site-design/sample-data.json: one consistent set of numbers for every mockup.

Rules are the agreed mainnet numbers (NEXT_SESSION.md, khaed1/plea branch next): fact score
0-45, need = 71 - fact, 2.25% fees, 15-day seasons, top 25 with 60+ points, Seasons.SHARES,
10,000,000 PLEA bonus, seat x1.2 rounded down, Objection! (sustained when new + 2 < need,
recorded = min of panels), 7-minute sell window, 20-minute objection window and pending expiry,
4-hour cooldown and appeal window, 33-hour dead-man. Names, texts and wallets are made up.

Run: python3 plea/site-design/tools/sample_data.py
"""
import json
import math
import os
from datetime import datetime, timedelta, timezone

UTC = timezone.utc
NOW = datetime(2026, 11, 16, 8, 0, 0, tzinfo=UTC)
OPEN = datetime(2026, 10, 26, 12, 0, 0, tzinfo=UTC)  # START placeholder on the mainnet draft
SEASON = timedelta(days=15)
DEADMAN = timedelta(hours=33)
SELL_WINDOW = timedelta(minutes=7)
OBJECTION_WINDOW = timedelta(minutes=20)
PENDING_EXPIRY = timedelta(minutes=20)
COOLDOWN = timedelta(hours=4)
APPEAL_WINDOW = timedelta(hours=4)

SHARES = [450, 446, 442, 438, 433, 429, 425, 421, 417, 412, 408, 404, 400, 396, 392, 388, 383, 379,
          375, 371, 367, 362, 358, 354, 350]
assert sum(SHARES) == 10000
BONUS = 10_000_000
MIN_POINTS = 60
PRICE = 14.16          # IMD per 1,000,000 PLEA now (hourly snapshot)
PRICE_24H = 14.05      # 24h-ago checkpoint: +0.8%, flat
OPEN_PRICE = 14.00     # 14,000 IMD opening market cap / 1e9 PLEA
BURNED = 26_134_870   # 0.25% of the PLEA leg of ~141,000 IMD of trading (the pots' 0.25%) at ~14.1 IMD per 1M, plus cap trims
SUPPLY = 1_000_000_000 - BURNED
FEE = 0.0225
IMD_LEG = 0.02         # 0.5 cashback + 1 owner + 0.25 pot + 0.25 wall
ORACLE_FEE = 0.5
TIP = 0.25
AUTO_SELL_FEE = 0.35
APPEAL_WALL_FEE = 0.35
STAKE = 0.35


def t(dt):
    return dt.strftime('%Y-%m-%d %H:%M:%S UTC')


def hm(dt):
    return dt.strftime('%H:%M UTC')


def left(until, now=NOW):
    s = int((until - now).total_seconds())
    if s <= 0:
        return '0:00'
    d, rem = divmod(s, 86400)
    h, rem = divmod(rem, 3600)
    m, sec = divmod(rem, 60)
    if d:
        return f'{d}d {h}h'
    if h:
        return f'{h}h {m:02d}m'
    return f'{m:02d}:{sec:02d}'


def share_pts(pct):
    return 16 if pct <= 20 else 9 if pct <= 35 else 3


def hold_pts(days):
    return 7 if days >= 7 else 4 if days >= 3 else 2 if days >= 1 else 0


def pl_pts(pl):  # pl in percent, negative = loss
    if pl < 0:
        return 13
    return 12 if pl <= 50 else 10 if pl <= 200 else 8 if pl <= 500 else 6 if pl <= 1000 else 4


def trend_pts(tr):
    return 9 if tr > 2 else 0 if tr < -2 else 5


def fmt_int(n):
    return f'{int(round(n)):,}'


def fmt_floor2(x):
    """Two decimals rounded down, as the chain pays (floor) and prints (Letterbox._imd)."""
    return f'{math.floor(x * 100 + 1e-9) / 100:,.2f}'


def fmt_imd(x):
    return f'{x:,.2f}'


def plea_value_imd(amount):
    return amount * PRICE / 1e6


def sale_out(amount):
    """IMD out of a sale before price impact: value less the 2.25% fee (IMD side 2%, PLEA burn 0.25%)."""
    return plea_value_imd(amount) * (1 - FEE)


def fee_plea(imd_needed):
    """PLEA a letter or the auto-sell box sells for `imd_needed` IMD (exact output, 2.25% fee)."""
    return imd_needed / (PRICE / 1e6) / (1 - FEE)


def season_of(dt):
    return int((dt - OPEN) / SEASON) + 1


def season_bounds(k):
    start = OPEN + SEASON * (k - 1)
    return start, start + SEASON


# ------------------------------------------------------------------ wallets
W = {
    'mira_eth': '0x7a3f2c19d4e85b06a1f3c9e2d7b4a6f8e1c0c21e',
    'kafka_cat': '0x1c8e4a7b2f90d36e5a1b7c4d9e0f2a3b6c5dd4a9',
    'lettersonly': '0x4e2b9a1c7d3f8e6b0a5c2d9f1e4b7a3c8d6e0b55',
    'oath_keeper': '0x8d1f3e5a7c9b2d4f6e8a0c1b3d5f7e9a2c4b6e13',
    'hodl_goblin': '0x2f7a9c1e3b5d7f9a1c3e5b7d9f1a3c5e7b9d0a88',
    'deg_monk': '0x6b3d5f7a9c1e3b5d7f9a1c3e5b7d9f1a3c5e7c02',
    'shrimp_lord': '0x9e1c3b5d7f9a2c4e6b8d0f1a3c5e7b9d1f3a5d71',
    'brine_oracle': '0x3f8a2c6e0b4d8f1a5c9e3b7d1f5a9c3e7b1d5f28',
    'velvet_rug': '0x7c2e6a0f4b8d2f6a0c4e8b2d6f0a4c8e2b6d0e97',
    None: None,
}
ANON = {
    '0x51ab': '0x51ab3c9d2e7f1a4b8c6d0e5f9a2b3c7d1e4f7c3e',
    '0x9c41': '0x9c41d2e8f3a7b1c5d9e0f4a2b6c8d1e3f5a7e07a',
    '0x3b7e': '0x3b7e1a9c5d2f8e4b6a0c3d7f1e9b5a2c8d4f91d0',
    '0x2d10': '0x2d10f4e8c2a6b0d9e3f7a1c5b9d3e7f1a5c8b6f2',
}


def short(addr):
    return addr[:6] + '…' + addr[-4:]


def who(name_or_short):
    if name_or_short in W:
        return {'name': name_or_short, 'address': W[name_or_short], 'short': short(W[name_or_short])}
    a = ANON[name_or_short]
    return {'name': None, 'address': a, 'short': short(a)}


SEAT = {'mira_eth', 'kafka_cat', 'oath_keeper', 'brine_oracle', 'gm_lawyer'}

# ------------------------------------------------------------------ pleas
# Each: id, who, how (site | site-auto | letter), share %, balance, hold days, P/L %, trend %, score,
# submitted, verdict delay (min), outcome, text, extras.
RAW = [
    dict(id=214, who='mira_eth', how='site', share=20, balance=6_200_000, hold=3.17, pl=-18.0, trend=0.8, score=36,
         submitted=NOW - timedelta(minutes=4, seconds=58), delay=timedelta(minutes=4, seconds=10), agreed=26, answered=30,
         outcome='approved', judge_note='Honest about the timing, and funny about it.',
         text='I bought at the top like a fool and held through two red weeks. My rent is due Friday and my landlord does not take PLEA. Let me sell a fifth; I keep the rest as a monument to my own judgement.'),
    dict(id=213, who='kafka_cat', how='letter', share=20, balance=7_450_000, hold=1.1, pl=12.0, trend=0.8, score=31,
         submitted=NOW - timedelta(minutes=11, seconds=30), delay=timedelta(minutes=5, seconds=2), agreed=24, answered=30,
         outcome='denied', judge_note='Charming, but it is a victory lap, not a reason.',
         text='Dear Cabal, my cat walked across the keyboard and bought PLEA. He is up 12% and now demands tuna. I am only his accountant. Release a fifth so he can eat like a whale.'),
    dict(id=212, who='lettersonly', how='letter', share=20, balance=9_400_000, hold=8.4, pl=-6.0, trend=0.8, score=37,
         submitted=NOW - timedelta(minutes=16), delay=timedelta(minutes=3, seconds=40), agreed=27, answered=30,
         outcome='sold', runner='0x3b7e', judge_note='A real letter. Short, sad, well made.',
         text='Eight days ago I promised my sister I would stop trading memes. She found out. I am keeping four fifths as proof I can hold; let one fifth go so I can buy her dinner and an apology.'),
    dict(id=215, who='deg_monk', how='site', share=20, balance=4_800_000, hold=2.25, pl=35.0, trend=0.8, score=None,
         submitted=NOW - timedelta(minutes=2, seconds=30), outcome='pending',
         text='Second try, shorter this time. I held through two days of silence from the chart and from my wife. One fifth out to buy flowers; the rest stays in the monastery.'),
    dict(id=211, who='0x51ab', how='site', share=10, balance=3_100_000, hold=1.2, pl=0.0, trend=0.8, score=37,
         submitted=NOW - timedelta(minutes=17, seconds=40), delay=timedelta(minutes=5, seconds=0), agreed=25, answered=30,
         outcome='sold', objection=dict(id=9, by='kafka_cat', rescore=None, agreed=None, answered=None, pending=True,
                                        text='The plea says nothing about why: "already regret it" is a mood, not a reason. Judge it as plain.'),
         judge_note='Short and honest. Nothing special, nothing wrong.',
         text='Bought yesterday, already regret it. Not a loss, not a gain, just a lesson. Ten percent out, the rest stays to learn the second half of the lesson.'),
    dict(id=210, who='deg_monk', how='site', share=30, balance=4_800_000, hold=2.2, pl=35.0, trend=0.8, score=None,
         submitted=NOW - timedelta(minutes=58), delay=timedelta(minutes=6, seconds=20), agreed=14, answered=29,
         outcome='noverdict', reason='The panel split: 14 of 29 agreed (17 needed).',
         text='Meditated on this chart for 52 hours. The chart did not meditate back. Thirty percent out; the other seventy stay in the monastery.'),
    dict(id=209, who='0x9c41', how='site', share=15, balance=5_200_000, hold=3.5, pl=-12.0, trend=0.8, score=34,
         submitted=NOW - timedelta(hours=2, minutes=10), delay=timedelta(minutes=4, seconds=5), agreed=25, answered=30,
         outcome='sold', objection=dict(id=8, by='0x2d10', rescore=29, agreed=23, answered=30,
                                        text='This plea is the 2025 CabalCoin winner with two words changed; copied text scores low under the rules.'),
         text='My grandmother says a man who cannot sell a meme coin is not a man but a bag. I would like to prove her wrong by selling 15% and keeping the rest as a bag of honour.'),
    dict(id=208, who='hodl_goblin', how='site', share=20, balance=8_000_000, hold=3.4, pl=-22.0, trend=0.8, score=35,
         submitted=NOW - timedelta(hours=3, minutes=5), delay=timedelta(minutes=3, seconds=58), agreed=28, answered=30,
         outcome='lapsed', judge_note='Specific and loyal. The goblin will be fine.',
         text='Goblin law says never sell. Goblin landlord says pay rent. Goblin compromise: one fifth, and I keep the hoard warm for the other four.'),
    dict(id=207, who='oath_keeper', how='site', share=20, balance=5_600_000, hold=3.06, pl=-15.0, trend=0.8, score=34,
         submitted=NOW - timedelta(hours=4, minutes=40), delay=timedelta(minutes=4, seconds=30), agreed=26, answered=30,
         outcome='sold', appeal_of=205,
         text='My first plea scored 30 against a need of 33, and that was fair: I wrote it in a hurry. Here is the real reason. My daughter starts school on Monday and needs shoes; I keep 80% and my word.'),
    dict(id=206, who='brine_oracle', how='site', share=15, balance=2_000_000, hold=4.1, pl=-9.0, trend=0.8, score=34,
         submitted=NOW - timedelta(hours=5, minutes=25), delay=timedelta(minutes=4, seconds=40), agreed=25, answered=30,
         outcome='sold', objection=dict(id=7, by='0x2d10', rescore=33, agreed=24, answered=30,
                                        text='The seller pleaded the same story on another token last month.'),
         text='Four days of holding taught me patience, humility and that I should not check the chart at 3 a.m. I would like to sell 15% and sleep.'),
    dict(id=205, who='oath_keeper', how='site', share=20, balance=5_600_000, hold=3.0, pl=-15.0, trend=0.8, score=30,
         submitted=NOW - timedelta(hours=6, minutes=12), delay=timedelta(minutes=4, seconds=50), agreed=25, answered=30,
         outcome='denied', judge_note='Sincere but plain.',
         text='Need to sell some, life costs money. Thanks.'),
    dict(id=204, who='shrimp_lord', how='site-auto', share=20, balance=2_000_000, hold=7.6, pl=-30.0, trend=0.8, score=33,
         submitted=NOW - timedelta(hours=7, minutes=2), delay=timedelta(minutes=5, seconds=10), agreed=22, answered=30,
         outcome='sold', runner='0x3b7e', judge_note='Small, honest, and the shrimp joke landed.',
         text='I am a shrimp among whales. My whole bag is two million PLEA and my whole dinner budget is zero. Twenty percent out, eighty percent swimming on.'),
    dict(id=203, who='velvet_rug', how='site', share=20, balance=3_000_000, hold=3.5, pl=-20.0, trend=0.8, score=29,
         submitted=datetime(2026, 11, 16, 0, 5, 0, tzinfo=UTC), delay=timedelta(minutes=4, seconds=20), agreed=24, answered=30,
         outcome='denied', appeal_of=201, judge_note='Louder, not better.',
         text='APPEAL OF THE CENTURY: the first plea was right and the judges were wrong. I will not explain again. Twenty percent, please, and quickly, before my patience is also seized.'),
    dict(id=201, who='velvet_rug', how='site', share=20, balance=3_000_000, hold=3.4, pl=-20.0, trend=0.8, score=28,
         submitted=datetime(2026, 11, 15, 21, 40, 0, tzinfo=UTC), delay=timedelta(minutes=4, seconds=30), agreed=25, answered=30,
         outcome='denied', judge_note='Plain, and a little rude.',
         text='I want to sell. That is my reason. You do not need more.'),
    dict(id=196, who='mira_eth', how='site', share=15, balance=2_000_000, hold=4.1, pl=-9.0, trend=0.8, score=33,
         submitted=datetime(2026, 11, 12, 18, 31, 0, tzinfo=UTC), delay=timedelta(minutes=4, seconds=40), agreed=24, answered=30,
         outcome='sold', judge_note='Spite is a reason. A small one.',
         text='Small bag, small plea. I am selling fifteen percent to pay back the friend who told me not to buy. He was right; I am keeping the rest out of spite.'),
]


def build_plea(r):
    sh = share_pts(r['share'])
    ho = hold_pts(r['hold'])
    pl = pl_pts(r['pl'])
    tr = trend_pts(r['trend'])
    fact = sh + ho + pl + tr
    need = 71 - fact
    assert need <= 45, r['id']
    amount = r['balance'] * r['share'] // 100
    amount = min(amount, 2_500_000)
    assert amount >= max(r['balance'] // 100, 0) and amount <= r['balance'] // 2, r['id']
    w = who(r['who'])
    seat = r['who'] in SEAT
    sub = r['submitted']
    p = {
        'id': r['id'],
        'seller': w,
        'seat': seat,
        'how': r['how'],
        'byLetter': r['how'] == 'letter',
        'autoSell': r['how'] in ('letter', 'site-auto'),
        'text': r['text'],
        'bytes': len(r['text'].encode('utf-8')),
        'amount': amount,
        'amountFmt': fmt_int(amount),
        'balance': r['balance'],
        'balanceFmt': fmt_int(r['balance']),
        'sharePct': r['share'],
        'valueImd': fmt_imd(plea_value_imd(amount)),
        'facts': {
            'share': {'value': f"{r['share']}%", 'points': sh},
            'hold': {'value': hold_text(r['hold']), 'points': ho},
            'pl': {'value': f"{r['pl']:+.0f}%".replace('-', '−'), 'points': pl},
            'trend': {'value': 'flat' if tr == 5 else 'up' if tr == 9 else 'down', 'points': tr},
        },
        'fact': fact,
        'need': need,
        'submittedAt': t(sub),
        'submittedAgo': ago(sub),
        'outcome': r['outcome'],
    }
    if r.get('appeal_of'):
        p['appealOf'] = r['appeal_of']
    if r['outcome'] == 'pending':
        p['expiresAt'] = t(sub + PENDING_EXPIRY)
        p['expiresIn'] = left(sub + PENDING_EXPIRY)
        p['stamp'] = 'PENDING'
        return p
    verdict_at = sub + r['delay']
    p['verdictAt'] = t(verdict_at)
    p['verdictAgo'] = ago(verdict_at)
    p['panel'] = {'seats': 30, 'quorum': 17, 'agreed': r['agreed'], 'answered': r['answered'],
                  'took': f"{int(r['delay'].total_seconds() // 60)}m {int(r['delay'].total_seconds() % 60)}s"}
    if r.get('judge_note'):
        p['judgeNote'] = r['judge_note']
    if r['outcome'] == 'noverdict':
        p['stamp'] = 'NO VERDICT'
        p['reason'] = r['reason']
        p['note'] = 'Cleared at once by the Intake. No cooldown; the 0.5 IMD oracle fee is not refunded.'
        return p
    score = r['score']
    p['score'] = score
    approved = score >= need
    assert approved == (r['outcome'] in ('approved', 'sold', 'lapsed')), r['id']
    p['sellWindowEnds'] = t(verdict_at + SELL_WINDOW) if approved else None
    p['cooldownEnds'] = t(verdict_at + COOLDOWN) if not approved or r['outcome'] == 'lapsed' else None
    if not approved and r.get('appeal_of'):
        p['stamp'] = 'UPHELD'
        p['note'] = f"Appeal of #{r['appeal_of']} denied again: no further appeal. The 4-hour cooldown runs from this verdict (until {hm(verdict_at + COOLDOWN)})."
        return p
    if not approved:
        p['stamp'] = 'DENIED'
        p['appealBy'] = hm(verdict_at + APPEAL_WINDOW)
        p['appealIn'] = left(verdict_at + APPEAL_WINDOW)
        p['appealCost'] = ('APPEAL letter: 1.10 IMD paid in PLEA (0.50 oracle fee + 0.35 to the buy wall + 0.25 tip, back if you send SELL yourself)'
                           if r['how'] == 'letter' else
                           '0.50 IMD oracle fee + 0.35 IMD to the buy wall, from your IMD (with the auto-sell box: paid in PLEA, plus the 0.25 IMD tip)')
        return p
    # approved family
    objection_ends = verdict_at + OBJECTION_WINDOW
    p['objectionWindowEnds'] = t(objection_ends)
    recorded = score
    if 'objection' in r and r['objection'].get('pending'):
        o = r['objection']
        p['objection'] = {'id': o['id'], 'by': who(o['by']), 'text': o['text'], 'ruling': 'PENDING',
                          'line': f"OBJECTION #{o['id']} pending: points held until the second panel rules",
                          'sustainedIf': f"new score {need - 3} or less (more than 2 below the need {need})"}
        recorded = score
    elif 'objection' in r:
        o = r['objection']
        sustained = o['rescore'] + 2 < need
        recorded = None if sustained else min(score, o['rescore'])
        p['objection'] = {
            'id': o['id'], 'by': who(o['by']), 'text': o['text'], 'rescore': o['rescore'],
            'panel': {'agreed': o['agreed'], 'answered': o['answered']},
            'ruling': 'SUSTAINED' if sustained else 'OVERRULED',
            'stake': 'returned' if sustained else 'to the season 2 prize pot',
            'line': (f"SUSTAINED ({o['rescore']} vs need {need}) · no points" if sustained
                     else f"OVERRULED ({o['rescore']} vs need {need}) · counts {math.floor(min(score, o['rescore']) * 1.2) if seat else min(score, o['rescore'])} points"),
        }
    p['recordedScore'] = recorded
    p['points'] = None if recorded is None else (math.floor(recorded * 1.2) if seat else recorded)
    held = NOW < objection_ends or ('objection' in r and r['objection'].get('pending'))
    p['pointsHeld'] = bool(held)
    if held and p['points'] is not None:
        why = 'an objection is pending' if ('objection' in r and r['objection'].get('pending')) else f'objections open until {hm(objection_ends)}'
        p['pointsLine'] = f"+{p['points']} points held ({why})"
    if NOW < objection_ends:
        p['objectionsIn'] = left(objection_ends)
    if r['outcome'] == 'approved':
        p['stamp'] = 'APPROVED' if not r.get('appeal_of') else 'OVERTURNED'
        p['sellIn'] = left(verdict_at + SELL_WINDOW)
        p['objectionsIn'] = left(objection_ends)
        p['pointsLine'] = f"+{p['points']} points held until {hm(objection_ends)} (objections open)"
        p['saleQuote'] = sale_quote(p['amount'], auto=False)
        p['deadmanReset'] = t(verdict_at + DEADMAN)
    elif r['outcome'] == 'lapsed':
        p['stamp'] = 'LAPSED'
        p['note'] = 'Approved but not sold within 7 minutes. The score still counts for the season; the 4-hour cooldown runs from the verdict.'
    else:
        p['stamp'] = 'SOLD' if not r.get('appeal_of') else 'OVERTURNED'
        p['soldStamp'] = 'SOLD'
        auto = r['how'] in ('letter', 'site-auto')
        q = sale_quote(p['amount'], auto=r['how'] == 'site-auto')
        p['soldFor'] = q['youGet']
        p['soldAt'] = t(verdict_at + timedelta(minutes=1, seconds=12))
        if auto:
            rid = r.get('runner', '0x3b7e')
            p['deliveredBy'] = who(rid)
            p['runnerTip'] = '0.25 IMD'
        p['cooldownEnds'] = t(verdict_at + timedelta(minutes=1, seconds=12) + COOLDOWN)
    return p


def hours_left(until, now=NOW):
    s = int((until - now).total_seconds())
    return f'{s // 3600}h {(s % 3600) // 60:02d}m'


def hold_text(days):
    d = int(days)
    h = int(round((days - d) * 24))
    return f'{d}d {h}h' if d else f'{h}h'


def ago(dt):
    s = int((NOW - dt).total_seconds())
    if s < 60:
        return f'{s} s ago'
    if s < 3600:
        return f'{s // 60} min ago'
    if s < 86400:
        return f'{s // 3600} h ago'
    return f'{s // 86400} d ago'


def sale_quote(amount, auto):
    gross = sale_out(amount)
    impact = 0.0015  # small pool impact for the mockup
    out = gross * (1 - impact)
    minimum = plea_value_imd(amount) * (1 - FEE) * 0.95
    q = {
        'value': fmt_imd(plea_value_imd(amount)),
        'expected': fmt_imd(out),
        'minimum95': fmt_imd(minimum),
        'slippage1Min': fmt_imd(out * 0.99),
    }
    if auto:
        q['autoSellFee'] = fmt_imd(AUTO_SELL_FEE)
        q['youGet'] = fmt_imd(out - AUTO_SELL_FEE)
        q['youGetAtLeast'] = fmt_imd(minimum - AUTO_SELL_FEE)
    else:
        q['youGet'] = fmt_imd(out)
    return q


pleas = [build_plea(r) for r in RAW]
by_id = {p['id']: p for p in pleas}
# An appealed denial has no appeal left: point it at its appeal instead.
for p in pleas:
    if p.get('appealOf') in by_id:
        orig = by_id[p['appealOf']]
        orig['appealedBy'] = p['id']
        for k in ('appealBy', 'appealIn', 'appealCost'):
            orig.pop(k, None)
ids = [p['id'] for p in sorted(pleas, key=lambda q: q['submittedAt'])]
assert ids == sorted(ids), ('ids must rise with submission time', ids)
pleas.sort(key=lambda q: -q['id'])

# ------------------------------------------------------------------ season 2 leaderboard
# Recorded points per wallet this season (best three count). #214 is not recorded yet (held).
S2 = {
    'kafka_cat': [45, 44, 43, 37],
    'oath_keeper': [44, 40, 40],
    'lettersonly': [41, 39, 37, 37],
    'mira_eth': [40, 39, 37],          # #188 (34 -> 40), #196 (33 -> 39), #171 (31 -> 37); #214 is held
    '0x9c41': [38, 36, 35],
    'shrimp_lord': [37, 36, 33],
    'hodl_goblin': [35, 35, 34, 30],
    'deg_monk': [38, 34, 31],
    'brine_oracle': [39, 36, 33],      # #206 overruled: counts 33 -> 39 with the seat
    'velvet_rug': [35, 34, 32],
    'not_selling': [34, 33, 32],
    'paper_crane': [36, 32, 30],
    'gm_lawyer': [33, 32, 32],
    'tuna_fund': [34, 31, 30],
    'quiet_whale': [32, 31, 30],
    'moth_capital': [33, 30, 29],
    '0x51ab': [31, 30, 29],
    'judge_judy_fan': [30, 30, 28],
    'salt_miner': [31, 29, 27],
    'bagholder_99': [29, 28, 27],
    'lamp_oil': [33, 28],
    'rope_seller': [30, 27],
    'fresh_start': [32, 26],   # a recorded score is at least 26 (the lowest possible need)
    'one_shot': [44],
    'late_owl': [35],
}
SEAT_S2 = {'kafka_cat', 'oath_keeper', 'mira_eth', 'brine_oracle', 'gm_lawyer'}
POT_S2 = 184.20
ROLLOVER_S1 = 22.56

rows = []
for name, pts in S2.items():
    best = sorted(pts, reverse=True)[:3]
    rows.append({'name': name, 'best': best, 'points': sum(best), 'seat': name in SEAT_S2})
rows.sort(key=lambda r: -r['points'])
assert len({r['points'] for r in rows}) == len(rows), 'no ties (the chain breaks ties by the newest counted plea id)'
lb = []
paid_bps = 0
for i, r in enumerate(rows[:25]):
    rank = i + 1
    bps = SHARES[i]
    qualifies = r['points'] >= MIN_POINTS
    entry = {
        'rank': rank,
        'name': r['name'] if not r['name'].startswith('0x') else None,
        'address': short(ANON[r['name']]) if r['name'].startswith('0x') else None,
        'seat': r['seat'],
        'best': r['best'],
        'points': r['points'],
        'shareBps': bps,
        'sharePct': f'{bps / 100:.2f}%',
        'qualifies': qualifies,
        'prizeImd': fmt_floor2(POT_S2 * bps / 10000) if qualifies else None,
        'bonusPlea': fmt_int(BONUS * bps / 10000) if qualifies else None,
        'you': r['name'] == 'mira_eth',
    }
    if qualifies:
        paid_bps += bps
    lb.append(entry)
roll_bps = 10000 - paid_bps
# mira after #214 is recorded: 43 replaces 37
mira_after = sorted([40, 39, 37, 43], reverse=True)[:3]

season2 = {
    'number': 2,
    'start': t(season_bounds(2)[0]),
    'end': t(season_bounds(2)[1]),
    'left': left(season_bounds(2)[1]),
    'potImd': fmt_imd(POT_S2),
    'potSources': {
        'tradeFees': fmt_imd(POT_S2 - ROLLOVER_S1 - 23 * AUTO_SELL_FEE - 2 * STAKE),
        'autoSellFees': f'{fmt_imd(23 * AUTO_SELL_FEE)} (23 sales from the site\'s auto-sell box × 0.35; letters pay none)',
        'overruledStakes': f'{fmt_imd(2 * STAKE)} (2 overruled objections × 0.35)',
        'rolloverFromSeason1': fmt_imd(ROLLOVER_S1),
    },
    'bonusPlea': fmt_int(BONUS),
    'bonusSeason': '2 of 6',
    'leaderboard': lb,
    'qualifying': sum(1 for e in lb if e['qualifies']),
    'ifEndedNow': {
        'paidPct': f'{paid_bps / 100:.2f}%',
        'rolloverImd': fmt_floor2(POT_S2 * roll_bps / 10000),
        'rolloverPct': f'{roll_bps / 100:.2f}%',
        'bonusBurned': fmt_int(BONUS * roll_bps / 10000),
    },
    'you': {
        'name': 'mira_eth', 'seat': True, 'bestRecorded': [40, 39, 37], 'points': 116,
        'heldPlea': 214, 'heldPoints': 43, 'afterRecord': mira_after, 'pointsAfterRecord': sum(mira_after),
    },
    'closeAfterGrace': t(season_bounds(2)[1] + timedelta(hours=1)),
}
season2['you']['rank'] = next(e['rank'] for e in lb if e['you'])
after_rows = sorted([(r['name'], r['points'] if r['name'] != 'mira_eth' else sum(mira_after)) for r in rows],
                    key=lambda x: -x[1])
season2['you']['rankAfterRecord'] = [n for n, _ in after_rows].index('mira_eth') + 1

POT_S1 = 212.48
S1_WINNERS = 22
s1_paid = sum(SHARES[:S1_WINNERS])
season1 = {
    'number': 1,
    'start': t(season_bounds(1)[0]),
    'end': t(season_bounds(1)[1]),
    'closedAt': '2026-11-10 13:05:41 UTC',
    'closedBy': short(ANON['0x3b7e']),
    'potImd': fmt_imd(POT_S1),
    'winners': S1_WINNERS,
    'paidImd': fmt_floor2(POT_S1 * s1_paid / 10000),
    'rolloverImd': fmt_floor2(POT_S1 * (10000 - s1_paid) / 10000),
    'bonusPaid': fmt_int(BONUS * s1_paid / 10000),
    'bonusBurned': fmt_int(BONUS * (10000 - s1_paid) / 10000),
    'top3': [
        {'rank': 1, 'name': 'one_shot', 'points': 129, 'prizeImd': fmt_floor2(POT_S1 * 450 / 10000), 'bonusPlea': fmt_int(BONUS * 450 / 10000)},
        {'rank': 2, 'name': 'kafka_cat', 'points': 127, 'prizeImd': fmt_floor2(POT_S1 * 446 / 10000), 'bonusPlea': fmt_int(BONUS * 446 / 10000)},
        {'rank': 3, 'name': 'lettersonly', 'points': 118, 'prizeImd': fmt_floor2(POT_S1 * 442 / 10000), 'bonusPlea': fmt_int(BONUS * 442 / 10000)},
    ],
}
assert abs(float(season1['rolloverImd']) - ROLLOVER_S1) < 0.01, season1['rolloverImd']

# ------------------------------------------------------------------ market, Cabal, fees
last_verdict = datetime.strptime(by_id[214]['verdictAt'], '%Y-%m-%d %H:%M:%S UTC').replace(tzinfo=UTC)
market = {
    'now': t(NOW),
    'tradingOpened': t(OPEN),
    'pricePer1M': fmt_imd(PRICE),
    'price24hAgoPer1M': fmt_imd(PRICE_24H),
    'trend24h': f'{(PRICE / PRICE_24H - 1) * 100:+.1f}% (flat: within ±2%)',
    'openPricePer1M': fmt_imd(OPEN_PRICE),
    'supply': fmt_int(SUPPLY),
    'burned': fmt_int(BURNED),
    'marketCapImd': fmt_int(PRICE * SUPPLY / 1e6),
    'wallImd': '412.80',
    'pleas': {'total': 215, 'approved': 140, 'denied': 55, 'noVerdict': 19, 'pending': 1, 'approvalRateOfJudged': f'{140 / 195 * 100:.1f}%'},   # enough approvals for both seasons' boards
    'cabal': {
        'alive': True,
        'lastVerdict': t(last_verdict),
        'diesAt': t(last_verdict + DEADMAN),
        'diesIn': hours_left(last_verdict + DEADMAN),
        'rule': 'The Cabal dies after 33 hours without a verdict; then PLEA trades freely forever.',
    },
}

buy = {
    'pay': '100.00', 'unit': 'IMD', 'balanceImd': '412.50',
    'get': '6,881,240', 'minimum1pct': '6,812,427',
    # The hook takes its 2% IMD fee from what reaches the pool (100 * 200 / 10200), plus 0.25% of the PLEA burned.
    'fees': {'total': '2.25%', 'reachesPool': '98.04', 'feeImd': '1.96', 'cashback': '0.49', 'owner': '0.98', 'pot': '0.245', 'wall': '0.245', 'burnPct': '0.25% of the PLEA'},
    'launchWindow': {
        'example': 'at 12:30 UTC on opening day (30 of 90 minutes gone)',
        'launchFeePct': '46.7% of the IMD that reaches the pool, on top of the normal 2.25% (falls in a straight line from 70% to 0% at 13:30 UTC)',
        'perBuyCap': '5,000,000 PLEA',
    },
    'record': {'costBasisPer1M': '17.27', 'heldWeighted': '3d 4h', 'pl': '−18.0%'},
    'cashbackEarnedImd': '0.83',
}

# The site's plead form for #214 with the auto-sell box on, as the alternative
fee_imd = ORACLE_FEE + TIP
fee_p = fee_plea(fee_imd)
autosell = {
    'feesImd': fmt_imd(fee_imd),
    'feesPleaAbout': '54,180',   # the exact-output fee swap needs about 54,182 PLEA (reviewed against PleaHook)
    'feesPleaMax': fmt_int(math.ceil(fee_imd * 1.1 / (PRICE / 1e6))),   # Letterbox.feesFor: snapshot value + 10%
    'tipImd': fmt_imd(TIP),
    'appealFeesImd': '1.10',
    'appealFeesPleaAbout': fmt_int(round(1.10 / (PRICE / 1e6) / (1 - FEE), -1)),
    'appealFeesPleaMax': fmt_int(math.ceil(1.10 * 1.1 / (PRICE / 1e6))),
    'autoSellFeeImd': fmt_imd(AUTO_SELL_FEE),
    'quote': sale_quote(1_240_000, auto=True),
    'explain': 'Fees are paid in PLEA in the same transaction (0.50 IMD oracle fee + 0.25 IMD tip). If approved, anyone can sell it for you within 7 minutes and earns the tip (our runner does it; you can also press Sell and keep the tip); 0.35 IMD of the sale goes to the season prize pot. If nobody sells it, or on any other ending, your PLEA and the tip come back (the 0.50 IMD oracle fee is spent).',
    'manual': 'Off: you pay the 0.50 IMD oracle fee from your IMD and sell yourself within 7 minutes, no extra fee.',
}

plead_form = {
    'balance': '6,200,000', 'amount': '1,240,000', 'chips': ['1%', '10%', '20%', '35%', 'Max'], 'maxChip': 'Max = 2,500,000 (40% of your balance; the cap is 2,500,000)',
    'mockClock': 'This page shows the form at 07:54 UTC, just before plea #214 was sent (at 08:00 #214 is open, so a new plea would be refused: one plea at a time).',
    'min': fmt_int(6_200_000 // 100), 'max': fmt_int(min(2_500_000, 6_200_000 // 2)),
    'fact': by_id[214]['facts'], 'factScore': by_id[214]['fact'], 'need': by_id[214]['need'],
    'cannotPassExample': {
        'who': 'you, at the Max chip',
        'amount': '2,500,000 of 6,200,000 (40%)', 'facts': 'share 40% \u2192 3 + held 3d 4h \u2192 4 + loss \u2192 13 + flat \u2192 5 = 25', 'need': 46,
        'message': 'Even a perfect plea (45) cannot pass at this size. Plead 20% or less (need 33) or wait for better facts.',
    },
    'cooldownExample': 'Next plea possible at 12:00 UTC (4-hour cooldown after your sale).',
    'oracleFee': '0.50 IMD',
}

letters = {
    'letterbox': '[Letterbox address, after launch]',
    'sepoliaLetterbox': '0xbc335Ae3DC12D4bF78f8E44A03f4fC62e3afd1d3 (run 9)',
    'share': '20% of your PLEA, at most 2,500,000',
    'cost': '0.75 IMD paid in PLEA (0.50 oracle fee + 0.25 tip); an APPEAL letter 1.10 IMD (+0.35 to the buy wall)',
    'costPleaAbout': '54,180',
    'noAutoSellFee': 'Letters pay no auto-sell fee; send SELL yourself and the 0.25 tip comes back.',
    'limits': ['at most 280 bytes (≈ 280 Latin, 140 Cyrillic or Arabic, 93 CJK characters)', 'one line, no hidden characters',
               f"a balance of at least about {fmt_int(math.ceil(math.ceil(fee_imd * 1.1 / (PRICE / 1e6)) * 10))} PLEA at today's price: the fees (at most {fmt_int(math.ceil(fee_imd * 1.1 / (PRICE / 1e6)))} PLEA) may take at most 10% of your PLEA",
               'a plea worth at least 0.70 IMD (20% of your PLEA)', 'the contract floor: 20% must be at least 1,000 PLEA'],
    'examples': [
        'I held through the dip like a lighthouse keeper holds through a storm. The storm is over; I would like to buy the keeper a sandwich. Twenty percent, please.',
        'APPEAL My first letter said too little. The truth: my brother lent me the money and his wedding is Saturday. I keep the rest and repay him with interest.',
        'NAME mira_eth',
    ],
    'status': [
        f"Plea #212 · SOLD for {by_id[212]['soldFor']} IMD · +{by_id[212]['points']} points held until {hm(datetime.strptime(by_id[212]['objectionWindowEnds'], '%Y-%m-%d %H:%M:%S UTC'))} (objections open) · Cooldown until {hm(datetime.strptime(by_id[212]['cooldownEnds'], '%Y-%m-%d %H:%M:%S UTC'))}",
        f"Plea #213 · DENIED ({by_id[213]['score']} vs {by_id[213]['need']}) · send APPEAL <text> before {by_id[213]['appealBy']} · call settle to get your PLEA back (a new plea waits for the cooldown)",
        'No plea yet. Next plea possible now.',
    ],
}

objections = {
    'window': '20 minutes after an approval',
    'cost': '0.50 IMD oracle fee + 0.35 IMD stake',
    'rule': 'A new panel of 30 re-scores the plea. Sustained when the new score is more than 2 below the need: no points, your stake comes back. Otherwise overruled: the plea counts the lowest score any panel gave, and your stake goes to the season prize pot. Void when the panel splits or gives no answer within 20 minutes: nothing changes, your stake comes back. Stakes move when anyone calls settle. At most 2 objections per plea, from different wallets; a sustain closes the case. The sale is never touched.',
    'open': [
        {'plea': 214, 'closesIn': by_id[214]['objectionsIn'], 'closesAt': by_id[214]['objectionWindowEnds'], 'filed': 0, 'max': 2, 'note': 'Your own plea: you cannot object to it.'},
        {'plea': 212, 'closesIn': left(datetime.strptime(by_id[212]['objectionWindowEnds'], '%Y-%m-%d %H:%M:%S UTC').replace(tzinfo=UTC)), 'closesAt': by_id[212]['objectionWindowEnds'], 'filed': 0, 'max': 2, 'note': 'Sold by letter; the sale stands whatever the ruling.'},
        {'plea': 211, 'closesIn': left(datetime.strptime(by_id[211]['objectionWindowEnds'], '%Y-%m-%d %H:%M:%S UTC').replace(tzinfo=UTC)), 'closesAt': by_id[211]['objectionWindowEnds'], 'filed': 1, 'max': 2, 'pending': 'objection #9 by kafka_cat', 'sustainedIf': by_id[211]['objection']['sustainedIf']},
    ],
    'recent': [by_id[209]['objection'] | {'plea': 209}, by_id[206]['objection'] | {'plea': 206}],
}

claim = {
    'split': {'distributor': '120,000,000 PLEA (12%)', 'swarm': '100,000,000 (10%)', 'airdrop': '20,000,000 (2%)'},
    'rootSetAt': '2026-10-26 13:02:11 UTC',
    'claimsTotal': 482,
    'claimedSoFar': 311,
    'examples': [
        {'address': short(W['mira_eth']), 'full': W['mira_eth'], 'state': 'claimable', 'amount': '48,210', 'index': 117},
        {'address': '0x2b9c…a01f', 'state': 'claimed', 'amount': '120,000', 'claimedAt': '2026-10-27 09:14 UTC'},
        {'address': '0x0d4e…b3c2', 'state': 'not-listed'},
    ],
    'delegate': {
        'registry': '0x00000000000000447e69651d841bD8D104Bed493',
        'hot': short(W['mira_eth']),
        'vault': '0x5e1d…44b0',
        'vaultAmount': '212,500',
        'note': 'Your cold wallet delegated to this one on delegate.xyz. Claim from here; the PLEA lands on the vault.',
    },
    'gasNote': 'about 70,000 gas',
}

profile = {
    'name': 'mira_eth', 'address': W['mira_eth'], 'short': short(W['mira_eth']),
    'seat': True, 'seatNft': 'identity.md 0x0000ec93127baa929e58e97dd0095a2bfb38ec1d',
    'pleaBalance': '6,200,000', 'imdBalance': '412.50',
    'cashbackEarnedImd': '0.83',
    'buyRecord': buy['record'],
    'cooldown': 'Plea #214 is open: sell by 08:06 UTC. Next plea 4 hours after the sale (12:00 UTC if sold now), or 11:59 UTC if it lapses.',
    'pleas': [214, 196],
    'pleasNote': 'The latest two; season 2 also counts #188 and #171 (all pleas on the Wall, filtered by wallet).',
    'nextPleaAfterSale': 'After #214 sells, the balance is 4,960,000: a 20% plea is 992,000 PLEA and needs 33 (16 + 4 + 13 + 5).',
    'seasonPoints': [{'season': 1, 'points': 97, 'rank': 14, 'prizeImd': fmt_floor2(POT_S1 * SHARES[13] / 10000), 'bonusPlea': fmt_int(BONUS * SHARES[13] / 10000)},
                     {'season': 2, 'points': 116, 'rank': season2['you']['rank'], 'prizeImd': None}],
    'nameBox': {'value': 'mira_eth', 'state': 'This is your current name.', 'taken': 'kafka_cat is taken.', 'bad': 'Only lower-case a–z, digits 0–9 and _ are allowed.'},
}

addresses = {
    'imd': '0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7',
    'stacker': '0x06909f672301f28a810f78cfe7a754851269f4f0',
    'seatNft': '0x0000ec93127baa929e58e97dd0095a2bfb38ec1d',
    'poolManager': '0x000000000004444c5dc75cB358380D2e3dE08A90',
    'intakeV2': '0xa43e6f75ee006411f79ac1c84120606c2330de82',
    'delegateRegistry': '0x00000000000000447e69651d841bD8D104Bed493',
    'plea': '[after launch]', 'cabalGate': '[after launch]', 'seasons': '[after launch]', 'pleaHook': '[after launch]',
    'letterbox': '[after launch]', 'tribunal': '[after launch]', 'pleaDistributor': '[after launch]', 'pleaLaunch': '[after launch]',
}

data = {
    'roundingNote': 'Prizes and payouts are rounded down on their own, as the chain pays and prints them, so parts and totals can differ by a cent.',
    '_about': 'Sample data for the PLEA site mockups, generated by tools/sample_data.py from the agreed mainnet numbers. Names, wallets and texts are made up; mainnet PLEA addresses do not exist yet.',
    'rules': {
        'fact': {'share': '≤20%: 16 · ≤35%: 9 · more: 3', 'hold': '≥7d: 7 · ≥3d: 4 · ≥1d: 2',
                 'pl': 'at a loss: 13 · gain ≤50%: 12 · ≤200%: 10 · ≤500%: 8 · ≤1,000%: 6 · more: 4',
                 'trend': 'up >2%: 9 · flat ±2%: 5 · down: 0', 'received': 'PLEA no buy record covers: held since trading opened, profit 10'},
        'need': 'need = 71 − fact score; above 45 no plea can pass (CannotPass, refused before paying)',
        'panel': '30 judges, 17 must agree, score 0–45',
        'plea': '1% to 50% of your balance (the 1% minimum is capped at 2,500,000 for balances above 250M), at most 2,500,000 PLEA; 1–280 bytes; 0.50 IMD oracle fee',
        'windows': {'pending': '20 min', 'sell': '7 min', 'objection': '20 min', 'appeal': '4 h after a denial', 'cooldown': '4 h after a sale, denial or lapse', 'deadman': '33 h without a verdict'},
        'fees': '2.25%: 0.50% cashback as staked IMD, 1.00% owner, 0.25% season prize pot, 0.25% buy wall, 0.25% of the PLEA burned',
        'seasons': '15 days; best 3 scores; top 25 with 60+ points share the IMD pot (4.50% → 3.50%) and, in the first six seasons, 10,000,000 PLEA; IMD seat holders earn score × 1.2 (rounded down)',
        'shares': SHARES,
        'supply': '1,000,000,000 PLEA: 82% pool, 6% season bonus, 12% distributor (swarm 10% + airdrop 2%)',
    },
    'market': market,
    'buy': buy,
    'plead': plead_form,
    'autoSell': autosell,
    'pleas': pleas,
    'season1': season1,
    'season2': season2,
    'letters': letters,
    'objections': objections,
    'claim': claim,
    'profile': profile,
    'addresses': addresses,
}

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'sample-data.json')
with open(out, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
print('wrote', os.path.normpath(out))
for p in pleas:
    print(p['id'], p['stamp'], 'fact', p['fact'], 'need', p['need'], 'score', p.get('score'), 'points', p.get('points'), 'bytes', p['bytes'])
print('lb', [(e['rank'], e['name'] or e['address'], e['points'], e['prizeImd']) for e in lb[:6]], '... qualifying', season2['qualifying'])
print('you', season2['you'])
print('if ended now', season2['ifEndedNow'], 'pot sources', season2['potSources'])
print('cabal', market['cabal'], 'mcap', market['marketCapImd'])
print('autosell', autosell['feesPleaAbout'], autosell['quote'])
print('s1', season1['rolloverImd'], season1['paidImd'])
