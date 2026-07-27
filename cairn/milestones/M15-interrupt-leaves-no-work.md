# M15: An interrupted run stops the work it started

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Branch/PR:** `m15-interrupt-leaves-no-work`

## Goal

A parallel `nested_tune_grid()` run that is interrupted leaves no fold still
computing on the daemons the user will reuse next.

## Scope

**In:** Cancelling the dispatched map when `dispatch_folds()` unwinds without
returning, so an interrupted run does not leave folds executing; updating the
documented interrupt contract that the change makes stale; and anchoring
`daemons_load_status()`'s "nothing here can hang" comment to the mirai version
its claim was verified against.

**Out:** Any bound on `mirai::collect_mirai()` itself —
`R/nested-tune-grid.R:153-157` declines a per-fold time limit because "a slow
fold and a dead one would be indistinguishable", and nothing here overturns
that; a bound would need its own decision entry. Any new argument on an
exported function (D-018). Reworking the pre-flight probe: `everywhere()` was
shown by execution at this plan's gate to return immediately on a saturated
dispatcher-backed pool, so the blocking-send theory is disproven and only the
comment needs work. All test-suite diagnosability work → M14.

## Acceptance criteria

- [ ] AC1 A parallel `nested_tune_grid()` run whose collect at
      `R/parallel.R:91` is interrupted leaves no outstanding task: a test
      dispatches folds that run measurably long, interrupts during the collect,
      and asserts within a bounded wait that `mirai::status()$mirai` reports
      nothing executing. The test fails against the pre-change code, where the
      same probe reported `executing = 2`.
- [ ] AC2 The cancellation holds for any non-local exit from `dispatch_folds()`
      between the `mirai_map()` at `R/parallel.R:83` and its return, not only a
      console interrupt, and the criterion states which such exits are
      reachable and which are not.
- [ ] AC3 The roxygen interrupt contract at `R/nested-tune-grid.R:172-181`
      describes what happens after this change; no sentence there survives that
      the change made false.
- [ ] AC4 `daemons_load_status()`'s header comment makes no unqualified claim
      that nothing on its path can hang: it names the mirai version its
      `everywhere()` claim was verified against, and the probe output backing
      that version is recorded in the Review section.
- [ ] AC5 A `NEWS.md` entry records the user-visible change in user-facing
      words, naming no milestone.
- [ ] AC6 No exported function's signature changes, and any new control is an R
      option in the `nestedtune.<snake_case>` namespace validated as D-020's is.
- [ ] AC7 The `verify` slot is clean: `devtools::test()` passes, and
      `devtools::check()` is clean (0 errors, 0 warnings; NOTEs justified).

## Coverage

- AC1 → T1, T2
- AC2 → T2, T3
- AC3 → T4
- AC4 → T5
- AC5 → T6
- AC6 → T2
- AC7 → T2, T4, T5, T6

## Tasks

- [x] T1 Write the failing test: dispatch long folds, interrupt the collect,
      assert the pool goes idle within a bounded wait. Confirm it fails first.
- [x] T2 Add the cancelling `on.exit()` around the dispatched map in
      `dispatch_folds()` (`R/parallel.R:83-93`); confirm no exported signature
      moved.
- [x] T3 Enumerate the non-local exits reachable between dispatch and return —
      `collect_mirai()` returns only when every element has resolved, so
      classification cannot be one — and record which AC2 covers.
- [x] T4 Update the roxygen interrupt contract.
- [x] T5 Re-run the saturated-pool `everywhere()` probe against the installed
      mirai, record its output, and rewrite the header comment to its verified
      scope.
- [ ] T6 Add the NEWS entry.

## Work log

