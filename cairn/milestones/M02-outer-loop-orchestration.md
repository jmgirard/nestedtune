# M02: Outer-loop orchestration

- **Status:** in-progress
- **Priority:** high
- **Depends on:** M01
- **Driving RR:** RR01
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

**Out:** parallelism over outer folds, failed-fold handling (IP4), print/summary surfacing of
selection instability, the separate final-fit path IP3 implies, variance estimation (G6), and
tune#969 posture (G7) — each already a ROADMAP candidate row carrying its reason; the first is
planned once this milestone's results object exists and its real shape is known.

## Acceptance criteria

- [ ] AC1 — `devtools::check()` clean: 0 errors, 0 warnings, NOTEs justified in the review evidence.
- [ ] AC2 — Per-fold metrics match a hand-rolled `tune_grid()` → `select_best()` → `finalize_workflow()`
      → `last_fit()` reference loop under a fixed seed. Reference-implementation oracle (GP2); AC16 fixes the construction.
- [ ] AC3 — With a single-candidate grid, per-fold metrics match `tune::fit_resamples()` on the outer
      `rset` — nothing to select, so nested CV degenerates to ordinary CV. Invariant oracle, GP2's second type; AC17 fixes the engine.
- [ ] AC4 — IP1 checked, not asserted: for every outer fold, the rows seen by inner tuning and by the
      outer fit are disjoint from that fold's assessment rows, verified by a test instrumenting membership.
- [ ] AC5 — The results object retains each outer fold's selected parameters, and `collect_metrics()`
      returns both per-fold and summarized metrics.
- [ ] AC6 — An outer bootstrap is refused with `cli_abort()`, deliberately stricter than rsample's
      warning (GP3); every error branch is fired by a test.
- [ ] AC7 — Every exported object has roxygen docs and a `_pkgdown.yml` reference row;
      `devtools::document()` produces no diff; NEWS.md records the user-visible change.
- [ ] AC8 (BC1): `nested_tune_grid()` derives all per-fold seeds from the caller's RNG
      state at entry in a single documented `sample.int()` call producing one
      tuning seed and one outer-fit seed per outer fold, assigned by fold position;
      no seed is drawn inside the fold loop or worker.
- [ ] AC9 (BC2): Each fold's work seeds the RNG with its own seeds and a pinned kind:
      the tuning step runs after `set.seed(<tuning seed>, kind = "Mersenne-Twister",
      normal.kind = "Inversion", sample.kind = "Rejection")` and `last_fit()` runs
      immediately after the same call form with that fold's outer-fit seed.
- [ ] AC10 (BC3): The returned `nested_results` object exposes each fold's tuning seed
      and outer-fit seed, and the exported documentation states the
      hand-replication contract in terms of those seeds.
- [ ] AC11 (BC4): On exit (including on error), `.Random.seed` and the full `RNGkind()`
      triple equal their entry values; a test asserts that draws following the
      call are identical to draws with the call absent. If `.Random.seed` does not
      exist at entry, the function neither errors nor leaves the session without a
      valid RNG state.
- [ ] AC12 (BC5): DESCRIPTION declares `tune (>= 2.0.0)`.
- [ ] AC13 (BC6): Same-seed identity is asserted with a stochastic engine whose
      randomness flows through R's RNG (ranger via Suggests, test skipped if
      unavailable): two runs under the same `set.seed()` produce `identical()`
      per-fold metrics and `identical()` selected parameters; a companion
      assertion shows a different seed changes the metrics.
- [ ] AC14 (BC7): The per-fold computation is an internal function of (outer split,
      inner rset, fold seeds, static inputs) only; a test executes the folds
      through it in a permuted order and asserts per-fold results `identical()`
      to the driver's in-order output.
