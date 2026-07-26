# M03: Fold failures are recorded, never fatal

**Status:** done (2026-07-26, PR #3 https://github.com/jmgirard/nestedtune/pull/3)

**Goal:** A fold that fails is recorded and the run continues, so the results object says
what actually ran and no summary presents a partial design as the one that was requested.

**Outcome:** `nested_fold_fit()` returns an outcome record instead of throwing, with both
stages guarded — `finalize_workflow()` and the outer-fit seeding included. Catches all
three failure shapes: a raise, inner tuning's quiet all-candidates-failed (which raises
only at `select_best()`), and `last_fit()`'s silent `NULL` metrics. tune's notes are kept
verbatim beside a stage note, including on a fold completing on a truncated inner design.
`nested_results` gains `.notes`, `.completed`, `folds_attempted` / `folds_completed`, and
`[.nested_results` keeping those counts true of the rows kept. `collect_metrics()` covers
only completed folds, warns (`nestedtune_partial_summary`), aborts when none completed;
the run warns too. `check_grid_params()` refuses a malformed `grid` before any seed.

**Decisions:** Milestone-local: an all-fold failure is recorded rather than raised, then
superseded in part by adopting the pre-flight grid check. No cross-cutting D-entry, and no
dependency change — `tune::extract_parameter_set_dials()` was already exported.

**Review:** Blame-history and prior-PR lenses clean. Diff-bug found 3: actioned F1 (96,
`collect_metrics()` read a stale attribute *and* the `.completed` column, so a subset
answered from its parent's counts) and F2 (82, a partly-failed fold recorded as clean,
tune's notes dropped); F3 (42) fixed at the maintainer's direction. Suite 755 → 775.
