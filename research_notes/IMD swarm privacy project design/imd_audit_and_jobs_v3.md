# IMD jobs, audit template, track record, Goals state, network size (v3, fetched 10 Nov 2026)

Read-only planning research. Nothing was submitted, signed, posted or paid; no account was made. All live fetches were
plain GETs made on **10 Nov 2026 in two windows: 14:44-15:03 UTC and 23:11-23:17 UTC**. Sections A, B, D and E rest on
the first window; the audit list pages 2-5, the one audit job record and the job keyword searches in B7 and C are from
the second. "Local" means the earlier notes in this folder.

## Source keys

| Key | URL | Notes |
|---|---|---|
| DOCS | https://imd.fun/docs/llms.txt (Markdown of https://imd.fun/docs/ and https://imd.fun/docs/api/) | 158,265 bytes, sha256 `29767125…c643`; same byte count as on 9-10 Nov. Line numbers refer to this file |
| SKILLMD | https://imd.fun/skill.md | 13,122 bytes |
| CAP | https://api.imd.fun/requests/capabilities | live price and paid actions |
| OPENAPI | https://api.imd.fun/openapi.json | `x-imd-actions` |
| SKILLS | https://api.imd.fun/skills | live skill catalog, 64 skills, with per-skill record |
| READ | https://api.imd.fun/reads/skill/<skill-id> | the exact prompt text a worker gets for a skill (public route, DOCS line 1975) |
| HEALTH | https://api.imd.fun/health | control-plane status |
| VERSION | https://api.imd.fun/version | control-plane commit |
| STATUS | https://explorer.imd.fun/status | explorer counters |
| ACT | https://explorer.imd.fun/api/activity | live activity |
| SEARCH | https://explorer.imd.fun/api/search?q=<term>[&part=published] | explorer search over jobs, oracle questions and publications |
| WREPO | https://github.com/Identity-md/worker (git clone; `README.md`, `RELEASE_NOTES.md` history, `build.json`, `dist/cli.js` read as data, nothing executed) | HEAD `7548341` of 2026-11-10T05:06:10Z |
| LOCAL-README | /home/user/claude/README.md | the user's own worker manual |

The API answers `429 rate limited` often from this session's address; requests were spaced 20-40 s apart.

---

## A. Job format

**Verdict: Verified** for job types, brief fields, size limits of the request, price, delivery, acceptance, panels and
model requirements (official docs plus live API). **Partly verified** for how much work one step can hold: the protocol
bounds are in the public worker bundle, but the per-skill budgets the control plane actually sets are not published.

### A1. What can be bought (paid actions) and the price

- Eight paid actions, each 0.5 IMD. DOCS lines 454-463:
  > "`job.open` | 0.5 IMD | A job." … "`job.continue` | 0.5 IMD | The next version of a project your wallet paid for,
  > delivered into its repository." … "`launch.open` | 0.5 IMD | A job that ends in a contract launch." …
  > "`workflow.open` | 0.5 IMD | A contract-to-website release" … "`oracle.request` | 0.5 IMD" … "`oracle.group` | 0.5 IMD
  > per question" … "`schedule.create` | 0.5 IMD per run" … "`schedule.topup` | 0.5 IMD per run"
- Live check: CAP returns the same eight actions, each `"amount": "500000000000000000"` (18 decimals = 0.5 IMD),
  `"quoteTtlSeconds": 600`. No `goal.open`. [CAP, OPENAPI, 10 Nov]
- The price does not depend on size. SKILLMD: "the price: 0.5 IMD per request (per question for `oracle.group`), whatever
  the panel size or number of steps".
- No refund, no guarantee. SKILLMD: "There are no refunds: a refused body is a spent payment." and "Payment buys the work
  being admitted, not a guaranteed result." Quote terms in DOCS line 527: `"resultGuaranteed": false`.
- Free pre-checks exist: `POST /requests/check` ("what a quote would say, with no token and no price held", returns
  `blockers`, `suggestions`, `plan`, `facts`) and `POST /requests/quote` (validates every field; unpaid quote expires in
  10 minutes). [DOCS lines 482-484; SKILLMD step 2]. Not called in this research (they are POSTs).
- Products named on the docs front page (DOCS lines 11-20): Token, Contracts, Company, Oracle, Heartbeat, Website,
  "**Audit** Four agents audit your contracts. A judge ranks what they find.", Report, Indexer, Media.

### A2. Job kinds: templates, skills, shapes

- `job.open` must say what to build: "a `skill`, a `template`, `steps` or the `contracts`. An objective alone is refused"
  (DOCS line 693).
- Templates (DOCS line 695): "`single`, `impl_tests`, `impl_tests_review`, `multi_contract`, `fuzz`, `research`, `audit`".
  There is no "proof", "circuit" or "goal" template for buyers.
- Multi-step: `shape` = "`chain`, `fan_out_join` or `dag`"; `steps` "Array, 1–6. One runnable skill per step" (DOCS
  lines 696-697).
- Runnable skills a buyer may name (DOCS lines 808-820): implement: `build-contract-project`, `scaffold-project`,
  `implement-contract`, `implement-and-test`, `refine-project`, `fix-findings`, `implement-one-contract`,
  `adapt-contract-project`, `import-site`, `build-website`, `frontend-for-contract`, `implement-component`,
  `build-ponder-indexer`, `deploy-script`, `research-report`, `write-readme-and-docs`, `create-image`, `create-audio`,
  `create-video`; tests: `write-foundry-tests`, `gas-and-size-report`; review (read-only): `adversarial-review`,
  `audit-imported-code`, `site-content-check`; integrate: `integrate-project`.
- Reference-only skills (go in `references`, max 8, "never a step"): `defi-native`, `solidity-security-review`,
  `uniswap-v4-hooks`, `uniswap-v4-security`, `pashov-skill`, `pashov-xray`, `pashov-fizz`, `tob-entry-point-analyzer`,
  `tob-property-based-testing`, `better-interface`, `public-rpcs`, `evm-project-launch`, `evm-contracts-launch`,
  `custom-token-launch`, `eth-addresses`, `eth-concepts`, `eth-frontend-ux`, `eth-l2s`, `eth-security`, `eth-standards`,
  `eth-testing` (DOCS line 820).
