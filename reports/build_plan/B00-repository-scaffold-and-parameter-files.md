# B00 · Repository scaffold and parameter files

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** nothing
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Create the project layout: Foundry project (solc 0.8.30, optimizer 200 runs, evm version pinned), a Makefile
with targets check, sizes, gas and vectors, and two parameter files. params/mainnet.json holds every value in
the specification's parameter table (assets, caps, weights, exit sizes, epoch lengths, stake, emission steps,
auction constants, seat contract and IMD token addresses). params/canary.json differs only in the cap step
length, the emission period, the deposit window and the salt. script/gen_params.py writes src/Params.sol from
a parameter file so that no constant is typed by hand in a contract. Work only from the pinned commit of the
project repository and the build specification (`reports/Murmuration v4 specification.html`, section "Build
specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade
or setter may appear in any contract. If the specification is ambiguous, stop and report the ambiguity instead
of choosing.

## Paths the job may write

- `foundry.toml`
- `Makefile`
- `params/mainnet.json`
- `params/canary.json`
- `script/gen_params.py`
- `src/Params.sol`
- `README.md`
- `.github/workflows/check.yml`

## Acceptance tests

1. `make check` runs forge build and forge test and exits 0 on the empty project.
2. `python3 script/gen_params.py params/mainnet.json` reproduces src/Params.sol byte for byte.
3. `make sizes` fails if any deployed contract exceeds 24,576 bytes.
4. params/canary.json differs from params/mainnet.json in exactly the four keys named in the objective.
5. No parameter appears as a literal in src/ outside src/Params.sol (a grep test enforces it).

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
