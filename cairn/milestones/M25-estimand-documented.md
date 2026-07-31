# M25: The number has a name, and the docs say which

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, GP5
- **Branch/PR:** `m25-estimand-documented`

## Goal

Extend M06's guide so the nested estimate is named as a published quantity,
its bias direction and its `std_err` carry sources, and the guide says when
nesting changes the answer and when it does not.

## Scope

**In:** `vignettes/nested-cv.Rmd` and the roxygen on
`collect_metrics.nested_results()` (`R/nested-results.R:127-146`). Name the
estimand as the k-fold test error of the tune-and-fit procedure at the outer
folds' reduced training size, disclosing in one clause that the marginal
quantity is what you cannot infer. Source the bias-direction claim, which is
uncited today at `vignettes/nested-cv.Rmd:133-136` and
`R/nested-final-fit.R:62`. Say why `std_err` must not be read as an interval,
in the man page as well as the vignette (closes M02 review finding F5).
Warn that two nested estimates cannot be compared inferentially. Add a
when-it-matters section, and correct the `mtcars` justification at
`vignettes/nested-cv.Rmd:81-84` that the new section contradicts. Reader-facing
citations are full author-year with a References section; cairn citekeys stay
internal.

**Out:**
- Any interval or inference on the estimate → the G6 candidate row, narrowed by
  this plan to the interval half.
- Re-cutting the vignette onto a p > n example where nesting demonstrably earns
  its cost → candidate row (it invalidates every inline number and both
  figures).
- The `parsnip::null_model()` analytic oracle and the degenerate-grid invariant
  → candidate rows.
- A synthesis note reconciling the shelf's five stability notions → candidate
  row.
- Changing IP3's text → not proposed; it would need a D-entry.

## Acceptance criteria

- [ ] AC1: `vignettes/nested-cv.Rmd` names what `collect_metrics()` reports as
      the k-fold test error of the tune-and-fit procedure, states that the
      training sets are the outer analysis sets and so smaller than the full
      data, and names at least two quantities it is not — one of them the risk
      of the deployed model. Cites Bayle, Janson & Mackey (2026) for the named
      quantity and Luo & Barber (2026) for why the marginal version is not
      inferable here. Reconciled with the existing claim at
      `vignettes/nested-cv.Rmd:33`.
- [ ] AC2: The bias-direction statement cites Varma & Simon (2006) (+4.2 points
      against a 50.0% truth, n = 40, `references/varma2006.md` p. 6) and
      Wilimitis & Walsh (2023) (1–2% AUROC and 5–9% AUPR pessimistic,
      n = 41,121, `references/wilimitis2023.md` p. 8), names reduced training
      size as the mechanism, and states in the same paragraph that a single run
      at this vignette's sample size can land either way. No number in that
      paragraph is computed inline from the vignette's own run.
- [ ] AC3: `collect_metrics.nested_results()`'s roxygen states that `std_err`
      must not be read as a confidence interval and why, citing Bengio &
      Grandvalet (2004) for the absence of a universally unbiased variance
      estimator and Gauran, Ombao & Yu (2025) for variance-denominator Type I
      error measured near 0.36 against a nominal 0.05 inside a nested design.
      `man/collect_metrics.nested_results.Rd` regenerates with no further diff.
- [ ] AC4: The vignette states (a) that two nested estimates cannot be compared
      inferentially from `collect_metrics()` output, and (b) that fold-to-fold
      disagreement is expected wherever candidates perform near-identically —
      a condition consistent with this vignette's own run, in which `mtry`
      splits across folds while `min_n` does not. Both cite Bayle, Janson &
      Mackey (2026).
- [ ] AC5: The vignette carries a section stating when nesting changes the
      reported number materially and when it does not, citing Tibshirani &
      Tibshirani (2009) (material only at p ≫ n), Vabalas et al. (2019) (the
      flat-CV bias persists to n = 1000, and nesting feature selection matters
      more than nesting tuning) and Wilimitis & Walsh (2023) (a measured null
      result at n ≫ p with a small grid). `vignettes/nested-cv.Rmd:81-84` no
      longer claims `mtcars` is where the optimism is largest.
- [ ] AC6: A `testthat` test asserts every author-year citation in the
      vignette's References section maps to an existing
      `cairn/references/<citekey>.md`, and skips when `cairn/` is absent, as
      it is in the built package (`.Rbuildignore:1`; the pattern is
      `tests/testthat/test-ci-workflows.R:1-15`).
- [ ] AC7: `Rscript -e 'devtools::check()'` clean per `cairn/PROFILE.md`'s
      consistency-gate — 0 errors, 0 warnings, NOTEs justified — run on a
      machine with `ranger` installed, so the vignette's
      `requireNamespace()`/`knit_exit()` guard
      (`vignettes/nested-cv.Rmd:42-54`) does not let the new material past
      unexecuted. `pkgdown::check_pkgdown()` passes and the article renders.

## Coverage

- AC1 → T2
- AC2 → T3
- AC3 → T6
- AC4 → T4
- AC5 → T5
- AC6 → T7
- AC7 → T8

## Tasks

