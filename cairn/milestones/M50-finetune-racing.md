# M50: `nested_tune_race_anova()` and `nested_tune_race_win_loss()` run finetune's racing tuners inside the outer loop

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP1, IP2, IP4, GP1, GP2, GP3
- **Resolves:** #35 partial
- **Branch/PR:** m050-finetune-racing

## Goal

A user runs nested cross-validation around finetune's two racing tuners through two sibling exports of
`nested_tune_grid()`, and each outer fold records every candidate its race scored and how many inner resamples scored it.

## Scope

User-facing tier: two new exports and a help page. **In:** the tuner description (`R/tuner.R`) learns which package a
tuner lives in, and the sites that switch on a tuner's name (`default_control()`, `control_class()`,
`empty_param_columns()`, the final fit's grid re-check, `procedure_label()`) read one registry instead;
`nested_tune_race_anova()` and `nested_tune_race_win_loss()`, each taking `control = finetune::control_race()` through
`...` under D-042's rules; the per-fold record of a race as every candidate scored; entry refusals for a missing
package, an inner design too small for the burn-in, and a control of another class; finetune loaded on daemons; the
final fit re-running a race; the help page's six-heading control classification; `finetune` and `BradleyTerry2` in
Suggests with a D-entry. The suite's fixtures hold 3 inner resamples and `control_race()` defaults `burn_in` to 3,
which racing refuses, so every racing test passes `control_race(burn_in = 2)` unless it is the refusal's own.
**Out:** `nested_tune_sim_anneal()` → M51 (planned, depends on this milestone). A racing view in `autoplot()` — the
per-resample elimination order `finetune::plot_race()` draws is not kept by the fold record — joins the standing
`autoplot()` candidate row (M49 Out). Probing finetune on daemons before dispatch, rather than attaching it and warning,
joins the standing daemon pre-flight candidate row. The Gaussian-process and outer-loop `control` remainders stay on
their M48 Out row.

## Acceptance criteria

- [ ] AC1: `nested_tune_race_anova()` and `nested_tune_race_win_loss()` are exported with `nested_tune_grid()`'s
      formals, defaults and order (`object, resamples, ..., param_info = NULL, grid = 10, metrics = NULL, event_level
      = "first", eval_time = NULL`), and for each racer on each of the deterministic and the metric-separating
      fixtures, under `control_race(burn_in = 2)`, every fold's `.metrics`, `.selected` and `.inner_metrics` are
      `identical()` to a reference loop that, per outer fold, pins the fold's tuning seed, calls
      `finetune::tune_race_anova()` (or `tune_race_win_loss()`) on the inner `rset` under the same control with
      `allow_par = FALSE`, selects with `tune::select_best()`, finalizes, pins the fold's outer seed and scores with
      `tune::last_fit()`.
- [ ] AC2: On the deterministic fixture, under one seed and one explicit grid data frame passed to both, every
      candidate a race scored on all 3 inner resamples (`n == 3` in `.inner_metrics`) carries exactly the `mean`
      `nested_tune_grid()` records for the same candidate, and the test asserts at least one such candidate exists in
      every fold.
- [ ] AC3: A racing fold's `.inner_metrics` equals `tune::collect_metrics(<the fold's race result>, all_configs =
      TRUE)` and its `.selected` equals `tune::select_best()` on that result; on a fixture whose engine draws from the
      RNG, a test asserts at least one candidate's `n` is below the inner resample count and that `.selected` is a
      candidate whose `n` equals it. (RB tripwire: ip-touching)
- [ ] AC4: For both racers: the same seed gives `identical()` results serially and at 2 and 3 daemons whose library
      holds finetune; on a fixture whose engine draws from the RNG, two seeds give different `.inner_metrics`; the
      caller's `.Random.seed` and `RNGkind()` triple are restored on exit, including when the call errors; and the
      help page's by-hand recipe reproduces one fold's `.inner_metrics` and `.selected`.
- [ ] AC5: For both racers, each refusal fires at entry, before any fold runs, with its condition class asserted:
      finetune not installed, and for `nested_tune_race_win_loss()` BradleyTerry2 not installed, each asserted under
      a mocked absence; a control that is not a `control_race()` (`nestedtune_bad_control`); an inner `rset` in any
      outer fold whose resample count is not greater than the control's `burn_in`, the message naming the count and
      the burn-in.
- [ ] AC6: `nested_final_fit()` on a racing result re-runs the recorded race on the full data: `$tuning` inherits
      `tune_race`, `attr(x, "procedure")` records the tuner's name and the `grid` as given, `extract_scored_candidates()`
      reads the race through the same `all_configs = TRUE` derivation the fold reader uses (D-043), `print()` names the
      racing method, and the fit's two seeds, `selected`, tuning split ids and `predict()` output are `identical()` to a
      reference final fit that pins the two seeds and calls finetune, `select_best()`, `finalize_workflow()` and `fit()`
      by hand.
- [ ] AC7: The help page the two exports share places every `control_race()` slot under exactly one of the six
      headings (`Forced`, `Settable as its own argument`, `Refused`, `Passed through`, `Not returned`, `Inert`), with
      `allow_par` Forced and `burn_in`, `alpha`, `num_ties`, `randomize` and `verbose_elim` Passed through, and states
      that the recorded `grid` is the design offered while `n` in `.inner_metrics` is the resamples each candidate was
      scored on; the profile's verify slot is clean.

## Coverage

- AC1 → T1, T3
- AC2 → T3
- AC3 → T3
- AC4 → T4, T6
- AC5 → T2
- AC6 → T5
- AC7 → T6

## Tasks

- [x] T1: A tuner registry in `R/tuner.R` — name → package, control constructor, control class, whether it takes
      `grid` or `iter`/`initial` — replacing the `switch()`es in `default_control()` (`R/tuner.R:121`) and
      `control_class()` (`:137`), the `tune_bayes` test in `empty_inner_metrics()` (`R/nested-tune-grid.R:796`) and
      the grid read in `empty_param_columns()` (`:806`), the grid re-check in `nested_final_fit()`
      (`R/nested-final-fit.R:211`) and `procedure_label()` (`R/nested-final-fit-print.R:210`); `run_tuner()` builds
      its call with `.ns = <the registry's package>` (`R/tuner.R:82`); `tuner_race(fn, grid)`. Grid and Bayes suites
      green, unchanged.
