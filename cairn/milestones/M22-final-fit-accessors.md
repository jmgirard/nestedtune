# M22: What selection saw has a name

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, IP4, GP1, GP3
- **Branch/PR:** `m22-final-fit-accessors`

## Goal

A `nested_final_fit` answers for the tuning run its parameters were selected
from, and for the candidates that run actually scored, through named exported
accessors rather than an undocumented list slot.

## Scope

**In:** Two exported S3 generics — `extract_tune_results()` and
`extract_scored_candidates()` — each with a `nested_final_fit` method and a
default method that fails as nestedtune's own error. The candidates accessor
reuses `scored_candidates()` (`R/nested-tune-grid.R:404`), so what it returns is
identical in shape to the `.grid` column M21 put on `nested_results`, `.config`
label included. Roxygen carrying RR02 BC4's bias caution onto the accessor that
hands the tuning run over, a `print.nested_final_fit()` pointer at both doors,
and the `_pkgdown.yml` rows the profile requires. Names and shape settled at the
plan gate, recorded as D-023.

**Out:**

- Retaining an inner tuning run on `nested_results` → the "Two metrics loose
  ends" candidate row, which already owns that half and cross-references this
  one.
- A `nested_results` method for either accessor → the `.grid` column is that
  object's per-fold surface as of M21, and pooling it across folds would assert
  a shared candidate menu M21 measured to be false.
- `predict()` / `augment()` on `nested_final_fit` → their own candidate row;
  D-014 left them off deliberately and `extract_workflow()` stays the door.
- Registering `collect_metrics()` / `show_best()` / `select_best()` for
  `nested_final_fit` → refused by D-010 and D-014, and RR02 Q7 says those
  refusals stand.
- Any change to how `scored_candidates()` derives a candidate set → M21 owns it,
  including the documented limit that a candidate failing on every inner
  resample leaves no metric row and is unrecoverable.

## Acceptance criteria

- [ ] AC1: `extract_tune_results()` on a `nested_final_fit` returns the stored
      tuning run unreduced — `expect_identical()` against `fit$tuning` on a fit
      built in the test, and `tune::collect_metrics()` on the returned value
      succeeds, which is the leg that establishes a live `tune_results` came
      back rather than a copy.
- [ ] AC2: `extract_scored_candidates()` on a `nested_final_fit` returns one row
      per candidate the stored run actually scored, carrying one column per
      tuned parameter plus tune's `.config` label — the same shape
      `nested_results$.grid` carries. On a fit built with `grid` a data frame of
      k candidates all of which score, it has exactly k rows and its parameter
      values equal the supplied grid's as a set, asserted for k = 3 and for a
      k > 9 grid where tune zero-pads `.config`.
- [ ] AC3: Each accessor's default method aborts as a classed nestedtune
      condition naming both the object it was handed and the class that answers;
      fired in tests for a `nested_results` and for a bare list, message
      snapshotted. R's "no applicable method" reaches the user on neither
      accessor.
- [ ] AC4: `extract_tune_results()`'s help page states that any metric reachable
      through the returned object is a selection-time quantity, optimistically
      biased as a claim about this model, and names `collect_metrics()` on the
      `nested_tune_grid()` result as the number to report instead (IP3; extends
      RR02 BC4 from the print method to the accessor that hands the run over).
- [ ] AC5: `print.nested_final_fit()` names both accessors and carries that same
      caution adjacent to the `extract_tune_results()` pointer, and still shows
      no number derived from `x$tuning` — the existing assertion at
      `tests/testthat/test-nested-final-fit-print.R:35-47` (over `mean` and
      `std_err`, digits 3:6, non-emptiness guarded) extended to the new lines
      rather than replaced by a weaker one.
- [ ] AC6: The profile's `verify` slot is clean — `devtools::document()` run
      after the roxygen changes, `devtools::test()` passing — and
      `devtools::check()` is clean at 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T4
- AC2 → T2, T4
- AC3 → T1, T2, T4
- AC4 → T1
- AC5 → T3
- AC6 → T5

## Tasks

