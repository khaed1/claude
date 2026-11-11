# B12 · Pool: deposit, activate, refund

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B11
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the Pool's deposit, activate and refund and their accounting exactly as in the build specification.
deposit(asset, value, ownerCommit) pulls value + value/500 and checks that exactly that arrived (msg.value for
ETH, zero msg.value for a token), stores keccak256 of depositor, asset, value, ownerCommit and deposit time,
and adds to pending. activate(id, record), depositor only, requires Registry.isApproved(id, depositTime) and
room under the cap counted on activated value, computes the commitment on-chain as H3(packed, index,
ownerCommit), inserts H4(commitment, 0, 0, 0), moves value to shielded (tokenIn for the reward token) and
value/500 to fees. refund(id, record) is open to the depositor in every state and to anyone while
Registry.isRefused(id); it always pays the depositor value plus fee. Token transfers go through
SafeTransfer.sol, which accepts tokens that return no value, as USDT does. The reward index and roll are read
through internal hooks that B13 and B14 fill; use stubs. spend is out of scope. Work only from the pinned
commit of the project repository and the build specification (`reports/Murmuration v4 specification.html`,
section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin,
pause, upgrade or setter may appear in any contract. Every duration is in seconds of block.timestamp counted
from Params.GENESIS; no schedule may count blocks. If the specification is ambiguous, stop and report the
ambiguity instead of choosing.

## Contracts named

- `src/Pool.sol`

## Paths the job may write

- `src/Pool.sol`
- `src/lib/SafeTransfer.sol`
- `src/interfaces/IRegistry.sol`
- `test/PoolDeposit.t.sol`
- `test/mocks/MockRegistry.sol`
- `test/mocks/Tokens.sol`

## Acceptance tests

1. Only the depositor can activate (fuzzed caller). A third party can refund only while the registry marks the deposit refused, and the money still goes to the depositor.
2. A deposit ends in exactly one of activated or refunded; a second activate or refund reverts.
3. refund returns exactly value + value/500 in every screening state and after the deposit window.
4. activate reverts when isApproved is false and when shielded + value would exceed cap(asset); the note's value is exactly the deposited value.
5. deposit reverts after DEPOSIT_END, for an unlisted asset, below the smallest size, above the cap, with ownerCommit >= p, with ETH sent alongside a token, and when the amount received differs from value + value/500 (fee-on-transfer mock).
6. A token whose transfer returns no value (USDT mock) deposits, activates and refunds correctly.
7. For each asset, balance >= pending + shielded + fees after every call (invariant test, 5,000 runs).
8. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
