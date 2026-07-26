# M04: Printing surfaces the run and its disagreement

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** M03
- **Driving RR:** —
- **Principles touched:** IP3, IP4
- **Branch/PR:** `m04-print-nested-results`

## Goal

Printing a `nested_results` says how much of the requested design ran, where the outer
folds disagreed on parameters, and that the estimate describes the procedure rather
than a model you can ship.

## Scope

**In:** An exported `print.nested_results()` method. It reports the outer design's shape
and how many folds completed (reading M03's counts), names any failed fold and its
stage, lays out each tuned parameter's selected value across folds while distinguishing
unanimous selection from disagreement, and carries one plain sentence saying the
estimate characterizes the tune-and-fit procedure and not a fitted model (IP3). It also
shows the summarized metric estimate across the folds that completed, immediately above
that sentence, computed by the same path `collect_metrics()` uses but never warning or
erroring. Snapshot tests over the output shapes that carry meaning.

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
- [ ] AC8: Printing shows the summarized metric estimate across completed folds and the
      number of folds it covers, and neither warns nor errors when folds failed or when
      none completed.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T3
- AC3 → T1, T4
- AC4 → T1, T5
- AC5 → T5, T6
- AC6 → T1
- AC7 → T6
- AC8 → T1, T7

## Tasks

- [x] T1: Snapshot tests for the four output shapes in
      `tests/testthat/test-nested-results-print.R` (tests first).
- [x] T2: Header formatter — outer design shape, folds requested and completed, from
      M03's counts on the object.
- [x] T3: Failure formatter reading M03's per-fold outcome record.
- [x] T4: Selection formatter — pivot `.selected` across folds, mark the parameters that
      varied, and handle the single-fold and no-tuned-parameter cases.
- [x] T7: Estimate formatter — the summary across completed folds, silent on a partial
      run and on one where nothing completed. (Added by the 2026-07-26 amendment.)
- [x] T5: `print.nested_results()` in `R/nested-results-print.R` assembling the pieces with
      cli, carrying the IP3 sentence, returning `x` invisibly.
- [ ] T6: Roxygen for the method, NEWS entry, `_pkgdown.yml` reference row,
      `devtools::document()`, verify + `devtools::check()`.

## Work log

- 2026-07-26: created by /milestone-plan; absorbs the print/summary half of the M02 split candidate row.
- 2026-07-26: branch `m04-print-nested-results` cut; status in-progress.
- 2026-07-26: amendment (gated) — print also shows the metric summary across completed folds; Scope In extended, AC8 added, T7 added, Coverage AC8 → T1, T7. Escalation was offered on the IP3 reading and declined.
- 2026-07-26: gate — selection laid out one line per parameter in fold order, collapsed when unanimous, rather than a fold-by-parameter table.
- 2026-07-26: T1 tests written and committed red (the object still prints as a bare tibble); box stays unticked until the method exists. Added `unstable_data()`/`unstable_workflow()` — a deterministic PCA+lm fixture whose four outer folds land on 4, 4, 4, 3 — plus `break_every_fold()` and `print_text()` helpers.
- 2026-07-26: T2-T5, T7 — `print.nested_results()` and its formatters land in `R/nested-results-print.R`; `summarize_folds()` split out of `collect_metrics()` so printing shows the same numbers without its warning or abort. Full suite green (814 pass, 0 warn).
- 2026-07-26: cli writes to stderr whenever a sink is on stdout, so `capture.output()` around a cli print method captures nothing — the test helper uses `cli::cli_fmt()`. `cli_alert_*()` does not wrap at console width; `cli_bullets()` does, so every line goes through the latter.
- 2026-07-26: the 5-fold deterministic fixture turned out to select 3, 3, 2, 3, 3 rather than unanimously — the unanimous snapshot uses a 150-row frame and asserts unanimity rather than assuming it.
- 2026-07-26: minor plan edit — T5's method and its formatters go in `R/nested-results-print.R`, mirroring the test file the plan already names, rather than growing `R/nested-results.R`.

## Decisions

### The outer scheme label is dropped by `[`, not carried (2026-07-26)

`print()` names the outer scheme ("5-fold cross-validation") from a
`pretty()` label stamped at construction. Unlike `folds_attempted` and
`folds_completed`, that label cannot be recomputed from the rows, so
subsetting has no honest value to re-stamp: three rows carrying
"10-fold cross-validation" is exactly the claim IP4 forbids. `[` clears
the attribute and printing omits the line, leaving the requested/completed
counts — which the rows do support — to describe the subset. Considered and
rejected: carrying the label through (misreports the design), and deriving a
scheme from the splits (a subset of a 10-fold design is not a 3-fold one).

## Review
