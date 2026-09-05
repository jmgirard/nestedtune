# M63: A site-only article runs the outer loop on mirai daemons and shows the result identical to the serial run

- **Status:** review
- **Priority:** normal
- **Depends on:** M60
- **Driving RR:** —
- **Principles touched:** IP2
- **Resolves:** —
- **Surface tier:** user-facing — an article on the published site
- **Branch/PR:** m063-parallel-article · https://github.com/tidymodels/nestedtune/pull/73

## Goal

Ship `vignettes/articles/parallel.Rmd` ("Running the outer loop in parallel"), built by pkgdown alone, which starts two mirai daemons, runs the getting-started guide's loop on them, shows the metrics and selections identical to the serial run, and explains the pre-flight, what crosses the wire, the `load_all()` caveat, interrupting and cancelling, and the dispatcher warning.

## Scope

**In:** the article, its `mirai` and `ranger` guards, its `_pkgdown.yml` entry, and a confirmation that the package tarball excludes it and the pkgdown CI job installs `mirai` and builds it.

**Out:** remote daemon pools (candidate row); mori shared memory (candidate row); the tuner and results pages → M61, M62; a stored precomputed run (the article executes at build; a build without mirai prints a notice); a change to `Config/Needs/website` (a dependency gate, opened only if the CI log shows `mirai` uninstalled).

## Acceptance criteria

- [x] AC1: `pkgdown::build_article("articles/parallel")` on the development machine with `mirai` and `ranger` installed produces HTML holding executed output from `mirai::daemons(2)`, a `nested_tune_grid()` run on that pool, `mirai::daemons(0)`, and the same run made serially; and the pkgdown CI workflow's run on the branch succeeds with its log naming `mirai` among the installed packages and `parallel.Rmd` among the articles built.
- [x] AC2: An executed chunk shows `identical()` on the `.metrics`, `.selected` and `.tuning_seed` columns of the parallel and serial results returning `TRUE`, and the prose reads that value inline.
- [x] AC3: An executed chunk starts a pool with `mirai::daemons(2, dispatcher = FALSE)`, runs the loop under `withCallingHandlers()` and prints the caught condition's class showing `nestedtune_pool_not_cancellable`, then stops the pool.
- [x] AC4: `R CMD build` of the source tree produces a tarball whose listing (`untar(list = TRUE)`) contains no path under `vignettes/articles/`.
- [x] AC5: With `mirai` masked from `.libPaths()`, and separately with `ranger` masked, the article prints its notice and exits at `knitr::knit_exit()`, each verified by one masked build.
- [x] AC6: The citation guard (M60) passes over the article, and the profile's `verify` slot is clean.

## Coverage

- AC1 → T1, T4
- AC2 → T2
- AC3 → T3
- AC4 → T4
- AC5 → T1, T4
- AC6 → T4

## Tasks

- [x] T1: Draft the article with the guards (`requireNamespace()` on `mirai` and `ranger` + `knit_exit()`), the pool start, the run, the pool stop, and prose sections for the pre-flight, the wire, the `load_all()` caveat and interrupts drawn from `?nested_tune_grid`'s parallel section as cross-references rather than restatements; digits in prose inside backtick spans or inline R.
- [x] T2: The identity chunk: the serial run under the same seed, `identical()` on the three columns, the inline read.
- [x] T3: The dispatcher chunk: `daemons(2, dispatcher = FALSE)`, `withCallingHandlers()` capturing the warning, class printed, `daemons(0)` in the same chunk.
- [x] T4: `_pkgdown.yml` entry under an Articles section; `R CMD build` and `untar(list = TRUE)` for AC4; one masked build each for AC5; push and read the pkgdown job log for AC1; run the guard and the verify slot; after the merge, read the published `articles/parallel.html` for the `daemons(2)` output and log it.

## Work log

