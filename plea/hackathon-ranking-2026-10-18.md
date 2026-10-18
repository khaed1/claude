# IMD hackathon: where PLEA and imd/acc stand (2026-10-18, ~08:00 UTC)

All 37 entries on imdradar.site/hackathon, plus PLEA and imd/acc (not submitted yet), scored on the 100-point rubric of IMD's own hackathon proposal (Identity-md/research, job `e9efec16`, `report.md`). IMD Radar's hackathon file calls those "the proposed rules"; the organizers have not confirmed the dates or the network list.

## How the judging is supposed to work
- **Agents (55 points):** working functionality and reproducible deployment (A, 20), technical quality, security checks and disclosed risks (B, 15), depth of meaningful IMD integration (C, 20).
- **Humans (45 points):** originality and creative use of IMD (D, 20), user value, adoption potential and ecosystem benefit (E, 25). Market cap, price and followers earn nothing by themselves.
- **Process:** agents check eligibility and shortlist 10 finalists; a jury of three ranks the top 5 from them; agents rank places 6–15. Ties go to IMD integration, then functionality.
- **Eligibility (proposal):** a working token project launched through IMD during the build period (5–19 Oct) **on an organizer-approved network**; a v4 hook or meaningful custom contract; an IMD-dependent feature with code, addresses and transaction evidence; a project X account **and a personal X account**; a public repo with build/test steps, addresses, demo, risks/admin powers and a payout wallet; reused code disclosed.
- **Deadline:** 19 Oct 00:00 UTC in the proposal. The form takes contracts on Ethereum, Base or Robinhood Chain only and pays prizes to the contract's deployer.

## What was checked
- Each entry's text, and its contract matched to IMD's launch registry (`api.imd.fun/launches`, 757 launches).
- On-chain use of every product contract (97 contracts; Ethereum via Blockscout, Robinhood Chain via its RPC): events, transactions, distinct wallets.
- Who calls IMD's oracle: requests to the Intake and Intake v2 on both chains, mapped to launches.
- Market data from IMD Radar and Dexscreener (context only, no points).

## The ranking (my estimate)

