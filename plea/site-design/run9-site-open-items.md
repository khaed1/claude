# PLEA run 9 site: open items after round 2

What is still wrong in the run 9 site after IMD's round-2 fix job `cd805c00` (launch-2234 repository, commit `b214b52`, https://plea-test-run-9.sites.imd.fun/). Found by the round-2 re-test on 2026-10-21: four section checkers (T, C, S, X) and a diff reviewer, each followed by a skeptic who re-checked every not-fixed claim, tried to break the fixed P1 items and confirmed or refuted every new issue (none was refuted). Item refs (T1, C2, …) are the round-2 file's, `run9-site-review-2.md`; round-1 refs are `run9-site-review.md`'s. Evidence names (screenshots, JSON) refer to the testers' work folders, which were not kept.

Status: of the 45 round-2 items, 31 fixed and 14 partly; the round-1 fixes still hold (51 of 52; WW9 regressed); IMD's own review recorded two medium bugs (IMD4, IMD5), both real; 48 new issues (9 medium, 19 low, 20 nit). A dry run of the run 9 live-test script on a fork worked end to end through the site, with the traps below.

## Traps found in the live-test dry run

1. Letters need about 1.44M PLEA or more (FeeTooHigh caps the fees at 10% of the balance). A wallet that bought ~10 imdTEST inside the 90-minute launch window holds ~0.6M PLEA; the site still lets it press Send letter, then fails with wrong advice (r2D-N4).
2. The default-on auto-sell box blocks Submit on Plead and Appeal for small wallets (the reason does say to untick it).
3. The fixed imdTEST fees (0.50 plea fee, 0.85 objection fee + stake) are not checked against the balance before the approval (r2D-VN1).
4. A confirmed transaction can be reported as failed ("Nothing was sent") when the follow-up reads fail or the receipt wait times out (r2D-N2).
5. An objection with no answer after 20 minutes still reads "pending … points held" until someone presses "Expire unanswered objection" (IMD5).
6. Phones: a browser that announces a wallet only through EIP-6963 gets only "Open in …" links (IMD4).
7. The runner who delivers someone's auto-sell or letter plea gets the writer's "sold for you" toast (r2D-N1); plea, objection and letter toasts show two "Open plea #N" links (r2D-N3).

## Round-2 items still partly fixed

### C2 (P1) Sale panel: a sustained plea is told its points count, and the objection, sustained, overturned and upheld blocks are missing

