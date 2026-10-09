# Docket: `OracleGovernor` and mandate spec

**Status: prototype, 4 October 2026.** Code: `contracts/src/OracleGovernor.sol`, interface `contracts/src/IOracleGovernor.sol`. Values in examples are test fixtures, not decided settings (see `DECISIONS.md`, "Waiting for your decision").

Docket is a protocol for any project or protocol, not only PondPad. Each project gets **its own module**: its own Safe, charter, mandates, guardian, veto token and oracle signers. The module has no PondPad code. PondPad is the first client and appears only in the tests.

---

## 1. Pieces

| Piece | What it is |
|---|---|
| **Safe** | The project's Safe (v1.4.1). It enables the module. The module can only call `execTransactionFromModuleReturnData` with plain calls (never delegatecall, never ETH) |
| **Module** (`OracleGovernor`) | One per project. Holds the mandates, builds questions, checks oracle answers, runs the timelock and veto, executes through the Safe |
| **Charter** | `ipfs://` link. Each action keeps the charter in force when it was proposed, and the question names it |
| **Guardian** | An address (for PondPad: its team Safe). Cancels actions and switches mandates off. Can never spend |
| **Veto tokens** | The project's base token (counts 1:1) and ERC-4626 vaults of it (count their underlying assets) |
| **Signers** | IMD oracle signers this module accepts. Today one: `0x5598…2982` |

## 2. A mandate

A mandate is one bounded power: one function on one contract, with rules for every argument. Mandates **never change** once added; to change one, add a new one and switch the old one off.

| Field | Meaning |
|---|---|
| `target` | Contract the Safe calls. Never the Safe or the module itself |
| `signature` | Canonical signature, e.g. `grant(address,address,uint256,bytes32,string)`. The selector is computed from it; the number of arguments must match the rules |
| `name`, `ruleRef` | Quoted in the question: "the *growth grant* mandate", "under the charter at …, *section Grants*" |
| `args[]` | One rule per argument (below) |
| `capArg`, `capPerEpoch`, `epochLength` | Which number argument counts against a cap, and the cap per epoch (epochs are fixed windows of `epochLength` seconds) |
| `minInterval` | Minimum time between two executions (e.g. once per 30 days) |
| `answerWindow` | Time after proposing to get a "yes" in |
| `delay` | Timelock after the "yes" (veto window) |
| `executionWindow` | Time after the timelock in which anyone can execute |
| `minPanel`, `minAgreementBps` | Smallest panel and share of it that must agree (> 50%). The request's own quorum must also be met |
| `vetoBps` | Holder veto quorum in bps of the base token's total supply. 0 = guardian veto only |
| `bond` | Proposer bond in the bond token (IMD) |

### Argument rules

The proposer supplies **numbers, addresses, hashes and booleans only**. No free text reaches the target or the panel from the proposer except the evidence link.

| Kind | Value | Checks |
|---|---|---|
| `Uint` | proposer | `Any`, `Equal(min)`, `Range(min, max)` |
| `Address` | proposer | `Any`, `Equal(min)` |
| `Bytes32` | proposer | `Any`, `Equal(min)` |
| `Bool` | proposer | `Any`, `Equal(min)` |
| `ProposalId` | the module: the action id | none (as `uint256` / `bytes32`) |
| `Evidence` | the module: the proposal's `ipfs://` evidence link | at most one per mandate (as `string`) |

The module builds the calldata itself from these values, so the call is always well-formed and matches the question exactly.

### Example: PondPad grants

`GrowthFund.grant(token, to, amount, ref, reason)`:

| Arg | Rule |
|---|---|
| `token` | `Address`, `Equal(IMD)` |
| `to` | `Address`, `Any` |
| `amount` | `Uint`, `Range(1, 1,000 IMD)`, counts against the cap |
| `ref` | `ProposalId`: the onchain `Granted` event points back to the Docket proposal |
| `reason` | `Evidence`: the event carries the evidence link |

