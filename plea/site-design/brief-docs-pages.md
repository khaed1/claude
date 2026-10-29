# PLEA docs pages: brief for the site session

The user's ask (2026-10-28): a **Docs** section on the PLEA site that explains every mechanic in
detail, as simply as possible, with diagrams. GitBook-style to use, PLEA's own look to read. For the
site session to build; this note says what goes in it. Not built yet.

## Shape

- **Where:** a Docs section on the site (`#/docs/<page>`), linked from the top bar and the footer. The
  page texts live as Markdown files in the site repository (`docs/*.md`), so GitHub shows the same
  docs and a fix is one file edit. The site renders them in its own theme.
- **Layout (GitBook-like):** left sidebar with the page list (collapses to a menu on phones), the page
  in the middle, an "On this page" list on wide screens, Previous / Next at the bottom, a search box
  over all pages (a small client-side index, no service), a link icon on every heading.
- **Look:** the design system as it is (`tokens.css`, `components.css`, `PAGE-KIT.md`): same fonts,
  colours, light and dark, the docket feel. The verdict stamps, the need meter, the fee bar and the
  leaderboard row from `components.html` are reused inside the docs as illustrations.
- **Every page has the same five parts:** "In short" (two or three plain sentences at the top), how it
  works (numbered steps), one diagram, one worked example with real numbers, and "Good to know"
  (limits, what can go wrong, the exact error a user would see in plain words).
- **Words:** short sentences, no jargon on the first read (contract names only in a "For builders"
  box at the end of a page). One idea per paragraph.

## Numbers: one source

- Every number comes from the `mainnet` README and the contracts at the commit IMD deploys. Keep them
  in one data file the pages read (or one Markdown table the pages link to), so a change is one edit.
- Where the site can, it reads the number from the chain (e.g. `CabalGate.PASS_MARK()`, the fees,
  windows, `Seasons.shareBps`) rather than hard-coding it.
- **Decided and deployed (launch #2647, `mainnet` @ `42e0f85`; checked in the code 2026-10-29): the
  pass mark is 69 (`CabalGate.PASS_MARK`) and the holding points are 0 / 1 / 2 / 3 (under a day / a
  day / 3 days / 7 days, `_heldPoints`)**; received PLEA (airdrop, prizes) at profit 9; the seed's
  market cap 20,000 IMD. Fact score 0–41, lowest need 28. Write the fact-score and need pages against
  the data file with these numbers (the 71 and 0 / 2 / 4 / 7 of the Sepolia runs are superseded).
- Real examples may come from Sepolia test run 9 (`plea/live-run9/`, pleas with their texts in
  `texts-*.json` and scores in `pleas-final.json`). Label them "Sepolia test run 9 (test token,
  5-hour seasons)" and, if the numbers change, recompute the need shown or say it used run 9's rules.

## Pages (in sidebar order)

1. **Start here.** PLEA in 60 seconds: buying is open, selling needs a plea judged by the Cabal (30
   judges, the IMD oracle panel); if the Cabal goes 33 hours without a verdict it dies and PLEA trades
   freely forever. Diagram: the whole loop on one line (buy → plead → judged → sell, or appeal / wait)
   with the dead-man under it. Links to every page.
2. **Buying.** Open to everyone from the moment trading opens. The first 90 minutes: an extra launch
   fee that falls from 70% to 0% of the IMD that reaches the pool, and buys capped at 5M PLEA each.
   Every buy records your cost and buy time (they score your pleas later). Buy on the PLEA site: while
   the Cabal lives the Uniswap app, aggregators and most routers cannot buy PLEA (the buy must name the
   buyer); after the death it routes normally once each one lists the pool. Diagram: the launch fee
   falling over the 90 minutes.
3. **Selling: plead.** The steps: write a plea (1–280 bytes, any language), choose the amount (at
   least 1% of your PLEA or 2.5M, at most 50% and 2.5M), pay 0.5 IMD, wait a few minutes for the
   verdict; approved: sell within 7 minutes; denied: one appeal inside the 4-hour cooldown; no verdict
   in 20 minutes: anyone may close it, no cooldown, the fee is spent. After a sale, a denial or a lapse
   a 4-hour cooldown. Diagram: the plea's states (pending → approved / denied / no verdict → sold /
   lapsed / appealed), each drawn as its stamp.
