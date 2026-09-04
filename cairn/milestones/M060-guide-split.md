# M60: The guide splits into a getting-started path and a page on what the estimate means, and the citation guard sweeps every page under vignettes/

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3
- **Resolves:** —
- **Surface tier:** user-facing — two vignettes shipped in the package and on the site
- **Branch/PR:** m060-guide-split · https://github.com/tidymodels/nestedtune/pull/70

## Goal

Split `vignettes/nested-cv.Rmd` into a short getting-started guide that walks the design → loop → report → final-fit → reproducibility → write-up path and a code-free concept page carrying the M25 material on what the estimate means, and make the citation guard read every page under `vignettes/` rather than one hardwired path.

## Scope

**In:** `vignettes/nested-cv.Rmd` trimmed to the working path, keeping its title, its `VignetteIndexEntry`, its `ranger` guard and a shortened Reproducibility section; a new `vignettes/estimate.Rmd` ("What the estimate means") holding the estimand, the pessimism and `std_err` material, the no-comparison warning, the disagreement mechanism, "When this is worth the cost", the feature-selection caveat and the References; `tests/testthat/test-vignette-citations.R` sweeping every `.Rmd` under `vignettes/` recursively, with a per-page References rule and a new prose-numeral rule (AC4); the `_pkgdown.yml` articles index and the README links; `^vignettes/articles$` in `.Rbuildignore` so M63 and M64 land without touching the build ignore; a measured vignette build time.

**Out:** the tuner page → M61; the results page → M62; the parallel article → M63; the wide-data simulation → M64; any new cited source (a page owed to the shelf) → the milestone that cites it; Quarto (D-017).

## Acceptance criteria

- [x] AC1: `vignettes/nested-cv.Rmd` builds under `R CMD check` with `ranger` installed and, with `ranger` masked from `.libPaths()`, prints its notice and exits at `knitr::knit_exit()`; its built HTML contains executed output for `nested_resamples()`, `nested_tune_grid()`, `collect_metrics()`, `nested_final_fit()`, `predict()`, the RNG-restored check and the write-up block.
- [x] AC2: `vignettes/estimate.Rmd` builds under `R CMD check` with no executed R code beyond the `setup` chunk (procedure: `knitr::purl()` of the page yields only the setup chunk's lines, and `grep` finds no `` `r `` span in its source), and its `## References` section lists every source the pre-split guide listed (procedure: the guard's `entry_citekey()` set on `git show $(git merge-base main HEAD):vignettes/nested-cv.Rmd` minus the set on the new page is empty).
- [x] AC3: The citation guard enumerates its pages with `list.files(test_path("..", "..", "vignettes"), pattern = "\\.Rmd$", recursive = TRUE)` and, for every page it finds, every author-year citation in the prose resolves to a shelf page naming that surname and year, and every References entry is cited in that page's prose; a page with no citation and no References section passes; a page with one but not the other fails. Shown red, by test name, on planted fixtures in a temporary directory: a citation with no shelf page, a References entry no prose cites, a References section with no citation, a citation with no References section, and one of these planted in a page one directory deep.
- [x] AC4: The guard's prose-numeral rule holds on every page it enumerates: after fenced chunks, every backtick-quoted inline span, the YAML header and the `## References` section are removed, every paragraph containing a digit also contains an author-year citation. Shown red on planted fixtures holding an uncited digit in a plain paragraph, in a list item, and in a page one directory deep, and shown green on a fixture whose only digit sits inside a backtick span.
- [x] AC5: `_pkgdown.yml` lists both pages under Guides, `pkgdown::check_pkgdown()` passes, and `README.md` (rendered from `README.Rmd`) links to both pages by their site URLs.
- [x] AC6: The combined build time of the package's CRAN vignettes, measured as the median elapsed seconds of three runs of `tools::buildVignettes()` on a temporary copy of the source tree on the development machine, is at most 20 seconds.
- [x] AC7: The profile's `verify` slot is clean and `devtools::check()` reports no error, warning or note beyond those on the default branch, a URL note for a page the site has not yet deployed counted as not new.

## Coverage

- AC1 → T4, T6
- AC2 → T3
- AC3 → T1, T3, T4
- AC4 → T2, T3, T4
- AC5 → T5
- AC6 → T6
- AC7 → T6

## Tasks

