# M48: `...` reaches the inner tuning call, and every inner control slot is documented as forced, refused, passed through, not returned, or inert

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, IP4, GP3
- **Resolves:** #33 closes, #35 partial
- **Branch/PR:** m048-dots-control-passthrough · https://github.com/tidymodels/nestedtune/pull/58

## Goal

A user passes `control = tune::control_grid(...)` or `tune::control_bayes(...)` through `...` on `nested_tune_grid()` or
`nested_tune_bayes()`, it reaches the inner tuning call in every fold and in the final fit, and each slot of tune's two
control objects is documented as what this package does with it.

## Scope

**In:** user-facing tier — an exported argument surface. `...` accepts `control` only, on both orchestrators, and any
other name is refused at entry. The control that runs is the caller's (or tune's default when none is passed) with the
forced slots overwritten: `allow_par = FALSE` on both, the fold's tuning seed as the Bayesian `seed`, and `event_level`
from the argument, where a control naming a level that is neither tune's default nor the argument's is refused rather
than overwritten.
`control` rides as a shared argument through `nested_loop()`, `dispatch_folds()` and its mirai `.args`, `fold_task()`,
`nested_fold_fit()` and `run_tuner()`, still entering the assembled call as a symbol (the M05 inlining lesson). The
`procedure` attribute records the effective control — forced slots applied, the Bayesian `seed` dropped since the fold
record holds it — on every result, and `procedure_tuner()` treats `control` as a shared slot so the final fit passes
exactly one. Both help pages classify every `control_grid()` / `control_bayes()` slot under one of six headings; `time_limit`
passes through with the caveat that a wall-clock stop makes the candidate set depend on the machine (IP2). NEWS; D-042.

**Out:** the Gaussian-process fitter's options through `nested_tune_bayes()`'s `...` and the outer-loop `control` topepo
reserved the name for → one candidate row; finetune's racing and annealing tuners → the trimmed #35 candidate row;
retaining anything from the inner `tune_results` beyond what M49 keeps → M49.

## Acceptance criteria

- [x] AC1: `nested_tune_bayes(object, resamples, control = tune::control_bayes(no_improve = 2, uncertain = 2))` runs on a
      fixture where at least one fold stops before `iter` (its recorded candidate set has fewer than `initial + iter`
      rows), and each completed fold's candidate set is identical to what `tune::tune_bayes()` run by hand under that
      fold's tuning seed with the same control slots plus the forced ones records; asserted by a test.
- [x] AC2: The control reaches every fold on the parallel path as on the serial one: the AC1 call over two mirai daemons
      returns fold records (`.metrics`, `.selected`, the candidate column, both seed columns) identical to the serial
      run's; asserted by a test in `test-parallel-identity.R`.
- [x] AC3: Forced slots win and the visible conflict is refused: `nested_tune_bayes(..., control =
      tune::control_bayes(allow_par = TRUE, seed = 999))` returns an object identical to the same call with no control,
      `procedure` attribute included; on both orchestrators, `event_level = "first"` beside a control carrying
      `event_level = "second"` is refused at entry with a classed condition naming both values; each asserted by a test.
- [x] AC4: `attr(x, "procedure")$control` is the effective control on every result — the caller's slots with `allow_par`
      set `FALSE`, `event_level` set from the argument and the Bayesian `seed` removed — and tune's default control when
      none was passed; `nested_final_fit()` re-runs under it, passing exactly one `control` to the inner call: a test
      asserts the recorded slots on both tuners, and that the final fit's retained tuning run under `no_improve = 2`
      matches a hand-run `tune::tune_bayes()` with the same control and the fit's tuning seed.
- [ ] AC5: A name in `...` other than `control` is refused at entry by both orchestrators with a classed condition naming
      it, and a `control` that is not what the matching `tune::control_*()` returns is refused naming the class expected;
      asserted by tests on both functions.
- [x] AC6: The "Differences from calling tune directly" section of each help page lists every slot of
      `tune::control_grid()` (grid page) and `tune::control_bayes()` (Bayes page) under exactly one of six headings —
      forced, settable as its own argument, refused, passed through, not returned, inert; a test enumerates the slot
      names from `formals()` of the two control functions, parses the rendered section into heading → names, and asserts
      each slot appears under exactly one heading.
