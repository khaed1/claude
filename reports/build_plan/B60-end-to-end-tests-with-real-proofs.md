# B60 · End-to-end tests with real proofs

**Kind:** Build · **IMD template:** `single` · **Steps:** `write-foundry-tests`
**Depends on:** B50, C06, S03
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write end-to-end tests over the contracts deployed through the Deployer and launch() on a fork with real
Uniswap v3, the real USDT and USDC bytecode and a mock seat contract, using proofs produced by C06 for a fixed
scenario: deposits in ETH, USDT and IMD; a deposit refused, held past 21 days and refunded by a third party;
activation; a self-sent transfer; a transfer relayed for an ETH fee from a fee note; a USDT withdrawal relayed
for a USDT fee by a wallet that holds one USDT note; a transfer with an empty input; a claim of reward; an ETH
withdrawal to a contract that refuses payment, then claimOwed; a fee sweep; a basket sale; two buyback steps;
a staker claim in USDT; a screener pay withdrawal. Work only from the pinned commit of the project repository
and the build specification (`reports/Murmuration v4 specification.html`, section "Build specification").
Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may
appear in any contract. Every duration is in seconds of block.timestamp; no schedule may count blocks.
Screening epochs count from Params.GENESIS; caps, emissions and the deposit window count from START, which the
registry records at its first applied batch. If the specification is ambiguous, stop and report the ambiguity
instead of choosing.

## Paths the job may write

- `test/EndToEnd.t.sol`
- `test/fixtures/e2e/`
- `docs/e2e.md`

## Acceptance tests

1. Every step of the scenario succeeds with the real Verifier and the fixture proofs, and every amount paid equals the amount the specification gives, to the base unit.
2. Replaying any fixture proof a second time fails; replaying it against a second deployment with another address fails on extHash; submitting it with another relayer address fails.
3. At the end, each capped asset's Pool balance equals pending + shielded + fees + owed exactly, and the reward paid is at most released.
4. The scenario crosses one cap step by warping, and a proof built against gPrev and a checkpoint root still verifies after 65 other spends.
5. A spend built with a relay fee one base unit above the ceiling is rejected at the block's base fee.
6. docs/e2e.md lists each step with its gas.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
