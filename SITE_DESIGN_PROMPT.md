Start the PLEA website's design system. Repo `khaed1/claude`, branch `claude/adoring-goodall-pn3jyz` (the notes; another session pushes there too: fetch + merge before every push, never rebase or force-push). Read this prompt first, then `NEXT_SESSION.md` ("The two projects", "Agreed numbers") and the site notes listed below.

**What PLEA is:** a meme token on Uniswap v4 where buying is open but selling needs a plea. The seller writes why they want to sell; "the Cabal", 30 judges on an IMD oracle panel, scores it 0-45; it passes if the score reaches the need, 71 minus the on-chain fact score (share sold, hold time, profit or loss, 24h trend).
- Approved: sell within 7 minutes. Denied: one appeal within 4 hours. A 4-hour cooldown after a sale, a denial or a lapse.
- Letters: plead by sending text to the Letterbox from Etherscan; it sells automatically when approved, and whoever delivers it earns a 0.25 IMD tip.
- Objection!: for 20 minutes after an approval anyone may object (0.5 IMD fee + 0.35 stake); a new panel re-scores the plea.
- Seasons (15 days on mainnet): the best 3 scores count; the top 25 with at least 60 points share the IMD pot, plus a 10,000,000 PLEA bonus in each of the first six seasons; IMD seat holders get 1.2x points.
- The Cabal dies after 33 hours without a verdict; trading is free from then on.
- Fees 2.25%: 0.5% cashback as staked IMD (imd/acc), 1% owner, 0.25% season prize pot, 0.25% buy wall, 0.25% PLEA burned. The 12% distributor (swarm 10% + airdrop 2%) is claimed on a claim page.

**Your job: the design system for the PLEA site.** IMD's site job builds the site later (a static Vite + React export on IPFS, label `plea` -> plea.sites.imd.fun, reading the chain and IMD's API; IMD's Indexer job comes first). You do not build the site, submit any IMD job, pay anything, or touch wallets or keys.

**Step 1: ask me about the style first; do not pick one yourself.**
- Show me 3 style directions as small visual samples of the same screen (a plea card with its verdict stamp, the buy box, a leaderboard row), each with its type, palette and a one-line mood.
- My lead candidate is neo-brutalism (thick black outlines, hard offset shadows, flat bold colours, chunky type). Make it one of the three, done with restraint for a tool that moves money.
- Recommend one, say why in plain words, and wait for my pick.
- Also ask me: light or dark by default (or both); how loud the colours; mono or a display face for headlines; the tone (serious courtroom or meme); how much motion; keep or redo the X logo and header (`plea/brand/`).

**Step 2: after I pick, write the design system.**
- Tokens as CSS variables: colour (with state colours: approved, denied, pending, no verdict, lapsed, executed; light and dark if both), type scale, spacing scale, borders, radii, shadows, motion.
- Components: nav, buttons, inputs (with a byte counter and the contract's text checks), pills, cards, the verdict stamp, the plea card, countdowns, tables and the leaderboard, the Wall card, toasts, and empty, loading and error states.
- Mockups of the key pages with real numbers from NEXT_SESSION's agreed numbers (no lorem ipsum): home and how it works, buy, plead with the auto-sell box, a plea's status page, letters (the Etherscan how-to), objections, seasons and the leaderboard with the seat multiplier, the Wall, the claim page for the 12%, a wallet profile, and the X share card for each plea.
- Accessibility: body text contrast at least 4.5:1 (large text 3:1), keyboard use, reduced motion, colour never the only signal. Responsive at 360, 768 and 1280 px with no horizontal scroll.
- Polished: one spacing scale, one type scale, aligned grids, the same stamp everywhere, tabular figures for amounts and countdowns, a real state for every element.
- Finally, a short brief for IMD's site job, at most 5,500 characters (the explorer form cuts there).

**Read first (the site notes, all in this repo):**
- `plea/site-next-fixes.md`: what the last site got wrong and what the next one needs (a colour per verdict state, the letters page, the auto-sell box, the status page, the Wall card redesign, the X share card, the claim page and delegate.xyz, the byte counter, the seat multiplier on the leaderboard).
- `plea/launch-spec.md` (the Website section): the last design system (imd.fun's tokens, IBM Plex Mono, pills, stamps).
- `plea/job-2-website.md`, `plea/job-v10-site.md`, `plea/job-v4-site.md`, `plea/job-continue-site.md`: earlier briefs ("a private court: ink, parchment and a wax-seal red", the refuse list, contrast and layout floors). They are history: the style I pick replaces them, but keep what still fits: the verdict stamp as the signature, and never IMD's diamond logo, so the site is not taken for an official IMD page.
- `plea/letters-spec.md` (how letters work), `plea/hackathon-submission.md` (the pitch in my voice), `plea/brand/` (the current X logo and header).
- Read only: the live v10 site's source `khaed1/plea-site` and the contracts and README `khaed1/plea` branch `next` (attach both with add_repo).

**Rules:** explain simply; when I must choose, recommend one option. Show visuals (artifacts or PNGs), not long text. Save the design system in `plea/site-design/` and push after each step; add a short section for this work at the end of `HANDOFF.md`. Never touch wallets, keys, IMD jobs or khaed1/plea's branches; imd/acc (`khaed1/imd-acc`) is read only.
