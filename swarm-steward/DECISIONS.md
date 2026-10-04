# Docket: decisions

Numbered `DK-n` so they don't mix with PondPad's `D-n` (`../launchpad/DECISIONS.md`). Newest last.

## Decided

| # | Decision | Reason |
|---|---|---|
| DK-1 | **Name: Docket** (was "Swarm Steward", working name). The folder stays `swarm-steward/` until the project gets its own repo. Contract names stay generic (`OracleGovernor`) | User's choice. Fits "a court, not a parliament": every decision is a case a panel rules on. Domain and handles not checked yet |
| DK-2 | **Docket is its own protocol for many projects and protocols; PondPad is only the first client.** One module per project with its own Safe, charter, mandates, guardian, veto token and signers. No client-specific code in the protocol | User's direction |
| DK-3 | **Home chain: Robinhood Chain (4663) first**, chain-neutral code. A module always lives on the same chain as the project's Safe, so other chains (Base, Ethereum) are added when a client needs them | User's choice. PondPad, client 1, is on Robinhood. Safe v1.4.1 (factory `0x4e1D…ec67`, L2 singleton `0x29fc…C762`) is deployed there; checked on a fork |
| DK-4 | **Mandate changes: the project's Safe proposes, a config timelock follows with the same veto (guardian or locked holder tokens), then anyone executes.** Switching a mandate off is instant. Mandates can't be edited; a change is a new mandate plus switching off the old one | User's choice. The team can't quietly widen Docket's powers; narrowing is always safe |
| DK-5 | **Holder veto by locking tokens** (lock-to-veto): holders lock the base token or an ERC-4626 vault of it (for PondPad: $PONDPAD, sPONDPAD) against a queued action; at the quorum it is cancelled. Locks return only after the timelock would have ended | User's choice. sPONDPAD has no vote snapshots; locking needs no change to the client's token and a flash loan can't stay locked across blocks |
| DK-6 | Foundry project in `swarm-steward/contracts`: Solidity 0.8.26, cancun, via-IR, no proxies; its own forge-std v1.9.7, solady v0.1.9 and v4-core `46c6834` (same versions as PondPad). PondPad's sources are only read by the tests (`pondpad/` remapping), never changed | User's rules: same stack as PondPad, no changes to PondPad |

## Waiting for your decision

These are in the prototype so it can run, but they decide fees, thresholds or powers, so they need your OK. Each can change before any deploy.

| # | What the prototype does | Why | Alternatives |
|---|---|---|---|
| P-1 | **Each module checks IMD attestations itself** (EIP-712 domain = the module; IMD requests name the module as `consumer`). Signers are changed by config (Safe + timelock + veto) | No shared verifier with an owner who could swap signers for every project at once | A shared Docket verifier per chain (one place to update signers, but it needs an owner) |
| P-2 | **Two steps: propose onchain with a bond, then submit the panel's answer.** The question names the proposal id, module, Safe, chain, charter, call and every value | The proposal is public before the panel runs; the answer can't be reused anywhere else | One step like PondPad's `CTOModule` (attestation at propose time) |
| P-3 | **Bond: refunded on any panel answer (yes or no) and on a guardian cancel; goes to the project's Safe only if no answer arrives in time.** The bond amount is set per mandate | Honest proposals that lose shouldn't be punished; the bond stops proposals nobody is willing to take to a panel | Keep the bond on "no"; send forfeits to a Docket treasury; a separate "is this spam?" question |
| P-4 | **Answer shopping:** anyone can cancel a queued action with a "no" to the same question issued no later than the accepted "yes" | Attestations are public, so a hidden "no" can be found and used. Not complete until IMD answers `IMD-QUESTIONS.md` Q18 | Accept the first answer only |
| P-5 | **The guardian can switch mandates off instantly**, as well as cancel actions | Fast response to a bad mandate without waiting for the Safe | Only the Safe switches mandates off; the guardian only cancels actions |
| P-6 | **The Safe can withdraw its own config changes** during their timelock | Narrowing only | Only the guardian cancels |
| P-7 | **Proposers can only supply numbers, addresses, hashes and booleans**; the module fills the proposal id and the evidence link into the call | No free text reaches the panel or the target contract | Allow bounded text arguments |
| P-8 | No Docket fee in the prototype | Business model is open (DESIGN.md §6.8) | Fee on managed budgets, subscription, share of work escrow |

Test fixtures, **not decisions** (`contracts/test/Base.t.sol`): grants 1 to 1,000 IMD, cap 1,000 IMD per 7 days; cap decay 300k to 700k $PONDPAD, once per 30 days; panel ≥ 51 at 2/3; answer window 7 days; timelock 3 days; execution window 3 days; bond 10 IMD; holder veto 5% of $PONDPAD supply; config timelock 2 days, config veto 10%.