- [x] T1: `extract_tune_results()` — generic, `nested_final_fit` method
      returning `x$tuning`, and a default method aborting per AC3. Roxygen
      carrying AC4's caution. New file `R/nested-final-fit-extract.R`; the
      generic pattern to follow is `extract_workflow.nested_final_fit()` at
      `R/nested-final-fit.R:252-256`, and the `.default`-aborts convention is
      M06's lesson about `tune::show_best()`.
- [x] T2: `extract_scored_candidates()` — generic, `nested_final_fit` method
      delegating to `scored_candidates(x$tuning)`, default method per AC3.
      Roxygen naming the M21 limit (a candidate that failed on every inner
      resample is absent) by cross-reference, never restated.
- [x] T3: `print.nested_final_fit()` (`R/nested-final-fit-print.R:28-41`) gains
      the two pointers with the caution beside the tuning-run one; extend the
      no-number assertion at `test-nested-final-fit-print.R:35-47` to cover the
      added lines and re-record the snapshot.
- [x] T4: `tests/testthat/test-nested-final-fit-extract.R` — AC1's two legs,
      AC2's two grid sizes, AC3's four aborts. Not a budgeted file, so no
      `helper-time-budget.R` row is owed.
- [x] T5: `devtools::document()`, a `_pkgdown.yml` reference row per new export
      (profile `test-doctrine`), a NEWS.md entry naming both accessors in
      user-facing words, then `devtools::test()` and `devtools::check()`.

## Work log

- 2026-07-30: created by /milestone-plan.
- 2026-07-30: [O] criteria audit ran on the step-2 wording and returned five findings — AC5 vacuous (`collect_metrics()` on a `tune_results` has no `.estimate` column; the literal test asserts nothing and is weaker than shipped coverage), AC1's identity leg circular and over-claiming, AC2's column clause false against `scored_candidates()` which also returns `.config`, AC6-as-drafted circular against the M05 oracle and below RR02 BC3 (which forbids reading seeds off the returned object), AC3/AC4 clean. AC5 and AC1 fixed in place; AC2 and the proof bar went to the gate; the drafted AC6 was dropped and replaced by the profile's verify slot.
- 2026-07-30: plan gate chose `extract_tune_results`/`extract_scored_candidates` over `extract_tuning`/`extract_grid` and `extract_tuning_run`/`extract_candidates`, because naming the returned class is hardhat's own idiom and `grid` already denotes the request on `nested_results`; falsified by an upstream generic of either name appearing in tune or hardhat, which would make the collision real rather than hypothetical.
- 2026-07-30: plan gate chose returning `.config` beside the parameters over a parameters-only table, because one shape for one concept across both classes beats a cleaner table that forks it; falsified by evidence a user reads the accessor's output as a grid to pass back to `tune_grid()`, which `.config` would break.
- 2026-07-30: plan gate chose the known-grid proof bar over independently re-deriving tune's space-filling expansion, because M21 already oracle-verified `scored_candidates()` two ways (O3, O4) and re-deriving pins tune internals IP2 declines to promise across versions; falsified by the accessor and the `.grid` column disagreeing on a run where both are defined.
- 2026-07-30: decided autonomously that neither accessor gets a `nested_results` method — `.grid` is that object's per-fold surface and a pooled table would assert a shared menu M21 measured false; falsified by a user needing the candidates of a results object in one table with the fold labels attached.
- 2026-07-30: /milestone-implement started on `m22-final-fit-accessors`, cut from `main` at 017dc6e.
- 2026-07-30: no implementation question gate — names, table shape and proof bar were all settled at the plan gate and recorded as D-023, and the user declined escalation on the `irreversible-api` decision at the plan routing chip.
- 2026-07-30: T1 and T2 landed in one checkpoint (minor amendment): T1's `@seealso` forward-references T2's function, so a T1-only commit would have carried a `document()` link warning as its checked-in state.
- 2026-07-30: `rlang::current_env()` and not `caller_env()` in both default methods — verified by execution that inside a UseMethod-dispatched method the former renders the generic's own call (`extract_tune_results(1:3)`) while the latter renders one frame further out, naming whatever function the user was inside.
- 2026-07-30: T1-T5 done. `devtools::document()` no diff on re-run, `devtools::test()` 1447 pass / 0 fail / 0 warn / 0 skip, `devtools::check()` 0 errors / 0 warnings / 0 notes (4m39s), `pkgdown::check_pkgdown()` no problems.

## Decisions

## Review
