# M41: `eval_time` reaches the metrics that need it

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP2, GP3
- **Branch/PR:** —

## Goal

Both orchestrators take an `eval_time` argument and forward it untouched to
every `tune` call whose answer depends on it.

## Scope

Surface tier: **user-facing** — the deliverable is a new argument on two
exported functions and the documentation that describes it.

**In:** an `eval_time` argument on `nested_tune_grid()` and
`nested_final_fit()`, defaulting to `NULL`, validated at entry and forwarded
to `tune::tune_grid()` and `tune::last_fit()` on both the serial and the
mirai path; `censored` and `survival` in Suggests so a
dynamic survival metric can prove the value is used rather than accepted;
roxygen on both pages.

**Out:** a `control` argument → nowhere: D-030 settled it, and this milestone
retires the ROADMAP row that still bundled the two halves. `eval_time` is not
even a `control` slot, so D-030's per-slot rule applies without amendment.
Refusing `eval_time` on a non-censored mode → left to tune's own warning
(GP1). Forwarding to `tune::select_best()` → nothing to do: with the argument
`NULL`, `tune:::choose_eval_time()` reads the tuning run's own evaluation
times and `tune:::first_eval_time()` takes element 1 in both branches, so
passing it would change no selection and would duplicate tune's "First
evaluation time" message. Any other `control_grid()` slot → its own decision
under D-030.

## Acceptance criteria

- [ ] AC1: both orchestrators take `eval_time`, defaulting to `NULL`. Each of
      `-1`, `NA_real_`, `"1"`, `Inf`, `numeric(0)` and `c(1, NA_real_)` is
      refused by both with an error whose `conditionCall()` names the function
      the user called, raised before any fitting begins — verified with
      `dispatch_folds()` mocked to signal on the loop path and
      `final_fit_worker()` mocked to signal on the final-fit path. `NULL` and
      a well-formed positive numeric vector pass through untouched, on a
      regression workflow included.
- [ ] AC2: on the censored-regression fixture, every outer fold of a
      `nested_tune_grid()` run completes, and the dynamic survival metric each
      reports at the named evaluation time equals the IPCW-weighted squared
      error the test computes from the definition out of a refit of that
      fold's selected candidate under the fold's recorded seeds, with
      `yardstick::brier_survival()` read beside it as a second reading of the
      same predictions, agreeing with it to tolerance. The fixture test
      asserts at-risk observations and events on both sides of each named
      evaluation time, without which the equality holds vacuously.
- [ ] AC3: two `nested_tune_grid()` runs over the same seed differing only in
      `eval_time` report a different metric on at least one outer fold, and
      each run's per-fold metrics equal a `tune::tune_grid()` +
      `tune::last_fit()` reference the test builds from that fold's own
      `inner_resamples` under the fold's recorded seeds at the same evaluation
      time. The two probes are distinct scalar evaluation times, and a run at
      a multi-element `eval_time` reports the metric its first element names,
      matching what tune does with the same vector.
- [ ] AC4: `nested_final_fit()` tunes and selects under the caller's
      `eval_time` — its retained tuning results equal, candidate for
      candidate, a `tune::tune_grid()` the test builds at the same `eval_time`
      under the object's recorded `tuning_seed`, and its `selected` equals
      `tune::select_best()` on those reference results at that `eval_time`. At
      least one candidate ranks differently between the two evaluation times
      probed, and `selected` differs between the two runs.
- [ ] AC5: under a mirai daemon pool, a `nested_tune_grid()` run at a named
      `eval_time` returns the same per-fold metrics and selections as the
      serial run at the same seed.
- [ ] AC6: `man/nested_tune_grid.Rd` and `man/nested_final_fit.Rd` each carry
      an `\item{eval_time}` entry; `nested_tune_grid()`'s "Differences from
      calling tune directly" section names `eval_time` beside `event_level`
      as settable, and both pages state which `eval_time` values this package
      refuses ahead of tune.
- [ ] AC7: `censored` and `survival` are declared in Suggests and a
      `_R_CHECK_DEPENDS_ONLY_=true` check run passes, every test needing them
      skipping rather than failing; `Rscript -e 'devtools::test()'` clean and
      `Rscript -e 'devtools::check()'` clean (0 errors, 0 warnings, NOTEs
      justified).

## Coverage

- AC1 → T3
- AC2 → T1, T2, T4, T6
- AC3 → T4, T6
- AC4 → T5, T6
- AC5 → T4, T7
- AC6 → T8
- AC7 → T1, T8

## Tasks

- [ ] T1: `censored` and `survival` into `DESCRIPTION` Suggests; a
      `skip_if_no_censored()` guard beside the existing guards in
      `tests/testthat/helper-orchestration.R`; confirm by execution that
      `survival_reg(dist = tune())` on engine `"survival"` fits and predicts
      `type = "survival"`. Write the D-entry (argument + dependency).
