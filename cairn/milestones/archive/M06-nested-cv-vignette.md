# M06: A guide that says what to report

**Status:** done (2026-07-26, PR #6 https://github.com/jmgirard/nestedtune/pull/6)

**Goal:** Ship the guide IP3 obliges the package to carry: what a nested
estimate is, what to report instead of the model's score, where the model comes from.

**Outcome:** `vignettes/nested-cv.Rmd` runs `nested_resamples()` →
`nested_tune_grid()` → `nested_final_fit()` → `extract_workflow()` as chunks
executed at build, on `mtcars` with a 6-candidate ranger grid. Every prose
number is inline `r`; API claims are demonstrated by `error = TRUE` chunks,
`args()`, `identical(before, .Random.seed)`; `requireNamespace()` +
`knit_exit()` degrades the build without `ranger`. DESCRIPTION gains
knitr/rmarkdown + `VignetteBuilder`, `_pkgdown.yml` an `articles:` index.

**Decisions:** D-017 (knitr/rmarkdown as the vignette builder). Milestone-local:
`mtcars` + ranger over six candidates, corrected from the probe's five; AC1
amended off the deprecated `build_vignettes()` onto `check()`'s own rebuild.

**Review:** Two lenses clean; [O] found 4, all fixed — F1 (85) `std_err` called
the fold spread, F2 (82) optimism claim refuted by the vignette's own output,
F4 (85) wrong rationale for the final fit, F5 (85) hand-typed API claims (an AC4
failure). F3 (78) fixed at user override; F6 (45) a candidate.
