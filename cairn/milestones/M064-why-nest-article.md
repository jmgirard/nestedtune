# M64: A site-only article repeats a null-data simulation showing tuned-CV optimism and the nested estimate removing it, with nnet in Suggests

- **Status:** planned
- **Priority:** normal
- **Depends on:** M60
- **Driving RR:** —
- **Principles touched:** IP3, GP2
- **Resolves:** —
- **Surface tier:** user-facing — an article on the published site
- **Branch/PR:** —

## Goal

Ship `vignettes/articles/why-nest.Rmd` ("Why nest: a simulation"), built by pkgdown from a stored result that `vignettes/articles/why-nest-sim.R` produces, showing over repeated draws of pure-noise wide data that the best tuned cross-validation score sits above the known 50% accuracy while the nested estimate sits at it.

## Scope

**In:** the script (n rows, p ≫ n Gaussian features, a fair-coin label, a `parsnip::mlp()` on the `nnet` engine tuned over a grid, flat `tune_grid()` best accuracy against `nested_tune_grid()`'s estimate, R replicates, seeded); the stored `vignettes/articles/why-nest.rds` carrying the replicate results, the design, the seed, the null accuracy, a tolerance for the nested median, the commit and the date; the article reading the store; `nnet` in Suggests (D-050); the `_pkgdown.yml` entry.

**Out:** a live build (minutes of fits; the store is the deliverable and the script its provenance); any learner beyond the one the gate chose; the concept page's literature (M60); a test that re-runs the script (too slow; the review re-runs it once).

## Acceptance criteria

- [ ] AC1: `vignettes/articles/why-nest-sim.R` runs from a clean session with the package and `nnet` installed and writes `vignettes/articles/why-nest.rds`; a second run from the same seed writes an object `identical()` to the first once the `date` and `commit` fields are removed from both.
- [ ] AC2: The stored object records `n`, `p`, the grid, the replicate count (at least 20), the seed, the null accuracy, the tolerance, the commit hash and the date it was produced, and the article prints each from the object rather than from prose.
- [ ] AC3: In the stored object, the median over replicates of the flat best-candidate accuracy lies further from the null accuracy than the median nested estimate does, and the median nested estimate lies within the stored tolerance (0.05) of the null accuracy; the article states both medians as inline R over the object.
- [ ] AC4: The built article's figure shows both quantities' distributions across replicates with a reference line at the stored null accuracy and carries a non-empty `fig.alt`.
- [ ] AC5: `pkgdown::build_article("articles/why-nest")` succeeds on the development machine with `nnet` masked from `.libPaths()` (the article reads the store), and `R CMD build`'s tarball listing (`untar(list = TRUE)`) contains no path under `vignettes/articles/`.
- [ ] AC6: `nnet` is in `Suggests`, and the citation guard (M60) passes over the article, its cited sources (at least `varma2006`) each backed by a shelf page.
- [ ] AC7: The profile's `verify` slot is clean and `devtools::check()` reports no error, warning or note beyond those on the default branch.

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3
- AC5 → T4
- AC6 → T4
- AC7 → T4

## Tasks

- [ ] T1: Write the script: the design from the plan gate's probe (n = 60, p = 200, a 20-candidate `hidden_units` × `penalty` grid, `epochs = 50`, `MaxNWts` raised), replicates in a seeded loop, each replicate's flat best accuracy and nested estimate kept, the metadata attached; run it twice for AC1 and log the runtime; if either AC3 condition fails on the store, stop and return to the plan gate through the amendment protocol (raise `p`, the grid or the replicate count) before writing the article.
- [ ] T2: Write the article: the design read from the store, the two medians, the Varma and Simon (2006) design it follows, the caveat that this is one learner on one design; digits in prose as inline R over the store or inside backtick spans.
- [ ] T3: The figure: both distributions on one panel or two, a dashed line at the stored null accuracy, `fig.alt`; render to PNG and look at it before committing (the M08 lesson), and log the file.
- [ ] T4: `nnet` to Suggests; `_pkgdown.yml` entry; `R CMD build` listing; a build with `nnet` masked; the guard, the verify slot and `devtools::check()`.

## Work log

- 2026-09-04: created by /milestone-plan.
- 2026-09-04: plan gate chose a repeated simulation with a neural net over a single run, over ranger alone, and over no page, because two single-run probes showed no effect (ranger) or a 3-point gap inside fold noise (nnet), and a distribution over replicates is what an honest demonstration needs; falsified by the stored replicates showing no gap between the flat best and the nested estimate.
- 2026-09-04: plan gate kept `nnet` in Suggests over no declaration and over `Config/Needs/website`, re-posed after the audit noted the script is build-ignored and the article builds without `nnet`; the user kept Suggests; falsified by a CRAN check flagging an unused Suggests entry.
- 2026-09-04: plan gate chose returning to the gate on a failed AC3 inequality over restating the criterion to whatever direction the store shows, because the page exists to demonstrate the effect and a store that does not show it is not the page; falsified by no affordable design showing the effect.
- 2026-09-04: criteria audit (full mode, the M60 reader) returned seven findings: AC1's `identical()` contradicted AC2's date field (provenance fields excluded), AC1 and AC4 bound verification acts (moved to T1 and T3), AC3's stochastic outcome given the fallback above, D-050 written at plan time, and the null accuracy stored so the article's line and medians read it inline.
- 2026-09-04: second audit pass (full mode, a fresh [O] reader) returned two M64 findings, applied: the nested article's pkgdown name (AC5), and AC3 restated as absolute distances from the null with the nested median held within a stored tolerance, since the old inequality was satisfied by a nested median far below the null.
