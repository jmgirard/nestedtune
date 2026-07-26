# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-07-25 (design interview complete, both phases; 3 candidates banked, no milestones yet; all checks green)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
| M01 | Memory-lean nested resampling structure | planned | — | normal | milestones/M01-memory-lean-nested-resampling.md |
<!-- rows grouped by status, not sorted by ID; keep only the 5 most recent
     terminal (done or dropped) rows — older ones live in milestones/archive/ + git -->

## Candidates
<!-- unnumbered ideas; one line each: idea — added YYYY-MM-DD — links -->
- Report the M01 diagnosis upstream on rsample#283 (cause is inside_resample()'s as.data.frame(); the 13x figure's reprex used a 10x10 scheme, not 5x2) — added 2026-07-25 — G4; promoted from the memory candidate, which became M01
- Outer-loop orchestration: run the nested loop through tune/parsnip and return collected results — added 2026-07-25 — G1-G3, G5, D-002; the package's contract, to plan after M01
- Variance estimation / inference on the nested estimate — added 2026-07-25 — G6; needs oracle-grade literature support before it is plannable
- Settle posture toward upstream's dormant tune prototype once tune#969 is answered — added 2026-07-25 — G7
