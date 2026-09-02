# M45: The inner loop takes its tuner as an argument, and `nested_tune_bayes()` is its second consumer

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Resolves:** #35 partial
- **Principles touched:** IP2, IP4, GP1, GP2, GP3
- **Branch/PR:** `m045-nested-tune-bayes`

## Goal

A user runs nested cross-validation around `tune::tune_bayes()` through
`nested_tune_bayes()`, and the outer loop that runs it is the one
`nested_tune_grid()` runs, told which tuner to call rather than copied.

## Scope

Surface tier: user-facing — a new export and a new attribute on the results
object. Absorbs the ROADMAP candidate row for issue #35 (added 2026-08-31).

**In:** an internal *tuner description* — the tune function to call and the
static arguments only that tuner takes — built by each orchestrator and
threaded through `nested_fold_fit()`, `dispatch_folds()`, the mirai lean
wrapper, `fold_task()` and `final_fit_worker()` in place of the `grid` formal,
the inner call assembled with `rlang::call2()`; `nested_tune_bayes()` with
`iter`, `initial` and `objective` as its own arguments per D-030 (D-040), the
Gaussian-process seed fixed from the fold's tuning seed; entry checks for the
three; a per-fold candidate record that carries `.iter`; a `procedure`
attribute recording what ran, on both orchestrators' results; oracles, RNG and
parallel-identity tests for the new path; docs.

