# M66: The six vignette pages read the results through the package's readers under `library(tidymodels)`, and take a prose pass

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** M65
- **Driving RR:** —
- **Principles touched:** IP3
- **Resolves:** —
- **Surface tier:** user-facing — the shipped vignettes and the site articles
- **Branch/PR:** m066-vignette-sweep

## Goal

Rewrite every reader-facing chunk on the six pages under `vignettes/` to read through the M65 readers, dplyr and tibble with tidymodels attached, and pass all six pages' prose through one fresh read.

## Scope

**In:** `vignettes/nested-cv.Rmd`, `estimate.Rmd`, `results.Rmd`, `tuners.Rmd`, `articles/parallel.Rmd`, `articles/why-nest.Rmd`. `tidymodels` joins Suggests (D-053) and every page with a reader-facing chunk attaches it before `nestedtune`, behind a guard. Reader-facing chunks (effective `echo` and `include` after each page's `opts_chunk$set()`, which today sets only `collapse` and `comment`) drop the apply family, `do.call()`, anonymous functions, `<<-`, `withCallingHandlers()`, `data.frame()` and `$`-keyed bracket subsets for `collect_selections()`, `collect_notes()`, `collect_inner_metrics()`, dplyr verbs, `tibble()` and `rlang::catch_cnd()`; `final$tuning` becomes `extract_tune_results(final)` with `show_best()`; `expand.grid()` stays. A prose pass over all six pages with every finding dispositioned. NEWS.

**Out:** hidden chunks keep their base guards (plumbing the reader never sees). `vignettes/articles/why-nest-sim.R` (a script, never rendered; regenerating its store costs about 40 minutes). The roxygen examples (swept at planning: no base idiom found). An accessor for `attr(x, "procedure")`, which `tuners.Rmd` keeps reading with `attr()` → candidate row. Re-cutting the guide onto wide data → the existing M25 candidate row.

## Acceptance criteria

- [ ] AC1: A scripted sweep over the reader-facing chunks of every `.Rmd` under `vignettes/` (recursive), its command recorded in the Review evidence, finds no `vapply(`, `sapply(`, `lapply(`, `do.call(`, `Reduce(`, `Map(`, `<<-`, `withCallingHandlers(`, `function(`, `data.frame(`, or a bracket subset keyed on a `$` column (the pattern `[<name>$`), and finds `[[` only in a peek of the form `<object>$<column>[[<integer>]]`.
- [ ] AC2: The same sweep finds no `pkg::` prefix on `nestedtune` or on any package in `tidymodels::core`; every page with a reader-facing chunk attaches `tidymodels` and then `nestedtune` in its libraries chunk, behind a guard that ends the page with one notice when tidymodels is absent.
- [ ] AC3: No chunk under `vignettes/` reads `$tuning` off a final fit; `nested-cv.Rmd` reaches the tuning run through `extract_tune_results()` and its best score through `show_best()`, both in reader-facing chunks.
- [ ] AC4: The reader-facing chunk that prints the guide's fold-by-selection table calls `collect_selections(res)`; the chunks that print the failed fold's and a completed fold's notes on `results.Rmd` call `collect_notes()`; the chunk that counts fits per fold on `tuners.Rmd` calls `collect_inner_metrics()` and summarises with dplyr; the chunks that show a warning's class on `results.Rmd` and `articles/parallel.Rmd` call `rlang::catch_cnd()`.
- [ ] AC5: The four CRAN vignettes build in under 150 s together, `tuners` under 45 s and `results` under 60 s, each the median of three `rmarkdown::render()` timings on one head.
- [ ] AC6: Outside code chunks and inline `r` expressions, the six `.Rmd` files contain no em dash and no token matching `M\d\d`, and every `vignette("<name>")` string in them names one of `nested-cv`, `estimate`, `results`, `tuners`; each shown by a grep recorded in the Review evidence.
- [ ] AC7: `test-vignette-citations.R` passes, `devtools::check()` reports 0 errors, 0 warnings, 0 notes, `pkgdown::check_pkgdown()` passes, and `pkgdown::build_articles()` renders both site articles locally with mirai and ranger installed.

## Coverage

- AC1 → T2, T3, T4, T5
- AC2 → T1
- AC3 → T2
- AC4 → T2, T3, T4, T5
- AC5 → T7
- AC6 → T6, T7
- AC7 → T7

## Tasks

- [x] T1: Install tidymodels locally (absent on 2026-09-05); add it to Suggests; on each of the five code pages fold `requireNamespace("tidymodels")` into the existing `has_*` guard so one notice names what is missing, and replace the libraries chunk with `library(tidymodels)` then `library(nestedtune)`; drop `library(recipes)` and `library(ggplot2)` where tidymodels attaches them; strip `tune::`, `dplyr::`, `dials::`, `yardstick::`, `tibble::` prefixes.
- [x] T2: `nested-cv.Rmd`: `filter()` for the rmse rows; `collect_selections(res)` for the fold table and `n_distinct()` for the counts; `tibble()` for the comparison table; `extract_tune_results(final)` piped to `show_best(metric = "rmse", n = 1)` for the selection-time score, in the hidden writeup chunk too; the refusal chunks unprefixed.
- [ ] T3: `results.Rmd`: `select()` for the seed columns; `collect_notes(failed)` for both notes readings, the counts as `count(id)`; the `mutate()` example with a plain arithmetic column; `rlang::catch_cnd()` for the partial warning's class and message with the summary printed in a `warning = FALSE` chunk; `tibble()` for `surv_df`.
- [ ] T4: `tuners.Rmd`: `collect_inner_metrics(race)` with `filter()`, `group_by()` and `summarise()` for the fits per fold, `slice_min()` for the cheapest fold; the hidden count chunk may follow.
- [ ] T5: `articles/parallel.Rmd`: the dispatcher-less run in a `warning = FALSE` chunk, then `rlang::catch_cnd()` on a repeat call for the class, its message through `cli::ansi_strip()` (the M63 lesson); `articles/why-nest.Rmd`: the figure's long table via `tibble()` and `bind_rows()`.
- [ ] T6: Prose pass: a fresh [O] reader over the six rendered pages for clarity, consistency between pages and plain style; every finding fixed or rejected with a one-line reason in this file's Decisions section.
- [ ] T7: Timings (median of three renders per page), `pkgdown::build_articles()`, `devtools::test()`, `devtools::check()` 0/0/0, `pkgdown::check_pkgdown()`, `air format --check`; the AC1, AC2 and AC6 sweeps run and recorded; NEWS entry.

## Work log

- 2026-09-05: created by /milestone-plan. Criteria audit ran in full mode on a fresh [O] reader: seven findings, all fixed in the wording (reader-facing defined by effective chunk options; the attach claim narrowed to the prefixes; `$selected` and `$tuning_seed` kept as documented elements, only `$tuning` moved to the accessor; the article render moved to AC7's named command; the inline-numbers claim dropped, the citation guard's prose-numeral rule already enforcing it; the em-dash claim scoped to prose).
- 2026-09-05: plan gate chose `library(tidymodels)` (user choice) over attaching the Imports individually (the recommended option) because the pages should read like the ecosystem's; falsified by the guard failing on a CRAN flavor or the attach cost pushing a page past its cap, at which point the pages attach tune, dplyr and ggplot2 individually.
- 2026-09-05: plan gate chose keeping `expand.grid()` over `dials::grid_regular()` because the call shows the six candidates the page runs; falsified by a reader mistaking the grid for a dials object.
- 2026-09-05: plan gate chose a review-time token sweep and a prose ledger over a permanent test enforcing the idiom list, because a style lint over in-repo prose is a checker over internal artifacts; falsified by a later page reintroducing the idioms unnoticed at its review.
- 2026-09-05: plan gate chose `rlang::catch_cnd()` over knitr's default warning display because the warning's class is the didactic point; falsified by the repeat call the parallel article needs costing more than the page's budget allows.
- 2026-09-05: T1 done. tidymodels installed locally and added to Suggests; the five code pages guard on tidymodels plus their optional packages with one notice, then attach `library(tidymodels)` and `library(nestedtune)`; core-package prefixes stripped from chunks; `library(recipes)` and `library(ggplot2)` dropped. `benchmarks/sweep-vignette-idioms.R` written for the AC1, AC2 and AC6 sweeps; on the pre-T2 pages it reports 23 idiom hits and no prefix or prose hit. All five pages render; nestedtune reinstalled so the parallel article's daemons see the M65 readers.

- 2026-09-05: T2 done. `nested-cv.Rmd` reads the rmse row with `filter()`, the fold table with `collect_selections()` and `n_distinct()`, the per-fold scores with `filter()` and `pull()`, the selection-time score with `extract_tune_results(final) |> show_best(metric = "rmse", n = 1)` and the comparison table with `tibble()`; the page renders and the sweep reports nothing on it. The rendered comparison shows the selection-time rmse higher than the nested estimate, as before.

## Decisions

## Review