- 2026-09-04: created by /milestone-plan.
- 2026-09-04: plan gate chose a live build on the pkgdown job over a stored precomputed run because two daemons on the runner cost about a minute and the numbers then come from an executed chunk as the acceptance bar asks; falsified by the pkgdown job failing or timing out on the daemon start.
- 2026-09-04: criteria audit (full mode, the M60 reader) returned four findings: the `ranger` guard added, AC1's CI half strengthened to the log naming `mirai` installed, the numeral rule's backtick exemption settled in M60, and AC5's masked build given a task (T4).
- 2026-09-04: second audit pass (full mode, a fresh [O] reader) returned one M63 finding, applied: pkgdown names a nested article by its path, so AC1 calls `build_article("articles/parallel")`.
- 2026-09-04: question gate: no executed timings on the page (the example is too small to show a speedup and a runner figure would drift build to build); the article lists under a new `Articles` section in `_pkgdown.yml` below `Guides`, where M64 will join it.
- 2026-09-04: T1: `vignettes/articles/parallel.Rmd` drafted with the mirai+ranger guard (one notice, singular and plural branches, then `knit_exit()`), the pool start printing `status()$connections`, the run, the pool stop, and prose sections for the pre-flight, the wire, the `load_all()` caveat and interrupts drawn from `?nested_tune_grid`; `_pkgdown.yml` gains the `Articles` section (both sections now carry a navbar heading so the menu shows the split); `build_article("articles/parallel")` executed with connections `2` then `0`; citation guard 37 green.
- 2026-09-04: T2: the serial run under `set.seed(2)` and `identical()` on `.metrics`, `.selected` and `.tuning_seed` executed `TRUE` for each, the prose reading `all(same)` inline; the probe also showed `identical()` on the whole objects `TRUE`.
- 2026-09-04: T3: `daemons(2, dispatcher = FALSE)`, the run under `withCallingHandlers()` muffling the warning, `class()` printed with `nestedtune_pool_not_cancellable` first, `.metrics` identical to the serial run, `daemons(0)` in the same chunk; the message shown through `cli::ansi_strip()` since the raw `conditionMessage()` carried ANSI codes into the HTML.
- 2026-09-04: draft PR #73 opened from implement because no workflow runs on a branch push and `workflow_dispatch` on pkgdown.yaml would deploy the branch site to gh-pages; T4 reads AC1's CI half from the PR's pkgdown job, and review skips `gh pr create` (its resume route d).
- 2026-09-04: T4: `R CMD build --no-build-vignettes` tarball lists 139 paths, none under `vignettes/articles/` (AC4); two masked builds from a symlinked library lacking `mirai` and then `ranger` each print the one notice naming the missing package and exit at `knit_exit()`, HTML text 1,090 chars against 10,152 full (AC5); pkgdown run 33943096826 on PR #73 head 4d925bd succeeded, its log listing `mirai 2.7.2` and `ranger 0.18.0` installed and `Reading vignettes/articles/parallel.Rmd` then `Writing articles/parallel.html` in 32 s (AC1 CI half); `devtools::test()` 7042 pass 0 fail, `pkgdown::check_pkgdown()` clean, citation guard 37 (AC6). The post-merge read of the published page waits for review, since the site deploys only from the default branch.
- 2026-09-04: status → review; tracking commits after the PR push held local per the M50 lesson.

## Review

