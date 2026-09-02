# M48: `...` reaches the inner tuning call, and every inner control slot is documented as forced, refused, passed through, not returned, or inert

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, IP4, GP3
- **Resolves:** #33 closes, #35 partial
- **Branch/PR:** m048-dots-control-passthrough

## Goal

A user passes `control = tune::control_grid(...)` or `tune::control_bayes(...)` through `...` on `nested_tune_grid()` or
`nested_tune_bayes()`, it reaches the inner tuning call in every fold and in the final fit, and each slot of tune's two
control objects is documented as what this package does with it.

## Scope

**In:** user-facing tier — an exported argument surface. `...` accepts `control` only, on both orchestrators, and any
other name is refused at entry. The control that runs is the caller's (or tune's default when none is passed) with the
forced slots overwritten: `allow_par = FALSE` on both, the fold's tuning seed as the Bayesian `seed`, and `event_level`
from the argument, where a control whose `event_level` disagrees with the argument is refused rather than overwritten.
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

- [ ] AC1: `nested_tune_bayes(object, resamples, control = tune::control_bayes(no_improve = 2, uncertain = 2))` runs on a
      fixture where at least one fold stops before `iter` (its recorded candidate set has fewer than `initial + iter`
      rows), and each completed fold's candidate set is identical to what `tune::tune_bayes()` run by hand under that
      fold's tuning seed with the same control slots plus the forced ones records; asserted by a test.
- [ ] AC2: The control reaches every fold on the parallel path as on the serial one: the AC1 call over two mirai daemons
      returns fold records (`.metrics`, `.selected`, the candidate column, both seed columns) identical to the serial
      run's; asserted by a test in `test-parallel-identity.R`.
- [ ] AC3: Forced slots win and the visible conflict is refused: `nested_tune_bayes(..., control =
      tune::control_bayes(allow_par = TRUE, seed = 999))` returns an object identical to the same call with no control,
      `procedure` attribute included; on both orchestrators, `event_level = "first"` beside a control carrying
      `event_level = "second"` is refused at entry with a classed condition naming both values; each asserted by a test.
- [ ] AC4: `attr(x, "procedure")$control` is the effective control on every result — the caller's slots with `allow_par`
      set `FALSE`, `event_level` set from the argument and the Bayesian `seed` removed — and tune's default control when
      none was passed; `nested_final_fit()` re-runs under it, passing exactly one `control` to the inner call: a test
      asserts the recorded slots on both tuners, and that the final fit's retained tuning run under `no_improve = 2`
      matches a hand-run `tune::tune_bayes()` with the same control and the fit's tuning seed.
- [ ] AC5: A name in `...` other than `control` is refused at entry by both orchestrators with a classed condition naming
      it, and a `control` that is not what the matching `tune::control_*()` returns is refused naming the class expected;
      asserted by tests on both functions.
- [ ] AC6: The "Differences from calling tune directly" section of each help page lists every slot of
      `tune::control_grid()` (grid page) and `tune::control_bayes()` (Bayes page) under exactly one of six headings —
      forced, settable as its own argument, refused, passed through, not returned, inert; a test enumerates the slot
      names from `formals()` of the two control functions, parses the rendered section into heading → names, and asserts
      each slot appears under exactly one heading.
- [ ] AC7: `test-dots-barrier.R` is extended to `nested_tune_bayes()` and its grid entry expectation rewritten to the new
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

- [ ] T1: Tests first: the AC1 hand-run oracle in `test-nested-tune-bayes-oracles.R` on a fixture where `no_improve = 2`
      fires (assert the early stop); AC3 and AC5 refusals in `test-nested-tune-bayes-checks.R` and
      `test-nested-tune-grid-checks.R`; the AC4 recorded slots and final-fit oracle in `test-nested-final-fit-oracles.R`.
- [ ] T2: Thread `control` from both orchestrators through `nested_loop()` (`R/nested-tune-grid.R:463-521`),
      `dispatch_folds()` and its `.args` list (`R/parallel.R:194-320`), `fold_task()` (`R/parallel.R:1040-1061`),
      `nested_fold_fit()` (`R/nested-tune-grid.R:543-575`) into `run_tuner()`; `tuner_control()` (`R/tuner.R:80-97`)
      becomes the merge of the caller's control with the forced slots, still built inside the fold's seed scope.
- [ ] T3: Entry: pull `control` out of `rlang::list2(...)`, refuse every other name; `check_control(control, tuner)` for
      class and the `event_level` conflict, beside the existing checks (`R/nested-tune-grid.R:446-454`,
      `R/nested-tune-bayes.R:185-194`).
- [ ] T4: `new_procedure()` and `procedure_tuner()` (`R/tuner.R:104-124`) carry `control` as a shared slot in effective
      form; `final_fit_worker()` (`R/nested-final-fit.R:277-284`) passes it once; the by-hand recipe in the final-fit
      roxygen (`R/nested-final-fit.R:114-124`) shows it.
- [ ] T5: Parallel and barrier tests: extend `test-parallel-identity.R` with the AC1 control; update the `.args` shapes
      in `test-parallel-payload.R:140-218,332`; extend `test-dots-barrier.R` (AC1/AC2 probes at `:11-66`) to the Bayes
      sibling and rewrite the grid expectation.
- [ ] T6: Docs: rewrite the "Differences" sections (`R/nested-tune-grid.R:371-401`, `R/nested-tune-bayes.R:107-134`)
      under the six headings with the `time_limit` caveat; write the Rd-parsing test for AC6.
- [ ] T7: NEWS entry, D-042 (drafted at plan), DESIGN.md paragraph, verify slot.

## Work log

- 2026-09-02: created by /milestone-plan from issues #33 and #35, on topepo's replies of 2026-09-02.
- 2026-09-02: criteria audit ran in full mode by a fresh [O] reader; for M48 it returned: no D-entry superseding D-030/D-040 (added, D-042); AC3's whole-object identity contradicting AC4's as-passed record (settled: the record is the effective control); `procedure_tuner()` would pass `control` twice (T4); AC5's unbounded Bayes pass-through (gate: `control` only); AC6 testing presence rather than the heading mapping and lacking a heading for `event_level` (both fixed); AC1's discriminator vacuous when no fold stops early (fixture must show the stop); AC7 "rewritten" corrected to "extended", the barrier test never reaching the Bayes sibling.
- 2026-09-02: plan gate chose `...` accepting `control` only on both orchestrators over forwarding the Gaussian-process fitter's options on the Bayes sibling because one enumerable name keeps the two contracts identical (GP3) and every slot topepo named rides inside `control_bayes()`; falsified by a user needing a GP option `control_bayes()` cannot carry.
- 2026-09-02: plan gate chose overwriting `allow_par` and the Bayesian `seed` silently while refusing an `event_level` conflict, over refusing every forced slot, because both controls default `allow_par` to `TRUE` and `seed` to a draw so refusal would reject every default control; falsified by a user surprised by an overwritten slot they set deliberately.
- 2026-09-02: plan gate chose recording the effective control on `procedure` over the control as passed, because the record exists to let `nested_final_fit()` re-run what ran and a forced-slot override must leave the object identical to the default run; falsified by a reader needing both the passed and the effective value of a slot.

## Decisions

## Review
