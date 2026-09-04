# M62: A vignette reads the results object: summary, agreement, both plots, a failed fold, dplyr and the survival arguments

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** M60
- **Driving RR:** —
- **Principles touched:** IP4
- **Resolves:** —
- **Surface tier:** user-facing — a vignette shipped in the package and on the site
- **Branch/PR:** `m062-results-vignette`

## Goal

Ship `vignettes/results.Rmd` ("Reading the results"), which walks the `nested_results` object's columns, `summary()`, `collect_metrics(summarize = FALSE)`, `agreement()`, both `autoplot()` types, a run with one failed fold and the partial-summary warning that follows, the dplyr verbs that keep the class and the ones that shed it, and `event_level` and `eval_time` on a censored-regression run.

## Scope

**In:** the page; its `knit_exit()` guard on `ranger` and `recipes` (the guide's form); a planted failing fold (a preprocessor that errors on a data value present in exactly one outer fold's analysis set, the chunk asserting `sum(!res$.completed) == 1L`); a censored-regression section guarded on `censored` and `survival`; the page's `_pkgdown.yml` entry; its build-time figure.

**Out:** the tuners → M61; parallel runs → M63; inference on the estimate (GP5, the G6 candidate row); the `.inner_metrics` trajectory plot (candidate row); the Reproducibility section (stays in the guide, M60).

## Acceptance criteria

- [ ] AC1: The page builds under `R CMD check` with `ranger`, `recipes`, `censored` and `survival` installed, and its built HTML holds executed output from `print()`, `summary()`, `collect_metrics(summarize = FALSE)`, `agreement()` and `autoplot()` with both `type` values on one `nested_results`.
- [ ] AC2: An executed chunk produces a `nested_results` with exactly one `FALSE` in `.completed` and prints that fold's `.notes` showing its `location` and `type`; a chunk shows `summary()` on it warning with class `nestedtune_partial_summary`, the message naming the completed and requested fold counts, and the summary it still returns describing only the folds that ran; the prose reads the fold id and the location from the object inline.
- [ ] AC3: Executed chunks show `class()` of `dplyr::mutate(res, ...)` adding a column keeping `nested_results`, of a `dplyr::filter(res, ...)` that drops a fold shedding it, and of `res[, "id"]` shedding it, with the prose stating in one sentence the rule the help page states (D-031, D-036).
- [ ] AC4: A censored-regression section runs `nested_tune_grid()` with `eval_time` at two times on `survival_reg(dist = tune())` and shows `collect_metrics()` carrying `.eval_time`, with the prose reading both times inline; with `censored` or `survival` masked from `.libPaths()` the section is replaced by one notice and the rest of the page builds; with `ranger` or `recipes` masked the page prints its notice and exits at `knitr::knit_exit()`; each verified by one masked build.
- [ ] AC5: The built HTML contains both `autoplot()` figures, each with a non-empty `fig.alt`.
- [ ] AC6: The citation guard (M60) passes over the page; its build time, measured as M61 AC6 measures (`tools::buildVignettes()` with `skip =` naming every other vignette, median of three), is at most 60 seconds, and the combined figure without `skip =` at most 150 seconds.
- [ ] AC7: The profile's `verify` slot is clean and `devtools::check()` reports no error, warning or note beyond those on the default branch.

## Coverage

- AC1 → T1, T2
- AC2 → T3
- AC3 → T4
- AC4 → T5, T6
- AC5 → T2, T6
- AC6 → T6
- AC7 → T6

## Tasks

- [ ] T1: Draft the page: the guide's guard extended to `recipes`, design and run, then the anatomy section listing each column (`splits`, `id`, `.metrics`, `.selected`, `.inner_metrics`, `.notes`, `.completed`, the two seed columns) with one sentence and an executed peek.
- [ ] T2: The readers: `print()`, `summary()`, `collect_metrics(summarize = FALSE)`, `agreement()`, both `autoplot()` types with `fig.alt`; render both figures to PNG and look at them before committing (the M08 lesson).
- [ ] T3: The failed-fold section: a recipe step that errors on a value present in one fold's analysis set, the chunk's `stopifnot(sum(!res$.completed) == 1L)`, `.notes[[i]]` printed, `summary()` under `withCallingHandlers()` printing the warning class and message.
- [ ] T4: The dplyr section: the three `class()` chunks and the one-sentence rule.
- [ ] T5: The survival section with `has_srv <- requireNamespace("censored", quietly = TRUE) && requireNamespace("survival", quietly = TRUE)`, chunks `eval = has_srv`, inline reads confined to guarded chunks; a notice chunk `eval = !has_srv`; the fixture shape of `tests/testthat/helper-orchestration.R`'s `srv_data()` as the data.
- [ ] T6: `_pkgdown.yml` entry; measure AC6's two figures and log them with date and commit; run the guard, the verify slot and `devtools::check()`; one masked build each for `censored`/`survival`, for `ranger` and for `recipes`.

## Work log

- 2026-09-04: created by /milestone-plan.
- 2026-09-04: plan gate chose a data-keyed failing fold asserted to be exactly one over the test suite's design-level `break_fold()` plant because a page teaches with a workflow a reader could write, and the assertion in the chunk makes the count checkable; falsified by no data-keyed plant failing exactly one fold on the guide's design.
- 2026-09-04: criteria audit (full mode, the M60 reader) returned eight findings: `summary()` warns rather than refuses on a partial run (AC2 rewritten), a filter that drops no fold is the uninteresting case (AC3's triple re-cut), AC5 bound a viewing act (narrowed to the built figures), logging moved to T6, the `ranger` guard added, AC4's coverage extended, T1 split into T1 and T2, and the failing-fold mechanism decided as the line above records.
- 2026-09-04: second audit pass (full mode, a fresh [O] reader) returned three M62 findings: AC6's per-page figure now names `skip =`, AC5's width-and-height clause dropped as unfalsifiable, and `recipes` added to the guard and AC1 over committing to a workflow-level plant, because a recipe step is the plant a reader would write.
