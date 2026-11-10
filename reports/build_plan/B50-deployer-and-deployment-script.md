# B50 · Deployer and deployment script

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`, `deploy-script`
**Depends on:** B15, B22, B32, B41, B51
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement Deployer: its constructor stores six creation-code hashes in order; deploy(i, code) creates contract
i with CREATE if keccak256(code) matches hash i and all earlier ones exist. Because addresses follow from the
Deployer's address and its nonce, the script computes all six in advance and passes them as constructor
arguments. Deploy.s.sol deploys the Deployer through the deterministic proxy at
0x4e59b44847b379578588920cA78FbF26c0B4956C with the salt from the parameter file, then one contract per
transaction, then calls launch. Work only from the pinned commit of the project repository and the build
specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30,
Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Deployer.sol`

## Paths the job may write

- `src/Deployer.sol`
- `script/Deploy.s.sol`
- `test/Deployer.t.sol`
- `docs/deploy.md`

## Acceptance tests

1. deploy reverts for wrong code, wrong order, or an index already deployed; anyone can call it.
2. Each deployed contract's stored addresses of the other five equal the actual deployed addresses.
3. The Deployer has no function other than deploy and views, and holds no funds.
4. Running the script twice from clean state with the same parameter file gives identical addresses.
5. docs/deploy.md lists each transaction with its gas today and under EIP-8037, and none needs more than 16,777,216 execution gas.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
