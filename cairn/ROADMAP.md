# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-07-26 (M03 merged and archived — a failing fold is now recorded rather than fatal; M04 planned and workable, 7 candidates, nothing in progress; 4 lessons captured, all checks green)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M01 | Memory-lean nested resampling structure | done | — | normal | milestones/archive/M01-memory-lean-nested-resampling.md |
| M02 | Outer-loop orchestration | done | M01 | high | milestones/archive/M02-outer-loop-orchestration.md |
| M03 | Fold failures are recorded, never fatal | done | M02 | high | milestones/archive/M03-failed-fold-recording.md |
| M04 | Printing surfaces the run and its disagreement | planned | M03 | normal | milestones/M04-print-nested-results.md |
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Report the M01 diagnosis upstream on rsample#283 (cause is inside_resample()'s as.data.frame(); the 13x figure's reprex used a 10x10 scheme, not 5x2) — added 2026-07-25 — G4; promoted from the memory candidate, which became M01
- Parallelism over outer folds, plus plotting selection instability — added 2026-07-25 — split from M02; failed-fold handling became M03 and print/summary became M04, leaving this remainder. Parallelism needs its own dependency gate and D-entry (tune 2.x carries mirai and future in Suggests); D-011's RNG scheme is already parallel-ready, so the work is verifying it across workers, not redesigning it
- Final-fit path as a separate object, never a field on the results — added 2026-07-25 — IP3, DESIGN Conventions; plan after M02
- Variance estimation / inference on the nested estimate — added 2026-07-25 — G6; needs oracle-grade literature support before it is plannable. Absorbs M02 review finding F5 (scored 73): `collect_metrics()` already ships a naive `std_err` across outer folds, mirroring tune's columns, with no roxygen caveat saying it is not an oracle-backed interval — document or drop it when this is planned
- Route a preprocessor-only workflow through `nested_tune_grid()`'s own `cli_abort()` instead of letting `workflows::extract_spec_parsnip()` raise it, so every bad-`object` shape fails with the same discipline — added 2026-07-25 — M02 review finding F6, scored 75 (below the action threshold)
- Settle posture toward upstream's dormant tune prototype once tune#969 is answered — added 2026-07-25 — G7
- Document IP2's enforceable scope in DESIGN.md — it binds only randomness flowing through R's RNG, so engines that bypass it (kernlab SVM, keras/torch) are unreachable by any R-side scheme — added 2026-07-25 — RR01 B4; amending IP text needs a D-entry
- Validate that `inside` evaluates to an `rset` and `cli_abort()` if not; today a non-rset spec surfaces rsample's internal "Split and ID vectors have different lengths" — added 2026-07-25 — M01 review finding F7, scored 78 (below the action threshold)
