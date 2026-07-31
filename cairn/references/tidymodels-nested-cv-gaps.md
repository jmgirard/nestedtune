# Nested cross-validation support in the tidymodels ecosystem — gap ledger (design interview, pre-M01)

**Provenance.** Ingested 2026-07-25 by the `/design-interview` run that preceded the first milestone, from read-only probing of external repositories and registries: `tidymodels/rsample` and `tidymodels/tune` on GitHub (source, issues, branches, commit history, via `gh api`), the tidymodels.org learn article, and the CRAN package index.
Pagination: —.
Extraction: a 2026-07-25 snapshot of external projects; the assessed artifacts move independently of this repo and none has been re-read since — observed 2026-07-25.

**Scope.** This page characterizes what the tidymodels ecosystem does and does not provide for nested cross-validation, and ledgers the gaps. It is not a summary of one source, and it deliberately builds no API proposal — what this package should do about each gap is a design decision, recorded in `DESIGN.md` and `DECISIONS.md`, not here. Standing disclaimer: this is a reference, not an authority — status lives in `ROADMAP.md`, decisions in `DECISIONS.md`, architecture in `DESIGN.md`.

**Evidence snapshot.**

- `rsample::nested_cv()` full source, ~40 lines — `tidymodels/rsample` `R/nested_cv.R`, branch `main` — observed 2026-07-25.
- `tune`'s resample-object check rejecting `nested_cv` — `tidymodels/tune` `R/checks.R:19-21`, branch `main` — observed 2026-07-25.
- Vignette removal history — `tidymodels/rsample` commits touching `vignettes/Applications/Nested_Resampling.Rmd`: "Another non-vignette article" 2017-12-09, "Remove vignette stub" 2021-05-07 — observed 2026-07-25.
- Nested resampling article, current canonical how-to — https://www.tidymodels.org/learn/work/nested-resampling/ — observed 2026-07-25.
- `rsample` issue #283, "Nested CV is Memory-inefficient", open since 2022-03-17, 3 comments — observed 2026-07-25.
- `tune` issue #969, "nested resampling implementation", open, filed 2024-11-24 by topepo (Max Kuhn) — observed 2026-07-25.
- `tune` branch `nested`, prototype referenced by #969; last commit 2024-09-13 — observed 2026-07-25.
- `tune` issues #115 (2019-11-25) and #148 (2020-01-05), both closed, documenting the same absence and a performance gap — observed 2026-07-25.
- CRAN package `nestedcv` 0.9.0, maintainer Myles Lewis (QMUL), published 2026-07-14, caret/glmnet-based, 15 imports — observed 2026-07-25.
- CRAN name availability checked against the full index, 24,393 packages, via `available.packages()` — observed 2026-07-25.

## What the ecosystem provides today

`rsample::nested_cv(data, outside, inside)` is a **data-structure constructor**. It evaluates the outer resampling specification, maps the inner specification over each outer split's analysis set (`inside_resample()` calls `as.data.frame()` on the rsplit, which yields the analysis set), attaches the result as an `inner_resamples` list-column, and adds the `nested_cv` class. It warns when bootstraps are used as the outer scheme, because the same observation can then land in both the inner analysis and inner assessment sets. It performs no fitting, no tuning, no metric collection, and no parallelization.

Nothing downstream consumes that object. `tune` rejects it at the door, alongside `loo_cv` and `permutations`, with an abort reading that nested resampling is not currently supported.

The canonical how-to is therefore an article rather than package functionality. It defines five helpers by hand (`svm_rmse`, `rmse_wrapper`, `tune_over_cost`, `summarize_tune_results`, `best_cost`), fits with `kernlab::ksvm` directly rather than through parsnip or workflows, tunes by mapping over a manually constructed grid, and parallelizes with a user-supplied `furrr::future_map`. Its worked example fits 1250 models per tuning parameter and the article acknowledges the cost.

## Gap ledger

