# M06: A guide that says what to report

- **Status:** planned
- **Priority:** normal
- **Depends on:** M05
- **Driving RR:** —
- **Principles touched:** IP3, GP3

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

- [ ] T1: pick and pin the worked dataset — small enough that the full nested
      run plus a final fit executes inside a check budget, from a package
      already in Suggests; a new dependency would need its own gate and D-entry.
- [ ] T2: draft the vignette skeleton and the runnable end-to-end example, all
      output produced by executing chunks.
- [ ] T3: write the "what to report, and why" section against IP3 — the
      estimate describes the procedure, the model is a separate object.
- [ ] T4: write the selection-instability section from actual
      `print.nested_results()` output.
- [ ] T5: pkgdown articles entry, README pointer, and a full check with
      vignettes built.

## Work log

- 2026-07-26: created by /milestone-plan.

## Decisions

## Review
