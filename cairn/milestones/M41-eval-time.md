# M41: `eval_time` reaches the metrics that need it

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP2, GP3
- **Branch/PR:** `m041-eval-time` / https://github.com/tidymodels/nestedtune/pull/50

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

- [x] AC1: both orchestrators take `eval_time`, defaulting to `NULL`. Each of
      `-1`, `NA_real_`, `"1"`, `Inf`, `numeric(0)` and `c(1, NA_real_)` is
      refused by both with an error whose `conditionCall()` names the function
      the user called, raised before any fitting begins — verified with
      `dispatch_folds()` mocked to signal on the loop path and
      `final_fit_worker()` mocked to signal on the final-fit path. `NULL` and
      a well-formed positive numeric vector pass through untouched, on a
      regression workflow included.
- [x] AC2: on the censored-regression fixture, every outer fold of a
      `nested_tune_grid()` run completes, and the dynamic survival metric each
      reports at the named evaluation time equals the IPCW-weighted squared
      error the test computes from the definition out of a refit of that
      fold's selected candidate under the fold's recorded seeds, with
      `yardstick::brier_survival()` read beside it as a second reading of the
      same predictions, agreeing with it to tolerance. The fixture test
      asserts at-risk observations and events on both sides of each named
      evaluation time, without which the equality holds vacuously.
- [x] AC3: two `nested_tune_grid()` runs over the same seed differing only in
      `eval_time` report a different metric on at least one outer fold, and
      each run's per-fold metrics equal a `tune::tune_grid()` +
      `tune::last_fit()` reference the test builds from that fold's own
      `inner_resamples` under the fold's recorded seeds at the same evaluation
      time. The two probes are distinct scalar evaluation times, and a run at
      a multi-element `eval_time` reports the metric its first element names,
      matching what tune does with the same vector.
- [x] AC4: `nested_final_fit()` tunes and selects under the caller's
      `eval_time` — its retained tuning results equal, candidate for
      candidate, a `tune::tune_grid()` the test builds at the same `eval_time`
      under the object's recorded `tuning_seed`, and its `selected` equals
      `tune::select_best()` on those reference results at that `eval_time`. At
      least one candidate ranks differently between the two evaluation times
      probed, and `selected` differs between the two runs.
- [x] AC5: under a mirai daemon pool, a `nested_tune_grid()` run at a named
      `eval_time` returns the same per-fold metrics and selections as the
      serial run at the same seed.
- [x] AC6: `man/nested_tune_grid.Rd` and `man/nested_final_fit.Rd` each carry
      an `\item{eval_time}` entry; `nested_tune_grid()`'s "Differences from
      calling tune directly" section names `eval_time` beside `event_level`
      as settable, and both pages state which `eval_time` values this package
      refuses ahead of tune.
- [x] AC7: `censored` and `survival` are declared in Suggests and a
      `_R_CHECK_DEPENDS_ONLY_=true` check run passes, every test needing them
      skipping rather than failing; `Rscript -e 'devtools::test()'` clean and
      `Rscript -e 'devtools::check()'` clean (0 errors, 0 warnings, NOTEs
      justified).

- [ ] AC8: on a `nested_tune_grid()` run at a multi-element `eval_time`,
      `collect_metrics()`, `summary()` and `print()` report each metric
      separately per evaluation time — every row names its evaluation time,
      its `mean` is over that time's fold estimates alone, and its `n` counts
      the folds contributing at that time — and the rows for the two times
      differ. A run at a scalar `eval_time`, and one at `NULL` on the
      regression fixture, each still report one row per metric with `n` equal
      to the completed folds.

## Coverage

- AC1 → T3
- AC2 → T1, T2, T4, T6
- AC3 → T4, T6
- AC4 → T5, T6
- AC5 → T4, T7
- AC6 → T8
- AC7 → T1, T8
- AC8 → T9
- AC6 → T10

## Tasks

- [x] T1: `censored` and `survival` into `DESCRIPTION` Suggests; a
      `skip_if_no_censored()` guard beside the existing guards in
      `tests/testthat/helper-orchestration.R`; confirm by execution that
      `survival_reg(dist = tune())` on engine `"survival"` fits and predicts
      `type = "survival"`. Write the D-entry (argument + dependency).
