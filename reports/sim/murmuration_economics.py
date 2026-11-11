#!/usr/bin/env python3
"""
Murmuration economics, as arithmetic. No dependencies. Run:  python3 murmuration_economics.py > results.md

Everything here is a model of the DESIGN, not a forecast. Inputs are the owner's decisions (allocation,
48,000 IMD starting valuation, 0.2% + 0.2% fee, 40/40/20 split, the asset list), the defaults the
specification recommends and builds to (revision 4.3), and prices of 10 Nov 2026 (ETH $2,130, IMD $2.64).
Token supply is set to 1e9 for readable numbers; every result in % of supply or in IMD is supply-independent.

Revision 4.3 changes to this script:
  - the primary schedule is the recommended one: caps stop after five doublings; the unlimited doubling of
    version 4 is shown as a variant;
  - emissions run 730 days from START (the first applied screening batch), at a rate proportional to the cap
    in force; START is taken as 33 days after launch, the earliest it can be;
  - reward weights follow prices on the freeze day (a stablecoin unit weighs 1/2,130 ETH, not 1/2,000);
  - the swarm vests over 730 days in the primary schedule;
  - a section on what a screener stake costs on the one-sided curve.
"""
from math import sqrt

# ---------------------------------------------------------------- inputs
ETH_USD, IMD_USD = 2130.0, 2.64
SUPPLY = 1_000_000_000            # assumption for readability only
START_VALUATION_IMD = 48_000.0    # owner's decision, for the whole supply
ALLOC = dict(users=0.45, pool=0.25, screeners=0.15, swarm=0.10, founder=0.05)
FEE_IN = FEE_OUT = 0.002
SPLIT = dict(stakers=0.40, screeners=0.40, liquidity=0.20)

CAP0_ETH, STABLE_CAP0, IMD_CAP0 = 25.0, 50_000.0, 2500.0      # starting caps: ETH, each stablecoin, IMD
PERIOD_DAYS = [90] * 7 + [100]                                  # 730 days from START
MULT_STOP = [1, 2, 4, 8, 16, 32, 32, 32]                        # recommended: stop after five doublings
MULT_NOSTOP = [1, 2, 4, 8, 16, 32, 64, 128]                     # version 4: doubling with no stated end
LAUNCH_TO_START = 33                                            # days: 30-epoch screener wait plus the first batch
VEST_DAYS = 730
STAKE_SHARE = 0.00005                                           # 0.005% of supply per screener (recommended in 4.3)

# capacity at the first step, in ETH-equivalent at freeze-day prices, and in dollars
W_ETH = CAP0_ETH
W_STABLE = STABLE_CAP0 / ETH_USD
W_IMD = IMD_CAP0 * IMD_USD / ETH_USD
CAPACITY0 = W_ETH + 2 * W_STABLE + W_IMD
USD_STEP0 = CAP0_ETH * ETH_USD + 2 * STABLE_CAP0 + IMD_CAP0 * IMD_USD

P0 = START_VALUATION_IMD / SUPPLY                         # IMD per token at the bottom of the range
X0 = ALLOC["pool"] * SUPPLY                               # tokens placed one-sided
RANGE_TOP_MULTIPLE = 1e12                                 # effectively unbounded


def fmt(x, d=0):
    return f"{x:,.{d}f}"


