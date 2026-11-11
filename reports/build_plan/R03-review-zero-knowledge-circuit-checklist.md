# R03 · Review: zero-knowledge circuit checklist

**Kind:** Review · **IMD template:** `research` · **Steps:** `research-report`
**Depends on:** C04, C05
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Panel review, five reviewers, quorum four, of the clean circuit and the Circom oracle against a checklist that
IMD's audit template does not contain, because that template is written for Solidity. Checklist: signals
assigned but not constrained; missing range checks before additions and comparisons; bit decompositions that
allow an alias above the modulus; equality checks done on hints; selectors not forced to be boolean; public
inputs unused in any constraint; nullifier not bound to the note it spends; empty inputs able to carry value
or reward; a fee input able to carry an asset other than ETH; an empty fee input with a non-zero nullifier;
domain separation between hashes; division by a value that can be zero; differences between the witness
generator and the constraints.

## Paths the job may write

- `docs/reviews/R03-circuit.md`

## Acceptance tests

1. Each checklist item has a verdict per template with file and line, or 'not applicable' with a reason.
2. Every finding comes with a witness that satisfies the constraints and violates the specification, or is marked unconfirmed.
3. The report states what the reviewers could not cover.
4. Minimum of 10 citations.

## Notes

Nothing public shows that IMD has reviewed a circuit before. This brief supplies the checklist the template
lacks.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
