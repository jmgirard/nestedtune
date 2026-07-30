# M20: The metric set a run scored under is provable, on every path and on the object

**Status:** done (2026-07-30, PR #21 https://github.com/jmgirard/nestedtune/pull/21)

**Goal:** Prove `metrics` reaches the parallel dispatch path, and make the results
object's record of the grid and metrics it ran under documented, asserted, and honest.

**Outcome:** `test-parallel-metrics.R` drives `nested_tune_grid()` across two primed
daemons on M18's `sep_*` fixture, asserting `last_dispatch()`, the metric names scored,
and per-fold `.selected`/`.metrics` against a serial reference — the `mirai_map(.args =)`
site at `R/parallel.R:86` had no test, `reg_metrics()` being tune's own regression
default. Registered in `BUDGETED_FILES` with `METRICS_BUDGET_CEILING_S <- 150` against
120 s declared; combined worst case 1983.678 → 2103.678 s. `attr(x, "grid")` and
`attr(x, "metrics")` are documented in `@return`, asserted through row and column subsets,
and mutation-verified; the docs state `grid` holds the request, not the candidates
evaluated, so IP4's clause is unmet when a size is passed and a ROADMAP candidate records it.

**Decisions:** none milestone-local. Plan gate chose a daemon-backed contract test over
mocking `.args`, honest documentation over deriving the expanded grid, one milestone over two.

**Review:** three lenses, 18 findings (diff-bug 17, blame 1, prior-review 0), scored
independently. Actioned ≥80: F2 (88) no column-subset coverage, added and verified
non-vacuous; F1 (85) the claim that `[.data.frame` and `[.tbl_df` behave alike on a column
subset was false, measured and corrected; F15 (85) mis-cited check site. Fifteen logged
below threshold; the M03 attribute lesson was extended, none retired.
