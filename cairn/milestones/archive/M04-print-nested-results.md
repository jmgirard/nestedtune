# M04: Printing surfaces the run and its disagreement

**Status:** done (2026-07-26, PR #4 https://github.com/jmgirard/nestedtune/pull/4)

**Goal:** Printing a `nested_results` says how much of the requested design ran,
where the outer folds disagreed, and that the estimate describes the procedure.

**Outcome:** Exported `print.nested_results()` in `R/nested-results-print.R`,
built from `print_design()`, `print_failures()`, `print_selection()`,
`print_estimate()`. It names the outer scheme from an `outer_label` attribute
stamped by `outer_scheme_label()`, derives folds requested vs. completed from
the rows, names each failed fold and stage from M03's notes, collapses a
parameter's selection when folds agreed and lists it per fold when they did not,
and prints the estimate from `summarize_folds()` — split out of
`collect_metrics()` so both read one averaging without its warning or abort.
`has_results_columns()` now gates the class in `[.nested_results`.

**Decisions:** The outer scheme label is dropped by `[` rather than carried: not
recomputable from the rows, so a subset has no honest value to re-stamp (IP4).

**Review:** Three lenses; blame-history and prior-PR-comments clean. Diff-bug
raised five: F1 (95) print errored on a column subset keeping `.completed`,
F2 (85) `1 of 1 outer folds`, F3 (80) absent or `NA` selections read as
disagreement — all fixed; F4 (58) fixed anyway; F5 (42) rejected, the estimate
is oracle-pinned already. F1 corrected an M03 assertion. Three lessons captured.
