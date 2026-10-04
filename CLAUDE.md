# Repository notes

This repository has three separate projects:

- `README.md` + `assets/`: a manual for running an IMD swarm worker on an Ubuntu VPS with Claude Code.
- `swarm-steward/`: **Swarm Steward** (working name), an AI DAO that runs projects after launch using IMD swarm panels; design only so far (`swarm-steward/DESIGN.md`). Separate from PondPad; PondPad is meant to be its first client.
- `launchpad/`: **PondPad**, an IMD-paired token launchpad on Robinhood Chain. **Start with `launchpad/HANDOFF.md`**: it has the current state, how to build and test, and the next steps. Decisions are logged in `launchpad/DECISIONS.md`, future work in `launchpad/ROADMAP.md`.

When working on PondPad:
- Keep `HANDOFF.md`, `DECISIONS.md` and `ROADMAP.md` up to date with every change and decision.
- Contracts live in `launchpad/contracts` (Foundry, Solidity 0.8.26, cancun, via-IR). Run local tests with `forge test --no-match-contract Fork`, fork tests with `FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork`.
- Don't change fees, splits or launch numbers without the user's decision; they are logged in `DECISIONS.md`.