- [x] T2: `check_tuner_installed()` (through `rlang::is_installed()`, mocked in tests), `check_race_burn_in()`
      over every fold's inner `rset`, `check_control()` accepting `control_race`; the AC5 tests, mocked-absence
      cases included.
- [x] T3: The two exports over one internal `nested_tune_race()`; `inner_metrics()` and `scored_candidates()`
      (`R/nested-tune-grid.R:886`) calling `all_configs = TRUE` on a `tune_race`; `reference_nested_race_loop()` in
      `helper-orchestration.R` on the pattern of the Bayesian loop; the AC1, AC2 and AC3 tests.
- [x] T4: `attach_daemon_pkgs()` (`R/parallel.R:597`) takes the tuner's package beside the workflow's; the AC4 RNG
      battery on the pattern of `test-nested-tune-bayes-rng.R`, the daemon identities on the pattern of
      `test-parallel-identity.R`, gated on finetune and mirai.
- [x] T5: The final fit on a racing result — grid re-check on the recorded `grid`'s presence, `procedure_label()`,
      `extract_scored_candidates()` on a `tune_race` — and `reference_race_final_fit()` for the AC6 identity.
- [ ] T6: The shared help page with the control classification and the by-hand recipe (its test in AC4);
      `test-control-slots.R`'s `differences_section()` (`:51`) accepting "Differences from calling finetune directly"
      and a block for the racing page; `_pkgdown.yml`, `NEWS.md`, DESIGN.md architecture and function families;
      `DESCRIPTION` Suggests `finetune`, `BradleyTerry2` and the D-entry; `devtools::check()`.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. EXEMPT from the 150-line cap. -->

