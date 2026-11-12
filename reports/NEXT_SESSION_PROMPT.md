# Next-session prompt: after Murmuration revision 4.5

Paste the block below into a fresh Claude Code session on this repository. The files are on `claude/fervent-gauss-ujoati`.

---

You are taking over Murmuration, a privacy-pool design for Ethereum mainnet built and run by the IMD (IdentityMD, imd.fun) swarm. Four reviews in two days each found serious faults, most of them in the fixes for the review before. The counts fell each round: one critical and six high (revision 4.1), seven high (4.2), one high and three "high if misread" (4.3 and 4.4). Revision 4.5 answers the fourth review. A fifth review of revision 4.5 was started on 12 November 2026; **check whether its two notes are complete before doing anything else** (see A). Nothing is built, deployed or submitted.

Read first, in this order:
1. `reports/Murmuration v4 specification.html` (published at https://claude.ai/artifact/4BpAYUhRLVR3vv4u9RfsaB). Start with "What revision 4.5 changes", "Fourth review", "Build specification" and "The defaults, as decided". Render it to text with `reports/tools/render_text.py` and read the text.
2. `research_notes/IMD swarm privacy project design/design_review_v4.md`: the owner's decisions of 11 November and the reasons for every change in 4.5.
3. The fifth-review notes, `adversarial_review_r45_core_v4.md` (ids X-n) and `adversarial_review_r45_mechanisms_v4.md` (ids Y-n), if they exist and are complete.
4. `reports/build_plan/README.md`, then only the briefs you need.
5. The revision 4.5 block of the changelog in `reports/Murmuration privacy stack.html` (published at https://claude.ai/artifact/FTpHa2bajd3eY8mhumgTZQ).

Do not show earlier review notes to a new reviewer.

**The owner's decisions are not reopened.** Immutable contracts; the pool as the main product; no external audit firm; 0.2% in and 0.2% out with a 40/40/20 split paid in the asset received; the token allocation 45/25/15/10/5 on two-year schedules; one pseudonymous founder address; a 25% one-sided pool against IMD from 48,000 IMD; screening at entry by staked seat holders; the team operates nothing; exit sizes from 0.005 ETH, 5 IMD and 10 USDT or USDC; the asset list ETH, USDT, USDC, IMD and the pool's own token; IMD at full reward weight with a cap of 2,500 rising to 80,000; a screener stake of 0.03% of supply. Decided in session on 11 November: **keep every feature and fix findings, do not cut scope**; the relayer is paid in the asset being spent out of the notes being spent, with no fee note, and the ceiling `(4 × basefee + 1 gwei) × 2,000,000`; two thirds of active screeners with no fallback, removal by strikes and a 90-day bar; the stop on the caps at 800 ETH; a one-day minimum age measured at the batch; schedules from the registry's first batch; refund of a refused deposit by others at 21 days; a 30-day wait and 14 days of unbonding for screeners; a four-year deposit window; the reward floor; a two-year swarm vest; the auction and buyback. Nothing is left for the owner to confirm.

One thing to tell the owner plainly if they have not seen it: they confirmed strikes of +2 and −1 with removal at 14. The fourth review showed those figures let a group that takes turns block up to 42% of days for ever. Revision 4.5 uses +3, −1 only on a day a batch is accepted, and removal at 21, which holds a group to about one day in three (`reports/sim/strike_rule.py`).

Then, in order:

**A. Finish the fifth review and act on it. Repeat until a review comes back with no high and no high-if-misread finding.** If the two fifth-review notes are missing or stop at a skeleton, start that review again from `reports/tools/review_brief_r45.md` and a fresh text rendering. If they are complete: fix every finding as revision 4.6 (a removal is fine where it is the fix; nothing the owner decided is reopened), record reasons in `design_review_v4.md`, and send 4.6 to two fresh reviewers split the same way (circuit, notes and pool; registry, launch, fees and canary). Point them at what the revision changed. Keep the count of findings per round in the specification's risk table honest.

**B. Re-check EIP-8037 and EIP-8038** after the audit reports of 13 November and the developer call of 19 November 2026. On 11 November nothing had changed (`status_changes_v4.md`, section 1): `launch` needs about 42M gas under the draft rules and stops fitting above about 2,190 gas per state byte or under a block limit of about 42M. The other provisional facts were settled on 11 November and need no re-check unless something moves: the `clean` Poseidon branch (unmerged, conflicting), Uniswap's protocol fee (one sixth on 1% pools), X-Wing (draft 11, not adopted), USDT's source.

**C. Only if the owner says so in the session:** create the public project repository, and submit B00, C00 and R01 from the build plan. The owner signs off the frozen statements from C00 after reading R01. Nothing else in the proof track starts before that. Not before a review has passed.

**D. Update the deliverables** as before: edit the specification in place and publish to its existing URL, add each change to the changelog with reason and source, regenerate the briefs with `reports/build_plan/generate.py`, save new notes with a `_v4` suffix, commit and push.

Constraints: no deployments, transactions or external audits. Nothing is sent to IMD, its developer or any third party unless the owner says so in the session. Do not create a pull request. Do not advise on concealing anyone's identity. This is not legal advice, and the specification must keep saying that a lawyer reviews the fee, the token, the public pool and the founder allocation before launch and before the canary. Write for a reader who knows crypto but is not a cryptographer.

Practical notes, learned the hard way:
- Commit and push after every step. Worker restarts and the usage limit interrupted this work four times in one day, and background agents do not survive a restart: anything they had not committed was lost.
- Give each background agent its brief as a file, tell it to write its note's skeleton and commit it in its first minutes, and to commit after every finding.
- Edit the pages with `reports/tools/edit_lib.py` (exact-match edits that fail loudly), then `validate_html.py`, then re-render and grep the text for wording the edit made stale. Summary sections go stale first: the lede, "How a payment moves", the pool design table, the parameter table and the risks.
- Publishing over an artifact this session has not published needs a full read of the saved copy first. Delegate both pages to one subagent so that the read stays out of your context.
- IMD has a fixed supply of about 7.08 million and no mint function; do not describe its owner key as able to mint. IMD's address begins `0xd34a`.