- [x] T2: the survival fixture — `srv_data()`, `srv_workflow()`, `srv_grid()`,
      `srv_metrics()`, `srv_nested()` in `helper-orchestration.R` — and the
      fixture-property test opening a new `tests/testthat/test-eval-time.R`,
      asserting AC2's non-degeneracy clause and that the metric separates the
      two evaluation times.
- [x] T3: `check_eval_time()` in `R/checks.R` beside `check_event_level()`
      (`R/checks.R:437`), wired into both check blocks ahead of the seed draw
      (`R/nested-tune-grid.R:404`, `R/nested-final-fit.R:202`); AC1 tests.
- [x] T4: thread `eval_time` through the `nested_tune_grid()` path —
      signature (`R/nested-tune-grid.R:395`) → `dispatch_folds()`
      (`R/parallel.R:194`) → the lean wrapper's positional call and
      `fold_task()` (`R/parallel.R:278-308`, `:1033`) → `nested_fold_fit()`'s
      `tune_grid()` and `last_fit()` (`R/nested-tune-grid.R:475`, `:508`).
      Leave `select_best()` (`:483`) alone and comment why.
- [x] T5: thread through `nested_final_fit()` (`R/nested-final-fit.R:186`) →
      `final_fit_worker()`'s `tune_grid()` (`R/nested-final-fit.R:262`),
      leaving its `select_best()` (`:277`) alone for the same reason.
- [x] T6: AC2-AC4 behavioral tests, including the from-the-definition IPCW
      Brier recomputation and the two scalar probes; record the
      oracles in the file header the way `test-event-level.R:1-21` does.
- [x] T7: AC5 parallel-path test; add its declared bound to the per-file total
      in `helper-time-budget.R` (the M16 lesson: bounded waits do not bound a
      suite).
- [x] T8: roxygen on both orchestrators, the "Differences from calling tune
      directly" section, NEWS entry; `devtools::document()`;
      `devtools::check()`.
- [ ] T9: key `per_fold_metrics()` and `summarize_folds()` (`R/nested-results.R`)
      on the evaluation time too, carrying `.eval_time` into the summary rows
      (column shape decided at the implement gate: it changes an exported
      output); update the `collect_metrics()` roxygen contract and the
      `print()` / `summary()` readers; AC8 tests plus the unchanged-shape controls.
- [ ] T10: reword `@param eval_time` on both pages against tune 2.1.0 as
      measured in review (R2–R4: `numeric(0)` aborts in tune, `"1"` is coerced
      and accepted, the not-censored warning keys on the metric set, repeated
      times draw a "0 inappropriate evaluation time points" warning per call);
      assert `\code{eval_time}` inside AC6's "Settable:" sentence (R5); `document()`.

## Work log