- 2026-09-02: created by /milestone-plan from the candidate row "The rest of issue #35 after M48"; finetune 1.3.0 probed by execution in a scratch library (result classes, `all_configs`, no `seed` slot, seed reproducibility, the burn-in refusal, BradleyTerry2 for win-loss, the race-equals-grid `mean` identity).
- 2026-09-02: criteria audit ran in full mode ([O] fresh reader over the drafted criteria): ten findings; eight fixed before the gate (fixtures' `burn_in = 2` stated, final-fit identity on seeds/selection/split ids/predictions, the circular "every candidate" gloss dropped, two-seeds-differ narrowed to an RNG-drawing engine, "for both racers" on the refusals, the grid comparison pinned to one explicit grid, the raced-grid IP4 wording added to AC7, parser and registration files moved to tasks); two posed at the gate (record shape, split).
- 2026-09-02: plan gate chose sibling exports over one function taking the tuner as an argument because D-010's rejection stands and D-040 kept it; falsified by a tuner family sharing no argument with grid or Bayes, which the registry could not describe.
- 2026-09-02: plan gate chose `collect_metrics(all_configs = TRUE)` for the fold record over finetune's survivors-only default because IP4 records what ran; falsified by a reader needing the survivors alone and unable to derive them from `n`.
- 2026-09-02: plan gate chose two milestones (racing here, annealing as M51) over one because the combined draft ran to 13 criteria and 11 tasks; falsified by M50 leaving M51 less than a session of work.
- 2026-09-02: plan gate chose `finetune` and `BradleyTerry2` both in Suggests over finetune alone so the win-loss tests run on CI; falsified by a CI leg on which BradleyTerry2 cannot install.
- 2026-09-02: plan chose refusing a burn-in mismatch at entry over letting every fold fail on finetune's own message because GP3 refuses before work is spent; falsified by an inner design whose folds legitimately differ in resample count.
- 2026-09-02: plan chose a tuner registry over extending the four `switch()`es on the tuner's name because each new tuner would otherwise touch every site; falsified by a tuner whose arguments neither the grid nor the iter/initial shape describes.
- 2026-09-02: acknowledgement comment posted on #35 at the user's choice.
- 2026-09-02: /milestone-implement started; branch `m050-finetune-racing` cut from the pushed default branch; finetune 1.3.0, BradleyTerry2 1.1.3 installed locally for the suite.
- 2026-09-02: question gate: `tune_race_anova()` calls `rlang::check_installed("lme4")` inside the fold and finetune only suggests lme4, so the user chose an entry refusal for lme4 on the ANOVA racer and lme4 in Suggests beside finetune and BradleyTerry2 (one D-entry for the three, T6); the AC3 tripwire (ip-touching) was offered escalation and the user chose to proceed as planned.
- 2026-09-02: T1 done: `tuner_registry` in `R/tuner.R` (package, requires, control constructor, control class, takes_grid, iterates, label) replaces the `switch()`es in `default_control()` and `control_class()`, the `.iter` and grid reads in the zero-row prototype, the final fit's grid re-check and `procedure_label()`; `run_tuner()` builds its call with `.ns = <registry package>`; `tuner_race(fn, grid)` added; `test-tuner-registry.R`; grid and Bayes suites green, unchanged.
- 2026-09-02: T2 done: `check_tuner_installed()` over the registry's `requires` through `rlang::is_installed()` (class `nestedtune_pkg_not_installed`), `check_race_burn_in()` over every fold's inner `rset` (class `nestedtune_bad_burn_in`, naming each short fold's count and the burn-in), `check_control()` naming the control's package; `R/nested-tune-race.R` holds the two exports over one `nested_tune_race()`; `test-nested-tune-race-checks.R` covers AC5 with the absences mocked one package at a time.

- 2026-09-02: T3 done: `collect_inner_metrics()` is the one `collect_metrics()` call behind `inner_metrics()` and `scored_candidates()`, `all_configs = TRUE` on a `tune_race`; `reference_nested_race_loop()`, `reference_race_final_fit()` and the racing fixtures in `helper-orchestration.R`; `test-nested-tune-race-oracles.R` covers AC1 (both fixtures, both racers, formals identical to the grid export), AC2 (raced-to-the-end means identical to the grid path's, at least one per fold) and AC3 (record from `all_configs = TRUE`, selection a survivor, an elimination observed on the ranger fixture); full suite green after T1 (336 lines of summary, no failures).

- 2026-09-02: T4 done: `attach_daemon_pkgs(object, tuner)` attaches the registry's package for the tuner beside the workflow's (tune left off, as the pre-flight's namespace load brings it; a tuner-less driver adds nothing); `test-nested-tune-race-rng.R` (same seed, two seeds differ in `.inner_metrics`, fold order, ambient kind, restore on completion, on failed folds and on error, unseeded session), BC12 in `test-parallel-identity.R` (both racers, serial against 2 and 3 daemons) and a finetune-attached probe in `test-parallel-required-pkgs.R`, each with its wait-budget ledger row.

- 2026-09-02: T5 done: the final fit's grid re-check keys on the registry's `takes_grid` (T1), `procedure_label()` names the racing method from the registry, `extract_scored_candidates()` reads a `tune_race` through `collect_inner_metrics()` (T3); `test-nested-final-fit-race.R` covers AC6 against `reference_race_final_fit()` on the ranger fixture for both racers, the eliminated candidates present in the extract, print and summary lines, and the recorded-grid refusal; the racing final-fit fixtures seed before building the workflow so the cache keys once.

- 2026-09-02: T6 in progress: help page `?nested_tune_race` shared by the two exports (six-heading classification, by-hand recipe), `test-control-slots.R` reads either "Differences from calling ... directly" title and classifies `control_race()`, the recipe test in `test-nested-tune-race-oracles.R`, `_pkgdown.yml` row, NEWS entry, DESIGN function families and architecture, DESCRIPTION Suggests finetune, lme4, BradleyTerry2 with D-044; per-file suites green, `pkgdown::check_pkgdown()` clean; `devtools::check()` and the full suite after T4 still running at this checkpoint.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. EXEMPT from the 150-line cap. -->

## Review
<!-- owner: review · exclusive; evidence per criterion. EXEMPT from the 150-line cap. -->
