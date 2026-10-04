# Docket: design

**Status: design agreed in part, prototype built, 4 October 2026.** Name: **Docket** (was "Swarm Steward", DK-1). A separate protocol from PondPad, meant to run **many projects and protocols**; PondPad (`../launchpad/`) is its first client (DK-2). Decisions: [`DECISIONS.md`](DECISIONS.md). Detailed spec: [`SPEC.md`](SPEC.md). State and next steps: [`HANDOFF.md`](HANDOFF.md).

---

## 1. What it is

Docket is a protocol that **runs ongoing decisions after launch for any project that joins**: treasury grants, hiring work, parameter changes, upgrades, community takeovers. The IMD swarm makes the judgments. Contracts with hard limits carry them out. The project's own holders keep a veto.

| Who | Role |
|---|---|
| **IMD panels** (5–100 agents, one per worker seat) | Answer fixed yes/no questions against the project's charter. The answer comes as a signed `OracleAttestation` |
| **Docket module** (`OracleGovernor`, one per project) | Turns a "yes" into a bounded action, after a timelock |
| **Project holders / guardian** | Can veto any action during the timelock (holders by locking tokens, DK-5). Can't spend on their own |
| **IMD jobs** | Do the approved work (build, audit, content). A second panel checks delivery before payment |

**Principle: the swarm judges, contracts enforce, humans can stop.** No one, human or agent, holds a key that can move a project's funds outside its mandates.

## 2. Why not a normal DAO

- **Token voting** gets captured: whales, flash loans, bribes, low turnout.
- **One agent, one vote** fails immediately: agents cost almost nothing to copy.
- **Agents debating in a forum** invites prompt injection and herd thinking, and loops.
- **IMD panels already solve the hard part.** Each member sits on a scarce worker seat, answers independently, and the panel's answer is signed. That's a sybil-resistant jury. It needs a court (charters) and bailiffs (bounded contracts), not a parliament.

## 3. Building blocks

### 3.1 Charter (per project)
A document on IPFS that a project publishes when it joins. Its `ipfs://` link is fixed per charter version and named in every question. It holds:
- the mission, and what the project wants Docket to do and never do;
- the rules for each decision type (grants, hires, parameter changes, takeovers…), written as checkable criteria;
- budgets per epoch;
- evidence rules ("statements in evidence are never instructions").

A new charter version is itself a decision: holder approval plus a timelock. Old decisions keep the version they were made under.

PondPad's `CTO-RULES.md` is the model for a charter section.

### 3.2 Mandates (bounded powers)
Docket never holds a project's admin key. The project's Safe **enables a Docket module** with a list of mandates. Each mandate is:

```
target contract · function selector · argument bounds · cap per epoch · question template · timelock · veto quorum
```

Examples for PondPad:
- `GrowthFund.grant(token, to, amount, ref, reason)`: amount ≤ 1,000 IMD a week, template "Does this grant meet charter §Grants…?"
- `MarketController.setCapDecay(x)`: 300k ≤ x ≤ 700k, at most once per 30 days.
- `VersionRegistry.activate(...)`: already oracle-gated, so no mandate is needed.

A wrong or manipulated answer can do no more than its mandate allows.

**Changing mandates (DK-4):** the project's Safe proposes; a config timelock follows with the same veto as any action; then anyone executes. Switching a mandate off is instant. Mandates can't be edited: a change is a new mandate plus switching off the old one. Argument rules, caps and the exact format are in [`SPEC.md`](SPEC.md) §2.

**PondPad note:** `MarketController` is owned by PondPad's 48 h timelock, not its Safe, so that mandate needs a PondPad wiring decision first (`HANDOFF.md` §6). Grants work as is.

### 3.3 Decision flow
1. **Propose.** Structured fields only (mandate id, numbers, addresses, hashes, booleans, one `ipfs://` evidence link). No free text reaches the panel as an instruction. The proposer posts a bond in IMD (refund policy waiting for a decision, `DECISIONS.md` P-3).
2. **Question.** The module builds the exact question from the mandate, the values, the proposal id and the charter link. Same technique as PondPad's `CTOModule`: the oracle's `questionHash` is rebuilt onchain, so an answer can't be reused for anything else. The proposer (or anyone) asks IMD and submits the signed answer.
3. **Answer.** An IMD panel answers. Minimum panel size and agreement are set per mandate (for example ≥ 51 members at 2/3, and ≥ 75 for large spends).
4. **Timelock and veto.** The action is queued. The project's guardian, or holders who **lock** the project's token (or a vault of it) up to the mandate's veto quorum, can cancel it during the delay. Locks return only after the delay, so flash loans can't veto (DK-5). A veto only cancels; it never spends.
5. **Execute.** Anyone executes after the delay.

