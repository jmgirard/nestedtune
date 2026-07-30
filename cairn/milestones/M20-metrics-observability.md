# M20: The metric set a run scored under is provable, on every path and on the object

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4
- **Branch/PR:** —

## Goal

The `metrics` argument is proved to reach the parallel dispatch path, and the
results object's own record of the grid and metrics it ran under is documented,
asserted, and honest about what it does not yet hold.

## Scope

**In:** A daemon-backed test that the caller's metric set reaches folds running
on mirai workers, red under a `metrics = NULL` mutation at `R/parallel.R`'s
`mirai_map()` `.args` site. Its registration in M16's time-budget apparatus,
with its own ceiling. Documentation and assertions for the `grid` and `metrics`
attributes on `nested_results`, which `R/nested-results.R:26-27` writes and
nothing in `R/` reads.

**Out:**
- Retaining the inner tuning run on `nested_results` → stays on the metrics
  ROADMAP row; it is an API addition with a memory cost (GP4), not plumbing.
- Changing `reg_metrics()` away from tune's regression default → stays on the
  same row, with its rationale weakened: M18's `sep_*` fixture already gives
  the suite a metric set that separates, so the shared fixture no longer has to.
- Making `attr(x, "grid")` hold the candidates actually evaluated → new
  candidate row (AC5). Recording the request is what the code does today; AC3
  documents that honestly rather than widening this milestone into deriving the
  expanded grid from a run whose folds may disagree.

## Acceptance criteria

- [ ] AC1: `tests/testthat/test-parallel-metrics.R` runs `nested_tune_grid()`
      on the `sep_*` fixture with ≥2 primed mirai daemons — that run **not**
      routed through `memoised()`, whose key ignores daemon state — and asserts
      `last_dispatch()` is `"parallel"`, that every fold's `.metrics` names
      exactly `mae` and `rmse`, and that every fold's `.selected` equals a
      serial run's under the same seed. With `metrics = metrics` replaced by
      `metrics = NULL` at the `mirai_map()` `.args` call in `R/parallel.R` the
      test fails; restored, it passes. Both outputs recorded as review evidence.
- [ ] AC2: `test-parallel-metrics.R` is listed in `BUDGETED_FILES`, every call
      in it matching `BUDGETED_WAIT_CALLS` carries a `time_budget_ledger()`
      row, `test-suite-hygiene.R`'s guards pass, and a `METRICS_BUDGET_CEILING_S`
      constant with a test asserting the file's `time_budget_totals()` row
      falls under it. Any wait the six budgeted names cannot see is named in
      the work log. The combined declared worst case across `BUDGETED_FILES`
      is recorded beside its pre-milestone value of 1983.678 s.
- [ ] AC3: `nested_tune_grid()`'s `@return` documents the `grid` and `metrics`
      attributes — what each holds, that `grid` is the argument **as given** and
      so may be a grid size rather than the candidates evaluated, and that a row
      subset carries both unchanged.
- [ ] AC4: a test asserts `attr(res, "grid")` and `attr(res, "metrics")` are
      identical to the `grid` and a non-`NULL` `metrics` argument passed — the
      metric set bound to a name once and compared to that binding, since two
      `metric_set()` calls are never `identical()` — and that both survive a row
      subset. Deleting either assignment in `new_nested_results()` makes it
      fail; both outputs recorded as review evidence.
- [ ] AC5: a ROADMAP candidate row records that `attr(x, "grid")` holds the
      request rather than the candidates evaluated, leaving IP4's "the grid
      actually evaluated" clause unmet whenever a grid size is passed, with a
      falsifying promotion condition.
- [ ] AC6: the profile's `verify` slot is clean, and `devtools::check()` passes.

## Coverage

- AC1 → T1, T3
- AC2 → T2
- AC3 → T4
- AC4 → T5, T6
- AC5 → T7
- AC6 → T1–T7

## Tasks