- [x] T1: In `tests/testthat/test-vignette-citations.R`, replace `vignette_file()` with the recursive page list, gated on `skip_if_not(dir.exists(test_path("..", "..", "vignettes")))` so `R CMD check`'s out-of-tree run skips rather than fails; run the References tests per page, allowing a page with neither citations nor References and failing one with either alone; move the fixed-path assertions to fixture-driven tests that plant AC3's five fixtures in a temporary directory and assert red by test name; assert the enumerated page count is greater than one.
- [x] T2: Strip every backtick span before the numeral rule; add the numeral rule; plant AC4's four fixtures and assert red or green by test name.
- [x] T3: Write `vignettes/estimate.Rmd`: move the estimand, pessimism, `std_err`, no-comparison, disagreement-mechanism, "When this is worth the cost", feature-selection and References material out of the guide, rewriting each inline-R number as prose or a cited figure, with a `setup` chunk only; cite each source as the guide did so every entry's shelf page still backs it; every prose digit inside a backtick span or a paragraph carrying a citation.
- [x] T4: Trim `vignettes/nested-cv.Rmd` to the path in Goal, replacing each moved passage with one sentence and a link to the concept page; keep the `deps`/`deps-notice` guard, the `error = TRUE` refusal chunks, the `autoplot()` figures, a shortened Reproducibility section and the write-up block; every prose digit inside a backtick span or inline R, and a References section kept only if a citation stays; render both `autoplot()` figures to PNG and look at them before committing (the M08 lesson).
- [x] T5: Add the page to `_pkgdown.yml` under Guides; add `^vignettes/articles$` to `.Rbuildignore`; update `README.Rmd`'s guide paragraph to link both pages and re-render `README.md`; run `pkgdown::check_pkgdown()`.
- [x] T6: Measure AC6's figure and log it with its date and commit; run the profile's verify slot and `devtools::check()`; build once with `ranger` masked from `.libPaths()` for AC1's notice path.

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
- 2026-09-04: T4 done: the guide keeps design, grid, loop, report, fold choices with both `autoplot()` figures, final fit with the comparison and the two refusals, a shortened Reproducibility section (the `args()` chunk dropped) and the write-up; each moved passage is one paragraph plus a `vignette("estimate")` link, no citation and no References section remain, no em dash remains, the guard is green, and both figures were rendered to PNG and looked at (subtitles fit, integer breaks).
- 2026-09-04: T5 done: `estimate` listed under Guides, `^vignettes/articles$` in `.Rbuildignore`, README.Rmd links both pages by site URL and README.md re-rendered (its code output unchanged), `pkgdown::check_pkgdown()` reports no problems.
- 2026-09-04: T6 in progress: build time measured at commit 78e3868 as elapsed 5.8, 4.8, 4.8 s over three `tools::buildVignettes()` runs on a temp copy (median 4.8 s, AC6's cap 20 s); with ranger masked from `.libPaths()` the guide printed its notice and stopped at `knit_exit()` (no design section in the HTML); the built guide HTML holds every executed output AC1 names; `devtools::test()` clean; the first `devtools::check()` returned one WARNING, `withr::` undeclared in tests, so the fixture tempdir moved to base `tempfile()` with a caller-frame `on.exit()` (withr is deliberately not a dependency); NEWS entry added; the second check is running.
- 2026-09-04: T6 done: the second `devtools::check()` is clean (0 errors, 0 warnings, 0 notes, 4m57s); all tasks checked, status to review.
- 2026-09-04: review checkpoint: PR #70 opened as draft, AC1–AC5 verified and ticked; AC6, AC7, the reviewer fan-out and the gate still pending.
- 2026-09-04: review: AC6 and AC7 verified at head, consistency gate clean, three-lens review returned nine findings, five fixed on the branch (numeral YAML fixture, empty References rule and `seq_len()` fix, "linear" dropped, `res` introduced, guide section retitled), one resolved by the evidence, two rejected, one (the dropped `args()` chunk) put to the gate.
- 2026-09-04: step-7 approval: PR #70 approved for merge; S1 rejected with reason at the gate.

## Review

- 2026-09-04 PR #70 opened as draft at 560fd0d; origin/main unchanged since the branch was cut (0 commits behind).
- AC1: `rmarkdown::render()` of the guide at 560fd0d with ranger installed completed; the rendered text holds the executed output of `nested_resamples()` (the design print), `nested_tune_grid()` (the results print), `collect_metrics(res)` (the two-row metrics tibble), `nested_final_fit()` (the final-fit print), `predict(final, ...)` (three `.pred` rows), the RNG-restored check (`#> [1] TRUE`) and the write-up block (the "Hyperparameters (mtry, min_n) were tuned ..." paragraph). With ranger masked from `.libPaths()` (a symlinked library omitting ranger; `requireNamespace("ranger")` FALSE) the built page is 14 lines of text ending at the notice, with no design section. Build under `R CMD check`: the `devtools::check()` run recorded under AC7. PASS.
- AC2: `knitr::purl()` of `vignettes/estimate.Rmd` yields the `setup` chunk's five lines and nothing else; `grep -c '`r '` on the source is 0. The guard's `entry_citekey()` set over `git show $(git merge-base main HEAD):vignettes/nested-cv.Rmd` is {bayle2026, luo2026, tibshirani2009, vabalas2019, varma2006, wilimitis2023}; the set over the new page is the same six; the difference is empty. Build under `R CMD check`: the AC7 run. PASS.
- AC3: `vignette_pages(vignettes_dir())` composes to `list.files(test_path("..", "..", "vignettes"), pattern = "\\.Rmd$", recursive = TRUE)` verbatim (`tests/testthat/test-vignette-citations.R`). `testthat::test_file()` on the guard: 20 tests, 33 expectations, 0 failures, 0 skips. The real-tree tests pass over both pages (citations listed, entries parse, entries backed by a shelf page naming surname and year, entries cited). The neither-case passes in "a page citing and listing a backed source, and a page with neither, pass every rule"; each of AC3's five fixtures is shown red by `expect_failure()` in its own test: "a citation with no shelf page turns the shelf rule red", "a References entry no prose cites turns the cited rule red", "a References section with no citation turns the cited rule red", "a citation with no References section turns the listed rule red", "a defect one directory deep is found by the same rule" (`deeper/cited-only.Rmd`). PASS.
- AC4: the real-tree test "every paragraph with a digit in a page's prose carries a citation" passes over both pages; `numeral_prose()` strips YAML, fences, every backtick span and the References section before `numeral_units()` splits paragraphs and list items. Red fixtures by test name: "an uncited digit in a plain paragraph turns the numeral rule red", "an uncited digit in a list item turns the numeral rule red", "an uncited digit one directory deep turns the numeral rule red"; green: "a digit inside a backtick span, or beside a citation, passes the numeral rule". PASS.
- AC5: `_pkgdown.yml` Guides lists `nested-cv` and `estimate`; `pkgdown::check_pkgdown()` reports "No problems found"; `README.md` carries both site URLs (`/articles/nested-cv.html`, `/articles/estimate.html`); `devtools::build_readme()` re-run leaves README.md unchanged. PASS.
- AC6: at 4310946, three `tools::buildVignettes()` runs on a temp copy of the source tree (DESCRIPTION, NAMESPACE, R/, man/, vignettes/) took 6.5, 5.5 and 5.5 s elapsed; median 5.5 s against the 20 s cap. PASS.
- AC7: `devtools::document()` leaves no diff; `devtools::test()` at 4310946 is clean (no failures, the guard file's 33 expectations included); `devtools::check()` at 560fd0d (the same code, 4310946 adds tracking only) reports 0 errors, 0 warnings, 0 notes in 5m27s, so nothing beyond the default branch's clean check. PASS.
- Consistency gate: `cairn_validate.py` exit 0 (18 references-staleness advisories, pre-existing); no DESIGN.md principle changed, so `cairn_impact.py` skipped; `pkgdown::check_pkgdown()` clean; README.md in sync with README.Rmd; NEWS.md carries the split entry with no milestone number; no new top-level file, `^vignettes/articles$` added to `.Rbuildignore`; `air format --check` clean on the test file.
- Independent review (user-facing tier, three lenses): [O] diff-bug 8 findings, [S] blame-history 1 finding, [S] prior-review-record none (archives M06, M08, M17, M25, M30, M35, M53, M55–M57 read; the GitHub probe found human threads only on PR #30's workflow files). Dispositions:
- O1 (numeral fixtures leave the YAML strip unexercised; the References strip was already covered by the green cited fixture, so the finding is partly refuted): fix now. `plant_page()`'s YAML now carries `date: "2020-01-01"`, so the green numeral fixtures go red if `strip_yaml()` stops running; comment records why.
- O2 (an emptied `## References` section passed every rule, where the pre-split guard asserted entries > 0, and a heading on the last line made `seq()` run backwards): fix now. `page_halves()` indexes with `seq_len()`; new rule 1b `expect_references_nonempty()` with a real-tree test and a red fixture "an emptied References section turns the entries rule red".
- O3 ("linear SVM" on the concept page; `cairn/references/tibshirani2009.md` names no kernel): fix now, "linear" dropped.
- O4 (`res` used on the concept page with no introduction): fix now, the sentence names it as the results object the guide builds.
- O5 (both pages carried `## When this is worth the cost`): fix now, the guide's remnant retitled "Where this example sits"; no link targets that anchor.
- O6 (AC6/AC7 unticked at head): resolved by this review's AC6 and AC7 evidence at head; no change.
- O7 (the real-tree half of the guard runs only under `devtools::test()`): rejected, pre-existing and disclosed in the file header since M25 (the M25 C1 finding), unchanged by this diff.
- O8 (`numeral_units()` merges a paragraph that follows a list item with no blank line): rejected. Markdown reads such a line as a lazy continuation of the item, so the merge matches how the page renders.
- S1 (the "neither function takes a seed of its own" sentence lost its executed `args()` chunk, dropped by the planned Reproducibility trim): decided at the gate, proposed reject with reason: the trim was T4's plan, the sentence carries no number, and the seed contract is documented and tested on both functions' help pages.
- Post-fix re-verification at the fix commit: the guard file 22 tests, 37 expectations, 0 failures; `air format --check` clean; `tools::buildVignettes()` on a temp copy rebuilds both pages in 6 s.
- S1 disposition at the gate: rejected with reason (the planned T4 trim, a sentence with no number, the seed contract documented and tested on both help pages).
- conversation: PR #70 — empty (no reviews, no comments, no unresolved threads at the gate read).
