# IMD Goals and network state, re-verification v2 (fetched 9-10 Nov 2026)

Read-only re-check of what changed since the notes of 3-8 Nov 2026 (`imd_multisig_feature.md`, `imd_pages_fetched.md`,
`imd_and_swarm_tech.md` Part 1, `cost_inputs.md`). Nothing was signed, posted, submitted or sent. Two fetch passes:
**9 Nov 2026, 21:09-21:22 UTC** (main pass) and **10 Nov 2026, 00:13 UTC** (refresh). Each fact carries a source key and
the date it was fetched.

## Source keys

| Key | URL | Notes |
|---|---|---|
| DOCS | https://imd.fun/docs/llms.txt (Markdown of https://imd.fun/docs/ and https://imd.fun/docs/api/) | 158,265 bytes on both days; line numbers refer to this file |
| CAP | https://api.imd.fun/requests/capabilities | paid actions |
| HEALTH | https://api.imd.fun/health | control-plane status |
| JOBS | https://api.imd.fun/jobs?exclude=oracle&limit=200 (paged with `before=`) | public job list |
| W | https://github.com/Identity-md/worker/releases/download/worker-v0.1.16-3850b8948cda/identitymd-worker.tgz , file `package/dist/cli.js` | sha256 `2a39b67454ee53cb3f54f852eb75b24a002d9022fd5da511dd727dae47c13f78` matches the release's SHA256SUMS; byte-identical to `dist/` on `main` of https://github.com/Identity-md/worker (commit b78c70a). Inspected as data, nothing executed |
| RN | git history of `RELEASE_NOTES.md` in https://github.com/Identity-md/worker (one commit and one tag per build; tag pages are https://github.com/Identity-md/worker/releases/tag/worker-v<version>-<12 hex>) | read from a clone; the github.com HTML pages return 403 through this session's proxy |
| README | `README.md` in W (same file as https://raw.githubusercontent.com/Identity-md/worker/main/README.md) | 16,236 bytes |
| T1 | https://api.imd.fun/jobs/91efa16d-c8cf-4989-aac8-9d42a93c0ee2 and https://api.imd.fun/goals/91efa16d-c8cf-4989-aac8-9d42a93c0ee2 | first owner-action test goal |
| T2 | https://api.imd.fun/artifacts/a62fa7d945bc8d28f767fc255aa591b1068370b532ba158b0e3ad622aea8cf35 (write-up of goal https://api.imd.fun/goals/baa553fe-1019-4f21-8dc4-e862e0d48622) | second owner-action test goal |
| STATUS | https://explorer.imd.fun/status | explorer counters |
| DEX | https://api.dexscreener.com/latest/dex/tokens/0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7 | IMD pools |
| OS | https://opensea.io/collection/identitymd | read through WebFetch (page summary by a small model) |
| RPC | https://ethereum-rpc.publicnode.com , https://base-rpc.publicnode.com , https://robinhood-rpc.publicnode.com (`eth_call`, `eth_getStorageAt`, `eth_getCode`) | read at Ethereum block 26,380,015 (0x19286cf), 9 Nov 2026 |
| SRC | https://sourcify.dev/server/v2/contract/1/<address>?fields=all | verified sources and ABIs |
| ES | https://etherscan.io/address/<address>#code | read through WebFetch (curl returns 403) |

## A. Has Goals shipped? What is the current worker?

**Verdict: partly shipped.** Goals as large research or compute jobs run by the operator are live and public. The custody
half (mandates, owner actions, juries, paid goals, budget escrow, earnings epochs) is in the code but switched off, has no
documentation, no published contract address, and its first public test on Sepolia produced no transaction.

Live:
- "goal" is a public job template. 42 goal jobs were listed between 27 Oct and 9 Nov 21:10 UTC (37 completed, 2 executing,
  2 cancelled, 1 blocked); 33 of the 42 were opened 5-9 Nov, and 3 more were opened later on 9 Nov (45 by 10 Nov
  00:13 UTC). Most are attempts at Paradigm's puzzle boards. [JOBS, 9 and 10 Nov]
- The largest running goal had 235 nodes worked by 229 distinct seats. [https://api.imd.fun/jobs/cc45e1a7-047f-45d9-a5df-0b65be9cc03c , 9 Nov]
- Every goal inspected has `"paidBy": null`: they are opened by the operator, not bought. The operator can stop one:
  `"blockedReason": "stopped by the operator: cancelled at the operator's request"`. [T1 and three other `/jobs/:id`, JOBS, 9 Nov]
- Goal objectives, item results, orchestrator decisions and write-ups are public (`/jobs/:id/result`, `/artifacts/<hash>`)
  and are delivered to https://github.com/Identity-md/research . Orchestrator decision files carry the keys `notes`,
  `spawn`, `read`, `cancel`, `wake`, `finish`, and sometimes `pause`, `resume`, `ask` (75 decision files read). [JOBS + artifacts, 9 Nov]
- Undocumented public routes exist: `GET /goals/:id` (state, batches, episodes, judge, write-up) and
  `GET /goals/:id/actions` (returned `{"goal":"…","actions":[]}` for every goal tried). [https://api.imd.fun/goals/91efa16d-c8cf-4989-aac8-9d42a93c0ee2/actions , 9 Nov]
- HEALTH exposes `goalPlanners` (`"ladder":{"lead":5,"orchestrate":8,"value":20}`, `"qualified":{"lead":270,"orchestrate":15,"value":1}`,
  `"orchestratedGoals":4`) and timers named `goals`, `effects`, `chainActions`, `datasets`, `rewardLines`. [HEALTH, 10 Nov]
- The home page is rendered with `{"goals":true}` and its script polls for jobs with `"goal"===e.template&&"executing"===e.state`. [https://imd.fun/ and https://imd.fun/_next/static/chunks/6275-f88833de9c407733.js , 9 Nov]

Not live:
- Docs: the only two mentions of goals are "Venice and OpenRouter models only work on goals, the big jobs the swarm
  splits across many agents." (line 45) and "Only goals that ask for Venice use it" (line 311). The words mandate, jury,
  multisig, keeper, custody do not occur. `https://imd.fun/goals`, `/docs/goals`, `/docs/multisig`, `/skill/goals.md`,
  `/sitemap.xml`, `https://explorer.imd.fun/goals` are 404. [DOCS, 9 and 10 Nov]
- Paid actions are unchanged, eight of them: `job.open, job.continue, launch.open, oracle.request, oracle.group,
  workflow.open, schedule.create, schedule.topup`. No `goal.open` or `goal.topup`. [CAP, 10 Nov]
- `job.open` templates: "`single`, `impl_tests`, `impl_tests_review`, `multi_contract`, `fuzz`, `research`, `audit`" (line 695). No `goal`. [DOCS, 10 Nov]
- "Contract wallets such as a Safe are not supported yet." is still in the docs (line 603). [DOCS, 10 Nov]
- Jury lane: `GET https://api.imd.fun/jury/keys/793` returns `{"error":"not_found","detail":"the jury lane is off (JURY_LANE)"}`. [10 Nov]
- Earnings epochs: `GET https://api.imd.fun/earnings/epochs` returns `{"error":"not_found","detail":"earnings epochs are off on this control plane (GOAL_EARNINGS_ENABLED)"}`. [10 Nov]
- Worker: `var JUROR_CANONICAL=Object.freeze({});` and a juror refuses with "this release names no juror root on chain
  ${draw.chainId}, so it signs nothing there". The juror signer is "off unless you turn it on". [W, 9 Nov]
- Worker: buyback, distribution and vesting intents refuse with "it compiles only to the canonical management contracts
  (BuybackRouter, OwnerMerkleDistributor, VestingWallet), which wait for their audit (CANONICAL_CONTRACTS names no
  ${contract} on chain ${context.chainId})". [W, 9 Nov]
- No address is public for a custody Safe, JuryExecutor, JurorRoot, beacon, BudgetEscrow or any canonical owner contract
  (not in DOCS, W, CAP, HEALTH or the explorer pages). [9 Nov]

First public test of the custody path (Sepolia, 9 Nov):
- T1, created 2026-11-09T20:38:55Z: "Test of owner actions (mode 0) on Sepolia, chain 11155111. The goal's owner,
  0x047f606fd5b2baa5f5c6c4ab8958e45cb6b054b7, owns launch 551 on the IMD launch factory
  0x1721d7ae9c2bba9be52a316578c91295605c00fc … The owner signs this goal the mandate
  0xc0ca84c41d2e67866dec18175e0fa7f61c884ce9bde887ab23022fa5a3eb1f9c, which allows exactly one call: claimFees(551) on
  that factory." It ended `blocked`: "the orchestrator's last 3 episodes failed" (nine runs failed with
  "artifact unavailable: b01-intent-1"). [T1, 9 Nov]
- T2, created 2026-11-09T21:58:19Z, completed 22:12Z. Its write-up: "The test did not produce a transaction." All three
  attempts were "refused by the plane before compilation" with "item_b01_0001's intent has 0 of the 2 distinct holders it
  needs (1 replicas, 0 counted)". The write-up's table gives "Mandate mode | 0 (the owner sends from their own wallet)",
  "Mandate quorum | 2", "Mandate expiry | 2026-12-09T21:59:56.000Z", "Mandate scope | target 0x1721…00fc, function
  `claimFees(uint64)`". [T2, 10 Nov]
- 0x047f…54b7 is surfsurf.eth, the developer's deployer wallet (prior notes). The tests are the operator's own.

### Worker version and changes since 0.1.12

- Current: **0.1.16+3850b894**, commit dated 2026-11-09T18:19:36Z, tag `worker-v0.1.16-3850b8948cda`. No newer commit at
  10 Nov 00:13 UTC. [W `build.json`; RN, 10 Nov]
- Control plane: `0.1.0+80d6a6a7` on 9 Nov, `0.1.0+69117c07` on 10 Nov. The docs footer still reads "Last checked against
  control plane `3b96b1cc` on 2026-10-01. Running now: `6890b418`." [HEALTH; DOCS line 2676]
- Where the notes went: nowhere. README: "Every release page lists what changed since the previous one, and
  `RELEASE_NOTES.md` in this repository is the same text for the current build." The 333-byte file is the note for the last
  build only (a dependency pin). The full history is the git history of that file: 150 commits, 150 tags. [README; RN, 9 Nov]

Release notes after 0.1.12+df310a90 (4 Nov 04:15), quoted from RN (9 Nov):

| Build (UTC) | Notes that matter here |
|---|---|
| 0.1.13+e2656771 (4 Nov 16:53) | "a goal-chain task, a goal's intent item, runs jailed with chain-only egress"; "a contributor lends tasks their own Etherscan, Dune or Brave Search key with imd data" |
| 0.1.13+48c1bcfc (4 Nov 17:45) | "Goals: an ask decision puts a question to the oracle through its own door, with … a panel that excludes the author" |
| 0.1.14+212b225e (4 Nov 19:26) | jail hardening only |
| 0.1.15+c344ba4f (4 Nov 21:39) | "Worker: the juror signer, off by default: a keychain-only key, holder-signed registration, check-then-sign"; "Protocol: a mode 1 scope names its executor, a hello may report its juror key, and checkActionDraw checks a drawn action"; "Protocol: the intent compiler and the simulation judge move into the protocol, so a juror's daemon runs the plane's own"; "Protocol and worker: a jury's scope pins everything it could direct value with, on chain as off" |
| 0.1.15+e63fe50a (4 Nov 23:24) | "imd rpc setup fills Ethereum, Base and Robinhood Chain from one key, checks each, and asks about goal jobs" |
| 0.1.15+5315b319 (4 Nov 23:50) | "Plane: buyback, distribution and vesting intents compile to the canonical owner contracts once CANONICAL_CONTRACTS names a chain"; "Worker: a goal item stops at its cost cap, and every receipt carries what its run cost" |
| 0.1.15+553b7590 (5 Nov 01:52) | "an oracle result may carry the answer's version 1 signature beside version 2" |
| 0.1.15+8bb77c84 (5 Nov 15:23) | "Paid goals: goal.open and goal.topup pay a goal's own BudgetEscrow account, the goal seats nothing once its units are spent, and its payer's signed stop ends it, behind PAID_GOAL_ENABLED"; "Paid goals: dry earnings epochs publish what each seat earned as plane-signed IPFS documents an outside party rebuilds from IPFS alone, behind GOAL_EARNINGS_ENABLED=dry"; "Paid goals: an earnings epoch excludes its largest payees from its juries, leaves out accounts refunded or due a refund, comes an hour after a stop, and a void epoch frees its units (solidity-auditor)"; "Paid goals: the plane reads stops and refunds from the escrow, refuses a quote into an account stopped on chain, stops a goal its payer stopped on chain, and checks PAID_GOAL_ESCROW against the escrow at boot (solidity-auditor, 1 pass)"; "Plane: the escrow's twin reads bondDue, and the anvil test deploys BudgetEscrow linked to its BudgetJury library" |
| 0.1.16+18543036 (5 Nov 22:56), +d3143025 (6 Nov 04:26) | fix-step and Mac jail changes |
| 0.1.16+89159ae2, +86c49021, +6b1a2333 (8 Nov) | "Workers and the verifier refuse a test whose inline config could start a program"; "Workers and the verifier refuse a foundry.toml that names an external compiler"; "Verifier and workers on Foundry 1.9.0" |
| 0.1.16+c9de2ee5 (9 Nov 05:24) | "Base's pair token reads IMD" |
| 0.1.16+3850b894 (9 Nov 18:19) | "pin @noble/curves back to 1.9.1, the version the juror signer is written against" |

New CLI text in W (9 Nov): "imd jury     The juror signer (off unless you turn it on): this machine signs owner actions
as one drawn juror, after checking each one itself. Its key lives only in the OS keychain; every change of it is signed by
the wallet that holds your seat, and every task here then runs jailed. Needs your own RPC (imd rpc add) and anvil."
Sub-commands: `imd jury`, `enable`, `register`, `rotate [--finish]`, `remove`, `disable`. The text cites
`docs/jury-signer.md`, which is not in the public repository.

## What the shipped code now defines (W, 9 Nov; schemas inside `dist/cli.js`, no separate schema files in the tarball)

- **Two mandate modes.** `var MANDATE_MODES={owner:0,jury:1};`. Mode 0 per T2: "the owner sends from their own wallet".
  Mode 1: "a jury's scope names the JuryExecutor on the account's Safe (jury.executor)"; "a jury's executor is a module of
  the account, never the account itself".
- **Mandate (EIP-712).** Domain `name:"IdentityMD Mandate", version:"1", chainId, verifyingContract: account`. Type
  `ChainMandate{mandateId bytes32, goal string, account address, mode uint8, scopeHash bytes32, scopeUri string,
  valuePerDay uint256, approvalAbove uint256, quorum uint8, notBefore uint64, expiresAt uint64, issuedAt uint64, nonce
  uint256}`; `quorum` is 1 to 7; "a mandate ends after it starts, at most 90 days after it was signed". Signer may be a key
  or a contract: "the owner's mandate signature does not verify, by key or by the account (ERC-1271)". There are also
  `MandateRevokeMessage{mandateId, issuedAt, nonce}` and `ActionApprovalMessage{actionHash, mandateId, decision 1|2, …}`.
- **Scope.** As on 4 Nov (targets ≤16, functions ≤16 each, arg rules eq/oneOf/lte/gte/avatar, allowances, spenders ≤8,
  recipients ≤16, gas budget), plus `jury:{executor}`. Forbid list unchanged.
- **Extra rules under a jury** (`juryScopeProblem`): "a jury moves no native value: its Roles scope cannot bound ETH sent
  until it carries an ether allowance"; an address argument left free is refused: "under a jury it is pinned with eq,
  oneOf or avatar, or a colluding jury could pay itself"; a bytes32 argument: "under a jury it is pinned with eq or oneOf"
  (only a vesting salt is exempt); any other non-integer, non-bool type: "which no rule can pin yet: under a jury every
  argument that could direct value is pinned on chain".
- **Intent compiler** (`compileIntents`, `compileOne`): the same eight kinds as on 4 Nov. They compile only to
  `claimFees(uint64)`, `withdraw(address,address)`, `setRequester(uint64,address)` on a launch factory, ERC-20
  `transfer`/`approve`, a native send to a listed recipient, and the canonical `buyback(…)`, `observe(…)`,
  `openRound(address,bytes32,uint256,uint64)`, `createVesting(…)`. `lp.adjust` "is not compiled yet". Anything else:
  "no compiler for ${intent.kind}". There is no generic "call this function on that contract" intent.
- **Simulation judge** (`judgeSimulation`): verdict `failed` on a revert; `outside` on findings such as "an undeclared
  outflow of ${…} of ${delta.asset} from the account" or "an undeclared native-ETH outflow"; otherwise `within`.
- **Jury** (constants and functions): `JURY_MAX_SIZE=255`; `juryParamsValid(size,threshold)` requires
  `threshold>=1&&threshold<=size5&&size5<=JURY_MAX_SIZE&&3*threshold>=2*size5`. Juror root = Merkle tree of clusters
  (one per `holderKey`), each a tree of seats `{tokenId, jurorKey, holder}`. A draw takes distinct clusters, then one seat
  per cluster, from `keccak(tag, seed, key, j)`, with `key = keccak(chainId, executor, "act", nonce, commitment, attempt)`
  and `seed = beacon.seedOf(round)`.
- **Executor ABI the worker reads:** `avatar()`, `jurorRoot()`, `beacon()`, `jurySize() uint16`, `threshold() uint16`,
  `nonce()`, `roundOf(uint8)`, `live()`; juror root `current()` returns `(index, (root, clusterCount, seatCount, activeAt,
  contentHash, acceptedAt))`; `execute(action, attempt, jurors[])` where each juror is `(position, seatId, holder,
  clusterId, seatCount, r, vs, seatProof[], clusterProof[])`; event `Executed(uint64 indexed nonce, bytes32 indexed
  action, bytes32 mandate, uint64 epoch, uint64 round, uint256 jurors)`.
- **Juror approval (EIP-712):** domain `name:"IdentityMD Jury", version:"1", verifyingContract: executor`; type
  `JuryApproval{action, mandate, nonce, epoch, round, expiresAt, excluded}`; signature sent as compact `r`, `vs`.
- **Juror's own checks** (`checkAndSign`, `checkActionDraw`): own RPC required ("a juror reads and simulates on its
  own"), the executor is read again on a second endpoint, the root content is fetched from the plane at
  `/jury/roots/${contentHash}` and must rebuild to the on-chain root, the owner's signature is verified, intents are
  recompiled and must equal the draw's calls, item authors must be excluded ("${entry.item}'s author ${holder} is not
  excluded from its jury"), the action is simulated on a fork, and a daily cap applies (`dailyCap:200`).
- **Juror key:** registered per seat with an EIP-712 `JurorKeyChange{tokenId, action register|rotate|remove, jurorKey,
  keyStorage keychain|hardware, wallet, nonce, issuedAt, relayOrigin}` signed by the holder wallet and sent to the plane
  (`/jury/keys/${tokenId}`). "It sits on juries once the next juror root includes it."
- **Earnings document** (new): `EARNINGS_DOCUMENT_FORMAT="imd-earnings@1"`, `EARNINGS_RULE="per_unit@1"`;
  `EarningsUnit{nodeId, submissionHash, wallet, tokenId, amount}`; `EarningsAccount{account bytes32, jobId, payer, salt,
  unitAmount, deposited, debitedBefore, debit, units[]}`; document fields `escrow`, `asset` (an address), `cutoff`,
  `challengeEndsAt`, `previous{epochId,cid}`, `fee{bps,recipient}`, `accounts` (≤256), `lines`, `total`, `payoutRoot`,
  `debitsHash`, `excluded{holders,clusters}`, `release{mode: "dry"|"funded"}`.
- **Unchanged:** custody table (Safe 1.4.1, MultiSend, Zodiac Roles v2, ModuleProxyFactory, Multicall3,
  DelegationManager on chains 1, 4663, 8453, 11155111), `imd-epoch@1` with `funding.by: treasury_safe|budget_escrow` and
  `EPOCH_CHALLENGE_WINDOW_MS=72*60*6e4`, `KEEPER_RECIPES=["fees.claim","fees.withdraw","router.forward","router.buy",
  "distributor.sweep","gas.topup"]`.
- **Absent from W:** `BudgetEscrow`, `BudgetJury`, `goal.open`, `refund`, `bls`, `multisig`, `payroll`, `fundrais`,
  `surfsurf`, any goal-level `watch` schema (grep counts 0; "watch" matches only the RPC library).

## B. The 12 developer questions

Status key: **answered** = a public primary source settles it; **partly** = shipped code or a test artifact shows the
design, but no doc, no deployed contract and no developer statement confirms it; **not answerable** = nothing public.
All "W" answers describe code that is switched off today.

| # | Question | Status | Answer | Quote | Source (fetch date) |
|---|---|---|---|---|---|
| 1 | Who picks the jury and the Safe owners; on-chain seat registry or control plane? | Partly | The jury does not own the Safe. The owner keeps ownership; the jury acts through a JuryExecutor module under a scope. Jurors are drawn per action from an on-chain Merkle root of seats and a beacon seed, one seat per holder cluster, authors excluded; any holder of the root content can recompute the draw. The root's content (seat list, `holderKey` clustering) is assembled off chain from holder-signed key registrations sent to the plane, and is served by the plane. Who may post a root on chain is not public. In the code read, the juror checks that the content rebuilds to the on-chain root; no check against `ownerOf` on the seat NFT was seen. In mode 0 there is no jury: `quorum` counts distinct seat holders behind an intent, counted by the plane. | "a Safe's owners are the owner's alone"; "the draw does not seat this juror's key at position ${draw.position}"; "the root's content is not the content the chain's root commits to"; RN 0.1.11: "Plane: a draw is for a commitment already on chain, and a pending root's cancel jury is drawn too"; T2: "0 of the 2 distinct holders it needs" | W (9 Nov); RN (9 Nov); T2 (10 Nov) |
| 2 | One custody Safe, or a Safe and escrow per goal? Can an outside wallet create a goal with its own mandate? | Partly | A mandate is per goal and per account: the account is the owner's own (a wallet in mode 0, a Safe with a JuryExecutor in mode 1), not one protocol Safe. Budget is one BudgetEscrow contract holding one account per goal and payer. Outside creation is designed (`goal.open`, `goal.topup`, payer's signed stop) but not offered: no such paid action, and the four goals inspected have `paidBy: null`. | `ChainMandate{… goal, account, mode …}`; "goal.open and goal.topup pay a goal's own BudgetEscrow account … behind PAID_GOAL_ENABLED"; `EarningsAccount{account, jobId, payer, salt, …}` | W, RN (9 Nov); CAP (10 Nov); T1 (9 Nov) |
| 3 | Where do the mandate check and simulation run? Can a third party recompute "outside the mandate"? | Partly | Mode 0: on the plane (T2: "refused by the plane before compilation"). Mode 1: also on each drawn juror's machine, with its own RPC and a local fork. The scope check, intent compiler and simulation judge are functions in the public worker bundle, so a third party holding the signed mandate, its scope, the intents and chain state can rerun them. Limits: the bundle is minified and marked `"license": "UNLICENSED"`, there is no written spec, some inputs (`handoffs`, `neverPaid`, `held`) are supplied by the plane, and no public route serves a mandate or action today. | "the intent compiler and the simulation judge move into the protocol, so a juror's daemon runs the plane's own"; "a juror reads and simulates on its own"; "the scope is not the one the owner's scopeHash binds" | RN, W (9 Nov); T2 (10 Nov) |
| 4 | Per-signer Safe check or aggregated threshold signature? Is 100 of 150 fixed? | Partly (clear in code; contract not public) | Neither Safe's owner check nor an aggregate. A separate executor contract takes one ECDSA signature per juror (compact `r`, `vs`) with two Merkle proofs each. No BLS anywhere in the bundle. Size and threshold are per-executor parameters: size at most 255, threshold at least two thirds of size. 100 of 150 is the lowest threshold allowed for 150. A juror also enforces a per-chain floor, not yet set. Gas cost cannot be checked without the contract. | `3*threshold>=2*size5`; `JURY_MAX_SIZE=255`; `execute(action, attempt, jurors[])` with `r`, `vs`, `seatProof`, `clusterProof`; "the executor's jury is ${chain.jurySize}/${chain.threshold}, under the ${…floor.size}/${…floor.threshold} this juror signs for" | W (9 Nov) |
| 5 | Scope limited to one function on a third-party contract? Can a goal hold an ENS name? | Partly | A scope can name exactly one target and one function (the test mandate does). But no intent kind compiles to a call on an arbitrary contract, so a third-party function cannot be reached today. Under a jury, a free `bytes32` argument is refused, so a jury could not submit a new root value each day unless the owner pinned each value in the scope. ENS: nothing public. | T1: "which allows exactly one call: claimFees(551) on that factory"; W: "no compiler for ${intent.kind}"; "leaves argument ${arg} (a bytes32) free: under a jury it is pinned with eq or oneOf" | T1 (9 Nov); W (9 Nov) |
| 6 | Custom watch-and-wake on an outside contract, or built-in keeper recipes only? | Not answerable (partly observed) | The public decisions wake only on batches settling or a timer. Test objectives say "set no watches", so a watch decision exists, but its schema is in neither docs nor the worker. What is shown: a goal can put typed oracle questions about any contract's events to a panel. Keeper recipes are the same six. | `"wake": {"batches": ["fee-claim"]}`; `"wake": {"batches": […], "afterMinutes": 240}`; ask: "How many Deposit(address indexed dst, uint256 wad) events did WETH9 … emit in the window?" with `"panelSize": 7` | decisions under https://api.imd.fun/jobs/985d7221-b6fb-420d-8d06-3cfd7204206d/result and 10 other goals, 75 files (9 Nov); W (9 Nov) |
| 7 | Can an outside goal fund its own budget escrow and pay per accepted item? What does the 72-hour challenge check against? | Partly | Designed: a payer funds a goal's account in the escrow in an ERC-20 `asset`; seats are paid per accepted unit (`per_unit@1`), each unit tied to a node and a submission hash, with an optional fee in bps. Each epoch is a plane-signed IPFS document "an outside party rebuilds from IPFS alone", with a `challengeEndsAt`, a payout root, and juries that exclude the largest payees. The on-chain challenge procedure and the escrow source are not public. Not running. | RN 0.1.15+8bb77c84 (quoted in section A); `EarningsUnit{nodeId, submissionHash, wallet, tokenId, amount}`; API: "earnings epochs are off on this control plane (GOAL_EARNINGS_ENABLED)" | RN, W (9 Nov); https://api.imd.fun/earnings/epochs (10 Nov) |
| 8 | Deploy a contract from the Safe, reproducibly, with no EOA deployer? | Not answerable | No intent deploys a contract, and the forbid list bars the Safe and multicall paths a deployment would need. Launches still go through one wallet. | DOCS line 2534: "Launch deployer … The only wallet either factory takes a launch from, on every chain."; W: "a Safe transaction is an arbitrary call" | DOCS (10 Nov); W (9 Nov) |
| 9 | Rollout timeline; will the Safe address, mandate schema and jury rules be published first? | Not answerable | No timeline found. State: three feature flags off, no juror root named, owner contracts "wait for their audit", two Sepolia mode-0 tests on 9 Nov without a transaction. The mandate schema and jury rules are readable in the worker bundle but not documented. No custody Safe address is published. | "the jury lane is off (JURY_LANE)"; T2: "The test did not produce a transaction." | https://api.imd.fun/jury/keys/793 (10 Nov); T2 (10 Nov) |
| 10 | Canonical audited Safe, Roles, escrow? Will IMD-specific contracts be audited? | Partly | The custody table lists the standard Safe 1.4.1 and Zodiac Roles v2 addresses (unchanged since 4 Nov). The code says the IMD owner contracts (BuybackRouter, OwnerMerkleDistributor, VestingWallet) wait for an audit before any chain is named. The release notes tag escrow changes "(solidity-auditor)"; what that is, is not stated. No auditor, report or commitment for BudgetEscrow, BudgetJury, JuryExecutor or the juror root is public. | "which wait for their audit (CANONICAL_CONTRACTS names no ${contract} on chain ${context.chainId})"; "(solidity-auditor, 1 pass)" | W, RN (9 Nov) |
| 11 | Can the escrow pay an off-chain counterparty on milestones? Can the jury amend the mandate? | Partly | Escrow: no, its document pays seat wallets per accepted unit only. Paying an outside address is done from the owner's account under a mandate: token moves to addresses in `recipients` (at most 16), a Merkle distribution, or a vesting to a pinned beneficiary with start, duration and cliff. There is no milestone primitive, and a jury moves no native ETH. Amendment: the jury cannot. Only the owner signs a mandate (90 days at most) or revokes one; a new scope means a new mandate. | "${to} is not a recipient the mandate lists"; "a jury moves no native value"; "ownership is the owner's alone"; "Zodiac Roles administration is the owner's alone"; `MandateRevokeMessage` | W (9 Nov) |
| 12 | Can a goal raise ETH from outside contributors? Rules, refund, token or receipt? | Not answerable (refund path partly) | Nothing public describes a raise from several contributors. An escrow account belongs to one `payer`; the asset field is a token address, not native ETH; a refund path exists for that payer after a stop and a delay. No token or receipt appears in any schema. | "the plane reads stops and refunds from the escrow … stops a goal its payer stopped on chain"; "the plane reads the escrow's refund delay with its settings" | RN, W (9 Nov) |

## C. Numbers

| Measure | 3 Nov 2026 (notes) | 8 Nov 2026 (notes) | 9 Nov 2026, ~21:15 UTC | 10 Nov 2026, 00:13 UTC | Source for 9/10 Nov |
|---|---|---|---|---|---|
| Agents (seats that have submitted work) | 1,136 | not recorded | 1,148 | 1,149 | STATUS; https://api.imd.fun/seats/records (`count` 1148, 9 Nov) |
| Online | 913-921 | not recorded | 882 (header: 888) | 871 | STATUS |
| Connected daemons | not recorded | not recorded | 1,047 | 1,047 | HEALTH `connectedDaemons` |
| Working | 8 | not recorded | 66 (API: 74-83) | 118 (API: 116-131) | STATUS; HEALTH `workingNow`; https://explorer.imd.fun/api/activity |
| Jobs | 6,570 | not recorded | 6,876 (6,510 done, 364 incomplete) | 6,883 (6,515 done) | STATUS |
| Oracle entries | 9,012 | not recorded | 9,257 (8,704 signed) | 9,257 (8,704 attested) | STATUS; https://api.imd.fun/oracle/counts |
| Paid orders | 7,489 (4 Nov) | not recorded | 7,898 | 7,899 | HEALTH `payments.orders.paid` |
| Seat floor (ETH) | 0.796 | 0.74999999 | 0.72999899999999 | 0.699999 | OS |
| Seat floor in USD at the day's ETH price | not recorded | ~1,669 | ~1,553 (ETH 2,126.92) | ~1,493 (ETH 2,132.23) | computed; ETH from https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd |
| Owners | 792 | 792 | 794 (OpenSea); 795 (chain) | 795 | OS; https://api.imd.fun/seats/owners (`holders` 795, 9 Nov) |
| Items | 1,999 | 1,999 | 1,999 (OpenSea); 2,000 (chain) | 1,999 | OS; RPC `totalSupply()` = 0x7d0 |
| IMD price (USD, main Uniswap v4 pool) | not recorded | 2.60 | 2.24 (24h -9.94%) | 2.64 (24h +17.57%) | DEX |
| Market cap, DexScreener | not recorded | 10,968,133 | 9,435,005 | 11,115,915 | DEX `marketCap` |
| FDV, DexScreener | not recorded | 10,973,558 | 9,466,639 | 11,130,143 | DEX `fdv` |
| Main pool liquidity (USD) | not recorded | 1,281,550.66 | 1,161,501.02 | 1,266,553.41 | DEX, pair 0xb07d640f… |
| Main pool 24h volume (USD) | not recorded | 133,632.67 | 334,395.84 | 445,921.95 | DEX |
| IMD supply on Ethereum | not recorded | not recorded | 4,205,374.90 | not re-read | RPC `totalSupply()` on 0xd34a99bc… |
| IMD supply, three chains | ~7.1M (Sep, KuCoin) | not recorded | 7,081,201.74 | not re-read | computed, see below |

Supply working (RPC, 9 Nov 21:21 UTC): Ethereum `totalSupply` 4,205,374.90; Robinhood Chain `totalSupply` 73,196.12 on
0x5F7Bb593…7127; Base `totalSupply` 7,081,325.71 on 0xFF0C532F…E105, of which 4,278,694.99 sits in the bridge adapter
0xab152db8…690A. Outstanding = 4,205,374.90 + 73,196.12 + (7,081,325.71 - 4,278,694.99) = 7,081,201.74 IMD.
DexScreener's market cap equals the price times the Ethereum supply only (9,435,005 / 2.24 ≈ 4.21M). Price times the
three-chain supply is about $15.9M at $2.24 and about $18.7M at $2.64. These two figures are my arithmetic, not a quoted
source. The sIMD vault 0x9efa934d…7247 held 1,985,266.54 IMD (RPC `balanceOf`, 9 Nov).

Other counters (STATUS, 10 Nov): "Published 1,685 shipped 936 contracts 749 sites"; "Updates 789 of 871 on latest";
"Steps 97% accepted 1,571 in 24h". Newest launch number 3166 (https://api.imd.fun/launches?limit=1 , 9 Nov; it was 2978 on
4 Nov). Seat NFT transactions 7,834 (ES, 9 Nov; 7,813 on 3 Nov).

CoinGecko does not list the token: `https://api.coingecko.com/api/v3/coins/ethereum/contract/0xd34a99bc…63b7` returns
`{"error":"coin not found"}`, and a search for "identity.md" returns only "Identity.md 6900" (IMD6900), a different
token (9 Nov). GeckoTerminal (https://api.geckoterminal.com/api/v2/networks/eth/tokens/0xd34a99bc…63b7 , 9 Nov) still names
it "Vibe Coins (VIBE)": price 2.2186, FDV 9,240,915.92, main pool reserve 1,154,693.08.

## D. Extra tools, and running a third-party process on a seat

The README still has the Tools section, unchanged since 0.1.12 (only the RPC section changed, in commit 94c125a of
4 Nov). [README; RN diff, 9 Nov]

> "Some skills need a tool installed on your machine: `create-image`, `create-video` and `create-audio` need a tool
> declared as `image`, `video` or `audio`, and video work also needs `ffmpeg` and `ffprobe` on `PATH`. Website steps go
> first to machines with a `browser` tool, such as Playwright MCP. A tool is a stdio MCP server you have already
> installed. Declare it with `imd tools add`, which asks what kind of tool it is, where it is installed, which variables
> it needs and which of its methods a task may call."

> "Keys stay on this machine in `~/.identitymd/tools.env`, readable by your user alone, or in the shell that runs the
> worker; the network learns only the tool's id."

CLI help in W adds: "imd tools    Tools installed here that skills may ask for: an image generator, a video encoder, an RPC
client with your own key." and "imd tools add             add one, question by question (asks the server what it offers)".
So the kinds of tool come from the control plane's list, and a tool is called by a task, not exposed to the outside.

Nothing in the worker lets a seat run an outward-facing third-party process:
- "No inbound port is needed: the worker connects to the IdentityMD control plane over WSS." [README]
- Every local helper binds to loopback: RPC ("each task gets an address of its own on 127.0.0.1 that only reads"), data
  keys, Venice and OpenRouter ("The key stays here behind 127.0.0.1"). [README; W]
- The only outward publication is a static site served by the network, not a process on the seat: "A paired machine can
  publish its owner's static site under the network's name: `imd site publish ./dist --name alice`". [README]
- The juror signer is an outbound polling loop (`JURY_LOOP_INTERVAL_MS=6e4`) against the plane's `/jury/claims` and
  `/jury/draws/:id/approvals`. [W]

Conclusion: a third-party service is "run it beside the worker" as its own process. What it can reuse is the seat's
on-chain identity (seat NFT `ownerOf`, the ERC-8004 agent bound through the adapter), not anything the worker hosts.
Running beside a juror machine has a cost: with the signer on, "every task here then runs jailed", and the CLI warns the
key is not protected "from other programs you run as this user".

## E. Other changes that affect a third party building on seats

Contract verification and control (ES and SRC read 9 Nov; RPC at block 26,380,015):

| Contract | Verified | Control | Notes |
|---|---|---|---|
| Seat NFT 0x0000ec93127baa929e58e97dd0095a2bfb38ec1d | Etherscan "Source Code Verified", Exact Match, `IdentityMD`, solc 0.8.26; Sourcify match since 2026-05-14 | `owner()` returns 0x4e59b44847b379578588920ca78fbf26c0b4956c, the CREATE2 deployment proxy it was created through (69 bytes of code). The constructor runs `_initializeOwner(msg.sender)`. The owner-only setters (`setIdentityAllowed`, `setEpoch`, `setUniv4Hook`, `setUniv4Pool`) therefore have no key behind them | Not a proxy. `totalSupply()` 2,000. "No Contract Security Audit Submitted". 7,834 transactions |
| ERC-8004 adapter 0xde152afb7db5373f34876e1499fbd893a82dd336 | Etherscan Exact Match as `ERC1967Proxy`; implementation `AdapterImplementation` at 0x3d74ff0c1E0A78C5a291fA91F82f15bd54335231, Sourcify exact match verified 2026-10-19 | Upgradeable (UUPS): `_authorizeUpgrade(address newImplementation) internal view override onlyOwner`. `owner()` returns 0x03302df40186d9b85faea4fbb6cc5da028b23149, a Safe proxy: `getOwners()` returns four addresses, `getThreshold()` returns 3 | Creator 0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF, not surfsurf.eth; proxy created at block 24,821,152 (Sourcify record dated 2026-04-06), before IMD's May mint. Source comment: "The adapter proxy owns the identity token; the binding determines who can manage its record." `@custom:version 0.0.17`; uses the delegate.xyz v2 registry. It reads as a general adapter that IMD uses. 4,530 transactions. "No Contract Security Audit Submitted" |
| WorkRegistry 0xb6d0a187b050fa5bb0b87033a203f37becf4a775 | Etherscan Exact Match, `WorkRegistry`, solc 0.8.26; Sourcify match since 2026-10-12 | `admin()` = 0x047f606fd5b2baa5f5c6c4ab8958e45cb6b054b7 (surfsurf.eth, no code); `writer()` = 0x5da3054201bc7e241875ac68173e49c269f76d44 (no code). `setAdmin`, `setWriter` exist | Not a proxy; registries are immutable. 10,314 transactions. "No Contract Security Audit Submitted" |

- The docs line "None of the sources are verified on the explorers yet." (line 2468) is out of date for these three, and
  Sourcify also holds matches for the IMD token, Intake v2, LaunchFactory, ProjectFactory and LaunchFees. [DOCS, 10 Nov; SRC, 9 Nov]
- No ownership has moved to a Safe on mainnet: `owner()` of the IMD token 0xd34a99bc…, Intake v2 0xa43e6f75…,
  IntakeDelivery 0xce0e6a67… and LaunchFees 0x12c9e100… is 0x047f…54b7, an address with no code. The launch deployer,
  Intake payee and fee recipient also have no code. The "custody Safe" of the 3 Nov release note is not visible on chain. [RPC, 9 Nov]
- Audits: none found. Etherscan shows "No Contract Security Audit Submitted" on all three. [ES, 9 Nov]
- Incidents: none found since 3 Nov, but the search index returned no November coverage at all, so this is weak. The
  explorer status page read "All 15 checks passing". The tokens page lists "SIMD TEST - DO NOT BUY" and "SIMD TEST 2 - DO
  NOT BUY" ("Can take a fee on each trade", 2-3 days old), which look like operator tests. The 8 Nov worker builds close
  ways a task's repository could start a program on a worker or the verifier (quoted in section A); no incident is named. [STATUS, https://explorer.imd.fun/tokens , RN, 9 Nov]
- Goal work is fully public, down to each item's author seat and each orchestrator note. This supports the earlier
  design decision to keep relaying and proving out of Goals. [T1, T2]
- A seat can now carry a second key, the juror key, bound by the holder's signature. It is registered with the plane,
  not on chain, so a third party cannot read it until a juror root is published. [W, 9 Nov]
- Telegram is now holders-only: "Only seat holders get in. A bot checks your wallet first." [https://imd.fun/telegram/ , 9 Nov]

## Could not verify

1. **The developer's posts about Goals since 3 Nov.** https://x.com/surfcoderepeat returned HTTP 402 to WebFetch; four web
   searches returned nothing dated November; third-party mirrors of X were not used (blocked by this session's
   permission policy); the Telegram group is gated to seat holders. No statement on timeline, audits, raising funds or
   the "100 of 150" demo could be read. NOT VERIFIED.
2. **Any deployed JuryExecutor, juror root, beacon, BudgetEscrow, BudgetJury, BuybackRouter, OwnerMerkleDistributor,
   VestingWallet factory or custody Safe.** No address is public, so none of the contract behaviour described from the
   worker code could be checked against bytecode. NOT VERIFIED.
3. **Who may post a juror root on chain, who assigns `holderKey` clusters, and how a pending root is cancelled.** Only the
   one-line release note of 3-4 Nov. NOT VERIFIED.
4. **The goal `watch` decision and the full orchestrator reference** (T2 cites "The reference" for how holders are
   counted). They are served to workers by the plane, not published. NOT VERIFIED.
5. **What "(solidity-auditor)" in the release notes denotes**, and whether any external audit is commissioned. NOT VERIFIED.
6. **Who controls the 3-of-4 Safe that can upgrade the ERC-8004 adapter**, and who 0xF8e03bd4…b4EF is. Only the owner
   addresses were read. NOT VERIFIED.
7. **Whether the mode-0 test mandate was really signed by surfsurf.eth.** The objective says so; the signed message is
   not served publicly. NOT VERIFIED.
8. **Etherscan and OpenSea figures were read through WebFetch**, which returns a small model's reading of the page, not
   the raw page. The Etherscan results agree with Sourcify; the OpenSea owner count agrees with the IMD API within one.
9. **IMD price and market cap on 3 Nov**: not in the earlier notes, so no baseline. Explorer token count (692 on 3 Nov)
   and the former "Companies" tab were not re-read; the explorer's tab row now reads "All Tokens Contracts Oracles Sites
   Audits Reports Media".
10. **Incidents since 3 Nov**: absence of results is not evidence of absence (see section E).
11. **GitHub release pages** (github.com HTML is 403 here). The release notes were read from the repository's git
    history, which the README says carries the same text.

## Raw copies

Scratch directory of this session (not in the repository):
`/tmp/claude-0/-home-user-claude/edcb6707-89a1-58bb-8516-2cc611966e65/scratchpad/raw/` (docs, API, explorer, market,
Sourcify, 10 Nov refresh under `d10/`) and
`/tmp/claude-0/-home-user-claude/edcb6707-89a1-58bb-8516-2cc611966e65/scratchpad/untrusted/` (worker clone and the
extracted release tarball).
