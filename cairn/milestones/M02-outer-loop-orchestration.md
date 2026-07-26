# M02: Outer-loop orchestration

- **Status:** blocked
- **Priority:** high
- **Depends on:** M01
- **Driving RR:** —
- **Principles touched:** IP1, IP2, IP3, GP1, GP3
- **Branch/PR:** `m02-outer-loop-orchestration`

## Goal

Run the nested loop end to end — inner tuning, selection, outer fit and score —
returning a collected-results object that retains each outer fold's chosen
parameters.

## Scope

**In:** One exported entry point taking a workflow, the memory-lean nested
structure from M01, a grid, and a metric set. Per outer fold it calls
`tune::tune_grid()` on that fold's inner `rset` with
`control_grid(allow_par = FALSE)`, then `select_best()`,
`finalize_workflow()`, and `last_fit()` on the outer split — delegating every
step rather than reimplementing it. A results object retaining per-fold metrics
*and* per-fold selected parameters, with a `collect_metrics()` method. Outer
bootstrap refused outright. Serial execution. Docs, NEWS.md, pkgdown rows.

**Out:**
- Parallelism over outer folds, failed-fold handling (IP4), and print/summary
  surfacing of selection instability → one candidate row, planned once this
  milestone's results object exists and its real shape is known.
- The separate final-fit path IP3 implies → candidate row.
- Variance estimation (G6), tune#969 posture (G7) → existing candidate rows.

## Acceptance criteria

- [ ] AC1 — `devtools::check()` clean: 0 errors, 0 warnings, NOTEs justified in
      the review evidence.
- [ ] AC2 — For a fixed seed, per-outer-fold metrics are identical to a
      hand-rolled reference loop running `tune_grid()` → `select_best()` →
      `finalize_workflow()` → `last_fit()` explicitly. Reference-implementation
      oracle (GP2).
- [ ] AC3 — With a single-candidate grid, per-fold metrics are identical to
      `tune::fit_resamples()` on the outer `rset` under the same workflow, seed,
      and metrics — with nothing to select, nested CV degenerates to ordinary
      CV. Invariant oracle, the second independent type GP2 requires beside AC2.
- [ ] AC4 — IP1 is checked, not asserted: for every outer fold, the row indices
      seen by inner tuning and by the outer fit are disjoint from that fold's
      assessment indices, verified by a test that instruments membership.
- [ ] AC5 — The results object retains each outer fold's selected parameters,
      and `collect_metrics()` returns both per-fold and summarized metrics.
- [ ] AC6 — An outer bootstrap is refused with `cli_abort()`, deliberately
      stricter than rsample's warning (GP3); every error branch is fired by a
      test.
- [ ] AC7 — Every exported object has roxygen docs and a `_pkgdown.yml`
      reference row; `devtools::document()` produces no diff; NEWS.md records
      the user-visible change.

## Coverage

- AC1 → T1, T9
- AC2 → T2, T3, T4
- AC3 → T2, T3
- AC4 → T8
- AC5 → T5, T6
- AC6 → T7
- AC7 → T9

## Tasks

- [ ] T1 — Add `tune`, `workflows`, and `parsnip` to DESCRIPTION Imports per
      D-007; confirm `R CMD check` reports no unused declared dependency.
- [ ] T2 — Write the failing oracle tests first: the reference-loop equivalence
      (AC2) and the single-candidate-grid invariant (AC3).
- [ ] T3 — Implement the per-fold step: `tune_grid()` on the inner `rset` with
      `control_grid(allow_par = FALSE)`, `select_best()`,
      `finalize_workflow()`, then `last_fit()` on the outer split.
- [ ] T4 — Implement the serial driver over outer folds with RNG streams managed
      per fold rather than inherited, so the seed determines the result
      independently of execution order. (RB tripwire: ip-touching — IP2.)
- [ ] T5 — Results object: class, constructor, and storage of per-fold metrics
      alongside each fold's selected parameters.
- [ ] T6 — `collect_metrics()` method returning per-fold and summarized metrics.
- [ ] T7 — Input validation: refuse an outer bootstrap, and validate the
      workflow, grid, and metric-set arguments; test every `cli_abort()` branch.
- [ ] T8 — Leakage test: instrument row membership per outer fold and assert
      inner tuning and the outer fit never touch that fold's assessment rows.
      (RB tripwire: ip-touching — IP1.)
- [ ] T9 — Roxygen docs, `_pkgdown.yml` rows, NEWS.md entry, `document()`
      no-diff, `devtools::check()` clean.

## Work log

- 2026-07-25: created by /milestone-plan, absorbing the orchestration candidate row.
- 2026-07-25: /milestone-implement started; branch `m02-outer-loop-orchestration` cut from main.
- 2026-07-25: question gate — entry point, results class, and the `control` argument settled (D-010 + milestone-local entry); T4's RNG scheme escalated to /milestone-brief on the user's selection (IP2 tripwire).
- 2026-07-25: blocked on RB01 (per-outer-fold RNG streams, T4). RB committed on the milestone branch rather than the default branch, since M02's branch was already open — keeps this milestone's tracking on one branch.

## Decisions

- 2026-07-25: `nested_tune_grid()` takes no `control` argument in M02 — it
  builds `control_grid(allow_par = FALSE)` internally. One obvious path (GP3)
  and fewer branches to verify; adding the argument later is not a breaking
  change, so the choice is cheap to revisit once the parallelism milestone
  knows what it needs. The forced `allow_par = FALSE` is a GP1 divergence and
  is documented in the roxygen rather than left silent.

## Review
