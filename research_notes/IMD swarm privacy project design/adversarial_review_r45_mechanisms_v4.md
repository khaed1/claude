# Fifth adversarial review, mechanisms (registry, launch, fees, canary): Murmuration v4 specification, revision 4.5

Reviewer: MECH. Date: 2026-11-12.
Reviewed: the plain-text rendering `murmuration_spec_r45.txt` (1,732 lines), read in full. No earlier review note and no other file in the repository was opened.
Area: "Screening", "Token and fee", contracts 3 ScreenerRegistry, 4 FeeDistributor, 5 Distribution and 6 Token, the deposit state machine as far as screening decides it, "Deployment and the canary", "Economics, simulated", the related rows of the parameter, defaults and risk tables, and the gas of `launch` and `apply`.
Scripts: `/tmp/claude-0/-home-user-claude/29945ecd-c0f3-5435-9820-8daff0f0ffe0/scratchpad/review_r45/mech/` (`clear_starve.py`, `registry_model.py`, others named in the findings).

## Verdict

PROVISIONAL (the note is committed finding by finding; this block is updated as it grows).

- Pass (no high and no high-if-misread finding): **No.** Revision 4.5 does not pass in this area.
- Counts so far: critical 0, high 3, high if misread 1, medium 1, low 4.
- The three high findings are all in what revision 4.5 added: the 64/32 split of batch words, the "file in force" rule, and the silence rule inside settlement.

## 1. Findings, most severe first

### Y-1. High. Clearing can still be starved: a fifth of the seats can keep any deposit refused until it can be thrown out, which the page says only a majority can do

**Where.**

- Line 848 to 850: "At most 96 words, of which at most 64 set a bit, so that at least 32 places are always left for clearing. If more than 64 words set a bit, the batch lists the first 64 of them and lowers upTo to just below the first deposit of the first one left out. Words that only clear bits and do not fit wait for the next day."
- Line 847: "Words that set a bit come first, then words that only clear bits, each group in ascending order."
- Line 199: "In the registry a hold is an ordinary refusal bit, cleared by the first batch after it ends".
- Line 188: `{ "hold": "flags(deposit) >= a fifth of the snapshot, and at least 3", "untilAgeDays": 8 }`.
- Claims it breaks: line 210 "A fifth can delay any deposit by about a week, once. Only a majority can refuse."; line 584 "Clearing can no longer be starved."; line 538 "A batch sets bits in at most 64 words, so 32 are left for clearing."

**The fault.** A hold is lifted only when a batch lists the deposit's word. Words that only clear get what is left of 96 after the words that set a bit, and that is as little as 32 a day. Nothing limits how many words need clearing on a day. Whoever makes more than 48 words a day need a set and, eight days later, a clear, makes the queue of clears grow without end (demand `A` a day against `96 − min(A, 64)` places; at `A = 64` the queue grows by 32 words a day). The queue is served in ascending order, so a deposit waits behind every older word.

A word is 256 deposit ids. Ids are cheap: a deposit that is refunded in the same transaction still uses an id.

**Steps, with numbers.** The attacker holds a fifth of the snapshot and at least three seats (three seats in a registry of 7 to 15).

1. Every day a contract of the attacker makes 16,384 ETH deposits of the smallest size (0.005 ETH) and refunds all but 64 of them at once: one stays open in each of 64 consecutive words. About 50,000 to 85,000 gas for each deposit and refund pair, so 0.8 to 1.4 billion gas a day: about $105 to $180 a day at the 0.06 gwei median base fee the page quotes, $350 to $600 at its 0.2 gwei planning price. Capital: 0.32 ETH a day of open dust, refundable later.
2. The attacker's seats flag those 64 deposits (64 flags per seat per day, about 25,000 gas each). Under the published rule each is held until it is eight days old. Two days after it is made, its word needs a set: 64 set-words every day, which is the whole allowance. Eight days after, its word needs a clear: 64 clear-only words every day against 32 places.
3. The same seats flag every deposit they want kept out. Each is held until eight days old, as the page admits. Its word then needs a clear and stands in the queue behind all older words.
4. `clear_starve.py` runs the rule as written. With 64 words a day, a deposit made on day `t` of the attack has its bit cleared at age `8 + t` days: age 13 for day 5, 18 for day 10, 21 to 22 for day 13, 28 for day 20, and deposits made from day 30 on were still not cleared when the 60-day run ended. The backlog after 60 days is 1,664 words.
5. From day 13 on, every flagged deposit is still refused when it turns 21 days old, so anyone can send it back (line 752: "Anyone, once the deposit is at least 21 days old param and `Registry.isRefused(id, depositTime)`"). It could never be activated in between, because `isApproved` needs the bit clear.