- 2026-07-27: created by /milestone-plan.
- 2026-07-27: plan chose cancelling the map on unwind over bounding `collect_mirai()`, because `R/nested-tune-grid.R:153-157` declines a per-fold time limit on the ground that a slow fold and a dead one are indistinguishable, and that stance is not this milestone's to overturn; falsified by a bound that distinguishes them, which would need its own decision entry.
- 2026-07-27: plan chose a comment correction over a code change to the pre-flight probe, because `everywhere()` was shown by execution to return in 0.00 s on a saturated dispatcher-backed pool, disproving the blocking-send theory the scope was drafted around; falsified by a mirai version where the send does block.
- 2026-07-27: criteria audit (fresh-context [O], pre-gate) found the drafted AC2 unsatisfiable — `collect_mirai()` returns only once every element has resolved, so classification always runs with zero outstanding tasks — and it was re-aimed at non-local exits generally; the drafted AC3 was found trivially satisfiable by moving a deadline assignment and was replaced by AC4's version anchor; the formals clause was scoped to exported functions, since `test-parallel-classify.R:439` already asserts it.
- 2026-07-27: implement started on branch `m15-interrupt-leaves-no-work`; pre-gate probes against mirai 2.7.2 / nanonext 1.10.1 reproduced the defect with a real SIGINT (pool left `executing = 2`), confirmed the cancelling `on.exit()` fixes it (`executing = 0`), and found `stop_mirai()` on an already-collected map a harmless no-op.
- 2026-07-27: question gate settled both open choices — unconditional cancel on every exit, and a real-SIGINT test over stand-in folds rather than a simulated unwind.
- 2026-07-27: T1 — `tests/testthat/test-parallel-interrupt.R` delivers a real SIGINT once both stand-in folds have marked themselves started, so the signal cannot race the pre-flight probe; confirmed red against unchanged code (`executing` was 2, expected 0) with both markers present, so the pass is not vacuous.
- 2026-07-27: T2 — unconditional `on.exit(mirai::stop_mirai(mapped))` in `dispatch_folds()`; the new test goes green and the full suite is clean (1216 pass, 0 fail, 0 skip), which includes the formals assertion at `test-parallel-classify.R:439`.
- 2026-07-27: T3 — exits enumerated in this file's Decisions section; one is uncoverable (an error inside `mirai_map()` binds no handle to cancel), and the partial-collect exit AC2 was first drafted around does not exist.
- 2026-07-27: T4 — the interrupt contract now says the folds are cancelled on the way out, and that this holds for any exit once they are dispatched; no sentence there was made false by the change, so the paragraph gained rather than lost. `devtools::document()` clean; full suite and `check()` run at completion.
- 2026-07-27: T5 — probe re-run against mirai 2.7.2 / nanonext 1.10.1: pool `executing 2`, `everywhere()` returned in 0.001 s with the probe unresolved and queued (`awaiting 2`). The header comment now anchors the non-blocking-send claim to that version and states what a version whose send blocked would cost, instead of claiming nothing on the path can hang.

## Decisions

### 2026-07-27: The cancel on unwind is unconditional, not gated on a "finished" flag

`dispatch_folds()` cancels the dispatched map from an unconditional `on.exit()`,
so the normal return path calls `stop_mirai()` too. The alternative — a flag set
once the collect returns, cancelling only when the function is left early — was
declined at the implementation question gate.

Probe against mirai 2.7.2 / nanonext 1.10.1: `stop_mirai()` on a map whose
elements have all resolved returns `FALSE` per element, leaves the collected
values untouched, and leaves `status()$mirai` at `executing 0 completed 2`. There
is nothing for a flag to protect, and the unconditional form covers every exit
between the dispatch and the return rather than only the ones anticipated —
which is what lets AC2's enumeration state what is *reachable* rather than argue
what is *covered*.

Falsified by a mirai version where `stop_mirai()` on a resolved map is not inert:
a collected value damaged or a pool disturbed by it would make the flag necessary.

### 2026-07-27: Which non-local exits between the dispatch and the return are reachable (AC2)

Enumerated at T3, each with what it leaves outstanding:

- **An interrupt during `collect_mirai()`** — reachable, and the folds are still
  executing. This is the defect the milestone exists for; covered by the
  real-SIGINT test.
- **An interrupt during `lapply(collected, classify_fold_result)`** — reachable;
  nothing outstanding, because `collect_mirai()` returns only once every element
  has resolved (probe: `executing 0` on its return). The guard fires and is inert.
- **`classify_fold_result()` aborting** — reachable, and already tested on both
  routes (`nestedtune_interrupted`, `nestedtune_cancelled`); nothing outstanding,
  for the same reason.
- **An error raised by `collect_mirai()` itself** — reachable in principle, not
  producible on demand. Cancelling unconditionally is what covers it without a
  test to name it.
- **Not reachable: any exit past the collect with folds still executing.**
  `collect_mirai()` has no partial return — the finding the pre-gate criteria
  audit made when it retired the drafted AC2.
- **Not covered, and not coverable here: an error raised inside `mirai_map()`
  itself** (`options(warn = 2)` turning the per-fold serialization warning into
  an error would do it). It raises before `mapped` is bound, so no handle to the
  partially dispatched map exists for anyone to cancel. A limit of the API, not
  a choice made here.

## Review
