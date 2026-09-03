# M53: `nested_final_fit()` refuses a results object whose every outer fold failed

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, GP3
- **Resolves:** —
- **Branch/PR:** `m053-final-fit-all-failed`

## Goal

`nested_final_fit()` refuses a `nested_results` in which no outer fold completed, so a model is never returned
whose companion estimate does not exist — a misuse GP3 refuses, since IP3 makes that estimate the number the
model is reported with.

## Scope

**In:** user-facing tier — an exported function gains a refusal. A `nested_results` whose `.completed` column is
all `FALSE` is refused at entry, immediately after the three record refusals `check_results_record()` makes and
before the tuner, grid and seed steps, with its own condition class `nestedtune_no_completed_folds`; the message
says no outer fold completed and points at `summary()` on the results object, where each fold's failing stage
is listed. The same class goes on the abort `check_any_completed()` (`R/nested-results.R`) already raises for
`collect_metrics()`, `autoplot()` and `agreement()` on such an object, so the four doors that ask an all-failed
run for something signal one class, and each door's help page names it. NEWS carries one entry.

**Out:** a partial run (some folds failed) keeps fitting unchanged — `collect_metrics()`'s partial-summary
warning is the record, and the final fit is not the estimate; refusing a design carrying extra columns, or a
classed object with an empty label record → the standing candidate row those M38/M39 findings live on; the
final fit's other refusals → M46, D-041, unchanged.

## Acceptance criteria

- [ ] AC1: `nested_final_fit(object, results)` on a `nested_results` whose `.completed` column is all `FALSE`
      aborts with condition class `nestedtune_no_completed_folds`, `conditionCall()` naming `nested_final_fit`,
      and a message stating that no outer fold completed and naming `summary()`; asserted by a test on a grid
      result built with `break_every_fold()` at each of its two stages, `"inner tuning"` and `"outer fit"`. The
      check reads `.completed`, which every tuner's worker writes through one constructor, so the grid result
      stands for the five entry points.
- [ ] AC2: The all-failed refusal leaves the caller's RNG untouched: on such an object, `.Random.seed` is
      identical before and after the refused call; asserted by a test.
- [ ] AC3: The control is not refused: `nested_final_fit()` on a result from `break_fold(final_nested(d), 1L,
      "inner tuning")` — one failed fold, one completed — returns a `nested_final_fit`; asserted by a test.
- [ ] AC4: `collect_metrics()` (`summarize` TRUE and FALSE), `autoplot()` (each `type`) and `agreement()` on an
      all-failed `nested_results` abort with condition class `nestedtune_no_completed_folds`, each message still
      matching `no outer fold completed`; asserted by the existing all-failed test of each door.
- [ ] AC5: `?nested_final_fit` names the refusal and its class beside the three record refusals; the help pages
      of `collect_metrics.nested_results`, `autoplot.nested_results` and `agreement` name the class on their
      all-failed refusal; NEWS.md carries one entry covering both, with no milestone number;
      `devtools::document()` produces no diff.
- [ ] AC6: The profile's verify slot is clean and `devtools::check()` reports 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3
- AC5 → T3, T4
- AC6 → T5

## Tasks

- [x] T1: Tests first, in `tests/testthat/test-nested-final-fit-checks.R`: the all-failed refusal at both
      `break_every_fold()` stages (class, call, message), the RNG identity across the refused call, and the
      control built inline on `break_fold(final_nested(d), 1L, "inner tuning")` — `final_results()` hardcodes
      its design and `det_nested()`'s inner spec cannot be re-evaluated (the M05 lesson).
- [x] T2: `check_completed_folds()` in `R/checks.R` beside `check_results_record()` (`:338`), reading
      `results$.completed`, aborting with `nestedtune_no_completed_folds`, `call` threaded as its neighbours do;
      called from `nested_final_fit()` immediately after `check_results_record(results)`
      (`R/nested-final-fit.R:210`).