**Who and cost.** A fifth of the active seats and at least three (about 2.1 ETH of resalable seats and three stakes in a registry of 15), plus roughly $100 to $600 a day of gas, plus two weeks of the same to build the queue. Somebody else pays for `apply` each day. Without seats the same queue can be built with the "more than 10 ETH and freshly funded" hold, at 640 ETH of new refundable deposits a day, and it then stretches every other hold in the pool (large fresh deposits, `fundedByListed`) past 21 days: that is the depositor of "about a thousand ETH" in line 584, with the result line 584 denies.

**Consequence.** A fifth of the registry has a lasting power of refusal over any deposit it names, and so over who may enter and who earns the users' 45%: it does not flag its own deposits. The page gives that power to a majority only, and its whole two-step flag rule rests on the difference. The forced refund at 21 days turns each stretched hold into a bounce. Stopping the attack does not clear the queue: 1,664 words at 32 a day is another 52 days.

**Smallest fix.** Stop relying on a later batch to lift a hold. For example keep holds in a second bitmap that `isApproved` and `isRefused` ignore once `depositTime + 14 days ≤ dataTime` (the page already says no file may hold past 14 days), so that a hold lapses in the contract by the deposit's age and never needs a clearing word. The page rejected a second bitmap in "Not fixed, and why" on the ground that "the age rule on refunds and the rule that refusals are listed first do the same work with less"; they do not. Giving clears priority instead would only move the starvation to the sets, which fails open.

**Confidence.** Certain for the queue (it is arithmetic on lines 847 to 850, and the script follows them). Likely for the cost: the gas of a deposit and refund pair is taken from the page's own table.

### Y-2. High. One seat that is alone in the snapshot for one day fixes the criteria file for everybody, for good

**Where.**

- Line 202: "The file in force | The last file whose hash more than two thirds of the snapshot's seats had signalled at a base block, counting each seat's latest signal made under its present record. It stays in force until another file reaches two thirds, whoever joins or leaves in between. Until any file has, the file named in the parameter file".
- Line 211: "Nodes adopt a new file when more than two thirds of the screeners have signalled its hash, and keep it until another file reaches two thirds. Nobody coordinates this: it is a rule in the node software, and the registry sees only batch hashes."
- Line 845: "The snapshot of epoch e is the set of records whose activeFrom is not zero and at most e at the base block."
- Line 830: `signalCriteria` can be called by "the operator of a registered seat, active or still waiting".

**The fault.** A batch needs a snapshot of at least seven. The rule that chooses the criteria file has no minimum and no memory of how large the snapshot was. Two thirds of a snapshot of one is one seat. And the choice is sticky: it survives the seats that made it being outnumbered or leaving.

**Steps.**