| # | Project | Chain | A | B | C | D | E | Total | Evidence |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| 1 | keelpad_imd | ETH | 18 | 10 | 17 | 15 | 22 | **82** | Launchpad where trading pays for the next swarm build. KeelNotes NFT: about 400 minters, and KEEL (#1972): about 400 traders, both since last night. Launches #1233, #1716, #1801, #1972, #2007. |
| 2 | SinopiaMD | RH | 16 | 12 | 20 | 19 | 14 | **81** | #1942. One full round on chain: a bid, the contract pays Intake v2 for an image job, the callback arrives, the NFT is minted. The developer made the only bid. |
| 3 | **PLEA** | Sepolia | 11 | 15 | 20 | 19 | 14 | **79** | Seven IMD launches, but only on Sepolia. Runs 2–4 had real IMD verdicts, approved pleas and gated sales. 8 audit rounds, 5 One Dollar Audits, 852 tests. Every plea is a paid oracle question. |
| 4 | pupateIMD | ETH | 15 | 13 | 19 | 17 | 15 | **79** | #1434. Hook: 130 events. Cocoon vault: 25 events. About 114 traders. Seat price from an oracle attestation; seats work through ERC-1271. |
| 5 | PawnIMD | ETH | 11 | 13 | 19 | 17 | 19 | **79** | #1139. Deployed, but no loan yet: PawnShop has seen only the developer, and FloorRelay has never been used. A strong idea for seat holders. |
| 6 | pinkybond_fun | RH | 15 | 13 | 18 | 18 | 15 | **79** | #1166 and #1840. One promise settled with the oracle callback. The vault has 11 transactions from 3 wallets. |
| 7 | marginalia_md | ETH | 16 | 11 | 18 | 18 | 14 | **77** | #1283 and #1467. The hook has about 200 transactions. The developer and MarginaliaPages both ask the oracle. MARG has about 318 traders. |
| 8 | **imd/acc** | ETH + RH | 13 | 13 | 18 | 14 | 17 | **75** | #1409, #1495, #1529 (ETH) and #1537, #1561 (RH). Ownerless, with one registry oracle request on RH. Only 0.01 IMD is stacked: no project pays cashback on mainnet yet. |
| 9 | HarvestIMD | ETH | 15 | 12 | 15 | 14 | 18 | **74** | #1029. One demo transaction harvested 40 launch rewards. Nobody else has used it yet. |
| 10 | IMDhongbao | RH | 15 | 14 | 13 | 15 | 16 | **73** | #1815. A demo packet was opened. 4 audits plus a judge. Packets in IMD with a 0.5% burn. |
| 11 | imdusd (INFER) | ETH | 12 | 11 | 15 | 14 | 20 | **72** | #1282. INFER is live (about 309 traders, 90 stakers). The imdUSD vault itself is not deployed. |
| 12 | IMDBlackout | RH | 18 | 13 | 10 | 15 | 15 | **71** | #1710 plus 6 more launches. The game hook has 663 transactions. The game itself uses little IMD. |
| 13 | perkshireimd | RH | 12 | 12 | 17 | 15 | 11 | 67 | #1660. A hook vault with an IMD burn and a weekly oracle answer. Almost no trades. |
| 13 | IMD6900 | ETH + RH | 12 | 11 | 14 | 15 | 15 | 67 | #1604, #1615, #1639. SDK on npm. Barely used. |
| 15 | pepe2pepe_fun | ETH | 13 | 9 | 14 | 14 | 15 | 65 | #1918. Games are live (17 wallets). The P2P token is not trading yet. |
| 16 | imdplace | RH | 13 | 10 | 14 | 15 | 12 | 64 | #1033. About 67 traders. The hook has 4 events. |
| 16 | Quantum_Canary | ETH | 14 | 12 | 8 | 18 | 12 | 64 | #1235 and #1797. The hook has about 150 transactions. No contract in the form. Little IMD use. |
| 16 | PlayCourierWld | RH | 16 | 10 | 9 | 13 | 16 | 64 | Busy game (STAMP: over 10,000 events), but not launched through IMD (the swarm only audited it). |
| 19 | weirpay | RH | 12 | 9 | 16 | 14 | 11 | 62 | #1780 and #1869. Weir v1 asked the oracle on chain. The entry is three sentences long. |
| 19 | Pepesdotfamily | RH | 15 | 8 | 13 | 10 | 16 | 62 | Launchpad token with 1,019 transactions from 114+ wallets. Fees paid in IMD. |
| 21 | Musefren | ETH | 13 | 10 | 14 | 13 | 11 | 61 | #1245. The hook pays a seat-NFT holder. 9 hook events. |
| 22 | pfwafun | RH | 10 | 11 | 14 | 15 | 10 | 60 | #1389. The launcher is idle. No contract in the form. |
| 23 | Pixel_Pool | ETH | 15 | 10 | 8 | 15 | 10 | 58 | #1118. 40 swaps painted. IMD is only the pair. |
| 24 | AgentCityrh | RH | 12 | 7 | 12 | 13 | 13 | 57 | Sends jobs to IMD agents. Its token (96+ wallets) is not an IMD launch. |
| 25 | swarmpepes | ETH | 15 | 8 | 9 | 12 | 12 | 56 | #1040. Busy hook, about 297 traders. One-line entry. |
| 25 | stockroom | ETH | 12 | 10 | 11 | 11 | 12 | 56 | #1513. Only the developer has used it. |
| 27 | Numosimd | RH | 14 | 8 | 11 | 11 | 11 | 55 | #864 and #874. About 170 numbers claimed with IMD. |
| 28 | agentskill_imd | ETH | 10 | 9 | 12 | 12 | 11 | 54 | #1739. Only the developer has used it. |
| 29 | bunkervaultapp | ETH | 11 | 11 | 6 | 14 | 11 | 53 | Not an IMD launch. Two wallets. |
| 30 | jawaisme | ETH | 10 | 8 | 11 | 13 | 10 | 52 | Not an IMD launch. Only the developer has used it. |
| 31 | SovrnIMD | RH | 13 | 8 | 9 | 12 | 8 | 50 | #1205. The hook has 68 transactions from 36 wallets. The entry is lore only. |
| 32 | ArewaOS26 | Base | 11 | 10 | 6 | 12 | 9 | 48 | #1926. Reads IMD balances only. |
| 32 | imd_offset | ETH + Base | 12 | 7 | 8 | 11 | 10 | 48 | Launches #1370 to #2051. Busy token. Vague entry. |
| 34 | tungweb3 | ETH | 10 | 6 | 9 | 11 | 9 | 45 | #944. Standard token. The entry asks questions instead of pitching. |
| 35–39 | neethome_rh, 0xCompanyIMD, Illuminatico, IaMaDamIMD, xmrscn | | | | | | | 20–31 | A meme token, one-line or vague entries, and one idea with nothing built. |

