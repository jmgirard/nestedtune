# M63: A site-only article runs the outer loop on mirai daemons and shows the result identical to the serial run

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** M60
- **Driving RR:** —
- **Principles touched:** IP2
- **Resolves:** —
- **Surface tier:** user-facing — an article on the published site
- **Branch/PR:** m063-parallel-article

## Goal

Ship `vignettes/articles/parallel.Rmd` ("Running the outer loop in parallel"), built by pkgdown alone, which starts two mirai daemons, runs the getting-started guide's loop on them, shows the metrics and selections identical to the serial run, and explains the pre-flight, what crosses the wire, the `load_all()` caveat, interrupting and cancelling, and the dispatcher warning.

## Scope

**In:** the article, its `mirai` and `ranger` guards, its `_pkgdown.yml` entry, and a confirmation that the package tarball excludes it and the pkgdown CI job installs `mirai` and builds it.

**Out:** remote daemon pools (candidate row); mori shared memory (candidate row); the tuner and results pages → M61, M62; a stored precomputed run (the article executes at build; a build without mirai prints a notice); a change to `Config/Needs/website` (a dependency gate, opened only if the CI log shows `mirai` uninstalled).

## Acceptance criteria

- [ ] AC1: `pkgdown::build_article("articles/parallel")` on the development machine with `mirai` and `ranger` installed produces HTML holding executed output from `mirai::daemons(2)`, a `nested_tune_grid()` run on that pool, `mirai::daemons(0)`, and the same run made serially; and the pkgdown CI workflow's run on the branch succeeds with its log naming `mirai` among the installed packages and `parallel.Rmd` among the articles built.
- [ ] AC2: An executed chunk shows `identical()` on the `.metrics`, `.selected` and `.tuning_seed` columns of the parallel and serial results returning `TRUE`, and the prose reads that value inline.
- [ ] AC3: An executed chunk starts a pool with `mirai::daemons(2, dispatcher = FALSE)`, runs the loop under `withCallingHandlers()` and prints the caught condition's class showing `nestedtune_pool_not_cancellable`, then stops the pool.
- [ ] AC4: `R CMD build` of the source tree produces a tarball whose listing (`untar(list = TRUE)`) contains no path under `vignettes/articles/`.
- [ ] AC5: With `mirai` masked from `.libPaths()`, and separately with `ranger` masked, the article prints its notice and exits at `knitr::knit_exit()`, each verified by one masked build.
- [ ] AC6: The citation guard (M60) passes over the article, and the profile's `verify` slot is clean.

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
- [ ] T3: The dispatcher chunk: `daemons(2, dispatcher = FALSE)`, `withCallingHandlers()` capturing the warning, class printed, `daemons(0)` in the same chunk.
- [ ] T4: `_pkgdown.yml` entry under an Articles section; `R CMD build` and `untar(list = TRUE)` for AC4; one masked build each for AC5; push and read the pkgdown job log for AC1; run the guard and the verify slot; after the merge, read the published `articles/parallel.html` for the `daemons(2)` output and log it.

## Work log

- 2026-09-04: created by /milestone-plan.
- 2026-09-04: plan gate chose a live build on the pkgdown job over a stored precomputed run because two daemons on the runner cost about a minute and the numbers then come from an executed chunk as the acceptance bar asks; falsified by the pkgdown job failing or timing out on the daemon start.
- 2026-09-04: criteria audit (full mode, the M60 reader) returned four findings: the `ranger` guard added, AC1's CI half strengthened to the log naming `mirai` installed, the numeral rule's backtick exemption settled in M60, and AC5's masked build given a task (T4).
- 2026-09-04: second audit pass (full mode, a fresh [O] reader) returned one M63 finding, applied: pkgdown names a nested article by its path, so AC1 calls `build_article("articles/parallel")`.
- 2026-09-04: question gate: no executed timings on the page (the example is too small to show a speedup and a runner figure would drift build to build); the article lists under a new `Articles` section in `_pkgdown.yml` below `Guides`, where M64 will join it.
- 2026-09-04: T1: `vignettes/articles/parallel.Rmd` drafted with the mirai+ranger guard (one notice, singular and plural branches, then `knit_exit()`), the pool start printing `status()$connections`, the run, the pool stop, and prose sections for the pre-flight, the wire, the `load_all()` caveat and interrupts drawn from `?nested_tune_grid`; `_pkgdown.yml` gains the `Articles` section (both sections now carry a navbar heading so the menu shows the split); `build_article("articles/parallel")` executed with connections `2` then `0`; citation guard 37 green.
- 2026-09-04: T2: the serial run under `set.seed(2)` and `identical()` on `.metrics`, `.selected` and `.tuning_seed` executed `TRUE` for each, the prose reading `all(same)` inline; the probe also showed `identical()` on the whole objects `TRUE`.
