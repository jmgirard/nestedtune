# M54: The inner tuning call finalizes an unknown parameter range on the outer fold's analysis rows

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP1, IP2, GP1, GP2, GP4
- **Resolves:** —
- **Branch/PR:** m054-inner-finalize-analysis-frame · https://github.com/tidymodels/nestedtune/pull/64

## Goal

Every inner tuning call sees only its outer fold's analysis rows, so a parameter whose range tune
finalizes from the data — by row count, by column count after preprocessing, or by the values — is
finalized without the outer assessment rows, as IP1 requires and as a design from
`rsample::nested_cv()` already gets.

## Scope

**In:** user-facing tier — the candidates an exported orchestrator searches change for such a
parameter. On tune 2.1.0 and finetune 1.3.0 four of the five tuners finalize an unknown range on
`resamples$splits[[1]]$data`, the whole frame the first inner split carries, molded through the
workflow's preprocessor (`tune_grid_workflow()` directly; the two racers through the `tune_grid()`
they call; `tune_sim_anneal()` through its own `check_parameters()` call); `tune_bayes()` has no
finalizing path — its initial grid refuses a parameter with an unknown range before any frame is
read (`dials::grid_space_filling()`, "without unknowns"), and `initial` is a count only (D-040), so
`nested_tune_bayes()` records that refusal per fold and is a named non-case here.
`nested_resamples()` re-points every inner split at the caller's one frame
(`R/nested-resamples.R:176-178`), so that frame is the full data, assessment rows included; measured
2026-09-03 on a 200-row frame with five outer folds, a `min_n` finalized by
`dials::get_n_frac_range()` searched candidates up to 100 on a `nested_resamples()` design and up to
80 on the `rsample::nested_cv()` design with identical inner rows. The fix is worker-side: before
`run_tuner()` in `nested_fold_fit()` (`R/nested-tune-grid.R:633`), an inner rset whose every split
carries the outer split's own frame is rebuilt over `rsample::analysis(split)` — `$data` the
analysis frame, `in_id`/`out_id` remapped to positions in it, the fingerprint recomputed, the inverse
of `inner_resamples_from_split()` — so the frame tune reads holds exactly the analysis rows and
tune's own finalization, message and recipe refusal run on it unchanged. That is a documented
divergence from calling tune on the design's `inner_resamples` element (GP1): the inner call no
longer receives the object the design holds. An inner rset whose frame is not the outer split's (a
`nested_cv()` design), or an outer split whose `in_id` repeats (an evaluated `manual_rset()`; the
inverse is ambiguous there), is left as it is. The design object, its size and the wire payload do
not change; each running fold materializes one analysis-set copy inside its worker for the tune
call's duration (GP4). Docs on the three `@param param_info` sites and the DESIGN architecture prose
name the frame; NEWS one entry.

**Out:** the final fit's re-run (`R/nested-final-fit.R:304`) finalizes on the full data, which is the
final model's own training data and outside IP1's clause — documented, not changed; a value-reading
finalizer (`rbf_sigma()`, needing kernlab) and a column-count finalizer under a recipe whose width
differs across frames (`mtry` after `step_dummy()` on a level held-out rows alone carry) are covered
by AC1's row-identity assertion on the frame, not by a case of their own; generating one shared grid
up front → the standing M21 candidate row; a repeated-index outer split keeps today's frame.

## Acceptance criteria

- [x] AC1: For each tuner `tuner_registry` (`R/tuner.R:67`) enumerates other than `tune_bayes`, a
      run on a `nested_resamples()` design with a `param_info` whose `min_n` object carries an
      unknown upper bound and a finalizer recording every frame it is handed sees, in every outer
      fold, only frames whose row count equals `nrow(rsample::analysis(split))` for that fold and
      whose rows are that analysis frame's rows (a sorted predictor column compared `identical()`);
      the same holds for a `nested_tune_grid()` run on a design whose `outside` is an evaluated
      `vfold_cv()` rset; asserted by one test over the registry, the finetune entries skipped where
      finetune is absent.
- [x] AC2: On a `nested_tune_grid()` run under a pinned seed with `grid = 5` and the `min_n`
      finalizer `dials::get_n_frac_range(frac = c(1/10, 5/10))`, every candidate each fold searched
      (`.inner_metrics$min_n`) lies within `floor(n * c(1/10, 5/10))` computed in the test from that
      fold's `n = nrow(rsample::analysis(split))`; asserted by a test whose upper bound the full
      frame's `floor(nrow(data) / 2)` exceeds by 20 on the 200-row fixture.
- [x] AC3: On the same data, `nested_tune_grid()` on a `nested_resamples()` design and on the
      `rsample::nested_cv()` design built under the same seed — inner rows asserted identical in the
      test — returns `identical()` `.inner_metrics` and `.metrics` columns under the same run seed,
      once with the unknown-range `param_info` of AC2 and once with `stoch_grid()`'s data-frame grid;
      asserted by a test on two direct calls.