- The live catalog has 64 skills (SKILLS, 10 Nov). Besides the above it lists internal ones a buyer cannot name:
  `audit-specialist`, `audit-judge`, `design-critic`, `oracle-assess`, `quick-answer`, `token-logo`, `workflow-planner`,
  and seven goal skills (`goal-orchestrator`, `goal-lead`, `goal-task`, `goal-code`, `goal-check`, `goal-judge`,
  `goal-chain`). Every skill is `"kind": "code"`. Its `checks` field is either `foundry` or `none`: there is no check
  profile for any other toolchain.
- Solidity/Foundry is the only build-and-test toolchain the verifier runs: "For contracts it is `forge build` and
  `forge test`. For a site it is the structure, paths and integrity … For a text output it is the structure alone."
  (DOCS line 344). READ `build-contract-project`: "the independent verifier carries 0.8.20 to 0.8.30 offline".
- Generic code that is not a contract or site is possible (`scaffold-project`: "Build a working project from an empty
  tree — its layout, its build configuration, and the thing itself."; publication type `code` = "code delivered to a
  repository that is none of the others", DOCS line 2206), but it is judged by `verifier-paths` (structure and allowed
  paths only), not by building or testing it. [SKILLS: `scaffold-project` judge `verifier-paths`, checks `none`]

### A3. What a brief contains (fields and limits)

Job body (DOCS lines 689-724), quoted limits:

| Field | Limit (verbatim) |
|---|---|
| `objective` | "Required. String, 1–8,000 characters; at most 4,000 for `template: "research"`" |
| `steps` | "Array, 1–6. One runnable skill per step" |
| `steps[].objective` | "1–3,000 characters, appended to the job objective for this step" |
| `steps[].acceptanceCriteria` | "1–8 strings, each 1–500 characters, added to the skill's own" |
| `steps[].paths` | "Up to 16 repository-relative paths this step may write." |
| `steps[].dependsOn` | "Up to 6 step keys. Required on every `dag` step … branches must join into one final step" |
| `steps[].variables` | "Map of string to string (key max 64, value max 2,000)" |
| `references` | "Array of up to 8 reference-skill ids, attached to every step" (plus up to 8 more per step) |
| `repoUrl` + `baseCommit` | "URI, max 512. With `baseCommit`; both or neither. Neither means an empty workspace"; "40 lowercase hex" |
| `contracts` | "Up to 4 contract names or relative `.sol` paths, each max 512" |
| `paths` | "Up to 16 repository-relative paths the job may write." |
| `inputs[]` | up to 32 per step; "`bytes` (0–64 MiB)"; "copy them from an accepted file in `/jobs/:id/result`" |
| `outputs[]` | up to 32 per step; "`name`, `path` under `artifacts/`, `mediaType`. All required. The job must produce exactly these" |
| research | `panelSize` "1–9", `panelQuorum` "1–9", `minCitations` "0–20", `rubric.contains` "1–8 strings, each max 500" |
| fuzz | `runs` "1,000–10,000,000. Fuzz template; exactly one harness in `contracts`" |
| whole request | "**Body**: 16 KiB max; 4 KiB on `/requests/import`. Quotes last 600 seconds." (DOCS line 683) |
| workflow | `request` "1–16,000 characters … Joined with `context` and `draft.objective`, it must fit 8,000 characters, else `objective_too_large`"; "16 KiB for the whole quote body" (DOCS lines 971, 986) |

- Attachments: there is no free upload by the buyer. Files enter a job only as (a) a public GitHub repository at a pinned
  commit, or (b) `inputs` that are accepted outputs of an earlier IMD job. DOCS line 902: "Any accepted named file can
  feed another job … Only accepted files qualify." DOCS line 804: "To build on work you did not pay for, pass its
  repository as `repoUrl` and `baseCommit`, and its files as `inputs`."
- Repo access: public GitHub only. DOCS line 762: "`repoUrl` and `baseCommit` can name your own public GitHub
  repository. Resolve the commit with `POST /requests/import` first; the quote reads it on GitHub again and refuses a
  private, missing or oversized one." Size caps (DOCS line 483): "`kind` `site` (up to 100 MB), `contracts` or `code`
  (200 MB)".
- Everything is public. SKILLMD: "The body is public forever and goes into the builders' prompts. Keep keys, passwords
  and private data out of it." DOCS line 2298: "Uploads are publicly downloadable by hash."
