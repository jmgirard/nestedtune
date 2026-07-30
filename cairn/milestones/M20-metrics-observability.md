# M20: The metric set a run scored under is provable, on every path and on the object

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4
- **Branch/PR:** `m20-metrics-observability` · https://github.com/jmgirard/nestedtune/pull/21

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

- [x] AC1: `tests/testthat/test-parallel-metrics.R` runs `nested_tune_grid()`
      on the `sep_*` fixture with ≥2 primed mirai daemons — that run **not**
      routed through `memoised()`, whose key ignores daemon state — and asserts
      `last_dispatch()` is `"parallel"`, that every fold's `.metrics` names
      exactly `mae` and `rmse`, and that every fold's `.selected` equals a
      serial run's under the same seed. With `metrics = metrics` replaced by
      `metrics = NULL` at the `mirai_map()` `.args` call in `R/parallel.R` the
      test fails; restored, it passes. Both outputs recorded as review evidence.
- [x] AC2: `test-parallel-metrics.R` is listed in `BUDGETED_FILES`, every call
      in it matching `BUDGETED_WAIT_CALLS` carries a `time_budget_ledger()`
      row, `test-suite-hygiene.R`'s guards pass, and a `METRICS_BUDGET_CEILING_S`
      constant with a test asserting the file's `time_budget_totals()` row
      falls under it. Any wait the six budgeted names cannot see is named in
      the work log. The combined declared worst case across `BUDGETED_FILES`
      is recorded beside its pre-milestone value of 1983.678 s.
- [x] AC3: `nested_tune_grid()`'s `@return` documents the `grid` and `metrics`
      attributes — what each holds, that `grid` is the argument **as given** and
      so may be a grid size rather than the candidates evaluated, and that a row
      subset carries both unchanged.
- [x] AC4: a test asserts `attr(res, "grid")` and `attr(res, "metrics")` are
      identical to the `grid` and a non-`NULL` `metrics` argument passed — the
      metric set bound to a name once and compared to that binding, since two
      `metric_set()` calls are never `identical()` — and that both survive a row
      subset. Deleting either assignment in `new_nested_results()` makes it
      fail; both outputs recorded as review evidence.
- [x] AC5: a ROADMAP candidate row records that `attr(x, "grid")` holds the
      request rather than the candidates evaluated, leaving IP4's "the grid
      actually evaluated" clause unmet whenever a grid size is passed, with a
      falsifying promotion condition.
- [x] AC6: the profile's `verify` slot is clean, and `devtools::check()` passes.

## Coverage

- AC1 → T1, T3
- AC2 → T2
- AC3 → T4
- AC4 → T5, T6
- AC5 → T7
- AC6 → T1–T7

## Tasks

- [x] T1: write `tests/testthat/test-parallel-metrics.R` — daemon-backed
      delivery test per AC1, built on `start_daemons()` (`helper-parallel.R`)
      and the `sep_*` fixture (`helper-orchestration.R:251-284`). Header states
      that the serial comparison pins argument plumbing and **not**
      mode-independence: the path is PCA + `lm` and RNG-free, so an identity
      comparison on it passes vacuously (`test-parallel-identity.R:11-13`).
      Note also that the fixture pins its own generator triple host-side and
      `set_fold_seed()` pins all three inside the daemon, so mirai's ambient
      L'Ecuyer-CMRG streams cannot disturb the separation M18 measured.
- [x] T2: register the file in the budget apparatus — `BUDGETED_FILES`
      (`test-suite-hygiene.R:65-69`), ledger rows in `helper-time-budget.R`,
      `METRICS_BUDGET_CEILING_S` beside `CLASSIFY_BUDGET_CEILING_S`, and the
      guard asserting the file stays under it. Record both budget figures.
- [x] T3: verify AC1 by mutation — set `metrics = NULL` at `R/parallel.R:86`,
      run the new file, record red; restore, re-run, record green.
- [x] T4: document both attributes in `nested_tune_grid()`'s `@return`
      (`R/nested-tune-grid.R:35-40`), not in `@section When a fold fails:`,
      which is where the fold counts sit and has nothing to do with these.