1. The attacker registers one seat in an epoch in which nobody else registers. The easy case is the launch: `launch()` is open to anyone, the sender "can also be the first buyer in the same transaction" (line 1039), and can register in it too. Sent in the last minutes of an epoch, it leaves nobody else time to buy a stake and register in that epoch. Any later moment at which the attacker's seats are more than two thirds of the snapshot works as well: five seats of seven on the first active day, or the largest holder's 77 seats registered on day 0 against fewer than 39 others.
2. While waiting, the seat signals the hash of file X. On its first active day the snapshot is that one seat. More than two thirds of the snapshot has signalled X at that base block, so X is the file in force.
3. A day later the honest seats become active. Their nodes follow line 211: X stays in force "until another file reaches two thirds, whoever joins or leaves in between". They compute, commit and reveal batches under X, and those batches are accepted with honest reveals. The attacker's seat can exit.
4. X can be anything the file format allows. `"rules": [ { "allow": "default" } ]` switches screening off. A list whose source is `eth_call` to a contract of the attacker's (the format of line 182) lets the attacker refuse or admit any depositor, changing its mind block by block, with every honest node agreeing on the result. A file whose content is never published, or whose list source reverts, cannot be computed at all, and then "a node commits nothing" (line 196), which after seven days is Y-3.

**Who and cost.** One seat (0.70 ETH, resalable) and one stake (about $38), at the right moment. Undoing it needs more than two thirds of a later snapshot to signal another file by hand. The page's own premise (line 210) is that most seats "only run the program" and do nothing by hand.

**Consequence.** Lasting control of who may enter, or screening switched off, or the registry stopped, by a party the page would call no minority at all. The page prices capture at "a majority for a week" (line 139) and "two thirds" to approve (line 216). The first version of this design was rejected because "one third" could switch screening off; this is one seat. It also means the batch is not a function of chain data alone: it depends on whether each node can obtain the content behind a hash that seats signalled.

**Smallest fix.** Count a file as in force only while more than two thirds of the current snapshot signal it and the snapshot is at least seven, and fall back to the file named in the parameter file otherwise. That removes the stickiness and the small-snapshot case together. A node should also refuse to adopt a file it cannot fetch and parse, and treat "cannot compute" as in Y-3's fix.

**Confidence.** Likely. The rule is quoted and has no minimum. What node software would add on its own is not on the page, and line 211 says nobody coordinates.

### Y-3. High. A week in which honest nodes cannot compute a batch removes and bars every screener; the page says batches "stop until" a new file is signalled

**Where.**

- Line 858: "Silence. Take the later of the record's last reveal epoch and the epoch before `activeFrom`. If seven or more whole epochs have passed since then, the record is ended and the seat is barred."
- Line 862: "Barring sets `barredUntil` to the current epoch plus 90".
- Line 821, `commit`: "Settles the record. If that ended it, nothing is committed." Line 824, `settle`: "Anyone".
- Line 196: "If a list's source cannot be read there, no batch can be computed under this file and a node commits nothing. A retired oracle therefore stops batches until two thirds of the seats signal a file without it".
- Line 179: the base block counts "once it is finalized".

**The fault.** The silence rule does not ask why a screener did not reveal, or whether anybody could have. It counts epochs with no majority hash, and epochs with no record at all, the same as epochs in which the screener hid. So any week in which the honest program has nothing to commit ends every record at its next settlement, with a 90-day bar on the seat.

**Steps.**

1. The sanctions oracle named in the example file is retired by its owner, or the file in force cannot be read (Y-2), or the base block is not finalized inside the 12-hour commit window for seven days running, or a release of the node software fails for a week. Honest nodes do what line 196 says: they commit nothing.
2. Two thirds of the seats must now signal a new file by hand. If that takes until the eighth day, it is too late.
3. On day eight anyone calls `settle(seatId)` for every seat. Each record's last reveal is seven whole epochs back, so each is ended and its seat barred for 90 epochs. If nobody does, each screener does it to itself: its next `commit` settles first, ends the record, and commits nothing.
4. The registry is empty. The same seats cannot register for 90 days and then wait 30 more. Other seats can register and wait 30. Until seven are active nothing can be activated, the pot waits, and after seven days without a batch the screeners' 40% goes to stakers.

**Who and cost.** The owner of a list source, at no cost; whoever can put an unreadable file in force (one seat, by Y-2); or nobody at all, when two thirds of the seats do not act by hand within a week. The same rule also bars the seats of early registrants who see no point in paying gas to commit while the snapshot is still under seven, which is every seat in the weeks before the seventh one arrives, on the canary as well.

