# M35: The factor level a caller can name as the event

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP1, GP2, GP3
- **Branch/PR:** `m035-event-level`

## Goal

Let a caller name which factor level counts as the event, on both
orchestrators and on both loops, instead of every classification metric being
computed against the first level.

## Scope

User-facing tier: the deliverable is a new argument on two exported functions.

**In:** an `event_level` argument on `nested_tune_grid()` and
`nested_final_fit()`, after `...`, defaulting to `"first"`. It reaches the
`tune::control_grid()` each builds for its inner tuning run, and — on
`nested_tune_grid()` only — a `tune::control_last_fit()` for the outer scoring
fit, which receives no control object today (`R/nested-tune-grid.R:411`), so
outer-fold metrics are computed at `"first"` whatever the inner run did. A
two-class test fixture, and the refusal path for a value outside the two.

**Out:**
- A `control` argument taking tune's own settings object → stays on the
  ROADMAP candidate row this milestone trims. Of `control_grid()`'s ten slots,
  `save_pred`, `extract` and `save_workflow` land on the inner `tune_results`
  that the fold record discards on success (`R/nested-tune-grid.R:435-444`);
  `allow_par`, `parallel_over`, `backend_options`, `workflow_size` and `pkgs`
  are forced or inert under `allow_par = FALSE`; a daemon's `verbose` output is
  not shown. `event_level` is the one slot that changes what is reported.
- `eval_time` and the dynamic survival metrics → the same candidate row. It
  needs `censored` and `survival` as test-only dependencies, a fixture built
  from scratch, and its own oracle work.
- A behavioural assertion that `nested_tune_grid()`'s *inner* run honours the
  setting. Its inner `tune_results` is discarded on success, so the only
  observable is a changed selection, and no fixture can be required to produce
  one. AC4 asserts the inner site on `nested_final_fit()`, which retains its
  tuning run and exposes it through `extract_tune_results()`; the two
  orchestrators build the inner control the same way. Retaining the run on
  `nested_results` → the existing candidate row for it.

## Acceptance criteria

- [ ] AC1: `nested_tune_grid()` and `nested_final_fit()` each take
      `event_level` after `...`, defaulting to `"first"`. A value outside
      `c("first", "second")` — a wrong string, a non-character, a length-2
      character vector, `NA_character_` — is refused by both before anything is
      fitted, and each test asserts the abort's message and the call it names,
      the way `tests/testthat/test-nested-tune-grid-checks.R` asserts the
      existing checks.
- [ ] AC2: `nested_tune_grid()` passes a `tune::control_last_fit()` carrying
      the caller's `event_level` to the outer scoring fit. On the two-class
      fixture the sensitivity it reports for each completed outer fold equals
      the value obtained by refitting that fold's `.selected` candidate on the
      fold's analysis set under its recorded `.outer_fit_seed`, predicting the
      assessment set, and calling `yardstick::sens_vec()` at that same
      `event_level` — the metric computed by yardstick directly, no `tune`
      scoring function involved. The values reported at `"first"` and
      `"second"` differ.
- [ ] AC3: on that fixture, whose outer splits are stratified on the outcome so
      both classes appear in every assessment set, the sensitivity
      `nested_tune_grid()` reports at `event_level = "second"` equals the
      specificity it reports at `"first"`, and the specificity at `"second"`
      equals the sensitivity at `"first"` — both runs at the same seed under
      `yardstick::metric_set(sens, spec)`.
- [ ] AC4: `nested_final_fit()` sets the caller's `event_level` on its inner
      `tune::control_grid()`. On the two-class fixture under
      `yardstick::metric_set(sens, spec)`, the tuning run
      `extract_tune_results()` returns at `"second"` reports the metric values
      a `tune::tune_grid()` the test runs itself under
      `control_grid(allow_par = FALSE, event_level = "second")` reports at the
      same seed, and values differing from the same object built at `"first"`.
      The metric set is named because tune's default classification metrics —
      accuracy, brier_class, roc_auc — return byte-identical values at the two
      levels, so the difference clause is unsatisfiable under them.
- [ ] AC5: on the two-class fixture under `metric_set(sens, spec)` and
      `event_level = "second"`, a `nested_tune_grid()` run at 2 mirai daemons
      and the serial run at the same seed are `identical()` in `.completed`,
      `.metrics`, `.selected`, `.grid`, `.tuning_seed` and `.outer_fit_seed` —
      `.grid` included, which `tests/testthat/test-parallel-identity.R`
      compares nowhere today and which is where the inner run's
      event-level-dependent scoring lands.
- [ ] AC6: `devtools::test()` clean, and `devtools::check()` clean — 0 errors,
      0 warnings, any NOTE justified in the review evidence.

## Coverage

- AC1 → T1, T6
- AC2 → T3, T5, T6
- AC3 → T5, T6
- AC4 → T4, T5, T6
- AC5 → T2, T5, T7
- AC6 → T8, T9

## Tasks

- [x] T0: (discovered) stop the drift check counting a figure that sits inside a
      longer number, which had the suite red on the default branch before this
      milestone changed anything.
- [x] T1: add `check_event_level()` to `R/checks.R` beside `check_param_info()`
      (`R/checks.R:418`), covering the four refusal forms AC1 names.
- [ ] T2: add `event_level` to `nested_tune_grid()` after `...`; thread it
      through `dispatch_folds()` (`R/parallel.R:194-306`) and `fold_task()`
      (`R/parallel.R:917`) to `nested_fold_fit()`, and set it on the inner
      `tune::control_grid()` (`R/nested-tune-grid.R:390`).