- **Checker:** Matters today only if an objection is sustained on an unsold plea, or the owner pleads and lets it lapse.
- **Skeptic:** Checked on my own fork (8546, 12 players, pleas #1-#12), with api.imd.fun mocked (agreed 26, a comment). Two things are still wrong.
(1) UPHELD: plea #2 is p7's appeal of #1, denied again. Its sale panel reads only '#1 was denied, 21 vs need 37, at 12:32 UTC. The appeal scored 20 at 12:32 UTC: denied again. No further appeal. The 4-hour cooldown ran from this verdict, until 16:32 UTC.' The C4 judge line is not there, although the oracle data had loaded: 'The judges' panel on the same page shows 'Judged by 30 · 26 agreed · 1s · A judge said: …'. The UPHELD branch (pages-court.tsx:1920-1927) never renders it, while plea.html's UPHELD band ends with 'Judged by 30 · 24 agreed · 4m 20s. A judge said: …'.
(2) The page lead still contradicts the panel below it (confirmed as r2C-N1). An excluded seller's lapsed plea is still told its points count, which is this item's own fault. Owner A's lapsed #10 has the lead 'The approval lapsed unsold; its points still count.', next to 'This seller is excluded from season points.' and 'No points'.
What works, checked independently:
- Sustained and lapsed #8, with a named objector: 'Objection #3 by lynx_judge: a second panel re-scored it 30 (26 of 30 agreed). The first panel gave 40. / No points for this plea. Nothing was sold. / The objector’s 0.35 imdTEST stake goes back when anyone calls settle.'
- Sold with a pending objection, #7: 'Objection #1 by kafka_cat:' + text + '+42 points held until the second panel rules. Sustained if the new score is 34 or less (more than 2 below the need 37). The sale stands either way: 806,870 PLEA sold for 4.80 imdTEST at 13:32 UTC.'
- Sold, with one objection pending and the second sustained, #9: the sustained block with 'The sale stands: 345,110 PLEA sold for 2.05 imdTEST at 13:33 UTC.'
- Sell-window note for sustained #8 and excluded #10: '…Miss it and the plea lapses.'
- LAPSED, excluded #10: 'This seller is excluded from season points.'
Evidence in r2C-verify/: s1.json (p2-upheld, p7-seller, p9-visitor, p8-seller) and s2.json (p8-lapsed-seller, p10-lapsed); screenshots shots/s1-p2-upheld.png, shots/s2-p10-lapsed.png, shots/crop-p8-lapsed-top.png.

### S1 (P1) Only one waiting season is shown, the rollover note names the wrong season, and the seat panel renders twice

- **Checker:** The intermediate details sit inside the oldest season's section. That works, but nothing heads the displayed season's own block.
- **Skeptic:** Independent attempt on my own fork (8547, forked from rpc.sepolia.ethpandaops.io, an archive node, so it does not decay). Seeded at T0=1792583120. Seasons 1 and 2 had ended unclosed and season 3 was running. Pages loaded as p13 at 768 light and p10 at 1280 dark, with the details open. Most of the item holds. The wait line reads 'Seasons 1 to 2 wait to be closed, oldest first.' There is one #seat (SECTION.panel aria-labelledby=seat-title). Ended blocks use h3. The pot notes read 'Plus what season 1 rolls over at its close.' (season 2) and '…season 2…' (season 3). Home at 768 reads '…; season 3 ends in 4h 48m; plus what season 2 rolls over at its close' (out/home-768.json). p10's lapsed approved #9 is listed and its Record button sits in the details; lapsed pleas are recordable, since gate.result treats Lapsed as approved. BROKEN: the details summary also lists a plea that cannot be recorded. As p13 it reads 'Season 2 ended · Awaiting close · pot 0.02 imdTEST · your plea #8 to record'. #8 had objection #2 sustained: Tribunal.standing(8) = (false, true, 30), and record(8) reverts ObjectionSustained(8) (cast call). The opened SeasonView(2) for the same wallet says 'No approved plea of yours is recorded in season 2 … Write a plea', with no Record button. Cause: WaitingSeason (seasons.tsx:105-160) keeps every approved, unrecorded own plea and never applies the sustained or excluded filter that SeasonBody's own list uses (!p.standing?.[1], !p.excluded). Fix: apply the same filter. Evidence: out/sea-s1-p13.json, shots/sea-s1-p13.png, out/sea-s1-p10.json. Today's test: it shows only once two or more seasons wait while the Cabal lives (01:00 UTC tomorrow at the earliest, if season 1 is not closed) and a middle season holds a sustained objection. Low impact.

### T2 (P1) Costs block: two rows missing, labels short of the mockup, and parts and sums that do not add up

- **Skeptic:** The checker is right. The rows, labels, row classes and launch-window sums are right: in the window, 49 gives '28.746 + 0.574 + 19.68 launch fee = 49.00' (v1.json). Home's 100 imdTEST sentence is right: 98.028 / 1.972 / 0.49 / 0.99 / 0.246 / 0.246. After the launch window the sum line is wrong for some amounts. I saw it in the browser on my fork (p2 at 768 light): 1.01 gives '0.984 imdTEST reaches the pool + 0.016 imdTEST fees = 1.01', which adds to 1.00. 4.07 gives '3.99 + 0.07 = 4.07' (adds to 4.06). 6.11 gives '5.99 + 0.11 = 6.11' (adds to 6.10). 15, 64 and 3.33 add up. Evidence: r2T-verify/v2.json and shots/v2-costs-4.07-768.png. My own BigInt copy of models.ts feeDisplay (r2T-verify/fd.mjs) gets 980 of the 50,000 two-decimal amounts from 0.01 to 500.00 wrong. These are exactly the amounts where raw ≡ 50 (mod 51). Then fee = floor(raw/51) is 1 wei below floor(reaches×200/10000), so models.ts:174 rounds a −1 wei 'launch fee' up to +0.01: BigInt division truncates toward zero and n % unit is non-zero. models.ts:199 then subtracts that 0.01 from 'Reaches the pool', while no launch row is shown (pages-trade.tsx:670 shows it only when extra > 0). The 'Reaches the pool' row is wrong for the same amounts. Fix: launch = 0n when extra is 0, or clamp the residual at 0.

### X1 (P1) RPC transport: sentio cannot serve history, one JSON-RPC error or a short outage locks the site out for a minute, and a head lag shrinks log chunks to one block

- **Checker:** The transport classification, cooldown recovery and chunk rules match the fix list. What is still missing is in the done-when list: sentio as the only RPC, and under 15 s with publicnode hung.
- **Skeptic:** Checked on the live site through my own fault proxy (work dir r2X-verify/x1.mjs). (1) Sentio as the only RPC, failing done-when (c). #/wall at 1280 with publicnode and ethpandaops answering 503 for 150 s (x1/s503-a-wall.json): sentio's 429 'limited to 1000 blocks' body is kept and history loads in 13 chunks of 1,000 blocks, ready at 12.6 s. Then the yellow 'History is incomplete' banner shows from 91.1 s to 107.3 s. The full snapshot's scan of 11962404..11962410 got 'block 11962410 is beyond the latest block … retry later' four times in 6.7 s (83.9, 86.1, 88.3 and 90.6 s), and it happened again at 132–139 s. #/ at 360 with both refused (x1/srefuse-b-home.json): 'Can't read the latest verdicts' at 112.5 s, after 19 head-lag answers. A curl probe at 12:20 UTC showed sentio's eth_getLogs node 1 block behind its own eth_getBlockByNumber head on 3 of 6 tries, for 3 s or more at a time. The 3 × 2 s retry does not cover that. (2) Publicnode hung, done-when (a): ready at 17.18, 16.78 and 15.52 s. Normal loads took 8.33 and 7.0 s, and publicnode refused took 10.94 s. Exactly 1 request went to publicnode and all the rest to ethpandaops, so the excess is the kept 6 s timeout plus ethpandaops being about 3 s slower from this machine. The round-1 re-test measured 13.8–16.3 s in the same harness, so this criterion depends on the environment and is borderline, not a regression. The transport classification and cooldown match the Fix (rpc-health.ts classifyRpc, config.ts:173-225).

### C5 (P2) Plea page panels are written as the seller's own for other wallets and visitors

- **Skeptic:** Confirmed. On #/p/7, p9 is named kafka_cat (NAME letter) and its objection #1 is pending. The Objections panel reads 'OBJECTION OBJECTION #1 pending by 0x269D…0731 · “…”'. That line ignores the display name, which the sale panel on the same page shows ('Objection #1 by kafka_cat:'). It also repeats the word: the stamp prints OBJECTION, then the text starts 'OBJECTION #1…' (pages-court.tsx:1691 uses short(o.objector)). The intended look is plea.html's stamp 'Objection #9' + 'pending'. #/objections has the same gap: ObjectionForm prints 'Objection #1 pending by 0x269D…0731'.
What works:
- Seller's paragraph on #6, verbatim: 'You can’t object to your own plea. Others may until 13:52 UTC, for a 0.50 imdTEST fee + 0.35 imdTEST stake. A new panel of 30 re-scores it: sustained only at 34 or less (more than 2 below your need of 37), and then no points. Void if that panel splits or gives no answer within 20 minutes: nothing changes. The sale is never touched.'
- Points panel: 'Your points' / 'Record my points' for seller p1, 'Points' / 'Record the points' for p3.
Evidence: s1.json (p7-seller, p7-other, obj-open), s2.json (p6-lapsed); screenshot shots/crop-p7-seller-mid.png (all under the r2C-verify dir).

### S10 (P2) Profile: badge in the title row, name preview, seasons table, "also counts", the dead state

- **Checker:** Still wrong: the IMD seat panel copy is not the mockup's. The site says 'This wallet holds an IMD seat. Hold an IMD seat NFT when your plea is recorded…'; profile.html:205 says 'You hold an identity.md seat, so every recorded plea earns × 1.2. Plea #214's 36 becomes 43 points.' (profile.tsx:694-701). Also r2S-N4 (table at 320/360) and r2S-N5 ('07:42 left' in a season's last hour).
- **Skeptic:** Confirmed. The IMD seat panel copy (profile.tsx:697-703) reads 'This wallet holds an IMD seat. Hold an IMD seat NFT when your plea is recorded…' / 'No seat multiplier for this wallet now. …', not profile.html:205's 'You hold an identity.md seat, so every recorded plea earns × 1.2. Plea #214's 36 becomes 43 points.' It is the same on the live site (out/live.json). The label and short address are ported. Also confirmed: r2S-N4 (table class 'table', not 'table table--tight'), r2S-N5, and r2S-VN2 (the foot claims 'rank R's share' under 60 points).

### S12 (P2) Claim: the mockup's vault list, Try again, and the vault message when the list fails

- **Checker:** Still wrong: Try again's body is the raw load error ('The published claims.json file is not available yet. Load the published list below.'), not the mockup body from claim.html:210. The panel's lead copy also differs from the mockup. I saw the delegations-loading skeleton in code only.
- **Skeptic:** Confirmed in code. The error box body is the raw loadError (pages-info.tsx:583-585 and :707), 'The published claims.json file is not available yet. Load the published list below.', not claim.html:210's 'The claim list (claims.json) did not load, or the public RPC did not answer, so the site can't tell what this address may claim. Nothing was sent. The site tries the next RPC by itself.' The Try again reload key (setReload, pages-info.tsx:570, :713) and the four vault messages exist.

### S13 (P2) Share: the frame's label, the objection posts, the no-answer card

- **Checker:** Labels are still wrong in some states. PENDING #30 reads 'PENDING, 0 vs need 37. No points.': a 0 score, and points the card does not show (the mockup has 'Pending until 08:17 UTC. Need 36, 960,000 PLEA, 20% of the bag.'). The pending objection reads 'Objection #3 objection, a new panel re-scores it; 34 or less means no points.' (the mockup has '… Objection #9 pending: +37 points held.'). Objection labels drop the sale sentence ('Sold, 34 vs need 33, for 10.78 IMD.'). NO VERDICT reads 'No verdict: No answer within 20 minutes. No cooldown. No points.' (the spec has 'No verdict: no answer within 20 minutes. No cooldown.'). States are upper case ('SOLD, 45 vs need 37.') where the mockup has 'Sold, …' (share.tsx:99-103).
- **Skeptic:** Confirmed in code (share.tsx:99-103) and on my fork. The label's generic branch is `${state}, ${score} vs need ${need}. …`. PENDING gives 'PENDING, 0 vs need 37. No points.', where the mockup has 'Pending until 08:17 UTC. Need 36, 960,000 PLEA, 20% of the bag.' Sold reads 'SOLD, 44 vs need 37. +49 points.', with no 'for X imdTEST' and upper case where the mockup has 'Sold, 37 vs need 30, for 25.98 IMD.' The pending objection reads 'Objection #N objection, a new panel re-scores it…'. Objection labels drop the 'Sold, …, for …' sentence. NO VERDICT adds 'No points.' and capitalises 'No answer'. Posts for OBJECTION, SUSTAINED and OVERRULED follow the mockup when history is complete.

### S6 (P2) Seasons: the three panels in one row, and the seat panel's copy and label

- **Checker:** Still wrong: the note is not ported. The site has 'One seat or ten, the same multiplier. The need and verdict do not change.'; seasons.html has 'One seat or ten, the same. Points only: the judges' score, your need and the 60-point bar don't change. The leaderboard shows a seat holder's judges' scores in brackets.' (seasons.tsx:669-672).
- **Skeptic:** Confirmed in code. The seat note is not ported: seasons.tsx:669-672 reads 'One seat or ten, the same multiplier. The need and verdict do not change.'; seasons.html:157 reads 'One seat or ten, the same. Points only: the judges' score, your need and the 60-point bar don't change. The leaderboard shows a seat holder's judges' scores in brackets.' The copy, rows ('Score 36, with a seat 43 points', computed from SEAT_MULTIPLIER_BPS and rounded down), the 'Seat NFT · identity.md' label and the short address all match. The grid spans are md-span-8 lg-span-4 / md-span-4 lg-span-4 ×2 (seasons.tsx:409-466). The remaining gap is one sentence of copy.

### S7 (P2) Leaderboard and the panels under it: column heads, SEAT badge, percentages, Closing states, loading and error

- **Checker:** Still wrong: (1) The not-yet Closing copy is not the mockup's main copy. The site says 'Anyone can close it from 19:42 UTC (1-hour grace). Closing records eligible pleas, pays the qualifying wallets and carries the unpaid prize shares forward.'; the mockup says 'The close records any approved plea nobody recorded, pays the top 25 with 60+ points in IMD and PLEA, rolls the unpaid IMD over to season 3 and burns the unpaid PLEA.' (seasons.tsx:867). (2) The rounding note under 'If the season ended now' is 'Each imdTEST amount is rounded down on its own; the leftover rolls over.', not the mockup's 'as the chain pays and prints it, so parts and totals can differ by a cent…'. (3) While loading, aria-busy sits on panel__body, not on the panel, and the lines have no .skeleton wrapper or --mid/--short variants. (4) The error body is the generic 'your funds are not affected', not the band's '…your points are on the chain', and the box sits outside panel__body (double border). See also r2S-N2.
- **Skeptic:** Confirmed. (1) The not-yet Closing copy (seasons.tsx:867) is 'Anyone can close it from … (1-hour grace). Closing records eligible pleas, pays the qualifying wallets and carries the unpaid prize shares forward.', not the mockup's main copy. The same 'Anyone can close it from 2026-10-22 03:45 UTC (1-hour grace).' sentence also prints a second time as the button reason (shots/h-seasons-past.png). (2) The rounding note (seasons.tsx:850-853) is not the mockup's. (3) Loading puts aria-busy on the panel__body, not the panel (seasons.tsx:721), and renders six bare .skeleton__line with no .skeleton wrapper and no --mid/--short variants. (4) The error body is explainReadError's generic '…your funds are not affected.' (errors.ts:241), not the band's '…your points are on the chain and not affected.' The ready copy, head classes, sr-only Rank, SEAT badge and pct() all work.

### T5 (P2) "Your PLEA": no Balance label, an unsigned P/L, a bare open-plea line, the old selling text, and a 0.00 price and a Plead link before the seed

- **Skeptic:** Confirmed in the browser. On my fork, p6 filed hand plea #2 (need 44) and I approved it with fork-answer score 45 (verdictAt 1792587225 = 12:53:45). #/buy at 1280 dark then renders '<p class="small"><b>Plea #2 is open: Sell by 13:00 UTC.</b> Next plea 4 hours after the sale (16:53 UTC if sold now), or 16:53 UTC if it lapses.</p>'. The times are right: verdictAt+420 = 13:00:45 and verdictAt+14400 = 16:53:45. But 'Sell' has a capital S where buy.html and the fix say 'sell by'. The cause: chain.ts:821 openPleaNotice starts with 'Sell by' and pages-trade.tsx:881-899 splices it after 'is open: '. The pending line ('Plea #2 is open: waiting for the verdict, usually 3 to 6 minutes.'), the Balance label, '−41.3%' with U+2212 and the PASS_MARK text are right. A nit: the 'What selling takes' paragraph is a plain <p>, where buy.html has <p class="small">. Evidence: r2T-verify/v3.json and shots/v3-your-plea-approved-1280-dark.png.

### X5 (P2) Loading and read errors: one generic loader on every route, no Wall skeleton cards, a failing snapshot never reported, a bare Try again

- **Skeptic:** Every RPC answer delayed 4.5 s (x5.mjs, x5-loading.json). Profile band: 'Reading 0x4b91078b2374c956A65F7Af0999CaE0a935E6821’s balances, pleas and seasons from the chain…' (page-loading.tsx:22 uses the raw path id). At 360 dark the page is 396 px wide while it loads (shots/x5-loading-profile0x4b9-360-dark.png). At 390 it fits. What works: the Wall at 360 has aria-busy and 3 skeleton cards; Home at 768 dark shows the h1, buttons, six labelled stat cells with 2 skeleton lines each and 'Latest verdicts' with 3 visible cards. The checker's failure-count and error-box evidence stands, and the code matches (context.tsx:157-300).

### X6 (P2) Toasts: "sold for you" never appears, the record toast shows wrong points, and the denied, sale, letter, claim and window-closed toasts differ from the mockups

- **Checker:** The second-record case (a wallet's second plea in the same season) was not exercised: the 4 h cooldown and 5 h season make it a long warp sequence.
- **Skeptic:** Fork 8549, all actions through the site. Still wrong: (1) Window closed, normal case: 'The window closed at 13:47:38 UTC.' / 'Plea #2 lapsed: nothing was sold. Your +44 points still count. Next plea at 17:40 UTC.' It lacks ': held until 14:00 UTC, then record them' (plea.html:466; context.tsx:139). The sustained-objection variant is right: 'Plea #1 lapsed: nothing was sold. Next plea at 17:39 UTC.'. (2) Denied letter: 'Send APPEAL <text> to the Letterbox: about 189,495 PLEA. Call settle to return escrow and tip if you do not appeal.' letters.html:360 also has the deadline, the escrow amount and the tip, and says the oracle fee is spent. (3) Letter toast: 'Open plea #3Open plea #3', the second link going to sepolia.etherscan.io/tx/0x4904… (r2X-3). Verified fixed here, beyond the checker: the second record in one season gives '+45 points recorded.' / 'Season 2: 89 points (45 + 44), rank 1.' (Seasons.bestOf [44,45,0]); the first gives '+44 … Season 2: 44 points (44), rank 1.'. The letter-received text and fee match. Denied: toast--bad, x-circle, role=status, 'Denied, 6 vs need 37: 31 short.'. The claim toast cannot be checked: no claim list is published. Evidence: hero/A.json, B.json, D.json; shots/v-x6-*.png.

### X8 (P2) "How it works": every step number shows twice, the steps use two columns, the copy is paraphrased, and the example is cost rows

- **Checker:** The live chain is not seeded, so the dead-man countdown could not be seen on the live site. In code it is a Countdown with format='deadman' and the aria-label from the fix list.
- **Skeptic:** Live #/how at 360 dark, #/contracts at 1280 light and #/ at 768 light (how.json, shots/how-letters-*.png). All three show 'It pleads NaN% of your PLEA' (home-info.tsx:213 reads n('Letterbox.LETTER_SHARE_BPS'), which is not in the constants; Letterbox.sol:111 has it internal). The info panels are still paraphrased against index.html:270-290. Objection!: 'Others have 20 minutes after an approval to ask a second panel. … at most 2 per plea. The sale stands.' Seasons: no 'best 3 scores count once you record them', no roll-over or burn sentence, and '×1.2 points, rounded down'. Dead-man: no 'Every verdict, approved or denied, resets the clock.'. Each h3 is h3.card__title > span.cluster, not h3.cluster.cluster--sm. The steps are right (ol.steps.steps--4, copy as the mockup). I do not count the example's fact values ('20% / 0 min / −18%'): the Fix tells the site to use C6's FactCells.

## IMD's own review notes

### IMD4: The mobile wallet chooser hides wallets announced through EIP-6963

- **Found:** r2D/imd4.json: on iphone-6963only and android-6963only the Connect sheet lists only the four links 'Open in MetaMask / Coinbase Wallet / Rabby / Phantom'. The announced 'Rabby Wallet' button is missing. On desktop-6963only and android with window.ethereum it shows 'BUTTON: Rabby Wallet'. Screenshot r2D/shots/imd4-iphone-6963only.png. Cause: wallet.tsx:56-58 sets `mobile = phone UA && !window.ethereum`, and wallet.tsx:98-101 drops every `c.type === "injected"` connector on mobile. wagmi's EIP-6963 connectors have type 'injected', so they are dropped too. Full paths: r2D/imd4.json and .../r2D/shots/imd4-iphone-6963only.png
- **Fix:** Fix: on mobile, hide only the generic id 'injected' connector and keep the named EIP-6963 connectors (c.id !== 'injected'). Small risk today: the in-app browsers of MetaMask, Coinbase, Rabby and Phantom set window.ethereum and are not affected.
- **Skeptic:** Confirmed with a separate attempt on the live site, read-only (r2D-verify/imd4.mjs). Setup: a different wallet ('MetaMask', rdns io.metamask, announced only through EIP-6963), different user agents (an Android tablet at 800 px and an iPod touch at 360 px) and dark theme. Result: the Connect sheet lists only the four links 'Open in MetaMask / Coinbase Wallet / Rabby / Phantom'; the announced MetaMask button is missing. When window.ethereum exists, the button shows: in the 'android-both' case, and in the 'late' case where it was injected 3 s after load (mobile is re-computed on each render). Evidence: r2D-verify/imd4.json, r2D-verify/shots/imd4-androidtab-mm6963.png and shots/imd4-ipod-mm6963.png. Cause, at b214b52: wallet.tsx:54-56 sets mobile = phone UA && !window.ethereum, and the filter at wallet.tsx:98-101 drops every connector with type 'injected', which includes the named EIP-6963 ones. Live test: low risk. The in-app browsers of MetaMask, Coinbase, Rabby and Phantom set window.ethereum, so they are not affected.

### IMD5: An expired objection still promises a ruling and says the points are held

- **Found:** imd5b (stale on chain): standing(3) = (false,false,255) and status = 'Plea #3 · objections closed'. The page still says, in the seller's sale panel: 'Objection #2 by 0x269B…6009: “…” +44 points held until the second panel rules. Sustained if the new score is 34 or less … The sale stands either way'. The Objections panel shows 'OBJECTION #2 pending by 0x269B…6009' and the OBJECTION #2 stamp stays. The Points panel on the same page contradicts this: '+44 points once recorded' with Record enabled. #/objections lists it as 'OBJECTION pending … 0.35 imdTEST held', with Expire next to it. Screenshot r2D/shots/imd5b-p3-p2.png, data r2D/imd5b.json. Code: pages-court.tsx:1729-1767 (SaleSummary picks any ruling-1 objection and prints the held sentence). caseState in chain.ts never checks filedAt + PENDING_EXPIRY, and objectionLine prints 'pending'. Once Expire was pressed (r2D/ex2.json), the case read VOID correctly.
- **Fix:** A pending objection past filedAt + Tribunal.PENDING_EXPIRY (or one whose Intake request has completed) should read like 'Objection #2 got no answer in 20 minutes: it will be voided; the points count', with no held line and no 'second panel rules' promise. caseState should count it as freeing its slot. This matters today: an unanswered objection on the oracle is a normal live-test outcome.
- **Skeptic:** Confirmed on my own fork (port 8548) with a different case: a manual Sell-now plea, not a sold appeal. Plea #1: p1 sold at 15:05. p2 objected through the site at 390 px at 15:22:09 (objection #1, never answered). I warped to 15:43:57, past filedAt + Tribunal.PENDING_EXPIRY. On chain: standing(1) = (false,false,255) and status(1) = 'Plea #1 · objections closed'. Viewed as the seller (1280 light), the objector p2 (390 dark) and a visitor (768), every view still shows, in the sale panel: '+42 points held until the second panel rules. Sustained if the new score is 34 or less … The sale stands either way'. The Objections panel shows 'OBJECTION #1 pending by 0xed00…1d12' and the OBJECTION #1 stamp stays. The Points panel on the same page says '+42 points once recorded' with Record enabled. #/objections lists 'OBJECTION pending … 0.35 imdTEST held' next to 'Expire unanswered objection'. Only #/seasons is right: 'Objections on plea #1 closed'. Evidence: r2D-verify/imd5.json, shots/imd5-p1-p1.png, shots/imd5-p1-p2.png, shots/imd5-objections-p2.png. Cause: chain.ts objectionLine (714-718) and caseState (823-848) never compare filedAt + PENDING_EXPIRY, although pages-court.tsx:1644-1646 already does so for the Expire button. After Expire, the page correctly reads 'VOID #1: no answer within 20 minutes: nothing changes' with '+42 points recorded' (void.json). Live test: yes, an unanswered objection is a normal outcome on the live oracle.

## Regression

- **WW9** (regressed): Partly regressed. The Letters info panel on #/, #/how and #/contracts prints 'NaN%' where LETTER_SHARE_BPS (20%) belongs (r2X-2). The other constants checked (2.25%, 0.5%, 1–50%, 2,500,000, 280 bytes, 0.50, 30/17/45, 7 min, 4 h, 20 min, 0.35, 71) and all contract addresses equal the chain and addresses.json. The explorer is sepolia.etherscan.io. Skeptic: Confirmed live: the Letters info panel on #/, #/how and #/contracts prints 'NaN%' where Letterbox LETTER_SHARE_BPS (2,000 = 20%) belongs (how.json). It is one constant on a page every visitor sees. I did not repeat the checker's check of the other constants.

## New issues

### Medium (9)

#### r2T-N1: After the launch window, 'Reaches the pool' and the sum line are 0.01 short for about 2% of amounts

- **Where:** #/buy costs block, alive and dead, every width; web/src/models.ts:174 and :199 (feeDisplay)
- **Expected:** The spec says Reaches the pool = you pay − the fee total − the launch fee, and the sum line adds up. With no launch fee, 26 imdTEST should read '25.492 imdTEST reaches the pool + 0.508 imdTEST fees = 26.00 imdTEST you pay'.
- **Actual:** It reads '25.482 imdTEST reaches the pool + 0.508 imdTEST fees = 26.00 imdTEST you pay', which adds to 25.99. The same happens at 77 (75.482 + 1.508), 0.5 (0.476 + 0.014), 5.6 (5.482 + 0.108), 10.7 (10.476 + 0.214) and 26 after the death. The cause: with extra = 0, `fee - reaches*200/10000` often leaves 1 wei, which `round(…, 2, true)` turns into a hidden 0.01 'launch fee' that line 199 subtracts. No launch-fee row is shown.
- **Repro:** Wait until after the launch window, open #/buy with a wallet, and type 26. Read Reaches the pool and the sum line.
- **Live test:** Matters, though not as a blocker. From 16:30 UTC every buyer sees the costs block, and about 1 typed amount in 50 shows a sum that is 0.01 off. Cosmetic only: no funds are at risk and the transaction is right. A one-line fix (launch = 0 when extra is 0).
- **Skeptic:** Reproduced in the browser at 1.01, 4.07 and 6.11, after the window and while the Cabal lives (v2.json). The checker had 26, 77, 0.5, 5.6 and 10.7. The exact rule is raw ≡ 50 (mod 51): 1.96% of amounts, 980 of 50,000 in my own BigInt copy (r2T-verify/fd.mjs scan). The hidden residual is −1 wei, not +1, and round(…, up) turns it into +0.01 (models.ts:174, :199). Home's 100 imdTEST sentence is not affected. For today's test: it is visible to every buyer once the launch window ends (about 16:30 UTC if IMD seeds at 15:00), on about 1 typed amount in 50. It is cosmetic (the transaction is right), so it is not a blocker; the fix is one line.

#### r2C-N1: Plea page lead contradicts the sale panel for sustained and excluded pleas

- **Where:** #/p/<id> lead paragraph, pages-court.tsx:720-732
- **Expected:** The lead should agree with the C2 blocks. Before a sale or after a lapse of a sustained plea it should not say the sale stands. An excluded seller's lapsed plea should not promise points.
- **Actual:** Any sustained plea (standing[1]) gets 'A second panel sustained an objection. No points; the sale stands.', even while it is unsold in its sell window (Sell now still offered) and after it lapsed ('Nothing was sold.' in the panel below). Owner A's lapsed #14 gets 'The approval lapsed unsold; its points still count.' while the panel below says 'This seller is excluded from season points.'
- **Repro:** Approve a plea, have an objection sustained inside the 7-minute window, and open #/p/<id> as the seller before selling and again after the window. Separately, let an owner plea lapse.
- **Live test:** Yes if an objection is sustained before the seller sells, or the owner pleads and lets it lapse. Copy only; no money at risk.
- **Skeptic:** Reproduced on my fork.
- Sustained #8, unsold in its window, seen by seller p9 with Sell now offered: the lead reads 'A second panel sustained an objection. No points; the sale stands.'
- #8 after the lapse: the same lead, above 'No points for this plea. Nothing was sold.'
- Owner A's lapsed #10: 'The approval lapsed unsold; its points still count.', above 'This seller is excluded from season points.' and 'No points'.
Code: pages-court.tsx:715-733. The standing[1] branch ignores p.status, and the LAPSED branch ignores p.excluded. See also r2C-V1 (the share post).
Today: copy only, no money at risk. It shows when an objection is sustained before the seller sells (a ruling within the 7-minute window is possible, since the oracle takes 3-6 minutes), when a sustained plea lapses, or when wallet A pleads and lets it lapse.
Evidence: s1.json (p8-seller), s2.json (p8-lapsed-seller, p10-lapsed), shots/crop-p8-lapsed-top.png (all under the r2C-verify dir).

#### r2S-N1: When history is incomplete, Share, Past seasons and Profile show false facts instead of withholding them

- **Where:** share.tsx:297-299 and :344 (soldFor and objections come from s.logs); seasons.tsx:947-948 (Past seasons comes from SeasonClosedOut logs); profile.tsx:99-121 and :534-548 (pleas and season keys come from logs)
- **Expected:** While s.historyError is set, leave out or mark as unknown any fact that comes from logs: no 'Sold for — imdTEST', no dropped objection, no 'No seasons have closed', no 'No pleas yet'.
- **Actual:** With the 'History is incomplete' notice on screen: (1) #/share/19 drops the pending objection, and the post and X text read 'SOLD: my plea, 40 vs need 37. Sold for — imdTEST.' (2) #/seasons Past seasons reads 'No seasons have closed in this test run.' with 9 seasons closed. (3) Own #/profile for p1, who has 6 pleas and a season-1 prize, shows no plea cards and 'No plea of this wallet is recorded in any season yet.'
- **Repro:** Load #/share/<an older sold id> or #/seasons on a session whose first history chunk fails (publicnode 4444) and read the post and Past seasons.
- **Live test:** It matters today only if the site's history reads fail live (publicnode prunes the deploy range; the X1 fallback to ethpandaops has to work). A user could post a wrong share text.
- **Skeptic:** Reproduced on my fork. A browser route failed only the first history chunk (eth_getLogs fromBlock 0xb65313) with {4444, 'pruned history unavailable'}; 'History is incomplete' was on screen. #/share/8 (sold, objection #2 sustained), viewed as its seller, posts 'SOLD: my plea, 40 vs need 37. Sold for — imdTEST.' The card shows '— imdTEST to the writer' and the label drops the objection. #/share/10 (objection #3 overruled) posts 'SOLD: plea #10 by 0x9480…3911, 44 vs need 37. Sold for — imdTEST.' #/seasons Past seasons reads 'No seasons have closed in this test run.' with season 1 closed (season 2's pot even shows 'Rolled over from season 1 0.64'). Own #/profile as p2 (2 sold pleas, 49 points) shows 'No pleas yet … Write a plea' and 'No plea of this wallet is recorded in any season yet.' Evidence: out/hist.json, shots/h-share8.png, shots/h-seasons-past.png, shots/h-prof-p2.png. Cause in code: scanLogs stops at the first failed chunk with logs=[] (chain.ts:96-154), and these pages read logs without checking s.historyError. Today: it matters only if every RPC fails a history chunk. Three live loads at 360 around 11:45 UTC (pre-seed) showed no history notice (out/live.json).

#### r2X-1: With only sentio answering, the site shows 'History is incomplete' or 'Can't reach Sepolia' within a minute

- **Where:** web/src/chain.ts scanLogs head-lag retry (3 × 2 s); context.tsx poll; readSnapshot historyError
- **Expected:** X1 done-when: with publicnode and ethpandaops down, #/ and #/wall load full history from sentio in 1,000-block chunks, with no 'History is incomplete'.
- **Actual:** Sentio's eth_getLogs node runs one block behind its own eth_getBlockByNumber('latest'). Every scan up to the head it just reported fails with '-32000 block N is beyond the latest block N-1 of this node, retry later'. The three retries, 2 s apart, usually end before the next block. A refresh then sets historyError and the yellow 'History is incomplete' banner, and two failed polls show the 'Can't reach Sepolia' error box. Measured: #/ banner at 17.5 s (503) and 81 s (refused); #/wall box at 58.4 s and 64.9 s; #/ box at 57 s (hung). Each recovers on a later block, then fails again.
- **Repro:** Block or 503 the hosts ethereum-sepolia-rpc.publicnode.com and rpc.sepolia.ethpandaops.io, open #/ or #/wall, and watch for 90 s.
- **Live test:** Matters only if publicnode and ethpandaops fail at the same time during the test. Normal traffic goes to publicnode, which is fine. A fix: on a head-lag answer, scan only to head−1 (or to the block the RPC names) and treat the rest as not yet due, without setting historyError.
- **Skeptic:** Reproduced live twice (x1/s503-a-wall.json: banner at 91–107 s; x1/srefuse-b-home.json: 'Can't read the latest verdicts' at 112.5 s at 360). curl showed sentio's getLogs node 1 block behind its own head for 3 s or more, longer than the 3 × 2 s retry. Partial history is kept and the 1,000-block chunks are right; only the last chunk at the head fails. For today's live test it matters only if publicnode and ethpandaops are down at the same time. Normal traffic stays on publicnode.

#### r2X-2: 'How it works' Letters panel reads 'It pleads NaN% of your PLEA'

- **Where:** web/src/home-info.tsx:213 (#/, #/how, #/contracts; every width and theme; live now)
- **Expected:** 'It pleads 20% of your PLEA' (index.html:274; Letterbox LETTER_SHARE_BPS = 2,000).
- **Actual:** '…send your plea as text to the Letterbox from Sepolia Etherscan. It pleads NaN% of your PLEA and pays its fees in PLEA.' The code reads n('Letterbox.LETTER_SHARE_BPS'), which is not a chain constant: it is internal in Letterbox.sol:111, and the site pins Letterbox values in models.ts LETTERBOX.
- **Repro:** Open https://plea-test-run-9.sites.imd.fun/#/how and read the Letters panel.
- **Live test:** Yes. It is on the Home page every visitor sees. A one-line fix: use LETTERBOX.LETTER_SHARE_BPS, or the literal from models.ts.
- **Skeptic:** Live: 'It pleads NaN% of your PLEA' on #/, #/how and #/contracts (how.json). home-info.tsx:213 reads a constant that is not read from chain or listed in models.ts LETTERBOX. It matters for the live test: every visitor sees it on Home. It is a wrong figure, not a money risk.

#### r2D-N1: The runner who delivers someone else's auto-sell plea gets the writer's 'sold for you' toast

- **Where:** web/src/context.tsx:632-637 (receiptToast's Delivered branch calls deliveredToast for any sender) and :704-717
- **Expected:** X6: the Delivered toast goes only to the writer. A runner should get a runner line such as 'Delivered plea #4: 426,962 PLEA sold for the writer; you earned the 0.25 imdTEST tip.'
- **Actual:** p1 pressed 'Deliver approved sale' on p3's letter plea #4. p1's toast read 'Approved, 43 vs need 37, and sold for you: 426,962 PLEA for 2.40 imdTEST. / A runner (0x269B…6009) sold it … Record your +43 points after 16:59 UTC. Next plea after 20:39 UTC.' p1 has no points on #4 and no cooldown from it.
- **Repro:** Fork: approved auto-sell or letter plea of wallet X; open #/p/<id> as wallet Y; press Deliver approved sale.
- **Live test:** Yes: runners delivering letters or auto-sell pleas are part of today's script, and the toast tells them they sold their own plea.
- **Skeptic:** Reproduced with an auto-sell plea; the checker used a letter. p4's plea #2 was approved, and runner p5 pressed 'Deliver approved sale' at 1280 px. p5's toast read 'Approved, 43 vs need 37, and sold for you: 506,870 PLEA for 2.56 imdTEST. / A runner (0x4b5f…38CA) sold it … Record your +43 points after 16:56 UTC. Next plea after 20:36 UTC.' p5 is the runner and has no points or cooldown from #2. Writer p4 got the same toast, which is correct for the writer. Evidence: r2D-verify/dl2.json (runnerToasts, writerToasts). Code: context.tsx:632-637 calls deliveredToast for any sender. Live test: yes, runners delivering pleas are part of the script.

#### r2D-N2: A confirmed transaction is reported as failed ('Nothing was sent') when the follow-up reads fail or the receipt takes over 3 minutes

- **Where:** web/src/context.tsx:510-556 (useTx). In round 2, receiptToast became async and calls getPlea, blockTime, Seasons.bestOf/topOf inside the same try after setDone(true). WaitForTransactionReceiptTimeoutError (timeout 180000) also falls through to explainError's generic text.
- **Expected:** Once a hash exists, say the transaction was sent, link it, and never claim 'Nothing was sent'. A failing toast read should fall back to a plain 'Confirmed' toast.
- **Actual:** With eth_getBlockByNumber(<number>) failing on all three RPCs, p1's Sell now confirmed on chain (receipt status 1; the page shows 'Sold 48,621 PLEA for 0.27 imdTEST'). The toast still read 'The transaction could not be simulated. Refresh the chain data and try again. Nothing was sent. / View transaction'. On a slow fork, an approval waited more than 180 s: the same toast appeared, the button went back to Approve PLEA, and a second approval was sent.
- **Repro:** r2D/faultsell.mjs: route all three RPC hosts to answer 503 for eth_getBlockByNumber with a hex block number, then press Sell now.
- **Live test:** Yes: public RPCs throttle during busy minutes. A tester can be told a sale, record or delivery failed and then retry it.
- **Skeptic:** Reproduced on a different action: Deliver on letter plea #3 by runner p3 at 390 px dark, not Sell now. Every eth_getBlockByNumber with a hex block number answered 503 on all three RPC hosts (3 such requests failed). The deliver transaction 0x448fb8da… has receipt status true. The page shows 'Sold 1,001,221 PLEA … Sold by you … To the writer 5.75 imdTEST'. The toast still reads 'The transaction could not be simulated. Refresh the chain data and try again. Nothing was sent. / View transaction'. Evidence: r2D-verify/deliverfault.json and shots/n2-deliver-fault.png. Code: useTx (context.tsx:531-556) awaits the async receiptToast reads inside the same try after setDone(true), and the catch uses explainError's generic text. The receipt-timeout half (over 180 s) is confirmed by code only: WaitForTransactionReceiptTimeoutError is not a plain Error, so it also gets the generic text. A first Record attempt with a failing Seasons.bestOf read was recorded on chain ([42,0,0]), but my script timed out before I could read the toast, so that run is not counted. Live test: yes, public RPCs throttle during busy minutes.

#### r2D-N4: Letters: Send letter is enabled below the letter minimums, and the errors give wrong advice

- **Where:** web/src/pages-info.tsx:434-455 (no balance pre-check, no errors overrides); web/src/errors.ts:153-156
- **Expected:** The page's own Limits say 'A balance of at least 1,442,098 PLEA' and 'A plea worth at least 0.70 imdTEST'. Below them, Send letter should be disabled with that reason, or the decoded error should say how much PLEA is needed.
- **Actual:** p3 with 606,108 PLEA: 'The sale is too small to cover its fees. Increase the amount.' (a letter has no amount). p1 with 946,647 PLEA: 'The price fell since the hourly snapshot, so the fee needs more PLEA than its 10% margin. … or untick auto-sell.' (no such box on Letters). Both are preflight reverts, so nothing was sent.
- **Repro:** Fork: a wallet with 0.6M or 0.95M PLEA opens #/letters, types a plea, presses Send letter.
- **Live test:** Yes: a tester who buys with 10 imdTEST inside the 90-minute launch window gets about 0.6M PLEA, so today's 'send a letter' step fails with this copy. Letter senders need at least about 9 imdTEST of PLEA bought after 16:30 UTC.
- **Skeptic:** Reproduced at 390 px and 1280 px after the launch window. The page's own Limits read 'A balance of at least 1,434,248 PLEA.' Send letter was still enabled (aria-disabled false) for p3 with 609,014 PLEA and for p1 with 810,056 PLEA. Both got 'The price fell since the hourly snapshot, so the fee needs more PLEA than its 10% margin. … or untick auto-sell.' The price had not fallen; the balance was too low, and Letters has no auto-sell box. Both were preflight reverts and nothing was sent. Evidence: r2D-verify/lt3.json and lt1.json. Code: pages-info.tsx:434-455 has no balance check and passes no errors overrides to tx.send('Letterbox','letter'). The checker's '0.6M PLEA for 10 imdTEST' is off: 10 imdTEST at 15:00 gave 1.01M. That is still below the minimum, so the conclusion holds. Live test: yes.

#### r2D-VN1: Fixed imdTEST fees are not checked against the balance: the site sends the approval, then Submit fails with 'Lower the amount'

- **Where:** web/src/components.tsx:868-960 (ApprovalAction reads only the allowance, never balanceOf(token)); Plead's manual path in pages-court.tsx; errors.ts:87-88 (ERC20InsufficientBalance copy)
- **Expected:** With less imdTEST than the fixed fee (0.50 for a plea; 0.85 for an objection or appeal, which use the same ApprovalAction, checked by code reading only), Approve and Submit should be disabled. The reason should name the shortfall, for example 'You need 0.50 imdTEST for the oracle fee; you hold 0.03.' The auto-sell reason should not tell a wallet without imdTEST to 'pay the 0.50 imdTEST oracle fee from your imdTEST'.
- **Actual:** p1 held 1,012,569 PLEA and 0.0291 imdTEST after a 10 imdTEST launch-window buy. On #/plead at 360 px dark, auto-sell (ticked by default) was disabled with 'needs at least 1,442,098 PLEA. Untick … to pay the 0.50 imdTEST oracle fee from your imdTEST.' After unticking, 'Approve imdTEST' was enabled and the 0.50 approval was sent (allowance 5e17 on chain). 'Submit plea 0.50 imdTEST' then failed with 'There are not enough tokens in your wallet. Lower the amount or add test tokens.' Lowering the amount cannot help, because the fee is fixed. This wallet cannot plead by either path.
- **Repro:** Fork: a wallet buys with all its imdTEST (Max on #/buy pays everything) and holds under 1.44M PLEA. Open #/plead, pick 20%, untick auto-sell, press Approve, then Submit.
- **Live test:** Yes. A tester who presses Max, or spends all 10 imdTEST in the launch window, ends with about 1.0M PLEA and no imdTEST, so they can plead neither manually nor by auto-sell, and the site says so only after an approval. Tell testers to keep at least 1 imdTEST for fees.

### Low (19)

#### r2T-N2: Before the seed, an amount brings up the full costs block with a 0.00 price and a quote that never comes

- **Where:** #/buy before PleaHook.seeded, any wallet (pages-trade.tsx costs block: shown for raw > 0 with no seeded check)
- **Expected:** The brief says that until PleaHook.seeded, Buy only says trading is not open yet. T5 already drops the 0.00 price from Your PLEA.
- **Actual:** With 5 typed: 'Price 1M PLEA = 0.00 imdTEST', 'Minimum, 1% slippage: Waiting for the quote' (forever), the opening-buy cashback text, the sum line, and 'Step 1 of 2: lets the buy spend exactly 5.00 imdTEST. Nothing is bought yet.' under a disabled button that says 'Trading is not open yet.'
- **Repro:** Before the seed, open #/buy and type any amount.
- **Live test:** Visible to anyone who opens #/buy before IMD seeds. It is confusing but blocks nothing, and it goes away at the seed.
- **Skeptic:** Reproduced on the live site at 11:33 UTC, read-only with no wallet: #/buy, type 5. The page shows 'Price = 1M PLEA = 0.00 imdTEST' and 'Minimum, 1% slippage = Waiting for the quote', which never resolves. Under them come the full parts, 'none on this opening buy…' and the sum line '4.904 imdTEST reaches the pool + 0.096 imdTEST fees = 5.00 imdTEST you pay', all under 'Trading is not open yet'. The costs block has no seeded check (pages-trade.tsx:606). Evidence: r2T-verify/v6.json n2, shots/v6-live-preseed-buy-5-1280.png. For today's test: anyone on #/buy before the seed sees it, but nothing can be bought then, and it goes away at the seed. Low.

#### r2T-N3: Supply rows say 'Reading mint events…' forever when log reads fail

- **Where:** Home and #/contracts 'Fees and supply', Supply panel; web/src/details.tsx:44-76
- **Expected:** Either a fallback or an error with Try again (the site's read-error pattern), not a loader that never resolves.
- **Actual:** With every eth_getLogs failing (history scan and the one-block mint read), all three allocation rows stayed 'Reading mint events…' for the full 64 s observed, with no error. Only the global 'History is incomplete' notice appeared. A useRead error leaves data undefined, so the loading text stays.
- **Repro:** Block or fail eth_getLogs on all three RPC hosts and open #/.
- **Live test:** Only if the public RPCs cannot serve logs. Live reads work now. Low.
- **Skeptic:** Reproduced on the live site, read-only. I answered every eth_getLogs with a JSON-RPC error (15 blocked). All three allocation rows stayed 'Reading mint events…' for 70 s, with no error and no Try again. Only the global 'History is incomplete' and 'Can’t read the latest verdicts' notices appeared. details.tsx:47-76 has no error branch for mintQuery. Evidence: r2T-verify/v6.json n3, shots/v6-live-supply-no-logs-1280.png. For today's test: it matters only if the public RPCs refuse log reads. Low.

#### r2C-N2: A stale pending objection is still shown as holding the points while Record is enabled

- **Where:** #/p/<id> sale panel, Objections panel and share post (SaleSummary pages-court.tsx:1729-1761, caseState chain.ts:823-853)
- **Expected:** Tribunal._live and standing ignore a pending objection past PENDING_EXPIRY, so the points are no longer held. The page should say the objection got no answer and can be expired, not that points are held.
- **Actual:** On #10 at A+21 min (objection #3 filed 20+ minutes earlier, not yet expired), the sale panel still says '+44 points held until the second panel rules…'. The Objections panel shows 'OBJECTION #3 pending' and the share post says 'a new panel re-scores it'. Meanwhile the Points panel says '+44 points once recorded' with Record enabled, and the case counts it as filed.
- **Repro:** File an objection, never answer it, and open the plea page more than 20 minutes after filing.
- **Live test:** Only if the oracle never answers an objection (the Intake normally voids failures). Low.
- **Skeptic:** Reproduced on #7, whose two objections were filed at 13:32:55-56 and never answered. At 13:54:35 the contract has moved on: Tribunal.standing(7) = (false, false, 255) and status() = 'Plea #7 · objections closed'. The site still shows them as live:
- Sale panel: '+42 points held until the second panel rules…'.
- Objections panel: 'OBJECTION #1 pending'.
- Share post: 'a new panel re-scores it'.
- #/objections?plea=7: 'a new panel is re-scoring the plea' and 'The points may be recorded once no panel is pending.'
Meanwhile the Points panel says '+42 points once recorded', and Record is enabled ('Anyone may record these points').
Does not affect C3: a stale objection only exists after the window has closed.
Today: only if the oracle never answers an objection (failures are normally reported and voided). Low.
Evidence: s3.json (p7-stale-seller, obj7-stale) under the r2C-verify dir.

#### r2C-N3: Sale toast says to record after the objection window when the case is already closed

- **Where:** Sell now success toast on #/p/<id> (toast copy, X6 area)
- **Expected:** When both objection slots are already ruled, the points can be recorded at once. The plea page's Record button is enabled with 'Anyone may record these points.'
- **Actual:** After the UI sale of #2, which was closed by two rulings, the toast reads 'Sold 499,091 PLEA for 2.95 imdTEST. Record your +39 points after 09:23 UTC. Next plea at 13:04 UTC.'
- **Live test:** Rare (needs two rulings before the sale). Copy only.
- **Skeptic:** Reproduced with a real UI sale. Seat holder p2 sold #11 after both of its objections were overruled (40 and 39).
- Toast: 'Sold 200,498 PLEA for 1.19 imdTEST. Record your +46 points after 13:53 UTC. Next plea at 17:38 UTC.'
- The page right after: 'Objections closed: both objections were ruled', '+46 points once recorded', Record enabled with 'Anyone may record these points.' Tribunal.standing(11) = (false, false, 39).
Code: context.tsx:644 builds the time from the window and never consults caseState. The delivered-sale toast (context.tsx:714) and components.tsx:1235 use the same window-only time.
Today: rare, since it needs two rulings inside the 7-minute window. Copy only.
Evidence: sell11.json, shots/sell11-after.png under the r2C-verify dir.

#### r2C-N5: With incomplete history, a refused plea reads as an expiry at a future time

- **Where:** noVerdict() in chain.ts:855-881, used by SaleSummary and the stamp
- **Expected:** With no PleaFailed log available, the page should not state an expiry that has not happened yet.
- **Actual:** While the log scan failed, refused #15 showed 'no answer' and 'The request expired at 09:23 UTC with no answer.' at 09:04 fork time. With full history it correctly says 'The request was refused.'
- **Live test:** Only when the RPCs fail the history scan. Low.
- **Skeptic:** Reproduced on a fresh refused plea, #12 (PleaFailed status 1 at 13:55:46), loaded with every eth_getLogs answering an error.
- 'History is incomplete' is shown.
- The stamp reads 'NO VERDICT / no answer'.
- The panel reads 'No answer within 20 minutes. The request expired at 14:15 UTC with no answer.', a time still 20 minutes away.
- Card 'No answer / within 20 minutes'; post '…; no answer.'
With full history the same page correctly says 'The request was refused. Cleared at once by the Intake.'
Code: noVerdict() (chain.ts:855-881) defaults to 'no answer' and submittedAt + 20 min.
Today: only when the history scan fails, and the page does warn about it.
Evidence: n5.json against n6.json, shots/n5-p12.png (all under the r2C-verify dir).

#### r2C-V1: A sustained plea's share post says 'the sale stands' when nothing was sold

- **Where:** #/p/<id> and #/share/<id> post text, share.tsx:355 (and the fallback at :358)
- **Expected:** Like the C2 block: 'the sale stands' only for a sold plea (status 4 or 5). An unsold plea still in its window, or a lapsed one, should not claim a sale.
- **Actual:** Sustained #8, unsold with Sell now still offered, gives the post 'Objection #3 SUSTAINED: my plea re-scored 30 vs need 37, no points; the sale stands.'. After the lapse the post is unchanged, while the sale panel says 'No points for this plea. Nothing was sold.'. A visitor gets the same on #/share/8.
- **Repro:** Approve a plea, have an objection sustained inside the 7-minute sell window, and open #/p/<id> or #/share/<id> before the sale and after the window.
- **Live test:** Same condition as r2C-N1: a sustained objection on an unsold or lapsed plea. Copy only, and it is the text people post.

#### r2S-N2: During a leaderboard read error, Your standing and 'If the season ended now' show zeros as fact

- **Where:** seasons.tsx:345-377 and :497-637 (rows and best fall back to [] or [0,0,0] when query.error)
- **Expected:** While the board can't be read, Your standing and the projection panel show a reading or error state, not values.
- **Actual:** For seat_one, rank 1 with 102 points, the error state shows 'Rank none yet / Points 0 / Best three 0 + 0 + 0 = 0 / No approved plea of yours is recorded in season 1…'. The panel shows 'Paid to 0 wallets 0.00% · 0.00 imdTEST / Rolls over to season 2 100.00%', and Close shows 'Waiting for the required chain state.'
- **Repro:** Make the Seasons bestOf eth_call fail, then load #/seasons as a ranked wallet.
- **Live test:** Only shows during an RPC failure; the page recovers with Try again.
- **Skeptic:** Confirmed in code. seasons.tsx:345-350 fall back to rows=[] and best=[0,0,0] when query.error. Your standing (:497-637) never checks query.error, so it renders 'none yet / 0 / 0 + 0 + 0 = 0' and the no-plea band. 'If the season ended now' computes from rows=[] ('Paid to 0 wallets'). Close is disabled by !query.data with no reason, so TxButton shows its default 'Waiting for the required chain state.' (components.tsx:697). The checker's shots/lb-error.png matches. Today: only during an RPC failure; Try again recovers.

#### r2S-N3: Wall empty state for Denied + Objected says 'No objections yet' while objected pleas exist

- **Where:** pages-court.tsx:281-305 (the Empty title and copy pick 'No objections yet' whenever the Objected flag is on)
- **Expected:** For a filter combination that matches nothing, use 'No matching pleas' unless there really are no objections yet.
- **Actual:** With Denied and Objected on and 3 objected pleas on the Wall: 'No objections yet / Every approval so far went unchallenged. Suspicious. / Show all pleas'.
- **Repro:** #/wall, click Denied, open More filters, click Objected.
- **Live test:** Cosmetic; it can show once the live court has an objection.
- **Skeptic:** Reproduced on my fork. Denied + More filters › Objected gives 'No objections yet / Every approval so far went unchallenged. Suspicious. / Show all pleas', while Objected alone shows #10, #8 and #5 (out/n3n8.json, shots/n3-empty.png). pages-court.tsx:281-305 picks the title from the Objected flag alone. 'No denied pleas yet' has the same flaw when Denied is combined with a flag. Today: cosmetic, once the live court has an objection.

#### r2S-N4: Profile seasons table is wider than the screen at 320 and 360 and hides the Prize column

- **Where:** profile.tsx:610-650 (className 'table', where profile.html uses 'table table--tight'; th scope=row cells take header shading)
- **Expected:** The four columns fit at 320 px like the mockup's table--tight, or the overflow is obvious.
- **Actual:** The table spans 35..404 px in a 320 px viewport. Prize is cut off and only reachable by scrolling inside the table-wrap. The Season cells carry the header's dark shading.
- **Repro:** #/profile as a wallet with a season row, at 320 or 360.
- **Live test:** Shows on phones once wallets have recorded points.
- **Skeptic:** Reproduced at 320 light as p2. TABLE.table spans 35..380 while its table-wrap ends at 285, so Prize is cut off and reachable only by scrolling inside the wrap; the page itself does not scroll sideways (out/prof-p2-lasthour.json, shots/prof-p2-lasthour.png). profile.tsx:642 uses className 'table' where profile.html:190 has 'table table--tight'. The row header is <th scope=row>, which takes .table th's nowrap and paper-2 background (components.css:401). Today: shows on phones once a wallet has recorded points.

#### r2S-N7: An ended season's Your standing invites a new plea

- **Where:** seasons.tsx:623-634 (the no-plea band is shown for ended SeasonViews too)
- **Expected:** In an ended or waiting season, say that nothing more can be pleaded for it: no 'Your best three count…' pitch and no 'Write a plea'.
- **Actual:** Inside 'Season 1 ended' and the season-2 details: 'No approved plea of yours is recorded in season 1. Your best three count, and two pleas that score 30 already reach the 60-point bar; an IMD seat makes each one × 1.2. Write a plea'.
- **Repro:** #/seasons as a wallet with no plea in the ended season, while it awaits its close.
- **Live test:** Shows from 20:00 UTC today, when season 1 ends.
- **Skeptic:** Reproduced as p13: the 'Season 1 ended' section and the season-2 details both show 'No approved plea of yours is recorded in season 1/2. Your best three count, and two pleas that score 30 already reach the 60-point bar; an IMD seat makes each one × 1.2. Write a plea' (out/sea-s1-p13.json). After the death the same pitch shows for the closed season 9, without the link (out/close-s9-dead.json). seasons.tsx:623-634 shows the band whatever bounds[3] or ended says. Today: from 20:00 UTC, when season 1 ends, until it closes.

#### r2S-VN1: Seat bracket and 'Judges’ scores, before × 1.2' claim × 1.2 for a plea recorded without a seat

- **Where:** web/src/seasons.tsx:381-388 (judgeScores and hasMultiplier join every counted plea's score once any one is multiplied), :789-794 (bracket), Standing Costs row ~:546
- **Expected:** The bracket and the judges' row multiply only what the chain multiplied: show × 1.2 only on SeatMultiplier pleas (countedPleas already returns multiplied per plea), e.g. '48 · 38 (40 × 1.2 · 38)', or leave out unmultiplied scores.
- **Actual:** p5 recorded #11 with a seat (score 40 → 48), moved the seat away, then recorded #13 without one (38 → 38). The leaderboard reads 'Best three 48 · 38(40 · 38 × 1.2)' and Your standing reads 'Judges’ scores, before × 1.2 · 40 · 38', although 38 × 1.2 = 45 is not on the board.
- **Repro:** Fork: a seat holder records one plea, transfers the seat NFT, then records a second plea in the same season; open #/seasons.
- **Live test:** Only if a seat holder gains or loses a seat between two records in one season. Rare today.

#### r2S-VN2: Profile seasons foot and prize cell imply a prize for a wallet under the 60-point bar

- **Where:** web/src/profile.tsx:692 (foot) and :676-680 (prize cell)
- **Expected:** Under MIN_POINTS, the prize cell reads 'no prize (49 of 60)' as on the leaderboard, and the foot keeps only 'Prizes are rounded down and paid at the close, from …'.
- **Actual:** Own profile for p2 (49 points, rank 2): the row reads 'Season 2 · 27:32 left | 49 | 2 so far | 0.00 imdTEST + 0 PLEA' and the foot reads 'Season 2’s prize is rank 2’s share if it ended now. Prizes are rounded down…'. Rank 2 at 49 points gets nothing.
- **Repro:** #/profile as a wallet with recorded points under 60 in the running season.
- **Live test:** Yes. Most wallets sit under 60 points in season 1 today (one approved plea gives about 40-54), so their own profile shows this.

#### r2X-3: Receipt toasts show two identical 'Open plea #N' links, the second going to Etherscan

- **Where:** web/src/context.tsx:356-366 (the toast renderer uses toast.link for the hash link). Affects the plea sent, appeal sent, objection filed and letter received toasts.
- **Expected:** One 'Open plea #N' link to #/p/N, and the receipt link labelled 'View transaction', as before. Only the claim toast should use its own 'View the receipt' label.
- **Actual:** The letter toast reads 'Open plea #8Open plea #8': two links with the same name run together. The first opens #/p/8, the second opens sepolia.etherscan.io/tx/…. This came in with b214b52's `{toast.link || "View transaction"}`.
- **Repro:** On a fork, submit a plea or send a letter from the site and read the toast.
- **Live test:** Yes, every plea and letter toast in the test. Low severity: confusing, and two links with the same name go to different places.
- **Skeptic:** Fork, letter sent through the site: 'Open plea #3Open plea #3', with links #/p/3 and https://sepolia.etherscan.io/tx/0x4904… (hero/B.json, shots/v-x6-letter-toast.png). Code: context.tsx renderer uses {toast.link || 'View transaction'} for the hash link. The plea, appeal and objection receipt toasts set both href and link, and useTx adds the hash (context.tsx:537-542, 596-623). It matters for the live test: every plea, appeal, objection and letter toast is affected. It is confusing but harmless.

#### r2X-4: Profile loading line prints the full address and scrolls sideways at 320 px

- **Where:** web/src/page-loading.tsx:22 (#/profile/<address> while loading)
- **Expected:** X5: 'Reading <name or 0x7a3f…c21e>’s balances, pleas and seasons from the chain…', with no horizontal scroll.
- **Actual:** 'Reading 0x4b91078b2374c956A65F7Af0999CaE0a935E6821’s balances…'. At 320 px the page is 396 px wide until the snapshot arrives.
- **Repro:** Open #/profile/0x4b91078b2374c956A65F7Af0999CaE0a935E6821 at 320 px on a slow connection.
- **Live test:** Minor and brief: it shows for a few seconds on phones opening a profile link.
- **Skeptic:** Also at 360 dark: the full checksummed address in the loading line, and the page is 396 px wide until the snapshot arrives (x5-loading.json, shots/x5-loading-profile0x4b9-360-dark.png). It fits at 390 and 768. It shows for a few seconds on phones; minor for the live test.

#### r2X-5: On a phone without window.ethereum, the Connect sheet hides wallets that announce through EIP-6963

- **Where:** web/src/wallet.tsx:53-55 and 98-101 (mobile = phone UA and no window.ethereum; listed drops every injected connector)
- **Expected:** An EIP-6963 wallet in the page is offered, as on desktop.
- **Actual:** 390 px iPhone UA tested three ways. No wallet: the four 'Open in …' deep links (MetaMask, Coinbase Wallet, Rabby, Phantom), which is reasonable. window.ethereum plus EIP-6963: the wallet is listed. EIP-6963 only: the announced wallet is hidden and only the deep links show.
- **Repro:** Phone UA, announce an eip6963 provider without setting window.ethereum, press Connect.
- **Live test:** Matters little: wallet in-app browsers set window.ethereum. A phone user in Safari or Chrome sees the deep links.
- **Skeptic:** By code, wallet.tsx:53-55 and 98-101: when mobile, `listed` drops every connector of type 'injected', and EIP-6963 connectors are that type. Not changed this round: the wallet.tsx diff only touches explainError(...).title. It hardly matters for the live test: phone wallet browsers set window.ethereum.

#### r2X-6: A failed deployment load (one static-file error or offline) never retries by itself

- **Where:** web/src/main.tsx:17-43 (loadConfig().catch renders the error with a Reload button). Present before this round; main.tsx is unchanged.
- **Expected:** A retry when the browser comes back online, or after a short delay.
- **Actual:** 'The deployment configuration could not be loaded or verified. Transactions are disabled.' with a 'Reload deployment' button. It appeared once on a normal live load of #/claim at 360 dark, and on a load that went offline at 1.5 s. Neither recovered after 30 s back online, because DataProvider's online and visibility recovery is not mounted on this screen.
- **Repro:** Go offline right after navigation, wait 13 s, go online.
- **Live test:** Rare, and Reload deployment fixes it.
- **Skeptic:** By code: main.tsx (unchanged since cc33304) renders 'The deployment configuration could not be loaded or verified.' with only a 'Reload deployment' button. Nothing retries on 'online' or on a timer, because DataProvider's recovery is not mounted on that screen. Any single failed fetch of imd-deployment.json or an abi/*.json file (config.ts:66-116) leads there. It is rare for the live test, and the button fixes it.

#### r2D-N3: Toasts show two 'Open plea #N' links; the second one opens Etherscan

- **Where:** web/src/context.tsx:359-366 (the tx link now renders `{toast.link || "View transaction"}`; at cc33304 it was 'View transaction')
- **Expected:** One 'Open plea #N' link to #/p/N plus 'View transaction' to sepolia.etherscan.io (components.html toasts; WCAG 2.4.4 link purpose).
- **Actual:** <a href="#/p/6">Open plea #6</a><a href="https://sepolia.etherscan.io/tx/0x2e2a…" target="_blank">Open plea #6</a> on the plea-sent, appeal-sent, objection-filed and letter-received toasts.
- **Repro:** Submit any plea on #/plead and read the toast.
- **Live test:** Yes, mildly: every plea, objection and letter toast today has it.
- **Skeptic:** Seen on the plea-sent toast ('Plea #1 sent… / Open plea #1Open plea #1', pl1b.json), the letter-received toast (lt5.json) and the objection-filed toast. On the objection toast I read the anchors: ['Open plea #1', '#/p/1'] and ['Open plea #1', 'https://sepolia.etherscan.io/tx/0xfeeef9c9…', '_blank'] (ob1.json toastLinks). Cause: context.tsx:359-366 renders {toast.link || 'View transaction'}; at cc33304 the text was always 'View transaction'. Live test: yes, mildly. It shows on every plea, objection and letter toast.

#### r2D-N5: A pending objection past the objection window gives a past record time and a 00:00 countdown

- **Where:** web/src/pages-court.tsx:966-990 (objectionUntil is the window end; seasons.tsx:565-574 already uses filedAt + PENDING_EXPIRY)
- **Expected:** 'Record your +44 points after 15:25 UTC, when objection #2 is ruled or expires', counting down to filedAt + Tribunal.PENDING_EXPIRY.
- **Actual:** At 15:24, with objection #2 pending until 15:25:12, it read 'Objection panel pending 00:00' and 'Record your +44 points after 15:21 UTC, when objections close.'
- **Repro:** Object near the end of a plea's 20-minute window, then open the plea page after the window closes and before the objection expires.
- **Live test:** Minor: only when an objection is filed late in the window.
- **Skeptic:** Plea #1's window closed at 15:25:07. Objection #1 was filed at 15:22:09 and stays pending until 15:42:09. At 15:30:55 the Points panel showed the timer 'Objection panel pending 00:00' and 'Record your +42 points after 15:25 UTC, when objections close.' (seller), and 'Record the +42 points…' for the objector and the visitor. Chain: standing = (true,false,255), status 'OBJECTION #1 pending'. Evidence: r2D-verify/n5.json and shots/n5-p1-p1.png. Code: pages-court.tsx:966-990 uses objectionUntil, the end of the window. Live test: minor, only for objections filed late in the window.

#### r2D-N6: Deliver approved sale's estimate subtracts the auto-sell fee on letter pleas

- **Where:** web/src/pages-court.tsx:857 (pre-existing: `net - LETTERBOX.AUTO_SELL_FEE` whatever the BY_LETTER flag)
- **Expected:** Letters pay no auto-sell fee (Letterbox._deliver; the Letters page says 'Auto-sell fee: none for letters'), so the estimate should be ≈ 2.40.
- **Actual:** The button read 'Deliver approved sale ≈ 2.05 imdTEST'; the writer received 2.40 imdTEST.
- **Repro:** Approved letter plea; open #/p/<id> as any other wallet.
- **Live test:** Minor confusion only.
- **Skeptic:** Letter plea #3 (flags 3, BY_LETTER): the runner's button read 'Deliver approved sale ≈ 5.40 imdTEST'. eth_call deliver() quoted 5.7536, and the real Delivered event had out 5.7536 and fee 0.0. For auto-sell plea #2 (flags 2) the same estimate (≈ 2.56) was right: out 2.569 with fee 0.35. Evidence: r2D-verify/deliverfault.json (btnLabel, saleQuote), shots/n6-runner-letter.png and dl2.json. Code: pages-court.tsx:857 subtracts LETTERBOX.AUTO_SELL_FEE whatever the BY_LETTER flag; this predates round 2. Live test: minor confusion only.

### Nit (20)

#### r2T-N4: While the quote loads, 'Waiting for the quote from the pool.' shows twice

- **Where:** #/buy, quote loading, wallet whose allowance covers the buy; pages-trade.tsx:557-561 (field hint) and :297 (button reason)
- **Expected:** buy.html 'Quote loading' has the text once, under the button (ql-why).
- **Actual:** It shows as the quote field's hint (#quote-hint) and again under Buy PLEA.
- **Repro:** With an allowance in place, change the amount on a slow RPC.
- **Live test:** No; a cosmetic duplicate lasting a second or so.
- **Skeptic:** Reproduced on my fork (p7 with an allowance, RPC delayed 4 s). #quote-hint reads 'Waiting for the quote from the pool.' and the button note _r_0_-note repeats it, where buy.html has it once, as #ql-why under the button. Code: pages-trade.tsx:557-561 and :296. Evidence: r2T-verify/v5.json, shots/v5-quote-loading-1280.png. Does not matter for the live test.

#### r2T-N5: Supply panel: Total − Burned ≠ Supply now by 1 PLEA

- **Where:** Home Supply panel; details.tsx:150-160
- **Expected:** Like the mockup (1,000,000,000 − 26,134,870 = 973,865,130), the three rows add up.
- **Actual:** 'Burned so far −26,703 PLEA' and 'Supply now 999,973,296 PLEA' against 1,000,000,000. The negative burn rounds toward zero while supply rounds down. After the death: −22,165,510 and 977,834,489.
- **Repro:** After any trade, open #/ Fees and supply.
- **Live test:** No.
- **Skeptic:** Reproduced on my fork after the death: 'Burned so far −7,966,610 PLEA' and 'Supply now 992,033,389 PLEA' (totalSupply 992,033,389.74), but 1,000,000,000 − 7,966,610 = 992,033,390. The negative burn is truncated toward zero by amount(), while the supply is truncated down (details.tsx:152-160). Evidence: r2T-verify/v5.json supply. Does not matter for the live test.

#### r2T-N6: Small format slips next to the costs block: '0.5%', 'exactly 33.33', 'for 387.66' after Max

- **Where:** #/buy Cashback panel, step note, and fill line and toast
- **Expected:** Percentages with 2 decimals ('0.50% of every trade', as in buy.html). The step note should name the exact approved amount. After Max, the fill line should agree with the 387.65 that the field, Balance and sum line showed.
- **Actual:** The Cashback panel says 'Paid in the same transaction: 0.5% of every trade'. For a typed 33.333 the note says 'lets the buy spend exactly 33.33 imdTEST', while the approval is 33.333. After a Max buy of 387.6543211 (shown as 387.65), the toast and fill read 'Bought 46,301,593 PLEA for 387.66 imdTEST.'
- **Repro:** See where.
- **Live test:** No.
- **Skeptic:** Confirmed in code. pages-trade.tsx:939 prints Number(CASHBACK_BPS)/100 + '%', which gives '0.5% of every trade'; I saw it on the fork's Cashback panel (v1 screenshot). The step note uses tokenAmount(raw, s, true), which truncates to 2 decimals (:754), so 33.333 shows as 33.33. The buy fill uses tokenAmount(spent, s, true, 2, 'up') (:466), so after a Max of 387.6543 it reads 387.66 while the field showed 387.65. Does not matter for the live test.

#### r2C-N4: Denied plea's share post still offers the appeal after the window closed

- **Where:** #/p/<id> share post text, share.tsx:358
- **Expected:** Once verdictAt + COOLDOWN has passed, the post should not say 'Appeal until …'. The card on the same page already says 'Closed / appeal until 13:41 UTC'.
- **Actual:** At 14:40, seller p5's post for #3 reads 'DENIED: my plea, 20 vs need 37. Appeal until 13:41 UTC.'
- **Live test:** Cosmetic.
- **Skeptic:** Reproduced at 16:37 fork time on p5's denied #4, whose appeal window ended at 16:32. The post reads 'DENIED: my plea, 20 vs need 37. Appeal until 16:32 UTC.' (and the same on #/share/4 for a visitor). The card says 'Closed / appeal until 16:32 UTC', and the panel says 'The appeal window closed at 16:32 UTC.'
Code: share.tsx:358 checks only state === 'DENIED' && !p.appealed, never now.
Today: cosmetic.
Evidence: s5.json under the r2C-verify dir.

#### r2C-N6: Refused share card says 'within 20 minutes'; full-case Object button has no stated reason

- **Where:** share.tsx:203-205; the ObjectionForm button on #/objections for a full case
- **Expected:** A refusal happens at once. A disabled button should carry its reason through aria-describedby and the cost sub-label.
- **Actual:** The refused #15 card reads 'Request refused / within 20 minutes'. On #/objections?plea=13 (full) the button is a bare 'Object' with aria-disabled=true and no aria-describedby; the 'Two objections are pending…' line is not tied to it.
- **Live test:** Cosmetic and accessibility only.
- **Skeptic:** Both parts reproduced.
- Refused #12's share card reads 'Request refused / within 20 minutes'. share.tsx:201-205 uses the 'within 20 minutes' sub for anything that is not a split.
- #/objections, full case #7: the button renders as a bare <button class="btn" aria-disabled="true">Object</button>, with no aria-describedby and no cost sub-label (pages-court.tsx:1365). The 'Two objections are pending…' line is not tied to it. objections.html:292-294 has a btn--primary btn--block button with aria-describedby="full-why" and the 0.85 sub, under an info notice with i-prohibit (the site uses a warn notice).
Today: cosmetic and accessibility only.
Evidence: n6.json, s1.json (obj-p7) under the r2C-verify dir.

#### r2S-N5: Profile season cell reads '07:42 left' in a season's last hour

- **Where:** profile.tsx:631 uses duration(), which prints MM:SS under an hour
- **Expected:** Words such as '7 min left' (the mockup has '9d 4h left'), not a clock-like 07:42.
- **Actual:** 'Season 4 ¶ 07:42 left'. Home's pot note also reads 'season N ends in 07:42' in the last hour.
- **Repro:** Open #/profile in the last hour of a season.
- **Live test:** Shows in the last hour of each 5 h season.
- **Skeptic:** Reproduced: own profile at fork time T0+9h31 shows 'Season 2 / 27:32 left' (out/prof-p2-lasthour.json). duration() prints MM:SS under an hour (chain.ts:534-539); profile.tsx uses it in the season cell. It reads like a clock time. Today: shows in the last hour of every season (first 19:00-20:00 UTC).

#### r2S-N6: Leaderboard judges' bracket has no space before it

- **Where:** seasons.tsx:789-794
- **Expected:** '54 · 48 (45·40 × 1.2)', as in seasons.html:174.
- **Actual:** '54 · 48(45 · 40 × 1.2)'. 'no prize (48 of 60)' also lacks the mockup's nowrap span.
- **Repro:** #/seasons with a seat holder on the board.
- **Live test:** Cosmetic.
- **Skeptic:** Reproduced: rowHTML '…</span>48 · 38<span class="seatx nowrap">(40 · 38 × 1.2)</span>' with no space before the bracket (out/sea-s2-p5-360.json; seasons.tsx:789-794). 'no prize (N of 60)' has no nowrap span either. Cosmetic.

#### r2S-N8: The no-prize held projection ends with 'at today’s season prize pot'

- **Where:** seasons.tsx:402
- **Expected:** '…and rank 1: no prize yet (52 of 60).' (S5's wording).
- **Actual:** '…and rank 1: no prize yet (52 of 60) at today’s season prize pot.'
- **Repro:** A held plea whose projected total is under 60.
- **Live test:** Cosmetic.
- **Skeptic:** Reproduced as p3: 'Plea #16’s +39 points are held until 22:11 UTC. / Recorded, they make 39 points (39 + 0 + 0) and rank 1: no prize yet (39 of 60) at today’s season prize pot.' (out/n3n8.json). The template at seasons.tsx:402 always appends ' at today’s season prize pot.' Today: cosmetic, shows on most first held pleas of a season.

#### r2S-VN3: 'Paid to 1 wallets' and close toast '1 wallets paid'

- **Where:** web/src/seasons.tsx:836 and :995; web/src/context.tsx:653
- **Expected:** '1 wallet' when exactly one wallet qualifies.
- **Actual:** 'Paid to 1 wallets 4.50% · 0.03 imdTEST' and the toast 'Season 2 closed. 1 wallets paid 0.03 imdTEST + 450,000 PLEA. …'
- **Repro:** Close a season in which exactly one wallet has 60+ points.
- **Live test:** Likely at the first close tonight, if one wallet qualifies. Cosmetic.

#### r2X-7: Profile P/L prints '-39.9%' with a hyphen and no plus sign

- **Where:** web/src/profile.tsx:430 ('Now, at X per 1M' row uses toFixed(1))
- **Expected:** The shared signedPercent: '+0.8%' or '−39.9%' (U+2212), as Buy prints '−40.1%'.
- **Actual:** 'Now, at 5.95 imdTEST per 1M -39.9%' on #/profile, against '−40.1%' on #/buy.
- **Live test:** Cosmetic.
- **Skeptic:** My fork: #/profile/<p1> reads 'Now, at 5.93 imdTEST per 1M -40.0%' (hyphen) while #/buy for the same wallet reads '−40.0%' (hero/C.json). profile.tsx:430 uses toFixed(1), not signedPercent. Cosmetic.

#### r2X-8: Hero summary repeats 'sell by' and its numbers are not bold

- **Where:** web/src/components.tsx PleaFoot(hero) used in HeroPlea
- **Expected:** index.html:130-132: two spans, 'Sells <b>N</b> PLEA ≈ <b>X</b> IMD' and '<b>+43</b> points held (36 × 1.2)'. The sell-by time appears only in the meta line.
- **Actual:** A third span 'sell by 10:51 UTC' sits right above the meta line 'Sell by 10:51 UTC. …', and nothing in the summary is bold.
- **Live test:** Cosmetic.
- **Skeptic:** My fork, plea #2 visitor hero: spans ['Sells 501,526 PLEA ≈ 2.90 imdTEST','+44 points held','sell by 13:47 UTC'] plus the meta '… can sell until 13:47 UTC.' (hero/A.json). PleaFoot (components.tsx:1013-1080) emits the 'sell by' span for the hero too and has no <b>. Cosmetic.

#### r2X-9: A failing snapshot read is reported as 'The public RPC did not answer'

- **Where:** explainReadError (web/src/errors.ts), the error box after repeated snapshot failures
- **Expected:** Wording that fits a read that reverted or errored, because the RPC did answer.
- **Actual:** When eth_call answers 'execution reverted' or -32603 on every URL, the box reads 'Can’t read the latest verdicts / The public RPC did not answer. The site tries the next one by itself; your funds are not affected.'
- **Live test:** Only shows when a read fails, which should not happen against the deployed contracts.
- **Skeptic:** Seen again in my sentio-only run: 'The public RPC did not answer…' when sentio did answer, with a head-lag error (x1/srefuse-b-home.json). errors.ts:235-241 returns that text for every error that is not a plain Error. It shows only when reads fail.

#### r2X-10: A visitor hears 'Your need is 37 of 45' on someone else's pending plea

- **Where:** Meter aria-label for a pending plea (Home hero, plea cards); overlaps C5
- **Expected:** Neutral wording for a visitor ('No score yet. A 20% plea needs 37 of 45.' or 'need 37 of 45').
- **Actual:** meterAria 'No score yet. Your need is 37 of 45.' on the visitor's Home hero.
- **Live test:** Screen-reader wording only.
- **Skeptic:** My fork, pending plea #4 seen with no wallet: meterAria 'No score yet. Your need is 37 of 45.' (hero/C.json, 'pending hero visitor 1280'). Screen-reader wording only.

#### r2X-11: Home's loading lead differs from the loaded lead

- **Where:** web/src/page-loading.tsx:44-47
- **Expected:** The same lead in the loading band and the loaded hero, so the text does not change on load.
- **Actual:** Loading: 'PLEA is a meme token on Uniswap v4. Selling takes a plea while the Cabal lives.' Loaded: 'PLEA is a meme token on Uniswap v4. To sell, you write why, and the Cabal, 30 judges on an IMD oracle panel, scores it from 0 to 45.'
- **Live test:** Cosmetic.
- **Skeptic:** page-loading.tsx:46 'PLEA is a meme token on Uniswap v4. Selling takes a plea while the Cabal lives.' against pages-info.tsx:92-95 'To sell, you write why, and the Cabal, 30 judges…'. Seen in my Home 768 loading run (x5-loading.json). The mockup's loading band (index.html:409-418) does not set a lead. Cosmetic.

#### r2X-VN1: Home hero leaves out the objection stamp, so after a sustained objection an APPROVED hero reads 'no points' with no reason

- **Where:** web/src/components.tsx HeroPlea (from :1171): ObjectionStamps is rendered only in PleaCard (:1128-1130), not in the hero. Home #/, every width.
- **Expected:** The same objection row the plea's Wall card shows (wall.html:180: a stamp--sm stamp--objection 'Sustained' plus '#8: 29 vs need 33'), so the hero explains why it says 'no points'.
- **Actual:** Fork plea #1 (44 vs need 37) after objection #1 was sustained at 5: the hero shows a large APPROVED stamp, 'passes by 7' and 'Sells 605,899 PLEA ≈ 3.51 imdTEST · no points · sell by 13:46 UTC', with no SUSTAINED stamp or line. The Wall card renders ObjectionStamps.
- **Repro:** On a fork: submit a plea, approve it, object and answer the objection with a score at or below need − 3, then open #/.
- **Live test:** Only if the newest verdict gets a sustained objection during the test. Cosmetic and confusing, not wrong money.

#### r2D-N7: 'Mined but reverted. Nothing was traded' is shown for every kind of write

- **Where:** web/src/context.tsx:520-529
- **Expected:** Trade copy only for swaps; a neutral 'Mined but reverted: nothing changed; only the gas was spent.' for record, object, appeal, close, claim and the rest.
- **Actual:** The same DisplayError for every reverted receipt.
- **Live test:** No (rare).
- **Skeptic:** Code at b214b52, context.tsx:520-529: every reverted receipt throws the same DisplayError, 'Mined but reverted.' / 'Nothing was traded; only the gas was spent.', whatever fn is (record, object, expire, close and so on). Not triggered live. Live test: no.

#### r2D-N8: Profile's buy-record P/L is still unsigned with a hyphen-minus

- **Where:** web/src/profile.tsx:430 (toFixed(1)); #/buy uses signedPercent
- **Expected:** '−18.2%' (U+2212), as on #/buy and in the fact cells (X10/T5 helper).
- **Actual:** 'Now, at 5.74 imdTEST per 1M  -18.2%'
- **Live test:** No.
- **Skeptic:** At 320 px dark, p1's #/profile shows 'Now, at 5.75 imdTEST per 1M' with '-41.8%' (hyphen-minus, from toFixed at profile.tsx:428-430), while #/buy shows '−40.5%' (U+2212). Evidence: r2D-verify/overview.json. Live test: no.

#### r2D-N9: New round-2 copy hardcodes chain values

- **Where:** web/src/context.tsx (denied-letter toast body and Escrowed letter toast add 250000000000000000n for the tip); web/src/chain.ts:717 objectionLine 'no answer within 20 minutes'
- **Expected:** Read every value from chain (brief): Letterbox's tip and Tribunal.PENDING_EXPIRY.
- **Actual:** Literal 0.25 imdTEST and '20 minutes'.
- **Live test:** No (the values match run 9).
- **Skeptic:** 'no answer within 20 minutes' (chain.ts:717) is a literal although Tribunal.PENDING_EXPIRY is a public constant, so that part is confirmed. The tip cannot be read from chain: Letterbox.TIP is an internal constant (Letterbox.sol:115), and the site's models.ts:4 LETTERBOX.TIP is itself a literal. The two 250000000000000000n literals (context.tsx:217 and 611) only duplicate LETTERBOX.TIP and should use it. Values match run 9. Live test: no.

#### r2D-N10: Expire unanswered objection ends with a generic 'Transaction confirmed.' toast

- **Where:** web/src/context.tsx receiptToast (no ObjectionVoid branch)
- **Expected:** Something like 'Objection #2 is void: no answer within 20 minutes. Settle returns the 0.35 imdTEST stake.'
- **Actual:** 'Transaction confirmed. / View transaction'
- **Live test:** No.
- **Skeptic:** Code: the Objections page's TxButton fn='expire' (pages-court.tsx:1647-1653) passes no toast. receiptToast has no ObjectionVoid branch, so it falls through to 'Transaction confirmed.'. The checker's ex2.json shows exactly that toast. My own Expire through the site voided objection #1 on chain, but my script did not capture the toast. Live test: no.

#### r2D-VN2: Profile's 'Now' price is the hourly checkpoint, while #/buy and the header show spot

- **Where:** web/src/profile.tsx:428 (PleaHook.latestPrice) vs web/src/pages-trade.tsx:848 (PleaHook.priceX96)
- **Expected:** One 'Now' price everywhere. If Profile means the scoring price, label it as the hourly snapshot the next plea is scored on.
- **Actual:** At the same moment, 320 px dark: #/profile showed 'Now, at 5.75 imdTEST per 1M -41.8%'. #/buy showed 'Now, at 5.87 imdTEST per 1M −40.5%' and the header showed '1M PLEA = 5.87 imdTEST'.
- **Repro:** Fork: after a buy within the current hour, open #/profile and #/buy for the same wallet.
- **Live test:** No.
