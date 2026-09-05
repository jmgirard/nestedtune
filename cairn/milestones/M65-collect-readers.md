# M65: Three readers stack a per-fold list column with the fold labels beside it: `collect_notes()`, `collect_selections()` and `collect_inner_metrics()`

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4, GP3
- **Resolves:** —
- **Surface tier:** user-facing — three exported readers on the results object
- **Branch/PR:** `m065-collect-readers` — https://github.com/tidymodels/nestedtune/pull/75

## Goal

Give `nested_results` three readers that stack a per-fold list column with the recorded fold labels beside it, so a user reads notes, selections and inner metrics across folds with one call instead of an apply loop that hardcodes `id`.

## Scope

**In:** `collect_notes()` as a `nested_results` method on tune's generic, with the generic re-exported beside `collect_metrics()`; `collect_selections()` and `collect_inner_metrics()` as package-owned generics with a `nested_results` method and a default that aborts (D-052); one internal stacker keyed on the recorded label columns (`fold_ids()`, D-036) and `vctrs::vec_rbind()`; the completed-folds rule, partial warning and all-failed refusal `agreement()` uses; tests; one help page with executed examples; `_pkgdown.yml` rows; NEWS.

**Out:** rewriting the vignettes onto the readers → M66. An accessor for `attr(x, "procedure")` → candidate row. A trajectory `autoplot()` over the stacked inner metrics → the existing issue #57 candidate row. Methods on `nested_final_fit` → none needed: `extract_tune_results()` returns a `tune_results`, which answers tune's `collect_notes()` already.

## Acceptance criteria

- [x] AC1: `collect_notes()` on a `nested_results` returns one row per note across every fold: the recorded label columns, then `location`, `type`, `note` and `trace`; equal to `dplyr::bind_rows()` of the `.notes` column with each fold's labels prepended, asserted on a run with a failed fold and on a run with no note, where it returns zero rows with those same columns.
- [x] AC2: `collect_selections()` on a `nested_results` returns one row per completed fold: the recorded label columns, then the union of the columns of the completed folds' `.selected` rows stacked with vctrs, `NA` where a fold lacks one; on a partial run it warns once with class `nestedtune_partial_summary`; on a run in which no fold completed it aborts with the condition `check_any_completed()` raises.
- [x] AC3: `collect_inner_metrics()` on a `nested_results` returns one row per row of each completed fold's `.inner_metrics` table: the recorded label columns, then the union of those tables' columns stacked with vctrs, `NA` where a fold lacks one; the partial warning and all-failed refusal are AC2's.
- [x] AC4: Each of the three readers takes its label columns from the object's record: on a repeated outer design (`vfold_cv(v = 2, repeats = 2)`) every reader carries `id` and `id2`, and on the single-label design it carries `id` alone, asserted by tests on both designs.
- [x] AC5: `collect_selections()` and `collect_inner_metrics()` are package-owned S3 generics whose default method aborts with a classed nestedtune condition, asserted by a test on a plain data frame.
- [ ] AC6: `devtools::document()` produces no diff, `devtools::test()` is clean, and `devtools::check()` reports 0 errors, 0 warnings, 0 notes.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T3
- AC3 → T1, T4
- AC4 → T1, T2, T3, T4
- AC5 → T1, T3, T4
- AC6 → T6

## Tasks

- [x] T1: Tests first, `tests/testthat/test-collect-readers.R`: the `bind_rows()` equality on the failed-fold fixture (`helper-orchestration.R`) and on a clean run (zero rows, same columns); the two stackers on the clean run, on the failed-fold fixture (one `nestedtune_partial_summary` warning, `expect_warning()` with the class) and on the all-failed fixture (the `check_any_completed()` condition); the union stacking on a run whose folds selected different columns, or a hand-built object where no fixture does; the repeated design (`vfold_cv(v = 2, repeats = 2)`) and the single-label design for AC4; the default methods on a data frame for AC5.
- [x] T2: An internal stacker in `R/nested-results.R` (beside `fold_ids()`) taking the column name and whether to keep completed folds only, prepending the label columns and stacking with `vctrs::vec_rbind()`; `collect_notes.nested_results()` in a new `R/nested-results-collect.R`; `tune::collect_notes` re-exported in `R/reexports.R`.
- [x] T3: `collect_selections()` generic, default method aborting with a classed condition in the `agreement()` shape (`R/nested-results-agreement.R:80-130`), and the `nested_results` method calling `check_any_completed()` then `warn_partial_summary(x, noun = "table")` before stacking `.selected`.
- [x] T4: `collect_inner_metrics()` the same way over `.inner_metrics`.
- [x] T5: One roxygen page documenting the three with executed examples on a small run, naming the completed-folds rule and that `.config` labels a row in that fold's own inner table; `_pkgdown.yml` rows under "Running the loop"; a NEWS entry naming the three; `agreement()` and `summary()` tests untouched and passing.
- [x] T6: `devtools::document()` (no diff), `devtools::test()`, `devtools::check()` 0/0/0, `air format --check` on the touched files.

## Work log