- 2026-09-04 AC1: `pkgdown::build_article("articles/parallel")` on the development machine (R 4.6, pkgdown 2.2.1, mirai 2.7.2 and ranger 0.18.0 in the user library) wrote `docs/articles/parallel.html` (31,702 bytes) holding executed output: `status()$connections` printing `2` after `daemons(2)`, the printed `par_res` from the pool run, `0` after `daemons(0)`, and the serial run feeding the identity chunk. CI half: pkgdown run 33943096826 on PR #73 head 4d925bd concluded success; its setup-r-dependencies step lists `mirai 2.7.2` and `ranger 0.18.0` installed and the build step logs `Reading vignettes/articles/parallel.Rmd` then `Writing articles/parallel.html`. Verified.
- 2026-09-04 AC2: the identity chunk's executed output reads `metrics TRUE selected TRUE tuning_seed TRUE`, and the prose renders "returns TRUE for each" from the inline `r all(same)`. Verified.
- 2026-09-04 AC3: one executed chunk starts `mirai::daemons(2, dispatcher = FALSE)`, runs the loop under `withCallingHandlers()`, prints `class(caught)` with `nestedtune_pool_not_cancellable` first, shows `identical(nd_res$.metrics, ser_res$.metrics)` `TRUE`, and ends with `mirai::daemons(0)`; the following chunk prints the stripped message. Verified.
- 2026-09-04 AC4: `R CMD build --no-build-vignettes --no-manual` on the source tree; `untar(list = TRUE)` lists 139 paths, 0 under `vignettes/articles/`, the vignette entries being the four shipped vignettes. Verified.
- 2026-09-04 AC5: two symlinked libraries of 196 packages, one lacking mirai and one lacking ranger, each with `requireNamespace()` returning `FALSE` in the build process; each `build_article()` wrote the notice naming the missing package ("The mirai package is not installed here" / "The ranger package is not installed here") followed by nothing but the site footer, page text 1,619 and 1,620 characters against 11,016 for the full build. Verified.
- 2026-09-04 AC6: `test-vignette-citations.R` run on its own, 37 expectations green over the article; `devtools::test()` (SummaryReporter, max_reports Inf) finished with no failure block, exit 0; `devtools::check(document = FALSE)` 0 errors, 0 warnings, 0 notes in 7m17s. Verified.
- 2026-09-04 gate: `cairn_validate.py` exit 0 (references staleness advisory, 18 pages, not a gate failure); no principle changed so `cairn_impact` skipped; `devtools::document()` leaves no diff; README.Rmd and README.md share commit 2aac24a; `pkgdown::check_pkgdown()` no problems; NEWS.md carries the article entry with no milestone number; no new top-level file, so `.Rbuildignore` unchanged; full check clean as under AC6.
- 2026-09-04 review lenses: [S] blame-history no findings; [S] prior-review no findings (the probe found one real inline comment, topepo on PR #30's workflow YAML, unrelated to these files); [O] diff-bug twelve findings, ranked, dispositioned below.
- 2026-09-04 O1 fix now: the no-dispatcher chunk's handler caught every warning and kept the last, so a later warning could replace the one the page prints and a run with none would error at `conditionMessage(NULL)`; the handler is now keyed on `nestedtune_pool_not_cancellable`.
- 2026-09-04 O2 fix now: "the daemons cannot see it, so the pre-flight stops the call" overclaimed, since with a matching installed copy the run proceeds on it; reworded to stop only with no installed copy.
- 2026-09-04 O3 fix now: "here ranger" understated `needed_pkgs()`, which returns parsnip, ranger and workflows for this workflow; the prose names all three.
- 2026-09-04 O4 fix now: "The two results are the same object" replaced by "identical", which is what the chunk shows.
- 2026-09-04 O5 fix now: the payload sentence listed the workflow, grid and tuner settings and omitted the fold's seeds, against `nested_loop()`'s payload of split, inner and seeds; reworded.
- 2026-09-04 O9 fix now: "Two objects this does not reach are yours rather than the package's" reworded to the roxygen's sentence.
- 2026-09-04 O6 reject: pkgdown emits a `dropdown-divider` before every dropdown header, the first included, so the leading divider is its rendering of the two-heading layout the question gate chose; flipping Guides back to `navbar: ~` is a one-line edit if the maintainer prefers the headerless first group.
- 2026-09-04 O7 reject: the inline `r all(same)` is the read AC2 asks for, and a `FALSE` would show in the chunk output directly above it as a package defect, not a prose one.
- 2026-09-04 O8 reject: the guard exists for a build machine lacking the package (the M06 lesson), not for version drift; the pkgdown job installs from DESCRIPTION's floors, and the four vignettes' guards share the shape.
- 2026-09-04 O10 reject: the page is a site-only article, not a vignette, so `vignette("articles/parallel")` would not resolve; the path is pkgdown's name for it.
- 2026-09-04 O11 reject: the introduction names the demonstration's pool; the dispatcher-less pool is introduced in the section that uses it.
- 2026-09-04 O12 noted: AC6 was unticked pending the verify slot, ticked above.
- 2026-09-04 re-verification after the fix-nows: `build_article()` rebuilt clean, connections `2` then `0`, identity `TRUE TRUE TRUE` with "returns TRUE for each" inline, `class(caught)` unchanged with `nestedtune_pool_not_cancellable` first and `.metrics` identical (AC1 local half, AC2, AC3); both masked builds print the one notice, 1,619 and 1,620 characters (AC5); citation guard 37 green and no digit in prose outside a backtick span (AC6 guard half); AC4 unaffected (no file under `vignettes/articles/` reaches the tarball regardless of content). AC1's CI half is re-read on the pushed head before the merge, since the article changed after run 33943096826.
- 2026-09-04 return floor: no actioned finding shows a criterion failing; no status change.
