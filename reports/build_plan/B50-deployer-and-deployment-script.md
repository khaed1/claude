# B50 · Deployer and deployment script

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`, `deploy-script`
**Depends on:** B15, B22, B32, B41, B51
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement Deployer: its constructor stores five creation-code hashes in order (Verifier, ScreenerRegistry,
FeeDistributor, Pool, Distribution); deploy(i, code) creates contract i with CREATE if keccak256(code) matches
hash i and every earlier one exists, and reverts if creation fails. No address is passed to any constructor:
each contract takes its siblings from Addresses.sol, using the Deployer (msg.sender in its constructor) and
the fixed order, so no hash depends on an address. The Token is not deployed here; Distribution creates it at
launch. Deploy.s.sol deploys the Deployer through the deterministic proxy at
0x4e59b44847b379578588920cA78FbF26c0B4956C with the salt from the parameter file, then one contract per
transaction, then calls launch once GENESIS has passed. script/compare_builds.py compares the creation code of
two builds and lists every differing constant. Work only from the pinned commit of the project repository and
the build specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity
0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. Every duration is in seconds of block.timestamp; no schedule may count blocks. Screening epochs
count from Params.GENESIS; caps, emissions and the deposit window count from START, which the registry records
at its first applied batch. If the specification is ambiguous, stop and report the ambiguity instead of
choosing.

## Contracts named

- `src/Deployer.sol`

## Paths the job may write

- `src/Deployer.sol`
- `script/Deploy.s.sol`
- `script/compare_builds.py`
- `test/Deployer.t.sol`
- `docs/deploy.md`

## Acceptance tests

1. deploy reverts for wrong code, wrong order, an index already deployed, or a creation that fails; anyone can call it.
2. Each deployed contract's computed addresses of the other four equal the actual deployed addresses, and each reads the token from Distribution.token().
3. The Deployer has no function other than deploy and views, and holds no funds.
4. Running the script twice from clean state with the same parameter file gives identical addresses for the five contracts.
5. compare_builds.py on the canary and mainnet builds reports differences only in the constants params/canary.json changes, and fails on any other differing byte.
6. docs/deploy.md lists each transaction with its gas today and under EIP-8037, and none needs more than 16,777,216 execution gas.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