Cap 1,000 IMD per 7 days. `GrowthFund` keeps its own cap too (launchpad D-47), so the stricter one wins.

### Example: PondPad cap decay

`MarketController.setCapDecay(tokensPerDay)`: `Uint`, `Range(300,000, 700,000 $PONDPAD)`, `minInterval` 30 days. (Open item: in PondPad the controller's owner is its 48 h timelock, not the Safe. See `HANDOFF.md`.)

## 3. Lifecycle of an action

```
propose ──► Proposed ──yes──► Queued ──timelock──► executable ──execute──► Executed
               │  └──no──► Rejected       │                 └──window ends──► Expired
               └──no answer in time──► Expired (bond to Safe)
                                  guardian cancel / holder veto / earlier "no" ──► Cancelled
```

1. **Propose** (anyone): mandate id, the values, an `ipfs://` evidence link, plus the bond. Checked against the rules and the cap at once.
2. **Ask** (off-chain): the proposer (or anyone) asks IMD the exact `question(id)` with `evidence: "panel"`, `answerType: "bool"`, `chainId` = this chain, and `consumer` = {this chain, this module}.
3. **Answer** (anyone submits the attestation): checked for signer, exact question hash, bool answer, panel size, agreement (share and the request's quorum), issued after the proposal, not expired, request not used before.
   - "yes" → Queued; "no" → Rejected. The bond is refunded either way.
4. **Timelock**: the guardian can cancel; holders can veto by locking tokens; anyone can cancel with a "no" to the same question issued no later than the accepted "yes" (answer shopping).
5. **Execute** (anyone) in the execution window. The cap and rate limit are checked again here, and the mandate must still be on.

### The question

Built onchain, printable ASCII, under 2,000 characters:

> Docket proposal {id} for {project} on chain id {chain}, module {module}: under the charter at {charter}, {ruleRef}, should the {mandate name} mandate make the Safe {safe} call {signature} on {target} with {label}={value}, …? Evidence: {evidence}. Answer true only if every rule that applies is met.

It names the module, the Safe, the chain and the proposal id, so an answer can't be reused for another project, proposal or call. Numbers are raw integers (labels say the unit, e.g. `amount_wei`).

## 4. Holder veto (lock-to-veto)

- While an action is in its timelock, anyone can lock a veto token against it. Weight: base token 1:1; vault shares by `convertToAssets`.
- When locked weight reaches the action's quorum (fixed when it was queued: `vetoBps` × base total supply), the action is cancelled at once.
- Locks come back only **after the timelock would have ended**, even if the action was cancelled. A flash loan can't stay locked across blocks, so it can't veto.
- A veto only cancels. It never spends or changes anything.

## 5. Changing the module (config)

- The **Safe** proposes a config change: add a mandate, set the guardian, add or remove a signer, add a veto token, set the charter, set the config rules. Nothing else can be proposed.
- It waits the **config timelock**; the guardian or a holder veto (config veto quorum) can cancel it; the Safe can withdraw it; then anyone executes.
- **Switching a mandate off is instant** (the Safe or the guardian): it only ever narrows powers.
- The Safe's owners can also disable the whole module in the Safe at any time.

## 6. What the module never does

- No delegatecall, no ETH, no calls to the Safe or to itself through a mandate.
- No key: nobody can make it act outside a mandate.
- No owner, no proxy, no upgrade. A new version is a new module the Safe enables.

## 7. Not in the prototype yet

- `WorkEscrow` (pay IMD jobs after a delivery panel) and `CharterRegistry` (list of projects and modules), DESIGN.md §7.
- *k*-of-*n* signers per mandate (waits on IMD's answer about threshold signing, `IMD-QUESTIONS.md` §1).
- Bounds on nested calls (e.g. a mandate that schedules a call on a project's own timelock).
- Deploy scripts.
