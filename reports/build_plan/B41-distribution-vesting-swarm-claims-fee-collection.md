# B41 · Distribution: vesting, swarm claims, fee collection

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** B40
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement claimFounder (zero for the first 2,592,000 seconds after launch, then 5% of supply times the time
since launch over 63,072,000 seconds, to the fixed founder address), claimSwarm(index, account, amount, proof)
against the fixed Merkle root with leaves keccak256(bytes.concat(keccak256(abi.encode(index, account,
amount)))), linear over Params.SWARM_VEST from launch, and collect(): burn(0) then collect on the position,
the IMD to the FeeDistributor through fundBuyback, the token part to the burn address. Work only from the
pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp counted from Params.GENESIS; no schedule may count blocks. If the specification is ambiguous,
stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Distribution.sol`

## Paths the job may write

- `src/Distribution.sol`
- `test/DistributionVesting.t.sol`

## Acceptance tests

1. Founder payout at 0, 2,591,999, 2,592,000, 31,536,000 and 63,072,000 seconds after launch equals 0, 0, 30/730, 1/2 and all of the 5%.
2. A swarm entry can never be paid more than its vested amount or its allocation; a wrong proof, index or amount reverts.
3. The sum of all swarm claims in a fuzzed tree never exceeds the 10%.
4. collect sends fees only to the FeeDistributor and the burn address and leaves liquidity unchanged.
5. Distribution deployed size, including the Token's creation code it carries, is at most 24,576 bytes.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