- 2026-09-01: created by /milestone-plan.
- 2026-09-01: criteria audit ran in full mode (surface tier user-facing) and returned 12 findings across all six drafted criteria plus one cross-cutting gap. Nine were fixed here: AC1's `.Random.seed` probe dropped (both orchestrators restore the seed on every path, so it was satisfiable by any implementation) and replaced with a mocked-dispatch ordering check plus the accepting side; AC2 gained the completed-folds and at-risk/events non-degeneracy clauses; AC3 gained the fold's own seed recipe and, with AC4, the multi-element `eval_time` probe without which no scalar probe can tell forwarding to `select_best()` from omitting it; AC4's `.selected` corrected to `selected` (`.selected` is the `nested_results` column, not the final-fit field, `R/nested-final-fit.R:296`); AC6 reworded because `nested_final_fit()` has no "Differences from calling tune directly" section and made mechanical against `man/*.Rd`; AC7 added for the Suggests gap. Two went to the gate as questions (AC2's oracle independence, the validation shape) and were settled there.
- 2026-09-01: plan gate chose a `censored` fixture with a dynamic survival metric over an arrival-only proof from tune's "`eval_time` is only used for models with mode censored regression" warning, because only the fixture moves a reported number and only it reaches `select_best()`; cost is 7 new recursive dependencies, five of them compiled. Falsified by the CI legs failing to install `censored`, or by the survival fixture's suite time breaching the per-file budget.
- 2026-09-01: plan gate chose recomputing the IPCW Brier score from the definition, with `yardstick::brier_survival()` read beside it, over `brier_survival()` alone, because the latter is the same implementation `tune` calls and would confirm itself (GP2 wants two independent sources). Falsified by the censoring weights proving unreproducible outside yardstick.
- 2026-09-01: plan gate chose a local `check_eval_time()` validating shape only over delegating to tune entirely or also refusing a non-censored mode, because every other argument on these orchestrators is checked at entry and a tune abort from inside a mirai daemon names a tune frame, while mode appropriateness is upstream's call about upstream's argument (GP1). Falsified by tune's own value validation diverging from this check.
- 2026-09-01: plan gate chose retiring the ROADMAP row's `control` half onto D-030 over keeping a narrowed candidate row, because D-030 already names its own falsifier (a caller needing another slot, or the inner tuning run being retained) and the ROADMAP is 45.5 kB against a 24 kB budget. Falsified by a caller asking for a `control_grid()` slot other than `event_level`.
- 2026-09-01: implement gate confirmed the `censored` + `survival` Suggests addition (D-038) and chose an entry check that refuses only what tune cannot use — non-numeric, missing, negative, non-finite, empty — accepting `0`, duplicates and unsorted times, which `tune:::.filter_eval_time()` normalizes itself. Read from tune 2.1.0: it coerces with `as.numeric()`, drops `NA`, keeps `x >= 0 & is.finite(x)`, uniques, warns about what it dropped, and aborts only when nothing survives.
- 2026-09-01: T1 — `censored` and `survival` into Suggests, `skip_if_no_censored()` beside `skip_if_no_engines()`. Installing `censored` pulled 7 recursive dependencies not already present (`libcoin`, `inum`, `strucchange`, `stabs`, `nnls`, `partykit`, `mboost`), matching the plan gate's estimate. Confirmed by execution that `survival_reg(dist = tune())` on engine `"survival"` fits and predicts `type = "survival"`, returning a `.pred` list-column of `.eval_time`/`.pred_survival` rows. D-038 written; the same commit moves the `<!-- Template:` marker that had swallowed D-037 since M39 to sit above the template block where it belongs, leaving both entries' text untouched.
- 2026-09-01: T2 — the `srv_*` fixture in `helper-orchestration.R` and `test-eval-time.R` opened with its two property tests. The failure times are a mixture of an early burst no log-normal density can reproduce and a long-tailed log-normal no exponential can match, which is what makes the grid rank differently at the two probes; `srv_eval_times()` fixes them at 0.5 and 10, added beyond the plan's five helpers so the tests and the fixture cannot disagree about which times are probed, with `srv_risk_profile()` beside it so a degenerate-fixture failure names which count was zero. Measured on tune 2.1.0 / censored 0.3.4: the log-normal is best at 0.5 by 1.0% and worst at 10, where the Weibull leads by 3.5%. Discrimination checked by planting the defect the second test exists to catch — pinning both runs to the early time — which reddens both order assertions.
- 2026-09-01: T3 — `check_eval_time()` in `R/checks.R` beside `check_event_level()`, wired into both check blocks ahead of the seed draw, and `eval_time = NULL` on both signatures behind the `...` barrier. The unusable-element message names every offending position rather than the first; the positions are interpolated as character because cli reads a length-one numeric as the pluralization quantity, which made a two-position message abort inside cli. AC1's tests cover the six refused shapes on both orchestrators plus the ordering check, mocking `dispatch_folds()` and `final_fit_worker()` so an accepted value has to reach the sentinel and a refused one must not. Discrimination checked by making the check a no-op: nine assertions redden. Three existing formals pins (`test-dots-barrier.R` ×2, `test-parallel-classify.R`) re-agreed to the grown signature, which shifted three `helper-time-budget.R` ledger line numbers by one — the guard M16 built caught all of it.
- 2026-09-01: T4 — `eval_time` threaded from `nested_tune_grid()` through `dispatch_folds()` (serial `lapply` and both mirai argument lists), the lean wrapper's positional call and `fold_task()`, into `nested_fold_fit()`'s `tune_grid()` and `last_fit()`; `tune:::last_fit.workflow()` was read to confirm it takes the argument. `select_best()` is left alone with the comment D-038 states. AC1's pass-through capture asserts `expect_identical()` on what reaches `dispatch_folds()` for each of `NULL`, `0`, `c(0.5, 10)` and `c(10, 0.5, 10)`, so no step on the path may sort or unique the vector. Six worker stubs across five test files were re-agreed to the grown signature, which shifted four more budget-ledger line numbers.
- 2026-09-01: T5 — `eval_time` threaded from `nested_final_fit()` through `final_fit_worker()` into its `tune_grid()`, with the same comment on `select_best()`. AC1's capture asserted on the final-fit path too, on the same four accepted values.
- 2026-09-01: T6 — AC2-AC4 behavioral tests, with three oracle records in the file header. The plan gate's falsifier for the from-the-definition IPCW Brier did not fire: a reverse Kaplan-Meier of the censoring distribution fitted here on the fold's analysis rows reproduces tidymodels' Graf weights exactly (largest absolute difference 0 across the held-out rows), so the recomputation shares no weight machinery with the metric it checks, and on fold 1 at eval_time 0.5 the reported estimate, the from-the-definition value and `yardstick::brier_survival()` all read 0.2588329772. Measured on the fixture: the three folds report 0.2588/0.2397/0.2551 at 0.5 against 0.2280/0.2035/0.2224 at 10, and `nested_final_fit()` selects the log-normal at 0.5 and the Weibull at 10 from the same `tuning_seed`. A run at `c(0.5, 10)` records both rows, reports the 0.5 row identically to the scalar run and selects as the scalar run does, which is tune taking element one; its `select_best()` says so once per fold and the test suppresses that message rather than asserting on its wording. Discrimination checked by making both workers drop the argument: nine assertions across all four tests redden.
- 2026-09-01: T7 — BC8 in `test-parallel-identity.R`: the censored fixture at the late evaluation time, serial against a two-daemon pool, asserting the recorded `.eval_time` on every fold before the whole-object identity so a run that had lost the argument on both sides could not pass. Its `start_daemons()` bound declared in `helper-time-budget.R`. Discrimination checked by replacing the lean wrapper's forwarded `eval_time` with `NULL`, which reddens two of BC8's assertions and nothing else in that file.
- 2026-09-01: T8 — `@param eval_time` on both pages saying what this package refuses ahead of tune and what it passes on untouched; the "Differences from calling tune directly" section names it beside `event_level` and states why `select_best()` is not given it; both by-hand reproduction recipes in the roxygen now carry the argument, which they had silently stopped describing once it was threaded. NEWS entry written. AC6 asserted against the generated `.Rd` files rather than the roxygen, since a `@param` on the wrong `@rdname` would reach only one page.
- 2026-09-01: AC7 evidence — `devtools::check()` clean, 0 errors / 0 warnings / 0 notes, tests `[76s/119s]`. A second run under `_R_CHECK_DEPENDS_ONLY_=true` is also 0/0/0 with FAIL 0, SKIP 85, PASS 2229; the six `test-eval-time.R` blocks that need the new dependencies skip with "{censored} is not installed" and BC8 skips with mirai, so nothing fails where the Suggests are absent.
- 2026-09-01: all eight tasks done, `devtools::test()` clean (FAIL 0, WARN 0, SKIP 0, PASS 2645) and `devtools::check()` clean; status to review.
- 2026-09-01: a second criteria-audit pass over the revised wording (full mode, fresh reader) returned four defects, all fixed: AC3's planted-defect clause was unsatisfiable — verified against `tune:::choose_eval_time()` and `tune:::first_eval_time()`, which take element 1 whether the argument is passed or falls back to the run's own times, so forwarding to `select_best()` discriminates nothing and is now recorded as Out; AC1's probes were all length ≤ 1, admitting an implementation that validates only `eval_time[1]`, and gained `c(1, NA_real_)`; AC1's "before any fold is dispatched" had no referent on the final-fit path, which dispatches no folds, and now names `final_fit_worker()`; AC2's second oracle was satisfied by computing and discarding the value, and now has to agree to tolerance. AC4-AC7 were clean on all five questions.
- 2026-09-01: review — all seven criteria verified with fresh evidence; `cairn_validate` and the r-package consistency gate clean; `format-suggest` was red on one over-width line, fixed with `air format`. Nine findings recorded, dispositions pending at the merge gate.
- 2026-09-01: review returned M41 to in-progress — defect return 1 of the thrash count. Failed: finding R1, the summary over a multi-element `eval_time` averaging across evaluation times with `n` counting fold×time, which the maintainer judged load-bearing under the return floor; no acceptance criterion covered it, so this send-back adds AC8 with Coverage AC8 → T9, and T10 for the doc and test findings R2–R5. R6 absorbed into the existing fixture-cache candidate row at hygiene; R7, R8 rejected as style; R9 fixed here. Merge declined at the gate; PR #50 stays open as a draft.

