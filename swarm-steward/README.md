# Docket

A protocol that runs projects after launch, for any project or protocol that joins: IMD swarm panels judge, contracts with hard limits execute, and each project's holders keep a veto. PondPad (`../launchpad/`) is its first client. (Formerly "Swarm Steward".)

Separate project from PondPad. It lives here, in `swarm-steward/`, because the session could not create a new repository; move it to its own repo when one exists.

- [`HANDOFF.md`](HANDOFF.md): **start here**: current state, how to build and test, next steps.
- [`DESIGN.md`](DESIGN.md): the design, risks, open questions and the first version.
- [`SPEC.md`](SPEC.md): the `OracleGovernor` module and the mandate format.
- [`DECISIONS.md`](DECISIONS.md): decisions, and prototype choices waiting for a decision.
- [`IMD-QUESTIONS.md`](IMD-QUESTIONS.md): questions for the IMD dev.
- [`contracts/`](contracts/): Foundry prototype (Solidity 0.8.26, cancun, via-IR, no proxies).

Status: prototype of the `OracleGovernor` module, tested locally and on a Robinhood Chain fork with a real Safe.
