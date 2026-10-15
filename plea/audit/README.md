# PLEA swarm audit loop (notes side)

The kit the swarm reads lives in the audited repo, **`khaed1/plea` → `audit/`** (branch `testnet7`, merged into `main` and `mainnet`): `THREAT-MODEL.md`, `FINDINGS.md`, `README.md` (the loop), `jobs/common.md` + `A1.md` / `A2.md` / `A3.md`, `make_jobs.py`, and `rounds/<n>/` (objectives, request bodies, manifest, later the reports). PondPad's pattern (`claude/bold-gauss-qhlw86` `launchpad/audit/`), three areas instead of four.

This folder mirrors each round's pasteable texts for the user: `rounds/<n>/A1.objective.txt` … (the Description box), `<ID>.request.json` (the API body), `manifest.json` (every in-scope file with its sha256 at the commit).

## Submitting a round (the user, 1.5 IMD)
1. <https://explorer.imd.fun/launch> → **Hire the swarm** → **Audit**.
2. Repository `https://github.com/khaed1/plea` at the full commit printed by `make_jobs.py` (round 1: `cd88136e61abb84e9ee0e42a8c30f4dd38d8d5b5`; round 2: `4b14d13a635afab87e4e0f6830721594ab275028`; round 3: `376611264014a4852bd0f46c0011fe44efa3cc71`; round 4: `e41e426ea80dbc608d33dd36c98a7933069356ce`), press read.
3. Description = the whole of `rounds/<n>/A1.objective.txt`; **Check** (free: four "Audit the …, as a specialist agent" steps and one "Judge the audit"; no blockers); **Pay** 0.5 IMD; note the job id. Repeat for A2 and A3.
4. Reports: `https://api.imd.fun/jobs/<id>/report.md` once the judge is accepted; `GET /jobs/<id>` and `/jobs/<id>/submissions` on the way. `python3 plea/audit/watch.py <id> <id> <id>` polls every 60 s and exits on any change.
5. The session records every finding in `khaed1/plea` `audit/FINDINGS.md` (and the rounds' reports under `audit/rounds/<n>/`), fixes, pushes a new commit, builds round n+1 with `python3 audit/make_jobs.py round <n+1> --check`, and copies the texts here. Clean = no critical or high in any area and no open medium.
