# Next-session prompt: from the Murmuration v4 spec to a build-ready design

Paste the block below into a fresh Claude Code session on this repository. The files are on `claude/keen-ramanujan-cbv9bu` and `claude/upbeat-hawking-76x6mg` (same commit). Run it at high effort.

---

You are taking over Murmuration, a privacy-pool design for Ethereum mainnet built and run by the IMD (IdentityMD, imd.fun) swarm. Three earlier sessions produced the research, an adversarial re-review, and four revisions of the spec. Version 4 is the current design. Your job is to attack the parts of version 4 that have never been reviewed, turn it into a build-ready technical specification, and check the assumptions it still rests on.

Read first, in this order:
1. `reports/Murmuration v4 specification.html` (the current spec; published at https://claude.ai/artifact/4BpAYUhRLVR3vv4u9RfsaB)
2. The "Review findings" and "Changelog" sections of `reports/Murmuration privacy stack.html` (the history page; published at https://claude.ai/artifact/FTpHa2bajd3eY8mhumgTZQ). Skip the rest of that file.
3. `reports/NEXT_SESSION_PROMPT.md` (this file)

Do not read the 19 research note files in `research_notes/IMD swarm privacy project design/` yourself. They total about 800 KB. When you need a fact, send a subagent to the specific file (names ending `_v2.md` are the newest) and ask for quoted evidence.

**Decisions the owner has made. Do not reopen them. Record disagreement in the spec if you have evidence, then build what was decided.**
- Fully immutable contracts: no admin, pause, upgrade, fee switch or mint.
- The pool is the main product, with its own contracts and new circuits.
- No external audit firm. Assurance comes from IMD audit panels, machine-checked proofs, a 90-day mainnet canary and low caps.
- Pool fee 0.2% in and 0.2% out. The entry fee is taken at a deposit's first spend. Fee split 40% stakers, 40% screeners, 20% into locked liquidity through a daily descending-price auction for IMD.
- Token: fixed supply, no sale, no treasury, no governance. Allocation 45% users (private shielded-time rewards), 25% public pool, 15% screeners, 10% the swarm, 5% founder. Every schedule runs two years.
- Founder's 5%: one pseudonymous address, two-year vest, one-month cliff.
- Public pool: 25% of supply, one-sided against IMD only, position locked for good, starting valuation 48,000 IMD, wide range, no ETH pair.
- Screening stays. Deposits are screened at entry by staked seat holders using published, recomputable criteria.
- The team writes software and operates nothing.

**Defaults chosen by the previous session that the owner has not confirmed. List them for the owner with a recommendation each; do not treat them as settled.** Exit sizes (1, 2, 5 series); minimum age of 7,200 blocks; starting cap of about 25 ETH per asset doubling every 90 days; deposit window of about four years; screening threshold of two thirds with a seven-day fallback rule; screener stake amount (unset); user rewards released in step with the caps; swarm lock of up to one year; the asset list; the auction design.

Then do the following, in order.

**A. Attack the new parts.** The pool, the token contracts, the fee auction and the screening registry were designed in one session and never reviewed. For each, give the weakest assumption, the most likely failure and anything overbuilt, as specific mechanisms and not categories. Cover at least: screening at entry with no label carried afterwards (can a thief get a deposit approved, spend once, and be untouchable?); the fallback rule (can someone stall screeners for seven days to trigger it?); the reward index (rounding, the first-depositor case, index manipulation when total shielded value is tiny, whether reward notes can exceed the budget); fixed-size exits (how change and dust are handled, what a large withdrawal looks like on-chain); the daily auction (griefing, zero-bid days, sandwiching the liquidity add); screener registration (cost to capture two thirds, stake-and-exit timing); the canary (does it really exercise the same code paths?); per-asset limits and the cap schedule.

**B. Write the build-ready specification.** For each of the three circuits: public inputs, private inputs and every constraint in words. For each of the six contracts: storage, external functions, events and invariants. State machines for a deposit and for a note. Keep every contract under 24 KiB and every transaction under 16,777,216 execution gas, and price state under EIP-8037 and EIP-8038.

**C. Simulate the economics.** Write a small script and show results for: the one-sided range (IMD in the pool and price at 10%, 25%, 50%, 75% sold, from a 48,000 IMD start); sell pressure from two years of unlocks against that depth; fee income and liquidity added at pool volumes of $1M, $10M and $100M a month; user reward per unit of shielded value across the cap schedule.

**D. Check what was never verified.** Use parallel subagents. Whether IMD's launch factory can issue a token with no owner and no mint and route its trade fee to a contract; whether IMD has ever audited a zero-knowledge circuit, and what its audit template covers; whether an operator can reach a PPOI node; the Railgun engine's quick-sync hook; the cost of ML-KEM-768 ciphertexts on-chain today and under Glamsterdam; machine-checkable proof tooling for Circom or Noir circuits that an agent could use; anything that changed since 10 November 2026 in the Glamsterdam schedule, US v. Storm, or IMD's Goals feature. Mark what you could not verify.

**E. Draft the build plan for the swarm.** Break the work into IMD job briefs (build, review, audit, proof), each small enough for one request, with acceptance tests. Save them as files under `reports/build_plan/`. Do not submit any of them.

**F. Update the deliverables.** Edit `reports/Murmuration v4 specification.html` in place and publish it to its existing URL. Add each change to the changelog on the history page, with reason and source. Save new notes with a `_v3` suffix. Commit with clear messages and push.

**G. Report back** in under 400 words: the five most serious findings from A, the simulation's headline numbers, the unconfirmed defaults with your recommendation for each, what you could not verify, and both artifact links.

Constraints: no deployments, transactions or external audits. Nothing is sent to IMD, its developer or any third party unless the owner says so in the session. Do not create a pull request. Do not advise on concealing anyone's identity. This is not legal advice, and the spec must keep saying that a lawyer reviews the fee, the token, the public pool and the founder allocation before launch. Write for a reader who knows crypto but is not a cryptographer.

Practical notes from earlier sessions: commit and push early, because usage limits have interrupted long runs. For large edits to the HTML pages, use a script with exact-match assertions and validate the HTML afterwards. To publish over an artifact this session has not published, read its saved copy in full with explicit line ranges first; a truncated read does not count.
