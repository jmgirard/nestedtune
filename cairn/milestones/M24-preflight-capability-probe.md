# M24: The pre-flight tells the truth about the pool

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP3
- **Branch/PR:** —

## Goal

The dispatch-time check on a daemon pool answers the question that decides
whether the run is trustworthy — can these daemons actually run this fold —
rather than the weaker one it asks today.

## Scope

**In:** the pre-flight probe in `R/parallel.R` reports, per daemon, whether the
symbols `dispatch_folds()` resolves by name are present, and the run is refused
naming the daemons that lack them; and dispatch to a pool that cannot be
cancelled says so once.

**Out:**
- Taking the pre-flight deadline off the wall clock → candidate row, corrected
  at this gate to record that `proc.time()` is not established as step-immune.
- Detecting daemons whose code differs while carrying the same symbols (a build
  hash rather than symbol presence) → candidate row.
- Probing remote daemon pools → existing candidate row; needs a remote host.
- Any change to `nested_tune_grid()`'s formals — D-018's no-knob line binds
  signatures and D-020 left that clause standing.

## Acceptance criteria

- [ ] AC1: the pre-flight probe returns one record per daemon carrying the
      symbols it was asked for and which of them it could not find, validated
      positively by shape the way `is_fold_record()` is — a length-1 character
      vector is rejected as a non-answer, because a `miraiError` is exactly
      that shape and must never be read as a capability report.
- [ ] AC2: `preflight_outcome()` gains a fourth outcome for a pool whose
      daemons load the package but lack a required symbol, ranked *below*
      `cannot_load` in the existing ladder, so a pool failing both ways still
      takes the load failure's class (M10-D1). A unit test drives
      `preflight_outcome()` with hand-built records covering all four outcomes
      plus the mixed pool, and asserts each classification.
- [ ] AC3: the status record carries the fields the abort message names, and
      `check_daemons_can_load()` aborts on that outcome with condition classes
      `nestedtune_daemons_incompatible` and `nestedtune_daemons_unusable`,
      naming how many daemons are affected, which symbols are missing, and the
      remedy (reinstall the current version into the daemons' library, then
      restart the pool). Asserted through the existing `status =` injection
      point against a snapshot.
- [ ] AC4: the probe expression runs on a real daemon pool and correctly
      reports a symbol that genuinely is not present, asserted against a live
      pool by asking for a name no version of the package defines.
- [ ] AC5: dispatch to a pool started with `mirai::daemons(n, dispatcher = FALSE)`
      emits exactly one warning of class `nestedtune_pool_not_cancellable`,
      naming that an interrupted run's folds keep computing and that a
      dispatcher-backed pool is what makes cancellation work; a pool started
      with `mirai::daemons(n)` emits none. The warning is emitted in
      `dispatch_folds()`; both branches are asserted at the `nested_tune_grid()`
      seam and again driving `dispatch_folds()` directly.
- [ ] AC6: `NEWS.md` records the refusal and the warning; the roxygen
      cancellation paragraph (`R/nested-tune-grid.R:236-242`) says a warning now
      fires, the pre-flight bullet (`R/nested-tune-grid.R:191-195`) covers the
      new refusal, and `man/nested_tune_grid.Rd` is regenerated.
- [ ] AC7: every new daemon-touching test carries its `helper-time-budget.R`
      row, and the `verify` slot in `cairn/PROFILE.md` is clean.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T4
- AC5 → T5
- AC6 → T6
- AC7 → T4, T5, T7

## Tasks

- [ ] T1: replace the probe's logical answer with a per-daemon record and its
      positive validator, superseding `loaded_answer()`
      (`R/parallel.R:380-382`); amend the contract test at
      `tests/testthat/test-parallel-classify.R:503`, which encodes the answer
      shape this changes.
- [ ] T2: extend `preflight_outcome()`'s ladder (`R/parallel.R:390-411`) with
      the new outcome below `cannot_load`; test all four plus the mixed pool.
- [ ] T3: carry the new fields on the status record and add the abort branch to
      `check_daemons_can_load()` (`R/parallel.R:419-475`); snapshot the message.
- [ ] T4: assert the probe against a live pool with a deliberately absent
      symbol, in `test-parallel-detection.R`; add its time-budget row.
- [ ] T5: detect the pool kind from `mirai::status()$mirai` and warn once in
      `dispatch_folds()` (`R/parallel.R:169-273`); assert both pool kinds and
      add the time-budget rows.
- [ ] T6: `NEWS.md`, the two roxygen sites, and `devtools::document()`.
- [ ] T7: full `verify` slot clean; register any new prose-guard in the
      mutation harness.

## Work log

- 2026-07-30: created by /milestone-plan.
- 2026-07-30: plan gate chose a symbol-capability probe over comparing the daemon's package version because `DESCRIPTION`'s `Version:` has read `0.0.0.9000` since M01 (`fafb31f`, the only commit touching it in 23 milestones), so a stale daemon reports the host's own string and a version check cannot fire; falsified by a daemon whose symbols are all present while its code differs, which is the build-hash candidate this leaves in Out.
- 2026-07-30: plan gate chose proving the probe against a live pool with an absent symbol over installing a stubbed package into a scratch library, because priming a daemon reaches every daemon and erases the heterogeneity such a fixture exists to create (`test-parallel-detection.R:86-88`); falsified by a failure mode that only a genuinely mixed pool exhibits.
- 2026-07-30: plan gate chose warning on a `dispatcher = FALSE` pool over refusing it, because the pool computes correct results and only cancellation is unavailable, so GP3's refuse-don't-warn stance does not reach it; falsified by evidence that an uncancellable pool produces a wrong result rather than an uninterruptible one.
- 2026-07-30: criteria audit ([O], fresh context) returned 12 findings. Actioned at the gate: the version check was vacuous and became a capability probe; the probe answer became a validated record because a `miraiError` is a length-1 character vector; the new outcome was ranked below `cannot_load`; the status record gained the fields the message names; the roxygen criterion was rewritten after the audit found its premise false. The clock item was dropped to a corrected candidate row on the audit's finding that `proc.time()` is not documented as step-immune.

## Decisions

## Review
