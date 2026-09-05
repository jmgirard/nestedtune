# M66: The six vignette pages read the results through the package's readers under `library(tidymodels)`, and take a prose pass

- **Status:** review
- **Priority:** normal
- **Depends on:** M65
- **Driving RR:** —
- **Principles touched:** IP3
- **Resolves:** —
- **Surface tier:** user-facing — the shipped vignettes and the site articles
- **Branch/PR:** m066-vignette-sweep · https://github.com/tidymodels/nestedtune/pull/76

## Goal

Rewrite every reader-facing chunk on the six pages under `vignettes/` to read through the M65 readers, dplyr and tibble with tidymodels attached, and pass all six pages' prose through one fresh read.

## Scope

**In:** `vignettes/nested-cv.Rmd`, `estimate.Rmd`, `results.Rmd`, `tuners.Rmd`, `articles/parallel.Rmd`, `articles/why-nest.Rmd`. `tidymodels` joins Suggests (D-053) and every page with a reader-facing chunk attaches it before `nestedtune`, behind a guard. Reader-facing chunks (effective `echo` and `include` after each page's `opts_chunk$set()`, which today sets only `collapse` and `comment`) drop the apply family, `do.call()`, anonymous functions, `<<-`, `withCallingHandlers()`, `data.frame()` and `$`-keyed bracket subsets for `collect_selections()`, `collect_notes()`, `collect_inner_metrics()`, dplyr verbs, `tibble()` and `rlang::catch_cnd()`; `final$tuning` becomes `extract_tune_results(final)` with `show_best()`; `expand.grid()` stays. A prose pass over all six pages with every finding dispositioned. NEWS.

**Out:** hidden chunks keep their base guards (plumbing the reader never sees). `vignettes/articles/why-nest-sim.R` (a script, never rendered; regenerating its store costs about 40 minutes). The roxygen examples (swept at planning: no base idiom found). An accessor for `attr(x, "procedure")`, which `tuners.Rmd` keeps reading with `attr()` → candidate row. Re-cutting the guide onto wide data → the existing M25 candidate row.

## Acceptance criteria

- [x] AC1: A scripted sweep over the reader-facing chunks of every `.Rmd` under `vignettes/` (recursive), its command recorded in the Review evidence, finds no `vapply(`, `sapply(`, `lapply(`, `do.call(`, `Reduce(`, `Map(`, `<<-`, `withCallingHandlers(`, `function(`, `data.frame(`, or a bracket subset keyed on a `$` column (the pattern `[<name>$`), and finds `[[` only in a peek of the form `<object>$<column>[[<integer>]]`.
- [x] AC2: The same sweep finds no `pkg::` prefix on `nestedtune` or on any package in `tidymodels::core`; every page with a reader-facing chunk attaches `tidymodels` and then `nestedtune` in its libraries chunk, behind a guard that ends the page with one notice when tidymodels is absent.
- [x] AC3: No chunk under `vignettes/` reads `$tuning` off a final fit; `nested-cv.Rmd` reaches the tuning run through `extract_tune_results()` and its best score through `show_best()`, both in reader-facing chunks.
- [x] AC4: The reader-facing chunk that prints the guide's fold-by-selection table calls `collect_selections(res)`; the chunks that print the failed fold's and a completed fold's notes on `results.Rmd` call `collect_notes()`; the chunk that counts fits per fold on `tuners.Rmd` calls `collect_inner_metrics()` and summarises with dplyr; the chunks that show a warning's class on `results.Rmd` and `articles/parallel.Rmd` call `rlang::catch_cnd()`.
- [x] AC5: The four CRAN vignettes build in under 150 s together, `tuners` under 45 s and `results` under 60 s, each the median of three `rmarkdown::render()` timings on one head.
- [x] AC6: Outside code chunks and inline `r` expressions, the six `.Rmd` files contain no em dash and no token matching `M\d\d`, and every `vignette("<name>")` string in them names one of `nested-cv`, `estimate`, `results`, `tuners`; each shown by a grep recorded in the Review evidence.
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
- [x] T3: `results.Rmd`: `select()` for the seed columns; `collect_notes(failed)` for both notes readings, the counts as `count(id)`; the `mutate()` example with a plain arithmetic column; `rlang::catch_cnd()` for the partial warning's class and message with the summary printed in a `warning = FALSE` chunk; `tibble()` for `surv_df`.
- [x] T4: `tuners.Rmd`: `collect_inner_metrics(race)` with `filter()`, `group_by()` and `summarise()` for the fits per fold, `slice_min()` for the cheapest fold; the hidden count chunk may follow.
- [x] T5: `articles/parallel.Rmd`: the dispatcher-less run in a `warning = FALSE` chunk, then `rlang::catch_cnd()` on a repeat call for the class, its message through `cli::ansi_strip()` (the M63 lesson); `articles/why-nest.Rmd`: the figure's long table via `tibble()` and `bind_rows()`.
- [x] T6: Prose pass: a fresh [O] reader over the six rendered pages for clarity, consistency between pages and plain style; every finding fixed or rejected with a one-line reason in this file's Decisions section.
- [x] T7: Timings (median of three renders per page), `pkgdown::build_articles()`, `devtools::test()`, `devtools::check()` 0/0/0, `pkgdown::check_pkgdown()`, `air format --check`; the AC1, AC2 and AC6 sweeps run and recorded; NEWS entry.

## Work log

- 2026-09-05: created by /milestone-plan. Criteria audit ran in full mode on a fresh [O] reader: seven findings, all fixed in the wording (reader-facing defined by effective chunk options; the attach claim narrowed to the prefixes; `$selected` and `$tuning_seed` kept as documented elements, only `$tuning` moved to the accessor; the article render moved to AC7's named command; the inline-numbers claim dropped, the citation guard's prose-numeral rule already enforcing it; the em-dash claim scoped to prose).
- 2026-09-05: plan gate chose `library(tidymodels)` (user choice) over attaching the Imports individually (the recommended option) because the pages should read like the ecosystem's; falsified by the guard failing on a CRAN flavor or the attach cost pushing a page past its cap, at which point the pages attach tune, dplyr and ggplot2 individually.
- 2026-09-05: plan gate chose keeping `expand.grid()` over `dials::grid_regular()` because the call shows the six candidates the page runs; falsified by a reader mistaking the grid for a dials object.
- 2026-09-05: plan gate chose a review-time token sweep and a prose ledger over a permanent test enforcing the idiom list, because a style lint over in-repo prose is a checker over internal artifacts; falsified by a later page reintroducing the idioms unnoticed at its review.
- 2026-09-05: plan gate chose `rlang::catch_cnd()` over knitr's default warning display because the warning's class is the didactic point; falsified by the repeat call the parallel article needs costing more than the page's budget allows.
- 2026-09-05: T1 done. tidymodels installed locally and added to Suggests; the five code pages guard on tidymodels plus their optional packages with one notice, then attach `library(tidymodels)` and `library(nestedtune)`; core-package prefixes stripped from chunks; `library(recipes)` and `library(ggplot2)` dropped. `benchmarks/sweep-vignette-idioms.R` written for the AC1, AC2 and AC6 sweeps; on the pre-T2 pages it reports 23 idiom hits and no prefix or prose hit. All five pages render; nestedtune reinstalled so the parallel article's daemons see the M65 readers.

- 2026-09-05: T2 done. `nested-cv.Rmd` reads the rmse row with `filter()`, the fold table with `collect_selections()` and `n_distinct()`, the per-fold scores with `filter()` and `pull()`, the selection-time score with `extract_tune_results(final) |> show_best(metric = "rmse", n = 1)` and the comparison table with `tibble()`; the page renders and the sweep reports nothing on it. The rendered comparison shows the selection-time rmse higher than the nested estimate, as before.

- 2026-09-05: T3 done. `results.Rmd` reads the seeds with `select()`, both notes readings through `collect_notes()` with `filter()` on the fold label and the counts as `count(notes, id)`, the partial warning's class and message with `rlang::catch_cnd()` and the summary in a `warning = FALSE` chunk, the `mutate()` example as a `row_number()` column, and `surv_df` and `surv_grid` as tibbles. The rendered page shows no ANSI code in the warning's message, so it prints through `cat()` alone. Renders; the sweep reports nothing on it.

- 2026-09-05: T4 done. `tuners.Rmd` counts the fits per fold as `collect_inner_metrics(race) |> filter() |> group_by(id) |> summarise(fits = sum(n))`, takes the cheapest fold with `slice_min(with_ties = FALSE)` and shows its table by filtering the stacked metrics on its label; the hidden count chunk reads the same stack. Renders; the sweep reports nothing on it; the rendered prose still names Fold3 at 23 fits against 30.

- 2026-09-05: T5 done. `articles/parallel.Rmd` runs the dispatcher-less pool in a `warning = FALSE` chunk and catches the class on a repeat call with `rlang::catch_cnd()`, which returns at the dispatch-time warning before any fold runs; the hidden message chunk keeps `cli::ansi_strip()`. `articles/why-nest.Rmd` builds the figure's long table with `bind_rows()` and `tibble()` and levels it in `mutate()`. Both render; the sweep is clean over the whole tree.

- 2026-09-05: T7 started: NEWS entry written; the sweep script formatted by air; planted-page check shows every sweep class firing (idioms, prefix, attach order, guard, em dash, `M12`, a foreign `vignette()` name) with the peek, the hidden chunk and the inline span silent; `pkgdown::check_pkgdown()` clean. T6 reader and the test suite in flight.

- 2026-09-05: T6 done. A fresh [O] reader over the six rendered pages returned 32 findings (nested-cv 9, estimate 6, results 7, tuners 4, parallel 3, why-nest 3); 28 fixed in the prose, one (results F16) by adding a `collect_selections(res)` and `collect_inner_metrics(res)` chunk to the readers section, one (tuners F25) by reading the win/loss race through `collect_inner_metrics()` too; four rejected, reasons in Decisions. The tuners F23 em dash lives in the results print method and goes to a candidate row. Sweep clean; tuners and results re-rendered.

- 2026-09-05: T7: `test-vignette-citations.R` passes and the AC6 grep finds nothing on e26e722. First AC5 timing attempt on e26e722 under outside load (a game and a lualatex job each near a full core, load average 15.8): medians nested-cv 27.0 s, estimate 0.2 s, results 26.2 s, tuners 56.1 s (runs 143.0 / 36.9 / 56.1), total 109.5 s; tuners over its 45 s cap on that run, to be re-timed on a quieter machine (the T1 render measured it at 33.1 s). `devtools::check()` started.

- 2026-09-05: T7 all but the timings: `devtools::check()` 0 errors, 0 warnings, 0 notes (25m 54s); `pkgdown::build_articles()` renders both site articles with mirai and ranger; `pkgdown::check_pkgdown()` clean; `air format --check` clean; `devtools::test()` green; the AC1/AC2 sweep (`Rscript benchmarks/sweep-vignette-idioms.R`) and the AC6 grep clean on 542ac4c. Second AC5 run at load average 12 (the game, a lualatex job, and the user's own `devtools::test()` and a tidymedia `devtools::check()` in other sessions): medians nested-cv 24.2 s, estimate 0.7 s, results 49.2 s, tuners 146.1 s (runs 146.1 / 147.0 / 104.1), total 220.2 s; ranger's fits are multithreaded, so the page's elapsed time tracks the contention. Blocked: AC5 needs three renders per page on a machine without that outside load; resume with `/milestone-implement M66` runs the timing script once and, under the caps, sets review.

- 2026-09-05: T7 done. AC5 timings on 5a29070 (`Rscript benchmarks/time-vignettes.R <dir>`), the game and the lualatex job gone and one outside `devtools::test()` on one core, load average 7.5 falling to 5.9: medians nested-cv 5.7 s, estimate 0.2 s, results 10.8 s, tuners 31.9 s (runs 31.9 / 31.7 / 32.7), total 48.5 s; all four under the caps. An earlier run this session at load average 11.8 gave tuners 131.4 s and total 175.5 s; an A/B on main's `tuners.Rmd` under that same load rendered in 135.3 and 131.3 s against the branch's 129.1 and 79.1 s, so the excess was contention and the branch's page is no slower than main's. `benchmarks/time-vignettes.R` sits under the `.Rbuildignore`d `benchmarks/` and passes `air format --check`. Status set to review.

## Decisions

- 2026-09-05 (T6 prose pass): findings 2, 3, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 24, 25, 26, 27, 28, 29, 30, 31 and 32 of the reader's list fixed as proposed or in equivalent words; F13's direction check confirmed the sentence had the sign wrong (the selection-time score is not reliably better-looking) and F14's figures confirmed against `references/tibshirani2009.md` as minimum CV error rates.
- 2026-09-05 (T6 F1, rejected): the guide's notice says "guide" where the other pages say "page" because every other page calls it the getting-started guide, so the page names itself as the others name it.
- 2026-09-05 (T6 F4, rejected): the guide counts distinct values per parameter with `n_distinct()` because that is the sentence's claim (how many values each parameter took); `agreement()` tabulates combinations and is introduced on the results page.
- 2026-09-05 (T6 F10, rejected): "k-fold test error" is the cited source's name for the quantity (Bayle et al., 2026) and stays, the `v` in the same list item being this package's fold count.
- 2026-09-05 (T6 F23, rejected here): the em dash in the results print's candidates line is package output, not page prose, and changing it re-records snapshots outside this milestone's scope; captured as a ROADMAP candidate row.

## Review

- 2026-09-05, PR #76 (https://github.com/tidymodels/nestedtune/pull/76), evidence on 345fd78 unless stated; the default branch had not moved since the branch was cut, so no merge-in was needed.
- AC1: `Rscript benchmarks/sweep-vignette-idioms.R` over every `.Rmd` under `vignettes/` (recursive; six pages) prints `clean`, exit 0: no idiom hit in a reader-facing chunk and no `[[` outside the peek form. Verified.
- AC2: the same run's prefix check is clean (no `pkg::` on nestedtune or a `tidymodels:::core` package in a shown chunk). `grep -n '^library(\|requireNamespace\|knit_exit'` over the six pages shows each of the five pages with a reader-facing chunk (`nested-cv`, `results`, `tuners`, `articles/parallel`, `articles/why-nest`) attaching `library(tidymodels)` then `library(nestedtune)` after a hidden `deps` chunk that names tidymodels and a `deps-notice` chunk that prints one notice naming the missing packages and calls `knitr::knit_exit()`; `estimate.Rmd` has only a hidden setup chunk. Verified.
- AC3: `grep -rn '\$tuning\b' vignettes/` finds nothing. `nested-cv.Rmd` calls `extract_tune_results(final) |> show_best(metric = "rmse", n = 1)` at lines 261–262 inside the shown chunk `comparison` (header at line 260, no `echo`/`include` option). Verified.
- AC4: `collect_selections(res)` at `nested-cv.Rmd:172` in the shown chunk `selected`; `collect_notes(failed)` at `results.Rmd:269` in the shown chunk `failed-notes`, whose `notes` table the shown chunk `completed-notes` filters for a completed fold; `collect_inner_metrics(race) |> filter() |> group_by(id) |> summarise()` at `tuners.Rmd:208` in the shown chunk `race-anova-inner`; `rlang::catch_cnd()` at `results.Rmd:319` (shown chunk `failed-summary-warning`) and `articles/parallel.Rmd:250` (shown chunk `no-dispatcher-warning`). Chunk membership read by an awk pass over the fences. Verified.
- AC6: the sweep's prose check is clean, and an independent pass (`awk` dropping fenced `{r` chunks, `sed -E 's/`r[^`]*`//g'` dropping inline r spans, `grep -nE '—|\bM[0-9][0-9]\b'`) over the six pages finds no line; `grep -ohE 'vignette\("[^"]*"\)'` over the six pages finds only `estimate` (8), `nested-cv` (6), `results` (1) and `tuners` (3). Verified.
- AC5: `Rscript benchmarks/time-vignettes.R <scratch dir>` at load average 6.4 falling to 6.2, with the three review subagents' reads as the only outside work: medians tuners 31.5 s (runs 31.5 / 31.7 / 31.4), results 10.4 s, total of the four medians 47.1 s; against the caps of 45, 60 and 150 s. The pages rendered are 345fd78's (the docs-only checkpoint 6ce7590 landed during the run, so the script's head line names it; no page changed between the two). Verified.
