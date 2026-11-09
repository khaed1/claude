# Next-session prompt: adversarial re-review of Murmuration

Paste the block below into a fresh Claude Code session on this repository (branch `claude/keen-ramanujan-cbv9bu`). Run it at high effort.

---

You are taking over a privacy-protocol design called Murmuration: a swarm-operated privacy stack on Ethereum mainnet built on IMD (IdentityMD, imd.fun) seat agents. A previous session produced the research, the design and a published spec page. Your job is to re-review the whole thing adversarially, make it better, and make it cheaper to build and run, then update the spec page in place.

Start by reading, in this order:
1. `reports/IMD swarm privacy project design.md` (the full research report, ~10k words)
2. `reports/Murmuration privacy stack.html` (the spec page; the same content is published at https://claude.ai/artifact/FTpHa2bajd3eY8mhumgTZQ)
3. Every file in `research_notes/IMD swarm privacy project design/` (12 sourced note files: Tornado Cash, privacy coins, Aztec and zk.money, the Ethereum privacy ecosystem, the unsolved-problem inventory, IMD and swarm tech, IMD's unreleased Goals feature, the Ethereum roadmap as of 8 Nov 2026, and cost inputs)
4. `reports/NEXT_SESSION_PROMPT.md` (this file)

Do not redo the research corpus. Re-verify only what can have changed since 8 November 2026, and cite a dated source for every change you make.

Then do the following, in order.

**A. Attack the design.** For each of the six services, the Layer 0 pool, the Goals integration, the fee model and the legal gate: list the weakest assumption, the most likely failure, and anything that is overengineered relative to the guarantee it buys. Be specific. "Collusion risk" is not a finding; "the client-side selection seed is derived from the nullifier, so a broadcaster that sees two requests from the same wallet can test whether they share a seed" is.

**B. Simplify.** Wherever a simpler mechanism gives the same privacy or legal property, replace it. Candidates to test: whether the panel ASP can be an overlay on Privacy Pools' existing ASP contract rather than new contracts; whether collaborative proving is needed at all now that Aztec claims 1-second native proofs and Zcash 200 ms mobile proofs; whether the read layer and the broadcaster mesh should be one role; whether threshold disclosure should be cut from scope entirely; whether the Layer 0 pool should exist or whether the project should stay services-only forever. Keep a component only if you can state the guarantee that is lost without it.

**C. Cut cost.** The budget is dominated by audits and formal verification (about $0.75M to $1.5M over 24 months), not infrastructure. Reduce novel code: reuse audited components (Railgun's contracts and broadcaster client, Privacy Pools' ASP and pool, Safe 1.4.1 and Zodiac Roles v2, Semaphore v4, the canonical CREATE2 factory) instead of writing new ones wherever the guarantee survives. Recompute the cost tables after your changes, at the then-current gas and prices, and show before and after.

**D. Re-verify time-sensitive facts.** Check and update: IMD's Goals feature (has it shipped? are docs at imd.fun/docs updated? are the 12 developer questions in the spec answerable now? fill the Answer column where they are); the Glamsterdam schedule and whether EIP-8037 and EIP-8038 parameters changed; the Hegotá EIP-8081 list and EIP-8141 and EIP-8250 status; Privacy Pools v2's ASP interface and whether it accepts alternative roots; Railgun broadcaster client API and fee rates; Kohaku's release state; IMD explorer agent counts and seat floor; ETH, IMD and gas prices; any new legal developments in US v. Storm (Rule 29 ruling, retrial date) or EU AMLR guidance on anonymity-enhancing coins. Use parallel subagents for this. Mark anything you could not verify.

**E. Keep these rules unless you find evidence they are wrong, and say so explicitly if you change one:** immutable core contracts with no admin, pause, fee switch or upgrade; the team writes software and operates nothing; no developer fee in any token; no project token before Layer 0 is live, and probably never; nothing brokered through IMD's closed control plane, admission derived from on-chain seat ownership; pool funds never in IMD contracts or any Goal escrow; screening real, published and executed by independent panels; disclosure user-held, opt-in and revocable; TEE attestation never the sole root; services first, pool only with evidence; all signature checks ERC-1271-aware; all gas assumptions compatible with the Glamsterdam repricing and the 16,777,216 transaction cap.

**F. Update the deliverables.** Edit `reports/Murmuration privacy stack.html` in place, keeping its title, structure, theme tokens and section ids. Add a dated "Changelog" section near the end listing every change with the reason and the source. Publish it to the existing artifact URL above (read the artifact first, then publish with `url`). Update the markdown report only where a finding contradicts it. Save new research notes into `research_notes/IMD swarm privacy project design/` with a `_v2` suffix. Commit with clear messages and push to `claude/keen-ramanujan-cbv9bu`.

**G. Report back.** In chat, give the ten most important changes with one sentence of reasoning each, the before-and-after cost totals, the list of facts you could not verify, and the artifact link. Keep it under 400 words.

Constraints: no external audits, deployments or transactions; nothing is sent to IMD, the IMD developer or any third party; do not create a pull request; do not add a token to the design; write for a reader who knows Ethereum and ZK but has not seen the previous session.
