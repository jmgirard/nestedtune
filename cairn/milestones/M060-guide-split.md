# M60: The guide splits into a getting-started path and a page on what the estimate means, and the citation guard sweeps every page under vignettes/

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3
- **Resolves:** —
- **Surface tier:** user-facing — two vignettes shipped in the package and on the site
- **Branch/PR:** m060-guide-split

## Goal

Split `vignettes/nested-cv.Rmd` into a short getting-started guide that walks the design → loop → report → final-fit → reproducibility → write-up path and a code-free concept page carrying the M25 material on what the estimate means, and make the citation guard read every page under `vignettes/` rather than one hardwired path.

## Scope

**In:** `vignettes/nested-cv.Rmd` trimmed to the working path, keeping its title, its `VignetteIndexEntry`, its `ranger` guard and a shortened Reproducibility section; a new `vignettes/estimate.Rmd` ("What the estimate means") holding the estimand, the pessimism and `std_err` material, the no-comparison warning, the disagreement mechanism, "When this is worth the cost", the feature-selection caveat and the References; `tests/testthat/test-vignette-citations.R` sweeping every `.Rmd` under `vignettes/` recursively, with a per-page References rule and a new prose-numeral rule (AC4); the `_pkgdown.yml` articles index and the README links; `^vignettes/articles$` in `.Rbuildignore` so M63 and M64 land without touching the build ignore; a measured vignette build time.

**Out:** the tuner page → M61; the results page → M62; the parallel article → M63; the wide-data simulation → M64; any new cited source (a page owed to the shelf) → the milestone that cites it; Quarto (D-017).

## Acceptance criteria

- [ ] AC1: `vignettes/nested-cv.Rmd` builds under `R CMD check` with `ranger` installed and, with `ranger` masked from `.libPaths()`, prints its notice and exits at `knitr::knit_exit()`; its built HTML contains executed output for `nested_resamples()`, `nested_tune_grid()`, `collect_metrics()`, `nested_final_fit()`, `predict()`, the RNG-restored check and the write-up block.
- [ ] AC2: `vignettes/estimate.Rmd` builds under `R CMD check` with no executed R code beyond the `setup` chunk (procedure: `knitr::purl()` of the page yields only the setup chunk's lines, and `grep` finds no `` `r `` span in its source), and its `## References` section lists every source the pre-split guide listed (procedure: the guard's `entry_citekey()` set on `git show $(git merge-base main HEAD):vignettes/nested-cv.Rmd` minus the set on the new page is empty).
- [ ] AC3: The citation guard enumerates its pages with `list.files(test_path("..", "..", "vignettes"), pattern = "\\.Rmd$", recursive = TRUE)` and, for every page it finds, every author-year citation in the prose resolves to a shelf page naming that surname and year, and every References entry is cited in that page's prose; a page with no citation and no References section passes; a page with one but not the other fails. Shown red, by test name, on planted fixtures in a temporary directory: a citation with no shelf page, a References entry no prose cites, a References section with no citation, a citation with no References section, and one of these planted in a page one directory deep.
- [ ] AC4: The guard's prose-numeral rule holds on every page it enumerates: after fenced chunks, every backtick-quoted inline span, the YAML header and the `## References` section are removed, every paragraph containing a digit also contains an author-year citation. Shown red on planted fixtures holding an uncited digit in a plain paragraph, in a list item, and in a page one directory deep, and shown green on a fixture whose only digit sits inside a backtick span.
- [ ] AC5: `_pkgdown.yml` lists both pages under Guides, `pkgdown::check_pkgdown()` passes, and `README.md` (rendered from `README.Rmd`) links to both pages by their site URLs.
- [ ] AC6: The combined build time of the package's CRAN vignettes, measured as the median elapsed seconds of three runs of `tools::buildVignettes()` on a temporary copy of the source tree on the development machine, is at most 20 seconds.
- [ ] AC7: The profile's `verify` slot is clean and `devtools::check()` reports no error, warning or note beyond those on the default branch, a URL note for a page the site has not yet deployed counted as not new.

## Coverage

- AC1 → T4, T6
- AC2 → T3
- AC3 → T1, T3, T4
- AC4 → T2, T3, T4
- AC5 → T5
- AC6 → T6
- AC7 → T6

## Tasks