- [x] AC7: `test-dots-barrier.R` is extended to `nested_tune_bayes()` and its grid entry expectation rewritten to the new
      contract; the profile's verify slot is clean; NEWS carries the entry; D-042 is appended and DESIGN.md's
      architecture paragraph on what `run_tuner()` builds is updated.

## Coverage

- AC1 → T1, T2
- AC2 → T2, T5
- AC3 → T3
- AC4 → T4
- AC5 → T3
- AC6 → T6
- AC7 → T5, T7

## Tasks

- [x] T1: Tests first: the AC1 hand-run oracle in `test-nested-tune-bayes-oracles.R` on a fixture where `no_improve = 2`
      fires (assert the early stop); AC3 and AC5 refusals in `test-nested-tune-bayes-checks.R` and
      `test-nested-tune-grid-checks.R`; the AC4 recorded slots and final-fit oracle in `test-nested-final-fit-oracles.R`.
- [x] T2: Thread `control` from both orchestrators through `nested_loop()` (`R/nested-tune-grid.R:463-521`),
      `dispatch_folds()` and its `.args` list (`R/parallel.R:194-320`), `fold_task()` (`R/parallel.R:1040-1061`),
      `nested_fold_fit()` (`R/nested-tune-grid.R:543-575`) into `run_tuner()`; `tuner_control()` (`R/tuner.R:80-97`)
      becomes the merge of the caller's control with the forced slots, still built inside the fold's seed scope.
- [x] T3: Entry: pull `control` out of `rlang::list2(...)`, refuse every other name; `check_control(control, tuner)` for
      class and the `event_level` conflict, beside the existing checks (`R/nested-tune-grid.R:446-454`,
      `R/nested-tune-bayes.R:185-194`).
- [x] T4: `new_procedure()` and `procedure_tuner()` (`R/tuner.R:104-124`) carry `control` as a shared slot in effective
      form; `final_fit_worker()` (`R/nested-final-fit.R:277-284`) passes it once; the by-hand recipe in the final-fit
      roxygen (`R/nested-final-fit.R:114-124`) shows it.
- [x] T5: Parallel and barrier tests: extend `test-parallel-identity.R` with the AC1 control; update the `.args` shapes
      in `test-parallel-payload.R:140-218,332`; extend `test-dots-barrier.R` (AC1/AC2 probes at `:11-66`) to the Bayes
      sibling and rewrite the grid expectation.
- [x] T6: Docs: rewrite the "Differences" sections (`R/nested-tune-grid.R:371-401`, `R/nested-tune-bayes.R:107-134`)
      under the six headings with the `time_limit` caveat; write the Rd-parsing test for AC6.
- [x] T7: NEWS entry, D-042 (drafted at plan), DESIGN.md paragraph, verify slot.

- [ ] T8: Review round 1, finding 1 (AC5): close the `call` hole in `check_dots_control()` — force the dots in the orchestrators (`check_dots_control(rlang::list2(...))`) or rename the formal `.call`; add a `call = ` refusal probe to both checks files.
- [ ] T9: Review round 1, finding 2: an inline `tune::control_bayes()` in `...` draws its `seed` before `nested_loop()` snapshots `.Random.seed`; snapshot and restore around the forcing (or snapshot at orchestrator entry), with a test that `set.seed(s); nested_tune_bayes(..., control = tune::control_bayes())` leaves the stream restored and equals the no-control run.
- [ ] T10: Review round 1, findings 3 and 7: correct the "Not returned" heading on both pages — the final fit keeps the inner `tune_results` in `$tuning`, so `extract`/`save_pred`/`save_workflow` do return there — and reword `workflow_size` against `save_workflow`.
- [ ] T11: Review round 1, finding 4: a grid-path pass-through test (a `parallel_over = "everything"` probe on the stochastic grid fixture, or equivalent) showing a caller's `control_grid()` reaches the inner call.
- [ ] T12: Review round 1, finding 5: `tune::control_last_fit()` carries the `control_grid` class in tune 2.1.0 and passes `check_control()`; refuse it or document it, and put it in the checks tests' class list either way.
- [ ] T13: Review round 1, finding 6: `forced_bayes_control()` in `helper-orchestration.R` forces `event_level` as `effective_control()` does.