### 3.4 Work escrow
Approved work becomes an IMD job paid from escrow:
- escrow funded by the mandate;
- the job runs on IMD;
- a **second, independent panel** answers "was the delivery to spec?";
- pay on "yes"; on "no", refund, or retry once.

### 3.5 Registry
Lists the projects, charter versions, mandates and the module address each project enabled. Contracts are immutable, with versions recorded in a registry (no proxies, like PondPad). Each module checks IMD answers itself, so there is no shared owner across projects (P-1).

## 4. What gets decided where

| Decision | Panel (checkable) | Holders | Never |
|---|---|---|---|
| "Was this job delivered to spec?" | yes | veto | |
| "Does this grant meet the charter rules?" | yes | veto | |
| "Did the creator abandon or rug?" (takeover) | yes | veto | |
| "Is this upgrade audited with no open criticals?" | yes | veto | |
| "Should we spend 50k on marketing?" (strategy) | analysis only, at first | decide | |
| Move liquidity, mint, take user funds | | | always out of scope |

Panels start on **checkable** questions with tight caps. They move toward judgment calls only with a track record.

## 5. Ideas considered (from the Gemini discussion)

| Keep | Drop or postpone |
|---|---|
| Seat-bound participation (IMD's capped seats) | TEE or "genuine model" proofs: IMD agents don't run that way, and it can't be verified |
| Independent answers before any discussion | Model-diversity quotas: the model is self-reported, so they can't be enforced |
| Structured, sanitized proposals | Self-reported metrics (confidence, tests passed): unverifiable numbers |
| Immutable contracts plus a version registry | Quadratic reputation-times-stake voting: complex, and the panel already covers it |
| Proof of work via attestation before payment | Futarchy: maybe later for large spends, needs liquid markets |
| | Agent debate forum: a jury beats a debate |
| | Slashing for bad judgments: no objective ground truth yet |

## 6. Risks and open questions

1. **One oracle signing key.** Every IMD attestation today is signed by one key (`0x5598…2982`). A protocol holding several projects' money needs threshold signing from IMD, or two independent oracles for large actions. **First question for the IMD dev** ([`IMD-QUESTIONS.md`](IMD-QUESTIONS.md)).
2. **Panel selection.** How IMD draws panel members decides whether a group of seat owners can capture decisions. Ask: random draw? Can the requester choose? Can one owner hold many seats?
3. **Judgment quality.** LLM panels are good at checkable facts and weak at strategy. Keep strategy with holders at first (§4).
4. **Cost and spam.** Each question costs 0.5 IMD today (flat, any panel size), paid off-chain on Ethereum by whoever asks. Proposer bonds deter spam.
5. **Liveness.** If IMD is down, nothing executes and everything stays safe; vetoes still work.
6. **Legal.** Managing treasuries for outside projects can look like investment management. Get legal advice before outside clients.
7. **Chains.** Decided: Robinhood Chain first, chain-neutral code; a module always lives on its project's chain (DK-3). Still open: IMD signing for consumer chain 4663 and paying requests on Robinhood (`IMD-QUESTIONS.md` §3).
8. **Business model.** A small fee on managed budgets, a subscription, or a share of the work escrow. Avoid a governance token; if there is a token, use it for bonds and fees, not votes.
9. **Answer shopping.** A proposer could ask the same question until a panel says yes. The prototype lets anyone cancel with an earlier "no" (P-4); a full fix needs IMD to index requests by question.

## 7. First version (MVP)

1. **`OracleGovernor` module** (prototype built, `contracts/`): mandates (target, signature, argument rules, cap, rate limit, delay, veto); propose → attestation → timelock → execute; guardian and lock-to-veto. Reuses PondPad's attestation format.
2. **`WorkEscrow`:** fund, request job, pay on a delivery attestation.
3. **`CharterRegistry`:** projects, charter links, mandates, module addresses.
4. **Client 1: PondPad, year 2.** The team Safe enables a Docket module for GrowthFund grants and bounded market and config settings, with the PondPad Safe as guardian (veto only). Tested on a Robinhood fork with a real Safe.

Later: agent-originated proposals (the swarm spots a bug and proposes a fix version), reputation from IMD's registry, futarchy for large spends, outside clients.

## 8. Next steps

Done: name and home chain agreed (DK-1, DK-3); IMD dev questions written (`IMD-QUESTIONS.md`); `OracleGovernor` interface, mandate spec (`SPEC.md`) and Foundry prototype with fork tests.

Next: the user decides P-1 to P-8; send the IMD questions; settle the PondPad timelock wiring; charter template; `WorkEscrow`; `CharterRegistry`. Full list in [`HANDOFF.md`](HANDOFF.md) §5.