- [ ] T3: pass `tune::control_last_fit(event_level = ...)` to the outer
      `last_fit()` (`R/nested-tune-grid.R:411`), which takes no control today.
- [ ] T4: add `event_level` to `nested_final_fit()` and `final_fit_worker()`,
      set on the inner `tune::control_grid()` (`R/nested-final-fit.R:254`).
- [ ] T5: build the two-class fixture in
      `tests/testthat/helper-orchestration.R` — a binary outcome, outer splits
      stratified on it, a ranger classification workflow, a grid, and
      `yardstick::metric_set(sens, spec)` — with a guard asserting both classes
      appear in every assessment set and that sensitivity and specificity
      differ on at least one fold, without which AC2's and AC4's difference
      clauses are falsifiable by correct code.
- [ ] T6: write `tests/testthat/test-event-level.R` — AC2's tune-free
      recomputation, AC3's identity, AC4's inner-run comparison, and AC1's
      refusals on both orchestrators — recording both oracles in the file
      header the way `tests/testthat/test-metrics-argument.R` records O1.
- [ ] T7: extend the parallel-identity coverage to the new fixture (AC5).
- [ ] T8: document `event_level` on both orchestrators; rewrite the
      "Differences from calling tune directly" section
      (`R/nested-tune-grid.R:272-275`), which says there is deliberately no
      `control` argument, to say what is settable and what is not; run
      `devtools::document()`, add the NEWS entry, run `air format .`.
- [ ] T9: full `devtools::check()`; record the NOTEs.

## Work log

- 2026-08-31: created by /milestone-plan.
- 2026-08-31: criteria audit ran in FULL mode (user-facing tier), two rounds, both a fresh [O] reader. Round 1 returned 9 findings across 10 draft criteria; round 2 returned 8 against the revision. Fixed at the gate: every criterion conjoining both orchestrators was unsatisfiable, `nested_final_fit()` calling no `tune::last_fit()` and having no parallel path; the reference loop in `helper-orchestration.R:71-119` re-calls tune and is not an independent oracle for a metric value; the sens/spec identity is symmetric under a level swap and cannot alone catch inverted wiring; no run reports sens/spec unless the metric set names them, and a single-class assessment set gives NA; the parallel comparison pointed at `metric_set(rmse, rsq)`, insensitive to the setting; four criteria bound instruments (a grep, `document()`'s diff, a NEWS entry, a skip) and moved to tasks; two file:line citations were off.
- 2026-08-31: third audit round (full mode, fresh [O] reader) on the written criteria returned 5 findings; all fixed without a further gate round. AC2 named no refit path, though the fold record keeps no model or predictions (`R/nested-tune-grid.R:435-444`) — it now names refitting `.selected` under `.outer_fit_seed`. AC4 named no metric set, and measured against tune 2.1.0 the default classification metrics (accuracy, brier_class, roc_auc) return byte-identical values at the two event levels, making its difference clause unsatisfiable — the asymmetric sens/spec pair is now named. AC5 cited `test-parallel-identity.R:239-262`, which is a deliberately-broken-fixture test ending in `expect_false(serial$.completed[[2L]])`, unfollowable on a clean fixture — it now states its own field list and adds `.grid`, compared nowhere in that file today. T5's fixture guard gained the sens-differs-from-spec clause AC2 and AC4 rest on. AC6 was found instrument-bound and kept: the milestone template mandates the profile's verify and check output as a criterion on every code milestone.
- 2026-08-31: plan gate chose a narrow `event_level` argument over accepting tune's `control` object because eight of `control_grid()`'s ten slots are forced or land on an object the fold record discards; falsified by a user needing a slot other than `event_level`, or by the inner tuning run being retained on `nested_results`.
- 2026-08-31: plan gate chose two independent oracle types over M34's single before/after difference because the change moves a reported number; falsified by the identity oracle proving unrunnable on the fixture.
- 2026-08-31: plan gate chose to leave `nested_tune_grid()`'s inner run behaviourally unasserted over widening scope to retain it; falsified by a fixture in which the event level demonstrably reorders inner candidates.
- 2026-08-31: plan gate chose to leave `eval_time` on its candidate row over planning it as a second milestone now; falsified by a user needing a dynamic survival metric.
- 2026-08-31: /milestone-implement began; branch `m035-event-level` cut from `main` at `e10a8e5`.
- 2026-08-31: implementation gate chose the new outer control object to carry `event_level` alone, a hand-written refusal message matching the sibling checks in `R/checks.R`, and accepting `event_level` on a regression workflow the way tune does.
- 2026-08-31: minor amendment — added discovered task T0. `devtools::test()` was red on the default branch at `e10a8e5` (3 failures, all in `test-drift-manifest.R`): the drift check counted a rendering by plain substring, so `524 B` matched inside the hygiene stamp's unrelated `31,524 B` and, once a real occurrence was perturbed away, the accidental match restored the declared count and the checker's own planted-defect self-test went green. `rendering_pattern()` now anchors each rendering with a lookbehind. Suite green on that file, self-test red on the perturbation again.
- 2026-08-31: T1 — `check_event_level()` added beside `check_param_info()`; refuses a wrong string, a non-character, a length-2 character vector, `NA_character_`, `character(0)` and `NULL`, each with its own diagnosis bullet. `devtools::test()` 1670 pass, 0 fail.

## Decisions

## Review
