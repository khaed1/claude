#!/usr/bin/env python3
"""
Murmuration v4 economics, as arithmetic. No dependencies. Run:  python3 murmuration_economics.py > results.md

Everything here is a model of the DESIGN, not a forecast. Inputs are the owner's decisions (allocation,
48,000 IMD starting valuation, 0.2% + 0.2% fee, 40/40/20 split), the previous session's unconfirmed
defaults (25 ETH cap doubling every 90 days), and prices of 10 Nov 2026 (ETH $2,130, IMD $2.64).
Token supply is set to 1e9 for readable numbers; every result in % of supply or in IMD is supply-independent.
"""
from math import sqrt   # noqa: E402

# ---------------------------------------------------------------- inputs
ETH_USD, IMD_USD = 2130.0, 2.64
SUPPLY = 1_000_000_000            # assumption for readability only
START_VALUATION_IMD = 48_000.0    # owner's decision, for the whole supply
ALLOC = dict(users=0.45, pool=0.25, screeners=0.15, swarm=0.10, founder=0.05)
FEE_IN = FEE_OUT = 0.002
SPLIT = dict(stakers=0.40, screeners=0.40, liquidity=0.20)
CAP0_ETH, CAP_PERIOD_DAYS, CAP_PERIODS = 25.0, 90, 8      # v4 default: 25 ETH, doubling every 90 days, two years
IMD_CAP0 = 2500.0                 # IMD's own cap at the start, doubling with the others to 80,000 (owner's decision, 11 Nov 2026)
STABLE_CAP0 = 50_000.0            # USDT and USDC caps at the start, in dollars; each weighs 1/2,000 ETH per unit, so 25 ETH-equivalent
# Asset list decided by the owner on 11 Nov 2026: ETH, USDT, USDC, IMD and the pool's own token (weight 0).
# WEIGHTED_ASSETS is capacity in units of the ETH cap, for the reward arithmetic. USD_STEP0 is the dollar value the pool can hold at the first step.
WEIGHTED_ASSETS = 3 + IMD_CAP0 * IMD_USD / ETH_USD / CAP0_ETH
USD_STEP0 = CAP0_ETH * ETH_USD + 2 * STABLE_CAP0 + IMD_CAP0 * IMD_USD
BLOCKS_PER_DAY = 7200
P0 = START_VALUATION_IMD / SUPPLY                         # IMD per token at the bottom of the range
X0 = ALLOC["pool"] * SUPPLY                               # tokens placed one-sided
RANGE_TOP_MULTIPLE = 1e12                                 # "far above": effectively unbounded, as a full-range-above-start position is

def fmt(x, d=0):
    return f"{x:,.{d}f}"

