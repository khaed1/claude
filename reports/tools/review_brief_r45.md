# Brief for the fifth review of the Murmuration specification (revision 4.5)

You are an independent adversarial reviewer of a design document. Your job is to break it. Nothing has been built; a fault you find now costs nothing, and a fault you miss ends up in contracts that can never be changed.

There are two reviewers. The message that sent you here says which one you are: **CORE** (circuit, notes and pool) or **MECH** (registry, launch, fees and canary). Read the common part, then the part for your area.

## Common part

### The one input

Read this file in full, with explicit line ranges (about 250 lines at a time, 1,732 lines in all):

/tmp/claude-0/-home-user-claude/29945ecd-c0f3-5435-9820-8daff0f0ffe0/scratchpad/review_r45/murmuration_spec_r45.txt

It is a plain-text rendering of "Murmuration v4 specification, revision 4.5": an immutable, screened privacy pool for Ethereum mainnet (Groth16 on BN254, Poseidon, one `Spend` circuit, six contracts: Pool, Verifier, ScreenerRegistry, FeeDistributor, Distribution, Token). In the rendering `^` marks a superscript (2^96), backticks mark code, and table rows are pipe-separated.

**Do not open any other file under /home/user/claude except the note you write.** That repository holds earlier reviewers' notes and the author's notes. Your value is that you have not seen them. Do not search the repository, do not read git history. You may use the shell (python3 is available) for arithmetic, small models and scripts, kept in your own folder under /tmp/claude-0/-home-user-claude/29945ecd-c0f3-5435-9820-8daff0f0ffe0/scratchpad/review_r45/ (`core/` or `mech/`). You may consult public references on the web for facts about external systems if you have a tool for it. A blocked host is not a problem to solve: note it and move on.

The page says that four earlier reviews each found serious faults, mostly in the fixes for the review before. Revision 4.5 answers the fourth and has been read by nobody but its author. Its section "Fourth review" lists what it took out and what it added. Read the whole page, not only your sections: contradictions between a summary section and the build specification are findings. If you see a fault outside your area, record it in two lines and go on.

### Not open for relitigation

The owner has decided these, and a finding that only disagrees with one of them is not a finding (you may record a cost briefly). A fault in how one of them is built or described is a finding.

Immutable contracts. No external audit firm. 0.2% in and 0.2% out with a 40/40/20 split, paid in the asset received. The token allocation 45/25/15/10/5 on two-year schedules. One pseudonymous founder address. A 25% one-sided pool against IMD from 48,000 IMD. Screening at entry by staked seat holders. The team operates nothing. The asset list ETH, USDT, USDC, IMD and the pool's own token. Exit sizes from 0.005 ETH, 5 IMD and 10 USDT or USDC. IMD at full reward weight with a cap of 2,500 rising to 80,000. The stop on the caps at 800 ETH. Schedules counted from the registry's first batch. A screener stake of 0.03% of supply. Two thirds of active screeners with at least seven, no fallback, removal by strikes and a 90-day bar. A 30-day wait before a screener counts and 14 days to get a stake back. A one-day minimum age measured at the batch. Refund of a refused deposit by others once it is 21 days old. The relayer paid in the asset being spent out of the notes being spent, so that a relayed spend shows its asset. The relay-fee ceiling formula `(4 × basefee + 1 gwei) × 2,000,000` with a factor of eight for other assets. One continuous auction for IMD followed by a bounded buyback and burn.

### Severity, calibrated

- **Critical**: someone can take funds they do not own, create value or reward, or permanently lock funds already shielded, at low cost; or privacy is broken for every user beyond what the page states.
- **High**: loss or permanent lock for some users; a way around the fee, the caps or screening; a cheap or lasting denial of deposits, activation, spends, the launch or fee flow; a minority that can block or capture the registry beyond what the page admits; theft or stranding of fees, pay, stakes or rewards at meaningful scale; a safety claim on the page that is false in a way that matters.
- **High if misread**: two reasonable builder readings exist and one of them is high or worse. Quote both passages.
- **Medium**: bounded loss, griefing that costs the attacker real money, weaker privacy for some users, small amounts stranded.
- **Low**: wrong or inconsistent numbers, wording, things that fail safe.

Do not inflate and do not pad. Every finding needs a concrete sequence of steps with numbers, the passage it rests on (quote it, with the line number in the text file), who can do it and at what cost, and what breaks. The page lists weaknesses it accepts (the risks table, the "Not fixed, and why" lists); restating one is not a finding unless it is worse than the page says. If you cannot make a suspicion concrete, put it under "Suspicions not made concrete". If something holds, say so under "What held" with the reasoning you used to attack it. That list matters as much as the findings.

### Deliverable

One markdown note under `/home/user/claude/research_notes/IMD swarm privacy project design/`:

- CORE: `adversarial_review_r45_core_v4.md`, finding ids `X-1`, `X-2`, …, commit message "Fifth review, circuit and pool: findings (in progress)"
- MECH: `adversarial_review_r45_mechanisms_v4.md`, finding ids `Y-1`, `Y-2`, …, commit message "Fifth review, registry, launch and fees: findings (in progress)"

This container has been restarted and cut off without warning many times: whatever is not in the file and committed is lost. Write the skeleton of the note within your first few minutes and commit it. Then commit after EVERY finding, and add "What held" items as you go, not at the end:

```
cd /home/user/claude && git add "<path of your note>" && git commit -q -m "<your commit message>" -- "<path of your note>" && git push -q origin claude/fervent-gauss-ujoati
```

Other processes commit to the same repository at the same time. If git reports a lock or the push is rejected, wait a few seconds and retry; never force-push, pull, rebase, reset, stash or touch any other file, and never create a pull request.

Structure of the note:

1. Header: what was reviewed (revision 4.5, text rendering, date), your area, and a three-line verdict: does it pass (no high and no high-if-misread finding), and how many findings at each severity.
2. Findings, most severe first. Each: severity; title; where (quote and line); how it works, step by step with numbers; who and cost; consequence; the smallest fix; confidence (certain, likely, or depends on reading).
3. Contradictions between sections (short table: passage A, passage B, which one a builder would follow).
4. Points a builder would have to guess.
5. What held.
6. Suspicions not made concrete, and what you did not check.

Write for a reader who knows crypto but is not a cryptographer: plain sentences, define a term when you first use it.

### Your final message

At most 350 words: the verdict, counts by severity, and one line for each critical, high and high-if-misread finding with its id. The detail belongs in the note, not in the message.

---

## Part for CORE: circuit, notes and pool

Your sections: "How a payment moves", "The pool", "How private rewards work", "Build specification" from "Conventions" through "Keys, notes and addresses", "The circuit" (public inputs, private inputs, constraints, what must be shown), contract 1 "Pool" and contract 2 "Verifier", "State machines", "Rules for the wallet and the relayer", "Size, gas and state pricing", "What operators can see", and the rows of "Parameters fixed in the build", "The defaults, as decided" and "Risks" that concern them. The pool's interface with the registry (`isApproved`, `isRefused`, `START`) is yours too.

New or changed in your area, where faults are most likely:

1. Every public input must be below the field modulus `p`, checked in the pool before verification and again in the verifier. Is the rule complete and stated everywhere it is needed? Is there another place where a 256-bit value and its reduction differ (`extHash`, `ownerCommit` at deposit, commitments, the leaf, `root`)?
2. The diversifier was removed: `ownerPk = H3(TAG_PK, spk, nk)`, one per wallet, one address per wallet. Check domain separation between the hashes now that one changed arity, what a payer, a recipient and an observer can link, and whether a wallet restored from its seed recovers and can spend everything under the stated derivations (deposits, change, reward notes, payments received, an output 0 the sender kept).
3. The window of 64 recent roots was removed. A proof names `rootCur` with `gCur` or `rootPrev` with `gPrev`. Walk the timing: activation, the first roll after `START`, a roll each hour, a quiet pool with no roll for days, a proof that lands after one or two rolls, a note spent the hour it was made. Can a user be locked out, and can anyone make proofs fail on purpose, for example by rolling at a chosen moment?
4. A `deadline` inside `extHash` and one comparison in `spend`.
5. A refund now falls back to `owed` like every other ETH payment; the pool requires enough gas before each payment; `claimOwed` clears before it sends; fee sweeps of ETH travel with `notify`. Check re-entrancy, the invariants that mention `owed`, and what a hostile depositor, recipient or relayer contract can do.
6. Lemma 11 was rewritten as a machine-checked statement with explicit integer hypotheses, and part D gained a matching contract property. Lemmas 3, 9 and 10 and parts B and C were reworded. Is anything in part A still not a property of a constraint system, false, vacuous, or too weak to exclude a broken circuit? Do the hypotheses of lemma 11 cover every honest spend the page lists, and nothing dishonest?
7. Weights were scaled by 10^6 (IMD 10^6, ETH about 8.07 × 10^8, USDT and USDC about 3.79 × 10^17), and the page gives new bounds for the reward index (2^55 on mainnet, 2^61 on the canary). Redo every bound that depends on a weight: the product in constraint 9 against the modulus, the 2^160 bound, the build bounds, `weighted` and `floor` in their uint128, the rounding of `g` per second.
8. The relay-fee ceiling is described differently (0.002 ETH plus about seven times the base-fee cost, eight times that for other assets, no daily limit, usable as a small second exit). Is the new description accurate everywhere on the page, including the summary sections and the risks?
9. Unused outputs and ciphertext 0 must look like used ones; accrued reward stays with the sender; ciphertext 1 now carries the asset.