## Work log

- 2026-09-02: created by /milestone-plan from issues #33 and #35, on topepo's replies of 2026-09-02.
- 2026-09-02: criteria audit ran in full mode by a fresh [O] reader; for M48 it returned: no D-entry superseding D-030/D-040 (added, D-042); AC3's whole-object identity contradicting AC4's as-passed record (settled: the record is the effective control); `procedure_tuner()` would pass `control` twice (T4); AC5's unbounded Bayes pass-through (gate: `control` only); AC6 testing presence rather than the heading mapping and lacking a heading for `event_level` (both fixed); AC1's discriminator vacuous when no fold stops early (fixture must show the stop); AC7 "rewritten" corrected to "extended", the barrier test never reaching the Bayes sibling.
- 2026-09-02: plan gate chose `...` accepting `control` only on both orchestrators over forwarding the Gaussian-process fitter's options on the Bayes sibling because one enumerable name keeps the two contracts identical (GP3) and every slot topepo named rides inside `control_bayes()`; falsified by a user needing a GP option `control_bayes()` cannot carry.
- 2026-09-02: plan gate chose overwriting `allow_par` and the Bayesian `seed` silently while refusing an `event_level` conflict, over refusing every forced slot, because both controls default `allow_par` to `TRUE` and `seed` to a draw so refusal would reject every default control; falsified by a user surprised by an overwritten slot they set deliberately.
- 2026-09-02: plan gate chose recording the effective control on `procedure` over the control as passed, because the record exists to let `nested_final_fit()` re-run what ran and a forced-slot override must leave the object identical to the default run; falsified by a reader needing both the passed and the effective value of a slot.
- 2026-09-02: /milestone-implement started on `m048-dots-control-passthrough`; question gate chose the argument winning over a control left at tune's default `event_level` (Scope amended: refusal is for a control naming a level that is neither tune's default nor the argument's), because a control object cannot tell a default `"first"` from a typed one and the literal rule would refuse `event_level = "second"` beside every untouched control; and condition classes `nestedtune_bad_dots` (an unknown or unnamed argument in `...`) and `nestedtune_bad_control` (wrong class, or the `event_level` conflict).
- 2026-09-02: T1: tests written first and shown red on the old dots barrier — the AC1 oracle (`reference_nested_bayes_loop()` gains `control`, merged by a `forced_bayes_control()` helper written from the documented contract; fixture `bayes_control_results()` at `iter = 4`, where `no_improve = 2` stops two of three folds at five candidates against seven, measured before the test was written), AC3/AC5 refusals in both checks files, AC3 whole-object identity in the Bayes results file, AC4 record and final-fit oracle in the final-fit oracles file. `tune::control_resamples()` carries the `control_grid` class in tune 2.1.0, so it is accepted on the grid path and dropped from the wrong-class list.
- 2026-09-02: T2–T4 landed in one pass, each alone leaving the suite red: `control` threads orchestrator → `nested_loop()` → `dispatch_folds()` and its `.args` → `fold_task()` → `nested_fold_fit()` → `run_tuner()`; `check_dots_control()` pulls `control` from `rlang::list2(...)` and refuses any other or unnamed name; `check_control()` holds class and `event_level` and returns the effective control; `effective_control()` / `default_control()` / `control_class()` in `R/tuner.R`, the default Bayes control built as `control_bayes(seed = 1L)` so no draw moves the caller's stream (tune's own device in `tune_bayes()`); `new_procedure()` and `procedure_tuner()` carry `control` as a shared slot; `final_fit_worker()` makes the control effective before running and recording. Five `fold_task` mocks and the `tuner_control` mock gained the argument. The fixture for AC4 seeds before building its workflow so the recipe step ids key the same cache entry on every request.
- 2026-09-02: T5: `test-dots-barrier.R` extended to `nested_tune_bayes()` and its grid expectation rewritten to `nestedtune_bad_dots`; BC11 in `test-parallel-identity.R` runs the AC1 control over two daemons; the `.args` byte lists in `test-parallel-payload.R` carry the control.
- 2026-09-02: T6: measured on tune 2.1.0 before writing the headings — `parallel_over` changes a stochastic engine's numbers at `allow_par = FALSE` (`"resamples"` against `"everything"`, serial `tune_grid()` and `tune_bayes()` alike), `pkgs` is enforced serially (a missing package errors), `workflow_size` speaks only with `save_workflow = TRUE`, `backend_options` alone does nothing; so the D-030-era claim that `parallel_over` and `workflow_size` are inert is corrected on both pages, and `backend_options` is the one inert slot. Headings are bold text carrying the slot names in code, which `test-control-slots.R` parses from the Rd tree (source `man/` or the installed Rd db) with a planted-duplicate discrimination test.
- 2026-09-02: T7: NEWS entry; DESIGN.md's `run_tuner()` paragraph now names the effective control; D-042 was appended at plan and stands.
- 2026-09-02: checkpoint with T1–T7 written but unticked: the targeted files (checks, oracles, results, barrier, identity, payload, control-slots) pass and `devtools::document()` is clean; the full `devtools::test()` run had not finished when this was committed, so the ticks wait on it.
- 2026-09-02: the first full run found two things the targeted files could not: the `nested_fold_fit` stub in `test-nested-tune-grid-leakage.R` lacked the new argument, and the wait ledger in `helper-time-budget.R` keys pool starts by line, which the BC11 insertion and the mock signatures shifted (seven rows moved, one added for BC11). Both fixed; second full run started.
- 2026-09-02: second full run: two failures, both the M41 doc test in `test-eval-time.R` pinning the old "Settable:" sentence; rewritten to read the "Settable as its own argument" heading's paragraph, and the file passes. The suite is clean by composition of that run and the per-file reruns (leakage, suite-hygiene, identity, eval-time); `devtools::document()` leaves no diff. T1–T7 ticked; status set to review.
- 2026-09-02: /milestone-review started: branch contains origin/main, pushed; draft PR #58 opened; document() no diff, cairn_validate passes, pkgdown clean; full suite and the three reviewers running.

