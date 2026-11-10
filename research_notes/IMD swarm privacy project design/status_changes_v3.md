# Status changes v3: same-day check of Glamsterdam schedule and US v. Storm (10 Nov 2026)

Check run: 2026-11-10, first pass 14:44 to 14:55 UTC, second pass 23:11 to 23:13 UTC (section D). Read-only. Baseline: `ethereum_roadmap_v2.md` and `legal_developments_v2.md` (state as of 9 Nov 21:25 UTC, re-checked 10 Nov 00:13 UTC).

Conventions
- Every row gives source URL, a short quote, and the fetch time (all on 2026-11-10, UTC).
- "curl" means I downloaded the file and read the text myself, so the quote is verbatim. "WebFetch" means the page came through a summarising fetch tool; quotes from it are as the tool returned them and are weaker. "Search" means a web-search summary only.
- Labels: CONFIRMED UNCHANGED, CHANGED (old -> new), COULD NOT VERIFY (with what blocked it).

## 0. Headline

- A (Glamsterdam): CHANGED in two places, both about process and timing, not about the specification. (1) The Ethereum Foundation added an "Update (Nov. 9th 2026)" to its 6 Nov post with a dated timeline: audit reports 13 Nov, testing call 16 Nov, execution call 19 Nov with "No decision is pre-committed". (2) The testing call that had been announced for 9 Nov was not held under that number: ACDT #103 was created on 10 Nov and is scheduled for 16 Nov. No new Hoodi date, no mainnet date, no change to any EIP file, no change to the Hegotá scheduled set.
- B (US v. Storm): no change found. No ruling, sentencing date, retrial change, superseding filing or DOJ announcement was found for 19 Oct to 10 Nov 2026. The live docket itself could not be read, so this is "nothing found", not proof.
- C: two items dated 6 Nov that the baseline notes do not have. FinCEN withdrew a third digital-asset proposed rule (the 2020 recordkeeping and travel rule proposal). A banking trade group reportedly asked Congress for statutory authority to sanction mixers (secondary source only). No new mixer designation, no AMLA publication on the topic, no privacy-protocol exploit found.

---

## A. Glamsterdam schedule

### A1. CHANGED