## Decisions

## Review

Reviewed 2026-09-01 on `m041-eval-time` at PR #50, branch level with
`origin/main` (no merge needed). Evidence is from runs made in this review.

### Acceptance-criteria evidence

- AC1 — `testthat::test_local(filter = "eval-time")`: the four AC1 blocks pass.
  Each of `-1`, `NA_real_`, `"1"`, `Inf`, `numeric(0)` and `c(1, NA_real_)` is
  refused by both orchestrators, `rlang::call_name(conditionCall())` reading
  `nested_tune_grid` / `nested_final_fit`; with `dispatch_folds()` and
  `final_fit_worker()` mocked to a sentinel, no refused value reaches the
  sentinel and every accepted one does; `NULL`, `0`, `c(0.5, 10)` and
  `c(10, 0.5, 10)` reach both entry points under `expect_identical()`.
- AC2 — the AC2 block passes: all three outer folds complete, each reports
  `brier_survival` at `.eval_time` 0.5, and each reported estimate equals the
  from-the-definition IPCW Brier computed from a refit under the fold's
  `.outer_fit_seed` with Graf weights built here from a reverse Kaplan-Meier,
  with `yardstick::brier_survival()` agreeing to `expect_equal()` tolerance.
  The fixture-property block asserts at-risk observations and events on both
  sides of both times, on the whole frame and on every fold's assessment set.
