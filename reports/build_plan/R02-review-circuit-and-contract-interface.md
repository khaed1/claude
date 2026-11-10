# R02 · Review: circuit and contract interface

**Kind:** Review · **IMD template:** `single` · **Steps:** `adversarial-review`
**Depends on:** B14, C04
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Adversarial review, read-only, of the boundary between the Spend circuit and the Pool: the order and encoding
of the eleven public inputs; reduction of extHash and of every input modulo p on both sides; that the tree,
the bundle leaf and the commitment computed in Solidity equal the circuit's for the same note; that the
checkpoint the Pool accepts is the one the circuit used; that the standard-size check and the per-asset limit
use the same asset id as the proof. Try to construct a call that the Pool accepts with a meaning the circuit
did not prove.

## Paths the job may write

- `docs/reviews/R02-interface.md`

## Acceptance tests

1. Each of the eleven public inputs has a row: produced where, checked where, encoding, and whether a mismatch is possible.
2. Every finding has a severity, file and line, and a reproduction as a Foundry test or a witness.
3. The review states explicitly whether a proof for one deployment can be accepted by another.
4. No high or critical finding remains open at sign-off.

## Notes

IMD's adversarial review goes to a different agent on a different seat, with no write access.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
