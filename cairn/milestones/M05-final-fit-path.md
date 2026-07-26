# M05: The final model is its own object

- **Status:** planned
- **Priority:** high
- **Depends on:** M02
- **Driving RR:** —
- **Principles touched:** IP1, IP2, IP3, GP1, GP2, GP3

## Goal

Ship `nested_final_fit()`, which re-runs the tuning procedure on the complete
dataset and hands back the resulting model as its own object, so a user can
deploy a model without ever reading the nested estimate as that model's score.

## Scope

**In:** a `nested_final_fit(object, resamples, grid, metrics)` export mirroring
`nested_tune_grid()`'s signature. It re-evaluates the design's stored `inside`
specification against the full data (verified present as an unevaluated call on
both `nested_resamples()` and `rsample::nested_cv()` output), tunes with
`tune::tune_grid()`, selects, finalizes, and fits on every row. It returns a
`nested_final_fit` object carrying the trained workflow, the selected
parameters, and the tuning run, reached with `extract_workflow()`. It draws
kind-pinned seeds at entry and leaves the caller's RNG state as it found it,
reusing D-011's contract. Argument validation reuses `R/checks.R`. Roxygen says
what to report instead of the model's own performance, and why.

**Out:** the long-form guide teaching the applied audience the same lesson in
prose → M06. `predict()`/`augment()` methods on the new class → candidate row;
`extract_workflow()` is the door, as it is after `tune::last_fit()`. Storing the
workflow on `nested_results` so the final fit could re-run from the results
alone → not needed once the workflow is an argument, and it would make the
results object the source of the model. Parallelism over the tuning run → the
existing parallelism candidate.

## Acceptance criteria

- [ ] AC1: `nested_final_fit()` is exported and returns a `nested_final_fit`
      object holding the trained workflow, the selected parameters, and the
      tuning results; `extract_workflow()` on it satisfies
      `workflows::is_trained_workflow()`.
- [ ] AC2: under one seed its selected parameters and its predictions are
      `expect_identical()` to a hand-written tune pipeline over the same inner
      specification on the full data (reference-implementation oracle), and to a
      direct `fit()` of the finalized workflow under a one-row grid that forces
      the selection (invariant oracle) — two independent oracle types, recorded
      by the provenance header in the asserting test file (GP2).
- [ ] AC3: the same seed produces an identical fit, and `.Random.seed` and
      `RNGkind()` are unchanged after the call — on success and on error alike —
      asserted with `ranger`, whose randomness flows through R's RNG (IP2).
- [ ] AC4: `collect_metrics()`, `show_best()`, and `select_best()` have no
      method for the class and error rather than returning a number readable as
      the model's own performance; `print()` says in words that this object's
      performance is the nested estimate from `nested_tune_grid()`, pinned by a
      snapshot (IP3).
- [ ] AC5: every `cli_abort()` branch on the new path is fired by a test,
      including a design carrying no usable `inside` specification.
- [ ] AC6: `devtools::test()` and `devtools::check()` are clean (0 errors, 0
      warnings), `devtools::document()` produces no diff, and the new export has
      a `_pkgdown.yml` row and a NEWS entry.

## Coverage

- AC1 → T2, T3
- AC2 → T4
- AC3 → T5
- AC4 → T6
- AC5 → T1
- AC6 → T7, T8

## Tasks

- [ ] T1: extend `R/checks.R` with the final-fit input checks — reuse
      `check_workflow()`, `check_grid()`, `check_grid_params()`,
      `check_metrics()`, and add one refusing a design that carries no usable
      `inside` call to re-run; tests firing every branch.
- [ ] T2: implement `nested_final_fit()` in `R/nested-final-fit.R` — re-evaluate
      `attr(resamples, "inside")` against the data behind the splits, then
      `tune_grid(control_grid(allow_par = FALSE))`, `select_best()`,
      `finalize_workflow()`, fit on all rows; seeds drawn at entry and the
      caller's RNG restored on exit via `set_fold_seed()`/`restore_rng()`
      (`R/nested-tune-grid.R:342`). (RB tripwire: ip-touching — IP1, IP2)
- [ ] T3: add `new_nested_final_fit()` and the `extract_workflow()` method;
      test that the extracted workflow is trained.
- [ ] T4: `tests/testthat/test-nested-final-fit-oracles.R` with its provenance
      header — the hand-written-pipeline oracle and the forced-selection
      invariant oracle of AC2, on `ranger`.
- [ ] T5: `tests/testthat/test-nested-final-fit-rng.R` — same-seed identity and
      net-zero RNG state including on the error path.
      (RB tripwire: ip-touching — IP2)
- [ ] T6: `print.nested_final_fit()` in `R/nested-final-fit-print.R`, captured
      with `cli::cli_fmt()`/`expect_snapshot()`; tests that tune's ranking
      generics have no method here.
- [ ] T7: roxygen for the new exports, including the section saying what to
      report instead of this model's own performance and why (IP3); cross-link
      from `nested_tune_grid()`'s "no final model is returned here" paragraph
      (`R/nested-tune-grid.R:11`) and its `@seealso`.
- [ ] T8: `_pkgdown.yml` row, NEWS entry, DESIGN.md Function Families and
      Architecture updated to describe the shipped path; full check clean.

## Work log

- 2026-07-26: created by /milestone-plan.

## Decisions

## Review