- [x] T3: `check_any_completed()` (`R/nested-results.R`) gains `class = "nestedtune_no_completed_folds"`; the
      existing all-failed tests assert the class — `collect_metrics()` (`test-nested-tune-grid-failures.R:173`),
      `autoplot()` (`test-nested-results-plot.R:515-526`), `agreement()` (`test-nested-results-agreement.R:294`);
      the three doors' roxygen name the class.
- [x] T4: Roxygen on `@param results` (`R/nested-final-fit.R:37-47`), the NEWS entry, `devtools::document()`.
- [x] T5: Verify slot, `devtools::check()`.

## Work log

- 2026-09-03: created by /milestone-plan from the ROADMAP candidate row filed at M46's review (diff-lens finding 10); the row stays until completion.
- 2026-09-03: criteria audit ran in full mode ([O] fresh reader): 13 findings — AC1's cross-tuner clause added, AC2 narrowed to the all-failed refusal, AC3 narrowed to one named control and T1 given a re-evaluable design, AC4's "messages unchanged" cut for a concrete match and `agreement()` added as the fourth door, AC5 extended to the three doors' help pages and one NEWS entry, T2's insertion point pinned, T4 split, the Goal's warrant moved from IP4 to GP3 with IP3 as motivation; the class-scope finding went to the gate.
- 2026-09-03: plan gate chose one shared class `nestedtune_no_completed_folds` on all four doors over the final fit alone because one fact should be catchable one way; falsified by a user needing to tell the final-fit refusal from a summary refusal by class.
- 2026-09-03: plan gate chose leaving a partial run's final fit silent over a warning mirroring `collect_metrics()`'s because the final fit is not the estimate and the warning already sits where the estimate is; falsified by a user shipping a partial-run model unaware of the failed folds.
- 2026-09-03: plan chose a new class over reusing `nestedtune_bad_results` because that class means the object is the wrong shape and this refusal means the run is; falsified by handlers that need the two under one class.
- 2026-09-03: on the user's instruction, a comment asking topepo whether the inner-search `autoplot()` view is wanted was posted to #57; the plot stays a candidate row.
- 2026-09-03: implement started; question gate skipped, the plan pinning name, class, insertion point and message content.
- 2026-09-03: T1 three tests added to `test-nested-final-fit-checks.R`; before T2 the refusal test showed the final fit raising no condition and returning a model on an all-failed result, the control passing.
- 2026-09-03: T2 `check_completed_folds()` added after `check_results_record()` in `R/checks.R`, called from `nested_final_fit()` right after it; the file's 82 tests pass, both `break_every_fold()` stages built.
- 2026-09-03: T3 `check_any_completed()` carries the class; the three doors' all-failed tests assert it (each `summarize`, each `type`) and their roxygen names it; 315 tests across the three files pass.
- 2026-09-03: T4 `@param results` names the fourth refusal, its class and `summary()`; NEWS carries one entry covering the final fit and the three doors; `document()` rewrote `nested_final_fit.Rd` only.
- 2026-09-03: T5 first full run: 4810 pass, 1 error — M46's read-nothing-but-splits probe (`test-nested-final-fit-rng.R`) corrupts `.completed` to `NA`, which the new check reads; `check()` failed on the same test. The probe now exempts `.completed` (minor amendment under T2, decision below); the file's 52 tests pass; full suite and `check()` re-run.
- 2026-09-03: T5 second run: `devtools::test()` 4813 pass, 0 fail; `devtools::check()` Status OK (0 errors, 0 warnings, 0 notes). Status → review.

## Decisions

- 2026-09-03: the final fit reads `.completed` from the fold rows beside `splits`, and M46's probe that it reads nothing else now exempts that column. AC1 bound the check to `.completed` at the plan gate, and `check_any_completed()` reads the column for the same reason: the column travels with the rows in hand, where the stamped `folds_completed` count is a copy of it. The probe was an M46 oracle, recorded in no D-entry, DESIGN line or lesson. Falsified by a reader that needs the fold rows to be opaque to the final fit.
## Review
