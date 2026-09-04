# M58: The startup check asks every daemon for each package the workflow and the tuner need, and the host's entry check reads the same list

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Resolves:** —
- **Surface tier:** user-facing — a refusal every parallel driver raises before dispatch, and a host-side entry refusal
- **Branch/PR:** `m058-preflight-workflow-pkgs`

## Goal

A run whose daemons or host lack a package the workflow or the tuner needs is refused at entry, before any fold runs, naming the daemons and the packages.

## Scope

**In:** the parallel pre-flight (`daemons_load_status()`, `R/parallel.R`) sends every daemon the package list the attach step already builds — `tune::required_pkgs(object)` plus the tuner registry's `requires` — and each daemon reports which it cannot load; `preflight_outcome()` gains a `missing_pkgs` rung between `cannot_load` and `incompatible`, and `check_daemons_can_load()` a fourth classed refusal, `nestedtune_daemons_missing_pkgs` under the shared `nestedtune_daemons_unusable`, with cross-fault bullets like the existing ones. One helper builds the list for the probe, the attach step and the host. The host's own entry check widens from the engine's packages (`check_model_spec()`, `R/checks.R`) to the workflow's, carrying the class the tuner refusal already uses. Documentation in the daemons section of `?nested_tune_grid` and NEWS.

**Out:** the attach step's warning `nestedtune_daemon_pkgs_not_attached` for a package that loads but will not attach — untouched, since the pre-flight now refuses the installable case and the residue has no plantable fixture. Remote daemon pools — the "Probe remote mirai daemon pools" candidate row, which this row's probe now asks a second question of, for local daemons. A build fingerprint beyond the symbol manifest — its own candidate row. No new option or argument: the bound stays `nestedtune.preflight_timeout` (D-020) and the signatures are unchanged (D-018).

## Acceptance criteria

- [ ] AC1: Each of the five parallel drivers — `nested_tune_grid()`, `nested_tune_bayes()`, `nested_tune_race_anova()`, `nested_tune_race_win_loss()`, `nested_tune_sim_anneal()` — called with the parallel branch selected and a fabricated pre-flight answer set in which a daemon reports a needed package as not installed, stops with a condition carrying both `nestedtune_daemons_missing_pkgs` and `nestedtune_daemons_unusable` before any fold is dispatched: after `reset_dispatch_record()`, `last_dispatch()` is still `NULL`. The message names how many of the pool's daemons lack a package, which packages, and the remedy of installing into the daemons' library and restarting the pool. The test mocks `mirai_workers()` and `daemons_load_status()`, loops over the five drivers, and varies the answer set on three axes: the missing package is the workflow's for the grid and Bayesian drivers and the tuner's own requirement (`lme4`, `BradleyTerry2`, `finetune`) for the racing and annealing drivers; one daemon lacks it in one set and two in another; one package is missing in one set and two in another.
- [ ] AC2: On the real two-daemon pool `start_mixed_daemons()` builds — one daemon on the full library, one on the scratch library holding only mirai and nanonext — `daemons_load_status(package = "mirai", pkgs = "ranger")` reports `total` 2, `cannot_load` 0, `incompatible` 0, `no_answer` 0, `missing_pkgs` 1, `missing_packages` `"ranger"` and outcome `"missing_pkgs"`, with the test's elapsed time under 150 s as the existing heterogeneous-pool test asserts; skipped on windows and where the scratch library cannot be built, as that test is.
- [ ] AC3: `preflight_outcome()` orders its outcomes `cannot_load` > `missing_pkgs` > `incompatible` > `no_response` > `ok`, each of the five produced by at least one fabricated answer set and asserted on `$outcome`; and for each of the three pairs — missing packages beside a daemon that cannot load, beside an incompatible build, beside a silent daemon — the one abort `check_daemons_can_load()` raises names both facts, verified by seam tests over `check_daemons_can_load(preflight_outcome(...))`.
- [ ] AC4: A workflow needing a package the host's library lacks — as `tune::required_pkgs(object)` names it, a recipe step's requirement included, not only the engine's — is refused at entry with class `nestedtune_pkg_not_installed`, naming the package and an install call, by each of the five tuning drivers run serially and by `nested_final_fit()`; scoped to workflows whose `required_pkgs()` returns. Verified by a test whose recipe step carries a `required_pkgs()` method naming a package that is not installed, run through the six entry points.
- [ ] AC5: The daemons section of `?nested_tune_grid` states that the startup check also asks every daemon for each package the workflow and the tuner need and stops, naming the daemons and packages, when one lacks a package; `NEWS.md` carries one entry naming the daemon refusal and the widened host refusal.
- [ ] AC6: The r-package profile's verify slot is clean — `devtools::test()` green, `devtools::document()` no diff — and `devtools::check()` reports 0 errors and 0 warnings.

## Coverage

- AC1 → T2
- AC2 → T3
- AC3 → T1
- AC4 → T4
- AC5 → T5
- AC6 → T5

## Tasks

