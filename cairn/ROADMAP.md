# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-07-26 (M07 merged and archived — `nested_tune_grid()` runs its outer folds on mirai daemons with results identical to serial, verified by execution; D-018 added, M02's row pruned under terminal-row retention, 15 candidates, 3 lessons added)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M03 | Fold failures are recorded, never fatal | done | M02 | high | milestones/archive/M03-failed-fold-recording.md |
| M04 | Printing surfaces the run and its disagreement | done | M03 | normal | milestones/archive/M04-print-nested-results.md |
| M05 | The final model is its own object | done | M02 | high | milestones/archive/M05-final-fit-path.md |
| M06 | A guide that says what to report | done | M05 | normal | milestones/archive/M06-nested-cv-vignette.md |
| M07 | Parallel outer folds | done | M02 | high | milestones/archive/M07-parallel-outer-folds.md |
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Deploy the pkgdown site, so the URLs DESCRIPTION and README already advertise resolve — the site root 404s today, with no `gh-pages` branch and no deploy workflow (`usethis::use_pkgdown_github_pages()` is the standard route) — added 2026-07-26 — M06 review finding F6, scored 45; the dead URL predates M06, which only added a second link depending on it
- Report the M01 diagnosis upstream on rsample#283 (cause is inside_resample()'s as.data.frame(); the 13x figure's reprex used a 10x10 scheme, not 5x2) — added 2026-07-25 — G4; promoted from the memory candidate, which became M01
- Plotting selection instability, so the disagreement M04 prints can also be seen — added 2026-07-25 — split from M02; failed-fold handling became M03 and print/summary became M04. Trimmed to its remainder 2026-07-26: the parallelism half became M07, leaving plotting, which needs its own dependency gate (ggplot2) and is defended by no principle — DESIGN keeps instability-surfacing a convention deliberately, not a GP
- Reduce what each mirai worker must serialize — every fold's split references the whole dataset, so parallel dispatch sends a copy per worker, which is the memory axis M01's in-process leanness does not cover (GP4) — added 2026-07-26 — M07 Out; measure before designing, since mirai may already share via its own mechanisms
- Make the parallel pre-flight probe configurable and honest about timeouts — the 30 s bound is a hard-coded constant with no option, and a timeout is reported as "cannot load the package", telling a user to install what they already have — added 2026-07-26 — M07 review finding F3, scored 68 (below the action threshold); loading `tune` alone in a cold daemon measured 6.5 s, so a loaded CI runner or AV-scanned Windows library could plausibly exceed it
- Probe every daemon in the parallel pre-flight, not just one — `mirai::mirai()` submits a single task that one daemon takes, so in a heterogeneous pool (remote daemons, or a respawned one that `everywhere()` priming never reached) a single loadable daemon passes the check while the rest return opaque worker failures — added 2026-07-26 — M07 review finding F4, scored 60; RR03 Q5 already flags remote pools as unprobed
- Decide whether an externally cancelled parallel run should abort rather than record fold failures — `mirai::stop_mirai()` yields `errorValue` 20 classed only `errorValue`/`try-error`, never `miraiInterrupt`, so it falls through to `failed_fold()` and the run returns an estimate over whatever folds finished, which is the IP4 inversion BC4 exists to prevent for the interrupt path — added 2026-07-26 — M07 review finding F5, scored 78 (just below the action threshold); the interrupt path itself is handled and tested
- Give the orchestration tests a metric set that is not tune's default, so a dropped `metrics` argument fails something — today every fixture uses `metric_set(rmse, rsq)`, which equals the regression default, and `metrics = NULL` gives identical results — added 2026-07-26 — M05 review finding F1, scored 78 (below the action threshold); affects `nested_tune_grid()` as well as `nested_final_fit()`
- `predict()` and `augment()` methods on `nested_final_fit`, so the object answers directly instead of only through `extract_workflow()` — added 2026-07-26 — M05 Out; D-014 left them off deliberately, matching what `tune::last_fit()` asks of users
- An `extract_`-family accessor for the tuning run stored on `nested_final_fit`, named for what it is rather than a euphemism — added 2026-07-26 — RR02 rec 11 (consider); a documented slot suffices pre-1.0
- Make a design's stored `inside` call survive leaving its construction scope, by substituting its arguments' values at construction rather than capturing the frame — added 2026-07-26 — RR02 B1; M05 hit this on the repo's own `det_nested()` helper, so any wrapper parameterizing `v` is affected. M05 refuses loudly and asks for literals (AC11); capturing the frame instead would retain it, which GP4 argues against. Does not reach `rsample::nested_cv()` designs
- Variance estimation / inference on the nested estimate — added 2026-07-25 — G6; needs oracle-grade literature support before it is plannable. Absorbs M02 review finding F5 (scored 73): `collect_metrics()` already ships a naive `std_err` across outer folds, mirroring tune's columns, with no roxygen caveat saying it is not an oracle-backed interval — document or drop it when this is planned
- Route a preprocessor-only workflow through `nested_tune_grid()`'s own `cli_abort()` instead of letting `workflows::extract_spec_parsnip()` raise it, so every bad-`object` shape fails with the same discipline — added 2026-07-25 — M02 review finding F6, scored 75 (below the action threshold)
- Settle posture toward upstream's dormant tune prototype once tune#969 is answered — added 2026-07-25 — G7
- Document IP2's enforceable scope in DESIGN.md — it binds only randomness flowing through R's RNG, so engines that bypass it (kernlab SVM, keras/torch) are unreachable by any R-side scheme — added 2026-07-25 — RR01 B4; amending IP text needs a D-entry
- Validate that `inside` evaluates to an `rset` and `cli_abort()` if not, at `nested_resamples()` construction time; today a non-rset spec surfaces rsample's internal "Split and ID vectors have different lengths" — added 2026-07-25 — M01 review finding F7, scored 78 (below the action threshold). Trimmed to its remainder 2026-07-26: M05 covers the final-fit half, where `eval_inside_spec()` refuses a specification that does not produce an `rset`; construction is still unguarded
