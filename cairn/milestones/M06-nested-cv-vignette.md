# M06: A guide that says what to report

- **Status:** review
- **Priority:** normal
- **Depends on:** M05
- **Driving RR:** —
- **Principles touched:** IP3, GP3
- **Branch:** `m06-nested-cv-vignette`

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

- [ ] AC1: the vignette builds under `devtools::build_vignettes()` and
      `devtools::check()` is clean with it built (0 errors, 0 warnings).
- [ ] AC2: it states plainly what to report instead of the fitted model's own
      performance and why, and shows the full path from design to final model as
      code the reader can run (IP3).
- [ ] AC3: it shows disagreement between outer folds and says how to read it,
      from real output rather than a described example.
- [ ] AC4: no number or behavioral claim in the prose is hand-typed — each is
      produced by a chunk that executes at build, so drift fails the build.
- [ ] AC5: `pkgdown::check_pkgdown()` passes with the vignette in the articles
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
- 2026-07-26: `devtools::check()` clean with vignettes built — 0 errors, 0 warnings, 0 notes, 4m42s total, of which the vignette rebuild is 13s. `document()` produced no diff.

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

## Review