- 2026-09-05: created by /milestone-plan. Criteria audit ran in full mode on a fresh [O] reader: six findings, all fixed in the wording (tune's `trace` column kept; "unchanged" columns became the vctrs union with `NA`; the label probe gained the single-label design; docs, pkgdown rows and NEWS moved to T5; the check bar set to 0/0/0).
- 2026-09-05: plan gate chose a method on tune's `collect_notes()` generic over an owned generic because the generic exists and its shape matches; falsified by tune changing the generic's signature or return shape.
- 2026-09-05: plan gate chose two owned generics with aborting defaults over plain functions because `agreement()` and `extract_tune_results()` set the pattern (D-023, D-039); falsified by tune or hardhat defining either name.
- 2026-09-05: plan gate chose completed folds only, with the partial warning, for the two stackers over stacking every fold that holds a value, because `collect_metrics()` and `agreement()` already read that way and one rule is easier to state; falsified by a user needing a failed fold's inner table from the reader rather than from `.inner_metrics[[i]]`.
- 2026-09-05: plan gate chose stacking `.selected` and `.inner_metrics` columns as they are, `.config` included, over dropping `.config` as `agreement()` does, because a per-fold row's `.config` labels a row in that fold's own inner table; falsified by a reader mistaking `.config` for a cross-fold identity.
- 2026-09-05: plan gate chose helpers over adding purrr to Suggests for the vignettes (user choice, the recommended option), because once the readers exist no reader-facing chunk needs an apply call; falsified by a vignette needing a per-fold computation none of the three readers gives.
- 2026-09-05: /milestone-implement started on branch `m065-collect-readers`; no question gate, the plan left nothing open at the user's level.
- 2026-09-05: minor amendment: `R/nested-tune-grid.R` already carried an internal `collect_inner_metrics(tuned)` reading tune's summary of one inner run, so the exported generic would have shadowed it; renamed to `inner_metrics_table()` at its three sites, no behavior change.
- 2026-09-05: T1 done: `test-collect-readers.R` ran red on the missing functions (26 failures, every one "could not find function") before any code; a `stub_results()` builder in the file hands the constructor hand-written folds for the union and repeated-design shapes.
- 2026-09-05: T2, T3, T4 done: `stack_fold_column()` beside `fold_ids()`, the three readers and `abort_no_collect_method()` in `R/nested-results-collect.R`, `tune::collect_notes` re-exported; the file is green and `air format --check` clean.
- 2026-09-05: T5 done: NEWS entry naming the three readers, `collect_selections` row under "Running the loop" (`pkgdown::check_pkgdown()` clean), the page's examples executed by hand; the full suite ran with one failure, the Bayesian method-table test in `test-nested-tune-bayes-oracles.R` that reads NAMESPACE, which gained calls for the three methods; `agreement()` and `summary()` files untouched and green.
- 2026-09-05: correction to the T1 line: the red run's 26 is the reporter's capped listing (10 shown, 16 more announced), not a full count.
- 2026-09-05: T6 done: `devtools::document()` no diff, `devtools::test()` green (the full run above plus the two re-run files), `devtools::check()` 0 errors, 0 warnings, 0 notes in 16m 50s, `air format --check` clean on `R/` and the two test files; status set to review.

## Decisions

## Review

- 2026-09-05: PR #75 opened as draft; branch cut from and up to date with `origin/main` (no default-branch movement, `origin/main` an ancestor of HEAD).
- AC1 evidence: `test-collect-readers.R` run fresh, 14 tests, 0 failures. On the failed-fold fixture `collect_notes()` is named `id`, `location`, `type`, `note`, `trace`, its row count equals the sum over `.notes`, only the failed fold's label appears, and `expect_equal()` against `dplyr::bind_rows()` of `.notes` with `id` mutated first passes; on the clean run it is zero rows with those five columns, equal to the same hand stack.
- AC2 evidence: same run. `collect_selections()` on the clean run is one row per fold equal to the vctrs hand stack; on the failed-fold fixture `expect_warning(class = "nestedtune_partial_summary")` passes and a handler counts the warning once; on the all-failed fixture the caught condition's class is identical to `collect_metrics()`'s (`nestedtune_no_completed_folds`); on a hand-built object whose folds selected `num_comp` and `threshold` the result is the union with `NA` where absent.
- AC3 evidence: same run. `collect_inner_metrics()` on the clean run has one row per inner row, `id` repeated per fold's row count, equal to the hand stack; the partial warning counted once and the all-failed class identical to `collect_metrics()`'s; the union test over three inner tables gives `.iter` as `NA, NA, 0L, NA`.
- AC4 evidence: same run. On `repeated_design(v = 2, repeats = 2)` built through the constructor, `attr(res, "id_columns")` is `c("id", "id2")` and each of the three readers has `id`, `id2` as its first two columns, equal to the hand stack; on `det_nested()` the record is `"id"` and each reader has `id` first with no `id2`.
- AC5 evidence: same run. On a data frame, a list and an integer vector both generics raise `nestedtune_no_collect_method`, the message naming the generic and `nested_results`, `conditionCall()` the generic's own name; `collect_notes` is `identical()` to `tune::collect_notes`.
