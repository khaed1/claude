# Next-session prompt: after Murmuration revision 4.3

Paste the block below into a fresh Claude Code session on this repository. The files are on `claude/gallant-euler-eovmds`.

---

You are taking over Murmuration, a privacy-pool design for Ethereum mainnet built and run by the IMD (IdentityMD, imd.fun) swarm. Three reviews in two days each found serious faults, most of them in the fixes for the review before: revision 4.1 (the author's own review), revision 4.2 (answer to an independent review that found 1 critical and 6 high), and revision 4.3 (answer to two reviewers who found 7 high in 4.2). Nothing is built, deployed or submitted. **Revision 4.3 has not been reviewed by anyone but its author.**

Read first, in this order:
1. `reports/Murmuration v4 specification.html` (published at https://claude.ai/artifact/4BpAYUhRLVR3vv4u9RfsaB). Start with "Review of revision 4.2", "Build specification" and "Defaults to confirm".
2. `reports/build_plan/README.md`, then only the briefs you need. `generate.py` in that folder rewrites the briefs and checks IMD's request limits.
3. The revision 4.3 block of the changelog in `reports/Murmuration privacy stack.html` (published at https://claude.ai/artifact/FTpHa2bajd3eY8mhumgTZQ).
4. The last two addenda of `research_notes/IMD swarm privacy project design/design_review_v3.md`. Send subagents to the other `_v3.md` notes for quoted evidence; do not read them whole. Do not show the earlier review notes to a new reviewer.

**The owner's decisions are not reopened:** immutable contracts; the pool as the main product; no external audit firm; 0.2% in and 0.2% out with a 40/40/20 split; the token allocation 45/25/15/10/5 on two-year schedules; one pseudonymous founder address; a 25% one-sided pool against IMD from 48,000 IMD; screening at entry by staked seat holders; the team operates nothing. Decided on 10 and 11 November: exit sizes from 0.005 ETH; the asset list is ETH, USDT, USDC, IMD and the pool's own token; IMD has full reward weight, a cap of 2,500 IMD rising to 80,000 and exit sizes from 5 to 50,000 IMD; the screener stake is 0.03% of supply.

**Ask the owner first.** Ten defaults are listed in the spec under "Defaults to confirm". Five change the design: no fallback with removal by strikes; the stop on the caps at 800 ETH; the one-day minimum age measured at the batch; the relay fee (any listed asset, public, with a ceiling and the 0.2%); schedules counted from the registry's first batch. Also unconfirmed: the exit sizes for USDT and USDC, the 21-day rule for refunds by others, and the 30-day wait and 14-day unbonding for screeners. Ask too whether the owner wants to keep patching or to cut scope: every round has added mechanism, and every round's additions are where the next review found faults.

Then, in order:

**A. Review revision 4.3 before anything is submitted, and repeat until a review comes back with no high finding.** Use fresh reviewers given only the spec page (make a plain-text rendering for them), split by area as the last round was: circuit, notes and pool; registry, launch, fees and canary. Point them at what is new in 4.3: the public fee asset and the ceiling that reads `block.basefee`; value crossing between the fee side and the asset side; `owed` credits; the strike counter settled lazily from a 16-slot ring; the pool reading `START` from the registry; the salt loop in `launch`; the 4-hour apply-only window; the example criteria's terms. Tell each to write its note first and commit as it goes.

**B. Re-check what was provisional.** EIP-8037 and EIP-8038 after the audit reports of 13 November and the developer call of 19 November 2026, and with them the gas of `launch` (about 45M by estimate); whether the `clean` framework's `poseidon-n-arity` branch has merged; Uniswap's protocol fee on v3 pools at the 1% tier; the X-Wing draft's status; USDT's verified source.

**C. Only if the owner says so in the session:** create the public project repository, and submit B00, C00 and R01 from the build plan. The owner signs off the frozen statements from C00 after reading R01. Nothing else in the proof track starts before that.

**D. Update the deliverables** as before: edit the spec in place and publish to its existing URL, add each change to the changelog with reason and source, save new notes with a `_v4` suffix, commit and push.

Constraints: no deployments, transactions or external audits. Nothing is sent to IMD, its developer or any third party unless the owner says so in the session. Do not create a pull request. Do not advise on concealing anyone's identity. This is not legal advice, and the spec must keep saying that a lawyer reviews the fee, the token, the public pool and the founder allocation before launch and before the canary. Write for a reader who knows crypto but is not a cryptographer.

Practical notes: commit and push early; usage limits and a worker restart interrupted the last sessions several times. For large HTML edits write fragments, merge them with a script that asserts every exact match, and validate the result (tag balance, unique ids, in-page links); then scan the sections you did not touch for stale wording. To publish over an artifact the session has not published, read its saved copy in full with explicit line ranges first. IMD has a fixed supply of about 7.08 million and no mint function; do not describe its owner key as able to mint. IMD's address begins `0xd34a`.