**Consequence.** A pause that the page describes as lasting "until two thirds of the seats signal" becomes a stop of at least 31 days and the loss of every screening seat for 120. Activation stops for that time. Nothing already shielded is touched.

**Smallest fix.** Count silence only over epochs that have a majority hash (the same test the strike rule uses), or have the node commit and reveal a fixed "no batch" hash when it cannot compute, and say so in the criteria rules. Either keeps an honest screener alive through a week in which nobody could screen.

**Confidence.** Certain for the mechanism (lines 858 and 196 together). The trigger is an outside event or Y-2.

### Y-4. High if misread. The silence step is not defined for a record that is still waiting, and the two natural ways to code it are both bad

**Where.**

- Line 809: "`activeFrom` (zero until `activate` is called)".
- Line 858: "Take the later of the record's last reveal epoch and the epoch before `activeFrom`. If seven or more whole epochs have passed since then, the record is ended and the seat is barred."
- Line 855: settling is "Done at the start of `commit`, `requestExit` and `evict`, and by `settle`", and `settle` and `evict` are open to anyone.
- Against it, line 1061 expects "a screener that exits before it becomes active", and line 819 tells a buyer of a seat with an old record to call `evict` first.

**Reading A, the literal one with a guard.** For a waiting record `activeFrom` is 0 and it has never revealed. "The epoch before `activeFrom`" is taken as epoch 0, or the last reveal epoch's default of 0 wins. Then "seven or more whole epochs have passed" is true from epoch 8 after `GENESIS` on, for every waiting record. Anyone calls `settle(seatId)` on each newly registered seat: the record is ended and the seat barred for 90 epochs. No seat ever completes its 30 days. The registry never has seven active screeners, `START` is never set, and nothing is ever activated. Cost: one transaction per registration. A holder who calls `requestExit` while waiting, and a buyer who calls `evict` on a waiting record as line 819 tells them to, bar their own seat the same way.

**Reading B, checked arithmetic.** `activeFrom − 1` underflows and reverts. `settle`, `requestExit` and `evict` then revert for every waiting record. A holder cannot leave during the 30 days. If a seat with a waiting record is sold, the record can never be ended: the old holder cannot `activate` (the seat is no longer theirs) and cannot exit, and the buyer's `evict` reverts. The stake is locked for good and the seat can never be registered again. The same subtraction also underflows on the day `activate` is called (`activeFrom` is tomorrow) and, in "epochs passed", for a record that revealed today.

**What is probably meant.** Steps 2 and 3 apply only to a record whose `activeFrom` is not zero and at most the current epoch. The page does not say so. A builder who "stops and asks" gets it right; one who makes the revert go away with the obvious guard gets reading A.

**Smallest fix.** One sentence in Settling: a record that is not yet active is settled by step 1 and by setting `settledThrough`, and by nothing else. And write the comparison as `current epoch ≥ reference + 8` so that no subtraction can underflow.

**Confidence.** Depends on reading.

### Y-5. Medium. "One day in three" holds for a fixed group only; a holder with spare seats blocks more than half of all days, or all of them

**Where.** Line 864: "After that the group has been removed or has to let batches through, and over time it can block at most about one day in three". Line 139 and the risk row at line 1633 repeat it. Line 853: "The current epoch's snapshot is not touched".

**What holds.** For a group that cannot replace its members the figures on the page are right. `strikes.py` gives 25.2% of days for 11 of 30, 30.0% for 14 of 30, 33.1% for 50 of 101, and first stretches of 7 to 10 days when members are sacrificed. The closed form is `B / (B + 3W)` for a group of `B` in which `W` must withhold.

**What does not.** The bound is per active seat, and seats that are waiting or barred are not in the snapshot. A holder runs them in shifts.

1. Fifteen honest screeners. Eight hostile seats make the snapshot 23, and two thirds of 23 rounded up is 16, so eight silent seats block every batch.
2. A shift blocks for seven days and reaches 21 strikes. Its removal is at the settlement on day eight, after that day's snapshot was taken, so day eight is blocked as well: eight days a shift.
3. The seats are barred for 90 epochs, register again, wait 30 and are active on the next day: back after about 129 days.
4. The next shift registered a week later. Seventeen shifts, 136 seats, block every day for ever. The 77 seats of the largest holder (line 1691) are nine shifts: 72 blocked days in every 129, or 56%. The top five holders have 243 seats.

