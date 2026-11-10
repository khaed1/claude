# Next-session prompt: after the Murmuration build-ready revision (4.1)

Paste the block below into a fresh Claude Code session on this repository. The files are on `claude/gallant-euler-eovmds`.

---

You are taking over Murmuration, a privacy-pool design for Ethereum mainnet built and run by the IMD (IdentityMD, imd.fun) swarm. Revision 4.1 of 10 November 2026 reviewed the pool, token contracts, auction and screening registry, changed the design where they failed, wrote a build-ready specification, simulated the economics, checked seven assumptions and drafted 50 IMD job briefs. Nothing is built, deployed or submitted.

Read first, in this order:
1. `reports/Murmuration v4 specification.html` (published at https://claude.ai/artifact/4BpAYUhRLVR3vv4u9RfsaB). Sections "Review of the new parts", "Build specification", "Defaults to confirm" and "What was checked" are new.
2. `reports/build_plan/README.md`, then only the briefs you need. `generate.py` in that folder rewrites the briefs and checks IMD's request limits.
3. The revision 4.1 block of the changelog in `reports/Murmuration privacy stack.html` (published at https://claude.ai/artifact/FTpHa2bajd3eY8mhumgTZQ).
4. `research_notes/IMD swarm privacy project design/design_review_v3.md`. Send subagents to the other `_v3.md` notes for quoted evidence; do not read them whole.

**The owner's decisions are unchanged and are not reopened:** immutable contracts; the pool as the main product; no external audit firm; 0.2% in and 0.2% out with a 40/40/20 split; the token allocation 45/25/15/10/5 on two-year schedules; one pseudonymous founder address; a 25% one-sided pool against IMD from 48,000 IMD; screening at entry by staked seat holders; the team operates nothing.

**Ask the owner first.** Ten defaults are listed in the spec under "Defaults to confirm", each with a recommendation. Three change the design: removing the seven-day fallback, stopping the caps at 800 ETH, and the asset list (ETH, USDC, DAI, the token). Apply the owner's answers to the spec, the parameter table and `generate.py`.

Then, in order:

**A. Get an independent review of revision 4.1.** The redesign was done by the session that did the review, and a second reviewer was lost to a usage limit. Give a fresh subagent only the spec page and ask it to attack the new mechanisms: public activation by the depositor, the single Spend circuit and its fourteen constraints, the reward index with exact entry and floored checkpoints, the refusal bitmap and commit-reveal registry, the basket auction and stepped buyback, the staged deployer, the compressed-clock canary. Fix what it finds.

**B. Re-check what was provisional.** EIP-8037 and EIP-8038 after the audit reports of 13 November and the developer call of 19 November 2026; whether the `clean` framework's `poseidon-n-arity` branch has merged; whether Uniswap governance takes a protocol fee on v3 pools at the 1% tier; the X-Wing draft's status.

**C. Only if the owner says so in the session:** create the public project repository, and submit B00, C00 and R01 from the build plan. The owner signs off the frozen statements from C00 after reading R01. Nothing else in the proof track starts before that.

**D. Update the deliverables** as before: edit the spec in place and publish to its existing URL, add each change to the changelog with reason and source, save new notes with a `_v4` suffix, commit and push.

Constraints: no deployments, transactions or external audits. Nothing is sent to IMD, its developer or any third party unless the owner says so in the session. Do not create a pull request. Do not advise on concealing anyone's identity. This is not legal advice, and the spec must keep saying that a lawyer reviews the fee, the token, the public pool and the founder allocation before launch, and now before the canary. Write for a reader who knows crypto but is not a cryptographer.

Practical notes: commit and push early; a usage limit killed eight subagents mid-run in the last session, and they had written nothing to disk. Tell every subagent to write its note file first and update it as it goes. To publish over an artifact the session has not published, read its saved copy in full with explicit line ranges first. For large HTML edits use a script with exact-match assertions and validate the result.