- [x] AC4: An inner rset the rebuild does not apply to reaches `run_tuner()` untouched: on a
      `rsample::nested_cv()` design, and on a `nested_resamples()` design whose evaluated `outside`
      is a `manual_rset()` with a repeated `in_id`, the `resamples` argument `run_tuner()` receives in
      every outer fold of a `nested_tune_grid()` run is `identical()` to the design's
      `inner_resamples` element; asserted by a test through `local_mocked_bindings()` on `run_tuner`,
      the mock recording its argument and delegating to the original.
- [x] AC5: The `@param param_info` roxygen at its three sites (`grep -n '@param param_info' R/`:
      `nested_tune_grid()`, inherited by the racers, `nested_tune_bayes()`, `nested_tune_sim_anneal()`)
      states that an unknown range is finalized on the outer fold's analysis rows; `?nested_final_fit`'s
      `@param results` states that the final fit finalizes on the full data; `cairn/DESIGN.md`'s
      architecture prose names the rebuild as the GP1 divergence; `devtools::document()` produces no
      diff.
- [x] AC6: The profile's verify slot is clean, the serial/parallel identity suite included, and
      `devtools::check()` reports 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T1, T2
- AC5 → T3
- AC6 → T4

## Tasks

- [x] T1: Tests first in `tests/testthat/test-nested-tune-finalize.R`, opening with the oracle
      records header DESIGN's convention mandates (AC2 closed-form, AC3 live reference via
      `rsample::nested_cv()`): a helper building the recording `min_n` parameter
      (`dials::new_quant_param()` with an unknown upper bound, its finalizer appending `nrow(x)` and
      `sort(x$x1)` to an environment before delegating to `dials::get_n_frac_range()`) on the ranger
      workflow of `helper-orchestration.R:52`, inner `vfold_cv(v = 4)` or more so the racers' burn-in
      check (`R/checks.R:855`) passes, literal arguments in every `inside` spec (the M05 lesson); AC1
      over the registry (the pattern of `helper-orchestration.R:1558`) plus the evaluated-outer design;
      AC2 under a pinned seed, shown red before T2 and logged; AC3's two direct calls per grid shape
      (never `memoised()`, the M46 lesson); AC4's mocked `run_tuner()` on both untouched designs.
- [x] T2: `analysis_framed_inner(inner, split)` in `R/nested-resamples.R` beside
      `inner_resamples_from_split()`: when `anyDuplicated(split$in_id)` is 0 and every inner split's
      `$data` is `identical()` to `split$data` (strictly stronger than `is_fold_payload()`'s shared-frame
      check, `R/parallel.R:139`, which a `nested_cv()` design also passes), rebuild each split with
      `$data <- rsample::analysis(split)`, `in_id`/`out_id` mapped through `match(., split$in_id)`, and
      the rset's fingerprint recomputed as the constructor does; otherwise return `inner`. Called in
      `nested_fold_fit()` immediately before `run_tuner()` (`R/nested-tune-grid.R:633`), inside the
      fold seed's scope but drawing nothing.
- [x] T3: Roxygen on the three `@param param_info` sites and `?nested_final_fit`'s `@param results`;
      the DESIGN.md architecture sentence; the NEWS entry (no milestone number);
      `devtools::document()`.
- [x] T4: Verify slot, `devtools::check()`.

## Work log