def table(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(out)

# ---------------------------------------------------------------- 1. one-sided range
class Range:
    """One Uniswap-v3-style position over [P0, Ptop], funded with tokens only. x = tokens, y = IMD."""
    def __init__(self, x0=X0, p0=P0, top=RANGE_TOP_MULTIPLE):
        self.sp0, self.spt = sqrt(p0), sqrt(p0 * top)
        self.L = x0 / (1 / self.sp0 - 1 / self.spt)
        self.x0 = x0
        self.sp = self.sp0                     # current sqrt price
    # state
    def tokens(self): return self.L * (1 / self.sp - 1 / self.spt)
    def imd(self):    return self.L * (self.sp - self.sp0)
    def price(self):  return self.sp ** 2
    # moves
    def set_sold_fraction(self, f):
        x = self.x0 * (1 - f)
        self.sp = 1 / (x / self.L + 1 / self.spt)
    def sell_tokens(self, dx):
        """Sell dx tokens into the pool. Returns (IMD received, tokens actually sold). No fee modelled."""
        y_before, x_before = self.imd(), self.tokens()
        x_after = min(x_before + dx, self.x0)                 # cannot push below P0: no liquidity there
        self.sp = 1 / (x_after / self.L + 1 / self.spt)
        return y_before - self.imd(), x_after - x_before
    def buy_with_imd(self, dy):
        y_before, x_before = self.imd(), self.tokens()
        self.sp = self.sp0 + (y_before + dy) / self.L
        return x_before - self.tokens()

def part1():
    print("## 1. The one-sided range\n")
    print(f"25% of supply placed one-sided from a valuation of {fmt(START_VALUATION_IMD)} IMD "
          f"(${fmt(START_VALUATION_IMD*IMD_USD)}), with a range that runs from the starting price upward without a practical limit. "
          "No trading fee modelled. \"Sold\" is the share of the pool's tokens that buyers have taken.\n")
    rows = []
    for f in (0.0, 0.10, 0.25, 0.50, 0.75, 0.90):
        r = Range(); r.set_sold_fraction(f)
        val_imd = r.price() * SUPPLY
        # price impact of selling $1,000 and $3,000 worth of IMD out of the pool
        impacts = []
        for usd in (1000, 3000):
            rr = Range(); rr.set_sold_fraction(f)
            target = usd / IMD_USD
            if rr.imd() <= target: impacts.append("pool emptied")
            else:
                p_before = rr.price(); rr.sp = rr.sp0 + (rr.imd() - target) / rr.L
                impacts.append(f"-{(1 - rr.price()/p_before)*100:.1f}%")
        rows.append([f"{f*100:.0f}%", f"{r.price()/P0:.2f}x", fmt(val_imd), "$" + fmt(val_imd*IMD_USD),
                     fmt(r.imd()), "$" + fmt(r.imd()*IMD_USD), f"{r.imd()/val_imd*100:.1f}%", impacts[0], impacts[1]])
    print(table(["Pool tokens sold", "Price vs start", "Valuation, IMD", "Valuation, $", "IMD in pool",
                 "IMD in pool, $", "Pool IMD / valuation", "Price move, $1k sale", "Price move, $3k sale"], rows))
    print("\nReading: the IMD in the pool is the only exit liquidity the token has. Closed form for an unbounded range: "
          "IMD = 12,000 x f/(1-f), price = start/(1-f)^2. Below the starting price there are no bids at all.\n")

# ---------------------------------------------------------------- 2. unlock sell pressure
def unlock_schedule(swarm_months=12, util=1.0, months=24, cap_periods=CAP_PERIODS, cap_period_days=CAP_PERIOD_DAYS):
    """Fraction of total supply unlocking in each month (30-day months, 24 of them)."""
    out = []
    weights = [2 ** q for q in range(cap_periods)]; wsum = sum(weights)
    for m in range(months):
        day_a, day_b = m * 30, (m + 1) * 30
        users = 0.0
        for q, w in enumerate(weights):
            qa, qb = q * cap_period_days, (q + 1) * cap_period_days
            overlap = max(0, min(day_b, qb) - max(day_a, qa))
            users += ALLOC["users"] * util * (w / wsum) * overlap / cap_period_days
        screeners = ALLOC["screeners"] / months
        swarm = ALLOC["swarm"] / swarm_months if m < swarm_months else 0.0
        founder = 0.0 if m == 0 else (ALLOC["founder"] / months) * (2 if m == 1 else 1)   # one-month cliff, then catch-up
        out.append(dict(users=users, screeners=screeners, swarm=swarm, founder=founder))
    return out

def part2():
    print("## 2. Sell pressure from two years of unlocks\n")
    sched = unlock_schedule()
    cum = 0.0; rows = []
    for m in (1, 3, 6, 9, 12, 18, 24):
        tot = {k: sum(s[k] for s in sched[:m]) for k in ("users", "screeners", "swarm", "founder")}
        cum = sum(tot.values())
        rows.append([m] + [f"{tot[k]*100:.2f}%" for k in ("users", "screeners", "swarm", "founder")] +
                    [f"{cum*100:.2f}%", f"{cum/ALLOC['pool']:.2f}x"])
    print("Cumulative unlocks as a share of supply (v4 defaults: user rewards in step with caps at full use, "
          "screeners linear, swarm linear over 12 months, founder linear after a one-month cliff).\n")
    print(table(["After month", "Users", "Screeners", "Swarm", "Founder", "Total unlocked", "Versus the pool's 25%"], rows))
    total = sum(sum(s.values()) for s in sched)
    print(f"\nTotal unlocking over two years: {total*100:.0f}% of supply, three times what the public pool ever holds. "
          "(The v4 risk table says 70%; the allocation adds to 75%.)\n")

    print("### Months until the pool has no IMD left\n")
    print("Start: buyers have taken the stated share of the pool's tokens and nobody buys afterwards. Each month a fixed "
          "share of that month's unlocks is sold into the pool. \"Never\" means the IMD outlasts 24 months.\n")
    rows = []
    for f0 in (0.10, 0.25, 0.50, 0.75):
        r0 = Range(); r0.set_sold_fraction(f0)
        row = [f"{f0*100:.0f}% (pool holds {fmt(r0.imd())} IMD)"]
        for phi in (0.10, 0.25, 0.50, 1.00):
            r = Range(); r.set_sold_fraction(f0); gone = None; p12 = None
            for m, s in enumerate(sched, 1):
                r.sell_tokens(sum(s.values()) * SUPPLY * phi)
                if gone is None and r.imd() < 1e-6: gone = m
                if m == 12: p12 = r.price() / P0
            row.append(f"month {gone}" if gone else f"never (price {r.price()/P0:.2f}x at month 24)")
        rows.append(row)
    print(table(["Pool tokens bought at start", "10% of unlocks sold", "25% sold", "50% sold", "100% sold"], rows))

    print("\n### Price path, half the pool bought at the start (price 4.00x), no later buying\n")
    rows = []
    for phi in (0.10, 0.25, 0.50, 1.00):
        r = Range(); r.set_sold_fraction(0.50); row = [f"{phi*100:.0f}%"]; got = 0.0
        for m, s in enumerate(sched, 1):
            y, _ = r.sell_tokens(sum(s.values()) * SUPPLY * phi); got += y
            if m in (1, 3, 6, 12, 24): row.append(f"{r.price()/P0:.2f}x")
        row.append(fmt(got)); row.append("$" + fmt(got * IMD_USD))
        rows.append(row)
    print(table(["Share of unlocks sold", "Month 1", "Month 3", "Month 6", "Month 12", "Month 24",
                 "IMD sellers received", "In dollars"], rows))
    print("\nThe most that all sellers together can ever take out is the IMD that buyers put in, plus what the fee buyback adds.\n")

    print("### Unlock selling against the fee buyback\n")
    print("Half the pool bought at the start, half of each month's unlocks sold, and the 20% fee share buying tokens back "
          "every month at a constant pool volume. Bought tokens are burned.\n")
    rows = []
    for vol in (0, 1e6, 1e7, 1e8):
        r = Range(); r.set_sold_fraction(0.50); row = ["none" if vol == 0 else "$" + fmt(vol)]; gone = None
        add = vol * FEE_IN * SPLIT["liquidity"] / IMD_USD
        for m, s_ in enumerate(sched, 1):
            r.buy_with_imd(add)
            r.sell_tokens(sum(s_.values()) * SUPPLY * 0.50)
            if gone is None and r.imd() < 1e-6: gone = m
            if m in (6, 12, 24): row += [f"{r.price()/P0:.2f}x", fmt(r.imd())]
        row.append(f"month {gone}" if gone else "never")
        rows.append(row)
    print(table(["Pool volume a month", "Price, month 6", "IMD in pool", "Price, month 12", "IMD in pool",
                 "Price, month 24", "IMD in pool", "Pool first empty"], rows))
    print("\nAt $1M a month the buyback is 152 IMD against thousands of IMD of selling. It changes the outcome only from about $10M a month, "
          "which the caps do not allow before the last half-year of the schedule (section 3).\n")

    print("### Same, with the swarm's 10% vesting over 24 months instead of 12 (recommended)\n")
    sched2 = unlock_schedule(swarm_months=24); rows = []
    for phi in (0.25, 0.50, 1.00):
        r = Range(); r.set_sold_fraction(0.50); row = [f"{phi*100:.0f}%"]; gone = None
        for m, s in enumerate(sched2, 1):
            r.sell_tokens(sum(s.values()) * SUPPLY * phi)
            if gone is None and r.imd() < 1e-6: gone = m
            if m in (3, 6, 12, 24): row.append(f"{r.price()/P0:.2f}x")
        row.append(f"month {gone}" if gone else "never")
        rows.append(row)
    print(table(["Share of unlocks sold", "Month 3", "Month 6", "Month 12", "Month 24", "Pool empty"], rows))
    print()

# ---------------------------------------------------------------- 3. fees and liquidity added
def part3():
    print("## 3. Fee income and liquidity added\n")
    print("Volume is the dollar value crossing the pool's edge in a month, deposits plus withdrawals. "
          "The fee is 0.2% of it. (If you prefer to count the same money in and out as one, double the fee.)\n")
    rows = []
    for vol in (1e6, 1e7, 1e8):
        fee = vol * FEE_IN
        liq_usd = fee * SPLIT["liquidity"]; liq_imd = liq_usd / IMD_USD
        rows.append(["$" + fmt(vol), "$" + fmt(fee), "$" + fmt(fee*SPLIT["stakers"]), "$" + fmt(fee*SPLIT["screeners"]),
                     "$" + fmt(fee*SPLIT["screeners"]/15), "$" + fmt(liq_usd), fmt(liq_imd),
                     f"{12000/liq_imd:.1f}", "$" + fmt(fee*12)])
    print(table(["Monthly volume", "Fee per month", "Stakers 40%", "Screeners 40%", "Per screener, 15 screeners",
                 "To liquidity 20%", "IMD bought per month", "Months to add 12,000 IMD", "Fee per year"], rows))

    print("\n### What the caps allow\n")
    print("Railgun turns its balance over about 1.18 times a month ($125M of shield plus unshield volume on $106M). "
          f"The table applies that rate, and a rate five times higher, to a pool that is full at every cap: 25 ETH, 50,000 USDT, 50,000 USDC and {IMD_CAP0:,.0f} IMD at the start, all doubling in step.\n")
    rows = []
    for q in range(CAP_PERIODS):
        cap_eth = CAP0_ETH * 2 ** q
        tvl = USD_STEP0 * 2 ** q
        for_turn = []
        for turn in (1.18, 5.9):
            vol = tvl * turn; fee = vol * FEE_IN
            for_turn += ["$" + fmt(vol), "$" + fmt(fee), fmt(fee * SPLIT["liquidity"] / IMD_USD)]
        rows.append([f"{q*CAP_PERIOD_DAYS}-{(q+1)*CAP_PERIOD_DAYS}", fmt(cap_eth), "$" + fmt(tvl)] + for_turn)
    print(table(["Days", "Cap per asset, ETH", "Most the pool can hold", "Volume at 1.18x", "Fee per month", "IMD to liquidity",
                 "Volume at 5.9x", "Fee per month", "IMD to liquidity"], rows))
    # cumulative liquidity added over two years if full and at Railgun turnover
    cum = sum(USD_STEP0 * 2**q * 1.18 * FEE_IN * SPLIT["liquidity"] / IMD_USD * (CAP_PERIOD_DAYS/30)
              for q in range(CAP_PERIODS))
    def first_day(target, turn=1.18):
        for q in range(CAP_PERIODS):
            if USD_STEP0 * 2**q * turn >= target: return f"day {q*CAP_PERIOD_DAYS}"
        return "never inside the two-year schedule"
    print(f"\nA pool that is full at every cap for two years and turns over like Railgun adds about {fmt(cum)} IMD "
          f"(${fmt(cum*IMD_USD)}) to the market in total. At that turnover a full pool first reaches $1M a month at {first_day(1e6)}, "
          f"$10M a month at {first_day(1e7)}, and $100M a month: {first_day(1e8)}.\n")

# ---------------------------------------------------------------- 4. user reward per unit shielded
def part4():
    print("## 4. User reward per unit of shielded value\n")
    weights = [2 ** q for q in range(CAP_PERIODS)]; wsum = sum(weights)
    budget = ALLOC["users"] * SUPPLY
    print("v4 default: emissions follow the caps, so a full pool pays the same number of tokens per ETH per day in every period. "
          "Dollar figures use the starting valuation; multiply by the price multiple from table 1 for other prices.\n")
    rows = []
    for q, w in enumerate(weights):
        cap_eth_total = CAP0_ETH * 2 ** q * WEIGHTED_ASSETS
        emis = budget * w / wsum
        per_eth_day = emis / (cap_eth_total * CAP_PERIOD_DAYS)
        usd_day = per_eth_day * P0 * IMD_USD
        rows.append([f"{q*CAP_PERIOD_DAYS}-{(q+1)*CAP_PERIOD_DAYS}", fmt(CAP0_ETH*2**q), f"{w/wsum*100:.2f}%", fmt(emis),
                     fmt(per_eth_day, 1), f"{usd_day/ETH_USD*365*100:.2f}%", f"{usd_day/ETH_USD*365*100*4:.2f}%", f"{usd_day/ETH_USD*365*100*16:.2f}%"])
    print(table(["Days", "Cap per asset, ETH", "Share of user tokens", "Tokens emitted", "Tokens per ETH per day, full pool",
                 "Yield a year at start price", "At 4x", "At 16x"], rows))
    print(f"\nHalf of all user rewards ({weights[-1]/wsum*100:.1f}%) are paid in the last 90 days and "
          f"{sum(weights[:4])/wsum*100:.1f}% in the first year.\n")

    print("### An under-filled pool: the naive rule against a floor\n")
    cap_total = CAP0_ETH * WEIGHTED_ASSETS; emis0 = budget * 1 / wsum
    rows = []
    for shielded in (0.001, 0.1, 1, cap_total * 0.10, cap_total * 0.25, cap_total * 0.50, cap_total):
        naive = emis0 / (shielded * CAP_PERIOD_DAYS)
        floor = emis0 / (max(shielded, cap_total * 0.25) * CAP_PERIOD_DAYS)
        released = min(1.0, shielded / (cap_total * 0.25))
        rows.append([fmt(shielded, 3), f"{shielded/cap_total*100:.3f}%", fmt(naive, 1),
                     f"{naive*P0*IMD_USD/ETH_USD*365*100:,.1f}%", fmt(floor, 1), f"{floor*P0*IMD_USD/ETH_USD*365*100:.2f}%",
                     f"{released*100:.1f}%"])
    print(f"First 90 days, {fmt(emis0)} tokens to emit, pool capacity {fmt(cap_total, 1)} ETH-equivalent across assets.\n")
    print(table(["ETH shielded in total", "Use of capacity", "v4 rule: tokens per ETH per day", "Yield a year at start price",
                 "With a 25% floor", "Yield a year", "Share of emission released"], rows))
    print("\nUnder the v4 rule a single depositor of 0.001 ETH would collect the whole period's emission. With a floor on the "
          "divisor, the rate per ETH never exceeds four times the full-pool rate and the unreleased part stays locked for good.\n")

    print("### Recommended variant: the same start and pace, stopping at 800 ETH per asset\n")
    print("Caps of 25, 50, 100, 200, 400 and then 800 ETH from day 450 onward. Emissions follow the caps, so the last three periods pay equally.\n")
    caps2 = [25, 50, 100, 200, 400, 800, 800, 800]; w2 = [c / 25 for c in caps2]; rows = []
    for q, w in enumerate(w2):
        cap_total2 = caps2[q] * WEIGHTED_ASSETS
        emis = budget * w / sum(w2); per = emis / (cap_total2 * CAP_PERIOD_DAYS)
        rows.append([f"{q*CAP_PERIOD_DAYS}-{(q+1)*CAP_PERIOD_DAYS}", fmt(caps2[q]), "$" + fmt(USD_STEP0 * caps2[q] / CAP0_ETH), f"{w/sum(w2)*100:.1f}%",
                     fmt(per, 1), f"{per*P0*IMD_USD/ETH_USD*365*100:.2f}%", f"{per*P0*IMD_USD/ETH_USD*365*100*4:.2f}%"])
    print(table(["Days", "Cap per asset, ETH", "Most at risk, all assets", "Share of user tokens", "Tokens per ETH per day, full pool",
                 "Yield a year at start price", "At 4x"], rows))
    v4_tail = USD_STEP0 * 2 ** CAP_PERIODS
    print(f"\nUnder the v4 default the cap is 3,200 ETH per asset in the last quarter of year two and 6,400 ETH from day 720, "
          f"which is ${fmt(v4_tail)} across the assets, and v4 does not say where the doubling stops. "
          f"With a stop at 800 ETH the most that can be at risk is ${fmt(USD_STEP0 * 32)}.\n")

def part5():
    print("## 5. IMD as a listed asset with full reward weight\n")
    imd_eq = IMD_CAP0 * IMD_USD / ETH_USD
    cap_total = CAP0_ETH * 3 + imd_eq
    floor = cap_total / 4
    print(f"IMD is listed with the same reward per dollar as ETH at today's prices and a cap of its own: {IMD_CAP0:,.0f} IMD at the start "
          f"(${IMD_CAP0*IMD_USD:,.0f}, {imd_eq:.2f} ETH-equivalent), doubling with the other caps to {IMD_CAP0*32:,.0f} IMD (${IMD_CAP0*32*IMD_USD:,.0f}).\n")
    rows = []
    for label, others in (("full", 1.0), ("half full", 0.5), ("a quarter full", 0.25), ("a tenth full", 0.10), ("empty", 0.0)):
        w = CAP0_ETH * 3 * others + imd_eq
        share = imd_eq / max(w, floor)
        released = min(1.0, w / floor)
        rows.append([label, f"{share*100:.1f}%", f"{released*100:.0f}%"])
    print(table(["ETH, USDT and USDC are", "Share of the period's emission earned by a full IMD cap", "Share of the emission released"], rows))
    print(f"\nIMD is {imd_eq/cap_total*100:.1f}% of capacity. The same ratios hold at every cap step. At the stop, the IMD cap is "
          f"{IMD_CAP0*32/7_080_000*100:.1f}% of IMD's total supply of about 7.08 million.\n")

def main():
    print("# Murmuration v4 economics: simulation results\n")
    print(f"Generated by `reports/sim/murmuration_economics.py`. Prices of 10 November 2026: ETH ${ETH_USD:,.0f}, IMD ${IMD_USD}. "
          f"Supply assumed {SUPPLY:,} tokens for readable numbers. This is arithmetic on the design, not a forecast.\n")
    part1(); part2(); part3(); part4(); part5()

if __name__ == "__main__":
    main()
