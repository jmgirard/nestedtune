# M51: `nested_tune_sim_anneal()` runs finetune's simulated annealing inside the outer loop

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** M50
- **Driving RR:** —
- **Principles touched:** IP1, IP2, IP4, GP1, GP2, GP3
- **Resolves:** #35 closes
- **Branch/PR:** `m051-sim-anneal`

## Goal

A user runs nested cross-validation around `finetune::tune_sim_anneal()` through `nested_tune_sim_anneal()`, a sibling
of `nested_tune_bayes()`, and each outer fold's `.inner_metrics` carries the search's iterations.

## Scope

User-facing tier: a new export and its help page. **In:** the registry entry for `tune_sim_anneal` and
`tuner_anneal(iter, initial)`; the export taking `control = finetune::control_sim_anneal()` through `...`; `initial`
as a count only, floor 1 (finetune's default), and `iter` a whole number from 1, by a D-entry extending D-040's
`initial` clauses to this sibling and departing from its `iter` floor (finetune's `1:0` loop at `iter = 0`); `.iter`
on the fold record and its zero-row prototype; the final fit re-running an annealing run and its print; the help page's
six-heading classification of `control_sim_anneal()`.
**Out:** racing → M50. An `autoplot()` view of a fold's annealing trajectory joins the standing `autoplot()` candidate
row (M49 Out). The Gaussian-process fitter's options stay on the M48 Out row; `tune_sim_anneal()` takes none.

## Acceptance criteria

- [ ] AC1: `nested_tune_sim_anneal()` is exported with the formals `object, resamples, ..., iter = 10, param_info =
      NULL, metrics = NULL, initial = 1, event_level = "first", eval_time = NULL`, and on the deterministic and the
      metric-separating fixtures each fold's `.metrics`, `.selected` and `.inner_metrics` are `identical()` to a
      reference loop that, per outer fold, pins the fold's tuning seed, calls `finetune::tune_sim_anneal()` on the
      inner `rset` under the same control with `allow_par = FALSE`, selects with `tune::select_best()`, finalizes,
      pins the fold's outer seed and scores with `tune::last_fit()`; `.inner_metrics` carries `.iter`, `0` on the
      initial candidates, and a fold that scored nothing carries `.iter` on its zero-row table.
- [ ] AC2: On the deterministic fixture under one seed, the `.inner_metrics` rows at `.iter == 0` carry exactly the
      parameter values and `mean` that `nested_tune_grid()` with `grid = <the same initial count>` records under the
      same seed.
- [ ] AC3: Each refusal fires at entry, before any fold runs, with its condition class asserted: a `tune_results`
      passed as `initial`; `iter` or `initial` non-numeric, of length other than 1, fractional or `NA`; `initial`
      below 1; `iter` below 1; a control that is not a `control_sim_anneal()` (`nestedtune_bad_control`); finetune
      not installed, under a mocked absence.
- [ ] AC4: With `time_limit` unset, the same seed gives `identical()` results serially and at 2 and 3 daemons whose
      library holds finetune; two seeds give different `.inner_metrics`; the caller's `.Random.seed` and `RNGkind()`
      triple are restored on exit, including when the call errors; and the help page's by-hand recipe reproduces one
      fold's `.inner_metrics` and `.selected`.
- [ ] AC5: `nested_final_fit()` on an annealing result re-runs it on the full data: `$tuning` inherits
      `iteration_results`, `attr(x, "procedure")` records `iter` and `initial`, `print()` names simulated annealing
      with those two counts, and the fit's two seeds, `selected`, tuning split ids and `predict()` output are
      `identical()` to a reference final fit that pins the two seeds and calls finetune, `select_best()`,
      `finalize_workflow()` and `fit()` by hand.
- [ ] AC6: The help page places every `control_sim_anneal()` slot under exactly one of the six headings (`Forced`,
      `Settable as its own argument`, `Refused`, `Passed through`, `Not returned`, `Inert`), with `allow_par` Forced,
      `time_limit` Passed through under the IP2 caveat D-042 records, `verbose_iter` Passed through as printing from
      every fold, and `save_history` Not returned; the profile's verify slot is clean.

## Coverage

- AC1 → T1, T2
- AC2 → T2
- AC3 → T2
- AC4 → T3, T5
- AC5 → T1, T4
- AC6 → T5

## Tasks

- [ ] T1: The registry entry (`R/tuner.R`, M50's table) for `tune_sim_anneal` — package finetune,
      `control_sim_anneal()`, takes `iter` and `initial`; `tuner_anneal(iter, initial)`; `empty_inner_metrics()`
      adds `.iter` from the registry rather than the `tune_bayes` name; `candidate_set()`'s `.iter` ordering
      (`R/nested-tune-grid.R:893-934`) documented for both iterating tuners; `procedure_label()` and
      `procedure_counts()` (`R/nested-final-fit-print.R:195-227`) read the registry.
- [ ] T2: `nested_tune_sim_anneal()` on `nested_tune_bayes()`'s shape (`R/nested-tune-bayes.R:199-235`), `check_iter()`
      and `check_initial()` each taking its floor as an argument (`iter` 0 for Bayes and 1 here; `initial` 2 for Bayes
      and 1 here), `check_control()` accepting `control_sim_anneal`; the D-entry extending D-040's `initial` clauses to
      this sibling and departing from its `iter` floor; `reference_nested_anneal_loop()` in `helper-orchestration.R`;
      the AC1, AC2 and AC3 tests — AC3's probes name their exemplars (character, list, `NULL`, length 0 and 2, `2.5`,
      `NA`, `NA_real_`; a `tune_results` as `initial`; `initial = 0`; `iter = 0`), and where two refusals share a class
      (`nestedtune_bad_initial`, `nestedtune_bad_control`) the message pattern is asserted beside it.
- [ ] T3: The AC4 RNG battery and daemon identities on the M50 patterns, gated on finetune and mirai.
- [ ] T4: The final fit on an annealing result and `reference_anneal_final_fit()` for the AC5 identity.
- [ ] T5: The help page with the control classification and by-hand recipe (its test in AC4), its
      `test-control-slots.R` block; `_pkgdown.yml`, `NEWS.md`, DESIGN.md; `devtools::check()`.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. EXEMPT from the 150-line cap. -->

- 2026-09-02: created by /milestone-plan beside M50 from the candidate row "The rest of issue #35 after M48"; `tune_sim_anneal()` probed by execution (`iteration_results`, `.iter` with 0 on the initial rows, `iter = 0` and `initial = 1` accepted, a `tune_results` accepted as `initial`, the initial-rows-equal-grid identity, caller RNG not restored by finetune).
- 2026-09-02: criteria audit ran in full mode ([O] fresh reader over the drafted criteria, with M50's): findings on this file fixed before the gate — `initial` floor 1 and `iter` floor 0 stated with a D-entry task, the refusal modes named per argument, the final-fit identity on seeds/selection/split ids/predictions, `time_limit` unset for the identity battery, the `.iter == 0` comparison pinned to `mean` and parameter values, parser and registration files moved to tasks.
- 2026-09-02: plan chose `initial`'s floor of 1 (finetune's default) over D-040's 2 because the 2 came from `tune_bayes()`'s own requirement, which annealing does not share; falsified by a fold whose single initial candidate makes the search degenerate in a way finetune does not refuse.
- 2026-09-02: plan chose accepting `iter = 0` (the initial candidates alone, as the Bayesian sibling does) over a floor of 1; falsified by finetune refusing it in a later version.
- 2026-09-02: amendment (substantive, user's choice at the implement question gate): AC3 "`iter` below 0" → "`iter` below 1", and the Scope's `iter` floor 0 → 1 — finetune 1.3.0's `tune_sim_anneal()` loops `for (i in (existing_iter + 1):iter)`, so `iter = 0` runs `1:0`, two iterations labelled `Iter1` and `Iter0`, where `tune_bayes()` at 0 proposes nothing (measured 2026-09-02; the loop header is unchanged on finetune's GitHub main). The plan's `iter = 0` choice above is superseded; this export refuses 0 and the Bayesian sibling keeps accepting it.
- 2026-09-02: amendment audit ran in full mode ([O] fresh reader over the amended AC3 and Scope text): five findings, all disposed here — `check_iter()` gains a floor argument (T2 reworded; the hardcoded `>= 0` made the criterion unreachable as tasked); shared classes get a message pattern beside the class, and the refusal probes name their exemplars (both in T2's text, the criterion unchanged); the Scope says the D-entry departs from D-040's `iter` floor rather than extends it; and the superseded plan choice is marked by the line above.
- 2026-09-02: T1 done — `tune_sim_anneal` registry entry (finetune, `control_sim_anneal`, `takes_grid = FALSE`, `iterates = TRUE`, label "simulated annealing"), `tuner_anneal(iter, initial)`, `tuner_iterates()` total over any name; `procedure_counts()` and `procedure_label()` read `iterates` and the label so the Bayesian print line is unchanged (its snapshots hold) and the annealing line takes the same shape; `empty_inner_metrics()` already read `iterates` since M50, its comment and `candidate_set()`'s now name both iterating tuners and finetune's `Iter<i>` labels; registry tests extended.
- 2026-09-02: T2 done — `nested_tune_sim_anneal()` (`R/nested-tune-sim-anneal.R`) on the Bayesian shape with finetune checked first; `check_iter(floor = 0)` and `check_initial(floor = 2)` take the calling sibling's floor (1 and 1 here); D-046 written; `anneal_control()` (`verbose_iter = FALSE`, the one slot the fixtures set), `anneal_results()`, `reference_nested_anneal_loop()` and `forced_anneal_control()` in the helper; AC1 (deterministic and metric-separating, formals, `.iter` on the record and its zero-row table), AC2 (`.iter == 0` rows against `nested_tune_grid(grid = 3)` under seed 20: same `num_comp` values and means in every fold) and AC3 tests, the by-hand recipe test beside them.
- 2026-09-02: T3 done — the eight RNG properties on `nested_tune_sim_anneal()` (`test-nested-tune-sim-anneal-rng.R`, ranger where a deterministic engine would pass vacuously) and BC13 in `test-parallel-identity.R`: serial `identical()` to 2 and 3 daemons under one seed, `time_limit` asserted unset.
- 2026-09-02: T4 done — `nested_final_fit()` on an annealing result needed no code: `procedure_tuner()` rebuilds `tuner_anneal()`'s description and `run_tuner()` calls finetune from the registry; `reference_anneal_final_fit()` and `test-nested-final-fit-sim-anneal.R` pin seeds, selection, split ids, predictions, `iteration_results`, the recorded counts, the print line "simulated annealing, N initial candidates (3 requested), N iterations completed (2 requested)" and the finetune refusal on the final fit.
- 2026-09-02: T5 done — help page with the six-heading classification (11 slots Passed through, `save_history` Not returned beside the three, `verbose_iter`'s per-fold log named) and the by-hand recipe; `test-control-slots.R` block reads it off the Rd; cross-references on the grid, final-fit and summary pages; `_pkgdown.yml` row, NEWS entry, DESIGN.md (function families, architecture, dependency surface, the `time_limit` known issue); `pkgdown::check_pkgdown()` clean.
- 2026-09-02: checkpoint — T1–T5 code, tests and records written; their targeted test files, `document()` and `check_pkgdown()` clean; the full `devtools::test()` and `devtools::check()` runs were still in flight, so no task is ticked yet — ticks follow their results.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. EXEMPT from the 150-line cap. -->

## Review
<!-- owner: review · exclusive; evidence per criterion. EXEMPT from the 150-line cap. -->
