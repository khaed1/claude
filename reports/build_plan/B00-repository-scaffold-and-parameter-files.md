# B00 · Repository scaffold and parameter files

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** nothing
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Create the project layout: Foundry project (solc 0.8.30, optimizer 200 runs, evm version pinned), a Makefile
with targets check, sizes, gas and vectors, and two parameter files. params/mainnet.json holds every value in
the specification's parameter table: the five assets with ids 1 to 5 (ETH, USDT, USDC, IMD, token), their
caps, integer weights per base unit, units-per-ETH rates for the fee ceiling and exit sizes; GENESIS; epoch
and checkpoint lengths in seconds; the fee-ceiling constants; the stake; the 730-day emission; auction
constants; the token's name and symbol; the swarm root; the seat contract; the USDT, USDC and IMD addresses;
the three Poseidon contracts with their code hashes. params/canary.json differs only in the salt, GENESIS, the
token's name and symbol, the swarm root, the cap step (10 days), the emission period (81 days), the deposit
window (85 days), the four starting caps (0.5 ETH, 1,000 USDT, 1,000 USDC, 50 IMD) and the screener wait (3
epochs). script/gen_params.py writes src/Params.sol from a parameter file. script/check_params.py computes the
largest value the reward index can reach and fails at 2^88 or above. src/lib/Addresses.sol computes the
addresses of the five deployed contracts from the Deployer's address and their fixed creation order. Work only
from the pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp; no schedule may count blocks. Screening epochs count from Params.GENESIS; caps, emissions and
the deposit window count from START, which the registry records at its first applied batch. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `foundry.toml`
- `Makefile`
- `params/mainnet.json`
- `params/canary.json`
- `script/gen_params.py`
- `script/check_params.py`
- `src/Params.sol`
- `src/lib/Addresses.sol`
- `README.md`
- `.github/workflows/check.yml`

## Acceptance tests

1. `make check` runs forge build and forge test and exits 0 on the empty project.
2. `python3 script/gen_params.py params/mainnet.json` reproduces src/Params.sol byte for byte.
3. `make sizes` fails if any deployed contract exceeds 24,576 bytes.
4. params/canary.json differs from params/mainnet.json in exactly the keys named in the objective (a test lists the differing keys).
5. check_params.py reports the largest reward index for both files, both under 2^88, and fails on a test file with a supply of 79 billion and unit weights.
6. No parameter appears as a literal in src/ outside src/Params.sol, and no source file reads block.number (two grep tests enforce it).
7. Addresses.sol matches the addresses CREATE gives a contract with nonces 1 to 5 (fuzz over deployer addresses).

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
