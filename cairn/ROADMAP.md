# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-07-27 (M10 merged and archived — the parallel startup check now probes every daemon and separates a load failure from a non-response; review fixed six defects including a bound validated only after dispatch, M05's row pruned under terminal-row retention, 13 candidates, 2 lessons added and 2 retired)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M09 | A stopped run reports nothing, not a partial estimate | done | — | high | milestones/archive/M09-parallel-cancellation.md |
| M10 | The startup check inspects every worker and says what went wrong | done | — | normal | milestones/archive/M10-preflight-probe-coverage.md |
| M06 | A guide that says what to report | done | M05 | normal | milestones/archive/M06-nested-cv-vignette.md |
| M07 | Parallel outer folds | done | M02 | high | milestones/archive/M07-parallel-outer-folds.md |
| M08 | Selection instability you can see | done | — | normal | milestones/archive/M08-autoplot-nested-results.md |
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Cut this repo's GitHub Actions bill, which is ~5,393 billed minutes over ~100 runs on a private repo: macOS is 52% of it at only 260 raw minutes (×10 multiplier) while being the fastest job, 14 of 23 default-branch pushes were docs-only `cairn/` commits that fire the full 5-OS matrix (~27%), and 31 superseded runs burned ~897 billed minutes for want of a `concurrency` block (~17%) — added 2026-07-27 — measured from the jobs API; agreed shape is paths-ignore for `cairn/**`, concurrency cancel scoped off the default branch, and PRs on ubuntu+windows with the full matrix kept on `main` and tags; dependency caching is already in place via setup-r-dependencies and is not worth touching
- Deploy the pkgdown site, so the URLs DESCRIPTION and README already advertise resolve — the site root 404s today, with no `gh-pages` branch and no deploy workflow (`usethis::use_pkgdown_github_pages()` is the standard route) — added 2026-07-26 — M06 review finding F6, scored 45; the dead URL predates M06, which only added a second link depending on it
- Report the M01 diagnosis upstream on rsample#283 (cause is inside_resample()'s as.data.frame(); the 13x figure's reprex used a 10x10 scheme, not 5x2) — added 2026-07-25 — G4; promoted from the memory candidate, which became M01
- Reduce what each mirai worker must serialize — every fold's split references the whole dataset, so parallel dispatch sends a copy per worker, which is the memory axis M01's in-process leanness does not cover (GP4) — added 2026-07-26 — M07 Out; measure before designing, since mirai may already share via its own mechanisms
- Probe remote mirai daemon pools, which nothing verifies today — RR03 Q5 established the load requirement by execution only for local daemons and marked the remote case *inferred* from the same mechanism, so a remote host missing the package still surfaces as opaque per-fold worker failures — added 2026-07-26 — M10 Out, carried over from the absorbed pre-flight rows; needs a remote host to test against before it is plannable
- Give the orchestration tests a metric set that is not tune's default, so a dropped `metrics` argument fails something — today every fixture uses `metric_set(rmse, rsq)`, which equals the regression default, and `metrics = NULL` gives identical results — added 2026-07-26 — M05 review finding F1, scored 78 (below the action threshold); affects `nested_tune_grid()` as well as `nested_final_fit()`
- `predict()` and `augment()` methods on `nested_final_fit`, so the object answers directly instead of only through `extract_workflow()` — added 2026-07-26 — M05 Out; D-014 left them off deliberately, matching what `tune::last_fit()` asks of users
- An `extract_`-family accessor for the tuning run stored on `nested_final_fit`, named for what it is rather than a euphemism — added 2026-07-26 — RR02 rec 11 (consider); a documented slot suffices pre-1.0
- Make a design's stored `inside` call survive leaving its construction scope, by substituting its arguments' values at construction rather than capturing the frame — added 2026-07-26 — RR02 B1; M05 hit this on the repo's own `det_nested()` helper, so any wrapper parameterizing `v` is affected. M05 refuses loudly and asks for literals (AC11); capturing the frame instead would retain it, which GP4 argues against. Does not reach `rsample::nested_cv()` designs
- Variance estimation / inference on the nested estimate — added 2026-07-25 — G6; needs oracle-grade literature support before it is plannable. Absorbs M02 review finding F5 (scored 73): `collect_metrics()` already ships a naive `std_err` across outer folds, mirroring tune's columns, with no roxygen caveat saying it is not an oracle-backed interval — document or drop it when this is planned
- Route a preprocessor-only workflow through `nested_tune_grid()`'s own `cli_abort()` instead of letting `workflows::extract_spec_parsnip()` raise it, so every bad-`object` shape fails with the same discipline — added 2026-07-25 — M02 review finding F6, scored 75 (below the action threshold)
- Settle posture toward upstream's dormant tune prototype once tune#969 is answered — added 2026-07-25 — G7
- Document IP2's enforceable scope in DESIGN.md — it binds only randomness flowing through R's RNG, so engines that bypass it (kernlab SVM, keras/torch) are unreachable by any R-side scheme — added 2026-07-25 — RR01 B4; amending IP text needs a D-entry
- Validate that `inside` evaluates to an `rset` and `cli_abort()` if not, at `nested_resamples()` construction time; today a non-rset spec surfaces rsample's internal "Split and ID vectors have different lengths" — added 2026-07-25 — M01 review finding F7, scored 78 (below the action threshold). Trimmed to its remainder 2026-07-26: M05 covers the final-fit half, where `eval_inside_spec()` refuses a specification that does not produce an `rset`; construction is still unguarded