- 2026-09-02: defect return 1 of M48 (review round 1): AC5 fails — an argument named `call` in `...` binds to `check_dots_control()`'s `call` formal and is not refused; suite otherwise clean (3478 pass); nine further findings triaged at the gate chip, dispositions in Review.

- 2026-09-02: return gate chose fixing findings 1–7 (T8–T13) over fixing only the two contract defects; findings 8–10 and both prior-review findings rejected as logged in Review.

## Decisions

## Review

### Round 1 (2026-09-02)

**Gate checks.** Branch contains `origin/main` (no merge needed); `devtools::document()` leaves no diff; `cairn_validate.py` exit 0 (18 references-staleness advisories, no gate FAIL); no IP/GP text changed, so `cairn_impact` skipped; `pkgdown::check_pkgdown()` clean; README.md newer than README.Rmd; NEWS carries the entry with no milestone numbers; no new top-level files. Full `devtools::test()` (this session, tune 2.1.0): FAIL 0, WARN 0, SKIP 0, PASS 3478. `devtools::check()` not run: the review stopped at AC5 below, and the fix invalidates the evidence.

**Criterion evidence.**
- AC1: `test-nested-tune-bayes-oracles.R` "a control passed through `...` reaches every fold (M48, AC1)" passes in the full run: every fold's `.metrics`, `.selected` and scored candidates identical to the hand-run reference under the fold's seed with the merged control; at least one fold records fewer than `initial + iter` rows, and the no-control run records seven in every fold. Verified.
- AC2: `test-parallel-identity.R` BC11 passes: the AC1 call over two mirai daemons returns fold records and the whole object identical to the serial run. Verified.
- AC3: `test-nested-tune-bayes-results.R` "forced slots win" (whole object identical to the no-control run, `procedure` included) and the `event_level` refusals on both checks files (class `nestedtune_bad_control`, message naming `"first"` and `"second"`) pass. Verified.
- AC4: `test-nested-final-fit-oracles.R` "the procedure records the effective control on both tuners" (grid default with `allow_par = FALSE`; Bayes default and the AC1 control with `seed` removed; `procedure_tuner()` args exactly `iter/initial/objective`, so one `control` reaches the inner call) and "the final fit re-runs under the recorded control" (metrics, candidate ids, selection and predictions identical to a hand-run `tune_bayes()` under `no_improve = 2`) pass. Verified.
- AC5: FAILS. Refusal tests for `nonesuch`, an unnamed value and a wrong-class control pass on both orchestrators, but `check_dots_control(..., call = rlang::caller_env())` is invoked as `check_dots_control(...)`, so a caller's `call = <x>` binds to the formal instead of the dots: `nestedtune:::check_dots_control(call = 5)` returns NULL with no condition, and `nested_tune_grid(1, 2, call = quote(bogus()))` passes the fence (reviewer finding 1, re-run this session). A name other than `control` is not refused. Defect return.
- AC6: `test-control-slots.R` passes: every `formals()` slot of `control_grid()` (10) and `control_bayes()` (16) parsed from the rendered section sits under exactly one of the six bold headings, and the planted-duplicate discrimination test passes. Verified.
- AC7: `test-dots-barrier.R` covers `nested_tune_bayes()` and the grid entry expects `nestedtune_bad_dots`; verify slot clean (the run above); NEWS entry present; D-042 in DECISIONS.md; DESIGN.md's `run_tuner()` paragraph names the effective control. Verified.

