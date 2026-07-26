# M06: A guide that says what to report

- **Status:** review
- **Priority:** normal
- **Depends on:** M05
- **Driving RR:** —
- **Principles touched:** IP3, GP3
- **Branch:** `m06-nested-cv-vignette`
- **PR:** https://github.com/jmgirard/nestedtune/pull/6

## Goal

Ship the long-form guide IP3 obliges the package to carry: what a nested
estimate is, what a user should report instead of their model's own score, and
where the model itself comes from.

## Scope

**In:** one vignette for the applied audience — nested CV in a paragraph, the
end-to-end `nested_resamples()` → `nested_tune_grid()` → `nested_final_fit()`
path as runnable code, how to read the per-fold selections the print method
surfaces, and a plain statement of what belongs in a write-up. Its code chunks
execute during `R CMD check`, and every number in its prose comes from an
executed chunk. Wired into the pkgdown articles index and pointed at from the
README.

**Out:** a benchmarking or methods vignette → candidate row if wanted later.
Parallelism guidance → the parallelism candidate, which has no code yet.
Function-level reference prose → roxygen, shipped in M05. Any change to the
exported API → this milestone documents what M05 built and changes no behavior;
a gap found while writing returns to plan rather than being patched here.

## Acceptance criteria

- [x] AC1: the vignette builds from source during `devtools::check()` — its
      "checking re-building of vignette outputs" step passes — and the check is
      clean with it built (0 errors, 0 warnings).
- [x] AC2: it states plainly what to report instead of the fitted model's own
      performance and why, and shows the full path from design to final model as
      code the reader can run (IP3).
- [x] AC3: it shows disagreement between outer folds and says how to read it,
      from real output rather than a described example.
- [x] AC4: no number or behavioral claim in the prose is hand-typed — each is
      produced by a chunk that executes at build, so drift fails the build.
- [x] AC5: `pkgdown::check_pkgdown()` passes with the vignette in the articles
      index, and the README links to it.

## Coverage

- AC1 → T2, T5
- AC2 → T3
- AC3 → T4
- AC4 → T1, T2
- AC5 → T5

## Tasks

- [x] T1: pick and pin the worked dataset — small enough that the full nested
      run plus a final fit executes inside a check budget, from a package
      already in Suggests; a new dependency would need its own gate and D-entry.
- [x] T2: draft the vignette skeleton and the runnable end-to-end example, all
      output produced by executing chunks.
- [x] T3: write the "what to report, and why" section against IP3 — the
      estimate describes the procedure, the model is a separate object.
- [x] T4: write the selection-instability section from actual
      `print.nested_results()` output.
- [x] T5: pkgdown articles entry, README pointer, and a full check with
      vignettes built.

## Work log

- 2026-07-26: created by /milestone-plan.
- 2026-07-26: implement started; branch `m06-nested-cv-vignette` cut from main. Runtime probe of the full path (5x5 design, 5-candidate ranger grid): ~9s on `mtcars`, ~40s on `mlbench::BostonHousing`; outer folds disagree on both.
- 2026-07-26: question gate settled four items — vignette toolchain (knitr + rmarkdown, D-017), worked dataset (`mtcars`, milestone Decisions), file name (`nested-cv.Rmd`, under Articles since a package-named vignette would bypass the articles index AC5 requires), README treatment (fix the stale scope paragraph beside the pointer).
- 2026-07-26: T1 done. Minor amendment: the vignette toolchain (DESCRIPTION Suggests + `VignetteBuilder`) landed in T1 rather than T2, since its dependency gate ran alongside the dataset choice.
- 2026-07-26: T2, T3, T4 done in one commit — they are three sections of one document, and splitting them would have meant reverting drafted prose rather than staging it. `vignettes/nested-cv.Rmd` builds in ~9s.
- 2026-07-26: the first build caught the AC4 guard doing its job: `.selected` is a list column of one-row tibbles, so `res$.selected$mtry` is `NULL` and the prose rendered "chose 0 distinct values". Fixed by stacking with `do.call(rbind, ...)`; a hand-typed number would have shipped the error.
- 2026-07-26: the run shows `mtry` disagreeing across folds while `min_n` agrees, so the instability section reads both cases rather than only disagreement; its heading and prose are worded from the counts rather than asserting a direction.
- 2026-07-26: T5 done. `_pkgdown.yml` gains an explicit `articles:` index (`pkgdown::check_pkgdown()`: no problems found); README gains a guide pointer under the tagline and a runnable end-to-end section replacing the stale "ships the resampling structure only" paragraph; NEWS.md gains the guide entry. The README snippet was executed before committing and returns the same numbers the vignette does.
- 2026-07-26: all tasks checked; status set to review.
- 2026-07-26: AC1 amended via mini gate — it named `devtools::build_vignettes()`, deprecated in devtools 2.5.0 and now refusing to run without `remotes`; it now names the vignette-rebuild step inside `devtools::check()`, which builds from the tarball in a clean session and is strictly stronger. Scope, goal, and every other criterion unchanged.
- 2026-07-26: milestone-local Decisions corrected — the shipped grid is six candidates, not the probe's five; folds disagree on `mtry` and agree on `min_n`.
- 2026-07-26: `devtools::check()` clean with vignettes built — 0 errors, 0 warnings, 0 notes, 4m42s total, of which the vignette rebuild is 13s. `document()` produced no diff.