- Chaining jobs: `job.continue` (same paying wallet only; "Delivered: Into the project's repository, as a pull request
  merged by fast-forward", DOCS lines 782-791), or a new `job.open` on the delivered `repoUrl`/`baseCommit`
  (DOCS lines 920-933).
- Network access inside a task is per skill (SKILLS `requires`): contract skills (`build-contract-project`,
  `write-foundry-tests`, `adversarial-review`, the audit skills) have `requires: []`, i.e. no `network`; `build-website`,
  `scaffold-project`, `research-report`, `implement-component`, `goal-task`, `goal-code` require `network`.
  READ `build-contract-project`: "vendor any necessary dependencies as ordinary files when permitted. Never enable ffi
  or filesystem access."

### A4. How big one request / one step can be

What is published:
- Request text: 8,000 characters of objective, 6 steps of 3,000 characters each, all inside a 16 KiB body (above).
- What one worker task may carry (protocol schema in the public worker bundle, WREPO `dist/cli.js`, 0.1.17):
  `objective … .max(8e3)`, `acceptanceCriteria … .max(2e3)).min(1).max(32)`, `guidance … max(GUIDANCE_MAX)` with
  `GUIDANCE_MAX=64e3`, `reads … .max(64)` each inline read `INLINE_READ_MAX_BYTES=32768`, `inputs … .max(32)`,
  `outputs … .max(32)`, `dependencies … .max(8)`, `attempt … .min(1).max(3)`.
- Time and turn bounds per task (same file): `var TaskBudget=external_exports.object({maxTurns:external_exports.number()
  .int().min(1).max(200),maxWallClockMs:external_exports.number().int().min(6e4).max(4*60*6e4), inference: …enum(
  ["economy","standard","premium"])…`. So a single task is capped by the protocol at **200 turns and 4 hours of wall
  clock**. These are outer bounds; the budget the plane gives each skill is not published.
- Output size: a code change travels as a git bundle, "Up to 8 MiB"; named artifacts "Up to 64 MiB … at most 32 uploads
  and 128 MiB per lease" (DOCS lines 2272-2274).
- Observed run length per attempt, from SKILLS `record` (my arithmetic: `wallClockMs / attempts`, 10 Nov; includes
  failed and pending attempts, so indicative only): `adapt-contract-project` 38.8 min, `implement-and-test` 36.0,
  `frontend-for-contract` 32.5, `build-website` 28.8, `goal-task` 28.3, `goal-code` 28.3, `scaffold-project` 19.4,
  `build-contract-project` 18.7, `audit-imported-code` 14.7, `write-foundry-tests` 11.8, `audit-specialist` 10.8,
  `audit-judge` 9.3, `adversarial-review` 5.9, `refine-project` 5.2, `research-report` 3.8.
- Budgets do run out: STATUS (10 Nov) lists a failure cause "Wall-clock budget exhausted during repair | 2 runs".
- One whole audit job (four specialists in parallel, then the judge) took about 43 minutes end to end (section B7).
- Launch-specific hard limits (only for contracts deployed by IMD's factory; READ `audit-judge` and
  `build-contract-project`): "49,152 bytes of creation code with its arguments, 24,576 deployed"; "at most 16
  constructor arguments"; `evm_contracts` launches "1–8 contracts" (DOCS line 746).

Could not verify: any token limit per task (none is stated; `RuntimeUsage` only records `inputTokens`, `outputTokens`,
`turns`, `wallClockMs`); the actual `maxTurns`/`maxWallClockMs` per skill; any documented statement of "small enough for
one request". The docs give no such phrase. Sizing guidance is therefore an inference from the limits above: one request
is at most 6 steps, each step is one agent session of tens of minutes and at most 200 turns, writing at most 16 named
paths, with at most 4 contracts named.

### A5. Delivery, acceptance, rejection

- Delivery: `github` ("Publish source or report to GitHub. Code jobs and `research-report` default to true"), `ipfs`
  (site), `onchain` (launch only) (DOCS lines 730-732). Result: "`GET /jobs/:id/result` | Accepted `source` and `files`
  with download URLs and hashes, `complete`, `delivery`" (DOCS line 1995). A job "ends `completed` or `blocked` with
  `blockedReason`" (SKILLMD step 5).
- Acceptance is by a central verifier, not by the buyer. DOCS lines 338-344: "The verifier judges every submission,
  independently of the agent that produced it. Each verdict is accepted or rejected, with the checks that ran." It
  "restores the base the agent started from and applies the signed bundle. It then proves the result is what was claimed:
  the commit ancestry, the tree hash, that only allowed paths changed, and that the named outputs exist."
- Rejection reasons (DOCS lines 348-357): `tests_failed`, `build_failed`, `path_violation`, `tree_mismatch`,
  `dependency_missing`, `missing_required_file`, `fmt_failed`, `analysis_failed`, `bundle_invalid`, `timeout`.
- Retries (DOCS lines 361-363): "**Attempts**: Three in all." "**Findings**: A high or critical finding with a
  reproduction reopens the implementation, at most twice."
- The buyer has no accept/reject step and no dispute route in the docs. Could not verify any buyer-side acceptance.
- Static analysis is part of contract acceptance. READ `build-contract-project`: "The verifier runs Slither on your
  source and rejects the work outright on six of its detectors … and workers cannot run Slither first." Release note of
  28 Sep 2026 (WREPO history): "Launch quality, phase 2a: Slither and Aderyn read every contract step, and reviewers see
  what they found".
- Record: "When a job ends, its verdicts, rejections included, are written to the ERC-8004 reputation registry as
  reviews"; score policy "`acceptance-v2`: **1** for accepted, **0** for rejected" (DOCS lines 338, 371).

### A6. Multi-agent review and panels

- DOCS line 315: "Most steps go to one machine, research and audits to a panel." Line 322: "Nobody reviews their own
  work".
- Adversarial review (DOCS line 367): "A different agent, on a different seat, reads the work with no write access and
  tries to break it. Each finding has a severity, a path and line, and a reproduction. Only a high or critical finding
  with a reproduction blocks."
- Audit panel (DOCS line 769): "Four specialists (math, permissions, economics, control flow) read the pinned tree at
  once; a judge reproduces, merges and ranks what they found." On launches (DOCS line 822): "A launch planned from
  `steps` has its final `adversarial-review` replaced by an audit panel: four `audit-specialist` nodes, then an
  `audit-judge`. The planner adds them; do not name them yourself."
- Research panel: `panelSize` 1–9, `panelQuorum` 1–9 (DOCS lines 756-757). Oracle panel: 5–100 members (CAP `limits`).

### A7. Which models do which tasks

- DOCS lines 288-295 (table "What each job needs"): "Contract builds, tests and audits | Foundry | `claude-fable-5-1` or
  `gpt-6-astra`, high or above; `claude-opus-5-5` or `gpt-6.1-sol`, medium or above"; "Websites | Browser preferred | The
  same models"; "Images | Image tool | Any model"; "Research, oracle and the rest | No tools | Any model"; "Goals that ask
  for Venice | Venice key | Venice models".
- DOCS line 299: "Some steps name a model. Tests on Claude run on `claude-opus-5-5`, and websites on `gpt-6.1-sol` or
  `claude-opus-5-5`, at high or above."
- DOCS line 322: "Images go to Codex first, audits and other security work to Claude first."
- New on 10 Nov (WREPO README diff and release note 0.1.17+659102ae): "Claude Fable 5.2 is an approved premium model,
  from high effort"; README now reads "Claude Fable 5.1 or Fable 5.2 at high effort or above or Claude Opus 5.5 at medium
  or above".
- Tier labels per skill (SKILLS `inference`, 10 Nov): `premium` = `build-website`, `frontend-for-contract`,
  `design-critic`, `goal-orchestrator`, `goal-lead`, `goal-judge`; `economy` = `oracle-assess`, `quick-answer`; every
  other runnable skill, including all contract and audit skills, is labelled `standard`. Note the mismatch in naming:
  the docs still require an approved premium model on the machine for all "contract work" ("The first two rows, and every
  step of a workflow, are contract work", DOCS line 297). How the `standard` label on contract skills maps to the model
  actually used was not resolved. NOT VERIFIED.
- LOCAL-README line 18 says "premium (contract and frontend) tasks are only offered to Fable 5.1 at high effort" and that
  "Opus does not unlock any extra work". The upstream README and docs today also accept Opus 5.5 at medium, Fable 5.2 at
  high, GPT-6 Astra at high and GPT-6.1 Sol at medium, so that line of the local manual is out of date.
- Helpers: SKILLS gives `subagents` 3 for `audit-specialist`, 4 for `audit-judge`, `audit-imported-code`,
  `write-foundry-tests`, `goal-task`, `goal-code`; but HEALTH today reports `"taskSubagents": {"audit-specialist": 0,
  "audit-judge": 0, "audit-imported-code": 0, "write-foundry-tests": 0}`, which reads as helpers currently switched off
  for those four skills. The meaning of that field is not documented. NOT VERIFIED.

---

## B. Audit template

**Verdict: Verified.** The audit template's instructions and its checklist are public, word for word, through the
`/reads/skill/…` route. It is a Solidity/EVM audit only. None of the audit texts mentions zero-knowledge circuits.

### B1. How the template is invoked and what it returns

DOCS lines 769-780:
> "`template: "audit"` audits code that already exists and does nothing else: no build, no fix, no deployment. Four
> specialists (math, permissions, economics, control flow) read the pinned tree at once; a judge reproduces, merges and
> ranks what they found. Name the code with the `repoUrl` and `baseCommit` that `POST /requests/import` returns with
> `kind: "contracts"`, passed as returned. `ipfs` and `onchain` are refused."
>
> "The report is public once the judge is accepted: as Markdown at `GET /jobs/:id/report.md`, and as data in the judge's
> accepted submission at `GET /jobs/:id/submissions`, each finding with a location, a reproduction and often a Foundry
> proof. GitHub delivery is off by default; with `github: true` the same file is committed as `AUDIT.md` in IMD's
> research repository. Your code is not copied anywhere."

SKILLMD: "Say in the objective which contracts matter and what worries the user. The audit only reads; it fixes nothing."

The import kind is `contracts`, and for a launch the repository must be "A Foundry repository" (DOCS line 765).

### B2. The specialist's instructions (READ `audit-specialist`, version 5, digest `e7589be4…b1ad`), key passages verbatim

> "You are one of four specialists auditing this project at the same time. Each specialist takes one area, and a judge
> reads all four reports afterwards, merges duplicates, reproduces what is claimed, and decides what the author must fix."
>
> "Your area and the guides for it are named in the assignment. The guides are in the supplied Pashov reference
> (`.imd/reads/skills/pashov-skill/REFERENCE.md`) … Read the Senior Auditor's Mindset first, then your three guides, and
> check this code against each failure mode they list. Say which parts of your area you covered and which you could not
> reach within your budget."
>
> "Record that coverage, not just the findings. When the assignment lists the code's entry points, write one coverage row
> for each: `holds` … `finding` … or `unreached` when your budget ran out first."
>
> "Each finding needs a concrete reproduction: the exact call sequence, inputs and state, and what happens against what
> should. Cite the file and line, and copy the lines you mean into the snippet … Severity follows impact: critical and
> high for loss of funds, funds paid to the wrong party or permanent breakage, medium for loss under specific conditions
> or broken guarantees, low for the rest. … Static analysis output may be in front of you; treat it as leads for your
> area, never as findings on its own."
>
> "You write nothing: a submission that changes any file is rejected. Your output is findings."

### B3. The four areas and their twelve guides (READ `pashov-skill`, version 6, adapter text verbatim)

> "split the twelve in the four groups: math (Math Precision, Boundary, Numerical Gap), permissions (Access Control,
> Trust Gap, Asymmetry), economics (Economic Security, Invariant, Flow Gap) and control flow (Execution Trace, Periphery,
> First Principles)."

The reference is "Adapted from Pashov's solidity-auditor VERSION 3" (upstream https://github.com/pashov/skills/tree/main/solidity-auditor,
MIT, per SKILLS). Section headings of `REFERENCE.md` (56,984 characters, digest `df78fa8b…7210`), verbatim:
"Senior Auditor's Mindset" ("1. The Feynman test", "2. Socratic questioning", "3. Inversion"), "Math Precision Agent",
"Access Control Agent", "Economic Security Agent", "Execution Trace Agent", "Invariant Agent", "Periphery Agent",
"First Principles Agent", "Asymmetry Agent", "Boundary Agent", "Numerical Gap Agent", "Trust Gap Agent",
"Flow Gap Agent", "Finding Validation" ("Gate 1 — Path execution", "Gate 2 — Reachability", "Gate 3 — Trigger",
"Gate 4 — Impact", "Confidence", "Common protections", "Lead promotion", "Leads", "Do Not Report").

Checklist items inside each guide (the bold item titles, verbatim):

- **Math Precision**: "Map the math." "Wrong rounding direction." "Zero-rounding." "Amplify truncation." "Overflow
  intermediates." "Mismatch decimals." "Break downcasts." "Share-price inflation." "Lose sign on narrow-int casts."
  "Overflow inside intermediate shifts." "Round at sole-occupant boundary." "Cast-wrap at saturation." "Truncate interest
  accrual on tiny principals." "Underflow in unsigned-bonus computations." "Mask the wrong bits." "Divide by an
  unconstrained edge value." "Every finding needs concrete numbers."
- **Access Control**: "Map the permission model." "Exploit inconsistent guards." "Unprotected initialization." "Escalate
  privileges." "Exploit confused deputies." "Abuse delegatecall/proxy."
- **Economic Security**: "Break dependencies." "Exploit token misbehavior." "Extract value atomically." "Break ERC
  compliance." "Exploit token interfaces." "Abuse sentinel addresses." "Starve shared capacity." "Legitimate features
  turned against the protocol." "Every finding needs concrete economics."
- **Execution Trace**: "Parameter divergence." "Value leaks." "Encoding/decoding mismatches." "Sentinel bypass."
  "Untrusted return values." "Stale reads." "Partial state updates." "Wrong-state execution." "Operation interleaving."
  "Cross-message field manipulation." "Mid-operation config mutation." "Dependency swap." "Approval residuals."
- **Invariant**: "Conservation laws." "State couplings." "Capacity constraints." "Interface guarantees." "Break
  round-trips." "Exploit path divergence." "Break commutativity." "Abuse boundaries." "Bypass cap enforcement." "Exploit
  emergency transitions." "Use stale cached state after coupled mutation." "Reset timers via secondary call paths."
  "Mutate global parameters during in-flight operations." "Diverge view from write." "Break peg invariant during partial
  mint." "Strand value across emergency transitions." "Bypass capacity caps on secondary mutation paths." "Couple
  state-price reads across mutating paths."
- **Periphery**: "Exploit unvalidated inputs." "Corrupt return values." "Exploit hidden state side effects." "Break edge
  cases." "Exploit assembly byte-width bugs." "Spoof existence detection." "Brick via gas complexity." "Race provider
  swaps." "Truncate cross-encoded recipients." "Read library under wrong storage context." "Skip ERC165 dispatch in
  decoder fallbacks." "Hardcode magic IDs in helper lookups." "Read oracle in same block as deposit." "Manipulate
  single-block oracles." "Trust divergence-check dead code."
- **First Principles**: "Do not pattern-match." "Stale reads." "Desynchronized coupling." "Boundary abuse."
  "Cross-function breaks." "Assumption chains."
- **Asymmetry**: steps "Enumerate every paired surface", "Storage-write symmetry diff", "Branch-symmetry diff",
  "Storage-variable lifecycle audit", "Admin-function variants", "Bad symmetry (defensive checks that should not exist)".
- **Boundary**: steps "Enumerate every boundary", "For every external call: four corner cases", "For every payable
  function: three branch cases", "For every sentinel-address branch: walk both sides", "For every bytes input /
  abi.decode: corruption cases".
- **Numerical Gap**: "Seam 1 — precision × invariant." "Seam 2 — boundary × precision." "Seam 3 — boundary × invariant."
  "Seam 4 — three-way."
- **Trust Gap**: "Seam 1 — access × economics." "Seam 2 — economics × asymmetry." "Seam 3 — access × asymmetry."
  "Seam 4 — three-way."
- **Flow Gap**: "Seam 1 — execution × periphery." "Seam 2 — periphery × first principles." "Seam 3 — execution × first
  principles." "Seam 4 — three-way."
- **Finding Validation**, "Do Not Report" (verbatim): "Linter/compiler issues, gas micro-opts, naming, NatSpec. Admin
  privileges by design. Missing events. Centralization without exploit path. Implausible preconditions (but
  fee-on-transfer, rebasing, blacklisting ARE plausible for contracts accepting arbitrary tokens)."

### B4. The judge (READ `audit-judge`, version 6, digest `fc6fe41e…bd7f`), key passages verbatim

> "For each specialist finding: 1. Reproduce it against the code. Trace the exact calls and state, or write the test in
> your head precisely enough that the author could run it. A finding you cannot reproduce is dropped. 2. Merge
> duplicates … 3. Recalibrate severity by impact … 4. Keep the reproduction concrete".
>
> "Then read the code once more yourself, with the Senior Auditor's Mindset from the supplied Pashov reference, for
> anything all four missed."
>
> "Your coverage record is the one that counts. When the assignment lists the code's entry points, answer each one
> yourself".
>
> "When this is a second round … The specialists do not run again: their reports describe the code before the fix, and
> you are the only reviewer who reads what the fix changed."

Note "write the test in your head": reproduction by the judge may be a traced argument, not an executed test.

### B5. Related review texts

- READ `adversarial-review` (version 3): "**Every finding names a concrete failing input or state.**" … "**Say when you
  found nothing.**" … "**Review the requested design, not a replacement design.**"
- READ `audit-imported-code` (version 4) lists what to report: "defects: loss of funds, funds paid to the wrong party,
  broken accounting, reentrancy, access control that is weaker than the effect it guards, arithmetic that rounds the
  wrong way or overflows, broken invariants;" and "what the launch forbids, as medium findings … minting after launch;
  pausing, freezing, blacklisting or seizing holder balances; DELEGATECALL, CALLCODE, SELFDESTRUCT; proxies,
  initializers and anything configured after deployment rather than in a constructor."
- READ `solidity-security-review` (version 3) section headings: "Who can call what", "Value in and out" (includes
  "Reentrancy on every external call that happens before state is settled"), "Arithmetic and limits", "Time, ordering
  and randomness", "Signatures and identity", "External dependencies", "What the tests do not cover".

### B6. Does it mention ZK, Circom, Noir, Groth16, under-constrained signals, trusted setup, formal verification, fuzzing, invariant testing?

Case-insensitive counts of each term in the texts fetched on 10 Nov:

| Text | circom / noir / groth16 / plonk / snark / "zk" / zero-knowledge / under-constrained / trusted setup | "circuit" | formal verification | fuzz | invariant | reentrancy | access control |
|---|---|---|---|---|---|---|---|
| DOCS (158 KB) | 0 | 0 | 0 | 15 | 4 | 0 | 0 |
| SKILLMD | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `pashov-skill` REFERENCE (the audit checklist) | 0 | 0 | 0 | 1 | 44 | 2 | 8 |
| `audit-specialist`, `audit-judge`, `adversarial-review` | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `audit-imported-code` | 0 | 0 | 0 | 0 | 2 | 1 | 1 |
| `solidity-security-review` | 0 | 0 | 0 | 0 | 1 | 1 | 0 |
| `pashov-xray` | 0 | 1 (a "circuit breaker" on liquidations) | 7 (table rows "Formal Verification (Certora)", "(Halmos)", "(HEVM)" for counting a repo's existing tests) | 16 | 122 | 18 | 10 |
| `pashov-fizz` | 0 | 0 | 0 | 51 | 70 | 0 | 1 |
| `eth-security` | 0 | 0 | 0 | 5 | 0 | 13 | 3 |
| worker bundle `dist/cli.js` 0.1.17 | 0 (circom, snarkjs, nargo, noir, groth16, plonk, halo2, risc0) | not counted | 0 | present | 7 | not counted | not counted |
| SKILLS (64 descriptions) | 0; the only "zk" string is "zkSync" in `eth-l2s` | 0 | 0 | present | present | 0 | present |

- **ZK circuits: not mentioned anywhere** in the audit template, its references, the docs, the skill catalog or the
  worker. No skill, check profile or reference covers Circom, Noir, Groth16, constraint soundness or trusted setup.
- **Fuzzing: yes, as a separate product**, Foundry only. Template `fuzz` (`runs` 1,000–10,000,000, "exactly one harness
  in `contracts`"); workers report `counterexample`, `exhausted` or `failed` (DOCS lines 2336-2346). LOCAL-README line
  593: "Fuzzing campaigns run on the CPU only and use **none** of your Claude allowance".
- **Invariant testing: yes**, as Foundry invariant tests written by `write-foundry-tests`: "**Invariants for anything
  that holds value.** … write Foundry invariant tests: a handler contract that calls its functions in random order with
  bounded inputs" (READ `write-foundry-tests`, version 7).
- **Formal verification: not offered.** The only occurrences are Pashov x-ray's table for counting a target repo's
  existing Certora/Halmos/HEVM tests, and a worker rule that *refuses* a Halmos solver flag in a test ("workers refuse a
  test that sets anything else there, or a Halmos solver").
- Static analysis: Slither and Aderyn (B and A5 above).

Unknowns: the texts of `tob-entry-point-analyzer`, `tob-property-based-testing`, `eth-testing`, `defi-native`,
`uniswap-v4-security` were not term-counted in this pass (they are general Solidity references by their SKILLS
descriptions). Whether the audit template would accept a repository that holds circuits beside Solidity, and what the
specialists would do with non-Solidity files, is not stated anywhere. NOT VERIFIED.

---

### B7. What a real audit job looks like (one job record read, 10 Nov 23:13 UTC)

`GET https://api.imd.fun/jobs/b3859010-b6e0-480f-a7fc-9cd17e85e69a` (`"template": "audit"`, `"state": "completed"`):
- Five nodes, all `"role": "review"`, `"attempt": 1`, each on a different seat: `audit_math` (seat 970),
  `audit_permissions` (seat 1591), `audit_economics` (seat 1552), `audit_flow` (seat 544), and `audit_judge` (seat 694)
  with `"dependsOn": ["audit_math", "audit_permissions", "audit_economics", "audit_flow"]`.
- Time: `"createdAt": "2026-11-07T12:34:14.689Z"`, judge accepted `"updatedAt": "2026-11-07T13:16:55.615Z"`: about 43
  minutes from payment to report (my subtraction). One WorkRegistry transaction recorded the five reviews.
- Report header (`/report.md`, 41,352 bytes): "Four agents audited the code as it is at `e879a14`, each in one area
  (math, permissions, economics, control flow), and a judge reproduced, merged and ranked what they found, then read the
  code once more itself. Nothing in the repository was changed or deployed." Footer: "Acceptance means the report met
  the job's checks; it is not a guarantee that the code has no other defects."
- The report is a list of findings (here "4 medium · 6 low · 1 info") with file, line, snippet and reproduction. It has
  no coverage table and no statement of what was not reviewed (the words "coverage", "unreached", "out of scope" occur 0
  times), although the specialist prompt asks for coverage rows. Several reproductions end "Verified by reading lines …",
  i.e. traced by reading, not by running a test, even though that buyer asked for "Foundry tests, fuzzing, invariant
  testing".
- The audit template is also being used on non-Solidity code: 78 of the 432 public audit objectives name TypeScript,
  Python or JavaScript (my regex count), e.g. job `c0ebfa5e-cf39-4631-9e44-cee039176a70` ("TypeScript and Python, no
  Solidity in scope … If the audit tool cannot cover this scope, say so plainly."). So the plane does not refuse a
  non-Solidity scope, but the specialists still get the Solidity checklist of B3. How well that works was not assessed.

---

## C. Track record

**Verdict: (i) smart-contract audits: Verified, many public examples. (ii) zero-knowledge circuit audits: none found**,
after a full-text search of every job objective and of all public audit reports that could be reached (limits stated
below). Developer posts on X and the holders-only Telegram could not be read. No audit by IMD of IMD's own contracts,
and no outside audit of them, was found either.

### C1. Smart-contract audits (public, with links)

- Counts: `GET /publications/counts` → `{"counts":{"all":5308,"code":135,"media":1420,"sites":770,"audits":432,
  "tokens":706,"research":1774,"contracts":1058}}` (10 Nov 14:57 UTC). `GET /publications?type=audits` listed 432 audits
  at 14:58 UTC and 450 at 23:11 UTC. I hold 432 distinct audit records (page 1 from 14:58, pages 2-5 from 23:11; up to
  18 of the newest are therefore missing).
- Of those 432 (my tallies from the API records): all have a paying wallet (`paidBy` set; 59 distinct wallets); 83
  distinct repositories; 396 are on repositories outside the `identity-md-launches` org; published 4 in Sep, 379 in Oct,
  49 in Nov 2026; 427 report at least one finding; severities summed: 6 critical, 102 high, 423 medium, 1,414 low, 1,356
  info. A few buyers account for many jobs (top repository owners: 69, 52, 52, 36, 31 audits), so this is repeat use by
  a small group, including re-audits after fixes.
- IMD's `Identity-md/research` GitHub repository (cloned 10 Nov, HEAD `69562df`) holds 380 job folders and 122 `AUDIT.md`
  files.
- Examples (job page `https://explorer.imd.fun/jobs/<id>`, report `https://api.imd.fun/jobs/<id>/report.md`):

| Published | Job id | Repository @ commit | Findings | Objective starts |
|---|---|---|---|---|
| 2026-11-07 | `b3859010-b6e0-480f-a7fc-9cd17e85e69a` | github.com/kadiri-seer/quietpay @ e879a142 | 4 medium, 6 low, 1 info | "Conduct a deep security audit of the current QuietPay repository." |
| 2026-11-07 | `ad781e59-5e5f-41c2-a7b0-29ed0fed2f4c` | github.com/imdbell/imd-bell-contracts @ 8bdb3c7f | 1 high, 2 medium, 3 low | "Audit the IMD Bell contracts in src/ at this commit" |
| 2026-11-04 | `a80b18b5-d8d2-4c9d-a1a6-10f3473be4e9` | github.com/fa11up/miyamints-contracts @ a991e8c9 | 5 high, 1 medium, 2 low, 4 info | "Audit the alignment vaults: src/vaults/uni/ (UniAlignmentVault, UniAlignmentVaultFactory)" |
| 2026-11-03 | `1bd59a2f-b0be-4bd1-aa75-0c90009b5dcc` | github.com/contractclaus/claus-network-contracts @ 25df8a95 | 2 high, 3 medium, 4 low, 1 info | "Audit the code at exactly these repository-relative entry paths: ["src/DynamicSellFloorProgram.sol"]." |
| 2026-11-01 | `6acefe89-1311-462a-8f78-5697050c327d` | github.com/nitro-slav/imduel @ 8a46d287 | 1 high, 1 medium, 3 low, 3 info | "Audit IMDuelHook in this repository, a Uniswap v4 hook" |
| 2026-10-20 | `42b4b3b5-4c53-4368-aa49-ffdd71222d33` | github.com/JJ-ME55/tombola-contracts @ 705e9d24 | 1 high, 3 medium, 3 low, 3 info | "Audit the Tombola draw contracts in this repository: src/TombolaDraw.sol and src/TombolaSplitter.sol" |
| 2026-10-18 | `2a2826a6-6ce0-4dcb-8b20-ed61e0ae0004` | github.com/RobertKodes/nightshift | 2 critical, 2 high, 3 medium, 4 low, 1 info | (not read) |
| 2026-10-14 | `85083c05-6dca-432c-85a9-4969c58c6303` | github.com/identity-md-launches/launch-1545-goblin-gold | 1 critical, 3 high, 2 medium, 3 low, 1 info | (a launch's own audit) |

  Only the first report was opened and read. The others are listed from the API's records, not checked for quality.
  Nothing here measures how many real bugs were missed or how many findings were false.
- Audit panels also run inside launches (four `audit-specialist` nodes plus an `audit-judge`). SKILLS record, 10 Nov:
  `audit-specialist` "attempts": 5982, "accepted": 4829, "rejected": 0; `audit-judge` 1813 / 1451 / 0. A specialist or
  judge submission is "accepted" when it meets the format checks; zero rejections says nothing about audit quality.
- IMD's own contracts: Etherscan showed "No Contract Security Audit Submitted" (earlier notes, 9 Nov); Bankless, 25 Sep
  2026 (https://www.bankless.com/read/inside-imd-ethereum-s-new-ai-swarm-experiment.md, read through WebFetch): "treat
  this like an experiment that hasn’t been formally audited for now." The worker's own text says the custody contracts
  "wait for their audit" (earlier notes). Not re-checked today.

### C2. Zero-knowledge circuit audits: nothing found

What was searched on 10 Nov 2026, and the result:

| Where | Method | Terms | Result |
|---|---|---|---|
| All jobs except oracle panels: `GET https://api.imd.fun/jobs?exclude=oracle&limit=50&q=<term>` ("`q` (objective or id prefix …)", DOCS line 1991) | substring match on the objective | circom, groth16, snark, plonk, zero-knowledge | `count` 0 for each |
| same | same | nullifier | 2 jobs: audit `b3859010` (below) and a research report `59734b38` |
| same | same | zk | 4 jobs: two research reports, one goal (a snapshot of rollups), one website; none is an audit or a circuit |
| same | same | noir | 6 jobs, all games or sites (French text, "noir" as a colour or word); none is Noir code |
| same | same | circuit | 15 jobs: "circuit breaker" hooks, a game called "Squeek Burrow Circuit", logos; none is a ZK circuit |
| 432 public audit records (full objective text in each record) | regex over the JSON | circom, noir, groth16, plonk, snark, stark, zk, zero-knowledge, poseidon, halo2, risc0, sp1, semaphore, tornado, mixer | 0 for every term |
| same | same | nullifier 1, circuit 1 ("circuit breaker"), witness 3 (unrelated uses), privacy 7 | no circuit audit |
| 122 `AUDIT.md` files in github.com/Identity-md/research | grep | circom, noir, groth16, plonk, snark, zero-knowledge, zkp, zk, halo2, risc0, under-constrained, trusted setup, .zkey, r1cs, nullifier | 0 files |
| Explorer search `https://explorer.imd.fun/api/search?q=<term>` (jobs, oracle questions, publications) | site search | circom, groth16, snark, plonk, halo2, risc0, sp1, zkp, zero-knowledge, nullifier, poseidon, formal verification, halmos | `{"groups":[]}` for each |
| Web search (2 queries naming IMD/IdentityMD with circom / zk / groth16 / noir / audit) | search engine | | no result about IMD |
| github.com/Identity-md/awesome-imd README | grep | zk, circom, circuit, privacy | nothing relevant |

- The nearest case: audit job `b3859010-b6e0-480f-a7fc-9cd17e85e69a` (7 Nov 2026) audited a payments app whose brief
  listed "Shielded pool: 0xbow integration, Merkle proofs, nullifiers, root updates, approval churn, stale proofs, double
  withdrawals and ragequit." Its report covers Solidity routers, a relayer and web code. The words circom, groth, snark,
  circuit and verifier occur 0 times in the report; "nullifier" occurs once, in the quoted brief. It treats proofs as
  inputs to a router (`proof{pubSignals[2] = …}`); it does not review any circuit. This is an audit of contracts that
  *use* a shielded pool, not an audit of a zero-knowledge circuit.
- Statement: **no public evidence was found that IMD has audited, built or tested any zero-knowledge circuit** (Circom,
  Noir, Groth16 or other), and nothing in its tooling (section B6) supports one.

How thorough this is, and what it misses:
- Strong: the `q` search runs on the control plane over every non-oracle job's objective (about 6,900 jobs), and the 432
  audit records were scanned in full.
- Limits: (1) a job whose objective does not use any of these words but whose repository contains circuits would not be
  found; the 432 audited repositories were not opened. (2) Up to 18 of the newest audit records were not scanned, though
  the `q` search covers their objectives. (3) Oracle questions were searched only through the explorer search, which is
  not full-text (it returned nothing for "nullifier" although one job objective contains it). (4) Goal items and research
  reports mention ZK topics as subject matter (for example PLONK in a rollup survey); these are reports, not audits.
  (5) The developer's X account and the holders-only Telegram were not readable (earlier notes: X returned HTTP 402), so
  any claim made only there is NOT VERIFIED.

---

## D. Goals feature: changes since 9-10 Nov 2026

**Verdict: Verified, small change found.** A new worker minor version, 0.1.17, shipped on 10 Nov with goal fixes and a
new approved model. The custody half is still switched off, and no doc or paid action for goals has appeared.

Changed:
- Newest worker: **0.1.17+33599a32**, commit `7548341` dated 2026-11-10T05:06:10Z, tag `worker-v0.1.17-33599a325902`
  (WREPO `build.json`: `"version": "0.1.17", "daemonVersion": "0.1.17+33599a32"`). Four 0.1.17 builds on 10 Nov
  (02:39, 03:01, 04:09, 05:06 UTC). Previous notes had 0.1.16+3850b894 as newest at 10 Nov 00:13 UTC.
- Release notes, verbatim from the git history of `RELEASE_NOTES.md`:
  - 0.1.17+1dd97a72 (02:39): "Worker 0.1.17: the release that carries the four goal step fixes"; "Worker: an upload the
    plane could not take is sent again, three tries in all"; "Worker: a decisions file is checked against its schema
    before it is sent, and a fault names its field"; "Worker: a run on Claude Code is told how many turns it has";
    "Worker: what a goal item leaves in its workspace is left behind, not a path violation".
  - 0.1.17+7984da50 (03:01): "Bump @noble/curves from 1.9.1 to 1.9.7 in the npm-minor-and-patch group" (this reverses
    the 9 Nov pin "back to 1.9.1, the version the juror signer is written against").
  - 0.1.17+659102ae (04:09): "Claude Fable 5.2 is an approved premium model, from high effort"; "Worker: imd doctor says
    why the network paused a machine, and counts failed runs only where runs paused it".
  - 0.1.17+33599a32 (05:06): "A goal names the model its items run on machines' own logins"; "A goal's orchestrator, lead
    and judge ask for Claude Fable 5.2 on Claude machines".
- Control plane commit moved: VERSION returns `"commit":"fb0eafa6c75e84cb4abb878324852501341c8313"`; HEALTH
  `"version": "0.1.0+fb0eafa6"` (was `69117c07` at 10 Nov 00:13 UTC).
- HEALTH `goalPlanners` now: `"qualified": {"lead": 246, "orchestrate": 16, "value": 2}`, `"orchestratedGoals": 3`,
  `"online": 844, "premium": 679` (was lead 270, orchestrate 15, value 1, orchestratedGoals 4).

Not changed (checked 10 Nov ~14:50 UTC):
- Paid actions: still the same eight, no `goal.open` or `goal.topup` (CAP, OPENAPI).
- Docs: `llms.txt` has the same byte count (158,265) as on 9-10 Nov; the only goal sentences are still "Venice and
  OpenRouter models only work on goals, the big jobs the swarm splits across many agents." and "Only goals that ask for
  Venice use it". `job.open` templates still exclude `goal`. No Goals docs page.
- Worker bundle 0.1.17: `JUROR_CANONICAL=Object.freeze({});` unchanged (no juror root named on any chain);
  `MANDATE_MODES={owner:0,jury:1}` and `JURY_MAX_SIZE=255` unchanged; `BudgetEscrow` and `goal.open` still absent from
  the bundle.
- No release note since 9 Nov mentions mandates, juries, escrow, earnings epochs or an audit of the owner contracts.

Not re-checked in this pass (to keep requests low): the feature-flag routes `GET /jury/keys/:id` and
`GET /earnings/epochs`, the two Sepolia test goals, the count of goal jobs, and the developer's posts on X (X returned
HTTP 402 in the earlier pass). So "custody still off" rests on the worker bundle, CAP and the release notes, not on a
fresh read of those two routes. NOT RE-VERIFIED.

---

## E. Network size (10 Nov 2026, ~14:48-14:52 UTC)

**Verdict: Verified** (explorer and API both answered).

- STATUS: "Agents | 1,151 agents | 844 online"; "Working | 6 working | 1 % of 842 online"; "Fleet | 1,460 open slots |
  codex 500 | claude 339 | both 3"; "Updates | 787 of 842 on latest | 55 outdated"; "Jobs | 6,908 jobs | 6,540 done | 364
  incomplete"; "Oracle | 9,266 questions | 8,712 signed | 553 unsigned"; "Steps | 97% accepted | 1,949 in 24h | 19,201
  agent hours"; "Published | 1,686 shipped | 936 contracts | 750 sites"; "All 15 checks passing | control plane fb0eafa6".
- HEALTH: `"connectedDaemons": 1048`, `"workingNow": 6`, `"activeEnrollments": 1081`, `"acceptedLastDay": 1949`,
  `"payments" … "paid": 7924`, `goalPlanners.online` 844, `goalPlanners.premium` 679.
- ACT: `{"reachable":true,"workflows":0,"jobs":4,"oracle":1,"working":6,"total":5 …}`.
- "Agents 1,151" counts seats that have ever submitted work (per the earlier notes); "online" 844; machines holding an
  approved premium model 679 (HEALTH field name `premium`; its definition is not documented).
- Compared with 10 Nov 00:13 UTC (earlier notes): agents 1,149 → 1,151; online 871 → 844; working 118 → 6; jobs 6,883 →
  6,908; paid orders 7,899 → 7,924.

---

## Could not verify (all sections)

1. The time, turn and token budget the control plane gives each skill. Only the protocol's outer bounds (200 turns,
   4 hours) and observed averages are public.
2. Any official statement of how large one request should be. None exists in the docs; section A4 is inference.
3. How the `standard` inference label on contract and audit skills relates to the "approved premium model" rule.
4. The meaning of HEALTH `taskSubagents` (all 0 for the audit skills today) and whether audit helpers are in use.
5. Audit quality: false-positive and miss rates. No benchmark or outside comparison was found.
6. Whether an audit of a repository holding circuits would be refused, ignored or attempted. No such job exists to look at.
7. Developer statements on X or in the holders-only Telegram about audits, ZK work or the Goals roll-out.
8. Today's state of the jury and earnings feature flags (routes not re-read; see section D).
9. Buyer-side acceptance or dispute: the docs describe none.

## Raw copies

Scratch directory of this session (not in the repository):
`/tmp/claude-0/-home-user-claude/4107f7be-64fa-56df-982c-ff1f40a87dd3/scratchpad/raw/` (docs, skill.md, capabilities,
health, skills, `reads/` with every skill text and the audit list pages, `explorer/` search results, `jobsq/` job
keyword searches) and
`/tmp/claude-0/-home-user-claude/4107f7be-64fa-56df-982c-ff1f40a87dd3/scratchpad/untrusted/` (clones of the worker,
research and awesome-imd repositories; `rn_all.txt` is the full release-note history).
