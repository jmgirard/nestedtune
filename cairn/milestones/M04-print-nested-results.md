# M04: Printing surfaces the run and its disagreement

- **Status:** review
- **Priority:** normal
- **Depends on:** M03
- **Driving RR:** —
- **Principles touched:** IP3, IP4
- **Branch/PR:** `m04-print-nested-results` · https://github.com/jmgirard/nestedtune/pull/4

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

- [x] AC1: Printing shows the number of outer folds requested and the number completed.
- [x] AC2: When folds failed, printing names them and their failing stage.
- [x] AC3: Printing shows each tuned parameter's selected value per outer fold and
      distinguishes unanimous selection from disagreement between folds.
- [x] AC4: Printing states that the estimate describes the tune-and-fit procedure and
      not a shipped model (IP3).
- [x] AC5: `print()` returns its input invisibly, and the method is exported, registered
      in `NAMESPACE` by roxygen, and documented.
- [x] AC6: Snapshot tests cover four shapes — a complete run, a partially failed run,
      unanimous selection, and divergent selection.
- [x] AC7: `devtools::test()` and `devtools::check()` clean (0 errors, 0 warnings).
- [x] AC8: Printing shows the summarized metric estimate across completed folds and the
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
- [x] T6: Roxygen for the method, NEWS entry, `_pkgdown.yml` reference row,
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
- 2026-07-26: T6 — roxygen + `man/print.nested_results.Rd`, NEWS entries, `_pkgdown.yml` row; `document()` no-diff, `pkgdown::check_pkgdown()` clean, `devtools::check()` 0 errors / 0 warnings / 0 notes. All tasks done; status review.
- 2026-07-26: review — PR #4 opened; all 8 criteria verified with fresh evidence; `cairn_validate` exit 0 (one advisory: 8 ACs vs the >7 split tripwire). Three fresh-context lenses: two clean, the diff-bug lens raised 5 findings. F1/F2/F3 (95/85/80) fixed; F4 (58) fixed anyway as a one-line never-raises guard; F5 (42) rejected — the estimate is oracle-pinned in `test-nested-tune-grid-oracles.R`, so its premise fails.
- 2026-07-26: F1's fix corrects an M03 assertion — `[.nested_results` now keeps the class only when the whole per-fold record and an id column survive, not `.completed` alone; the M03 test is updated in place with the reason.
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

_Reviewed 2026-07-26 on branch `m04-print-nested-results`, PR #4. Evidence
gathered by execution against the branch, never by recall._

### Acceptance criteria

- AC1 — Printed a complete 3-fold run and a run with one failed fold. Both carry
  `Outer folds: N requested, M completed` (`3 requested, 3 completed`;
  `3 requested, 2 completed`), and the complete run also names the scheme,
  `3-fold cross-validation`. Both counts are derived from the rows at print time,
  not read off the construction-time attributes.
- AC2 — A fold broken at each stage in turn. The outer-fit break prints
  `Fold2 failed during outer fit.`; the inner-tuning break prints
  `Fold1 failed during inner tuning.` Both are followed by a pointer to
  `x$.notes`. The stage is read from M03's own note, the first row of the fold's
  notes.
- AC3 — Unanimity and disagreement rendered from two real runs, neither staged.
  Unanimous (5 folds, 150-row frame): `num_comp: 3 (all 5 completed folds agree)`.
  Divergent (4 folds, noise-dominated frame): `num_comp: 4, 4, 4, 3 (folds
  disagree)` — every fold's value shown, in fold order. The tests assert the
  underlying `.selected` values (`rep(3L, 5L)` and `c(4L, 4L, 4L, 3L)`), so a
  fixture that stopped being unanimous fails rather than silently re-recording.
- AC4 — Printed output carries `A nested estimate describes the tune-and-fit
  procedure, not a model you can deploy. Fit the final model separately, and
  report this estimate as what that procedure achieves.` It is emitted
  unconditionally, including on a run where no fold completed.
- AC5 — `withVisible(print(x))` returns `visible = FALSE` and a value
  `identical()` to the input. `utils::getS3method("print", "nested_results")`
  resolves, `NAMESPACE` carries `S3method(print,nested_results)` written by
  roxygen, and `man/print.nested_results.Rd` exists.
