# R01 · Review: are the frozen statements the right ones

**Kind:** Review · **IMD template:** `research` · **Steps:** `research-report`
**Depends on:** C00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Panel review, five reviewers, quorum four. Read circuit/lean/Murmuration/Spec.lean, Challenge.lean and
circuit/SPEC.md at the pinned commit and the build specification. Answer for each of the five theorems: does
the Lean statement say what the plain-words statement says; is any hypothesis stronger than an honest prover
satisfies; could the statement be true of a circuit that lets value be created; is anything quantified over
the wrong set (field versus integers, any root versus a known root). Propose a concrete counter-model for each
weakness found.

## Paths the job may write

- `docs/reviews/R01-statements.md`

## Acceptance tests

1. Each theorem gets a verdict: faithful, too weak (with a counter-model), or too strong (with an honest spend that violates a hypothesis).
2. Each constraint 1-14 of the build specification is matched to a definition or reported missing.
3. The report names every place where Spec.lean differs from the build specification, however small.
4. Minimum of 3 citations to file and line per theorem.

## Notes

IMD's research template takes panelSize, panelQuorum, minCitations and a rubric. The owner reads this report
and signs the statements off before P01 starts.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
