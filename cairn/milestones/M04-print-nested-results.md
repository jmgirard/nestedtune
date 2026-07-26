# M04: Printing surfaces the run and its disagreement

- **Status:** planned
- **Priority:** normal
- **Depends on:** M03
- **Driving RR:** —
- **Principles touched:** IP3, IP4
- **Branch/PR:** —

## Goal

Printing a `nested_results` says how much of the requested design ran, where the outer
folds disagreed on parameters, and that the estimate describes the procedure rather
than a model you can ship.

## Scope

**In:** An exported `print.nested_results()` method. It reports the outer design's shape
and how many folds completed (reading M03's counts), names any failed fold and its
stage, lays out each tuned parameter's selected value across folds while distinguishing
unanimous selection from disagreement, and carries one plain sentence saying the
estimate characterizes the tune-and-fit procedure and not a fitted model (IP3). Snapshot
tests over the output shapes that carry meaning.

**Out:**
- `summary()` and `autoplot()` methods → not planned; D-010 has `autoplot()` deliberately
  erroring, so writing one would need that decision superseded first.
- Plotting selection instability → stays in the M02-split candidate row.
- Any change to what `collect_metrics()` computes → M03 owns the numbers; this milestone
  only displays.
- The missing caveat on `std_err` → the variance-estimation candidate owns it.

## Acceptance criteria

- [ ] AC1: Printing shows the number of outer folds requested and the number completed.
- [ ] AC2: When folds failed, printing names them and their failing stage.
- [ ] AC3: Printing shows each tuned parameter's selected value per outer fold and
      distinguishes unanimous selection from disagreement between folds.
- [ ] AC4: Printing states that the estimate describes the tune-and-fit procedure and
      not a shipped model (IP3).
- [ ] AC5: `print()` returns its input invisibly, and the method is exported, registered
      in `NAMESPACE` by roxygen, and documented.
- [ ] AC6: Snapshot tests cover four shapes — a complete run, a partially failed run,
      unanimous selection, and divergent selection.
- [ ] AC7: `devtools::test()` and `devtools::check()` clean (0 errors, 0 warnings).

## Coverage

- AC1 → T1, T2
- AC2 → T1, T3
- AC3 → T1, T4
- AC4 → T1, T5
- AC5 → T5, T6
- AC6 → T1
- AC7 → T6

## Tasks

- [ ] T1: Snapshot tests for the four output shapes in
      `tests/testthat/test-nested-results-print.R` (tests first).
- [ ] T2: Header formatter — outer design shape, folds requested and completed, from
      M03's counts on the object.
- [ ] T3: Failure formatter reading M03's per-fold outcome record.
- [ ] T4: Selection formatter — pivot `.selected` across folds, mark the parameters that
      varied, and handle the single-fold and no-tuned-parameter cases.
- [ ] T5: `print.nested_results()` in `R/nested-results.R` assembling the pieces with
      cli, carrying the IP3 sentence, returning `x` invisibly.
- [ ] T6: Roxygen for the method, NEWS entry, `_pkgdown.yml` reference row,
      `devtools::document()`, verify + `devtools::check()`.

## Work log

- 2026-07-26: created by /milestone-plan; absorbs the print/summary half of the M02 split candidate row.

## Decisions

## Review
