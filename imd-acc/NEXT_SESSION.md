Repo: `khaed1/claude` (notes, prompts, HANDOFF). Work and push only on branch **`claude/adoring-goodall-pn3jyz`**. If it isn't in your session, attach it with `add_repo` (push access). The imd/acc code IMD built and deployed is public at https://github.com/identity-md-launches/launch-1129-build-imd-acc-sepolia-test (commit `934fb404`, site PR #2 at `7de7d635`).

You're taking over **imd/acc**, a project I'm building on the IMD swarm (imd.fun). A separate session on my other account keeps working on **PLEA**, imd/acc's first integration, so don't change PLEA; just use it as the live example. Read `imd-acc/README.md` first (the spec), then the imd/acc parts of `HANDOFF.md`: "The two projects" and "Status" at the top, the gas notes, and "Intake v2" at the end. Skip the PLEA-only sections.

## imd/acc in brief
Trading cashback paid in **staked IMD (sIMD)**, inspired by TokenWorks' btc/acc. A participating project sends 0.5% of each trade, taken from fees it already charges, to the trader as sIMD. It does this through one shared, ownerless **`Stacker.credit(trader, imdAmount)`**, which pulls the IMD from the project and calls `sIMD.deposit(amount, trader)`, so the vault mints shares straight to the trader. No new token and no cut. Every `Stacked(project, trader, imd, shares)` event is kept as **points** (trader and project), the basis for leaderboards and maybe a later airdrop (nothing promised). Only credits from **listed projects** earn points, from the block they were listed; anyone else's credits show as "direct, no points".

## Where it stands (2026-10-11)
- **Live on Sepolia, launch #1129** (block 11,874,601):
  - TestIMD `0x2b69099e59b05901faa1dd164fabf098bf831e82` (`faucet()`: 10,000 tIMD per address per 24h);
  - TestSIMD `0xf9e2eec3b610ec6781f7438ac5fb4bc049d81cc1` (a fork of StakedIMD; owner `0x4b91…6821` can pause it to test fallbacks);
  - **Stacker `0x293c7134ab8f6bf1d8ff44ed806575f8f1baf477`**.
  Verified on chain and tested end to end (faucet, credit, events, totals, one-block hold).
- **Test page live:** https://imd-acc-sepolia-test-run.site.identitymd.eth.limo (site job `5530dde0-f0f2-45c2-b18d-ea718fc458de`, the project's newest job; `projects.json` is still empty).
- **First real integration works:** PLEA v10's hook `0x3d4CcAc329010b8beA3b14498d9a45EAB00c68Cc` (deployed at block 11,885,872) credits 0.5% of every PLEA/IMD swap through the Stacker **inside the same swap**. New and repeat traders were stacked on live Sepolia. Stacker totals now: 101.27 tIMD stacked, 0.167 from the PLEA hook.
- **Gas on Sepolia is much higher now** for new storage: a first `credit` for a new trader ~0.7–1.2M gas, a repeat ~0.2M. Integrators must check gas before calling `credit`, as PLEA's hook does, not let a wallet's estimate pick a cheaper no-cashback path. Always use estimate ×1.3.

## What's next (recommend an order; ask me before paying for any job)
1. **List PLEA on the test page:** a `job.continue` of `5530dde0` that adds `{"address":"0x3d4CcAc329010b8beA3b14498d9a45EAB00c68Cc","name":"PLEA","fromBlock":11885872}` to `projects.json`, so PLEA traders earn points. Run `POST /requests/check` first. **Hosting lesson from the IMD dev:** set hosting only with the job's `ipfs` field (e.g. the existing label); never ask the agent to host or deploy in the text, or it tries to publish itself and blocks.
2. **imd/acc on mainnet:** a Stacker against the real IMD `0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7` and real sIMD `0x9efa934d9fad4ae28c998a40195646b965a97247` (ERC-4626, owner renounced, not pausable, one-block hold). PLEA mainnet will point at it.
3. **v2, the ETH route:** for ETH-fee projects, `creditETH(trader)` records pending ETH; a permissionless `flush()` swaps the batch to IMD through POOL4 (TWAP price guard, max batch), deposits into sIMD and splits shares pro rata. Spec in the README.
4. **Later: `ProjectRegistry`**, an ownerless listing decided by an IMD oracle panel instead of `projects.json` (README, "Which projects earn points").
5. **Open questions in the README:** an sIMD vault on Robinhood Chain for PondPad (planned integration; read-only for us), and cashback on sells as well as buys.

## Files to read
- `imd-acc/README.md` (spec, decisions, open questions), `imd-acc/job-sepolia.md` (the launch prompt), `imd-acc/job-continue-site.md` (the site prompt), `imd-acc/index.html` (an explainer page).
- `HANDOFF.md`, imd/acc parts only. The delivered launch-1129 repo (contracts, tests, `site/`).
- PLEA as a reference integration: `khaed1/plea` README and `src/PleaHook.sol` (`_payFees`, `_payCashback`), read only.
- IMD: docs https://imd.fun/docs/llms.txt · API https://api.imd.fun · free checks `POST /requests/import` and `POST /requests/check` · my orders `GET /requests/paid-by/0xf8ad3f88b0e0d177aa8c5e6be1e13410fd41cdc7` (jobs are paid from that wallet).

## Useful facts
- Sepolia RPC `https://ethereum-sepolia-rpc.publicnode.com`; Ethereum logs `https://eth.drpc.org`.
- Intake v2 (oracle payments, same address on Ethereum, Sepolia and Robinhood Chain): `0xa43e6f75ee006411f79ac1c84120606c2330de82`; it's only needed for the future ProjectRegistry.
- Foundry: download `foundry_v1.8.3_linux_amd64.tar.gz` from the GitHub release into `~/.foundry/bin` (`foundryup` is blocked). IMD launches need `bytecode_hash = "none"` in `foundry.toml`; keep `[lint] lint_on_build = false` (the linter can run out of memory).
- Test/owner wallet `0x4b91078b2374c956a65f7af0999cae0a935e6821`: its key is in env `TESTNET_KEY` if this environment has it set. Testnet only.

## Rules
- **Explain simply.** When I need to choose, recommend one option.
- **Don't change agreed numbers** (0.5% cashback, faucet amounts, points rules) without asking me.
- **Keys:** never print or commit `TESTNET_KEY`; never ask me for a mainnet key.
- **PLEA** (`khaed1/plea`, `khaed1/plea-site`) belongs to the other session: read only, don't push.
- **PondPad** (branch `claude/bold-gauss-qhlw86`) is read-only. Never commit its code.