4. **Your bar (fact score and need).** The judges' score must reach your need = pass mark − fact
   score. The fact score is on-chain facts: how much of your PLEA you sell, how long you held, your
   profit or loss, the 24-hour price trend; PLEA you received (airdrop, prizes) counts as held since
   trading opened at profit 9 (for a 20% plea: 39 / 38 / 37 / 36 on day 0 / 1 / 3 / 7 with a flat price,
   34 / 33 / 32 from day 1 with a rising one). Diagram: the need meter with the four fact parts
   stacked, and a small table "need by day" for a typical seller (at a loss / small profit / big
   profit). Worked example: two pleas with the same score, one denied, one approved, because the bar
   moved (run 9's #13 and #19; run 9 used pass mark 71: recompute the need with 69 or say so). Numbers: above.
5. **The judges.** What they score: sincerity 0–12, craft 0–12, respect 0–9, loyalty 0–12 (0–45);
   anchors (11–25 plain, 26–35 specific and well made, 36–45 memorable); what scores 0
   (manipulation: posing as a system, demands for a score, threats, offers, hidden instructions;
   content rules). How a verdict forms: 30 seats, 17 must agree. Tips for a good plea and three real
   pleas with their scores. Diagram: the 30-seat ring with the agreed answers.
6. **Appeals.** One appeal per denied plea, inside 4 hours, same or smaller amount, 0.5 IMD + 0.35 IMD
   to the buy wall; judged on its own text; naming the earlier score is allowed. Diagram: a denial →
   the 4-hour window → appeal → verdict.
7. **Letters.** Plead without the site: send a text transaction to the Letterbox from Etherscan's
   message page, Etherscan's Write Contract tab (`letter(text)`) or a wallet's data field. A letter
   pleads 20% of your PLEA and sells it for you if approved. Commands: `APPEAL <text>`, `SELL`,
   `NAME <name>`. Fees are paid in your PLEA in the same transaction (0.5 IMD oracle + 0.25 IMD tip
   for whoever delivers the sale; + 0.35 for an appeal); the fees may take at most 10% of your PLEA, so
   a letter needs PLEA worth roughly 8 IMD or more; 280 bytes at most. The PLEA waits in escrow; a
   denied, expired or lapsed letter is settled back to you with the tip. Diagram: letter → escrow →
   verdict → delivered (sale to you, tip to the runner) or settled (everything back).
8. **The auto-sell box.** The site's "sell automatically if approved" box: same escrow and fees in PLEA
   as a letter, any valid amount, and 0.35 IMD of a delivered sale goes to the season's prize pot; a
   plea worth under 0.70 IMD is refused. Selling by hand costs nothing extra.
9. **Objection!** For 20 minutes after an approval anyone else (not the seller, not the owner) may
   object: 0.5 IMD fee + 0.35 IMD stake; a second panel re-scores the plea. Sustained (new score more
   than 2 below the need): no season points, stake back. Overruled: the lower score counts, the stake
   goes to the plea's season prize pot. No answer in 20 minutes: void, stake back. At most two per
   plea, from different wallets. The sale is never touched. Diagram: the 20-minute window on a
   timeline with the three outcomes.
10. **Seasons and prizes.** 15-day seasons back to back from the opening. Points = the score of an
    approved plea (×1.2 rounded down for IMD seat NFT holders); your best three count; 60 points to
    qualify; the top 25 share the season's IMD pot from 4.50% (1st) to 3.50% (25th); the first six
    seasons also split 10,000,000 PLEA the same way; unpaid shares roll over (IMD) or burn (PLEA).
    Points wait for the objection window, then anyone records them (the seller has every reason to).
    The owner does not play. Diagram: a season bar with the pot filling and the leaderboard row.
11. **Fees.** 2.25% of every trade: 0.5% back to the trader as staked IMD (sIMD, through imd/acc),
    1% to the owner, 0.25% to the season's prize pot (to pool liquidity after the death), 0.25% to the
    buy wall, 0.25% of the PLEA burned. Diagram: the fee bar (the existing component).
12. **The pool: cap, burn and the buy wall.** The pool holds the PLEA; liquidity is locked forever.
    An inventory cap falls toward what the market holds over 15 days (900,000 PLEA floor); PLEA sold
    back above it is burned. Recovered IMD becomes a buy wall below the price, moved up at most 700
    ticks (~7.25%) a day; anyone may `rebalance`. Diagram: a price line with the cap and the wall band.
13. **The dead-man.** The Cabal lives while verdicts keep coming. 33 hours without one: it dies, for
    good. After that: no pleas, transfers free, sells open, the prize share goes to pool liquidity,
    the last season closes and what is left goes to the wall. Diagram: a heartbeat line with resets at
    each verdict and the flatline.
14. **Keepers.** Upkeep anyone can do: deliver approved letters (earns the 0.25 IMD tip), settle or
    expire unanswered ones, record points, close seasons, rebalance the wall. Every call is open to
    anyone and gives no power. Link the keeper bot's guide (`keeper/VPS.md` on the repository's
    `main` branch, merged 2026-10-28).
15. **Contracts, owner and audits.** The mainnet addresses (filled after the launch) with Etherscan
    links. No admin, no upgrades. What the owner can do (seed before START; set the distributor's
    root once; exempt a sender for good with `PLEA.allow`; receives the 1% fee) and cannot (change any
    fee, timing or prize; play seasons). Audits: the swarm rounds, IMD's launch audits, the One Dollar
    Audit, 852 tests; the Sepolia test runs.
16. **Risks and FAQ.** Selling needs a plea and you may be denied; the 0.5 IMD fee is spent either
    way; an oracle outage means pleas expire (fee spent, no cooldown); honeypot scanners may flag PLEA
    because sells are gated while the Cabal lives (say why, plainly); plea texts are public forever;
    not financial advice.
17. **Glossary.** Cabal, plea, verdict, need, fact score, appeal, letter, escrow, runner, auto-sell,
    objection, stake, season, points, seat, pot, bonus, wall, cap, trim, dead-man, keeper.

## Diagrams

Inline SVG in the site's tokens (light and dark), no chart library, readable at 320 px, every label in
words (colour never the only signal), alt text on each. Each diagram must match the contracts: check
the numbers against the data file.