A smaller version of the same thing: a member that does not commit on a day its group blocks can call `requestExit` that same day. Settlement "looks at past epochs only" (line 855), the snapshot still counts the seat, and the day's miss is never charged.

**Who and cost.** Seats are resalable, about 0.70 ETH each, and stakes come back. The honest side can answer only by adding seats, 31 days later, and each one raises the size of a shift.

**Consequence.** Lost days beyond what the page tells the owner to expect, for as long as the holder likes. Nothing shielded is touched.

**Smallest fix.** State the bound as what it is, a bound on a fixed set of seats. If more is wanted: take a removed seat out of the current snapshot when it is removed for strikes, and make the bar grow with each removal of the same seat.

**Confidence.** Certain.

### Y-6. Low. A hold bit outlives its hold whenever no batch is applied, and after a 13-day stop every held deposit can be bounced

**Where.** Line 199: "A hold ends with the deposit's age and with nothing else: a day without a batch does not stretch it". Same line: "In the registry a hold is an ordinary refusal bit, cleared by the first batch after it ends". Line 752: others may refund when the deposit "is at least 21 days old" and is refused now. Line 1443: the 21 days "must stay longer than the longest hold and the life of a flag".

**How.** The first sentence is true of the criteria and false of the contract. A deposit held at age 7 keeps its bit until some batch is applied. If none is applied for 13 days it is 21 days old and still refused, and anyone can send it back. Thirteen days without a batch is reachable without Y-1: an even split (line 864, "a deadlock"), a registry of seven that loses one member (30 days, line 214), or the removal of a blocking third from a registry of seven to ten (line 580). With a file that holds to the 14 days line 204 allows, seven days are enough, which is inside the "seven to ten days" one blockade lasts.

**Consequence.** Forced refunds of deposits whose hold ended days earlier. The depositor loses the place and the gas and nothing else, so this fails safe. It is the fourth review's Q-9 again in a narrower form, and the page says it is fixed.

**Smallest fix.** The same as Y-1: let a hold lapse in the contract by the deposit's age.

**Confidence.** Certain.

### Y-7. Low. `fundable()` says "commits are still open", which has two meanings on the page

**Where.** Line 833: "True when a batch was applied in the current epoch or one of the seven before it, and commits are still open". Line 821, `commit`: "in the commit window | Requires commits to be open". Line 868: "Commits are open until 30 epochs param after the deposit window closes". Line 802: "Commit runs from hour 0 up to hour 12".

**How.** Line 868 is clearly what is meant. A builder who writes one helper for "can a commit be made now" and uses it in both places makes `fundable()` false every day from hour 12. `sweepFees` is open to anyone once a day, so a staker sweeps each afternoon and the screeners' 40% goes to stakers every day. The canary's line "the pay each screener receives" would show it only if its sweeps happened to fall in the afternoon.

The same sentence also disagrees with itself on the count: "the current epoch or one of the seven before it" is eight epochs, line 902 says "within the last seven epochs", line 248 "within the last seven days".

**Smallest fix.** Give the lifetime test its own name, for example "screening has not ended", and one number.

**Confidence.** Depends on reading.

### Y-8. Low. A seat sold while active collects strikes, and after a week a 90-day bar, for days on which nobody could commit for it

**Where.** Line 821: a commit needs "a seat still held by the registered holder". Line 826: `evict` "Settles, which ends and bars a record that is silent or has 21 strikes. If the record is still there and its holder no longer owns the seat, ends it without a bar". Line 810: strikes and the bar belong to the seat.

