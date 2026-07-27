# M09: A stopped run reports nothing, not a partial estimate

- **Status:** planned
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4, IP2
- **Branch/PR:** —

## Goal

A parallel run cancelled from outside aborts, instead of recording the folds
that never ran as folds that were attempted and failed.

## Scope

**In:** `classify_fold_result()` (`R/parallel.R:155`) learns to tell a
cancelled task from a dead worker. mirai resolves queued tasks to bare
`errorValue`s when the pool is torn down — `stop_mirai()` reportedly yields
code 20, classed only `errorValue`/`try-error` and never `miraiInterrupt` —
so today they fall through to `failed_fold("worker", ...)` and the run returns
an estimate over whatever finished. Cancellation joins the existing
`miraiInterrupt` branch and aborts with class `nestedtune_interrupted`, letting
`nested_tune_grid()`'s `on.exit()` (`R/nested-tune-grid.R:201`) restore the
caller's RNG state. The distinction from `errorValue` 19 — a daemon killed
mid-task, which RR03 verified *is* a genuine fold failure — is established by
execution, not by reading, and is what the milestone must not get wrong.

**Out:** the pre-flight probe's daemon coverage and timeout messaging → M10.
Per-fold timeouts stay rejected (RR03 Q4); not reopened here. Cutting what each
worker must serialize → candidate row. Remote-pool behaviour → candidate row.

## Acceptance criteria

- [ ] AC1: An execution-verified table records what mirai returns for a task
      cancelled by `stop_mirai()` (in-flight and queued), for `daemons(0)` with
      tasks outstanding, and for a killed daemon — on the mirai version in the
      test library, named. Committed in this file's Decisions section.
- [ ] AC2: `classify_fold_result()` aborts with class `nestedtune_interrupted`
      on every cancellation shape AC1 found, and the caller's `.Random.seed`
      and `RNGkind()` are restored afterwards. Both fired by test.
      *(RB tripwire: ip-touching — IP4; reading settled at the M09 plan gate.)*
- [ ] AC3: `errorValue` 19 still becomes a recorded worker failure — the
      existing BC3 test (`tests/testthat/test-parallel-identity.R:232`) passes
      unmodified, and the classification stays positive-by-shape: no
      `inherits(x, "condition")`, no `conditionMessage()` on a bare
      `errorValue`.
- [ ] AC4: No partial `nested_results` object is constructed on the abort path
      — the cancelled run returns nothing at all, tested.
- [ ] AC5: Each new guard proven by inversion: deleting the cancellation branch
      reddens the AC2 tests, recorded in the work log.
- [ ] AC6: The "Parallel execution" roxygen section
      (`R/nested-tune-grid.R:99`) says what a cancelled run does, distinguished
      from a fold whose worker died; `NEWS.md` entry added.
- [ ] AC7: Profile `verify` slot clean — `devtools::document()` no diff,
      `devtools::test()` and `devtools::check()` clean.

## Coverage

- AC1 → T1
- AC2 → T2, T3, T4
- AC3 → T2, T3
- AC4 → T4
- AC5 → T5
- AC6 → T6
- AC7 → T6

## Tasks

- [ ] T1: Probe by execution what mirai hands back for each cancellation path
      above, and for a killed daemon, against the installed mirai. Record the
      table and the version. Do not infer the codes from the candidate row.
- [ ] T2: Write the failing tests first, in
      `tests/testthat/test-parallel-classify.R`: each cancellation shape →
      `nestedtune_interrupted`; `errorValue` 19 → recorded worker failure.
- [ ] T3: Add a positive cancellation predicate to `classify_fold_result()`
      (`R/parallel.R:155`), beside the `miraiInterrupt` branch and above the
      `failed_fold()` fallback. Classify by the shape expected, never by asking
      whether the value is an error (M07 lesson).
- [ ] T4: End-to-end test in `test-parallel-identity.R`, alongside BC4: cancel
      a real dispatched run, assert the abort, the restored RNG state and kind,
      and that no `nested_results` is returned. Bound it so a failure is an
      error, never a hang.
- [ ] T5: Inversion pass — remove the branch, confirm T2/T4 redden, restore and
      diff. Log the result.
- [ ] T6: Roxygen section + `NEWS.md`; `devtools::document()`, then
      `devtools::test()` and `devtools::check()` clean.

## Work log

- 2026-07-26: created by /milestone-plan — promotes the M07 review candidate row scored 78; sequencing and the IP4 reading were both settled at the plan gate, with escalation to an RB declined.

## Decisions

## Review