Tags: `fix-here` (this package's job) · `candidate` (worth a ROADMAP row, not yet scoped) · `out` (deliberately not ours).

| # | Gap in the ecosystem | State today | Tag |
|---|---|---|---|
| G1 | Nested resampling objects cannot be consumed by the tuning layer | `tune` hard-aborts on class `nested_cv` (`R/checks.R:19-21`) | `fix-here` |
| G2 | No orchestration of the nested loop | User writes the outer loop, inner tuning, and collection by hand, per the article | `fix-here` |
| G3 | No parsnip/workflows path through a nested design | Article fits `kernlab::ksvm` directly, bypassing the model abstraction entirely | `fix-here` |
| G4 | Memory scales with the **outer** fold count | rsample#283 open since 2022; 13× object-size blow-up measured on a 10×10 scheme _(corrected 2026-07-25: the reprex read "5×2", but it passed `vfold_cv(times = 5)`/`(times = 2)` and `vfold_cv()` has no `times` argument — in 2022 it fell into `...` and both levels defaulted to `v = 10`; current rsample errors on that call via `check_dots_empty()`)_ | `fix-here` (M01) |
| G5 | No collected-results object or summarization idiom | Article ends at `summary(results$RMSE)`; nothing comparable to `collect_metrics()` | `fix-here` |
| G6 | No variance estimation or inference on the nested estimate | Absent everywhere; the underlying statistics are contested in the literature | `candidate` |
| G7 | Upstream intends to close G1–G3 but has stalled | tune#969 open; prototype branch `nested` untouched since 2024-09-13 (~22 months) | `candidate` |
| G8 | The name `nestedcv` is unavailable on CRAN | CRAN `nestedcv` 0.9.0 published 2026-07-14, actively maintained, different toolchain and audience | `fix-here` |

## Disposition

- **G1, G2, G3, G5** — the core premise of this package; they define the contract boundary settled in the design interview and land in `DESIGN.md` Purpose & Scope.
- **G4** — planned as M01 _(promoted from a candidate row, 2026-07-25)_. The cause is settled: `nested_cv()`'s helper `inside_resample()` calls `as.data.frame(src)`, materializing each outer fold's analysis set, so the inner `rset` references that copy rather than the original data. Cost is therefore V materialized analysis frames plus index vectors — driven by the outer fold count and nearly flat in the inner count, which is what the issue's own measurements show (10 outer × 5 bootstraps = 11.9×; 10 × 100 = 38.0×, the extra ≈26× being bootstrap index vectors). Not inherent to `rsplit`, and fixable from public rsample API (`make_splits()` + `manual_rset()`) without a fork. Scope consequence recorded as D-005.
- **G6** — a ROADMAP candidate row, deliberately not committed to. The statistics are unsettled; shipping an interval here without oracle backing would violate the oracle convention in `DESIGN.md`. _(2026-07-31: primary sources now on the shelf — `bates2023.md` and `krstajic2014.md`. They sharpen the gap rather than close it; see the G6 candidate row in `ROADMAP.md`.)_
- **G7** — drives the coordination action chosen at the design interview: ask on tune#969 about the prototype's status and whether a companion package is welcome, before scoping the first milestone. Recorded as a D-entry when the answer arrives.
- **G8** — forces a rename before any code is written. Recorded as a D-entry with the chosen name.

No rule was produced by this page, so no test locks it.

## Open questions

- Whether the tune `nested` prototype is dormant by intent or by capacity, and whether a companion package is welcome — unasked as of 2026-07-25; the question is queued for tune#969 — observed 2026-07-25.
- Whether the tune `nested` branch's prototype covers G2/G3/G5 or only G1 — branch not read beyond its commit metadata — observed 2026-07-25.
- ~~Whether rsample#283's memory behavior is inherent to the `rsplit` design or fixable within it~~ — **settled 2026-07-25**: not inherent; caused by `inside_resample()`'s `as.data.frame()`. Issue and all three comments read in full; `R/nested_cv.R`, `R/misc.R` (`make_splits`), and `R/manual.R` (`manual_rset`) read at `main` — observed 2026-07-25. See the G4 disposition above.
