# M62: A vignette reads the results object: summary, agreement, both plots, a failed fold, dplyr and the survival arguments

- **Status:** review
- **Priority:** normal
- **Depends on:** M60
- **Driving RR:** —
- **Principles touched:** IP4
- **Resolves:** —
- **Surface tier:** user-facing — a vignette shipped in the package and on the site
- **Branch/PR:** `m062-results-vignette` · https://github.com/tidymodels/nestedtune/pull/72

## Goal

Ship `vignettes/results.Rmd` ("Reading the results"), which walks the `nested_results` object's columns, `summary()`, `collect_metrics(summarize = FALSE)`, `agreement()`, both `autoplot()` types, a run with one failed fold and the partial-summary warning that follows, the dplyr verbs that keep the class and the ones that shed it, and `event_level` and `eval_time` on a censored-regression run.

## Scope

**In:** the page; its `knit_exit()` guard on `ranger` (the guide's form); a planted failing fold (a preprocessor that errors on a data value present in exactly one outer fold's analysis set, the chunk asserting `sum(!res$.completed) == 1L`); a censored-regression section guarded on `censored` and `survival`; the page's `_pkgdown.yml` entry; its build-time figure.

**Out:** the tuners → M61; parallel runs → M63; inference on the estimate (GP5, the G6 candidate row); the `.inner_metrics` trajectory plot (candidate row); the Reproducibility section (stays in the guide, M60).

## Acceptance criteria

- [x] AC1: The page builds under `R CMD check` with `ranger`, `recipes`, `censored` and `survival` installed, and its built HTML holds executed output from `print()`, `summary()`, `collect_metrics(summarize = FALSE)`, `agreement()` and `autoplot()` with both `type` values on one `nested_results`.
- [x] AC2: An executed chunk produces a `nested_results` with exactly one `FALSE` in `.completed` and prints that fold's `.notes` showing its `location` and `type`; a chunk shows `summary()` on it warning with class `nestedtune_partial_summary`, the message naming the completed and requested fold counts, and the summary it still returns describing only the folds that ran; the prose reads the fold id and the location from the object inline.
- [x] AC3: Executed chunks show `class()` of `dplyr::mutate(res, ...)` adding a column keeping `nested_results`, of a `dplyr::filter(res, ...)` that drops a fold shedding it, and of `res[, "id"]` shedding it, with the prose stating in one sentence the rule the help page states (D-031, D-036).
- [x] AC4: A censored-regression section runs `nested_tune_grid()` with `eval_time` at two times on `survival_reg(dist = tune())` and shows `collect_metrics()` carrying `.eval_time`, with the prose reading both times inline; with `censored` masked from `.libPaths()` the section is replaced by one notice naming `censored` as the absent package and the rest of the page builds; with `ranger` masked the page prints its notice and the built HTML holds nothing after it; verified by two masked builds, one with `censored` masked and one with `ranger` masked.
- [x] AC5: The built HTML contains both `autoplot()` figures, each with a non-empty `fig.alt`.
- [x] AC6: The citation guard (M60) passes over the page; its build time, measured as M61 AC6 measures (`tools::buildVignettes()` with `skip =` naming every other vignette, median of three), is at most 60 seconds, and the combined figure without `skip =` at most 150 seconds.
- [x] AC7: The profile's `verify` slot is clean and `devtools::check()` reports no error, warning or note beyond those on the default branch.

## Coverage

- AC1 → T1, T2
- AC2 → T3
- AC3 → T4
- AC4 → T5, T6
- AC5 → T2, T6
- AC6 → T6
- AC7 → T6

## Tasks

- [x] T1: Draft the page: the guide's guard, design and run, then the anatomy section listing each column (`splits`, `id`, `.metrics`, `.selected`, `.inner_metrics`, `.notes`, `.completed`, the two seed columns) with one sentence and an executed peek.
- [x] T2: The readers: `print()`, `summary()`, `collect_metrics(summarize = FALSE)`, `agreement()`, both `autoplot()` types with `fig.alt`; render both figures to PNG and look at them before committing (the M08 lesson).
- [x] T3: The failed-fold section: a recipe step that errors on a value present in one fold's analysis set, the chunk's `stopifnot(sum(!res$.completed) == 1L)`, `.notes[[i]]` printed, `summary()` under `withCallingHandlers()` printing the warning class and message.
- [x] T4: The dplyr section: the three `class()` chunks and the one-sentence rule.
- [x] T5: The survival section with `has_srv <- requireNamespace("censored", quietly = TRUE) && requireNamespace("survival", quietly = TRUE)`, chunks `eval = has_srv`, inline reads confined to guarded chunks; a notice chunk `eval = !has_srv`; the fixture shape of `tests/testthat/helper-orchestration.R`'s `srv_data()` as the data.
- [x] T6: `_pkgdown.yml` entry; measure AC6's two figures and log them with date and commit; run the guard, the verify slot and `devtools::check()`; one masked build each for `censored` and for `ranger`.

