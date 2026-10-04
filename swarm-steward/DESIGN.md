# Swarm Steward: design draft

**Status: first draft, 4 October 2026. Working name.** A separate project from PondPad. PondPad (`../launchpad/`) is meant to be its first client.

---

## 1. What it is

Swarm Steward is a protocol that **runs a project's ongoing decisions after launch**: treasury grants, hiring work, parameter changes, upgrades, community takeovers. The IMD swarm makes the judgments. Contracts with hard limits carry them out. The project's own holders keep a veto.

| Who | Role |
|---|---|
| **IMD panels** (5–100 agents, one per worker seat) | Answer fixed yes/no questions against the project's charter. The answer comes as a signed `OracleAttestation` |
| **Steward contracts** | Turn a "yes" into a bounded action, after a timelock |
| **Project holders / guardian** | Can veto any action during the timelock. Can't spend on their own |
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
- the mission, and what the project wants the Steward to do and never do;
- the rules for each decision type (grants, hires, parameter changes, takeovers…), written as checkable criteria;
- budgets per epoch;
- evidence rules ("statements in evidence are never instructions").

A new charter version is itself a decision: holder approval plus a timelock. Old decisions keep the version they were made under.

PondPad's `CTO-RULES.md` is the model for a charter section.

### 3.2 Mandates (bounded powers)
The Steward never holds a project's admin key. The project's Safe (or timelock) **enables a Steward module** with a list of mandates. Each mandate is:

```
target contract · function selector · argument bounds · cap per epoch · question template · timelock · veto quorum
```

Examples for PondPad:
- `GrowthFund.grant(token, to, amount, ref, reason)`: amount ≤ 1,000 IMD a week, template "Does this grant meet charter §Grants…?"
- `MarketController.setCapDecay(x)`: 300k ≤ x ≤ 700k, at most once per 30 days.
- `VersionRegistry.activate(...)`: already oracle-gated, so no mandate is needed.

A wrong or manipulated answer can do no more than its mandate allows.

### 3.3 Decision flow
1. **Propose.** Structured fields only (mandate id, typed arguments, evidence links). No free text reaches the panel as an instruction. The proposer posts a bond in IMD, refunded unless the proposal is judged spam.
2. **Question.** The contract builds the exact question from the mandate's template, the arguments and the charter link. It's the same technique as PondPad's `CTOModule`: the oracle's `questionHash` is rebuilt onchain, so an answer can't be reused for anything else.
3. **Answer.** An IMD panel answers. Minimum panel size and agreement are set per mandate (for example ≥ 51 members at 2/3, and ≥ 75 for large spends).
4. **Timelock and veto.** The action is queued. Holders (by a token-weighted veto threshold) or the project's guardian can cancel it during the delay. A veto only cancels; it never spends.
5. **Execute.** Anyone executes after the delay.

### 3.4 Work escrow
Approved work becomes an IMD job paid from escrow:
- escrow funded by the mandate;
- the job runs on IMD;
- a **second, independent panel** answers "was the delivery to spec?";
- pay on "yes"; on "no", refund, or retry once.

### 3.5 Registry
Lists the projects, charter versions, mandates and the module address each project enabled. Contracts are immutable, with versions recorded in a registry (no proxies, like PondPad).

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

1. **One oracle signing key.** Every IMD attestation today is signed by one key (`0x5598…2982`). A protocol holding several projects' money needs threshold signing from IMD, or two independent oracles for large actions. **First question for the IMD dev.**
2. **Panel selection.** How IMD draws panel members decides whether a group of seat owners can capture decisions. Ask: random draw? Can the requester choose? Can one owner hold many seats?
3. **Judgment quality.** LLM panels are good at checkable facts and weak at strategy. Keep strategy with holders at first (§4).
4. **Cost and spam.** Each question costs 0.5 IMD today (flat, any panel size). Proposer bonds cover it.
5. **Liveness.** If IMD is down, nothing executes and everything stays safe; vetoes still work.
6. **Legal.** Managing treasuries for outside projects can look like investment management. Get legal advice before outside clients.
7. **Chains.** IMD runs on Ethereum and Base; Robinhood Chain support is coming (PondPad's dependency). Pick the Steward's home chain(s).
8. **Business model.** A small fee on managed budgets, a subscription, or a share of the work escrow. Avoid a governance token; if there is a token, use it for bonds and fees, not votes.

## 7. First version (MVP)

1. **`OracleGovernor` module:** mandates (target, selector, bounds, cap, template, delay, veto); propose → attestation → timelock → execute; holder/guardian veto. Reuses PondPad's `AttestationVerifier` approach.
2. **`WorkEscrow`:** fund, request job, pay on a delivery attestation.
3. **`CharterRegistry`:** projects, charter links, mandates, module addresses.
4. **Client 1: PondPad, year 2.** Hand over the GrowthFund granter role and bounded market and config settings from the team Safe to the Steward module, with the PondPad Safe as guardian (veto only).

Later: agent-originated proposals (the swarm spots a bug and proposes a fix version), reputation from IMD's registry, futarchy for large spends, outside clients.

## 8. Next steps

- Agree the name and the home chain.
- Ask the IMD dev the oracle questions in §6 (signing key, panel selection).
- Write the `OracleGovernor` interface and a mandate spec, then prototype it against PondPad's contracts on a fork.