- [x] T1: Draft the References section and its entry list, and decide the
      author-year form each of the six sources takes in prose. Reader-facing
      text carries no cairn citekey.
- [x] T2: Name the estimand in the "What to report, and why" section
      (`vignettes/nested-cv.Rmd:124-163`), reconciling it with line 33.
- [x] T3: Replace the uncited bias-direction clause at
      `vignettes/nested-cv.Rmd:133-136` with the sourced paragraph, no inline
      `r` values in it (M06 review F2: an optimism claim refuted by the
      vignette's own output). Carry the same correction to
      `R/nested-final-fit.R:62`, which repeats the uncited claim.
- [x] T4: Add the comparison warning, and give the selection-disagreement
      section (`vignettes/nested-cv.Rmd:165-215`) its mechanism.
- [ ] T5: Write the when-it-matters section and correct
      `vignettes/nested-cv.Rmd:81-84`.
- [ ] T6: Add the `std_err` caveat to `collect_metrics.nested_results()`'s
      roxygen (`R/nested-results.R:127-146`); `devtools::document()`.
- [ ] T7: Write the citation-resolution test.
- [ ] T8: Render the vignette and read it end to end as a reader would
      (LESSONS, M08: assertions on a built object cannot see the part a reader
      meets); NEWS.md entry; full `devtools::check()` and
      `pkgdown::check_pkgdown()`.

## Work log

- 2026-07-31: created by /milestone-plan.
- 2026-07-31: implement started on `m25-estimand-documented`, cut from `main` at 4fd429e.
- 2026-07-31: verified the audit's reproduction of the vignette run independently before writing anything resting on it — `mtry` 5/8/5/8/5, `min_n` 2 in all five folds, RMSE 2.46 (SE 0.445). AC4(b)'s condition holds.
- 2026-07-31: T1 done. References section carries the six reader-facing sources; prose form is author-year (`Varma and Simon (2006)`, `Bayle et al. (2026)`). `bengio2004` and `gauran2025` are roxygen-only per AC3 and get `@references` on the man page instead.
- 2026-07-31: T2 done. Estimand named as the k-fold test error of the tune-and-fit procedure (Bayle et al., 2026), with the two quantities it is not — the deployed model's risk, and the training-set-averaged version, the latter carrying Luo and Barber (2026)'s ratio argument. Intro line 33 reconciled: the nested estimate is reported *in place of* a model score, not as one.
- 2026-07-31: T3 done. Bias-direction paragraph sourced to Varma and Simon (2006) (54.2% against a 50.0% truth at n = 40, attributed to training on 39 rows) and Wilimitis and Walsh (2023) (most pessimistic method compared, ~1-2% AUROC / 5-9% AUPR on 41,121 visits), with the mechanism named and a second paragraph saying the gap is a property of the estimator and not a prediction about this run. No inline `r` in either. Same correction carried to `R/nested-final-fit.R`'s `@section What to report`, which repeated the uncited claim, plus an `@references` block; `document()` regenerated `man/nested_final_fit.Rd`.
- 2026-07-31: T4 done. Comparison warning placed after the `std_err` paragraph, framed on the absence of any valid interval first and Bayle et al. (2026)'s difference-instability second, so the citation carries only what it establishes. Disagreement mechanism added to "What each fold chose", stated over the condition that actually holds here — the run splits on `mtry` and is unanimous on `min_n`, and the paragraph names both.
- 2026-07-31: criteria audit ([O], fresh context) returned seven findings. Three fixed before the gate — AC3 re-sourced off `bates2023` (whose own reference page records the statistic as different and the effect unmeasured for it) onto `bengio2004` + `gauran2025`; AC4(b)'s "fine grid" condition dropped as false of this vignette's six-point grid and unanimous `min_n`; AC7 pointed at PROFILE's gate definition and required `ranger` present, since `knit_exit()` made "vignette rebuilt" vacuously satisfiable. Three became gate questions (estimand choice, the `mtcars` claim, citation form); one (AC6 checking a superset of "citations this milestone adds") accepted as satisfied a fortiori — there are zero such citations in the tree today.
- 2026-07-31: plan gate chose naming the estimand as the conditional k-fold test error (bayle2026's R_n) over bates2023's marginal Err because Err is the quantity luo2026 proves is not inferable at N/n ≈ 1.11, so naming it would overclaim; falsified by a source establishing that the outer-fold mean estimates the marginal quantity at this sample ratio.
- 2026-07-31: plan gate chose correcting the `mtcars` justification over re-cutting the vignette onto a wide example because the re-cut invalidates every inline number, both figures and the runtime budget; falsified by the corrected paragraph proving unwritable without the example itself changing.
- 2026-07-31: plan gate chose full author-year citations with a References section over bare cairn citekeys because `cairn/` is stripped from every shipped form while the vignette renders publicly; falsified by the References section proving unmaintainable against the shelf.
- 2026-07-31: plan chose keeping the roxygen caveat (AC3) in this milestone over splitting it out because it is ~6 lines and closes M02 review finding F5, which the G6 row has carried since 2026-07-25; falsified by the roxygen change growing past a task.

## Decisions

## Review