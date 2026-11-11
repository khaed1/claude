# R04 · Review: ceremony transcript and verification key

**Kind:** Review · **IMD template:** `single` · **Steps:** `adversarial-review`
**Depends on:** L02, B51
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Read-only check of the final ceremony output: verify the whole contribution chain with snarkjs from the pinned
powers-of-tau file to the final key; confirm the final beacon step was applied; run script/check_vk.py on the
final verification key; confirm the constants in src/Verifier.sol equal that key; confirm spend.r1cs used in
the ceremony is the file whose hash P04 proved.

## Paths the job may write

- `docs/reviews/R04-ceremony.md`

## Acceptance tests

1. The full `snarkjs zkey verify` output for the final key is in the report and passes.
2. check_vk.py passes: gamma and delta distinct, all points valid, 14 IC points.
3. A table shows the hash of spend.r1cs in three places: the P04 build, the ceremony and the fixtures; all equal.
4. The verifier contract's constants match the key (script output included).

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