- [ ] T1: write `tests/testthat/test-parallel-metrics.R` — daemon-backed
      delivery test per AC1, built on `start_daemons()` (`helper-parallel.R`)
      and the `sep_*` fixture (`helper-orchestration.R:251-284`). Header states
      that the serial comparison pins argument plumbing and **not**
      mode-independence: the path is PCA + `lm` and RNG-free, so an identity
      comparison on it passes vacuously (`test-parallel-identity.R:11-13`).
      Note also that the fixture pins its own generator triple host-side and
      `set_fold_seed()` pins all three inside the daemon, so mirai's ambient
      L'Ecuyer-CMRG streams cannot disturb the separation M18 measured.
- [ ] T2: register the file in the budget apparatus — `BUDGETED_FILES`
      (`test-suite-hygiene.R:65-69`), ledger rows in `helper-time-budget.R`,
      `METRICS_BUDGET_CEILING_S` beside `CLASSIFY_BUDGET_CEILING_S`, and the
      guard asserting the file stays under it. Record both budget figures.
- [ ] T3: verify AC1 by mutation — set `metrics = NULL` at `R/parallel.R:86`,
      run the new file, record red; restore, re-run, record green.
- [ ] T4: document both attributes in `nested_tune_grid()`'s `@return`
      (`R/nested-tune-grid.R:35-40`), not in `@section When a fold fails:`,
      which is where the fold counts sit and has nothing to do with these.
- [ ] T5: add the attribute test per AC4 to `test-nested-tune-grid-results.R`,
      and comment `R/nested-results.R:75-76` to record that `NextMethod()`
      already carries both attributes through a subset — verified at plan time
      against row, column, logical and negative indices — so the two lines are
      belt-and-braces rather than load-bearing.
- [ ] T6: verify AC4 by mutation — delete each assignment in
      `new_nested_results()` in turn, record red for both, restore.
- [ ] T7: add the AC5 candidate row to `cairn/ROADMAP.md`, search-first.

## Work log

- 2026-07-30: created by /milestone-plan, promoting the parallel-`metrics`-delivery candidate row (added 2026-07-30 from M18's Out list) and the unread-attribute third of the metrics-loose-ends row, which is trimmed to its remainder.
- 2026-07-30: criteria audit ([O], fresh context) returned 22 findings; ten fixed into the criteria before the gate — missing `last_dispatch()` assertion; the fixture cache's key ignoring daemon state, which would have served the parallel test a serially-built value; `identical()` false on two `metric_set()` calls; `metrics = NULL` deleting rather than storing the attribute; "the four parallel files" excluding the file this adds; `time_budget_totals()` not summing; a non-discriminating `document()` clause; "wait-shaped" not matching the guard's six names; the serial comparison readable as an IP2 claim it cannot support; `R/nested-results.R:75-76` dead — and three routed to the gate.
- 2026-07-30: plan gate chose a daemon-backed contract test over mocking `mirai_map()`'s `.args` because a mock pins the argument slot rather than the behavior and breaks under a behavior-preserving move of `metrics` into the per-fold payload; falsified by evidence that no daemon-backed test can be kept inside the CI job budget.
- 2026-07-30: plan gate chose documenting `attr(x, "grid")` honestly over storing the expanded grid because deriving what tune actually evaluated needs a rule for folds that disagree and for folds that failed, a design question this milestone would have to answer to state one sentence of documentation; falsified by any consumer needing the evaluated candidates rather than the request.
- 2026-07-30: plan gate chose a new `test-parallel-metrics.R` with its own ceiling over appending to `test-parallel-identity.R` because that file is the subject of the pool-sharing candidate and growing it raises that row's cost; falsified by the new file's fixed pool-start cost proving larger than sharing identity's existing pool would have been.
- 2026-07-30: plan gate chose one milestone over two despite the goal sentence needing "and", because both halves are one thread — the `metrics` argument's observability from the call to the returned object — and neither half fills a session; falsified by the implement phase finding either half needs more than one sitting.

## Decisions

## Review
