<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M08: Selection instability you can see

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, IP4, GP1, GP3, GP4
- **Branch/PR:** `m08-autoplot-nested-results`

## Goal

`autoplot()` on a `nested_results` object draws what each outer fold's inner
tuning selected and how the per-fold outer scores spread, so the disagreement
the print method describes in words can also be seen.

## Scope

**In:** `autoplot.nested_results(object, type = c("parameters", "performance"),
...)`, registered on `ggplot2::autoplot()` and defaulting to the parameters
view. The parameters view draws one panel per tuned parameter and one point per
completed outer fold at its selected value, keyed by fold id, so agreement and
disagreement are legible without reading the numbers. The performance view
draws one panel per metric, one point per contributing fold, and marks the
nested estimate — the value `collect_metrics()` reports, read off
`summarize_folds()` (`R/nested-results.R:170`) rather than recomputed, so plot
and summary can never disagree. Both views state how many of the requested
folds contributed and omit the rest rather than imputing them (IP4).
`ggplot2` joins Imports and `vdiffr` joins Suggests (D-019). Documentation:
`_pkgdown.yml` reference row, a `NEWS.md` entry, and the vignette's
disagreement section gains the plot.

**Out:**

- An `autoplot()` for `nested_final_fit` — deliberately not planned: the object
  holds no performance number of its own by D-014, so there is nothing an
  honest plot could draw.
- `show_best()` / `select_best()` methods — stay unregistered, per D-010.
- Plotting each fold's *inner* tuning surface — deliberately not planned: the
  results object does not retain the inner `tune_results`, and keeping every
  fold's would cost the memory GP4 exists to defend.
- An interval or band on the fold spread → the existing variance-estimation
  candidate row, which GP5 keeps parked until the literature backs it.

## Acceptance criteria

- [ ] AC1: `autoplot()` on a `nested_results` returns a `ggplot` for both
      `type` values; `type` defaults to `"parameters"`; the method is
      registered so a bare `autoplot(x)` dispatches without namespacing.
- [ ] AC2: For a fixture whose outer folds disagree on a parameter, every
      completed fold's selected value appears in the built plot's data keyed by
      its fold id; for a fixture where they agree, every completed fold appears
      at the one value. Asserted on `ggplot2::ggplot_build(p)$data`, never on
      pixels.
- [ ] AC3: A failed outer fold, and a completed fold carrying no value for a
      parameter, contribute no point to that parameter's panel and are never
      imputed; the plot states how many of the requested folds contributed —
      derived from the columns in hand as `print.nested_results` does, never
      from the stamped attribute (IP4).
- [ ] AC4: In the performance view the marked central value for each metric
      equals `collect_metrics(x)$mean` exactly, and the plot carries IP3's
      caveat — the number describes the tune-and-fit procedure, not a
      deployable model — where a reader meets the number *(RB tripwire:
      ip-touching — print carries this in a sentence; what a plot can honestly
      carry is unsettled)*.
- [ ] AC5: Three error branches fire with the package's own `cli_abort()` in
      the `R/checks.R` idiom: a results object where no outer fold completed, a
      `type = "parameters"` request against a design with no tuned parameters,
      and an unrecognized `type` (which names the allowed values).
- [ ] AC6: `vdiffr` snapshots pin both views for a deterministic fixture;
      `_pkgdown.yml` carries the new method, `NEWS.md` says what a user can now
      see and why it matters, and the vignette plots the disagreement it
      currently only describes.
- [ ] AC7: `devtools::test()` clean and `devtools::check()` clean — 0 errors, 0
      warnings, NOTEs justified — with `ggplot2` in Imports, and
      `devtools::document()` producing no diff.

## Coverage

- AC1 → T1, T3, T5
- AC2 → T2, T3
- AC3 → T2, T3
- AC4 → T4, T5
- AC5 → T6
- AC6 → T7, T8
- AC7 → T1, T8

## Tasks

- [x] T1: Add `ggplot2` to Imports and `vdiffr` to Suggests in `DESCRIPTION`;
      `devtools::document()`; confirm the existing suite stays clean with the
      new hard dependency in place.
- [ ] T2: Failing tests for the parameters view — folds agreeing, folds
      disagreeing, a failed fold, and a completed fold missing a parameter —
      asserting on `ggplot_build()$data` and the stated contributing count.
- [ ] T3: Implement `autoplot.nested_results(type = "parameters")` in a new
      `R/nested-results-plot.R`. Stack `.selected` with `do.call(rbind, ...)`
      before reading a parameter out of it (a list column of one-row tibbles
      answers `$mtry` with `NULL`, which rendered "0 distinct values" in M06),
      and take fold labels from `fold_ids()` (`R/nested-results.R:263`).
- [ ] T4: Failing tests for the performance view, including that the marked
      central value is the one `summarize_folds()` produces and that the IP3
      caveat is present in the plot's labels.
- [ ] T5: Implement `type = "performance"` over `per_fold_metrics()` and
      `summarize_folds()`, and the `type` dispatch itself.
- [ ] T6: The three error branches — tests first, then `cli_abort()` calls
      matching the `check_*()` idiom in `R/checks.R`.
- [ ] T7: `vdiffr` snapshots for both views on a deterministic fixture from
      `helper-orchestration.R`; roxygen with an `@examplesIf` guard; the
      `_pkgdown.yml` reference row.
- [ ] T8: `NEWS.md` entry; the vignette section plotting its disagreement;
      `devtools::check()` clean.

## Work log

- 2026-07-26: created by /milestone-plan, promoting the plotting candidate row split out of M02 (whose parallelism half became M07); gate settled one `autoplot()` with a `type` argument and `ggplot2` to Imports with `vdiffr` in Suggests (D-019), leaving the three other candidate shapes as rows.

- 2026-07-26: T1 — `ggplot2` to Imports, `vdiffr` to Suggests, `autoplot` re-exported beside `collect_metrics` so a bare `autoplot(x)` dispatches; `document()` clean, suite clean at 1028 passing / 0 failures with the new hard dependency in place.

## Decisions

- 2026-07-26 (T1 gate): Both views share a fold-on-x layout — one point per
  outer fold, folds in design order, the selected value or score on y, one
  panel per parameter or metric. Agreement reads as a flat row and
  disagreement as scatter, no two points can overlap, and it matches the order
  `print.nested_results()` lists choices in. Rejected: a count-per-value
  distribution (discards fold identity, so a fold that is an outlier on every
  parameter is invisible); the transpose (a numeric parameter reads
  left-to-right where a value is expected on y).
- 2026-07-26 (T1 gate): Every *attempted* fold keeps its slot on the x axis and
  a failed one draws no point, so the shortfall is visible in the figure and
  not only in the stated count, which is the part a crop removes (IP4).
  Rejected: dropping failed folds from the axis (a cropped figure then looks
  like a complete design).
- 2026-07-26 (T1 gate): IP3's obligation is discharged in the performance view
  by a precise y-axis label naming the quantity plus a subtitle carrying the
  caveat, because ggplot2 renders a subtitle into the image itself and it
  therefore survives being exported into a slide or a paper, detached from the
  console and the help page. Rejected: a caption (the part readers skip and a
  tight crop loses first); the title (strongest placement, but spends the title
  on a disclaimer and reads as scolding on every plot). The RB tripwire on AC4
  is discharged here rather than escalated, at the maintainer's choice at the
  gate.

## Review