- [x] T1: In `tests/testthat/test-vignette-citations.R`, replace `vignette_file()` with the recursive page list, gated on `skip_if_not(dir.exists(test_path("..", "..", "vignettes")))` so `R CMD check`'s out-of-tree run skips rather than fails; run the References tests per page, allowing a page with neither citations nor References and failing one with either alone; move the fixed-path assertions to fixture-driven tests that plant AC3's five fixtures in `withr::local_tempdir()` and assert red by test name; assert the enumerated page count is greater than one.
- [x] T2: Strip every backtick span before the numeral rule; add the numeral rule; plant AC4's four fixtures and assert red or green by test name.
- [x] T3: Write `vignettes/estimate.Rmd`: move the estimand, pessimism, `std_err`, no-comparison, disagreement-mechanism, "When this is worth the cost", feature-selection and References material out of the guide, rewriting each inline-R number as prose or a cited figure, with a `setup` chunk only; cite each source as the guide did so every entry's shelf page still backs it; every prose digit inside a backtick span or a paragraph carrying a citation.
- [ ] T4: Trim `vignettes/nested-cv.Rmd` to the path in Goal, replacing each moved passage with one sentence and a link to the concept page; keep the `deps`/`deps-notice` guard, the `error = TRUE` refusal chunks, the `autoplot()` figures, a shortened Reproducibility section and the write-up block; every prose digit inside a backtick span or inline R, and a References section kept only if a citation stays; render both `autoplot()` figures to PNG and look at them before committing (the M08 lesson).
- [ ] T5: Add the page to `_pkgdown.yml` under Guides; add `^vignettes/articles$` to `.Rbuildignore`; update `README.Rmd`'s guide paragraph to link both pages and re-render `README.md`; run `pkgdown::check_pkgdown()`.
- [ ] T6: Measure AC6's figure and log it with its date and commit; run the profile's verify slot and `devtools::check()`; build once with `ranger` masked from `.libPaths()` for AC1's notice path.

## Work log

- 2026-09-04: created by /milestone-plan.
- 2026-09-04: plan gate chose splitting the guide before writing new pages over writing the tuner and results pages first because each later page inherits the recursive guard and a slimmer guide to link from; falsified by a later page needing guard behaviour the split did not anticipate.
- 2026-09-04: plan gate chose a code-free concept page over keeping the estimand material beside the worked example because the M25 material is literature, not output, and a page with no run costs the check nothing; falsified by a reader needing the guide's own numbers to follow the concept page.
- 2026-09-04: criteria audit ran in full mode over M60–M64 in one fresh [O] reader; M60 returned twelve findings, ten clear fixes applied (test_path enumeration, subdirectory and no-References fixtures, backtick-span stripping, list-item fixture, purl plus `r`-span check, merge-base pin, logging moved to T5, Reproducibility section kept in the guide, AC1 coverage to T5, the reserved empty directory dropped) and two decided here: the subset relation in AC2 over set equality, and the page-count assertion moved from AC4 to T1.
- 2026-09-04: second audit pass (full mode, a fresh [O] reader) over the reworded criteria returned three M60 findings, all applied: AC3 and AC4 now map to the authoring tasks as well as the guard tasks, the enumerating tests skip out of tree so `R CMD check` stays clean, and the guard task split into T1 and T2.
- 2026-09-04: T1 done: the guard enumerates `vignettes/` recursively, each rule is one `expect_<rule>()` over the page list, and six fixtures in a temp tree with their own one-page shelf show each rule red by `expect_failure()`; the page-count test reads red until T3 adds the second page.
- 2026-09-04: user direction for every vignette on this branch and the ones M61–M64 add: plain sentences, no em dashes, no mannered prose, technical detail stated simply.
- 2026-09-04: T2 done: rule 7 reads the page less YAML, fences, every backtick span and the References section, one unit per paragraph or list item with its marker removed (a `1.` marker is not a claim); three red fixtures and one green fixture with two pages; the existing guide already passes it.
- 2026-09-04: T3 done: `vignettes/estimate.Rmd` written in plain sentences with a setup chunk only (`knitr::purl()` yields that chunk alone, no inline `r` span), the six References entries equal to the pre-split guide's set, every rule of the guard green over both pages, and the page rendered once to HTML.
