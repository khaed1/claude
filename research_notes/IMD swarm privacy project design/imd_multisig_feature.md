# IMD / IdentityMD: agent multisigs and agent-run "companies" — what exists vs. what is only in progress

Status as of 2026-11-04 (all pages fetched that day). Raw copies of every fetched page are in
`/tmp/claude-0/-home-user-claude/d80905a0-7eed-5ac6-af1c-2d3cf5ee442a/scratchpad/imddocs/raw/`; the worker
distribution was cloned to `/home/user/identity-md/worker` (commit 8d9cd68, "Update worker 0.1.14 (212b225e006a)").

## 1. Bottom line

- **Not shipped, not documented:** no public IMD doc, API, explorer page or contract gives an agent (seat) its own
  multisig/Safe, lets agents form or run a "company", self-manage, or raise and hold funds. The words
  "multisig", "DAO", "council", "board", "payroll", "fundraise", "agent wallet", "agent-owned", "self-manage" do not
  occur in https://imd.fun/docs/ , https://imd.fun/docs/llms.txt , https://imd.fun/skill.md or its sub-pages
  (grep over the fetched copies; see section 9).
- **"Company" on IMD today is a product name, not an organisation.** It is the explorer's label for a
  `workflow.open` launch: contracts + optional token + website bought in one 0.5 IMD payment by a human/contract payer.
  The explorer's "Companies 208" tab and "Launch a company" button map to `/launch?make=company`, whose form text is
  "Contracts and a website, launched together, with a token if you want one." (https://explorer.imd.fun/?type=companies ,
  https://explorer.imd.fun/launch rendered with Playwright). The docs' worked example is literally `company.json`, a
  `workflow.open@workflow-1` body (https://imd.fun/docs/llms.txt lines 1358-1392; https://imd.fun/skill/onchain.md "#### Company").
- **Safe is explicitly unsupported as a payer:** "The wallet must sign with its own key: an ordinary account or an
  EIP-7702 account. Contract wallets such as a Safe are not supported yet." (https://imd.fun/docs/llms.txt line 496;
  same sentence on https://imd.fun/docs/#paid).
- **What IS real, but only in release notes and the shipped protocol schemas (not in docs, not visible on chain):**
  between 2026-11-02 and 2026-11-04 the worker releases added (a) a "custody Safe" deployment plus a fork rehearsal
  that moves "every surfsurf.eth role" to it, (b) a vetted custody table (Safe 1.4.1, MultiSend, Zodiac Roles v2,
  ModuleProxyFactory, Multicall3, DelegationManager) per chain, (c) an "owner's mandate" with a scope and forbid list
  and "asset intents" (fees.claim, fees.withdraw, fees.redirect, treasury.rebalance, buyback.plan, distribution.round,
  vesting.setup, lp.adjust) that "a goal's items write", (d) keeper and simulator roles that claim/execute/simulate those
  actions, and (e) an "epoch document" for airdrop/earnings distributions funded by `treasury_safe` or `budget_escrow`
  with a 72-hour challenge window and a jury. This is the scaffolding for a protocol-owned treasury Safe operated under
  scoped delegation, with agent "goals" proposing asset moves. It is **not** agent-owned multisigs, and no Safe address,
  goal, mandate or epoch is published anywhere public yet. Details and quotes in sections 5-6.
- **How money reaches agents today:** (1) launch tokens, not IMD: 10% of every token launch goes to the swarm via a
  per-launch `MerkleDistributor` (2% to wallets with accepted work on that launch, 8% equally per seat connected at
  admission), claimed by the seat holder's wallet; (2) IMD itself: the docs describe no IMD payout to workers; the only
  IMD flows documented are payments *into* the Intake payee and the POOL4 trim split reported by third parties
  (4.5% of trims to NFT seats). TechFlow/Sparsity (2026-10-26) states the IMD "payroll" is "manually allocated via
  multisig wallets"; nothing on imd.fun confirms or describes that process. Section 7.

## 2. Sources fetched (and what was not reachable)

| # | Source | Result |
|---|---|---|
| 1 | https://imd.fun/docs/ (723 KB HTML, text-stripped and grepped in full) and https://imd.fun/docs/llms.txt (the same page as Markdown, 151 KB) | OK. https://imd.fun/docs/index.html is 404. Sub-pages linked from the nav: https://imd.fun/skill/{pay,onchain,jobs,workflows,oracle,schedules,follow,worker,errors}.md all fetched. |
| 2 | https://imd.fun/skill.md | OK (13 KB) |
| 3 | https://imd.fun/token/ | OK (JS page; stripped text + raw grep) |
| 4 | https://raw.githubusercontent.com/Identity-md/worker/main/RELEASE_NOTES.md | OK — it holds only the *current* build's notes (0.1.14+212b225e). Full history came from the GitHub releases pages (row 6). |
| 5 | https://raw.githubusercontent.com/Identity-md/worker/main/README.md | OK |
| 6 | https://github.com/Identity-md/worker/releases (pages 1-7 and 14) and individual tag pages | OK via WebFetch (summaries; verbatim quotes limited to short spans). `gh api` and api.github.com returned 403 from this session, and curl to github.com is proxied-403, so the raw release bodies could not be downloaded. Pages 8-13 (late Sep - 10 Oct) not read; page 14 shows the first release was 12 Sep. |
| 7 | https://api.imd.fun/openapi.json | OK |
| 8 | https://api.imd.fun/requests/capabilities | OK |
| 9 | https://explorer.imd.fun/ , /launch , /?type=companies , /tokens , /agents , /status , /wallet/0xbba9... | OK (Playwright render + WebFetch) |
| 10 | https://www.techflowpost.com/en-US/article/34850 | OK (published 2026-10-26T03:59Z, a Sparsity Data report republished by TechFlow) |
| 11 | https://github.com/orgs/identity-md-launches/repositories?sort=created | OK via WebFetch (30 newest repos) |
| 12 | Etherscan: https://etherscan.io/address/0xcecc29b037f5064fcdf45a5c318f132ef76aa551 , https://etherscan.io/txsInternal?a=0xcecc... , https://etherscan.io/name-lookup-search?id=surfsurf.eth , https://etherscan.io/address/0x047F606fD5b2BaA5f5C6c4aB8958E45CB6B054B7 | Partially: address pages render only the latest 25 txs; "Contract" tabs are irrelevant because IMD says "None of the sources are verified on the explorers yet" (https://imd.fun/docs/llms.txt line 2361); token-transfer, analytics and full history tabs did not load through WebFetch. |
| extra | https://github.com/Identity-md/worker cloned (public git read lane). `dist/cli.js`, `dist/client.js`, `dist/config.js`, `dist/web.js` are the shipped, inspectable protocol code ("Its JavaScript, prompts, API requests, and assigned task data are inspectable. Backend source and service credentials are not distributed." — README) | OK |
| extra | https://www.bankless.com/read/inside-imd-ethereum-s-new-ai-swarm-experiment (2026-09-25), https://www.kucoin.com/blog/imd-token-community-owned-ai-agents (2026-09-29) | OK, background only |

## 3. What the docs say the product is (exact scope of agent autonomy today)

- Positioning: "A network of AI agents that build, review and ship software, paid in IMD, with the record on Ethereum."
  (https://imd.fun/docs/llms.txt line 5). "IMD is a network of AI agents, each run by the holder of an IMD NFT on their
  own machine. Pay 0.5 IMD and it plans the work, builds it, has other agents review it, and delivers it to GitHub, IPFS
  or a chain" (https://imd.fun/skill.md).
- The paid actions are the entire surface: `job.open`, `job.continue`, `launch.open`, `oracle.request`, `oracle.group`,
  `workflow.open`, `schedule.create`, `schedule.topup`, each 0.5 IMD (500000000000000000 wei) to payee
  `0x4e0fa57bde726079356537e2f34d671e9f41adbc` (https://api.imd.fun/requests/capabilities). The OpenAPI document
  (title "IMD paid requests 1.0.0") has exactly five paths: `GET /openapi.json`, `GET /requests/capabilities`,
  `POST /requests/quote`, `POST /requests/{id}/submit`, `GET /requests/{id}`; schemas Policy, Quote, Order, Status,
  Error, Challenge. Nothing named multisig, safe, company, treasury, fund, raise, project or org
  (https://api.imd.fun/openapi.json).
- Agents (workers) do not hold or move funds in any documented flow. A worker "needs an IMD NFT ... a little ETH in the
  NFT's wallet for one transaction" (the ERC-8004 registration) and "is paid by the network" (https://imd.fun/skill.md
  "## Work"); the worker README adds "Config and the private device key live in `~/.identitymd/config.json`" — a device
  key, not a funded wallet (https://raw.githubusercontent.com/Identity-md/worker/main/README.md).
- Contract ownership from a launch goes to a human-chosen `owner` or the payer: "on a launch, `owner` gets the
  contracts' owner roles. Left out, the paying wallet gets them." (https://imd.fun/skill.md). "Who the payer is": owner
  roles, the rest of the 90%, and the 1% trade fee all go to "The payer" by default (https://imd.fun/docs/llms.txt
  lines 1684-1693). An agent is never the owner.
- A contract can be the payer and can own the resulting launch's fee stream (`OrdersALaunch` ... "as payer, this
  contract earns 1% of every trade. Hand it on, or take it out." — https://imd.fun/docs/llms.txt lines 1640-1655), so a
  *human-deployed* contract can run a project end to end, but there is no IMD-provided factory for that and no Safe
  support.

## 4. The launch / "company" data model as documented

- Kinds (`onchain`): `univ4_hook`, `evm_project`, `custom_token`, `evm_contracts`; chains Sepolia 11155111 (default),
  Ethereum 1, Robinhood Chain 4663; pairings eth / imd / fwa (https://api.imd.fun/requests/capabilities;
  https://imd.fun/docs/llms.txt lines 625-639).
- Supply rule (token kinds): "Ten percent to the swarm, ninety to the requester: `poolBps` of the supply seeds the pool,
  single-sided in the launch token, and the rest goes to `remainderTo`." Swarm share: "Claimed from the launch's Merkle
  distributor: 2% split equally between the wallets with accepted work on the launch, 8% equally per seat connected at
  admission. Proofs at `GET /launches/:id?claims=1`." Trading fee: "1.25% of every trade on today's factories, 1% to the
  paying wallet and 0.25% to the network. Anyone can call the distribution." (https://imd.fun/docs/llms.txt lines 636-638)
- Factories and registries (Ethereum mainnet; https://imd.fun/docs/llms.txt lines 2366-2381):
  LaunchFactory `0x12c63b581d07093f6126bc02263c58f7eadaa96f` ("Deploys a token, seeds its Uniswap v4 pool and records it,
  in one transaction"), LaunchFactory registry `0xa47fcb220ddd1cddda865f89029bec1b9eca3bf1`, ProjectFactory
  `0xff03410d0fe5fa8f7f59f743de35e333d9857120` ("Deploys a token with up to eight contracts beside it, and its pool"),
  ProjectFactory registry `0x7c9d5ee697bff5ac4f10e2e54d3f40c44e48fe23`, PoolInitializationGuard
  `0x784ff9a3ac5d88a30bfff6f7f2a270161fbe6000`, LaunchFees `0x12c9e1007262afac205567457f5826a9416a3863` ("The pool fee
  (1.25%), where the network's share goes, and the treasury."), Intake `0xa43e6f75ee006411f79ac1c84120606c2330de82`,
  WorkRegistry `0xb6d0a187b050fa5bb0b87033a203f37becf4a775`, ERC-8004 adapter `0xde152afb7db5373f34876e1499fbd893a82dd336`.
  Robinhood Chain and Sepolia tables are at lines 2383-2421. Wallets (same on every chain, lines 2423-2434): Launch
  deployer `0xcecc29b037f5064fcdf45a5c318f132ef76aa551` ("The only wallet either factory takes a launch from"), Fee
  recipient `0x3f252e859a277a86a3967c11d4e054b2f07a1f22`, Intake payee `0x4e0fa57bde726079356537e2f34d671e9f41adbc`,
  Intake writer `0x3d3c0df7c1a17d384545e9d7c8228897bd9625cb`, Quote signer `0x169b08ea234d7819eeabb246e34d8cd81e32279f`,
  WorkRegistry writer `0x5da3054201bc7e241875ac68173e49c269f76d44`. Note: all operational wallets are EOAs by their
  description; none is described as a Safe.
- Live example (https://api.imd.fun/launches/bee25289-1960-476f-a21a-eef0759db6b2?claims=1 , launch #2978 "Conditionals",
  `custom_token`, mainnet, 2026-11-04): artifacts = token `0x1fbf644110efe76184f9fd81cead18adef5e9420`, `MerkleDistributor`
  `0x613e06013439107c59c0263bf90d868d74a84d5d`, hook = PoolInitializationGuard; pool fee 12500 paired with IMD;
  `economics` `{poolBps: 8000, remainderTo: 0xd630…ce98, initialMarketCapWei: 3000 IMD}`; `policyVersion` 35;
  `rewardSnapshot.rule` = `equal_connected`, version 3, 6 workers with accepted review work; `allocations` = 439 wallets
  summing to exactly 100,000,000 tokens (the 10%); `claims.leaves` = 439 Merkle leaves with proofs. Per-wallet earnings
  are served by `GET /wallets/:address/earnings` (reward `{work, second, version}`) and the explorer's `GET /api/earned`
  (`{claimable:[launchId], unlocks:[{id, at}]}`; https://imd.fun/docs/llms.txt lines 2066, 2148-2150).
- The shipped policy schema is wider than the docs: `LaunchPolicy` carries `contributorPoolBps`, `liquidityBps`,
  `treasuryBps` ("supply shares must sum to 10000 bps"), optional `treasury` address, `owners.{token, lpPosition,
  treasury, hookAdmin|project}`, `contributorLockSeconds`, `perWalletCapBps` (dist/cli.js ~@1.47 MB; grep `treasuryBps`).
  For custom launches the code pins "the swarm's share of a custom launch is 1000 bps". So a `treasury` share per launch
  exists as a policy field; the public docs and the live launch above do not use it.
- Oracle work: recorded once a day as one OpenZeppelin `StandardMerkleTree` receipt (https://imd.fun/docs/llms.txt line 2130).

## 5. Release notes, Oct-Nov 2026 (Identity-md/worker) — every release, with the money/custody-relevant notes

Source: https://github.com/Identity-md/worker/releases (pages 1-7). Dates are as shown on GitHub (day/month; year is
2026). Tags are `worker-v<ver>-<12-hex>`. Only bullets touching Safe/custody/treasury/goals/keeper/mandate/intent/wallet
are quoted; everything else is summarised as "ops/runtime".

**November**
- 0.1.14+212b225e (04 Nov 19:26, latest; https://raw.githubusercontent.com/Identity-md/worker/main/RELEASE_NOTES.md):
  "Worker: git the daemon runs after a jailed run reads none of the repository's own configuration or hooks that run
  wrote"; "Worker 0.1.14: a jailed run starts without the session's runtime folder and bus, so a jailed Linux task is
  told of no Secret Service". No custody content.
- 0.1.13+48c1bcfc (04 Nov 17:45, tag worker-v0.1.13-48c1bcfc1b2c): a goal "ask" decision sends a question to the oracle
  through its own channel with a panel that excludes the author.
- 0.1.13+e2656771 (04 Nov 16:54, worker-v0.1.13-e2656771aa46): "a goal-chain task (a goal's intent item) runs jailed with
  chain-only egress on Claude and Codex"; "a contributor can lend tasks their own Etherscan, Dune or Brave Search key via
  imd data"; "Goals: chain batches compute figures over spans the plane pins, and the deployer's keyless figure lane
  reruns a tenth of them."
- 0.1.12+beb1864a (04 Nov 14:27): test: "the action page's typed data is checked against the protocol's test suite".
- 0.1.12+df310a90 (04 Nov 04:15, worker-v0.1.12-df310a901b84): "Protocol: the simulator's claim, task and signed result,
  under envelope kinds of its own"; "Protocol: an owner's mandate, its scope and forbid list, and the asset intents a
  goal's items write", with their EIP-712 typed data.
- 0.1.12+dadf30a7 (04 Nov 03:17, worker-v0.1.12-dadf30a7bde4): every "goal door" runs under the read jail;
  `oracleJuryDigest` and the oracle jury proof computed as `OracleJuryVerifier` does; ops.
- 0.1.11+7f615fcc (04 Nov 00:09, worker-v0.1.11-7f615fcc0906), quoted exactly: "Protocol: the epoch document, its IPFS
  CID, and the presence sample a signer checks before funding"; "Protocol: goal-dataset-delta@1 compares a dataset with
  the previous run's on its key, row by row, with exact total changes"; "Plane: a draw is for a commitment already on
  chain, and a pending root's cancel jury is drawn too"; "Protocol: the jury lane's draw, trees and typed data, equal to
  the contracts' to the byte".
- 0.1.11+27f56808 (03 Nov 22:56, https://github.com/Identity-md/worker/releases/tag/worker-v0.1.11-27f5680865af), quoted:
  "Contracts: the custody Safe's deployment, and a fork rehearsal that moves every surfsurf.eth role to it and runs the
  5a checks"; "Protocol: keeper.claim and keeper.result envelopes, and the keeper's claim, task and result schemas".
- 0.1.11+f00a3629 (03 Nov 19:20): test-only.
- 0.1.11+21b41e18 (03 Nov 16:42, worker-v0.1.11-21b41e180a47): goal items re-read cited sources; "goal-dataset@1" reducer
  with quorum; "each task reads the chain through its own read-only address with a quota cap"; "Goal tasks use the
  contributor's RPC only after `imd rpc goals on`"; datasets under `datasets/<…>/`; "a datasets-v1 claim capability".
- 0.1.11+06a20c1d (03 Nov, https://github.com/Identity-md/worker/releases/tag/worker-v0.1.11-06a20c1d797a), quoted:
  "Protocol: a vetted custody table of its own, Safe, MultiSend, Roles v2, ModuleProxyFactory, Multicall3 and
  DelegationManager by chain, kept out of the network block sites copy."
- 0.1.9+f2e4c1e1 (02 Nov): "goal tables and goal-dataset@1, a pure reducer producing canonical JSONL and CSV, exact
  decimal totals, and RFC 6962 roots".
- 0.1.9+4234b67d (02 Nov): dependency bumps. 0.1.9+3dcb4df2 (01 Nov): review sender may defer a batch "because its
  writer can't pay for it at its fee"; goal replay harness.

**October**
- 0.1.9+a6eb4461 (31 Oct): jail/ops. 0.1.8+c78f45fe (30 Oct): launch-check and site import ops; "Report bot" issues.
  0.1.8+0354a835 (29 Oct): fork-test verifier. 0.1.8+ddb63cea, +d372f99e, +1d98f47e (28 Oct): Venice and OpenRouter
  providers for goal items ("a goal item sent to OpenRouter goes through the task's gateway on the contributor's own
  key, with IMD attribution"). 0.1.8+b0c2298f, +a375dd80, +944e816a, +35dc4050, +260efc41 (26 Oct): Codex helper
  accounting, runtime auto-update gate, pairing signs with the machine key (`pairing.start`). 0.1.8+f3653923 (25 Oct):
  helper caps; "a Codex run has no goals". 0.1.7+def7b689, +81f38041, +25453465, +176931c4 (25 Oct): run isolation.
  0.1.7+2955ca33 and 0.1.5+0f0bbf52 (24 Oct): "Worker 0.1.5 runs a goal's code item jailed"; "A signed task merges a
  goal's code wave into its trunk"; "Goal task runs may use up to four subagents"; "Worker 0.1.4 runs a goal's
  orchestrator and judge under the read jail"; "Worker 0.1.3 runs every step of a goal job under the read jail".
  0.1.4+dd1aa5f3, +962b3018, +94d88d49, +1103e27b, +011c9f4c (23 Oct): fork tests, registry endpoint on IPFS, sites
  under identitymd.eth, "Each bound seat's ERC-8004 document is published as one IPFS folder on ENS", job records on
  chain as IPFS URIs. 0.1.2+a9b5b731 (21 Oct), +245cce90 (20 Oct: "A hook launch's manifest may name its own token's
  arguments"), +cf06456a (19 Oct), +6a374fcd (19 Oct), +745c1db4 (18 Oct: "An app a wallet links pauses and resumes that
  wallet's seats with its own key"), +5921f9e9 (18 Oct), +cb5346c3/+c3fba9eb/+7aaac31b/+45fc1aec (17 Oct),
  +c0fadb97/+b326004f/+78d471e4/+63e0a393/+024c41dd (15 Oct), +fa23b3ea/+d1681b55/+c0fbf294/+aca6c688/+9746468e/+3648896b
  (14 Oct), 0.1.1+c23cfac6 (14 Oct), 0.1.0+35c7b362 (13 Oct), 0.1.0+f0753cb7/+aca0ff06 ("the burn address only where a
  name says it burns, never a fee or treasury sink")/+788bb33f/+20b2eed8 (12 Oct), +fb8278c5/+47056004/+40b9e587 (11 Oct),
  +4ba55555/+46c92320/+3f1208aa (10 Oct): none flagged for custody/treasury/company. Releases 1-9 Oct (pages 8-13) were
  not read.

Reading: the Safe/custody/keeper/mandate/epoch/goal machinery arrived in a burst on 02-04 Nov 2026 and is unreleased
to users (no doc, no explorer page, no API route).

## 6. What the shipped protocol code actually defines (dist/cli.js in the 0.1.14 package)

All of the following are zod schemas or constants in `/home/user/identity-md/worker/dist/cli.js` (identical copies in
client.js/config.js/web.js). They are *protocol definitions the worker can validate*, not evidence that any instance
exists on chain.

- **Custody table** (`SAFE_141`, `ZODIAC`, `CUSTODY_CONTRACTS`): Safe 1.4.1 singleton `0x41675c099f32341bf84bfc5382af534df5c7461a`,
  SafeL2 `0x29fcb43b46531bca003ddc8fcb67ffe91900c762`, SafeProxyFactory `0x4e1dcf7ad4e460cfd30791ccc4f9c8a4f820ec67`,
  MultiSend `0x38869bf66a61cf6bdb996a6ae40d5853fd43b526`, MultiSendCallOnly `0x9641d764fc13c8b624c04430c7356c1c7c8102e2`;
  Zodiac Roles v2 `0xf2964ce6161ce0e75964fe7927ce114cb0b283d5`, ModuleProxyFactory `0x000000000000addb49795b0f9ba5bc298cdda236`;
  Multicall3 `0xca11bde05977b3631167028862be2a173976ca11`; DelegationManager `0xdb9b1e94b5b69df7e401ddbede43491141047db3`
  (matches the address published for the MetaMask Delegation Framework DelegationManager; not independently verified here). Chains: 1, 4663, 8453 (Base), 11155111. These are the canonical
  public deployments of those third-party contracts, i.e. the allowlist of what a custody setup may touch — not IMD's
  own Safe.
- **Owner's mandate** (`MandateScope`): `{v:1, chainId, targets[1..16]: {address, label?, functions[1..16]: {signature,
  args: ArgRule[]}}, allowances[≤16]: {asset|"native", amount, periodSeconds 1h..90d}, spenders[≤8], recipients[≤16],
  gasBudgetWei}`; `ArgRule` ∈ eq / oneOf / lte / gte / avatar; `MANDATE_MAX_SECONDS = 90 days`;
  `EOA_FRESH_SECONDS = 10 min`, `CONTRACT_FRESH_SECONDS = 7 days`. This mirrors a Zodiac Roles v2 scope.
- **Forbid list** (`FORBIDDEN_SIGNATURES`), with the reasons as written: multicall/aggregate variants ("runs calls the
  scope never saw"), universal-router `execute` ("runs commands the scope never saw"), ERC-4337 `execute`/`executeBatch`
  ("a smart account's execute is an arbitrary call"), `multiSend(bytes)` ("MultiSend batches only the owner's own Safe
  transactions, never a mandate's"), `execTransaction` ("a Safe transaction is an arbitrary call"),
  `execTransactionFromModule[ReturnData]`, `addOwnerWithThreshold`/`removeOwner`/`swapOwner` ("a Safe's owners are the
  owner's alone"), `changeThreshold`, `enableModule`/`disableModule`, `setGuard`, `setModuleGuard`, `setFallbackHandler`,
  Zodiac `assignRoles`/`setDefaultRole`/`allowTarget`/`revokeTarget`/`scopeTarget`/`allowFunction`/`revokeFunction`/
  `scopeFunction`/`setAllowance`/`setTransactionUnwrapper` ("Zodiac Roles administration is the owner's alone"),
  `transferOwnership`/`renounceOwnership`, `upgradeTo[AndCall]`. `APPROVAL_SIGNATURES` tracks approve / increaseAllowance /
  setApprovalForAll / Permit2 approve / permit. Design intent: an agent-side mandate can never change Safe ownership,
  modules, roles or run arbitrary calls — the human "owner" keeps those.
- **Asset intents** (`ASSET_INTENT_KINDS`, schema `asset-intent@1`): `fees.claim {factory, launchNumber}`,
  `fees.withdraw {factory, currency}`, `fees.redirect {factory, launchNumber, to}`, `treasury.rebalance {moves[≤8]:
  {asset|"native", to, amount}, approvals[≤4]}` ("a rebalance moves or approves something"), and `buyback.plan`,
  `distribution.round`, `vesting.setup`, `lp.adjust` each carrying a free-form `plan` record; every intent has `chainId`
  and a `rationale` (≤2000 chars). Per the release note these are what "a goal's items write".
- **Simulator** (`SimulationClaim/Task/Result`): a task is `{actionHash, chainId, account, calls[1..16]: ActionCall
  {to, value, data, signature, args}, declared: DeclaredEffects {outflows, approvals, redirects}, tokens, depth, gasLimit}`;
  result reports per-call status, balance `deltas`, `nativeTransfers`, gas. i.e. every mandated action is dry-run and
  its declared effects compared before execution.
- **Keeper** (`KEEPER_RECIPES = ["fees.claim","fees.withdraw","router.forward","router.buy","distributor.sweep","gas.topup"]`;
  `KeeperClaim.role ∈ {keeper, funder}`; `KeeperTerms {minValueMultiple ≥3, maxGasWei, maxTxGas, ethFloorWei}`;
  `KeeperTask {recipe, terms, lowKeys[≤32] (only for gas.topup), toppedUpWei24h}`; `KeeperResult {txs, lines: sent/
  skipped/refused/failed, accrual {factory, launchNumber, amount0/1, valueWei, gasWei}}`). Keepers are machines that
  claim fee accruals from the launch factories, forward/buy through a router, sweep distributors and top up gas for
  low keys — automation of the fee plumbing, with a `funder` role.
- **Epoch document** (`EPOCH_DOCUMENT_FORMAT = "imd-epoch@1"`, `EPOCH_KINDS = ["airdrop","earnings"]`,
  `EPOCH_CHALLENGE_WINDOW_MS = 72 h`, `EPOCH_MIN_CLAIM_WINDOW_SECONDS = 90 days`, `AIRDROP_RULE = "connected_equal@1"`,
  `PRESENCE_SAMPLE_SIZE = 32`): `{epochId, kind, chainId, distributor, token, tokenSymbol, tokenDecimals, lockSeconds,
  total, root, cutoff, createdAt, challengeEndsAt, funding: {by: "treasury_safe" | "budget_escrow"}, rule:
  {name: "connected_equal@1", presenceWindowMs}, lines[≤20000]: {wallet, amount, seats[≤256]: {tokenId, agentId,
  deviceKey, lastHeartbeatAt, amount}}, sample: {seed, entries[≤32]: presence evidence per device}}`. This is a
  periodic, Merkle-rooted, challengeable distribution of a token to seat wallets by presence, funded from a treasury
  Safe or a budget escrow — the automated replacement for the manual multisig "payroll" TechFlow describes. Envelope
  kind `epoch.document` is in the envelope enum alongside `keeper.claim/result`, `simulation.claim/result`,
  `goal-merge.*`, `goal-figure.*`, `etherscan.*`, `fuzz.*`.
- **Goals**: skill ids `goal-orchestrator`, `goal-lead`, `goal-judge`, `goal-check`, `goal-code`, `goal-chain`,
  `goal-task`; `GoalMergeTask` (waves of code bundles merged into a trunk by a signed publisher), `GoalFigureTask`
  (deployer reproduces a claimed on-chain figure over a pinned block window). CLI: `imd rpc goals on|off` ("goal tasks
  may/may not read through this machine's own RPC endpoints"); `imd venice`/`imd openrouter` keys let "goal tasks run on
  the models their goals name". What a goal *is* (who writes one, what it may own) is not defined in the distributed code
  or docs; from the notes, a goal has items of kinds code / chain / figure / intent / ask, datasets, write-ups, doors and
  a jury, and its intent items emit asset intents under an owner's mandate.
- Absent from the code: any IMD custody Safe address, any `surfsurf.eth` address, "company", "multisig", "payroll",
  "fundrais" (grep counts 0). The "fork rehearsal that moves every surfsurf.eth role" is not in the distribution.

## 7. How funds move to agents today (documented and observed)

1. **Launch tokens via Merkle distributors** (documented, live): see section 4. Each launch deploys its own
   `MerkleDistributor`; the plane freezes a reward tree (`rewardSnapshot`, `allocations`, `claims`) and seat holders'
   wallets claim. Explorer wallet page shows e.g. "Rewards 664 tokens, 41 ready to claim" for a 20-seat holder
   (https://explorer.imd.fun/wallet/0xbba92286026209e652384572a2c51e52c9aadbe8); `/api/earned` returned 41 claimable
   launch ids and `unlocks: []`. Reward rule `equal_connected` (8% per connected seat) dominates; `reward.work` was `0`
   and `reward.second` carried the amount on the sampled earnings rows (https://api.imd.fun/wallets/0xbba9…/earnings).
   The policy schema has `contributorLockSeconds` (lock) and the explorer serves `unlocks`, so locked swarm shares are
   provided for.
2. **Trade fees**: 1% of every trade to the launch's payer, 0.25% to the network's fee recipient
   `0x3f252e859a277a86a3967c11d4e054b2f07a1f22`; "Anyone can call the distribution." Agents get none of this directly
   (https://imd.fun/docs/llms.txt line 638, 2428).
3. **IMD paid by requesters**: every 0.5 IMD request is "forwarded whole to the treasury in the same call" (Intake docs,
   https://imd.fun/docs/llms.txt line 1152) to the Intake payee `0x4e0fa57bde726079356537e2f34d671e9f41adbc`. No doc
   describes IMD leaving that wallet to workers. Explorer status: "7,489 payments paid and 85 failed"
   (https://explorer.imd.fun/status).
4. **POOL4 trims** (third-party description, not on imd.fun docs): "Of every 100 IMD removed, 85 percent is permanently
   burned", 6% to an orchestrator compute reserve, 4.5% to sIMD stakers, 4.5% to NFT seats (KuCoin 2026-09-29;
   Bankless 2026-09-25 adds "Seats don't earn much yet").
5. **TechFlow / Sparsity (2026-10-26)** on the manual part, exact quotes from https://www.techflowpost.com/en-US/article/34850:
   "The segment still requiring manual intervention involves payroll settlement: $IMD distributed to working agents to
   date remains manually allocated via multisig wallets. Additionally, a single wallet controls administrative
   permissions for the core Hook contract (including its closeMarket circuit-breaker authority), meaning a single
   centralized entity theoretically holds the right to forcibly shut down the entire marketplace." Context quotes:
   "all 2,000 workstation seats have been minted, with over 1,000 agents coordinating daily online. These agents jointly
   completed 11,014 tasks, cumulatively consuming approximately 190 billion tokens in inference compute, and
   autonomously spawned 320 new project launches, with 105 successfully deployed on the Ethereum mainnet since
   October 5." "The POOL4 Hook contract on Uniswap v4 directly maintains a 34.28 ETH buy-order floor, and the protocol
   has cumulatively burned 33,279 $IMD tokens." "Working agents cover their own inference costs, primarily paying
   through subscribed Claude Code or OpenAI Codex plans." The article names no multisig address and gives no roadmap for
   agent-owned multisigs or companies; its "roadmap" content is limited to the sector thesis ("agents will eventually
   learn to autonomously procure inference compute from other agents on-chain").

## 8. On-chain check (Etherscan)

- Launch deployer `0xcECc29B037f5064fCdF45a5C318F132ef76aA551` (https://etherscan.io/address/0xcecc29b037f5064fcdf45a5c318f132ef76aa551):
  labelled "moneycanbuy.fun: Deployer"; 538 txs; funded by surfsurf.eth 30 days earlier; latest 25 txs (30 Oct - 4 Nov)
  are all `Launch Custom` / `Launch` calls to ProjectFactory `0xfF03…7120` and LaunchFactory `0x12C6…A96F`, 0 ETH value.
  No "Contract Creation" rows; internal transactions page reports "A total of 0 internal transactions found"
  (https://etherscan.io/txsInternal?a=0xcecc29b037f5064fcdf45a5c318f132ef76aa551). Nothing Safe-shaped.
- surfsurf.eth resolves to `0x047F606fD5b2BaA5f5C6c4aB8958E45CB6B054B7` (https://etherscan.io/name-lookup-search?id=surfsurf.eth).
  Its page (https://etherscan.io/address/0x047F606fD5b2BaA5f5C6c4aB8958E45CB6B054B7): 3,034 txs; the 12 visible latest
  (30 Oct - 3 Nov) are `Withdraw Fees` to `0xc6C965…2840`, `Claim` to a proxy `0x0a14B6…D2a0`, `Mint` to `0x72496B…49F7`,
  IMD transfers, 0.06 ETH to the Intake payee `0x4e0fA5…ADbc`, 0.1 ETH to the WorkRegistry writer `0x5dA305…6D44`,
  and one `Execute` whose counterparty was truncated. No interaction with SafeProxyFactory
  (`0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67`) or Zodiac ModuleProxyFactory is visible in that window, and no
  contract creation. The "5a checks"/role move rehearsed on a fork has therefore **not** been observed on mainnet in the
  visible window; a full history export (not reachable here) would be needed to rule it out.
- Bankless reports IMD's creator "Adam (@surfcoderepeat)" posts official updates from
  `0x200E710aCAA6A93bbc77146026328C40F1d60fB1` and "renounced ownership of the staking contract on Sept. 19"
  (https://www.bankless.com/read/inside-imd-ethereum-s-new-ai-swarm-experiment). Not checked on chain.

## 9. Explicit "not found" list

- No doc/API/explorer mention of: multisig, Safe (other than "not supported yet" as a payer), DAO, council, board,
  payroll, fundraise/raise, agent wallet, agent-owned, self-manage(d), treasury-as-a-feature (only the LaunchFees
  description "where the network's share goes, and the treasury") — grep of https://imd.fun/docs/ ,
  https://imd.fun/docs/llms.txt , https://imd.fun/skill.md , https://imd.fun/skill/*.md , https://imd.fun/token/ ,
  https://api.imd.fun/openapi.json , https://api.imd.fun/requests/capabilities , explorer HTML.
- No "companies/projects/orgs/treasury" pages on the explorer beyond `/?type=companies` (= workflow launches) and
  `/launch?make=company`; nav links are `/`, `/launch`, `/?type=companies`, `/?type=parts`, `/oracle`, `/heartbeats`,
  `/tokens`, `/agents`, `/status`, `/wallet/:addr`.
- No "CompanyFactory", Safe proxy, treasury or fundraising contract deployed by the Launch deployer or by
  surfsurf.eth in the visible Etherscan windows; no IMD custody Safe address anywhere public (docs, code, explorer).
- No repository in identity-md-launches (30 newest, all updated 2026-11-04: launch-2971 … launch-2935, mostly
  Squeek/Hamster games, custom tokens COND and WWW, `launch-2957-deploy-exactly-two-contracts`, workflow frontend
  stages) whose name or description mentions multisig, Safe, company, treasury, DAO, fund, raise, council, board, goal
  or keeper (https://github.com/orgs/identity-md-launches/repositories?sort=created). One site, "PAY//AGENT ... a
  concept for policy-controlled x402 agent payments" (launch-2963), is a user-ordered website, not an IMD feature.
- No public definition of a "goal": who may create one, whether a goal can hold assets, how an owner's mandate is
  granted, or where epoch documents are published. The release notes reference them; the docs do not.
- Not reachable from this session: GitHub REST/GraphQL (403), raw release bodies, release pages 8-13 (late Sep - 10
  Oct), Etherscan full tx history / token transfers / "Contract" tabs (sources unverified anyway), the Robinhood and
  Base explorers for the same wallets, the plane's backend (closed source by design).
- Web search for "imd.fun multisig Safe company treasury" and "IMD goals keeper mandate custody Safe surfsurf.eth"
  returned no relevant third-party coverage beyond Bankless and KuCoin (searched 2026-11-04).

## 10. Interpretation for the privacy-project design

- Today an IMD seat is an ERC-8004-registered NFT paired to a device key; the seat holder's EOA receives Merkle-claimable
  launch tokens. There is no per-agent treasury, no agent signing authority over any funds, and no agent-initiated
  deployment: every launch is still executed by the single Launch deployer EOA, and ownership goes to a human-chosen
  address.
- The 02-04 Nov protocol additions point to a *protocol-level* treasury Safe (Safe 1.4.1 + Zodiac Roles v2 /
  DelegationManager) whose operator roles (currently surfsurf.eth) would be migrated to it, with keepers executing
  scoped, simulated, forbidden-list-filtered asset intents written by agent "goals", and epoch documents paying seats
  from `treasury_safe`/`budget_escrow` after a 72h challenge. If that ships, it would convert the manual multisig payroll
  into an auditable on-chain one, but it is still a single shared custody, not per-agent companies. Any design assuming
  agents can own a Safe, raise funds or deploy contracts on their own authority should treat that as not available on
  IMD as of 2026-11-04.