**Out:** a final fit for the Bayesian procedure → M46. finetune's racing and
annealing tuners, and `control_bayes()`'s `no_improve`, `uncertain` and
`time_limit` → ROADMAP candidate row (added 2026-09-01). `initial` as a
`tune_results` object → refused (D-040). A `control` argument or `...`
pass-through → stays closed per D-030/D-038 (issue #33). tune's finalization
of unknown parameter ranges against the inner rset's full frame → ROADMAP
candidate row (added 2026-09-01), an IP1 question on the grid path today.

## Acceptance criteria

- [ ] AC1: `nested_tune_bayes(object, resamples, ..., iter = 10, param_info = NULL, metrics = NULL, initial = 5, objective = tune::exp_improve(), event_level = "first", eval_time = NULL)` is exported and returns a `nested_results`; every S3 method `NAMESPACE` registers on that class (`grep 'nested_results)' NAMESPACE`) runs on a `nested_tune_bayes()` result without error, `autoplot()` at each `type`.
- [ ] AC2 (live oracle; RB tripwire: no-oracle — the trade accepted at the plan gate, work log 2026-09-01): each completed fold's `.metrics` and `.selected` are identical to a hand-rolled reference loop in `helper-orchestration.R` written from the seed contract (`set.seed(s)`, one `sample.int(.Machine$integer.max, 2 * n)`, kind pinned per fold) that calls `tune::tune_bayes()` on the fold's inner `rset` with the same `iter`, `initial`, `objective` and `control_bayes(seed = <the fold's tuning seed>, allow_par = FALSE)`, then `tune::last_fit()` on the outer split; asserted at `iter = 2` on the deterministic and the stochastic-engine fixtures.
- [ ] AC3 (invariant oracle): at `iter = 0`, which `tune:::check_iter()` accepts at tune 2.1.0, `nested_tune_bayes(initial = k, param_info = p)` and `nested_tune_grid(grid = g, param_info = p)` under the same seed give identical `.metrics` and `.selected` in every fold, and each fold's `.grid` is the grid record plus an `.iter` column of `0L`; `g` is `dials::grid_space_filling(p, size = k)` and the fixture's parameter space is integer-only, where that draw does not depend on the seed (a continuous parameter makes it seed-dependent, measured 2026-09-01), so one grid serves every fold through the public function.
- [ ] AC4 (IP2): for `nested_tune_bayes()`, the same seed gives an identical result and a different seed different numbers; fold results do not depend on fold order, on the ambient RNG state or on its kind; the caller's RNG state and kind are restored after a completed run, a run with failed folds and an aborted call, and a session with no `.Random.seed` is left with a valid one; a mirai run at two daemon counts above the threshold is `identical()` to the serial run as a whole object. `control_bayes(seed = seeds[[1L]])` is constructed inside the fold's seed scope, and AC2's reference passes the same seed.
- [ ] AC5 (IP4): each completed fold's `.grid` holds one row per candidate that fold's `tune_bayes()` scored with an `.iter` column joined from the tuning run's top-level `.iter` (its per-resample `.metrics` frames carry none), and `print()`'s candidates-searched line and `summary()`'s candidate counts count those rows; a result of either orchestrator carries a `procedure` attribute — a named list naming the tuner (`"tune_grid"` or `"tune_bayes"`) and its static arguments (`grid`; or `iter`, `initial`, `objective`; and `param_info`, `event_level`, `eval_time` on both) — that joins `run_attributes()` and so survives every dplyr and vctrs door that set governs; `attr(x, "grid")` and `attr(x, "metrics")` are unchanged on the grid path, and `attr(x, "grid")` is `NULL` on a Bayesian result, documented.
- [ ] AC6 (entry checks): `nested_tune_bayes()` refuses before any fitting, naming the user's call, each with its own condition class: an `iter` that is not a single non-negative whole number; an `initial` that is not a single whole number of at least 2, a `tune_results` included; an `objective` not inheriting `acquisition_function`. Every `check_*()` call in `nested_tune_grid()`'s body other than `check_grid()` and `check_grid_params()` is also called in `nested_tune_bayes()`'s body, and a test fires each through it.
- [ ] AC7 (the grid path is unchanged): `nested_tune_grid()` on the deterministic and stochastic fixtures under a fixed seed gives `.metrics`, `.selected` and `.grid` `identical()` at `origin/main` and at the branch head, compared at review by running both; the grid-path oracle tests pass with their expectations unedited.
- [ ] AC8 (docs): `nested_tune_bayes()`'s help page has a "Differences from calling tune directly" section naming what is settable, the count-only `initial`, and the seed rule (the fold's tuning seed seeds `control_bayes()`, built inside that seed's scope); `nested_tune_grid()`'s help cross-references it; `_pkgdown.yml` lists it under "Running the loop"; `NEWS.md` carries an entry; `cairn/DESIGN.md`'s orchestration family line and architecture paragraph name it and the tuner description.
- [ ] AC9: `Rscript -e 'devtools::document()'` produces no diff, `Rscript -e 'devtools::test()'` is clean, and `Rscript -e 'devtools::check()'` reports 0 errors and 0 warnings.

## Coverage

- AC1 → T4, T5
- AC2 → T5
- AC3 → T5
- AC4 → T1, T6
- AC5 → T2, T5
- AC6 → T3
- AC7 → T1, T6
- AC8 → T4
- AC9 → T7

## Tasks

- [x] T1: The tuner description and the call it assembles (RB tripwire: ip-touching — IP2). Internal constructors `tuner_grid(grid)` and `tuner_bayes(iter, initial, objective)` returning a list naming the tune function and its static arguments; `run_tuner()` building the inner call with `rlang::call2()` over `object`, `resamples`, `param_info`, `metrics`, `eval_time`, the tuner's arguments and a control the tuner supplies — `control_grid(allow_par = FALSE, event_level)` or `control_bayes(allow_par = FALSE, event_level, seed = seeds[[1L]])`. `nested_fold_fit()` (`R/nested-tune-grid.R:490`), `dispatch_folds()` and its lean `task` (`R/parallel.R:194-330`), `fold_task()` (`R/parallel.R:1040`) and `final_fit_worker()` (`R/nested-final-fit.R:270`) take `tuner` in place of `grid`; `nested_tune_grid()` and `nested_final_fit()` build `tuner_grid(grid)`. Re-point the mocked worker signatures in `test-parallel-identity.R:348`, `test-parallel-interrupt.R:20,58`, `test-parallel-payload.R:294`, `test-parallel-detection.R:298` and the direct calls in `test-nested-tune-grid-rng.R:80,118`; re-point `helper-time-budget.R`'s ledger for moved lines. Package functions serialize by namespace name, so the description costs nothing on the wire (M12/M23 lesson).
- [ ] T2: The record (RB tripwire: ip-touching — IP4). `scored_candidates()` (`R/nested-tune-grid.R:634`) joins `.iter` from the tuning run's rows onto each per-resample frame; `new_nested_results()` (`R/nested-results.R:8`) takes and stamps `procedure`, which joins `run_attributes()` (`R/nested-results.R:259`); `expect_kept()` (`test-dplyr-compat.R:53`) and `expect_record_kept()` (`test-vctrs-compat.R:47`) gain it; `print_candidate_sets()` and `summary()` are run on an `.iter`-bearing `.grid` (M41 lesson: every reader of a changed shape).
- [ ] T3: Entry checks in `R/checks.R`: `check_iter()`, `check_initial()`, `check_objective()`, each refusing with a named class and the user's call; a test per refusal asserting the class, and one test per shared `check_*()` firing through `nested_tune_bayes()` (`test-nested-tune-bayes-checks.R`).
- [ ] T4: `nested_tune_bayes()` in `R/nested-tune-bayes.R` with roxygen (AC8's section, an engines-guarded example), the `nested_tune_grid()` cross-reference, `_pkgdown.yml`, `NEWS.md`, DESIGN's family line and architecture paragraph; `bayes_param_info()` fixture — a finalized, integer-only parameter set on the deterministic workflow — and a stochastic-engine sibling in `helper-orchestration.R`, built inline where a daemon is involved (M12 lesson).
- [ ] T5: Oracles and the readers test (`test-nested-tune-bayes-oracles.R`, provenance header per DESIGN): `reference_nested_bayes_loop()` for AC2 on both fixtures; the AC3 invariant; the AC5 record assertions; the AC1 readers test, its method list taken from `grep 'nested_results)' NAMESPACE` at implementation time and each method called once.
- [ ] T6: `test-nested-tune-bayes-rng.R` with AC4's eight properties; a BC10 test in `test-parallel-identity.R` at two daemon counts, its `start_daemons()` waits added as ledger rows in `helper-time-budget.R`; the AC7 before-and-after comparison, its command and result written to the work log.
- [ ] T7: `air format .`, `devtools::document()`, `devtools::test()`, `devtools::check()`; NEWS wording derived from the shipped behaviour, not composed.

## Work log

- 2026-09-01: created by /milestone-plan; absorbs the ROADMAP candidate row for issue #35 (added 2026-08-31). Probed by execution (tune 2.1.0): `tune_bayes()` is same-seed identical, its initial stage equals `tune_grid()` on the same space-filling set under the same seed, `iter = 0` is accepted, results carry a top-level `.iter`, `control_bayes()`'s default seed is drawn from the stream, and tune imports GauPro so no dependency is added.
- 2026-09-01: criteria audit ran in full mode (fresh [O] reader, no author): 29 findings over the 16 draft criteria of M45 and M46. Fixed with one clear answer: the reference and the orchestrator both pass an explicit `control_bayes(seed=)`; AC3 restricted to an integer-only fixture; `.iter` joined from the tuning run's rows; `procedure` joins `run_attributes()` and records `param_info`/`event_level`/`eval_time`; the shared-checks promise names its procedure; AC7 became a before-and-after identity of the fixture's numbers; instrument properties moved to T2/T5/T6; the stricter `iter`/`initial` checks got D-040. One finding became a gate question (the one-type oracle on the iteration stage).
- 2026-09-01: plan gate chose `nested_tune_bayes()` as a sibling export over a single function taking the tune function as an argument (topepo's #35 sketch) because D-010's naming convention stands and a sibling needs no superseding entry; falsified by a third tuner arriving whose signature the sibling shape cannot carry without a fourth near-identical export.
- 2026-09-01: plan gate chose `iter`, `initial`, `objective` as own arguments over a `control` argument or adding `no_improve`/`uncertain` because D-030's per-argument rule stands and most `control_bayes()` slots are inert or unreachable inside a daemon; falsified by a caller needing a slot beyond those three to change a number they are shown.
- 2026-09-01: plan gate chose accepting one oracle type on the Bayesian iteration stage (the reference loop, plus serial-versus-parallel identity) over a review brief because the proposals are tune's own search inside D-002's boundary and a brief could not supply an independent oracle for tune's Gaussian process either; the package's own contribution — the call, the seed, the record, the loop — has two types at the initial stage. Falsified by the reference loop and the orchestrator disagreeing for a reason the seeds do not explain, or by a tune release changing `tune_bayes()`'s draw order.
- 2026-09-01: plan chose (step 2, autonomously) one threaded tuner description over three more named formals on the four-function dispatch chain because each prior setting (M34, M35, M41) touched all four; falsified by a tuner whose arguments cannot be captured statically in a call.
- 2026-09-01: T1 done. `R/tuner.R` holds `tuner_grid()`, `tuner_bayes()`, `run_tuner()` (the call via `rlang::call2(.ns = "tune")`, the control built inside it from the fold's tuning seed) and `new_procedure()`; the loop body moved out of `nested_tune_grid()` into `nested_loop()`, which both orchestrators call with their tuner and their own frame as `call`; `nested_fold_fit()`, `dispatch_folds()`, the lean task, `fold_task()` and `final_fit_worker()` take `tuner`; `new_nested_results()` takes `procedure`. Five mocked signatures and four direct calls re-pointed by renaming a formal, so no budgeted line moved. Full suite clean. The question gate was skipped: nothing the plan left open needed the user — the AC3 fixture is a two-integer-parameter workflow (`bayes_workflow()`, landed in the helper with T1) because a single-parameter `grid_space_filling()` draw proved seed-dependent and a two-parameter one comes from sfd's tables with no draw (measured), which is the property AC3 states.

## Decisions

## Review
