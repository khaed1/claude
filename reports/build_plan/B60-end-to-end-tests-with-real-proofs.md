# B60 · End-to-end tests with real proofs

**Kind:** Build · **IMD template:** `single` · **Steps:** `write-foundry-tests`
**Depends on:** B50, C06, S03
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write end-to-end tests over all six contracts deployed through the Deployer on a fork with real Uniswap v3 and
a mock seat contract, using proofs produced by C06 for a fixed scenario: three deposits in two assets, a
refused deposit and its refund, activation, a transfer with a relay fee note, a transfer with a padding input,
a claim of reward, withdrawals at two sizes, a fee sweep, a basket sale, three buyback steps, a staker claim
and a screener pay withdrawal. Work only from the pinned commit of the project repository and the build
specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30,
Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `test/EndToEnd.t.sol`
- `test/fixtures/e2e/`
- `docs/e2e.md`

## Acceptance tests

1. Every step of the scenario succeeds with the real Verifier and the fixture proofs.
2. Replaying any fixture proof a second time fails; replaying it against a second deployment with another address fails on extHash.
3. At the end, each asset's Pool balance equals pending + shielded + fees exactly, and the reward paid is at most released.
4. The scenario crosses one cap step and one emission step by warping, and a proof built against gPrev still verifies.
5. docs/e2e.md lists each step with its gas.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