- 2026-09-03: created by /milestone-plan from the candidate row filed at M45's plan gate; the row is absorbed.
- 2026-09-03: criteria audit ran in full mode ([O] fresh reader): 16 findings — `tune_bayes()` shown by execution to refuse an unknown range before any frame is read, so AC1 and Scope cover four tuners; a repeated outer `in_id` defeats the `match()` inverse, so the rebuild skips it and AC4 tests it; T2's predicate respelled (a `nested_cv()` design passes `is_fold_payload()`); the column-count Out claim corrected for recipes whose width differs across frames; AC2's seed pinned and its redness moved to T1; oracle-records header, racers' burn-in floor (inner v ≥ 4), every-frame wording, `@param results` as AC5's site, AC4's orchestrator and mock delegation, the fingerprint recompute, the GP4 copy cost and AC3's inline identity precondition all added; the GP1 divergence stated; test placement kept in a new file.
- 2026-09-03: plan gate chose rebuilding the inner rset over the analysis frame in the worker over pre-finalizing `param_info` per fold because the former leaves tune's finalization, messages and recipe refusal to tune (GP1) where the latter duplicates the preprocessor-molding step and must mirror the refusal; falsified by a tune release that finalizes on something other than the first split's frame, or reads the frame elsewhere in the run.
- 2026-09-03: plan gate declined the /milestone-brief escalation offered on the ip-touching tripwire, the mechanism read from tune's code and measured by execution; the user waived the pre-1.0 deprecation cycle for the changed candidates, NEWS naming the change, over an argument keeping the full-frame finalization for a cycle; the recipe-width and kernlab test cases the audit raised were declined, AC1's row-identity assertion covering the frame every finalizer reads.
- 2026-09-03: T1 — `tests/testthat/test-nested-tune-finalize.R` written, run before T2: AC1 red on all four tuners and the evaluated-outer design (every recorded frame 200 rows, matching no fold), AC2 red on every fold (candidates 20–100 against the fold bound [16, 80], the full frame's 100 exceeding it by 20), AC3 red on the unknown-range pair and green on the data-frame-grid pair, AC4 green on both untouched designs; 17 failures, 88 passes. The question gate was skipped: the plan fixes the helper's name, site, predicate and both test designs, and no dependency changes.
- 2026-09-03: T2 — `analysis_framed_inner()` added beside `inner_resamples_from_split()` and called in `nested_fold_fit()` immediately before `run_tuner()`, inside the tuning seed's scope (probed: `.Random.seed` unchanged across the call; the rebuilt splits' `analysis()`/`assessment()` rows identical to the design's; a `nested_cv()` inner rset returned as is). One deviation from the task text: the analysis frame is materialized only after every inner index maps, so an outer split whose own `in_id` reaches past the data (the "raising last_fit()" test in `test-nested-tune-grid-failures.R`) still fails at the outer fit, not the inner stage — the first full-suite run failed that one test before the reorder. Full suite after it: 4922 passes, 0 failures, 0 warnings, the serial/parallel identity file included; the finalize file 105 passes.
- 2026-09-03: T3 — `@param param_info` at the grid, Bayesian and annealing sites (the racers inherit the grid's), `?nested_final_fit`'s `@param results`, the DESIGN architecture paragraph naming the rebuild as the GP1 divergence, one NEWS entry; `devtools::document()` run, five Rd files regenerated, `air format --check R/` clean. The Bayesian text was written against a run: `nested_tune_bayes()` on an unknown-range `min_n` fails every fold with tune's "must be a <param> object without unknowns" note (executed 2026-09-03), so that site says it refuses rather than finalizes.
- 2026-09-03: T4 — `devtools::document()` on the committed tree leaves no diff; `devtools::check()` 0 errors, 0 warnings, 0 notes (the suite inside it green after T2's 4922-pass run). All tasks checked; status set to review.

## Review

- 2026-09-03 step 1: `git fetch`; origin/main at `5146278`, the branch's base — nothing to merge, no unpushed default-branch commits.
- 2026-09-03 step 2: branch pushed; draft PR #64 opened; `Resolves: —`, so no closing lines.
- AC1 evidence (2026-09-03): `devtools::test(filter = "nested-tune-finalize")` 105 passes, 0 failures, 0 skips, 25 s. The AC1 block ran all four registry entries other than `tune_bayes` (finetune 1.3.0, lme4, BradleyTerry2 installed, no skip) plus the evaluated-`vfold_cv()` outer design; each asserts every recorded finalizer frame matches exactly one fold's sorted `x1` key under `identical()` with `n == nrow(rsample::analysis(split))`, and that every fold was hit. Verified by reading the test.
- AC2 evidence (2026-09-03): same run; per fold, `full_upper - bounds[2] == 20` asserted, and every unique `.inner_metrics$min_n` inside `floor(160 * c(1/10, 5/10)) = [16, 80]`; T1's log records this red before T2 (candidates up to 100).
- AC3 evidence (2026-09-03): same run; `expect_inner_identical(lean, ref)` precondition, then two direct `nested_tune_grid()` calls under `set.seed(3)` per grid shape (unknown-range `param_info`, then `stoch_grid()`), `.inner_metrics` and `.metrics` `expect_identical()` on both pairs.
- AC4 evidence (2026-09-03): same run; `local_mocked_bindings(run_tuner = ...)` records the `resamples` argument and delegates; on the `nested_cv()` design and on the repeated-`in_id` `manual_rset()` outer design every fold's argument is `identical()` to `design$inner_resamples[[i]]`.
- AC5 evidence (2026-09-03): `grep -n '@param param_info' R/` → the grid, Bayesian and annealing sites; the grid and annealing text state finalization on the outer fold's analysis rows, the Bayesian text states tune's refusal before any frame is read and that the other tuners finalize on the analysis rows; `?nested_final_fit` `@param results` states the full-data finalization; `cairn/DESIGN.md:267-278` names `analysis_framed_inner()` as the GP1 divergence; `Rscript -e 'devtools::document()'` on the branch head leaves `git status --porcelain` empty.
- Gate, universal (2026-09-03): `cairn_validate.py` exit 0, all checks pass, 18 `references staleness` advisories (pre-existing). No IP/GP principle line changed in `cairn/DESIGN.md` (`git diff` shows none); `cairn_impact.py --changed` run anyway on the declared GP1/IP1 — its listed citations are the architecture paragraph this milestone added (`DESIGN.md:267`, `:275`) and prior records; none diverges.
- Gate, toolchain (2026-09-03): `devtools::document()` no diff; `NAMESPACE`/`man/` regenerated, not hand-edited; README.md and README.Rmd last changed in the same commit (`bbf51da`), in sync; `pkgdown::check_pkgdown()` "No problems found"; NEWS.md carries the entry, no milestone number in it; no new top-level file. `devtools::check()` result under AC6 below.
- Review lens [S] blame-history (2026-09-03): zero findings — the rebuild runs inside `fold_task()` on both dispatch paths, mutates no shared object, sits inside the fold seed's scope and the fold's `tryCatch`, and the `nested_cv()` / repeated-`in_id` bail-outs match M15's payload design and M03's fold isolation; no commit or D-entry undone.
- Review lens [S] prior-review record (2026-09-03): zero findings — the nearest archived finding (M23 F1, the unenforced inner-frame invariant) is the check `analysis_framed_inner()`'s shared-frame predicate enforces, not a regression; the M05/M45 call-over-values lesson stands since `run_tuner()` is unchanged; the GitHub probe found one real inline comment repo-wide (PR #30, a workflow file), none on the PRs that touched these files.
- AC6 evidence (2026-09-03): `devtools::test()` at branch head `af50ce8`: 57 files, 4922 expectations, no Failed/Skipped/Warnings section, `parallel-identity` and `nested-resamples-identity` files included, exit 0; `devtools::check()` at the same head: `Status: OK` (0 errors, 0 warnings, 0 notes), tests 404 s, total 5 m 2 s.
- Review lens [O] diff-bug (2026-09-03): 11 ranked findings, none demonstrating a criterion failing; the reviewer reproduced AC2 red with the rebuild mocked to identity (candidates 20–100 against [16, 80]) and confirmed the rebuilt splits' rows, class, rset attributes and recomputed fingerprint. Triage, fixed on the branch in `2517861`: F1 the `@section Reproducibility` recipe at the grid, race and annealing sites still named `resamples$inner_resamples[[i]]` as exactly what fold `i` runs — now states that on a `nested_resamples()` design it stands for the inner rset re-pointed at the analysis set, differing only under an unknown range; F3 the stage comment ("left for `last_fit()`") was false when a bad index was appended to the outer `in_id` rather than substituted (every inner index maps, `rsample::analysis()` raised inside the rebuild, the fold failing at "inner tuning") — an index-bound guard now returns the inner rset untouched, and the failures file asserts "outer fit" for the appended shape too; F6 the two boolean assertions in the finalize file now name the offending frames/candidates (`expect_identical()` against an empty vector); F8 the grid `@param param_info` and NEWS now name the repeated-row outer split as kept as it is. Follow-up: F2 (live-oracle tests build their reference on `inner_resamples[[i]]`, which a future oracle with an unknown range would need to re-point) → a LESSONS line at hygiene. Rejected: F4 all-`NA` `out_id` branch — unreachable, `inner_resamples_from_split()` always writes `out_id` and every rsample constructor does, and a `NULL` `out_id` rsplit is not one rsample builds; F5 no unit test of the helper — profile doctrine tests internal helpers indirectly, and AC1/AC3/AC4 cover it behaviorally while the id columns are kept by construction (`out <- inner`); F7 the rebuild is unconditional — the plan chose it over reading `param_info` (delegation, GP1), the GP4 cost disclosed in DESIGN; F9 `mtry()` as the headline example — the plan names it, and a recipe whose width differs across frames does change it; F10 no D-entry — GP1's own text places a documented divergence in DESIGN, and the plan gate's choice is on the work log, offered to the user at the gate; F11 the IP1 leakage suite unchanged — the frame-level assertion is AC1's test, placement only.
- AC6 re-evidence after the review fixes (2026-09-03): `devtools::test()` at `2517861`: 57 files, 4925 expectations (the appended-index case adds 3), no Failed/Skipped/Warnings section, the identity files included, exit 0; `devtools::check()` `Status: OK` (0/0/0), 5 m 5 s; `devtools::document()` no diff; `air format --check` clean.
- 2026-09-03 step 6: pre-gate checkpoint; PR #64 CI at this head: pkgdown and format-suggest pass, R-CMD-check legs and test-coverage pending.
- 2026-09-03: step-7 approval: PR #64 approved for merge (recommended option; no D-entry requested).