- 2026-07-26: review sent the milestone back — AC4 fails as written. Every number in the prose is chunk-computed, but three behavioral claims about the API are hand-typed and unbacked ("show_best() ... error instead of answering", "there is no seed argument anywhere", "the caller's random state is left exactly as it was found"), which is exactly the drift AC4 exists to catch. Actioned alongside three prose defects the fresh-context review found (F1 std_err, F2 the optimism claim contradicted by the vignette's own output, F4 a rationale that does not hold for the final-fit object).

- 2026-07-26: F1, F2, F4, F5 fixed on the branch; re-verified from scratch — check Status OK (0/0/0, vignette rebuild 10s/11s), 943 tests pass, `pkgdown::check_pkgdown()` clean, prose scan 0 hand-typed numbers. Status back to review; every AC ticked against its own recorded evidence.
- 2026-07-26: F3 (78) and F6 (45) scored below the action threshold — logged in the Review section and raised as ROADMAP candidates, not fixed here.

## Decisions

- 2026-07-26 (T1): The worked example is `mtcars` with a `ranger` random forest
  over a five-candidate `mtry`/`min_n` grid, in a five-fold outer by five-fold
  inner design. Measured at ~9s for the full path against ~40s for
  `mlbench::BostonHousing`, and its outer folds disagree on both parameters, so
  the selection-instability section reads real disagreement rather than a
  contrived one. Considered and rejected: `BostonHousing` (four times the check
  time, and its race-related variable has pushed most of the ecosystem away from
  using it in teaching material); `PimaIndiansDiabetes` (slowest of the three,
  and its documented data-quality problems would need a caveat that spends the
  guide's space on the dataset rather than on nested CV).

- 2026-07-26 (T2, correcting the entry above): the grid the vignette ships is
  six candidates, `expand.grid(mtry = c(2L, 5L, 8L), min_n = c(2L, 10L))`, not
  the five-point grid the T1 runtime probe used. Under it the outer folds
  disagree on `mtry` and agree on `min_n`, rather than disagreeing on both. The
  choice of dataset and engine is unaffected, and so is the runtime: the
  vignette rebuilds in 13s inside `devtools::check()`.

## Review

_Verified 2026-07-26 against PR #6. All evidence is fresh — re-run after the
review fixes below, never carried over from implement._

**AC1.** `devtools::check(document = TRUE)`: `Status: OK`, 0 errors / 0 warnings
/ 0 notes, 4m32s. The vignette is built from the tarball in a clean session —
"creating vignettes ... OK", "checking package vignettes ... OK", "checking
re-building of vignette outputs ... [10s/11s] OK". `document()` produced no
diff; `devtools::test()` 943 pass / 0 fail / 0 warn.

**AC2.** "What to report, and why" opens "Report that", names the nested RMSE
from an inline expression, and gives the why in three places: the opening
paragraph on selection contaminating a tuned model's own score, the "number
**not** to report" passage, and the executed side-by-side table of the nested
estimate against the best selection-time score. The full path runs as code —
`nested_resamples()`, `workflow()`, `nested_tune_grid()`, `nested_final_fit()`,
`extract_workflow()` + `predict()` — every chunk executed at build. IP3 is
carried explicitly: "The model in hand has no honest number of its own."

**AC3.** From executed output, not description: the `print()` chunk renders
"! mtry: 5, 8, 5, 8, 5 (folds disagree)" beside "✔ min_n: 2 (all 5 completed
folds agree)", and the stacked `.selected` table shows each fold's choice
against its id. The prose that follows reads both cases — a parameter the folds
agree on versus one they split over — and says what each implies about how
well-determined the choice is. Counts are inline expressions, so the reading
cannot drift from the output.

**AC4.** Mechanical scan of `nested-cv.Rmd` with chunks stripped: **0** prose
lines carrying a digit without an inline `r` expression. Behavioral claims are
now executed rather than asserted — `tune::show_best(res)` and
`tune::select_best(final)` run in `error = TRUE` chunks and render tune's real
refusals; `args()` prints both signatures, showing no seed argument;
`identical(before, .Random.seed)` renders `TRUE`. This criterion **failed on
first pass** (F5) and the milestone was returned to `in-progress` before the fix.

**AC5.** `pkgdown::check_pkgdown()`: "No problems found." `_pkgdown.yml` carries
an explicit `articles:` index listing `nested-cv`. README reference links all
resolve — `[guide]` and `[issue]` each defined once and used, none orphaned.
Caveat recorded as F6 below.

### Findings

Three fresh-context reviewers ran in parallel on distinct evidence. The
blame-history lens (Sonnet) reported no findings: no prior deliberate work is
undone, the memory-benchmark table and rsample#283 link survive the README edit
untouched, and the `NEWS.md` heading convention holds. The prior-review lens
(Sonnet) reported no regressions; its GitHub probe returned `[]`, so archived
`## Review` sections were the whole surface. The diff-bug lens (Opus) found four.
A separate Sonnet scorer, which did not generate them, scored all six.

Actioned (scored ≥ 80), all fixed on the branch:

- **F1 (85) — `std_err` described as the fold spread.** It is `sd/sqrt(n)`, the
  standard error of the mean; the vignette twice called it the spread of the
  folds, understating fold-to-fold disagreement by sqrt(5). Fixed: the prose now
  distinguishes the two, and a chunk prints both `sd` and `std_err` so the
  distinction is visible rather than asserted.
- **F2 (82) — the optimism claim contradicted by the vignette's own output.**
  The prose set up the selection-time score as optimistically biased; the
  executed comparison rendered it *higher* than the nested estimate (2.63 vs
  2.46), so the central demonstration appeared to refute its own point. Fixed:
  the argument is now structural rather than directional — the number is
  computed on the resamples that chose the winner, and at this sample size noise
  swamps the bias, so the sign of a single comparison is explicitly not the
  lesson. Also dropped "smallest of a set", which is backwards for
  larger-is-better metrics.
- **F4 (85) — a rationale that does not hold for the final-fit object.** The
  single reason given for both objects refusing tune's ranking generics was
  D-010's "they would rank outer folds", which is meaningless for a
  `nested_final_fit` — one model, no folds. Fixed: each object now carries its
  own reason.
- **F5 (85) — AC4 failure, found by this review.** Numbers were all computed,
  but three behavioral claims about the API were hand-typed and unbacked. Fixed
  by demonstrating each with an executed chunk.

Logged, below the action threshold, not fixed here:

- **F3 (78) — the vignette uses the `ranger` engine unconditionally** though
  `ranger` is only in Suggests, unlike this repo's roxygen (`@examplesIf`) and
  tests (`skip_if_not_installed`). Under CRAN's noSuggests check flavor the
  vignette rebuild would error, which a local check cannot surface. Raised as a
  ROADMAP candidate.
- **F6 (45) — the README's guide URL points at an undeployed site.** The pkgdown
  site root 404s, there is no `gh-pages` branch and no deploy workflow. AC5 as
  written requires `check_pkgdown()` to pass and the README to link to the
  guide, both true; the dead site predates this milestone (DESCRIPTION already
  advertised the same URL) and standing pkgdown deployment up is its own work.
  Raised as a ROADMAP candidate.

Considered and not a finding: the prior-review lens noted D-017 says the
vignette costs "roughly nine seconds" while the work log says 13s. Both are
measured and neither is wrong — ~9s to render standalone, ~11s rebuilding inside
`R CMD check`, which installs the package first.