How sure is this? Within one cluster the order is a coin toss. Ranks 3–6 differ by less than any judge's taste. The clusters themselves are solid: about 12 strong entries, then a gap of 4 points or more.

## Where we land
- **PLEA: best guess 3rd–8th.** In the cluster it ties at 79 and wins the tie on IMD integration, the first tie-break. It has the best technical record in the field: the audits, 852 tests, the threat model and the findings ledger. Its IMD integration is the deepest (C 20), with Sinopia the only other entry at that level, and its idea is one of the most original. **The one big risk: it has no contract on an approved network.** If the agents read "on an organizer-approved network" strictly, A falls to about 6 and PLEA drops to 9th–12th, or out of the 15 if they apply the rule as a filter. The jury may also see sell gating as user-hostile. **Most likely prize: $500–$750.** A top-3 place ($1,000+) is possible but not the base case.
- **imd/acc: best guess 6th–12th.** It is live and ownerless on two chains and integrates sIMD, the oracle and the bridge. The weak point is adoption: 0.01 IMD stacked and no paying project on mainnet. A top-5 place is unlikely. **Most likely prize: $500.**

## Risks we can still reduce
1. **Copies of PLEA on Ethereum mainnet:** launches #1609 (13 Oct), #1728 (14 Oct) and #2090 (17 Oct) are plain tokens named PLEA, all paid by `0xee2aaa315cf7ed169f93148d30d24af9318dbb66`. #1609 and #1728 name imdacc.fun as their site. An agent that looks up "PLEA" in IMD's registry finds three plain ERC-20s on chain 1 and none of ours, so it could mistake one of them for PLEA.
2. **No proof list in the README.** It names the Sepolia runs but gives no transaction links for real verdicts and sales, and the agents want "transaction evidence".
3. **Personal X account:** the form marks it optional, but the proposal requires it for the lead developer.
4. **Payout:** imd/acc's three mainnet contracts were deployed by IMD's factory (`0xff03410d0fe5fa8f7f59f743de35e333d9857120`), so a contract-only payout would go to IMD. Both texts need a real payout wallet in place of `0x000…`.
5. **The deadline is likely tonight (19 Oct 00:00 UTC),** and an entry can't be edited after it is published.

## Recommendation
Submit both entries **today**, as drafted, with three changes:
- the personal X handle on both;
- real payout wallets in both texts;
- a short **"Proof on chain"** block in the PLEA README before submitting (the entry links the repo).

The block would hold:
- run 2's approved plea #1 (score 34) and its gated sale `0xf83a2448d3bc4c210f2477b1e5a59328352baf3712d1ab621c155ddfd74946be`;
- plea #2's auto-sale `0x6a4eae4a3b9ba88fb742022b8a635b6d3dc06c048e065402ffaede027e82ca35`;
- a denied plea and an upheld appeal;
- run 8.5's attested hashes;
- one line: "PLEA has no mainnet token yet; launches #1609, #1728 and #2090 are copies."

**Don't rush the mainnet launch for the hackathon.** It would need START, a fresh owner wallet, the launch job, the keeper bot and the site in a few hours, for at most a few hundred dollars more.
