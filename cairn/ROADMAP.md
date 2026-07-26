# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-07-25 (design interview complete, both phases; 3 candidates banked, no milestones yet; all checks green)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M01 | Memory-lean nested resampling structure | planned | — | normal | milestones/M01-memory-lean-nested-resampling.md |
| M02 | Outer-loop orchestration | planned | M01 | high | milestones/M02-outer-loop-orchestration.md |
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Report the M01 diagnosis upstream on rsample#283 (cause is inside_resample()'s as.data.frame(); the 13x figure's reprex used a 10x10 scheme, not 5x2) — added 2026-07-25 — G4; promoted from the memory candidate, which became M01
- Parallelism over outer folds, failed-fold handling (IP4), and print/summary surfacing selection instability — added 2026-07-25 — split from M02; plan once M02's results object exists
- Final-fit path as a separate object, never a field on the results — added 2026-07-25 — IP3, DESIGN Conventions; plan after M02
- Variance estimation / inference on the nested estimate — added 2026-07-25 — G6; needs oracle-grade literature support before it is plannable
- Settle posture toward upstream's dormant tune prototype once tune#969 is answered — added 2026-07-25 — G7