def table(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(out)


def period_bounds():
    out, a = [], 0
    for d in PERIOD_DAYS:
        out.append((a, a + d)); a += d
    return out


# ---------------------------------------------------------------- 1. one-sided range
class Range:
    """One Uniswap-v3-style position over [P0, Ptop], funded with tokens only. x = tokens, y = IMD."""
    def __init__(self, x0=X0, p0=P0, top=RANGE_TOP_MULTIPLE):
        self.sp0, self.spt = sqrt(p0), sqrt(p0 * top)
        self.L = x0 / (1 / self.sp0 - 1 / self.spt)
        self.x0 = x0
        self.sp = self.sp0
    def tokens(self): return self.L * (1 / self.sp - 1 / self.spt)
    def imd(self):    return self.L * (self.sp - self.sp0)
    def price(self):  return self.sp ** 2
    def set_sold_fraction(self, f):
        x = self.x0 * (1 - f)
        self.sp = 1 / (x / self.L + 1 / self.spt)
    def sell_tokens(self, dx):
        y_before, x_before = self.imd(), self.tokens()
        x_after = min(x_before + dx, self.x0)                 # cannot push below P0: no liquidity there
        self.sp = 1 / (x_after / self.L + 1 / self.spt)
        return y_before - self.imd(), x_after - x_before
    def buy_with_imd(self, dy):
        y_before, x_before = self.imd(), self.tokens()
        self.sp = self.sp0 + (y_before + dy) / self.L
        return x_before - self.tokens()
    def buy_tokens(self, dx):
        """Buy dx tokens out of the pool. Returns IMD paid (no fee)."""
        y_before = self.imd()
        x_after = self.tokens() - dx
        self.sp = 1 / (x_after / self.L + 1 / self.spt)
        return self.imd() - y_before


def part1():
    print("## 1. The one-sided range\n")
    print(f"25% of supply placed one-sided from a valuation of {fmt(START_VALUATION_IMD)} IMD "
          f"(${fmt(START_VALUATION_IMD*IMD_USD)}), with a range that runs from the starting price upward without a practical limit. "
          "No trading fee modelled. \"Sold\" is the share of the pool's tokens that buyers have taken.\n")
    rows = []
    for f in (0.0, 0.10, 0.25, 0.50, 0.75, 0.90):
        r = Range(); r.set_sold_fraction(f)
        val_imd = r.price() * SUPPLY
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
def emission_between(day_a, day_b, mult):
    """Share of the users' allocation emitted between two days counted from START, at full use."""
    total = sum(m * d for m, d in zip(mult, PERIOD_DAYS)); got = 0.0
    for (qa, qb), m in zip(period_bounds(), mult):
        got += m * max(0, min(day_b, qb) - max(day_a, qa))
    return got / total


def unlock_schedule(swarm_days=VEST_DAYS, mult=MULT_STOP, months=26):
    """Fraction of total supply unlocking in each 30-day month counted from LAUNCH."""
    out = []
    for m in range(months):
        a, b = m * 30, (m + 1) * 30
        sa, sb = a - LAUNCH_TO_START, b - LAUNCH_TO_START            # the same month counted from START
        users = ALLOC["users"] * emission_between(max(sa, 0), max(sb, 0), mult)
        screeners = ALLOC["screeners"] * max(0, min(sb, 730) - max(sa, 0)) / 730
        swarm = ALLOC["swarm"] * max(0, min(b, swarm_days) - a) / swarm_days
        vest = lambda t: 0.0 if t < 30 else min(t, VEST_DAYS) / VEST_DAYS   # one-month cliff, then the share of 730 days passed
        founder = ALLOC["founder"] * (vest(b) - vest(a))
        out.append(dict(users=users, screeners=screeners, swarm=swarm, founder=founder))
    return out


def empty_month(sched, f0, phi, buyback_imd=0.0):
    r = Range(); r.set_sold_fraction(f0); gone = None
    for m, s in enumerate(sched, 1):
        if buyback_imd: r.buy_with_imd(buyback_imd)
        r.sell_tokens(sum(s.values()) * SUPPLY * phi)
        if gone is None and r.imd() < 1e-6: gone = m
    return gone, r


def part2():
    print("## 2. Sell pressure from the unlocks\n")
    sched = unlock_schedule()
    rows = []
    for m in (1, 3, 6, 9, 12, 18, 24, 26):
        tot = {k: sum(s[k] for s in sched[:m]) for k in ("users", "screeners", "swarm", "founder")}
        cum = sum(tot.values())
        rows.append([m] + [f"{tot[k]*100:.2f}%" for k in ("users", "screeners", "swarm", "founder")] +
                    [f"{cum*100:.2f}%", f"{cum/ALLOC['pool']:.2f}x"])
    print("Cumulative unlocks as a share of supply, by 30-day month from launch. Recommended schedule: user rewards and screener "
          f"shares start {LAUNCH_TO_START} days after launch, when the first batch can be applied, and run 730 days from there; "
          "user rewards follow the caps (which stop after five doublings) at full use; the swarm and the founder vest over 730 days from launch, "
          "the founder after a one-month cliff.\n")
    print(table(["After month", "Users", "Screeners", "Swarm", "Founder", "Total unlocked", "Versus the pool's 25%"], rows))
    total = sum(sum(s.values()) for s in sched)
    print(f"\nTotal unlocking: {total*100:.0f}% of supply, three times what the public pool ever holds. The last of it arrives on day "
          f"{LAUNCH_TO_START + 730} after launch.\n")

    print("### Months until the pool has no IMD left\n")
    print("Start: buyers have taken the stated share of the pool's tokens and nobody buys afterwards. Each month a fixed "
          "share of that month's unlocks is sold into the pool. \"Never\" means the IMD outlasts 26 months.\n")
    rows = []
    for f0 in (0.10, 0.25, 0.50, 0.75):
        r0 = Range(); r0.set_sold_fraction(f0)
        row = [f"{f0*100:.0f}% (pool holds {fmt(r0.imd())} IMD)"]
        for phi in (0.10, 0.25, 0.50, 1.00):
            gone, r = empty_month(sched, f0, phi)
            row.append(f"month {gone}" if gone else f"never (price {r.price()/P0:.2f}x at month 26)")
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

    print("\n### Variant: the swarm's 10% vesting over 12 months, as version 4 had it\n")
    sched2 = unlock_schedule(swarm_days=365); rows = []
    for phi in (0.25, 0.50, 1.00):
        gone, r = empty_month(sched2, 0.50, phi)
        gone_rec, _ = empty_month(sched, 0.50, phi)
        rows.append([f"{phi*100:.0f}%", f"month {gone}" if gone else "never", f"month {gone_rec}" if gone_rec else "never"])
    print(table(["Share of unlocks sold", "Pool empty, 12-month swarm vest", "Pool empty, 730-day swarm vest"], rows))
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

    for label, mult in (("Recommended schedule: caps stop after five doublings", MULT_STOP),
                        ("Variant: doubling with no stop, as version 4 had it", MULT_NOSTOP)):
        print(f"\n### What the caps allow. {label}\n")
        print("Railgun turns its balance over about 1.18 times a month ($125M of shield plus unshield volume on $106M). "
              f"The table applies that rate to a pool that is full at every cap: 25 ETH, 50,000 USDT, 50,000 USDC and {IMD_CAP0:,.0f} IMD at the start. "
              "Days count from START.\n")
        rows = []; cum = 0.0
        for (a, b), m in zip(period_bounds(), mult):
            tvl = USD_STEP0 * m
            vol = tvl * 1.18; fee = vol * FEE_IN; imd = fee * SPLIT["liquidity"] / IMD_USD
            cum += imd * (b - a) / 30
            rows.append([f"{a}-{b}", fmt(CAP0_ETH * m), "$" + fmt(tvl), "$" + fmt(vol), "$" + fmt(fee), fmt(imd)])
        print(table(["Days", "Cap on ETH", "Most the pool can hold", "Volume a month at 1.18x", "Fee a month", "IMD to the buyback a month"], rows))
        def first_day(target):
            for (a, b), m in zip(period_bounds(), mult):
                if USD_STEP0 * m * 1.18 >= target: return f"from day {a}"
            return "never inside the 730 days"
        print(f"\nFull at every cap for 730 days and turning over like Railgun, the pool sends about {fmt(cum)} IMD "
              f"(${fmt(cum*IMD_USD)}) to the buyback in total. Volume of $1M a month: {first_day(1e6)}. "
              f"$10M a month: {first_day(1e7)}. $100M a month: {first_day(1e8)}.")
    print()


# ---------------------------------------------------------------- 4. user reward per unit shielded
def reward_rate(mult):
    """Tokens per ETH-equivalent per day on a full pool. Constant over the schedule, since emission follows the caps."""
    budget = ALLOC["users"] * SUPPLY
    return budget / (sum(m * d for m, d in zip(mult, PERIOD_DAYS)) * CAPACITY0)


def part4():
    print("## 4. User reward per unit of shielded value\n")
    budget = ALLOC["users"] * SUPPLY
    print(f"Capacity at the first step is {CAPACITY0:.2f} ETH-equivalent at freeze-day prices: {W_ETH:.0f} of ETH, {W_STABLE:.2f} for each "
          f"stablecoin cap and {W_IMD:.2f} of IMD. Emission per second is proportional to the cap in force, for 730 days from START, so a full pool "
          "pays the same number of tokens per ETH-equivalent per day throughout. Dollar figures use the starting valuation.\n")
    for label, mult in (("Recommended schedule: caps stop after five doublings", MULT_STOP),
                        ("Variant: doubling with no stop", MULT_NOSTOP)):
        per = reward_rate(mult); yld = per * P0 * IMD_USD / ETH_USD * 365 * 100
        print(f"### {label}\n")
        rows = []
        total = sum(m * d for m, d in zip(mult, PERIOD_DAYS))
        for (a, b), m in zip(period_bounds(), mult):
            rows.append([f"{a}-{b}", fmt(CAP0_ETH * m), "$" + fmt(USD_STEP0 * m), f"{m*(b-a)/total*100:.2f}%", fmt(budget * m * (b - a) / total)])
        print(table(["Days from START", "Cap on ETH", "Most the pool can hold", "Share of user tokens", "Tokens emitted"], rows))
        print(f"\nFull pool: {per:.1f} tokens per ETH-equivalent per day. A year's reward at the starting price is {yld:.2f}% of the value shielded, "
              f"{yld*4:.2f}% at 4x and {yld*16:.2f}% at 16x. On a pool a quarter full or less the rate is four times that: "
              f"{yld*4:.2f}%, {yld*16:.2f}% and {yld*64:.1f}%.")
        first90 = emission_between(0, 90, mult); first_year = emission_between(0, 365, mult); last = emission_between(630, 730, mult)
        print(f"{first90*100:.2f}% of the users' tokens are paid in the first 90 days, {first_year*100:.1f}% in the first year and "
              f"{last*100:.1f}% in the last 100 days.\n")

    print("### An under-filled pool: the naive rule against a floor\n")
    total = sum(m * d for m, d in zip(MULT_STOP, PERIOD_DAYS)); emis0 = budget * 90 / total
    rows = []
    for shielded in (0.001, 0.1, 1, CAPACITY0 * 0.10, CAPACITY0 * 0.25, CAPACITY0 * 0.50, CAPACITY0):
        naive = emis0 / (shielded * 90)
        floor = emis0 / (max(shielded, CAPACITY0 * 0.25) * 90)
        released = min(1.0, shielded / (CAPACITY0 * 0.25))
        rows.append([fmt(shielded, 3), f"{shielded/CAPACITY0*100:.3f}%", fmt(naive, 1),
                     f"{naive*P0*IMD_USD/ETH_USD*365*100:,.1f}%", fmt(floor, 1), f"{floor*P0*IMD_USD/ETH_USD*365*100:.2f}%",
                     f"{released*100:.1f}%"])
    print(f"First 90 days, {fmt(emis0)} tokens to emit, pool capacity {fmt(CAPACITY0, 2)} ETH-equivalent across assets.\n")
    print(table(["ETH-equivalent shielded", "Use of capacity", "Version 4 rule: tokens per ETH per day", "Yield a year at start price",
                 "With a 25% floor", "Yield a year", "Share of emission released"], rows))
    print("\nUnder the version 4 rule a single depositor of 0.001 ETH would collect the whole period's emission. With a floor on the "
          "divisor, the rate never exceeds four times the full-pool rate and the unreleased part stays locked for good.\n")

    print("### Exposure\n")
    print(f"Most the pool can hold: ${fmt(USD_STEP0)} at the first step, ${fmt(USD_STEP0*32)} at the recommended stop (from day 450). "
          f"With no stop the cap would be 3,200 ETH in the last period, ${fmt(USD_STEP0*128)} across the assets, and ${fmt(USD_STEP0*256)} from day 720, "
          "still doubling.\n")


def part5():
    print("## 5. IMD as a listed asset with full reward weight\n")
    floor = CAPACITY0 / 4
    print(f"IMD is listed with the same reward per dollar as ETH at freeze-day prices and a cap of its own: {IMD_CAP0:,.0f} IMD at the start "
          f"(${IMD_CAP0*IMD_USD:,.0f}, {W_IMD:.2f} ETH-equivalent), doubling with the other caps to {IMD_CAP0*32:,.0f} IMD (${IMD_CAP0*32*IMD_USD:,.0f}).\n")
    rows = []
    for label, others in (("full", 1.0), ("half full", 0.5), ("a quarter full", 0.25), ("a tenth full", 0.10), ("empty", 0.0)):
        w = (W_ETH + 2 * W_STABLE) * others + W_IMD
        share = W_IMD / max(w, floor)
        released = min(1.0, w / floor)
        rows.append([label, f"{share*100:.1f}%", f"{released*100:.0f}%"])
    print(table(["ETH, USDT and USDC are", "Share of the period's emission earned by a full IMD cap", "Share of the emission released"], rows))
    print(f"\nIMD is {W_IMD/CAPACITY0*100:.1f}% of capacity. The same ratios hold at every cap step. At the stop, the IMD cap is "
          f"{IMD_CAP0*32/7_080_000*100:.1f}% of IMD's total supply of about 7.08 million.\n")


def part6():
    print("## 6. Screener stake and pay\n")
    stake_tokens = STAKE_SHARE * SUPPLY
    print(f"A stake is {STAKE_SHARE*100:.3f}% of supply. Stakes can only be bought from the public pool until other tokens circulate, so each one moves the price. "
          "The table assumes stakes are the only purchases.\n")
    rows = []
    for share, label in ((0.00005, "0.005% (recommended)"), (0.0005, "0.05% (revision 4.2)")):
        st = share * SUPPLY; r = Range(); cost = {}; n = 0; total = 0.0
        for target in (1, 15, 100, 250, 400, 500, 1000, 2000):
            ok = True
            while n < target:
                if r.tokens() <= st * 1.0000001:
                    ok = False; break
                paid = r.buy_tokens(st); total += paid; n += 1; last = paid
            cost[target] = (f"{last:,.1f} IMD (${last*IMD_USD:,.0f})" if ok else "cannot be bought")
            if not ok: break
        rows.append([label] + [cost.get(t, "cannot be bought") for t in (1, 15, 100, 250, 400, 500, 1000, 2000)])
    print(table(["Stake", "1st", "15th", "100th", "250th", "400th", "500th", "1,000th", "2,000th"], rows))
    r = Range(); total = r.buy_tokens(77 * stake_tokens)
    print(f"\nRegistering 77 seats at launch costs {total:,.0f} IMD (${total*IMD_USD:,.0f}) in stake at the recommended size. "
          f"All 2,000 seats would take {2000*STAKE_SHARE*100:.0f}% of supply.\n")
    val = START_VALUATION_IMD * IMD_USD
    tok_day = ALLOC["screeners"] * val / 730
    fee_day = USD_STEP0 * 1.18 * FEE_IN * SPLIT["screeners"] / 30
    print(f"Pay at the starting valuation: the screeners' 15% is ${tok_day:,.0f} a day in total over 730 accepted epochs, and 40% of the "
          f"first step's fees on a full pool at Railgun's turnover is ${fee_day:,.2f} a day in total. With 15 screeners that is about "
          f"${(tok_day+fee_day)/15:,.2f} a day each, before gas for a commit and a reveal.\n")
    print("### Recycling of fees by insiders\n")
    rows = []
    for s, rr in ((0.0, 0.0), (0.25, 0.25), (0.5, 0.5), (1.0, 1.0)):
        back = 0.4 * (s + rr)
        rows.append([f"{s*100:.0f}%", f"{rr*100:.0f}%", f"{back*100:.0f}%", f"{0.4*(1-back):.3f}%"])
    print(table(["Share of stake held", "Share of revealing screeners", "Share of its own fees it gets back", "Net cost of a round trip (0.4% gross)"], rows))
    print()


def main():
    print("# Murmuration economics: simulation results (revision 4.3)\n")
    print(f"Generated by `reports/sim/murmuration_economics.py`. Prices of 10 November 2026: ETH ${ETH_USD:,.0f}, IMD ${IMD_USD}. "
          f"Supply assumed {SUPPLY:,} tokens for readable numbers. This is arithmetic on the design, not a forecast.\n")
    part1(); part2(); part3(); part4(); part5(); part6()


if __name__ == "__main__":
    main()
