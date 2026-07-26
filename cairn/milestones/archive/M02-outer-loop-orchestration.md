# M02: Outer-loop orchestration

**Status:** done (2026-07-26, PR #2 https://github.com/jmgirard/nestedtune/pull/2)

**Goal:** Run the nested loop end to end — inner tuning, selection, outer fit and score —
returning a collected-results object that retains each outer fold's chosen parameters.

**Outcome:** Exports `nested_tune_grid(object, resamples, grid, metrics)`, which per outer fold
calls `tune::tune_grid()` on that fold's inner `rset` with `control_grid(allow_par = FALSE)`, then
`select_best()`, `finalize_workflow()`, and `last_fit()` on the outer split. Returns
`nested_results` — one row per fold carrying `splits`, `id`, `.metrics`, `.selected`,
`.tuning_seed`, `.outer_fit_seed` — with a `collect_metrics()` method (per-fold and summarized).
Internals: `nested_fold_fit()` (pure per-fold worker), `new_nested_results()`, and `R/checks.R`,
refusing an outer bootstrap, a fitted workflow, an `id`-less design, and a missing engine package.
Serial only.

**Decisions:** D-010 (name, standalone `nested_results` class, no `control` argument), D-011
(per-fold RNG contract), D-012 (`tune (>= 2.0.0)` floor, `ranger`), D-013 (`recipes`,
`yardstick`). Milestone-local: none beyond these.

**Review:** RB01/RR01 settled the RNG scheme; BC1–BC10 ingested verbatim as AC8–AC17, no
deviations. Fan-out: blame-history and prior-review clean; diff-bug found 6, actioned F3 (92,
missing-`id` structural corruption), F1 (85, `NA` fold poisoning the summary), F4 (85, oracle tests
weaker than AC16 requires); logged F6 (75), F5 (73), F2 (65). Nothing retired.