- [ ] AC15 (BC8): A test asserts the per-fold worker's output for fixed seeds is
      `identical()` regardless of the caller's RNG kind and state at its
      invocation (at minimum: default Mersenne-Twister state and an
      L'Ecuyer-CMRG state).
- [ ] AC16 (BC9): The AC2 reference-loop test derives its expected fold seeds from the
      documented contract (its own `set.seed()` + `sample.int()` call, not the
      driver's output), asserts they equal the exposed seeds, and then asserts
      the hand-rolled `tune_grid()` → `select_best()` → `finalize_workflow()` →
      `last_fit()` loop reproduces per-fold metrics and selected parameters
      `identical()`ly, in both a deterministic-engine and a stochastic-engine
      variant.
- [ ] AC17 (BC10): The AC3 single-candidate-grid invariant against
      `tune::fit_resamples()` is asserted with a deterministic engine; no
      criterion claims stochastic-engine identity with `fit_resamples()`.

## Coverage

- AC1 → T1, T9
- AC2 → T2, T3, T4
- AC3 → T2, T3
- AC4 → T8
- AC5 → T5, T6
- AC6 → T7
- AC7 → T9
- AC8 → T4
- AC9 → T4
- AC10 → T5
- AC11 → T4, T10
- AC12 → T1
- AC13 → T10
- AC14 → T4, T10
- AC15 → T10
- AC16 → T2, T3
- AC17 → T2

## Tasks

- [ ] T1 — Add `tune (>= 2.0.0)`, `workflows`, and `parsnip` to DESCRIPTION
      Imports per D-007 and the RR01 version floor, and `ranger` to Suggests for
      the stochastic-engine tests; confirm `R CMD check` reports no unused
      declared dependency.
- [ ] T2 — Write the failing oracle tests first: the reference-loop equivalence
      (AC2/AC16, deterministic and stochastic variants, seeds derived from the
      documented contract) and the single-candidate-grid invariant (AC3/AC17,
      deterministic engine only).
- [ ] T3 — Implement the per-fold step: `tune_grid()` on the inner `rset` with
      `control_grid(allow_par = FALSE)`, `select_best()`,
      `finalize_workflow()`, then `last_fit()` on the outer split.
- [ ] T4 — Implement the serial driver over outer folds per D-011: draw
      `2 * n_folds` seeds at entry, run each fold through a pure per-fold worker
      seeded with the kind triple pinned, and restore the caller's RNG state and
      kind on exit (including on error). (RB tripwire: ip-touching — IP2;
      settled by RR01.)
- [ ] T5 — Results object: class, constructor, and storage of per-fold metrics
      alongside each fold's selected parameters and its two seeds.
- [ ] T6 — `collect_metrics()` method returning per-fold and summarized metrics.
- [ ] T7 — Input validation: refuse an outer bootstrap, and validate the
      workflow, grid, and metric-set arguments; test every `cli_abort()` branch.
- [ ] T8 — Leakage test: instrument row membership per outer fold and assert
      inner tuning and the outer fit never touch that fold's assessment rows.
      (RB tripwire: ip-touching — IP1.)
- [ ] T9 — Roxygen docs (including the hand-replication contract and IP2's
      R-RNG scope), `_pkgdown.yml` rows, NEWS.md entry, `document()` no-diff,
      `devtools::check()` clean.
- [ ] T10 — RNG test battery per RR01: same-seed identity and seed sensitivity
      on a stochastic engine, permuted fold-order invariance, ambient-state
      independence of the per-fold worker, and the net-zero exit-state pin.

## Work log

- 2026-07-25: created by /milestone-plan, absorbing the orchestration candidate row.
- 2026-07-25: /milestone-implement started; branch `m02-outer-loop-orchestration` cut from main.
- 2026-07-25: question gate — entry point, results class, and the `control` argument settled (D-010 + milestone-local entry); T4's RNG scheme escalated to /milestone-brief on the user's selection (IP2 tripwire).
- 2026-07-25: blocked on RB01 (per-outer-fold RNG streams, T4). RB committed on the milestone branch rather than the default branch, since M02's branch was already open — keeps this milestone's tracking on one branch.
- 2026-07-25: ingested RR01 ([F] Fable subagent, tune 2.1.0 installed and probed by execution). Applied: Scheme A′ (D-011), tune version floor, `ranger` in Suggests, deterministic engine for AC3 and both variants for AC2, the seeds-as-contract oracle construction. Rejected with reason (RR recs 2, 3, 7): L'Ecuyer streams, inherited state, and a `seed` argument. Deferred: B4 → ROADMAP candidate. BC1–BC10 ingested verbatim as AC8–AC17; no deviations.
- 2026-07-25: dependency gate — user approved the `tune (>= 2.0.0)` floor and `ranger` in Suggests (D-012); user also elected to carry M02 as one milestone despite the 17-criteria / 10-task split tripwires.
- 2026-07-25: plan amendment (substantive) — AC1–AC7 and Scope Out compressed in one pass to fit the 150-line cap after the BC ingestion; no criterion dropped, AC2/AC3 shed detail now carried more precisely by AC16/AC17. T1/T2/T4/T5/T9 refined and T10 added for the RNG test battery.

## Decisions

- 2026-07-25: `nested_tune_grid()` takes no `control` argument in M02 — it
  builds `control_grid(allow_par = FALSE)` internally. One obvious path (GP3)
  and fewer branches to verify; adding the argument later is not a breaking
  change, so the choice is cheap to revisit once the parallelism milestone
  knows what it needs. The forced `allow_par = FALSE` is a GP1 divergence and
  is documented in the roxygen rather than left silent.

## Review