- [x] T1: Seam first, in `tests/testthat/test-parallel-classify.R`: extend the `reports()` fabricator with a `missing_pkgs` field and `daemon_report()` (`R/parallel.R:667`) to validate it positively; `daemon_probe_expr()` (`R/parallel.R:495`) asks `requireNamespace()` for each of `pkgs` in both branches, still built from text; `daemons_load_status()` (`R/parallel.R:507`) takes `pkgs`; `preflight_outcome()` (`R/parallel.R:701`) gains `missing_pkgs` (a daemon count), `missing_packages` (the union) and the rung; the ladder and reachability tests (AC3).
- [x] T2: A helper `needed_pkgs(object, tuner)` returning `tune::required_pkgs(object)` under the attach step's `tryCatch` plus the registry's `requires`, read by the probe, by `attach_daemon_pkgs()` (`R/parallel.R:593`) and by T4; `dispatch_folds()` (`R/parallel.R:221`) passes it to the pre-flight; `check_daemons_can_load()` (`R/parallel.R:756`) gains the `missing_pkgs` abort — count, packages, install-then-restart remedy, the serial alternative — and cross-fault bullets on the cannot-load and incompatible branches; the per-driver refusal test (AC1) with its 0-second ledger rows.
- [x] T3: The real-pool test in `tests/testthat/test-parallel-detection.R` beside the existing heterogeneous-pool test (`:56`), its rows in `helper-time-budget.R` and the `test-suite-hygiene.R` guard (AC2).
- [ ] T4: Host side: `check_model_spec()` (`R/checks.R:91`) becomes a workflow-level check over the helper's workflow half, carrying `nestedtune_pkg_not_installed` with the tuner refusal's install hint; the custom-step test across the five drivers and `nested_final_fit()` (AC4).
- [ ] T5: The roxygen daemons bullet (`R/nested-tune-grid.R:340-353`), the NEWS entry, the DESIGN architecture sentence on the pre-flight and attach (`cairn/DESIGN.md:261-263`), `air format --check` on the touched files, `devtools::document()`, full `devtools::check()` (AC5, AC6).

## Work log

- 2026-09-04: created by /milestone-plan, promoting the candidate row "Ask the daemon pre-flight what the WORKFLOW needs" at the user's choice, ahead of the row's stated promotion condition (no user has yet reported the missing-rather-than-unattached case).
- 2026-09-04: criteria audit ran in full mode ([O] fresh reader): thirteen findings. Fixed — AC1 names the recorder reset and varies three answer-set axes; AC2 restated with `package = "mirai"` as the loadable stand-in, since under `devtools::test()` neither daemon holds nestedtune and cannot-load would take the class (this also removed a planned inverse scratch-library helper); AC3's unenumerable "no two share" clause replaced by per-outcome reachability and its cross-fault clause scoped to three named pairs; AC4 adds `nested_final_fit()` and is scoped to workflows whose `required_pkgs()` returns; document() no-diff moved from AC5 to AC6. Judgments — AC1 keeps the dispatch recorder as its proxy (precedent: the branch-record tests); the host class question went to the gate.
- 2026-09-04: plan gate chose refusing at the pre-flight over keeping the attach step's warning because a daemon that cannot load a needed package fails every fold it takes, a provably invalid pool GP3 refuses, and the pre-flight already refuses the nestedtune case the same way; falsified by a user needing a mixed pool to run through its good daemons.
- 2026-09-04: plan gate chose widening the host check to `tune::required_pkgs(object)` here over a candidate row because host and daemons then read one list from one helper; falsified by a workflow whose `required_pkgs()` names a package no fold calls.
- 2026-09-04: plan gate chose reusing `nestedtune_pkg_not_installed` over a distinct class because both refusals state the same fact about the host's library; falsified by a handler that must tell a missing step or engine package from a missing tuner package.
- 2026-09-04: step 2 chose folding the package question into the existing probe round trip over promoting the attach step's warning to an abort because one round trip and one ladder keep the pre-flight the single refusal site and its messages already name co-occurring faults; falsified by the probe's namespace loads lengthening a cold pool's first call past the bound, which the attach step would have paid anyway.
- 2026-09-04: T1 done. The probe asks `requireNamespace()` for each of `pkgs` ahead of its load branch, so a daemon on the cannot-load path still answers the package question; `daemon_report()` requires the `missing_pkgs` field; `preflight_outcome()` counts daemons in `missing_pkgs` and unions names in `missing_packages`, rung between `cannot_load` and `incompatible`; `check_daemons_can_load()` raises `nestedtune_daemons_missing_pkgs` and names the packages on the cannot-load branch too. The real-pool silent-case test moved to `test-parallel-detection.R` because the classify file's declared worst case is capped at 480 s. Ledger rows for the classify file re-keyed to the shifted lines. Full `devtools::test()` clean; one daemon test ("a connected daemon that cannot answer in time is bounded") hit its 60 s limit once under a parallel three-file run and passed alone and in the full run.
- 2026-09-04: T2 done. `workflow_pkgs(object)` reads `tune::required_pkgs(object)` and falls back to the engine's list when that call raises, `needed_pkgs(object, tuner)` adds the registry's `requires`; `dispatch_folds()` hands the list to the probe and the attach step, which now takes `pkgs` as an argument. The per-driver refusal test loops the five drivers over three fabricated answer sets under mocked `mirai_workers()` and `daemons_load_status()`; no wait call, so no ledger row. Full `devtools::test()` clean.
- 2026-09-04: T3 done. The AC2 test sits at the end of `test-parallel-detection.R` with five ledger rows; it ran unskipped locally (10 expectations) and the hygiene guard is green. The real-pool silent-case test T1 moved here also ran unskipped.

## Decisions

## Review