**How.** After a transfer the old record stays in the snapshot and cannot commit. When the buyer calls `evict`, as line 819 tells them to, settlement runs first: three strikes for each day since the sale that had a majority hash, and if the last reveal is seven epochs back, the record is ended as silent and the buyer's seat is barred for 90 epochs. The order of the two sentences in `evict` decides it, and it is the wrong way round for a seat that was sold. A seller who calls `requestExit` before selling avoids all of it; nothing tells them to.

**Smallest fix.** In `evict`, test ownership before settling strikes and silence, or do not count epochs after the holder stopped owning the seat (the contract cannot know when that was, so the first is the practical one).

**Confidence.** Certain.

### Y-9. Low. The operator key cannot be changed, and an operator can keep a holder from leaving

**Where.** Line 819: `register(seatId, operator)`. No function changes the operator. Line 825: `requestExit` "Reverts if the record has committed or revealed in the current epoch".

**How.** A holder whose operator key is lost has to exit, wait out nothing for the seat but 14 days for the stake, register again and wait 30 days. A holder whose operator is hostile or compromised cannot exit on any day the operator commits in the first block of the epoch, while the operator collects strikes on the seat by never revealing: seven days later the seat is barred. The holder's way out is to move the seat to another address and call `evict`, which nothing on the page mentions.

**Smallest fix.** `setOperator(seatId, operator)` for the holder.

**Confidence.** Certain.

## 2. Contradictions between sections

| Passage A | Passage B | Which one a builder would follow |
|---|---|---|
| Line 584: "Clearing can no longer be starved." | Lines 848 to 850: clear-only words get what is left of 96 after up to 64 set-words, and wait otherwise | B, which is the rule. See Y-1 |
| Line 196: a retired oracle "stops batches until two thirds of the seats signal a file without it" | Line 858: seven epochs without a reveal end the record and bar the seat | B. After a week there is no registry to resume. See Y-3 |
| Line 210: "Only a majority can refuse." | Lines 199 and 848 to 850 with the refund rule of line 752 | The contract and the batch rule. A fifth can refuse. See Y-1 |
| Line 199: "a day without a batch does not stretch it" | Same line: the bit is "cleared by the first batch after it ends" | The second. See Y-6 |
| Line 864, 139, 1633: a minority blocks "at most about one day in three" | Lines 853 and 862: a removed seat stays in that day's snapshot and returns after 90 + 31 days; other seats of the same holder take its place | The mechanism. See Y-5 |
| Line 833: batch applied "in the current epoch or one of the seven before it" (eight epochs) | Line 902: "within the last seven epochs"; line 248: "within the last seven days" | Unclear. One number is needed |
| Line 1433, a current row: "The cost is a wait of one and a half to three days" | Lines 974 and 1403: "between 44 hours and three days" | 44 hours. The row kept the figure from before apply moved to the last four hours |
| Line 1039: "The first batch can be applied about 33 days after launch" (also lines 974, 1086, 1139) | Line 820: active "no sooner than 31 epochs after registering", and apply opens at hour 20 | A seat registered on launch day can see the first batch 31 days and 20 hours after launch. The page's 33 is safe for the tables and wrong as a bound |
| Line 269 and the tables: a valuation of 48,000 IMD and 12,000 × f / (1 − f) | Line 925: "The starting tick is the starting price rounded down to the pool's tick spacing of 200" | The tick. It is −99,600, a valuation of 47,276 IMD, 1.5% under every figure on the page |
| Line 853: "A record cannot be ended in an epoch in which it has revealed" | Line 824: `settle` is open to anyone and has no such guard | No conflict in fact: after the day's commit has settled, a second settlement cannot find new strikes. Worth one sentence on the page |

## 3. Points a builder would have to guess