- [ ] T2: the survival fixture — `srv_data()`, `srv_workflow()`, `srv_grid()`,
      `srv_metrics()`, `srv_nested()` in `helper-orchestration.R` — and the
      fixture-property test opening a new `tests/testthat/test-eval-time.R`,
      asserting AC2's non-degeneracy clause and that the metric separates the
      two evaluation times.
- [ ] T3: `check_eval_time()` in `R/checks.R` beside `check_event_level()`
      (`R/checks.R:437`), wired into both check blocks ahead of the seed draw
      (`R/nested-tune-grid.R:404`, `R/nested-final-fit.R:202`); AC1 tests.
- [ ] T4: thread `eval_time` through the `nested_tune_grid()` path —
      signature (`R/nested-tune-grid.R:395`) → `dispatch_folds()`
      (`R/parallel.R:194`) → the lean wrapper's positional call and
      `fold_task()` (`R/parallel.R:278-308`, `:1033`) → `nested_fold_fit()`'s
      `tune_grid()` and `last_fit()` (`R/nested-tune-grid.R:475`, `:508`).
      Leave `select_best()` (`:483`) alone and comment why.
- [ ] T5: thread through `nested_final_fit()` (`R/nested-final-fit.R:186`) →
      `final_fit_worker()`'s `tune_grid()` (`R/nested-final-fit.R:262`),
      leaving its `select_best()` (`:277`) alone for the same reason.
- [ ] T6: AC2-AC4 behavioral tests, including the from-the-definition IPCW
      Brier recomputation and the two scalar probes; record the
      oracles in the file header the way `test-event-level.R:1-21` does.
- [ ] T7: AC5 parallel-path test; add its declared bound to the per-file total
      in `helper-time-budget.R` (the M16 lesson: bounded waits do not bound a
      suite).
- [ ] T8: roxygen on both orchestrators, the "Differences from calling tune
      directly" section, NEWS entry; `devtools::document()`;
      `devtools::check()`.

## Work log

- 2026-09-01: created by /milestone-plan.
- 2026-09-01: criteria audit ran in full mode (surface tier user-facing) and returned 12 findings across all six drafted criteria plus one cross-cutting gap. Nine were fixed here: AC1's `.Random.seed` probe dropped (both orchestrators restore the seed on every path, so it was satisfiable by any implementation) and replaced with a mocked-dispatch ordering check plus the accepting side; AC2 gained the completed-folds and at-risk/events non-degeneracy clauses; AC3 gained the fold's own seed recipe and, with AC4, the multi-element `eval_time` probe without which no scalar probe can tell forwarding to `select_best()` from omitting it; AC4's `.selected` corrected to `selected` (`.selected` is the `nested_results` column, not the final-fit field, `R/nested-final-fit.R:296`); AC6 reworded because `nested_final_fit()` has no "Differences from calling tune directly" section and made mechanical against `man/*.Rd`; AC7 added for the Suggests gap. Two went to the gate as questions (AC2's oracle independence, the validation shape) and were settled there.
- 2026-09-01: plan gate chose a `censored` fixture with a dynamic survival metric over an arrival-only proof from tune's "`eval_time` is only used for models with mode censored regression" warning, because only the fixture moves a reported number and only it reaches `select_best()`; cost is 7 new recursive dependencies, five of them compiled. Falsified by the CI legs failing to install `censored`, or by the survival fixture's suite time breaching the per-file budget.
- 2026-09-01: plan gate chose recomputing the IPCW Brier score from the definition, with `yardstick::brier_survival()` read beside it, over `brier_survival()` alone, because the latter is the same implementation `tune` calls and would confirm itself (GP2 wants two independent sources). Falsified by the censoring weights proving unreproducible outside yardstick.
- 2026-09-01: plan gate chose a local `check_eval_time()` validating shape only over delegating to tune entirely or also refusing a non-censored mode, because every other argument on these orchestrators is checked at entry and a tune abort from inside a mirai daemon names a tune frame, while mode appropriateness is upstream's call about upstream's argument (GP1). Falsified by tune's own value validation diverging from this check.
- 2026-09-01: plan gate chose retiring the ROADMAP row's `control` half onto D-030 over keeping a narrowed candidate row, because D-030 already names its own falsifier (a caller needing another slot, or the inner tuning run being retained) and the ROADMAP is 45.5 kB against a 24 kB budget. Falsified by a caller asking for a `control_grid()` slot other than `event_level`.
- 2026-09-01: a second criteria-audit pass over the revised wording (full mode, fresh reader) returned four defects, all fixed: AC3's planted-defect clause was unsatisfiable — verified against `tune:::choose_eval_time()` and `tune:::first_eval_time()`, which take element 1 whether the argument is passed or falls back to the run's own times, so forwarding to `select_best()` discriminates nothing and is now recorded as Out; AC1's probes were all length ≤ 1, admitting an implementation that validates only `eval_time[1]`, and gained `c(1, NA_real_)`; AC1's "before any fold is dispatched" had no referent on the final-fit path, which dispatches no folds, and now names `final_fit_worker()`; AC2's second oracle was satisfied by computing and discarding the value, and now has to agree to tolerance. AC4-AC7 were clean on all five questions.

## Decisions

## Review
