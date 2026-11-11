# R01 · Review: are the frozen statements the right ones

**Kind:** Review · **IMD template:** `research` · **Steps:** `research-report`
**Depends on:** C00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Panel review, five reviewers, quorum four, by agents that have not seen any circuit code. Read
circuit/lean/Murmuration/Spec.lean, Challenge.lean and circuit/SPEC.md at the pinned commit and the build
specification. Answer for the top statement and each of the ten lemmas: does the Lean statement say what the
plain-words statement says; is any hypothesis stronger than an honest prover satisfies; is anything quantified
over the wrong set (field versus integers, any root versus a known root). Then try to break the list as a
whole: describe a circuit that satisfies all eleven statements and still lets someone spend a note that is not
theirs, spend a note twice, create value or reward, change one asset into another, or redirect a payment.
Propose a concrete counter-model for each weakness found.

## Paths the job may write

- `docs/reviews/R01-statements.md`

## Acceptance tests

1. Each of the eleven statements gets a verdict: faithful, too weak (with a counter-model), or too strong (with an honest spend that violates a hypothesis).
2. Each constraint 1-14 of the build specification is matched to a definition or reported missing.
3. For each of the six broken circuits named in C00, the report confirms which lemma fails, or reports that none does.
4. The report names every place where Spec.lean differs from the build specification, however small.
5. Minimum of 3 citations to file and line per statement.

## Notes

IMD's research template takes panelSize, panelQuorum, minCitations and a rubric. The owner reads this report
and signs the statements off before P01 starts.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