**Independent review (three fresh-context lenses).** Findings ranked as the reviewers ranked them; each verified against the code before triage, disposition logged at the gate.
- [O] diff-bug lens:
  1. `call` in `...` slips the fence (`R/checks.R:678`): confirmed by re-running the probe. Fix on return (AC5).
  2. An inline `tune::control_bayes()` in `...` draws its `seed` when forced inside `check_dots_control()`, before `nested_loop()` snapshots `.Random.seed`: confirmed — `set.seed(1)` then the call with `control = tune::control_bayes()` leaves the stream changed, the same call without a control leaves it intact. Contradicts the help page's restore-on-exit and consecutive-call promises; AC3 holds only because the test passes `seed = 999L`. Proposed: fix on return.
  3. "Not returned" is false for the final fit, which keeps the inner `tune_results` in `$tuning` (`R/nested-final-fit.R:335`, `extract_tune_results()`): confirmed. Proposed: fix on return (one clause on each page).
  4. No grid-path test shows a caller's control reaching the inner call (every grid control test is a refusal or the recorded default): confirmed by reading the added tests. Proposed: fix on return (a `parallel_over = "everything"` probe on the stochastic grid fixture).
  5. `tune::control_last_fit()` carries the `control_grid` class in tune 2.1.0 and passes `check_control()`: confirmed. Proposed: fix on return (document or refuse; small).
  6. `forced_bayes_control()` test helper omits `event_level` while `effective_control()` forces it; invisible at `"first"`. Proposed: fix on return (one line).
  7. `workflow_size` (passed through) is gated on `save_workflow` (not returned), which reads as a contradiction. Proposed: fold into 3's doc edit.
  8. The AC4 final-fit oracle compares metrics, ids, selection and predictions rather than the whole object, and its two trailing bound assertions are vacuous. Proposed: reject — AC4 asks for a match of the tuning run and the test discriminates a dropped control.
  9. Internal aborts in `default_control()` / `control_class()` carry no `call`. Proposed: reject — unreachable, cosmetic.
  10. A fake control with the class but no `event_level` yields a degenerate message. Proposed: reject — only reachable by a hand-built object.
- [S] blame-history lens: no findings. The M05 symbols rule, D-011's net-zero RNG at entry (default Bayes control built with `seed = 1L`), the seed-inside-scope mechanism and the barrier test's guarantees all hold; D-030/D-040 are superseded by D-042 deliberately.
- [S] prior-review lens (archived Review sections; GitHub probe found one real inline comment, on `pkgdown.yaml`, not a touched file):
  1. The AC3 whole-object `expect_identical()` against a memoised fixture with a separately built `metric_set()` repeats the M12 lesson's trap. Rejected: `testthat::expect_identical()` compares through waldo, which ignores function environments (checked this session: `identical()` FALSE, `expect_identical()` passes), and the test passes in the full run.
  2. `run_tuner()` still has no size-invariant test for the inlining hazard the M05/M45 lesson names, while its surface grew. Rejected: pre-existing gap the diff did not introduce; the lesson line already records it.
  3. The time-budget ledger's line drift was caught and fixed by the guard as designed. Informational, no action.