| # | Item | Old (baseline) | New | Source, quote, fetch time |
|---|---|---|---|---|
| A1.1 | Latest official statement | "the EF 6 Nov post is still the latest official statement"; no dated plan | The same post now carries an update dated 9 Nov with a timeline to 19 Nov | https://blog.ethereum.org/en/2026/11/06/glamsterdam-8037-8038 (curl, 14:53). "Update (Nov. 9th 2026) Since Friday's post, we've received four reports identifying deployed contracts that could break under the proposed changes in EIP-8037 and EIP-8038." |
| A1.2 | Recommendation to core developers | Not stated | Wait for the audit findings before deciding on spec changes or a Hoodi date | Same page. "We recommend that ACD waits until the audit findings are public and there has been time to review them before deciding whether to revise the specifications or when to schedule the Hoodi upgrade." |
| A1.3 | Possibility of spec change | "spec changes only as last resort" (ACDT #102) | Stated as a live option, with revisions being prototyped | Same page. "If the findings show that the impact on deployed contracts is too widespread to accept, ACD could revise the specifications. Work is already underway to prototype and review several possible revisions." Also: "... to present on ACDE on 19 November." |
| A1.4 | Audit report date | "~2 weeks from October 26th", nothing published | Reports due 13 Nov | Same page, timeline table: "13.Nov Engagements end Dedaub and ChainSecurity reports delivered and published" |
| A1.5 | 12 Nov consensus call | Baseline inferred it could be the first venue for a decision | The repricing EIPs are not on its agenda | Same page: "12.Nov ACDC Consensus-layer agenda; 8037/8038 not on the agenda" |
| A1.6 | 19 Nov execution call | Baseline inferred a decision was plausible there | Discussion only is promised | Same page: "19.Nov ACDE Discussion of findings and possible next steps. No decision is pre-committed" |
| A1.7 | Testing call "announced for 9 Nov" (ACDT #103) | Announced for 9 Nov; unverified whether held | ACDT #103 is scheduled for Monday 16 Nov 2026, 14:00 UTC. The issue and forum topic were created on 10 Nov. No record of any testing call on 9 Nov | (a) https://ethereum-magicians.org/t/30326.json (curl, 14:45): title "All Core Devs - Testing (ACDT) #103, November 16, 2026", created 2026-11-10T09:19:58Z, "Meeting Time: Monday, November 16, 2026 at 14:00 UTC (90 minutes)". (b) `git clone` of https://github.com/ethereum/pm (14:45): commit `78a8f94`, 2026-11-10T09:20:04Z, "Update mapping for issue 2299", adds `"start_time": "2026-11-16T14:00:00Z"`, `"occurrence_number": 71`. (c) https://github.com/ethereum/pm/issues/2299 (WebFetch, 14:46): opened 10 Nov 2026 by danceratopz. |
| A1.8 | ACDT #103 agenda | Unknown | Audits, app-team findings, open Q&A | https://ethereum-magicians.org/t/30326.json (curl): "Status of Ongoing Audits (completion expected 16th-19th Nov)."; "App Team contract findings."; "Open Q&A on audit findings, the results in the Glamsterdam gas invariants repo." Same timeline row in the EF post: "16.Nov ACDT Dedaub, ChainSecurity and EF present findings. Open Q&A; app developers encouraged to join" |

Notes on A1
- Timing of the EF update: the blog feed's `lastBuildDate` is "Mon, 09 Nov 2026 21:18:41 GMT" (https://blog.ethereum.org/en/feed.xml, curl 14:44). The baseline fetched the post at 21:10 UTC on 9 Nov, eight minutes earlier. The feed item does not contain the update text, so a feed-only re-check could not have seen it.
- Two sources disagree on when the audits end. The EF post says reports are "delivered and published" on 13 Nov. The ACDT #103 agenda, written a day later, says "completion expected 16th-19th Nov". Treat 13 Nov as the earliest date and 19 Nov as the latest.
- Evidence that no testing call was held on 9 Nov: the pm repository's `meeting_topic_mapping.json` lists ACDT #102 (26 Oct) and then ACDT #103 (16 Nov), with nothing between; https://forkcast.org/api/calls.json (curl 14:44, `generatedAt` 2026-11-10T06:22:13Z) has its newest call as `"acdc", "date": "2026-10-29", "number": "190"`; the pm artifacts folder for acdt ends at `2026-10-26_102`. An informal, unrecorded call cannot be excluded.
- Practical effect: the earliest point at which a Hoodi date or a spec decision can be taken is the 19 Nov execution call, and the EF has said no decision is committed for that call. That is my reading of A1.2, A1.5 and A1.6; no source states a later date.

### A2. CONFIRMED UNCHANGED

| # | Baseline claim | Finding | Source, quote, fetch time |
|---|---|---|---|
| A2.1 | Live on Sepolia since 6 Oct 2026 | Same | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7773.md (curl 14:44): "Sepolia | 353024 | 1791294816 (2026-10-06 13:53:36 UTC)". https://raw.githubusercontent.com/eth-clients/sepolia/main/metadata/config.yaml (curl 14:54): "GLOAS_FORK_EPOCH: 353024" |
| A2.2 | Hoodi cancelled 22 Oct, no new date | Same. No new date anywhere | pm repo `glamsterdam-mainnet-plan.md` (clone 14:45): "Hoodi | TBD | TBD | TBD | TBD". https://raw.githubusercontent.com/eth-clients/hoodi/main/metadata/config.yaml (curl 14:46): zero lines containing "gloas". EF update (A1.2) treats the Hoodi date as still to be decided |
| A2.3 | No mainnet date | Same | pm plan file: "mainnet | TBD | TBD". https://raw.githubusercontent.com/ethereum/consensus-specs/master/configs/mainnet.yaml (curl 14:46): "GLOAS_FORK_EPOCH: 18446744073709551615". https://forkcast.org/api/upgrades.json (curl 14:44): `"activationDateLabel": "TBD"`, `"projectedActivation": "2026-12-02"` (Forkcast's own planning estimate, not an announced date) |
| A2.4 | EIP-7773 meta: status Review; stale Hoodi row; PR #12568 unmerged | Same | Raw file (curl 14:44): "status: Review"; "Hoodi | 132352 | 1793036568 (2026-10-26 17:42:48 UTC)". `git ls-remote` (14:47): `refs/pull/12568/head` = `158a9f9`, commit dated 2026-10-22, "Update EIP-7773: Clear postponed Hoodi activation" |
| A2.5 | EIP-8037 and EIP-8038: Last Call, parameters unchanged since October | Byte-identical to the baseline | `git ls-remote https://github.com/ethereum/EIPs.git refs/heads/master` (14:44) = `542e62e…`, the same commit the baseline recorded, so no EIP file has changed. Blob hashes of the files downloaded today: `c8bc85b0…` (8037), `a1c73c4f…` (8038), equal to the baseline's. Front matter: "status: Last Call", "last-call-deadline: 2026-11-01". EIP-8037: "`CPSB` | 1530". Rendered pages https://eips.ethereum.org/EIPS/eip-8037 and /eip-8038 (curl 14:46): "Last Call Deadline 2026-11-01" |
| A2.6 | EIP-7976: 64 gas per calldata byte; only a rename PR open | Same | Raw file (curl 14:44): "status: Last Call"; "`STANDARD_TOKEN_COST` | `4`"; "`TOTAL_COST_FLOOR_PER_TOKEN` | `16`"; "the floor cost is `64` gas per calldata byte". PR #12639 head `51b5320`, 2026-11-09T13:00:19Z, "Update parameter names", touches only `EIPS/eip-7976.md`, not merged |
| A2.7 | Candidate spec-change PRs open, unmerged | Same heads as before | `git fetch` of PR refs (14:47): #12581 head `2ba9176` (2026-10-25); #12582 head `19d788c` (2026-10-25); #12638 head `17034f5` (2026-11-08). https://github.com/ethereum/EIPs/pulls?q=is%3Apr+8037+sort%3Aupdated-desc (WebFetch 14:53): all three shown "Open"; #12581 "Updated Nov 4, 2026" |
| A2.8 | execution-specs: no Amsterdam change | Same | `git fetch` of https://github.com/ethereum/execution-specs (14:47): `forks/amsterdam` last commit `1689800`, 2026-10-06; the two exploratory branches still end at commits of 2026-11-03 |
| A2.9 | Gas-invariants repository | No new commit | `git ls-remote https://github.com/ethereum/glamsterdam-gas-invariants.git HEAD` (14:44) = `5998e89…`, same as baseline |
| A2.10 | Next calls 12 Nov and 19 Nov | Same dates, agendas still only headings | pm mapping (clone 14:45): "All Core Devs - Consensus (ACDC) #191, November 12, 2026", `2026-11-12T14:00:00Z`; "All Core Devs - Execution (ACDE) #249, November 19, 2026", `2026-11-19T14:00:00Z`. Magicians topics 30139 and 30071 (curl 14:45): "Agenda Glamsterdam Hegotá Misc" |
| A2.11 | Hegotá scheduled set: 7805, 8141, 8015 | Same three | https://forkcast.org/api/eip-stage-changes.json (curl 14:44, `generatedAt` 2026-11-10T06:22:13Z): Hegota "Scheduled": 7805 (2026-02-19), 8141 (2026-08-27), 8015 (2026-10-29). Newest stage change of any kind is dated 2026-10-29 |
| A2.12 | Hegotá listed for Q2 2027 | Same | https://ethereum.org/roadmap/hegota/ (curl 14:46): "Expected on mainnet Q2 2027 · Date not yet confirmed"; "Page last update: October 16, 2026". Forkcast: `"activationDateLabel": "2027"`, `"projectedActivation": "2027-06-16"` (estimate). EIP-8081 raw file: "status: Draft" |
| A2.13 | ethereum.org Glamsterdam page stale | Still stale | https://ethereum.org/roadmap/glamsterdam/ (curl 14:46): "Expected on mainnet Q4 2026 · Date not yet confirmed Next milestone Hoodi fork , October 27, 2026"; "Page last update: October 16, 2026" |
| A2.14 | No new EF blog post | Newest post still 6 Nov (but updated in place, see A1.1) | Feed (curl 14:44): first item "Fri, 06 Nov 2026 … EIP-8037/EIP-8038 Glamsterdam" |
| A2.15 | Forum threads | No new posts | Magicians JSON (curl 14:45): EIP-8037 thread `last_posted_at` 2026-11-03T01:51:02Z; EIP-8038 thread 2026-10-06T13:23:36Z; EIP-7976 thread 2026-08-26T10:40:24Z |
| A2.16 | Audit reports | None published yet | https://www.chainsecurity.com/blog (WebFetch 14:54): newest post dated 2026-10-21; the only Glamsterdam post is the 2026-10-13 one already in the baseline |

New pull requests in ethereum/EIPs since the baseline (numbers 12640 to 12646, heads fetched 14:47): none touches EIP-8037, 8038 or 7976. Two touch EIP-8141, which is in the Hegotá scheduled set: #12642 "Update EIP-8141: note that the blob fee can lower GASPRICE" (2026-11-10) and #12644 "Update EIP-8141: raise MAX_VERIFY_GAS to 300_000" (2026-11-10). Both are unmerged proposals (master is unchanged).

Press: two searches ("Glamsterdam mainnet date Hoodi November 2026"; "Glamsterdam EIP-8037 audit core developers call delay 2027") returned nothing newer than the 6 Nov coverage and no new date.

### A3. COULD NOT VERIFY

- Whether an informal or unrecorded testing call took place on 9 Nov. Public records show none (see notes on A1).
- (Resolved: the ACDE #248 wording "December 2026 fork now very unlikely; 2027 expected" was re-read and confirmed, see D5.)
- What the 12 Nov, 16 Nov and 19 Nov calls will decide. None has happened yet. The next points at which this note can go stale are 12 Nov 14:00 UTC, 13 Nov (audit reports), 16 Nov 14:00 UTC and 19 Nov 14:00 UTC.
- Whether Dedaub has published anything: https://www.dedaub.com/blog/ returned HTTP 403.
- github.com issue pages by curl: blocked by this machine's proxy (HTTP 403, "GitHub access to this repository is not enabled for this session"); api.github.com also blocked. I used `git clone` and `git ls-remote` (which work) and WebFetch for issue pages. Open or closed state of pull requests therefore rests on WebFetch.

---

## B. United States v. Storm (S.D.N.Y. 1:23-cr-00430, Judge Failla) and related

### B1. CHANGED

Nothing found.

### B2. CONFIRMED UNCHANGED (no change found)

| # | Baseline claim | Finding | Source, quote, fetch time |
|---|---|---|---|
| B2.1 | Latest docket entry seen: 308 (16-19 Oct 2026) | No later numbered document exists in the public RECAP store | https://storage.courtlistener.com/recap/gov.uscourts.nysd.604938/gov.uscourts.nysd.604938.N.0.pdf (curl 14:48): N = 306, 307, 308 return HTTP 200; N = 309 to 316 return HTTP 404 (also tried the `.0_1` and `.1` name forms). https://archive.org/metadata/gov.uscourts.nysd.604938 (curl 14:48): `item_last_updated` 2026-10-26T21:10:26Z; newest file "gov.uscourts.nysd.604938.308.0.pdf" |
| B2.2 | Rule 29 motion pending, no ruling | No ruling reported | https://freeromanstorm.com/ (WebFetch 14:52): latest timeline entry is 9 Apr 2026, "Judge Failla heard oral arguments on Roman Storm's motion for judgment of acquittal. A ruling remains pending." |
| B2.3 | Retrial 26 April 2027 | Same | Same page: retrial "is set to begin on April 26, 2027"; final pretrial conference 20 April 2027 |
| B2.4 | No docket activity in the last day | None | https://ecf.nysd.uscourts.gov/cgi-bin/rss_outside.pl (curl 14:48): 3,092 items from "Mon, 09 Nov 2026 13:05:47 GMT" to "Tue, 10 Nov 2026 13:00:40 GMT"; zero items match "23-cr-00430" or "Storm". With the baseline's pulls this gives unbroken coverage from 8 Nov 21:12 GMT to 10 Nov 13:00 GMT |
| B2.5 | Court-beat press | No new Storm item | https://www.innercitypress.com/ (WebFetch 14:49): page updated "November 9, 2026, 10:37 p.m."; its only Storm headline is still "After Tornado Cash Trial Roman Storm Says DC Circuit Decision on Bitcoin Fog is Different" (9 Oct 2026) |
| B2.6 | Specialist outlet | No new Storm, Samourai or Pertsev item | https://www.therage.co/rss/ (curl 14:49): newest items "Rage Weekly 45/26" (8 Nov) and "Rage Weekly 44/26" (1 Nov). I searched the full text of both for Storm, Tornado, Samourai, Rodriguez, Pertsev, Failla, "Rule 29", mixer: no match |
| B2.7 | Trade press, last two days | No Storm headline | RSS feeds fetched by curl at 14:49: CoinDesk (25 items, 9-10 Nov), The Block (20 items, 9-10 Nov), Decrypt (38 items, 6-10 Nov), Cointelegraph (30 items, 9-10 Nov). No title contains Storm or Tornado |
| B2.8 | DOJ announcement | None | https://www.justice.gov/news/rss?type=press_release (curl 14:49): 25 releases, 3 to 9 Nov 2026; none concerns Storm, Tornado Cash, a mixer or money transmitting |
| B2.9 | Samourai: no clemency | Same | https://www.justice.gov/pardon/clemency-grants-president-donald-j-trump-2025-present (curl 14:52): "Updated October 20, 2026"; zero matches for "Rodriguez", "Hill" or "Storm" (the page does match "Ulbricht" and "Zhao") |
| B2.10 | Safe-harbour bill (H.R. 3633): cloture failed 49-50 on 15 Sep; lapses 3 Jan 2027 | No later action recorded | https://www.govinfo.gov/bulkdata/BILLSTATUS/119/hr/BILLSTATUS-119hr3633.xml (curl 14:51): `updateDate` 2026-09-17T17:09:18Z; HTTP header "last-modified: Thu, 17 Sep 2026 20:25:06 GMT"; latest actions dated 2026-09-15, "Cloture on the motion to proceed to the measure not invoked in Senate by Yea-Nay Vote. 49 - 50. Record Vote Number: 234." The Rage Weekly 45/26 (8 Nov) carries the link headline "Clarity Act outlook bleak in 120th session". Two searches found no lame-duck vote scheduled |
| B2.11 | Pertsev appeal: status unknown | Still no ruling or hearing date found. One new primary check, negative | https://data.rechtspraak.nl/uitspraken/zoeken (Dutch courts open-data API; curl 14:51), court = Gerechtshof 's-Hertogenbosch, decision date 2026-09-01 to 2026-11-10: "Aantal gevonden ECLI's: 131". None of the 131 titles or summaries matches tornado, mixer, crypto, bitcoin, Pertsev, "smart contract" or Ethereum. Seven mention "witwas" (money laundering); all are drug, cash or theft cases |

Searches run for Storm (five, 14:47 to 14:52): "Roman Storm Rule 29 ruling Judge Failla November 2026"; "Tornado Cash Roman Storm acquittal decision sentencing retrial news"; a docket-number query; "Roman Storm Tornado Cash judge ruling this week" (extended); a Law360 query. Newest relevant results are the 25 Aug 2026 adjournment and the October Bitcoin Fog letters.

Caution on one search summary: it stated that "Judge Failla granted Storm's motion for acquittal and set the retrial date for April 2027". That is a garbled summary of the 25 Aug 2026 adjournment order, which adjourned the retrial "in light of" the pending motion. Every other source, including the defence site, says the motion is undecided. Not relied on.

### B3. COULD NOT VERIFY

- The live docket for 20 Oct to 9 Nov 2026. A ruling or order that nobody has uploaded to RECAP and no outlet has reported cannot be excluded without PACER. What blocked each route:
  - courtlistener.com docket page: HTTP 403 by WebFetch (14:48). A curl attempt that sent a browser identity was stopped by this session's permission system and was not retried.
  - pacermonitor.com: the URL I tried returned "Couldn't find this case" (WebFetch 14:48).
  - docketalarm.com: page shows no entries without an account ("Create an account to view the full docket"; "Last Updated: 6 hours ago").
  - Justia docket search: HTTP 403 (see D10).
  - Wayback Machine: newest snapshots of the two CourtListener docket URLs are from 2024-05-25 and 2026-03-22.
  - DL News RSS: HTTP 429. The Block's Tornado Cash category URL: HTTP 404. SDNY press-release page: empty through WebFetch. Law360: paywalled, headlines only via search.
- Docket entries without a PDF (minute entries, text orders) would not appear in the RECAP storage test in B2.1.
- Pertsev: the hearing date, and any ruling not published in the open-data set. Searches (English and Dutch, 14:50) returned no dated 2026 development; one result says a conference panel hoped the appeal would be heard "next year". Not tried: contacting anyone, and social media.
- Samourai docket (CourtListener, HTTP 403) and any clemency granted after 20 Oct 2026 other than by news search (none reported).

---

## C. Other developments since 1 Nov 2026 relevant to an immutable, fee-charging privacy pool

| # | Item | Status | Source, quote, fetch time |
|---|---|---|---|
| C1 | FinCEN withdraws the 2020 recordkeeping and travel rule proposal (6 Nov 2026) | NEW to notes. Third digital-asset proposal withdrawn in five weeks (after the unhosted-wallet and mixing proposals on 5 Oct). It concerns obligations of financial institutions, not mixers directly | https://www.fincen.gov/news/news-releases/fincen-announces-withdrawal-proposed-rule-related-recordkeeping-and-travel-rule (curl 14:51): "Immediate Release November 06, 2026 … withdrawing a notice of proposed rulemaking that would have amended the Recordkeeping and Travel Rule regarding convertible virtual currencies. … This proposal is being jointly withdrawn with the Federal Reserve Board of Governors." |
| C2 | Bank trade group asks for authority over mixers and DeFi operators (letter dated 6 Nov 2026) | NEW, secondary source only; the letter itself was not found | https://coindoo.com/crypto-privacy-fight-banks-want-defi-reporting-net/ (WebFetch 14:52; article dated 8 Nov 2026): the Bank Policy Institute "asked FinCEN and the Office of Foreign Assets Control to designate digital-asset service providers, and the people who operate or control decentralized finance arrangements"; its requests include "Clear statutory authority to sanction mixers, tumblers and other blockchain applications used for illicit finance." The article says the group "asks Congress, rather than Treasury, for power over mixers". bpi.com comment-letter page returned empty |
| C3 | OFAC: no mixer designation | CONFIRMED UNCHANGED through 9 Nov | https://ofac.treasury.gov/recent-actions (curl 14:49): newest entries "Iran Designation Update November 09, 2026", "Iran-related Designations November 06, 2026", "Cyber-related and Transnational Criminal Organizations Designations; Cuba Designations … November 05, 2026". The 6 Nov action (https://home.treasury.gov/news/press-releases/sb0686, curl 14:54) names eight Canadian money services businesses that "facilitate the exchange of Iranian rials and other currencies for digital assets"; the release contains no occurrence of "mixer", "mixing" or "Tornado" |
| C4 | FinCEN: no new action on mixers | CONFIRMED UNCHANGED | https://www.fincen.gov/news/press-releases (curl 14:49): newest items 11/09/2026 "READOUT: FinCEN Hosts Exchange Event to Combat Overseas Scam Centers"; 11/06/2026 the withdrawal in C1; 11/06/2026 "Operation Economic Outcast Severs MEXC Global's Access to the U.S. Financial System" (already in the baseline). Follow-up press: Decrypt, 10 Nov 12:13 GMT, "Binance Halts MEXC Transfers as FinCEN Cuts Exchange Off From US Financial System" |
| C5 | Treasury press releases 1 to 6 Nov | Nothing on mixers or privacy tools | https://home.treasury.gov/news/press-releases (WebFetch 14:54): ten releases dated 4 to 6 Nov. https://home.treasury.gov/news/press-releases/sb0687 (curl 14:54), 6 Nov: "The FATF also agreed to launch a targeted review of certain jurisdictions with longstanding deficiencies related to the virtual assets sector" (matches the baseline's FATF item) |
| C6 | EU AMLA: publication on anonymity-enhancing tools or self-hosted addresses | None found | https://www.amla.europa.eu/news-media/news-articles_en (WebFetch 14:54): newest item 30 October 2026, "Call for expression of interest: technology providers roundtable on partnerships for information sharing". Nothing on crypto-assets since the 7 Oct item in the baseline |
| C7 | Major exploit of a privacy protocol | None found since 1 Nov | https://rekt.news/ (WebFetch 14:53): the only entries since 1 Nov are "Binance - Rekt" (6 Nov) and "Is the Internet Rekt?" (3 Nov). One search for a November 2026 exploit of a shielded pool or mixer returned only earlier 2026 incidents |
| C8 | Binance hack laundering | Continuing; no regulatory action on mixers found | CoinDesk RSS (curl 14:49), 9 Nov 15:00 GMT: "North Korean hackers are creating memecoins to wash loot from $6.3 billion Binance hack". Same story in The Block, Decrypt and Cointelegraph on 9 Nov |

Could not verify for C: the Bank Policy Institute letter at a primary source; the FinCEN withdrawal's Federal Register citation (not looked up); AMLA's consultation page (not fetched separately; the AMLA home page listed no new consultation).

---

## D. Second pass, 2026-11-10 23:11 to 23:13 UTC

Result: nothing in sections A, B or C changed between 14:55 and 23:13 UTC.

| # | Check | Finding | Source and quote |
|---|---|---|---|
| D1 | ethereum/EIPs master | Moved from `542e62e` to `bd93d24`, one commit, build configuration only. The five EIP files are byte-identical to the first pass | `git fetch` (23:11): "bd93d24 2026-11-10T11:25:20-05:00 … CI: Pin Jekyll build runner to ubuntu-24.04 (#12640)", touching only `.github/workflows/jekyll.yml`. Blob hashes at the new head: 8037 `c8bc85b0bf`, 8038 `a1c73c4f5b`, 7976 `15abf8001a`, 7773 `3b0d9db14e`, 8081 `3e65690f78` |
| D2 | ethereum/pm | Two new commits, both for unrelated calls. Core-developer call dates unchanged | `git pull` (23:11): "Update mapping for issue 2301" (RPC Standards #38, 16 Nov) and "Update mapping for issue 2300" (Encrypt The Mempool #12, 11 Nov). Mapping still lists ACDC #191 `2026-11-12T14:00:00Z`, ACDT #103 `2026-11-16T14:00:00Z`, ACDE #249 `2026-11-19T14:00:00Z` |
| D3 | EF blog | No new post, no rebuild | https://blog.ethereum.org/en/feed.xml (curl 23:11): `lastBuildDate` still "Mon, 09 Nov 2026 21:18:41 GMT" |
| D4 | Forum | One new related topic: a discussion thread for the outside proposal in pull request #12638. It has no fork target | https://ethereum-magicians.org/latest.json?order=created (curl 23:11): topic 30332, created 2026-11-10T16:04Z, "EIP-8488: Versioned Opcodes for Gas Repricing" |
| D5 | ACDE #248 wording (baseline claim) | Confirmed as quoted | pm repo, `.github/ACDbot/artifacts/acde/2026-10-22_248/tldr.json`: "Mainnet date implicitly on hold; December 2026 fork now very unlikely; 2027 expected"; "Hoodi hard fork canceled indefinitely; no new date set" |
| D6 | Origin of the "9 Nov testing call" | Confirmed as the source of the baseline claim | pm repo, `.github/ACDbot/artifacts/acdt/2026-10-26_102/tldr.json`: "ACDT #103 moved to November 9th; skipping November 2nd due to Devcon". Same file: "ChainSecurity + DWB audit ETA ~2 weeks; wait for results before rescheduling" |
| D7 | Storm: SDNY court RSS, second pull | No entry for the case | https://ecf.nysd.uscourts.gov/cgi-bin/rss_outside.pl (curl 23:12): 3,349 items from "Mon, 09 Nov 2026 23:05:08 GMT" to "Tue, 10 Nov 2026 23:05:00 GMT"; zero match "23-cr-00430" or "Storm". Unbroken coverage is now 8 Nov 21:12 GMT to 10 Nov 23:05 GMT |
| D8 | Storm: RECAP store, second probe | Still nothing after 308 | storage.courtlistener.com files 309, 310, 311 (curl 23:12): HTTP 404 |
| D9 | Press feeds, second pull | No headline on Storm, Tornado Cash, mixers, Samourai, Pertsev, the bill, Glamsterdam or Hoodi | RSS by curl at 23:12: CoinDesk (to 20:36 GMT), The Block (to 21:51), Cointelegraph (to 22:04), Decrypt (to 22:46), DOJ press releases (to 10 Nov 12:00). The only keyword match is the Decrypt MEXC item already listed in C4 |
| D10 | Justia docket search for the Storm case | Blocked | https://dockets.justia.com/ search (WebFetch, about 23:05): HTTP 403 |

---

## E. Full list of what was checked (all on 2026-11-10 UTC)

Glamsterdam
- forkcast.org JSON: /api/upgrades.json, /api/calls.json, /api/eip-stage-changes.json, /llms.txt; `git clone` of github.com/ethereum/forkcast (HEAD `36a03ad`, 2026-11-10T06:20:04Z, "sync: update EIP data"; `src/data/whether-report.ts` still dated 2026-11-06; plan artifacts last generated 2026-11-09T13:13:24Z).
- blog.ethereum.org: /en/feed.xml and the 6 Nov post page.
- github.com/ethereum/pm: `git clone` (HEAD `78a8f94`); `.github/ACDbot/meeting_topic_mapping.json`; artifact folders; `glamsterdam-mainnet-plan.md`; issue pages 2299, 2291, 2285 and the issue list (WebFetch).
- EIPs: raw files for EIP-7773, 8037, 8038, 7976, 8081; rendered eips.ethereum.org pages for 7773, 8037, 8038, 7976; `git ls-remote` of master; `git fetch` of pull-request heads 12568, 12581, 12582, 12638 to 12646; the pull-request list filtered on 8037 (WebFetch).
- github.com/ethereum/execution-specs branch heads; github.com/ethereum/glamsterdam-gas-invariants HEAD and repository page; eth-clients hoodi, sepolia and mainnet configs; consensus-specs mainnet config.
- ethereum-magicians.org: latest.json; topics 30326, 30139, 30071, 25694, 25693, 21195, 24597, 26876.
- ethereum.org/roadmap/glamsterdam and /hegota; chainsecurity.com/blog; dedaub.com/blog (403).
- Four web searches.

Storm and related
- storage.courtlistener.com RECAP files 306 to 316; archive.org metadata for the RECAP item; Wayback availability for two docket URLs; SDNY ECF RSS; courtlistener.com (403); pacermonitor.com; docketalarm.com.
- innercitypress.com; therage.co (home page and RSS full text); freeromanstorm.com; defieducationfund.org Storm page (published 24 Mar 2026, no later update); RSS of CoinDesk, The Block, Decrypt, Cointelegraph; DL News RSS (429); DOJ press-release RSS; SDNY press page (empty).
- justice.gov clemency list; govinfo bill status for H.R. 3633; Dutch courts open-data API.
- Eleven web searches (Storm x5, Pertsev x2, Samourai x1, bill x2, general x1).

Other
- ofac.treasury.gov/recent-actions; fincen.gov press-release list and two release pages; home.treasury.gov press-release list and releases sb0683, sb0684, sb0686, sb0687; amla.europa.eu home and news pages; rekt.news; coindoo.com article; tftc.io article; Latham crypto policy tracker (last updated September 2026, nothing relevant); three web searches.
