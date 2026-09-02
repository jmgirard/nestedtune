# M49: Each outer fold keeps its inner search's metrics in place of `.grid`

**Status:** done (2026-09-02, PR #59 https://github.com/tidymodels/nestedtune/pull/59; resolves #57 closes)

**Goal:** A `nested_results` carries, per outer fold, the inner tuning run's `collect_metrics()` table in a `.inner_metrics` column in place of `.grid`, so a user can compute the best candidate or plot a Bayesian search's trajectory from the object.

**Outcome:** `inner_metrics()` (`R/nested-tune-grid.R`) records `tune::collect_metrics(tuned)` per fold, `.iter` included on the Bayesian
tuner, or `empty_inner_metrics()`'s zero-row prototype when the fold scored nothing — each parameter column typed from the grid data
frame, else `param_info`, else the workflow's dials set, with `.eval_time` added only under a dynamic survival metric (or tune's censored
default); `failed_fold()` keeps the table of a fold that tuned and then failed its outer fit. `candidate_set()` derives a candidate set
(parameter columns, `.config`, `.iter`) from any metrics table, serving `scored_candidates()` on the final fit and `candidate_sets()` for
the print and summary comparison, `candidate_key()` still comparing parameter values; `join_iteration()` and the per-resample pooling are
retired. `.inner_metrics` replaces `.grid` in `new_nested_results()`, `record_columns()` and `has_results_columns()`; `.selected` is
unchanged; `extract_scored_candidates()` on a survival final fit no longer carries `.eval_time`. NEWS, the help pages, DESIGN.md and
the vignette updated; the test helper `fake_tuning()` stands in for a tuning run and unregisters its method on exit.

**Decisions:** D-043 (the column, `.selected` kept, the final-fit accessor's shape). Milestone-local: a record column altered under the
class through `$<-` or `[[<-` passes the self-templating `[` and `rbind()` — pre-existing, recorded in DESIGN.md Known issues, not
fixed; the accessor's `.eval_time` was one arbitrary time per candidate, not a promised shape, so D-043 stands unannotated.

**Review:** three-lens fan-out, two rounds. Round 1 returned the milestone (defect return 1): the zero-row prototype diverged from a
completed fold's columns on `eval_time` without a dynamic metric and on an engine parameter with no dials object, and the accessor
dropped `.eval_time` against AC6's base-identity wording — fixed by T7, AC6 amended at a gate to a named column set with the drop
chosen; a roxygen sentence and the helper's S3 cleanup fixed alongside. Round 2: twelve [O] findings, four wording fixes before the
merge (the accessor's `@return`, a stale citation, an orphaned comment, NEWS's list), the rest rejected, one noted; [S] lenses clean.
