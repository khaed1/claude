# Next-session prompt: after Murmuration revision 4.2

Paste the block below into a fresh Claude Code session on this repository. The files are on `claude/gallant-euler-eovmds`.

---

You are taking over Murmuration, a privacy-pool design for Ethereum mainnet built and run by the IMD (IdentityMD, imd.fun) swarm. Revision 4.1 (10 November 2026) reviewed and redesigned the pool, token contracts, auction and screening registry. An independent reviewer then found one critical and six high faults in it. Revision 4.2 (11 November 2026) answers that review and builds in the owner's asset list. Nothing is built, deployed or submitted. **Revision 4.2 has not been reviewed by anyone but its author.**

Read first, in this order:
1. `reports/Murmuration v4 specification.html` (published at https://claude.ai/artifact/4BpAYUhRLVR3vv4u9RfsaB). Start with "Independent review of revision 4.1", "Build specification" and "Defaults to confirm".
2. `reports/build_plan/README.md`, then only the briefs you need. `generate.py` in that folder rewrites the briefs and checks IMD's request limits.
3. The revision 4.2 block of the changelog in `reports/Murmuration privacy stack.html` (published at https://claude.ai/artifact/FTpHa2bajd3eY8mhumgTZQ).
4. `research_notes/IMD swarm privacy project design/design_review_v3.md` (the last addendum) and the top-ten section of `adversarial_review_independent_v3.md`. Send subagents to the other `_v3.md` notes for quoted evidence; do not read them whole.

**The owner's decisions are not reopened:** immutable contracts; the pool as the main product; no external audit firm; 0.2% in and 0.2% out with a 40/40/20 split; the token allocation 45/25/15/10/5 on two-year schedules; one pseudonymous founder address; a 25% one-sided pool against IMD from 48,000 IMD; screening at entry by staked seat holders; the team operates nothing. Decided on 10 and 11 November: exit sizes from 0.005 ETH; the asset list is ETH, USDT, USDC, IMD and the pool's own token; IMD has full reward weight, a cap of 2,500 IMD rising to 80,000 and exit sizes from 5 to 50,000 IMD.

**Ask the owner first.** Nine defaults are listed in the spec under "Defaults to confirm". Four change the design: removing the fallback together with the rule that a screener seven days against the majority can be removed; the stop on the caps at 800 ETH; measuring the one-day minimum age at the batch, which makes activation take about two days; and paying the relayer in public ETH from a third input. The exit sizes for USDT and USDC (1 to 1,000,000) are also unconfirmed. Apply the answers to the spec, the parameter table and `generate.py`.

Then, in order:

**A. Get a third review, of revision 4.2, before anything is submitted.** Each of the last two reviews found faults in the fixes for the one before. Give a fresh subagent only the spec page. Point it at what is new: the launch that creates the token with a `prevrandao` salt and a bounded price reset; the age rule against `dataTime`; majority-miss eviction and what a majority can now do; the three-input circuit and its zero conventions; `roll()` and the checkpoint roots; the buyback bound from the locked position's liquidity; the Deployer's derived addresses; the seven-condition launch gate. Ask it for contradictions between sections and for anything a builder would have to guess. Tell it to write its note file first and append as it goes.

**B. Re-check what was provisional.** EIP-8037 and EIP-8038 after the audit reports of 13 November and the developer call of 19 November 2026; whether the `clean` framework's `poseidon-n-arity` branch has merged; whether Uniswap governance takes a protocol fee on v3 pools at the 1% tier; the X-Wing draft's status; USDT's verified source (not re-read in revision 4.2).

**C. Only if the owner says so in the session:** create the public project repository, and submit B00, C00 and R01 from the build plan. The owner signs off the frozen statements from C00 after reading R01. Nothing else in the proof track starts before that.

**D. Update the deliverables** as before: edit the spec in place and publish to its existing URL, add each change to the changelog with reason and source, save new notes with a `_v4` suffix, commit and push.

Constraints: no deployments, transactions or external audits. Nothing is sent to IMD, its developer or any third party unless the owner says so in the session. Do not create a pull request. Do not advise on concealing anyone's identity. This is not legal advice, and the spec must keep saying that a lawyer reviews the fee, the token, the public pool and the founder allocation before launch and before the canary. Write for a reader who knows crypto but is not a cryptographer.

Practical notes: commit and push early; usage limits and a worker restart interrupted the last session several times. Tell every subagent to write its note file first and update it as it goes. To publish over an artifact the session has not published, read its saved copy in full with explicit line ranges first. For large HTML edits use a script with exact-match assertions and validate the result (tag balance, unique ids, in-page links). IMD has a fixed supply of about 7.08 million and no mint function; do not describe its owner key as able to mint.
