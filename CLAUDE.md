# Repository notes

This repository has three separate projects:

- `README.md` + `assets/`: a manual for running an IMD swarm worker on an Ubuntu VPS with Claude Code.
- `swarm-steward/`: **Docket** (formerly "Swarm Steward"), a protocol that runs many projects and protocols after launch using IMD swarm panels. **Start with `swarm-steward/HANDOFF.md`**. Prototype in `swarm-steward/contracts` (Foundry; `forge test`, fork tests with `FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork`). Keep its `HANDOFF.md`, `DECISIONS.md` and `DESIGN.md` up to date. Separate from PondPad: never change `launchpad/` from Docket work; PondPad is only its first client.
- `launchpad/`: **PondPad**, an IMD-paired token launchpad on Robinhood Chain. **Start with `launchpad/HANDOFF.md`**: it has the current state, how to build and test, and the next steps. Decisions are logged in `launchpad/DECISIONS.md`, future work in `launchpad/ROADMAP.md`.

When working on PondPad:
- Keep `HANDOFF.md`, `DECISIONS.md` and `ROADMAP.md` up to date with every change and decision.
- Contracts live in `launchpad/contracts` (Foundry, Solidity 0.8.26, cancun, via-IR). Run local tests with `forge test --no-match-contract Fork`, fork tests with `FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork`.
- Don't change fees, splits or launch numbers without the user's decision; they are logged in `DECISIONS.md`.
