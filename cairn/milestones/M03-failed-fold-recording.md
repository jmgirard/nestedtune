# M03: Fold failures are recorded, never fatal

- **Status:** planned
- **Priority:** high
- **Depends on:** M02
- **Driving RR:** —
- **Principles touched:** IP4, IP2, GP1
- **Branch/PR:** —

## Goal

A fold that fails is recorded and the run continues, so the results object says what
actually ran and no summary presents a partial design as the one that was requested.

## Scope

**In:** Per-fold failure capture in `nested_tune_grid()`'s loop, covering both a thrown
error and the quieter path where `tune::tune_grid()` swallows the error itself and
returns no usable candidates for `select_best()`. A per-fold outcome record on
`nested_results` naming the failing stage and its condition message, plus the
attempted/completed counts that make a partial run identifiable without inspecting
every row. `collect_metrics()` averaging over the folds that completed, warning and
naming the ones that did not, and aborting when none did.

**Out:**
- Displaying any of this when the object prints → M04.
- Parallel execution over outer folds → ROADMAP candidate (needs its own dependency gate).
- The missing caveat on `collect_metrics()`'s `std_err` → the variance-estimation candidate owns it.
- Changing how a fold that *scores* `NA` is handled (`R/nested-results.R:94`) — that path already matches tune and stays as it is.

## Acceptance criteria

- [ ] AC1: A workflow that errors on one outer fold returns a `nested_results` with a
      row for every fold; the call does not abort and later folds still run.
- [ ] AC2: The object records, per fold, whether it completed and — when it did not —
      the failing stage (inner tuning or outer fit) and the condition message. Both a
      thrown error and a tuning run that yields no usable candidate are recorded this way.
- [ ] AC3: The object records folds attempted and folds completed, so a partial run is
      distinguishable from a complete one without reading per-fold contents.
- [ ] AC4: `collect_metrics()` on a partially failed run returns the mean over completed
      folds with `n` equal to that count, and warns naming the failed fold ids.
- [ ] AC5: `collect_metrics()` on a run where no fold completed aborts naming the
      failure, rather than returning `NA`.
- [ ] AC6: Failure capture disturbs nothing M02 established: a fully successful run's
      `collect_metrics()` output is unchanged — same columns, same values, no warning —
      and a fold's two seeds are identical whether or not an earlier fold failed (IP2).
- [ ] AC7: `devtools::test()` and `devtools::check()` clean (0 errors, 0 warnings).

## Coverage

- AC1 → T2, T3
- AC2 → T1, T2, T3, T4
- AC3 → T5
- AC4 → T6
- AC5 → T6
- AC6 → T7
- AC7 → T8

## Tasks

- [ ] T1: Fixtures in `tests/testthat/helper-orchestration.R`: a workflow that errors
      deterministically on a chosen outer fold, and one whose inner tuning leaves
      `select_best()` with no candidate.
- [ ] T2: Failing tests for the non-aborting loop and the per-fold outcome record.
- [ ] T3: `nested_fold_fit()` (`R/nested-tune-grid.R:144`) returns an outcome record
      rather than throwing — each stage wrapped, stage and condition captured.
- [ ] T4: Guard the no-usable-candidate path ahead of `select_best()`
      (`R/nested-tune-grid.R:156`) so it lands in the same record.
- [ ] T5: `new_nested_results()` (`R/nested-results.R:8`) carries the outcome column and
      the attempted/completed counts.
- [ ] T6: `collect_metrics()` (`R/nested-results.R:79`) warns and counts on a partial
      run; aborts on an all-failed one. Message quantities take `{cli::qty()}`.
- [ ] T7: Regression tests — untouched happy path, and fold seeds stable across a
      failure.
- [ ] T8: Roxygen for the failure record on `nested_tune_grid()`'s `@return` and on
      `collect_metrics()`; NEWS entry; `devtools::document()`; verify + `devtools::check()`.

## Work log

- 2026-07-26: created by /milestone-plan; absorbs the failed-fold half of the M02 split candidate row.

## Decisions

## Review
