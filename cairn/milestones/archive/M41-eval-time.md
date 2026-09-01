# M41: `eval_time` reaches the metrics that need it

**Status:** done (2026-09-01, PR #50 https://github.com/tidymodels/nestedtune/pull/50)

**Goal:** Both orchestrators take an `eval_time` argument and forward it
untouched to every `tune` call whose answer depends on it.

**Outcome:** `eval_time = NULL` on `nested_tune_grid()` and `nested_final_fit()`,
checked at entry by `check_eval_time()` (`R/checks.R`: non-numeric, empty,
missing, negative or non-finite refused naming the caller; zero, repeats and
unsorted passed through), threaded via `dispatch_folds()`, the mirai lean
wrapper and `fold_task()` into `tune_grid()` and `last_fit()`, and into
`final_fit_worker()`'s `tune_grid()`; `select_best()` deliberately not given it.
`per_fold_metrics()` and `summarize_folds()` key on tune's `.eval_time` column
when the recorded metrics carry it: one summary row per time, NA on a static
metric's row; `print_estimate()` says `at time <t>`, `plot_performance()` gives
a panel per time (`timed_metric()`, `render_times()`). `censored` and `survival`
in Suggests; the `srv_*` fixture and `test-eval-time.R`, its IPCW Brier
recomputed from the definition beside `yardstick::brier_survival()`.

**Decisions:** D-038. Milestone-local: `.eval_time` present exactly when tune
records it, not always.

**Review:** two rounds, three-lens each. Round 1 returned on R1 (summary pooled
across times), adding AC8; R2–R5 fixed on the return, R6 to the fixture-cache
row, R7–R8 rejected. Round 2: F1 (`autoplot` erroring on a multi-time run) and
F2–F5 fixed at the gate; F6 accepted; F7, F8, S1 rejected.
