# PondPad swarm audit loop

The IMD swarm audits PondPad v1 before deploy (ARCHITECTURE §10, ROADMAP item 13): **four independent auditors**, each owning one area, then **a judge** that verifies, dedupes and grades their findings. We fix, and run another round on the new commit until the judge says **CLEAN** (D-60).

| File | What it is |
|---|---|
| [`THREAT-MODEL.md`](THREAT-MODEL.md) | Actors, trust, the 22 invariants, deliberate behaviour (not findings), severity scale. Every job reads it |
| [`FINDINGS.md`](FINDINGS.md) | Ledger of rounds and findings (open / fixed / accepted). Every job reads it |
| [`jobs/`](jobs/) | Templates: `_common.md` (shared auditor text), `A1-core.md`, `A2-market.md`, `A3-staking.md`, `A4-governance.md` (files and focus per area), `judge.md` |
| [`make_jobs.py`](make_jobs.py) | Fills the templates for one round at a pinned commit and writes the request bodies |
| `rounds/<n>/` | Generated per round: `manifest.json` (every in-scope file, sha256, lines), `<ID>.objective.md`, `<ID>.request.json` |

## Scope

All of `contracts/src/` (30 contracts), `contracts/script/Deploy.s.sol` and the fork generators in `contracts/upstream/` (36 files, ~8,800 lines at `6545311`). `make_jobs.py` refuses to build a round if any in-scope file is in no auditor's list.

| Auditor | Area | Files |
|---|---|---|
| A1 | Coin trading core | curve, `PadHook`, router, payment swapper, coin token, factory, config, fee lib, vaults, splitter, lens |
| A2 | $PONDPAD sale and market | `PondPadToken`, `PadSale`, `PadMarketHook` + POOL4 original + `make_fork.py`, `MarketController`, `PadBurner` |
| A3 | Staking, funds, distribution | `StakedPONDPAD`, `RewardDripper` + POOL4 originals + `make_staking.py`, `PadBuyer`, splitter, `WorkerFund`, `GrowthFund`, `AirdropDistributor`, `TeamVesting` |
| A4 | Governance, takeovers, deploy | `AttestationVerifier`, `CTOModule`, `VersionRegistry`, `SocialRegistry`, `PadConfig`, `Deploy.s.sol`, `CTO-RULES.md` |

Out of scope: tests, `lib/`, `keeper/`, `airdrop/` (offchain tools; the airdrop root is checked separately by rerunning `snapshot.py build`).

## One round

1. **Freeze.** Commit the code to audit and push it. Auditors read it from GitHub at that exact commit, so it must be pushed and must contain `audit/THREAT-MODEL.md` and `audit/FINDINGS.md`.
2. **Build the auditor jobs.**
   ```bash
   cd launchpad/audit
   python3 make_jobs.py round 1            # HEAD; or --commit <sha>
   ```
   It checks the commit is on GitHub, every listed file exists there, the scope is fully covered, each objective fits the API's size limit, and writes `rounds/1/`.
3. **Submit A1–A4** (`job.open`, 0.5 IMD each, paid on Ethereum mainnet). Each `rounds/1/A*.request.json` is the exact body for `POST https://api.imd.fun/requests/quote`. The API flow (from `/openapi.json`):
   1. Make a random 32-byte hex secret; send it as `Authorization: Bearer <secret>` on every call for that order.
   2. `POST /requests/quote` with the body → a saved, priced order (no charge). Check the quote: action `job.open`, 0.5 IMD, payTo `0x4e0f…adbc`.
   3. `POST /requests/{id}/submit` with an empty body → the x402 challenge.
   4. Sign the Permit2 payment and IMD's EIP-712 `QuoteApproval` with the same wallet; resubmit with `PAYMENT-SIGNATURE`, `x-imd-quote-approval` and `{quoteSignature}`.
   5. Poll `GET /requests/{id}` with the same token; `admission.result` links to the job.
   Run A1 alone first in round 1 (a 0.5 IMD pilot) to confirm the job reads the GitHub sources and returns `A1-round1.md`; then send A2–A4.
4. **Judge.** When the four reports are in:
   ```bash
   python3 make_jobs.py judge 1 <A1 report link> <A2 link> <A3 link> <A4 link>
   ```
   and submit `rounds/1/judge.request.json` the same way.
5. **Record.** Copy the judge's valid findings into `FINDINGS.md` (round row with the job ids), save the five reports in `rounds/1/`, and commit.
6. **Fix.** One commit per finding where practical, each with a test that fails before the fix. High and Critical: always fixed. Medium: fixed, or accepted by the project owner with a written reason in `FINDINGS.md`. Low / Info: fixed when cheap.
7. **Repeat** from step 1 on the new commit until the verdict is **CLEAN**. Each round costs 2.5 IMD (5 jobs). A round after fixes still runs all four auditors on the whole scope, since fixes can break other areas.

## After a clean round

- The clean judge report (or `FINDINGS.md` at that commit) is the `AUDIT_LINK` for `Deploy.s.sol`, which activates version 1 at deploy (D-57, D-59).
- Once the IMD oracle signs for Robinhood, later versions are activated by an oracle attestation to `VersionRegistry`'s question (version, audit job id, code hash, five addresses), not by hand.
- Still before large TVL (ROADMAP item 13): swarm fuzz campaigns, a human audit, a bug bounty.

## Notes on the API (probed 5 Oct 2026, no payment made)

- `job.open` input is `{"objective": "<text>"}`. An 8,000-character objective was accepted; 20,000 returned `request_too_large`. `make_jobs.py` keeps each objective ≤ 7,500 bytes (they are ~4–4.5k).
- The planner needs **1–16 allowed paths** per job (it returned `bad_path_count` for an objective without any). Each auditor names ≤ 14 files and one output file, so they fit.
- Still to confirm with the IMD dev or the pilot job: whether an audit job gets web fetch or a shell (to clone and run `forge test`), how the report is returned (device-signed git bundle with the output file), and whether `job.continue` can ask an auditor to re-check a fix cheaply.