As a minimum: treat every constraint as an equation over a prime field and ask what a malicious prover can choose. Then take each kind of honest spend the page lists (the canary list is a good catalogue) and check that the fifteen constraints and the contract's checks accept it, because a constraint that rejects an honest spend locks funds for good. Walk each Pool function against each invariant and each balance (`pending`, `shielded`, `fees`, `tokenIn`, `tokenOut`, `owed`, `released`). Redo the arithmetic the page gives with a script. Ask what a block builder, a relayer, a recipient contract, a token issuer or a depositor who never activates can do. For every place where the page admits two readings, say what happens under the worse one.

---

## Part for MECH: registry, launch, fees and canary

Your sections: "Screening" (with the example criteria file and its table of terms), "Token and fee" (the fee, the token, the public pool, the 20% auction and buyback), "Build specification" contracts 3 "ScreenerRegistry", 4 "FeeDistributor", 5 "Distribution" and 6 "Token", the deposit state machine as far as screening decides it, "Deployment and the canary", "Economics, simulated", and the rows of "Parameters fixed in the build", "The defaults, as decided" and "Risks" that concern them, plus the gas of `launch` and `apply` in "Size, gas and state pricing". The registry's interface with the pool and the distributor (`isApproved`, `isRefused`, `START`, `fund`, `fundable`, `notify`) is yours too.

The ScreenerRegistry was rewritten in this revision. Press on:

1. **One permanent record per epoch and the roll.** `epochs[e]` is written only during epoch `e`; the roll at the first call of an epoch folds `joining` into `activeCount` and writes the snapshot. Run it by hand and by script through: days with no call at all, the first call of a day being each of the functions in turn, `flag` and `signalCriteria` (which do not roll), a call before `GENESIS`, the first epoch ever, and years of silence. Is every field of the record defined in every case? Is the snapshot the set the criteria file says it is?
2. **`activeCount`, `joining` and ending a record.** Follow one record through register, activate, become active, commit, reveal, exit, evict, sale of the seat, registration by the buyer. Do the two counters always equal what the invariant says? Can a record be counted twice or not at all, and can the snapshot be made larger or smaller than the number of screeners able to reveal? What does a record that can never be ended look like, given that a record cannot be ended on a day it revealed and cannot exit on a day it committed?
3. **Settling.** Four steps: pay, silence, strikes, removal, said to visit at most seven epochs. Check the claim. Check each step against a screener that reveals every day, one that commits and never reveals, one that reveals a wrong hash, one that stops for six, seven and eight days, one that has just become active, and one whose `activeFrom` is in the future. Can pay be credited twice or lost? Can strikes be dodged (by not settling, by exiting, by selling the seat, by re-registering) or caused for others? What happens when settlement ends a record inside `commit`?
4. **Strikes.** +3 for a miss on a day with a majority hash, −1 for revealing it on a day with an accepted batch, removal at 21, and a 90-epoch bar that stays with the seat. The page claims a group under half can block for seven to ten days at a stretch and about one day in three after that. Simulate rotation, groups of 34% to 49.9%, exactly 50%, a registry of seven to fifteen, and a group that sacrifices members. Is "one day in three" right? Who else can be made to gain strikes?
5. **Pay fixed inside `apply`**, in the last four hours of the epoch: `pot`, `reserved`, `owed`, `accounted`, the 730 token shares, the remainder, `fund` (also for ETH), `withdrawPay`, and `fundable()` as used by the distributor's `notify`. Does every ledger close in every order of calls? What is stranded, and when? Who pays for `apply`, and what if nobody does?
6. **Flags from seats that are still waiting**, the two-step flag rule in the example criteria (a fifth of the snapshot and at least three hold a deposit until it is eight days old; more than half refuse), holds defined by a deposit's age, `fundedByListed`, "the file in force", a list that cannot be read. Is the batch still a deterministic function of chain data? What can a fifth of the seats, three seats in a small registry, or seats that are registered but not active do? Does the first batch ever now behave as the page says?
7. **The 21-day refund by others against the new hold and flag rules**, and the 96-word batch with at most 64 words that set a bit, including coverage moving backwards.
8. **Unchanged but worth one more pass**: the salt loop in `Distribution.launch()` and the claims about gas (about 42M under the draft rules, the room left for Uniswap's factory, the gas limit advice); `swarmPaid`; `collect()`; the stream accounting and `accounted` in the FeeDistributor; the auction and the buyback step; the canary's constants and its lists of lines.

As a minimum: write the registry as state and transitions in a script and run adversaries through it day by day, checking every listed invariant after every call. Walk every function of each contract against every invariant listed for it and against each balance it keeps. Redo the arithmetic the page gives. Ask what a block builder, the sender of the launch transaction, a seat buyer, IMD's bridge key, a stablecoin issuer or a data provider can do. For every place where the page admits two readings, say what happens under the worse one.