1. What settlement does with a record whose `activeFrom` is zero or in the future (Y-4).
2. The first value of `accounted` for the token. Line 816 counts "the unpaid part of the 15%" in it, and the 15% arrives by a plain transfer at launch, with no call. If `accounted` starts at zero, the first `fund` for the token takes the whole 15% for "what arrived", puts it in the pot, and the next applied batch pays it out to that day's revealers. The stakes then cover the daily shares. The page should say that it starts at 15% of supply.
3. The first value of `settledThrough` at registration, and of `rolledEpoch` before the first roll. Epoch 0 is a real epoch, and the pool's `window` has a stated "none" value where the registry's fields have not.
4. Whether "Before `GENESIS` every function reverts" (line 800) includes the views. If `fundable()`, `isApproved` and the getter of `START` revert, the pool's `roll`, which "can never revert", reverts before `GENESIS`. Harmless, and still a sentence that is not true as written.
5. Whether a node commits and reveals when no batch can be accepted, for example while the snapshot is under seven. Under the silence rule the answer decides whether early registrants are barred (Y-3).
6. Whether a flag can name a deposit id that does not exist yet. `flag` stores nothing and checks nothing, and line 197 counts flags "in the last 14 epochs". If it can, a fifth of the seats holds every future deposit with one sweep of flags a fortnight.
7. What a listed word writes for the bits of deposits above `upTo`, and whether a word that straddles `upTo` can be listed at all.
8. How a node obtains the content of a criteria file from its hash, and what it does when it cannot (Y-2, Y-3).
9. The `from` address, gas limit and block context of the `eth_call` that reads a list. A list contract can answer differently for different callers or gas, which splits honest nodes and earns the smaller side strikes.
10. Whether the pool is initialised at the price of the starting tick or at the starting price. Only the first lets a position that holds no IMD be placed.
11. How `withdrawPay` and `withdrawStake` send ETH and tokens, and what a failed transfer does. The pool has a written rule for every payment; the registry has none.
12. Whether `activate` may be called by a third party for a seat ("The holder or operator") and whether `register` checks that the operator is not zero.
13. What "commits are still open" means in `fundable()` (Y-7).

## 4. What held

Each item says how it was attacked.

