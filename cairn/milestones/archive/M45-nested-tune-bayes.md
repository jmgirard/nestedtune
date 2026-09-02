# M45: The inner loop takes its tuner as an argument, and `nested_tune_bayes()` is its second consumer

**Status:** done (2026-09-02, PR #54 https://github.com/tidymodels/nestedtune/pull/54; resolves #35 partial)

**Goal:** A user runs nested cross-validation around `tune::tune_bayes()` through `nested_tune_bayes()`, and
the outer loop that runs it is the one `nested_tune_grid()` runs, told which tuner to call rather than copied.

**Outcome:** `R/tuner.R`: `tuner_grid(grid)` / `tuner_bayes(iter, initial, objective)` build a tuner description (the tune
function's name and its static arguments) threaded through `nested_fold_fit()`, `dispatch_folds()`, the lean mirai task,
`fold_task()` and `final_fit_worker()` in place of `grid`; `run_tuner()` assembles the call with `rlang::call2(.ns = "tune")` over
symbols, evaluated where they are bound, its control (`allow_par = FALSE`; `control_bayes(seed = <the fold's tuning seed>)`) built
inside the fold's seed scope; `nested_loop()` is the shared body. `nested_tune_bayes()` with `check_iter()`, `check_initial()` (a
`tune_results` refused), `check_objective()`. `join_iteration()` stamps `.iter` on each fold's `.grid`, ordered by `.iter` then
`.config`; `candidate_key()` drops it. Every result carries `procedure` (tuner, its arguments, `param_info`, `event_level`,
`eval_time`) in `run_attributes()`; a Bayesian result has no `grid` attribute. Oracles: a reference loop on two fixtures, the
`iter = 0` identity with the grid path, nine RNG properties, BC10 at two daemon counts; the grid path identical before and after
(12 of 12). Docs: help page, pkgdown row, NEWS, DESIGN.

**Decisions:** D-040 (own arguments, count-only `initial`, the control seed). Milestone-local: none.

**Review:** one round, three lenses; history and prior-review lenses clean. Diff lens: eleven; fixed at the gate the call built
over values (a tune condition carried the training data as its call: 172,423 characters, 149 after), three false claims in the
not-offered paragraph about `no_improve`, `uncertain` and `save_gp_scoring`, a stale comment, payload stand-ins, the AC3 seed
check, a dead formal; rejected the AC7 set's blindness (met as written), an unpinned Bayesian `eval_time`, `rbind()` keeping the
first `procedure` (pre-existing). The M05 inlining lesson extended; nothing graduated.