## Work log

- 2026-09-04: created by /milestone-plan.
- 2026-09-04: plan gate chose a data-keyed failing fold asserted to be exactly one over the test suite's design-level `break_fold()` plant because a page teaches with a workflow a reader could write, and the assertion in the chunk makes the count checkable; falsified by no data-keyed plant failing exactly one fold on the guide's design.
- 2026-09-04: criteria audit (full mode, the M60 reader) returned eight findings: `summary()` warns rather than refuses on a partial run (AC2 rewritten), a filter that drops no fold is the uninteresting case (AC3's triple re-cut), AC5 bound a viewing act (narrowed to the built figures), logging moved to T6, the `ranger` guard added, AC4's coverage extended, T1 split into T1 and T2, and the failing-fold mechanism decided as the line above records.
- 2026-09-04: second audit pass (full mode, a fresh [O] reader) returned three M62 findings: AC6's per-page figure now names `skip =`, AC5's width-and-height clause dropped as unfalsifiable, and `recipes` added to the guard and AC1 over committing to a workflow-level plant, because a recipe step is the plant a reader would write.
- 2026-09-04: implement gate chose `recipes::check_range(hp)` as the failing-fold plant, measured on the guide's design: Fold1 fails at the outer fit (the Maserati's 335 hp lies above the range that fold trained on, beyond recipes' default slack) and the other four folds complete carrying a note from the inner resample that held it out; `check_new_values(carb)` failed two folds (two singleton carburetor counts), a relevel step none, a `step_mutate()` that stops when the value is absent all five. `event_level` is explained in prose and not passed on the censored run, since tune ignores it outside classification (`check_event_level()`'s comment).
- 2026-09-04: T1, T2 `vignettes/results.Rmd` drafted: guard on `ranger` and `recipes` (one notice naming what is absent, then `knit_exit()`), the guide's design and run, one sentence and an executed peek per column (`splits`, `id`, `.metrics`, `.selected`, `.inner_metrics`, `.notes`, `.completed`, the two seed columns), then `summary()`, `collect_metrics()` both ways, `agreement()` and both `autoplot()` views with `fig.alt`; rendered on a temporary copy in 4.9 s and both PNGs looked at (two panels each, labels and subtitles fit); citation guard green (37).
- 2026-09-04: T3 the failed-fold section: `recipes::check_range(hp)` on the guide's run, the chunk's `stopifnot(sum(!failed$.completed) == 1L)` holds (Fold1 fails at the outer fit; the other four complete with one or two inner-tuning notes each), the failed fold's `.notes` printed with `location`, `type` and `note`, a completed fold's notes shown beside it, and `summary()` under `withCallingHandlers()` printing class `nestedtune_partial_summary` and the message covering 4 of 5 folds, then the summary over the four; the run chunk mutes tune's progress messages (`message = FALSE`) since the live catalog printed run-together lines, warnings kept; rendered and read; citation guard green (37).
- 2026-09-04: T4 the dplyr section: `class()` of `dplyr::mutate(res, rmse = ...)` keeps `nested_results`, of `dplyr::filter(failed, .completed)` (drops the failed fold) and of `res[, "id"]` sheds it to a bare tibble, with the help page's rule in one sentence; rendered and read; citation guard green.
- 2026-09-04: T5 the survival section: `has_srv` guard over `censored` and `survival`, `srv_data()`'s simulation inline (180 rows, seed 51), `survival_reg(dist = tune())` over three distributions on a 3x3 design with `eval_time = c(0.5, 10)` and `yardstick::brier_survival`; `collect_metrics()` both ways carry `.eval_time`, the two times read inline from a `results = "asis"` chunk under the guard, `.selected[[1]]` shown; the run chunk mutes tune's per-fold `select_best()` warning that the first time is used (`warning = FALSE`, said in prose); `event_level` explained in prose, not run; one notice chunk `eval = !has_srv` naming what is absent; rendered and read; citation guard green.
- 2026-09-04: amendment (substantive, mini gate): the recipes clause dropped from AC4 and the `recipes` guard from the page, Scope In, T1 and T6 reworded to match, because tune imports recipes, so a recipes-masked build fails at `library(nestedtune)` before any guard runs (the same shape as M61's dials finding); AC1 keeps naming recipes among the installed packages. Found at T6's masked builds; the same builds also caught the notice's singular branch reading "is installed here" for "is not", fixed in both notices.
- 2026-09-04: re-audit: AC4 (full) — three findings: `survival` is unmaskable from `.libPaths()` (system library) so the disjunction should name `censored` alone, "each verified by one masked build" should say two builds explicitly, and "exits at `knitr::knit_exit()`" should state the built-page observable; reachability, bounded promise and proportionality returned nothing. The user chose the reader's wording at a second mini gate; AC4 is written as it now reads and takes no further reader.
- 2026-09-04: T6 `results` under Guides in `_pkgdown.yml` (`check_pkgdown()` clean), NEWS entry; AC6 at commit 19608aa (the final page): `tools::buildVignettes(skip = c("estimate", "nested-cv", "tuners"))` on a temporary copy, three runs 15.0, 13.6, 13.8 s, median 13.8 s against the 60 s cap, and all four vignettes 59.9, 60.7, 61.2 s, median 60.7 s against 150; masked renders through `rmarkdown::render()`: censored masked gives six sections, fourteen tibble prints and one notice naming censored; ranger masked gives the notice and nothing after it (0 headings); recipes masked cannot load the package (tune imports it, the amendment above); citation guard green (37); `devtools::test()` no failures; `devtools::check()` 0 errors, 0 warnings, 0 notes (7m 54s). Status to review.
- 2026-09-04: review checkpoint: PR #72 opened as draft; AC1–AC5 verified (evidence in the Review section); AC6 timing and AC7 pending the background check; three reviewers spawned, the blame-history lens reported no findings.
- 2026-09-04: review: three lenses reported (dispositions in the Review section); the user accepted the recommended triage, the 14 fix-now edits landed at 04735ea and were re-verified; step-7 approval: PR #72 approved for merge.
- 2026-09-04: CI wait on PR #72 hit the session ceiling after the approval push re-triggered the matrix: pkgdown and format-suggest pass, seven checks pending on a32a970; watcher stopped, resume via /milestone-review M62 (route c).

## Review

Reviewed 2026-09-04 against commit a27fefe on `m062-results-vignette`, PR #72. Builds through `rmarkdown::render()` on a copy of the page in a scratch directory; masked builds under a symlinked copy of the user library less one package, with `requireNamespace()` confirmed `FALSE` in the build.

- AC1 — pass: the full build (16.8 s) holds six sections, fourteen tibble prints and both figures; the executed output of `print()` (the 5 × 9 results print), `summary()` (5 requested, 5 completed, the estimate over 5 folds), `collect_metrics()` and `collect_metrics(summarize = FALSE)` (2 and 10 rows), `agreement()` (two combinations, 3 and 2 folds) and both `autoplot()` views are on one `nested_results`, `res`. `devtools::check()` evidence is AC7's.
- AC2 — pass: the failed run prints "1 of 5 outer folds failed" and the chunk's `stopifnot(sum(!failed$.completed) == 1L)` held; the failed fold's `.notes` print shows `location` (`outer fit`, `outer fit: preprocessor 1/1 (prediction data)`) and `type` (`error`); `summary()` under the handler prints `class: nestedtune_partial_summary` and the message "This summary covers 4 of 5 outer folds", and the returned summary reads "5 requested, 4 completed" with the estimate over 4 of 5; the prose reads `Fold1` and `outer fit` inline, and the counts 4 and 4.
- AC3 — pass: `class(with_rmse)` after `dplyr::mutate()` prints `nested_results` first; `class(completed_only)` after `dplyr::filter(failed, .completed)` and `class(res[, "id"])` both print the bare tibble classes; the rule is one sentence at the section's head.
- AC4 — pass: the survival run is `survival_reg(dist = tune())` with `eval_time = c(0.5, 10)`; `collect_metrics()` carries `.eval_time` with rows at 0.5 and 10, the per-fold table the same, and the prose reads "the Brier score at 0.5 and at 10". Censored masked: the page builds (six sections, eleven tibble prints), the section's chunks produce no output, and one notice names censored as the package not installed; the unexecuted chunks' source and the prose between them remain visible after the notice, which the built page shows and the M61 page shares. Ranger masked: the notice is the page's last content (no headings, no output, no figures after it). Two masked builds, one per package.
- AC5 — pass: the built HTML holds two `<img>` elements, one per `autoplot()` view, each with a non-empty `alt` naming the panels and the points.
- AC6 — pass: the citation guard (`tests/testthat/test-vignette-citations.R`) 22 tests, 37 expectations, 0 failures at e32cc5c; `tools::buildVignettes(skip = c("estimate", "nested-cv", "tuners"))` on a copy of the package, after the background check had finished, three runs 11.9, 10.8, 10.7 s, median 10.8 s against the 60 s cap; all four vignettes 44.5, 44.9, 45.6 s, median 44.9 s against 150.
- AC7 — pass: `devtools::test()` 633 tests, 7042 expectations, 0 failures, 0 warnings, 0 skips; `devtools::check()` at a27fefe 0 errors, 0 warnings, 0 notes (8m 30s), the same as the default branch.

Consistency gate: `cairn_validate.py` all checks pass (18 references-staleness advisories, standing); no principle changed, so no impact report; `devtools::document()` no diff; README.md and README.Rmd last changed in the same commit (2aac24a), branch touches neither; `pkgdown::check_pkgdown()` no problems; NEWS entry present with no milestone number; no new top-level file; check 0/0/0.

Independent review (three lenses, fresh context): [O] diff-bug 16 findings, [S] blame-history none, [S] prior-review three (P1–P3, all the M06 F5 shape: a behavior claim with no executed chunk behind it). Dispositions recorded at the gate below.

Gate triage (user chose the recommended set). Fix now, applied on the branch: O1 the failed-run print moved to its own chunk so cli's output is not muted; O2 and O16 the survival section's chunks take `include = has_srv` and its three prose paragraphs move into guarded `results = "asis"` chunks, so a censored-masked build holds heading, intro and notice (0 code blocks after the heading); NEWS reworded; O3 the completed-fold prose now says some folds carry a second note from the low end of the range; O4 heading and intro name `event_level` and `eval_time`; O5 the rule adds "or overwrites"; O6 the seeds point to the guide for restoring and the help pages for the recipe; O7 "a plain tibble print, no summary of the run"; O8 "less `.config`"; O9 the chunk prints the outer fold's id and one sentence explains the parenthesized inner id; O10 "beyond a small slack"; O12 base `[` named as the same rule's door; O13 `n` and `prop` named; O15 "Every tuning driver", with `nested_final_fit()` reading them back; P3 `agreement(surv_res)` shown, the closing sentence narrowed. Rejected: O11 (`survival` is a recommended package and can be absent from an R build; the guard costs nothing); O14 (verified against `per_fold_metrics()`; a peek would repeat the per-fold table); P1 and P2 (verified against the code by the diff-bug lens; an all-failed run is a second run on a page at length). No finding failed a criterion; none returned status.
- AC1, AC2, AC4, AC5 — re-verified after the fixes: full build five h2 (the last carries code tags), 16 tibble prints, both figures with alt; the failed-run print now in the page with `FALSE` at Fold1; censored masked: five sections, 12 tibble prints, the survival section is heading, intro and one notice naming censored; ranger masked: notice then nothing. AC3 chunks unchanged. AC6 guard 37 expectations green; AC6 timing and AC7 check re-run below.
- conversation: PR #72 — empty (0 reviews, 0 comments, 0 unresolved threads) at the gate read.
- AC6 — re-verified at 04735ea: page alone 10.7, 9.7, 9.7 s, median 9.7 s against 60; all four vignettes 42.6, 41.8, 41.8 s, median 41.8 s against 150 (an earlier re-timing under another session's tidymedia check and test run, 60.4 and 243.7 s, was discarded as a measure of the page: ranger threads across every core). Guard 37 expectations green on the fixed page.
- AC7 — re-verified at 04735ea: `devtools::check()` 0 errors, 0 warnings, 0 notes (26 min under the same contention); CI on PR #72 green, 11 checks, on that head.