1. **The two counters.** `activeCount` and `joining` were checked against their definitions after every call in 400 random runs of 300 days (`fuzz2.py` on `registry_model.py`): 30 seats moving between 10 wallets, register, activate, commit, reveal, exit, evict, settle, sale and registration by the buyer, the first call of a day being any of them, and stretches of up to ten days with no call. 30,579 applied epochs, no mismatch. `activate` cannot be used twice, a record that leaves while joining lowers `joining`, and the roll after any gap folds `joining` correctly because every ending is preceded by a roll in the same call.
2. **The snapshot is the set the criteria file names.** Nothing changes registry storage between the base block and the first call of the epoch, because `flag` and `signalCriteria` store nothing and every other function rolls first. So `epochs[e].snap` equals the number of records with `activeFrom` between 1 and `e` at the base block. It can be larger than the number of screeners able to reveal (sold seats, silent seats nobody has evicted, records ended earlier the same day), never smaller.
3. **Pay.** In the same runs: the registry's balance equals pot + reserved + owed + stakes + unbonding + the unpaid 15% after every call; no record is credited twice for one epoch; and after settling every live record `reserved` is zero, so no revealer's pay is lost. A record cannot be ended between its reveal and `apply`: `evict` and `requestExit` revert, and a second settlement on that day cannot reach 21 strikes. The remainder of each division stays in the pot. The number of revealers is at least five, so nothing divides by zero.
4. **"No settlement visits more than seven epochs."** True, under the reading that a waiting record is skipped. The largest count in the runs was seven. A commit settles through yesterday, a reveal needs a commit, and the silence test runs before the loop.
5. **The strike figures for a fixed group.** `strikes.py`: 25% for a bare third at every registry size from 7 to 101, 30% for 14 of 30, 33% for 50 of 101 and 499 of 1,000, first stretches of 7 to 10 days. A group under half cannot make a majority hash, so it cannot give strikes to anyone else. Selling the seat, exiting and registering again do not shed strikes. A commit followed by no reveal, a wrong reveal and plain silence all cost the same three.
6. **Coverage cannot be held back for ever with holds.** More than 64 words that set a bit lower `upTo`, but a hold can set a bit only on a deposit younger than its limit. Words older than eight days stop needing a set and coverage passes them. The lag is bounded by the length of the hold, which is the delay the page already gives a fifth. (Clearing is another matter: Y-1.)
7. **The first batch can refuse.** A seat that is waiting can flag, and the flag counts once the seat is in the snapshot, if it was posted in the last 14 epochs. For a deposit of the first weeks that means posting it again shortly before the first batch, and it takes a majority, because the hold by a fifth reaches only deposits under eight days old. That is the same as in steady state, so the claim stands.
8. **Timing.** 44 hours to three days from deposit to activation, and one to two days for a flag or a list to count, both follow from the windows.
9. **One accepted hash per epoch**, since two hashes cannot both have two thirds of one snapshot. Commitments cannot be copied: they include the seat id and a salt.
10. **The launch loop.** A candidate depends on the block's randomness and the caller, so pools created in earlier blocks are for other candidates, and at most about 13 can be created ahead of the launch in its own block against some 211 usable candidates. 82.5% of addresses sort below `0xd34a…`. The launch transaction's sender can buy first and register first; it cannot do worse to the token or the position.
11. **Launch and `apply` gas, as arithmetic.** 22,142 bytes of pool code, about 3,000 of token code, two accounts and two dozen slots come to 41.2M of state gas under the draft rules. 96 new words cost 2.12M today and 10.56M under the draft rules, 1.16M of it execution gas. Not measured, as the page says.
12. **The range and the tables.** 12,000 × f / (1 − f), the stake prices (14.4, 18.6, 29.3, 89.7, 558), 220 IMD for fifteen stakes and 1,222 for 77, every row of the unlock table, the fee tables, $26 and $5 a day for screeners, and 510 tokens per ETH per day were all reproduced.
13. **`swarmPaid`, `claimFounder`, `collect`.** A list that adds up to more than 10% stops at 10%. `collect` burns only what the pool returned in the call. No path lowers the position's liquidity.
14. **The staker stream.** With the scales given, the largest products stay far under 2^256 even for the token as the fee asset and one base unit staked, and each update loses under one base unit. Daily sweeps turn the seven-day line into a decay of one seventh a day, which the page states.
15. **The distributor's 40%.** With the seven-day test, a blocked day no longer moves that day's fees to stakers. Fees swept during a stop of more than a week do go to stakers, as line 248 says.
16. **Capture cannot move funds.** Nothing in the registry reaches the pool, and no batch can decide a deposit younger than a day at the start of its epoch, whatever `upTo` and the words say.

## 5. Suspicions not made concrete, and what was not checked

- **A listed depositor can stall coverage where a hold cannot.** `deny: listed(depositor)` has no age limit, so a sanctioned address that keeps one open dust deposit in each of more than 64 new words a day would hold `upTo` back for ever. It needs the cooperation of a key on the list, so it is not written up as a finding.
- **Software versions.** Two versions of the screening program that differ on one corner case split the registry, and the smaller side gains three strikes a day. Nobody will want to upgrade first. The page versions the criteria file and says nothing about the program.
- **Flash-borrowed seats.** `register`, `activate`, `commit` and `reveal` each test ownership at one instant. A seat lent for one transaction at a time could back a record its holder does not keep. Anyone can evict such a record between loans, which is why this is a suspicion only.
- **`evict` and "a seat call that reverts counts as not held".** If the same rule applies in `evict`, a seat contract whose `ownerOf` fails ends every record. The seat contract is said to have no key; I did not read it.
- **The gas that reaches Uniswap's factory under the draft rules**, the "1.6M to spare", and whether state gas is refunded when a deposit record is created and cleared in one transaction (it changes the cost of Y-1 under Glamsterdam by a factor of two or three). Not checked: it needs the text of EIP-8037.
- **The buyback and the auction** were read against their invariants and not simulated again. The fourth review's result is taken as it stands.
- **The Chainalysis oracle's interface** and whether its owner can in fact make it unreadable were not checked. Line 338 of the page says the owner "can change or retire it".
- **The canary's lines** were read for reachability within 90 days at the stated caps (they are reachable) and not for completeness against every function.