- AC6 — `tests/testthat/_snaps/nested-results-print.md` holds five recorded
  snapshots: the four the criterion names (complete run, partially failed run,
  unanimous selection, divergent selection) plus a run where no fold completed.
- AC7 — `devtools::test()` re-run fresh on the branch: 814 pass, 0 fail, 0 warn,
  0 skip. `devtools::check()` re-run fresh: Status OK, 0 errors, 0 warnings,
  0 notes. Re-run again after the review fixes: 826 pass, 0 fail, 0 warn, 0 skip;
  `check()` Status OK, 0/0/0; `document()` no diff. CI green on all six jobs
  (macOS, Windows, Ubuntu release/devel/oldrel-1, coverage).
- AC8 — A partial run prints `Estimate (2 of 3 outer folds)` above
  `rmse (standard): 1.52`; a run with no completed fold prints
  `0 completed` and `no estimate`. Printing raised no condition on any of the
  three cases (complete, partial, empty), checked with a calling handler that
  fails on a warning as well as an error, while `collect_metrics()` still warns
  on the partial run and errors on the empty one.

### Consistency gate

- `cairn_validate` — exit 0, all checks pass. One advisory: M04 carries 8
  acceptance criteria against a >7 split tripwire, a consequence of the gated
  AC8 amendment. Judged not to warrant a split: the eight criteria describe one
  function's output and one PR, and the tripwire is advisory by design.
- `devtools::document()` — no diff; generated `NAMESPACE` and `man/` are current.
- `pkgdown::check_pkgdown()` — no problems found; `print.nested_results` carries
  its `_pkgdown.yml` reference row.
- `NEWS.md` — four entries for the user-visible change, no milestone numbers.
- README.Rmd — absent, so the knit-sync check is a clean no-op. No new top-level
  files, so no `.Rbuildignore` entry is owed.

### Independent review (three fresh-context lenses + scorer)

- **[S] blame-history** — no findings. Verified `summarize_folds()` moved M03's
  averaging body verbatim with `check_any_completed()` and `warn_partial_summary()`
  still called, unmoved, from `collect_metrics()`; no dependency added; D-010's
  refusal to inherit `tune_results` untouched.
- **[S] prior-PR-comments** — no regressions. Archived `## Review` sections and
  `LESSONS.md` checked against the touched files; the cli-pluralization, tolerance,
  and surviving-attribute lessons are applied here rather than regressed. The
  GitHub probe returned no inline review comments, so that walk was skipped.
- **[O] diff-bug** — five findings, scored by a fresh Sonnet scorer.

**Actioned (scored 80+), all fixed on the branch:**

- **F1 (95) — `print()` warned twice then errored on a column subset that kept
  `.completed`.** `[.nested_results` shed the class only when `.completed` was
  gone, so `res[, c("id", ".completed")]` stayed a results object while every
  method reading `.metrics`/`.selected` failed on it. Fixed by `has_results_columns()`:
  the class survives only when the whole per-fold record and an id column do.
  This corrects an M03 assertion — `test-nested-tune-grid-failures.R` asserted
  that keeping `.completed` was enough — which is updated in place with the reason.
- **F2 (85) — `Estimate (1 of 1 outer folds)`** on a single-fold object. Fixed
  with cli pluralization, matching the `fold{?s}` four lines below.
- **F3 (80) — a parameter absent from some folds, or a genuine `NA` selection,
  printed as `folds disagree`.** A false instability flag is the most expensive
  thing this method can print. Agreement is now judged over the folds that have a
  value, with the count that had none stated; a real `NA` renders as `NA` and an
  absent column as `--`, so neither reads as the other.

**Below threshold — logged, not actioned (2):**

- **F4 (58)** — `vapply(..., character(1))` aborted on a list-valued `.selected`
  column, a shape `select_best()` never produces. Fixed anyway: one line, and the
  method's contract is that it never raises.
- **F5 (42)** — the snapshots bake in the run's numeric estimates, so a regression
  in the estimate could be absorbed by `snapshot_accept()`. Rejected: the premise
  does not hold. The per-fold estimate is independently pinned by both oracles in
  `test-nested-tune-grid-oracles.R` (O1 reference loop, O2 `fit_resamples()`
  degeneracy) with `expect_identical()`, so a changed estimate fails those first.

Regression tests added for F1-F4 (5 tests); suite 826 pass, 0 fail, 0 warn.
