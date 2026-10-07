# PondPad swarm audit loop

The IMD swarm audits PondPad v1 before deploy (ARCHITECTURE §10, ROADMAP item 13). Each round audits one pushed commit with **four IMD audit jobs, one per area**. Each job is IMD's native audit template: four specialists (math, permissions, economics, control flow) read the code at once, then a judge reproduces, merges and ranks their findings. We fix, and run another round on the new commit until every area is clean (D-60, D-61).

| File | What it is |
|---|---|
| [`THREAT-MODEL.md`](THREAT-MODEL.md) | Actors, trust, the 22 invariants, deliberate behaviour (not findings), severity scale. Every job reads it |
| [`FINDINGS.md`](FINDINGS.md) | Ledger of rounds and findings (open / fixed / accepted). Every job reads it |
| [`jobs/`](jobs/) | `_common.md` (shared objective) and one file per area: `A1-core.md`, `A2-market.md`, `A3-staking.md`, `A4-governance.md` |
| [`make_jobs.py`](make_jobs.py) | Builds a round at a pinned commit; `--check` runs IMD's free check on each job |
| `rounds/<n>/` | Per round: `manifest.json` (every in-scope file, sha256, lines), `<ID>.objective.txt` (paste into the form), `<ID>.request.json` (API body) |

## Scope

All of `contracts/src/` (33 contracts), `contracts/script/Deploy.s.sol` and the fork generators in `contracts/upstream/` (39 files, ~10,000 lines; the exact count is in each round's `manifest.json`); A4 also reads `CTO-RULES.md`. `make_jobs.py` refuses a round if any in-scope file is in no area.

| Job | Area | Files |
|---|---|---|
| A1 | Coin trading core | curve, `PadHook`, router, payment swapper, coin token, factory, config, fee lib, vaults, splitter, lens |
| A2 | $PONDPAD sale and market | `PondPadToken`, `PadSale`, `PadMarketHook` + POOL4 original + `make_fork.py`, `MarketController`, `PadBurner` |
| A3 | Staking, funds, distribution | `StakedPONDPAD`, `RewardDripper` + POOL4 originals + `make_staking.py`, `PadBuyer`, splitter, `WorkerFund`, `GrowthFund`, `AirdropDistributor`, `TeamVesting` |
| A4 | Governance, takeovers, deploy | `AttestationVerifier`, `CTOModule`, `VersionRegistry`, `SocialRegistry`, `PadConfig`, `FixedOwnable`, `PondPadTimelock`, `PadToken` (holder stream), `Deploy.s.sol`, `CTO-RULES.md` |

Out of scope: tests, `lib/`, `keeper/`, `airdrop/` (offchain tools; the airdrop root is checked by rerunning `snapshot.py build`).

Cost: 0.5 IMD per job, **2 IMD per round**, paid in IMD on Ethereum mainnet (the wallet also needs a little ETH for the one-time Permit2 approval).

## One round

1. **Freeze.** Commit the code to audit and push it.
2. **Build the jobs:**
   ```bash
   cd launchpad/audit
   python3 make_jobs.py round 1 --check     # HEAD; or --commit <sha>
   ```
   It prints the repository address to use, writes `rounds/1/`, and runs IMD's free check (plan and blockers) on each job.
3. **Submit each job (A1 to A4) in the web form** at <https://explorer.imd.fun/launch> ("Hire the swarm"):
   1. Connect the wallet that holds the IMD (Ethereum mainnet).
   2. Choose **Audit**.
   3. Repository: paste the address `make_jobs.py` printed, `https://github.com/khaed1/claude/tree/<commit>` (the full commit, so the audit reads exactly that commit, not the branch's latest), and press read. It should show `khaed1/claude` at that commit.
   4. Description: paste the whole of `rounds/1/A1.objective.txt`.
   5. **Check** (free): the plan should list four "Audit the …, as a specialist agent" steps and one "Judge the audit" step, with no blockers.
   6. **Pay**: sign the Permit2 payment and the quote approval in the wallet (0.5 IMD).
   7. Note the job id and link. Repeat for A2, A3, A4.

   *Or by API:* each `rounds/1/<ID>.request.json` is the body for `POST https://api.imd.fun/requests/quote` (add a fresh UUID `requestKey` and a `Bearer` token), then `POST /requests/{id}/submit` for the x402 challenge, sign, resubmit and poll (`imd.fun/docs` → Paid requests).
4. **Read the reports.** When a job's judge is accepted, its report is public at `https://api.imd.fun/jobs/<job id>/report.md` (findings worst first, with reproductions and Foundry proofs), and on the job's page in the explorer.
5. **Record.** Save the four reports in `rounds/1/`, add the round and every valid finding to `FINDINGS.md`, and commit.
6. **Fix.** One commit per finding where practical, each with a test that fails before the fix. Critical and High: always fixed. Medium: fixed, or accepted by the project owner with a written reason in `FINDINGS.md`. Low / Info: fixed when cheap.
7. **Repeat** from step 1 on the new commit until all four judges report no open Critical or High. Every round re-audits all four areas, since a fix can break another area.

## After a clean round

- The four clean reports (or `FINDINGS.md` at that commit) are the `AUDIT_LINK` for `Deploy.s.sol`, which activates version 1 at deploy (D-57, D-59). IMD also records outside audits on a launch (`/launches/:id/assurances`); ours is a self-deployment, so the reports themselves are the record.
- Once the IMD oracle signs for Robinhood, later versions are activated by an oracle attestation to `VersionRegistry`'s question (version, audit job id, code hash, five addresses).
- Still before large TVL (ROADMAP item 13): swarm fuzz campaigns (IMD's `fuzz` template, one Foundry harness per job), a human audit, a bug bounty.
