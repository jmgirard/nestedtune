# M64: A site-only article repeats a null-data simulation showing tuned-CV optimism and the nested estimate removing it

- **Status:** review
- **Priority:** normal
- **Depends on:** M60
- **Driving RR:** —
- **Principles touched:** IP3, GP2
- **Resolves:** —
- **Surface tier:** user-facing — an article on the published site
- **Branch/PR:** m064-why-nest-article · https://github.com/tidymodels/nestedtune/pull/74

## Goal

Ship `vignettes/articles/why-nest.Rmd` ("Why nest: a simulation"), built by pkgdown from a stored result that `vignettes/articles/why-nest-sim.R` produces, showing over repeated draws of pure-noise wide data that the best tuned cross-validation score sits above the known 50% accuracy while the nested estimate sits at it.

## Scope

**In:** the script (n rows, p ≫ n Gaussian features, a fair-coin label, a `parsnip::mlp()` on the `nnet` engine tuned over a grid, flat `tune_grid()` best accuracy against `nested_tune_grid()`'s estimate, R replicates, seeded); the stored `vignettes/articles/why-nest.rds` carrying the replicate results, the design, the seed, the null accuracy, a tolerance for the nested median, the commit and the date; the article reading the store; the `_pkgdown.yml` entry; no `nnet` declaration in DESCRIPTION (D-051).

**Out:** a live build (minutes of fits; the store is the deliverable and the script its provenance); any learner beyond the one the gate chose; the concept page's literature (M60); a test that re-runs the script (too slow; the review re-runs it once).

## Acceptance criteria

- [ ] AC1: `vignettes/articles/why-nest-sim.R` runs from a clean session with the package and `nnet` installed and writes `vignettes/articles/why-nest.rds`; a second run from the same seed writes an object `identical()` to the first once the `date` and `commit` fields are removed from both.
- [x] AC2: The stored object records `n`, `p`, the grid, the replicate count (at least 20), the seed, the null accuracy, the tolerance, the commit hash and the date it was produced, and the article prints each from the object rather than from prose.
- [x] AC3: In the stored object, the median over replicates of the flat best-candidate accuracy lies further from the null accuracy than the median nested estimate does, and the median nested estimate lies within the stored tolerance (0.05) of the null accuracy; the article states both medians as inline R over the object.
- [x] AC4: The built article's figure shows both quantities' distributions across replicates with a reference line at the stored null accuracy and carries a non-empty `fig.alt`.
- [x] AC5: `pkgdown::build_article("articles/why-nest")` succeeds on the development machine, and a fresh-process `rmarkdown::render()` of `vignettes/articles/why-nest.Rmd`, evaluating its chunks in that process rather than a child session, succeeds with `nnet`, `tune` and `nestedtune` all absent from `loadedNamespaces()` in that same process after the render returns.
- [x] AC6: The article cites Varma and Simon (2006) and lists it under `## References`, and the citation guard (M60) runs over the article from the source tree, not skipped, and passes, every entry the article lists backed by a shelf page.
- [x] AC7: The profile's `verify` slot is clean and `devtools::check()` reports no error, warning or note beyond those on the default branch.
- [x] AC8: `R CMD build`'s tarball listing (`untar(list = TRUE)`) contains no path under `vignettes/articles/`.

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3
- AC5 → T4
- AC6 → T4
- AC7 → T4
- AC8 → T4

## Tasks

- [x] T1: Write the script: the design from the plan gate's probe (n = 60, p = 200, a 20-candidate `hidden_units` × `penalty` grid, `epochs = 50`, `MaxNWts` raised), replicates in a seeded loop, each replicate's flat best accuracy and nested estimate kept, the metadata attached; run it twice for AC1 and log the runtime; if either AC3 condition fails on the store, stop and return to the plan gate through the amendment protocol (raise `p`, the grid or the replicate count) before writing the article.
- [x] T2: Write the article: the design read from the store, the two medians, the Varma and Simon (2006) design it follows, the caveat that this is one learner on one design; digits in prose as inline R over the store or inside backtick spans.
- [x] T3: The figure: both distributions on one panel or two, a dashed line at the stored null accuracy, `fig.alt`; render to PNG and look at it before committing (the M08 lesson), and log the file.
- [x] T4: `_pkgdown.yml` entry; `R CMD build` listing; the fresh-process render check (`Rscript -e 'rmarkdown::render("vignettes/articles/why-nest.Rmd", output_dir = tempdir(), quiet = TRUE); print(c("nnet", "tune", "nestedtune") %in% loadedNamespaces())'`, three `FALSE` logged); the guard run from the source tree, the verify slot and `devtools::check()`.

## Work log

- 2026-09-04: created by /milestone-plan.
- 2026-09-04: plan gate chose a repeated simulation with a neural net over a single run, over ranger alone, and over no page, because two single-run probes showed no effect (ranger) or a 3-point gap inside fold noise (nnet), and a distribution over replicates is what an honest demonstration needs; falsified by the stored replicates showing no gap between the flat best and the nested estimate.
- 2026-09-04: plan gate kept `nnet` in Suggests over no declaration and over `Config/Needs/website`, re-posed after the audit noted the script is build-ignored and the article builds without `nnet`; the user kept Suggests; falsified by a CRAN check flagging an unused Suggests entry.
- 2026-09-04: plan gate chose returning to the gate on a failed AC3 inequality over restating the criterion to whatever direction the store shows, because the page exists to demonstrate the effect and a store that does not show it is not the page; falsified by no affordable design showing the effect.
- 2026-09-04: criteria audit (full mode, the M60 reader) returned seven findings: AC1's `identical()` contradicted AC2's date field (provenance fields excluded), AC1 and AC4 bound verification acts (moved to T1 and T3), AC3's stochastic outcome given the fallback above, D-050 written at plan time, and the null accuracy stored so the article's line and medians read it inline.
- 2026-09-04: second audit pass (full mode, a fresh [O] reader) returned two M64 findings, applied: the nested article's pkgdown name (AC5), and AC3 restated as absolute distances from the null with the nested median held within a stored tolerance, since the old inequality was satisfied by a nested median far below the null.
- 2026-09-05: implement started; branch `m064-why-nest-article`. Gate chose 30 replicates (one replicate 80 s serially, so about 40 min a run) and a one-panel figure of paired points with median bars. T1 script written and run 1 in progress; the article draft, `nnet` in Suggests, the `_pkgdown.yml` entry and the NEWS entry written, none yet verified against a store. Checkpoint, half-done.
- 2026-09-05: run 1 (script as committed at 734d2eb) wrote the store in 4108 s: median flat best 0.567, median nested 0.458, both AC3 conditions holding (0.067 above the null against 0.042 below, inside the 0.05 tolerance). Script reformatted by air and its top-level `on.exit()` dropped (inert in Rscript, the M09 lesson); run 2 started on that script. Article reworded for the nested median sitting below the null; `pkgdown::build_article()` builds it and the figure was rendered and read.
- 2026-09-05: AC5's masked build is unsatisfiable: nnet is a recommended package in the system library, unmaskable from `.libPaths()`, and a stub mask shows it in the hard import closure (tune → recipes → ipred → nnet), so `library(nestedtune)` fails and pkgdown's autolinker fails resolving `tune::tune_grid()`; a fresh-process `rmarkdown::render()` of the article loads neither nnet, tune nor nestedtune. Mini gate offered replacing the clause with that render check; the user chose escalation. Blocked on RB06.
- 2026-09-05: RR06 received (advisory, no binding criteria) and ingested. Gate adopted its AC5 rewording, split the tarball listing into AC8 mapped to T4, and removed `nnet` from Suggests by D-051 superseding D-050; the title, Scope In, AC6, T4, NEWS and DESCRIPTION amended together. AC1 unchanged (the script still needs `nnet`).
- 2026-09-05: re-audit: AC5 (full) — the process evaluating `loadedNamespaces()` was unstated and the trailing "since" clause read as an unenumerated universal; both fixed.
- 2026-09-05: re-audit: AC6 (full) — the wording was satisfied by the shelf page existing without the article citing it; fixed to require the citation and the listing.
- 2026-09-05: re-audit: AC8 (full) — nothing.
- 2026-09-05: re-audit: AC5 (full) — a render farming chunks to a child session would pass vacuously; fixed by pinning chunk evaluation to the same process. Second line, the stop: further churn goes to the user.
- 2026-09-05: re-audit: AC6 (full) — the real-tree guard skips under `R CMD check`, so a skip could be read as a pass; fixed by requiring the source-tree run. Second line, the stop.
- 2026-09-05: gate chose the second reader's tightened AC5 and AC6 over the first-audit wording. RB06/RR06 archived; status back to in-progress.
- 2026-09-05: run 2 (script as committed at c51349b, store's commit field 3d715b6) wrote the store; `identical()` to run 1's store once `date` and `commit` are removed from both, so AC1 holds and T1 is done; run 2's store committed. T2 checked against the store: every design figure, both medians, the distances, the commit and the date read inline from the object; the prose-digit sweep finds only citation years. T3: `pkgdown::build_article()` rendered the figure (`docs/articles/why-nest_files/figure-html/figure-1.png`), read: flat column above the dashed null line with its median bar at 0.567, nested column straddling below with its bar at 0.458; the built page carries the `fig.alt`. T4 so far: the fresh-process render printed `FALSE FALSE FALSE`; the source-tree guard ran 37 expectations with no skip; the tarball lists 139 entries, none under `vignettes/articles/`; verify slot and `check()` running.
- 2026-09-05: T4 done: `devtools::test()` clean (no failure, no skip) and `devtools::check()` 0 errors, 0 warnings, 0 notes in 7 min on the branch, so nothing to compare against the default branch; the `_pkgdown.yml` entry stood from the first checkpoint. All tasks checked; status review.

## Decisions

- 2026-09-05 (RR06 Q1, Q4): AC5 certifies the article's independence by a fresh-process render leaving `nnet`, `tune` and `nestedtune` unloaded, naming all three so the check does not rest on ipred's import of nnet; the tarball listing is its own criterion, as M63's was. Rejected: naming `nnet` alone (passes by an upstream accident); dropping the clause (certifies nothing about dependence); a static grep of the chunks (cannot see a transitive load).
- 2026-09-05 (RR06 Q2): a repeatable measurement whose outcome is the criterion stays in the criterion with its instrument named; the command and its printed output go in T4 and the review evidence; the ipred mechanism goes to a lesson, not a criterion.
- 2026-09-05 (RR06 Q5): the original AC5 is not ticked under any reading: a stub package is not "masked from `.libPaths()`", and under it "succeeds" is false.
- 2026-09-05 (RR06 beyond the brief): a LESSONS line on checking an Import's recursive closure and a package's `Priority` before writing a masking or skip-on-absence criterion is scheduled for the review's post-merge hygiene, as the third instance after M61 (dials) and M57 (tibble), to be merged into the M06 line. The pkgdown job renders from the committed store, so the review evidence records the commit the store's `commit` field names.

## Review

- 2026-09-05: step 1: origin/main (69db830) is an ancestor of the branch head; nothing to merge. Step 2: draft PR #74 opened.
- AC2 evidence (2026-09-05): `readRDS()` of the committed store lists `n` 60, `p` 200, a 20-row `grid`, `replicates` 30, `seed` 20260905, `null_accuracy` 0.5, `tolerance` 0.05, `commit` 3d715b6d…, `date` 2026-09-05; the built page (`pkgdown::build_article()`) prints each of these from the object, the commit hash, date and seed found in the HTML. Holds.
- AC3 evidence (2026-09-05): from the store, median flat best 0.5667 and median nested 0.4583; distances from the null 0.0667 against 0.0417, the flat further; 0.0417 inside the 0.05 tolerance. The article states both medians as inline R over the object (`round(flat_median, 3)`, `round(nested_median, 3)`), the built page showing 0.567 and 0.458. Holds.
- AC4 evidence (2026-09-05): `docs/articles/why-nest_files/figure-html/figure-1.png` rendered by the build and read: one panel, two columns of jittered points, a median crossbar on each, a dashed horizontal line at 0.5; the built HTML carries the chunk's non-empty `fig.alt` as the image's `alt`. Holds.
- AC5 evidence (2026-09-05): `pkgdown::build_article("articles/why-nest")` exited 0 and wrote `docs/articles/why-nest.html`; the fresh-process `Rscript -e 'rmarkdown::render(...); print(c("nnet","tune","nestedtune") %in% loadedNamespaces())'` (default in-process knit, no child session) printed `FALSE FALSE FALSE`. Holds.
- AC6 evidence (2026-09-05): the article cites Varma and Simon (2006) in four paragraphs and lists it under `## References` beside Ambroise and McLachlan (2002); `devtools::test(filter = "vignette-citations")` from the source tree ran 37 expectations, all passing, no skip; both entries have shelf pages (`cairn/references/varma2006.md`, `ambroise2002.md`). Holds.
- AC8 evidence (2026-09-05): `R CMD build --no-build-vignettes` of the branch; `untar(list = TRUE)` lists 139 entries, none under `vignettes/articles/`; the four CRAN vignettes are the only `vignettes/` paths. Holds.
- Consistency gate (2026-09-05): `cairn_validate.py` exit 0, all checks PASS, advisories only (sizing tripwire on M064's 8 criteria, references staleness on 18 shelf pages, both pre-existing); no DESIGN.md principle changed, `cairn_impact` skipped; `devtools::document()` no diff; `pkgdown::check_pkgdown()` no problems; README.md and README.Rmd last changed in the same commit; NEWS carries the article's entry with no milestone number; no new top-level file.
- 2026-09-05: review step 3 in progress: AC2–AC6 and AC8 evidenced and ticked; AC1 (a third script run in a scratch dir), AC7 (`check()` and `test()`) and the three review lenses running. Checkpoint, half-done.
- AC7 evidence (2026-09-05): `devtools::test()` on the branch clean (no failure, no skip, exit 0); `devtools::check()` 0 errors, 0 warnings, 0 notes, so nothing beyond the default branch. Holds.
- Step 5 reviewers (2026-09-05): [O] diff-bug 17 findings; [S] blame-history 2 notes, no defect; [S] prior-review record "no prior-review evidence", 0 findings (the one real GitHub thread is topepo's on PR #30, an untouched file). Dispositions below were applied on the branch before the gate and stand for the maintainer's acceptance or reversal there.
- O1 (fix now): the article said the nested estimate varies more because each outer fold is scored on 12 rows; the flat run's folds are the same size, so the clause could not explain the gap. Removed; the two standard deviations are stated without a cause.
- O2 (fix now): the paragraph explaining the below-null nested median (training rows leaning one way, assessment rows the other; "shrinks as the folds grow") was composed, not derived, and wrong for independently drawn labels. Rewritten from the store: with every label an independent coin toss the nested expectation is the null, the mean is 0.485, 0.015 below against a standard error of 0.016, the median landing where the draws put it.
- O3 (fix now): the page asserted and then denied the nested expectation; O2's rewrite removes the contradiction.
- O4 (fix now): "no signal for a smaller training set to lose" contradicted `varma2006.md`'s +4.2 null residual; replaced by the iid-label argument beside Varma and Simon's fixed class counts and their 4.2-point pessimistic nested estimate.
- O5 (fix now): the `1 − (1/2)^K` sentence now states the independence premise, that the shared folds break it, and prints the chance as one in `2^K` (1,048,576) rather than a rounded probability.
- O6 (fix now): the script stops when `show_best()$n != v_outer` or any outer fold's `.completed` is FALSE, so a dropped fold can no longer be stored as a full design (IP4); store regenerated (run 4).
- O7 (fix now): the script reads the commit before the run and appends `-dirty` on a non-clean tree; the provenance paragraph says the commit is one on the branch that added the page, reachable through the pull request; store regenerated from the committed script.
- O8 (fix now): the reproducibility sentence is limited to one machine and one set of package versions.
- O9 (fix now): the flat distance takes `abs()` and a below/above switch like the nested one.
- O10 (fix now): folded into O5; `format(2^K, big.mark = ",")` is exact for any grid size.
- O11 (fix now): "each run drawing its own fold assignment" added.
- O12 (fix now): Ambroise and McLachlan (2002) described as feature selection rather than tuning.
- O13 (fix now): replicate counts given as above / at / below the truth (flat 25 / 3 / 2, nested 11 / 1 / 18).
- O14 (fix now in part): `MaxNWts` added to the design table; the `v_outer` coupling rejected, the script and page being versioned together and the store's field being the flat run's fold count by construction.
- O15 (reject): the script does not assert serial execution; IP2 promises worker-count invariance and each replicate seeds on entry.
- O16 (fix now): the 93-character line was inside the paragraph O2 rewrote.
- O17 (fix now): `position_jitter(seed = sim$seed)` replaces `set.seed()` before the plot; `fun.min` and `fun.max` set explicitly on the crossbar.
- B1 (follow-up, already scheduled): the LESSONS line on an Import's recursive closure and `Priority` lands at post-merge hygiene, per the Decisions section.
- B2 (reject): D-024 and D-025's "(D-050)" predates this branch and cites the cairn plugin's release-timing decision, as tracking-rules does; no collision in this repo's numbering.
- Re-verification after the fixes (2026-09-05): `pkgdown::build_article()` exit 0; the figure re-rendered and read (same layout, points re-jittered); the fresh-process render printed `FALSE FALSE FALSE`; the guard ran 37 expectations, no skip; the script parses and `air format` is clean. AC2 and AC3 to be re-read against run 4's store.
