# Docket: handoff and resume guide

**Read this first in a new session.** Docket (formerly "Swarm Steward") is a separate project from PondPad. It lives in `swarm-steward/` of `khaed1/claude` until it gets its own repo; move it there when one exists.

| File | What it holds |
|---|---|
| [`HANDOFF.md`](HANDOFF.md) | This file: current state, how to resume, next steps |
| [`DESIGN.md`](DESIGN.md) | The design: what Docket is, building blocks, risks, MVP |
| [`SPEC.md`](SPEC.md) | `OracleGovernor` and the mandate spec, in detail |
| [`DECISIONS.md`](DECISIONS.md) | Decisions (DK-n) and prototype choices waiting for a decision (P-n) |
| [`IMD-QUESTIONS.md`](IMD-QUESTIONS.md) | Questions for the IMD dev, ready to send |
| [`contracts/`](contracts/) | Foundry project |

Last updated: 4 October 2026. Branch: `claude/bold-gauss-qhlw86`.

---

## 1. In one paragraph

Docket is a protocol that runs projects after launch, for **any** project or protocol. Each project's Safe enables a Docket module with **mandates**: bounded powers (one function on one contract, with rules for each argument, a cap per epoch, a rate limit and a timelock). Anyone proposes an action under a mandate with a bond; an **IMD oracle panel** answers a yes/no question the module builds itself from the charter, the call and its values; a "yes" queues it; the **guardian** or **holders who lock tokens** can cancel it during the timelock; then anyone executes it through the Safe. No one holds a key that can act outside the mandates. **PondPad** (`../launchpad/`) is the first client. Home chain: Robinhood (4663) first.

## 2. Current state

- Decided with the user: name, home chain, how mandates change, lock-to-veto, multi-project scope (DK-1 to DK-6).
- **Prototype built and tested:** `OracleGovernor` (20,970 bytes), `IOracleGovernor`, `OracleAttestation` (attestation hashing, same format as PondPad's verifier).
- **Tests:** 23 local tests; the same 23 plus 3 more on a Robinhood fork with a **real Safe v1.4.1** (canonical factory) and the **real IMD**. They use PondPad's real `GrowthFund`, `MarketController`, `PondPadToken` and `StakedPONDPAD` (imported, not changed), with two mandates: GrowthFund grants and MarketController cap decay. Also a check of the EIP-712 struct hash against a live IMD attestation.
- **Not built:** `WorkEscrow`, `CharterRegistry`, deploy scripts, *k*-of-*n* signers, a charter template.

## 3. How to resume

```bash
cd swarm-steward/contracts
git submodule update --init --recursive     # forge-std v1.9.7, solady v0.1.9, v4-core @ 46c6834
forge build
forge test                                   # 23 local tests (the fork suite is skipped)
FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork   # 26 fork tests
```

Install Foundry in the cloud sandbox the same way as PondPad (`foundryup` is blocked):

```bash
mkdir -p ~/.foundry/bin && curl -sSL -o /tmp/foundry.tgz \
  https://github.com/foundry-rs/foundry/releases/download/stable/foundry_stable_linux_amd64.tar.gz \
  && tar -xzf /tmp/foundry.tgz -C ~/.foundry/bin && export PATH=$HOME/.foundry/bin:$PATH
```

Notes:
- The tests read PondPad's sources through the `pondpad/` remapping (`../../launchpad/contracts/src/`). Don't change PondPad from here. When Docket moves to its own repo, bring PondPad in as a dependency (or copy the few contracts into test fixtures).
- Same via-IR gotcha as PondPad: warp to absolute times (`T0` and stored timestamps), not to `block.timestamp + x` computed after an earlier warp.
- Public RPCs can rate-limit fork runs; rerun the failed test alone.

## 4. Key facts

| Thing | Value |
|---|---|
| IMD oracle signer (live) | `0x5598aa9146215bc13eb26f2c692ad1461fd32982` |
| Attestation domain | `{"IdentityMD Oracle", "2", chainId, verifyingContract = the Docket module}` |
| `oracle.request` | 0.5 IMD flat, paid on Ethereum mainnet (x402 + Permit2); panel 5 to 100; `consumer` must name the module |
| Robinhood Chain | 4663, RPC `https://rpc.mainnet.chain.robinhood.com` |
| IMD on Robinhood | `0x5F7Bb59365ce557C26dbcAa4EE9d39A4b95B7127` |
| Safe v1.4.1 on Robinhood | factory `0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67`, L2 singleton `0x29fcB43b46531BcA003ddC8FCB67FFE91900C762`, fallback handler `0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99` |

## 5. Next steps

1. **User:** decide the prototype choices P-1 to P-8 in `DECISIONS.md`.
2. **User:** send `IMD-QUESTIONS.md` to the IMD dev (signing, panels, consumer chain 4663 are the blockers).
3. **User + PondPad:** how Docket reaches PondPad settings owned by PondPad's 48 h timelock (open item below).
4. Write a charter template (mission, Grants and Market settings sections, evidence rules), modelled on PondPad's `CTO-RULES.md`.
5. `WorkEscrow` (pay an IMD job after a second panel's delivery "yes"), then `CharterRegistry`.
6. Deploy scripts and a full fork rehearsal for client 1.
7. Check the name "Docket" (domain, X handle, trademark conflicts).

## 6. Open items

| Item | Waiting on |
|---|---|
| Prototype choices P-1 to P-8 (bond policy, guardian powers, verifier per module, fee) | User |
| Threshold signing, panel draw, seat caps, consumer chain 4663, payments on Robinhood (`IMD-QUESTIONS.md`) | IMD dev |
| **PondPad wiring:** `MarketController` (and other policy settings) are owned by PondPad's 48 h timelock, not the Safe, so a Docket mandate on the Safe can't call them directly. Options: PondPad makes the Safe (with Docket) the owner of chosen settings; or the Safe is a proposer on PondPad's timelock and Docket learns to bound nested timelock calls. The tests let the Safe own the controller to show the mandate working. `GrowthFund.grant` works as is (granter = Safe) | User (PondPad decision; no PondPad change made here) |
| Name checks for "Docket" | User |
| Legal advice before outside clients (DESIGN.md §6.6) | User |