- [x] T5: add the attribute test per AC4 to `test-nested-tune-grid-results.R`,
      and comment `R/nested-results.R:75-76` to record that `NextMethod()`
      already carries both attributes through a subset. (Corrected at review:
      that holds for `[.tbl_df` but not `[.data.frame`, which drops them on a
      column subset — see review finding F1.)
- [x] T6: verify AC4 by mutation — delete each assignment in
      `new_nested_results()` in turn, record red for both, restore.
- [x] T7: add the AC5 candidate row to `cairn/ROADMAP.md`, search-first, and
      the `NEWS.md` entry for the newly documented attributes.

## Work log

- 2026-07-30: review fan-out — 18 findings across three lenses (diff-bug 17, blame-history 1, prior-review 0), scored by a fourth agent. Three actioned at ≥80: F2 (88) added the missing column-subset coverage, F1 (85) corrected a false claim about `[.data.frame` in the comment T5 added, F15 (85) fixed a mis-cited check site in the AC5 row. Fifteen logged below threshold. Post-fix: PASS 1346, check 0/0/0.
- 2026-07-30: review checkpoint — PR #21 opened as draft; all six criteria verified with fresh evidence and ticked under AC fencing; consistency gate clean. Prior-review lens reported zero findings (PR-thread probe empty, archived `## Review` sections the evidence base); blame-history lens reported one (H1, on the `[.nested_results` comment's phrasing). Diff-bug lens still running, so scoring and triage are not yet done.
- 2026-07-30: `devtools::check()` clean — 0 errors, 0 warnings, 0 notes, 3m23s; test suite 80s/130s under check. No prose-guard authored or edited this milestone, so guard-doctrine §8's fresh-context description review does not apply. Status → review.
- 2026-07-30: T7 — AC5 candidate row added, search-first sweep over candidates, `milestones/archive/`, and `DECISIONS.md` finding no overlap. T7 extended (minor task edit) with the `NEWS.md` entry the consistency gate requires: documenting the two attributes changes the public contract, so it is user-visible.
- 2026-07-30: T4 — `@return` now documents both attributes, stating that `grid` is the argument as given (a size, not the candidates evaluated, when a size was passed) and that `metrics` is absent rather than `NULL` when none was supplied. `devtools::document()` regenerated `man/nested_tune_grid.Rd`.
- 2026-07-30: T5 — two tests added to `test-nested-tune-grid-results.R`: the attributes carry the caller's arguments and survive a row subset, and a `metrics = NULL` run carries no metrics attribute at all. `R/nested-results.R:75-76` commented as belt-and-braces, since `NextMethod()` supplies the survival.
- 2026-07-30: T6 — both mutations verified. Deleting either assignment in `new_nested_results()` reds the file with 2 failures each, on the fresh object and on the subset. Restored.
- 2026-07-30: `devtools::test()` clean — FAIL 0, WARN 0, SKIP 0, PASS 1343 (up 6).
- 2026-07-30: T1 — `test-parallel-metrics.R` added; 8 assertions green. Ran T3 ahead of T2 (minor reorder) to prove T1 immediately.
- 2026-07-30: T3 — mutation verified. `metrics = NULL` at the `mirai_map()` `.args` site reds the file with 5 failures across all three assertion classes: metric names in each of the 3 folds, `.selected`, and `.metrics`. Restored, file green, `git diff` on `R/parallel.R` empty.
- 2026-07-30: T2 — file registered in `BUDGETED_FILES`, one `start_daemons` ledger row (120 s), `METRICS_BUDGET_CEILING_S <- 150` with its guard. Waits the guard's six names cannot see, disclosed per AC2: the two `mirai::daemons(0)` calls at :50 and :53, which M16 measured returning in ~0.2 s (they orphan, never block), so neither has a bound to declare.
- 2026-07-30: budget figures — `test-parallel-metrics.R` 120.000 s against its 150 s ceiling; combined across `BUDGETED_FILES` 2103.678 s, up from the pre-milestone 1983.678 s.
- 2026-07-30: `devtools::test()` clean — FAIL 0, WARN 0, SKIP 0, PASS 1337.
- 2026-07-30: start — status in-progress on `m20-metrics-observability`.
- 2026-07-30: created by /milestone-plan, promoting the parallel-`metrics`-delivery candidate row (added 2026-07-30 from M18's Out list) and the unread-attribute third of the metrics-loose-ends row, which is trimmed to its remainder.
- 2026-07-30: criteria audit ([O], fresh context) returned 22 findings; ten fixed into the criteria before the gate — missing `last_dispatch()` assertion; the fixture cache's key ignoring daemon state, which would have served the parallel test a serially-built value; `identical()` false on two `metric_set()` calls; `metrics = NULL` deleting rather than storing the attribute; "the four parallel files" excluding the file this adds; `time_budget_totals()` not summing; a non-discriminating `document()` clause; "wait-shaped" not matching the guard's six names; the serial comparison readable as an IP2 claim it cannot support; `R/nested-results.R:75-76` dead — and three routed to the gate.
- 2026-07-30: plan gate chose a daemon-backed contract test over mocking `mirai_map()`'s `.args` because a mock pins the argument slot rather than the behavior and breaks under a behavior-preserving move of `metrics` into the per-fold payload; falsified by evidence that no daemon-backed test can be kept inside the CI job budget.
- 2026-07-30: plan gate chose documenting `attr(x, "grid")` honestly over storing the expanded grid because deriving what tune actually evaluated needs a rule for folds that disagree and for folds that failed, a design question this milestone would have to answer to state one sentence of documentation; falsified by any consumer needing the evaluated candidates rather than the request.
- 2026-07-30: plan gate chose a new `test-parallel-metrics.R` with its own ceiling over appending to `test-parallel-identity.R` because that file is the subject of the pool-sharing candidate and growing it raises that row's cost; falsified by the new file's fixed pool-start cost proving larger than sharing identity's existing pool would have been.
- 2026-07-30: plan gate chose one milestone over two despite the goal sentence needing "and", because both halves are one thread — the `metrics` argument's observability from the call to the returned object — and neither half fills a session; falsified by the implement phase finding either half needs more than one sitting.

## Decisions

## Review

### Criterion evidence (fresh, by command at review)

- **AC1** — `test-parallel-metrics.R` present, 8 assertions green. Assertions
  confirmed in source: `last_dispatch()` checked on both the serial reference
  (:56) and the parallel run (:66); metric names per fold (:72); `.selected` and
  `.metrics` against the serial reference (:78-79); no `memoised()` call in the
  file. Mutation re-run fresh at review — `metrics = NULL` at the `mirai_map()`
  `.args` site produced **5 failures**; restored, `git diff` on `R/parallel.R`
  empty.
- **AC2** — file listed in `BUDGETED_FILES` (`test-suite-hygiene.R:68`); one
  ledger row (`helper-time-budget.R:208`) whose declared line 58 was verified to
  be the `start_daemons(2)` call; `METRICS_BUDGET_CEILING_S <- 150` (`:256`) with
  its guard (`test-suite-hygiene.R:195`); hygiene guards 16 assertions green. The
  waits the six budgeted names cannot see — `mirai::daemons(0)` at :50 and :53 —
  are disclosed in the ledger comment and the work log. Figures: file **120.000 s**
  against its 150 s ceiling; combined across `BUDGETED_FILES` **2103.678 s**
  against the pre-milestone **1983.678 s**.
- **AC3** — `man/nested_tune_grid.Rd` carries the generated text: `grid` held
  "as it was given ... a positive whole number, not a table of candidates,
  whenever a grid size was passed", `metrics` "absent rather than NULL when none
  was supplied", and "Subsetting rows carries both unchanged".
- **AC4** — both tests present; the metric set is bound once and compared to that
  binding. Mutations re-run fresh at review: deleting `attr(out, "grid")` gave
  **2 failures**, deleting `attr(out, "metrics")` gave **2 failures** — each on
  the fresh object and on the subset. Restored, no stray diff.
- **AC5** — candidate row present in `cairn/ROADMAP.md`, naming the shortfall,
  its reproduction (`grid = 10` storing the integer), and a falsifying promotion
  condition.
- **AC6** — `devtools::test()` FAIL 0 / WARN 0 / SKIP 0 / **PASS 1343**;
  `R CMD check` **0 errors, 0 warnings, 0 notes** (3m23s).

### Independent review — three lenses, one scorer

Three fresh-context reviewers with distinct evidence bases, then a scorer that
generated none of the findings. 18 candidate findings; 3 scored ≥80 and were
actioned, 15 logged below.

**Actioned (≥80).**

- **F2 (88) — no test covered a column subset, so `R/nested-results.R:81-82` had
  zero coverage.** Fixed: `test-nested-tune-grid-results.R` now asserts both
  attributes survive `res[, cols]` on a narrowed-but-still-classed object.
  Verified non-vacuous — breaking the contract (`[.nested_results` dropping both)
  reds it with 4 failures.
- **F1 (85) — the new comment on `R/nested-results.R:75-77` claimed
  `NextMethod()` carries both attributes through a column subset "under
  `[.tbl_df` and `[.data.frame` alike", which is false.** Measured at review:
  `[.data.frame` keeps them through a row subset and DROPS them on a column
  subset; `[.tbl_df` keeps them through every shape. Fixed: the comment now
  states both methods' actual behavior and that the two lines are the guarantee
  under `[.data.frame` rather than a duplicate. The same overclaim in T5's task
  text is corrected in place and marked.
- **F15 (85) — the AC5 candidate row mis-cited the check site**, naming
  `R/nested-tune-grid.R:26-30` (the `@param grid` roxygen block) as where the
  argument is checked. Fixed in place: the row now cites `check_grid()` at
  `R/checks.R:204`.

**Logged, below the action threshold (15).** F5 (70) the new test duplicates
`example_results()` without saying why the fixture is rebuilt un-memoised · H1
(65) "verified at M20" overstated what T6's persisted mutation exercised —
subsumed by the F1 fix · F16 (62) the file's oracle note points at
`test-nested-tune-grid-oracles.R` where O1 on this fixture lives in
`test-metrics-argument.R` · F7 (55) the per-fold loop carries no `info=` label ·
F11 (55) "as it was given" does not address `grid`'s default of 10 · F6 (50) the
instrument's non-vacuity invariant is guarded in a different file · F13 (50)
`expect_null()` beside `expect_false()` is redundant · F10 (45) `x` in `@return`
is not a parameter name · F14 (35) the combined declared worst case exceeds the
CI job cap — pre-existing and unguarded · F3 (30) dplyr/vctrs subsetting bypasses
`[.nested_results`, leaving the fold counts stale — pre-existing IP4 gap · F12
(30) the metrics-absent test is inert to the constructor mutation by design ·
F17 (30) strict `expect_identical()` on cross-process doubles carries no note ·
F9 (25) the `daemons(0)` disclosure is applied only to the new file · F8 (18)
the ceiling comment's headroom claim — refuted by the scorer against two
existing 30 s waits · F4 (5) stale, the Review section was written before the
scorer ran.

### Post-fix verification

`devtools::test()` FAIL 0 / WARN 0 / SKIP 0 / **PASS 1346**; `R CMD check`
**0 errors, 0 warnings, 0 notes** (3m27s); `devtools::document()` no diff;
`cairn_validate` exit 0.

### Consistency gate

- Universal: `cairn_validate` exit 0 — 12 PASS (including `coverage complete`
  and `principles slot valid`), 8 advisories OK. No `DESIGN.md` principle text
  changed, so `cairn_impact --changed` does not apply.
- Toolchain (`r-package` profile `consistency-gate`): `devtools::document()`
  produces no diff; generated `man/` regenerated, not hand-edited;
  `pkgdown::check_pkgdown()` "No problems found"; `NEWS.md` carries the
  user-visible entry; no `README.Rmd` in the repo, so no knit check applies;
  the one new top-level path is `NEWS.md`, already tracked; `devtools::check()`
  clean.
- Returns to `in-progress` this milestone: **0**. Thrash rule does not fire.