- AC3 — the two AC3 blocks pass: the runs at 0.5 and at 10 disagree on at
  least one fold, each fold's estimate and selection equals the
  `tune_grid()` + `last_fit()` reference rebuilt from that fold's own
  `inner_resamples` under its recorded seeds, and a run at `c(0.5, 10)`
  records both rows, reports the 0.5 row identically to the scalar run and
  selects as it does.
- AC4 — the AC4 block passes: at both evaluation times the retained tuning
  results equal `tune::collect_metrics()` on a reference `tune_grid()` built
  under the object's `tuning_seed`, `selected$dist` equals
  `tune::select_best()` on that reference, the candidate order differs between
  the two times and `selected` differs with it.
- AC5 — `testthat::test_local(filter = "parallel-identity")` passes with no
  skips; BC8 runs the censored fixture serially and under a two-daemon pool at
  the late evaluation time, asserts the recorded `.eval_time` on every fold and
  then `expect_identical(parallel, serial)`.
- AC6 — read directly off the generated pages rather than through the test:
  both `man/nested_tune_grid.Rd` and `man/nested_final_fit.Rd` carry an
  `\item{eval_time}` entry stating what is refused ahead of tune, and
  `nested_tune_grid.Rd`'s "Differences from calling tune directly" reads
  "Settable: `event_level` ... and `eval_time`". The AC6 test block passes;
  finding R5 below records that it is a weaker guard than the criterion.
- AC7 — `censored` and `survival` are in `DESCRIPTION` Suggests.
  `devtools::check()`: 0 errors, 0 warnings, 0 notes, tests `[112s/167s]`.
  A second check under `_R_CHECK_DEPENDS_ONLY_=true`: 0 errors, 0 warnings,
  0 notes, tests `[74s/74s]` — nothing fails where the Suggests are absent.

### Consistency gate

