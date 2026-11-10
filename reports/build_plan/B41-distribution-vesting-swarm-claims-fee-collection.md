# B41 · Distribution: vesting, swarm claims, fee collection

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** B40
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement claimFounder (nothing for the first 216,000 blocks after launch, then linear to 5,256,000 blocks, to
the fixed founder address), claimSwarm(index, account, amount, proof) against the fixed Merkle root with
leaves keccak256(abi.encode(index, account, amount)) double-hashed, linear over Params.SWARM_VEST from launch,
and collect(): burn(0) then collect on the position, IMD to the FeeDistributor, token part to the burn
address. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Distribution.sol`

## Paths the job may write

- `src/Distribution.sol`
- `test/DistributionVesting.t.sol`

## Acceptance tests

1. Founder payout at 0, 215,999, 216,000, 2,628,000 and 5,256,000 blocks equals 0, 0, 216000/5256000, 1/2 and all of the 5%.
2. A swarm entry can never be paid more than its vested amount or its allocation; a wrong proof, index or amount reverts.
3. The sum of all swarm claims in a fuzzed tree never exceeds the 10%.
4. collect sends fees only to the FeeDistributor and the burn address and leaves liquidity unchanged.
5. Distribution deployed size is at most 24,576 bytes.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