`cairn_validate.py` exit 0, all 16 checks PASS, 18 advisory warnings (the
standing references-staleness set), no release window. No `DESIGN.md`
principle changed, so `cairn_impact.py` did not apply. Toolchain slot:
`devtools::document()` produces no diff; `pkgdown::check_pkgdown()` reports no
problems; `NEWS.md` carries an entry naming no milestone number; no new
top-level files. `devtools::check()` clean as above. CI's `format-suggest` leg
was red on one over-width line in `tests/testthat/test-eval-time.R`; `air
format .` fixed it, whitespace only, committed on the branch.

### Findings and disposition

Three fresh-context reviewers ran: the blame-history and prior-review lenses
each reported no findings (the archive holds no `## Review` sections and the
repo's PR threads carry one real comment, on an untouched file). The diff-bug
lens reported eight, ranked; a ninth is this review's own. Each was verified
against the implementation before disposition.

- R1 (confirmed): a multi-element `eval_time` makes `collect_metrics()`,
  `summary()` and `print()` average across evaluation times.
  `per_fold_metrics()` (`R/nested-results.R:809`) drops `.eval_time` and
  `summarize_folds()` (`:709`) keys on `.metric` and `.estimator` alone, so a
  3-fold run at `c(0.5, 10)` reports one row whose `mean` is over six values
  from two different times and whose `n` reads 6 against a documented "number
  of folds" (`R/nested-results.R:613`). M41 is what makes that state
  reachable; no criterion covers it, and no test exercises
  `collect_metrics()` on a multi-time run. Disposition: floor return — the maintainer judged it a load-bearing defect in what `collect_metrics()` reports; M41 returns to `in-progress` under AC8 / T9.
- R2 (confirmed): the `@param eval_time` sentence "tune discards such values
  with a warning and carries on" is false for two of the six refused shapes.
  Measured against tune 2.1.0: `tune:::.filter_eval_time(numeric(0), fail =
  TRUE)` aborts with "There were no usable evaluation times", and `"1"` is
  coerced by `as.numeric()` and accepted, not discarded. Disposition:
  fix on the return (T10).
- R3 (confirmed): "Ignored, with a warning from tune, for a model whose mode
  is not censored regression" names the wrong trigger.
  `tune:::check_eval_time_arg()` branches on whether the metric set contains a
  survival metric; a censored model scored by a static survival metric gets a
  different warning. The sentence echoes tune's own message text, which is
  where the wording came from. Disposition: fix on the return (T10).
- R4 (confirmed): repeated times are accepted and forwarded by design, and
  tune then warns "There were 0 inappropriate evaluation time points that were
  removed" — once per tune call per fold. Measured on `c(10, 0.5, 10)`. The
  documentation does not mention it. Disposition: fix on the return (T10).
- R5 (confirmed): AC6's test scopes with `sub(".*Differences from calling tune
  directly", "", ...)` and then matches `\code{eval_time}` anywhere after the
  heading, so it would stay green if the argument appeared only in the "Not
  passed on" paragraph. The criterion holds on the artifact — verified above —
  but the guard is weaker than the promise. Disposition: fix on the return (T10).
- R6 (confirmed): `test-fixture-cache.R:231` enumerates the fixture signatures
  the suite asks for and gained no `srv_*` entry, so no pair differing only by
  `eval_time` is covered. `fixture_key()` hashes every matched argument, so
  behavior is right today and only the guard's coverage lags. The same gap is
  already a ROADMAP candidate row from M34 and M35. Disposition:
  follow-up — absorbed into the existing fixture-cache candidate row at post-merge hygiene, no new row.
- R7 (confirmed): `srv_workflow(data)`
  (`tests/testthat/helper-orchestration.R:579`) never uses its `data`
  argument, though every call site passes one. Disposition: rejected — style, no defect.
- R8 (confirmed): the rewritten comment at
  `tests/testthat/test-parallel-classify.R:801` runs past the file's wrapping
  width; `air` does not reflow comments, so the formatter stays green.
  Disposition: rejected — style, `air` is the formatter and it is green.
- R9 (this review): M41's plan commit removed the ROADMAP candidate row that
  bundled the `control` question, leaving the "Generalize the orchestrator
  past `tune_grid()`" row saying "Depends on the `control`/`...` question the
  row above owns" with no such row above it. `cairn_validate`'s dangling-token
  check does not see prose cross-references. Disposition: fixed in this review's return commit.
