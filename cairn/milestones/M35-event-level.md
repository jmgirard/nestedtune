# M35: The factor level a caller can name as the event

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP1, GP2, GP3
- **Branch/PR:** `m035-event-level` / https://github.com/tidymodels/nestedtune/pull/43

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

- [x] AC1: `nested_tune_grid()` and `nested_final_fit()` each take
      `event_level` after `...`, defaulting to `"first"`. A value outside
      `c("first", "second")`, in any of four forms — a wrong string, a
      non-character, a length-2 character vector, `NA_character_` — is refused
      by both before anything is fitted, the abort naming as its call the
      orchestrator the caller called and diagnosing the rejected value or its
      type.
- [x] AC2: `nested_tune_grid()` passes a `tune::control_last_fit()` carrying
      the caller's `event_level` to the outer scoring fit. On the two-class
      fixture its runs complete every outer fold, and the sensitivity it
      reports for each equals the value obtained by refitting that fold's
      `.selected` candidate on the fold's analysis set under its recorded
      `.outer_fit_seed`, predicting the assessment set, and calling
      `yardstick::sens_vec()` at that same `event_level` — no `tune` scoring
      function involved. The sensitivity differs between the two levels on at
      least one fold (T5's guard). AC2 anchors this site absolutely and AC4
      the final-fit inner site; AC3 and AC5 establish symmetry and
      mode-independence only.
- [x] AC3: on the two-class fixture, the two `nested_tune_grid()` runs at the
      same seed under `yardstick::metric_set(roc_auc, sens, spec)` complete
      every outer fold, have `.selected` identical, and on every fold the
      sensitivity at `event_level = "second"` equals the specificity at
      `"first"` and the specificity at `"second"` equals the sensitivity at
      `"first"`. `roc_auc` leads the set, which is what holds selection
      level-invariant.
- [x] AC4: `nested_final_fit()` sets the caller's `event_level` on its inner
      `tune::control_grid()`. On the two-class fixture under
      `yardstick::metric_set(roc_auc, sens, spec)`, the tuning run
      `extract_tune_results()` returns at `"second"` reports the metric values
      a `tune::tune_grid()` the test runs itself reports under
      `control_grid(allow_par = FALSE, event_level = "second")`, seeded by the
      recipe `R/nested-final-fit.R:106-118` documents — the object's own
      `tuning_seed`, kind-pinned, inner rset built inside that seed's scope.
      Against the same object at `"first"`, `roc_auc` agrees candidate for
      candidate while each candidate's `sens` and `spec` are exchanged, at
      least one candidate's two estimates differing.
- [x] AC5: on the two-class fixture under `metric_set(roc_auc, sens, spec)`
      and `event_level = "second"`, a `nested_tune_grid()` run at 2 mirai
      daemons and the serial run at the same seed complete every fold, the
      parallel run reporting `last_dispatch()` as `"parallel"`, and the two
      runs are `identical()` as whole objects.
- [x] AC6: `devtools::test()` clean, and `devtools::check()` clean — 0 errors,
      0 warnings, any NOTE justified in the review evidence.

## Coverage

- AC1 → T1, T6
- AC2 → T3, T5, T6
- AC3 → T5, T6
- AC4 → T4, T5, T6
- AC5 → T2, T5, T7
- AC6 → T8, T9, T10, T11

## Tasks

- [x] T0: (discovered) stop the drift check counting a figure that sits inside a
      longer number, which had the suite red on the default branch before this
      milestone changed anything.
- [x] T1: add `check_event_level()` to `R/checks.R` beside `check_param_info()`
      (`R/checks.R:418`), covering the four refusal forms AC1 names.
- [x] T2: add `event_level` to `nested_tune_grid()` after `...`; thread it
      through `dispatch_folds()` (`R/parallel.R:194-306`) and `fold_task()`
      (`R/parallel.R:917`) to `nested_fold_fit()`, and set it on the inner
      `tune::control_grid()` (`R/nested-tune-grid.R:390`).
- [x] T3: pass `tune::control_last_fit(event_level = ...)` to the outer
      `last_fit()` (`R/nested-tune-grid.R:411`), which takes no control today.
- [x] T4: add `event_level` to `nested_final_fit()` and `final_fit_worker()`,
      set on the inner `tune::control_grid()` (`R/nested-final-fit.R:254`).
- [x] T5: build the two-class fixture in
      `tests/testthat/helper-orchestration.R` — a binary outcome whose first
      factor level is the minority class, outer and inner splits stratified on
      it at a balance and `v` where `rsample` does not pool strata (measured:
      n = 120, 32 against 88, v = 3), a ranger classification workflow, a
      grid, and `yardstick::metric_set(roc_auc, sens, spec)`, which every
      criterion using the fixture runs under. Its design's `inside` call takes
      literal arguments, the way `final_nested()`'s does, because AC4 re-runs
      it. Two guards, measured under that metric set at both levels: both
      classes appear in every outer assessment set, in every per-fold inner
      assessment set, and in every assessment set of the rset
      `nested_final_fit()` builds from the full data; and sensitivity and
      specificity differ on at least one outer fold and one inner candidate.
- [x] T6: write `tests/testthat/test-event-level.R` — AC2's tune-free
      recomputation, AC3's identity, AC4's inner-run comparison, and AC1's
      refusals on both orchestrators — recording both oracles in the file
      header the way `tests/testthat/test-metrics-argument.R` records O1.
- [x] T7: extend the parallel-identity coverage to the new fixture (AC5).
- [x] T8: document `event_level` on both orchestrators; rewrite the
      "Differences from calling tune directly" section
      (`R/nested-tune-grid.R:272-275`), which says there is deliberately no
      `control` argument, to say what is settable and what is not; run
      `devtools::document()`, add the NEWS entry, run `air format .`.
- [x] T9: full `devtools::check()`; record the NOTEs.
- [x] T10: (discovered) repair `tests/testthat/test-ci-workflows.R`, which the
      default branch's rewrite of `pkgdown.yaml` into a single job left asserting
      two job names that no longer exist.
- [x] T11: (discovered) give `README.Rmd`, which the default branch added
      without one, its `.Rbuildignore` entry, so `devtools::check()` stops
      reporting a non-standard top-level file.
- [x] T12: (discovered) add `event_level` to both documented by-hand recipes
      and to `cairn/DESIGN.md:237-239`, which this milestone's change falsified.

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
- 2026-08-31: T2 — `event_level` added to `nested_tune_grid()` after `metrics`, checked at entry, and threaded through `dispatch_folds()`, both dispatch shapes, `fold_task()` and `nested_fold_fit()` onto the inner `tune::control_grid()`. Six test stand-ins for `fold_task`/`nested_fold_fit` widened to the new signature, the two recorded formals vectors updated, and three shifted `helper-time-budget.R` line numbers re-pointed. `air format .` run; `devtools::test()` 1670 pass, 0 fail.
- 2026-08-31: T3 — the outer `last_fit()` now receives `tune::control_last_fit(event_level = event_level)`; it took no control object before, so outer-fold metrics were computed at tune's default level whatever the inner run had been told. `allow_par` left at tune's default per the implementation gate. `devtools::test()` 1670 pass, 0 fail.
- 2026-08-31: T4 — `event_level` added to `nested_final_fit()` and threaded through `final_fit_worker()` to its inner `tune::control_grid()`. Its outer step is `parsnip::fit()`, which computes no metrics, so there is no second site here. `devtools::test()` 1670 pass, 0 fail.
- 2026-08-31: amendment criteria audit ran in FULL mode (user-facing tier), two rounds, each a fresh [O] reader that authored none of the wording. Round 1 returned 10 findings on the first revision of AC3/AC4/AC5/T5; round 2 returned 9 on the second. Fixed across both: AC3 was falsifiable by correct code under a `sens`-led metric set, because `select_best()` resolves its metric from the tuned object's first metric name and the two runs then selected different candidates (measured on the fixture: fold 1, sensitivity 0.9667 at `"second"` against specificity 0.9333 at `"first"`); AC4's difference clause quantified over every value in a whole `tune_results` and a coincident sens/spec row satisfies correct code; AC5 claimed `.grid` was compared nowhere in `test-parallel-identity.R`, which asserts whole-object identity at :47, :78 and :298, and named `.grid` as where event-level scoring lands where `scored_candidates()` strips every metric column; AC3 and AC5 were both vacuous on a run where no fold completed, and AC5 on a parallel run that fell back to serial; AC4 cited `reference_final_fit()` for a seeding independence it deliberately has and this oracle does not; T5's guard enumerated a different rset than the criteria quantify over, and named no metric set or level.
- 2026-08-31: substantive amendment adopted at the mini gate — AC3, AC4, AC5 and T5 reworded. The fixture's metric set becomes `metric_set(roc_auc, sens, spec)`: `roc_auc` is byte-identical at the two event levels, so it can lead and hold selection invariant while `sens` and `spec` carry the difference. AC3 now requires every outer fold completed and `.selected` identical between the runs; AC4 states the exchange rather than an unbounded difference and names the seeding recipe it actually follows; AC5 requires every fold completed and `last_dispatch()` reporting `"parallel"`, and compares whole objects; T5's guards enumerate the per-fold inner rsets and the final-fit rset as well as the outer assessment sets, and its design's `inside` call takes literal arguments. Plan-owned body 149 lines against the 150 cap, so no compression pass was owed.
- 2026-08-31: T5 — two-class fixture added to `helper-orchestration.R`: `cls_data()` (n = 120, 32 events against 88, event the first level), `cls_workflow()` (ranger classification, `min_n` tuned), `cls_grid()`, `cls_metrics()` (`metric_set(roc_auc, sens, spec)`), `cls_nested()` (v = 3, outer and inner stratified on the outcome, literal arguments), plus `missing_assessment_levels()` and `cls_design_rsets()` for the class-presence guard. Measured: both classes present in all three outer assessment sets and in all nine per-fold inner assessment sets, no rsample pooling warning. `devtools::test()` 1670 pass, 0 fail.
- 2026-08-31: T6 — `tests/testthat/test-event-level.R` written: a fixture guard, AC1's refusals on both orchestrators (message and named call), AC2's count-from-the-refit recomputation, AC3's exchange with `.selected` asserted equal, AC4's hand-run `tune_grid()` comparison. Three oracles recorded in the header: O1 closed-form (sensitivity as the definitional rate, `sens_vec()` read beside it), O2 live (the independent `tune_grid()`), O3 invariant (the level exchange). Discrimination proven by planting each defect separately: removing `event_level` from the outer `control_last_fit()` turned AC2 red on all three folds and AC3 red on two, leaving AC4 green; removing it from `nested_final_fit()`'s inner `control_grid()` turned AC4 red and left AC2 and AC3 green. `devtools::test()` 1732 pass, 0 fail.
- 2026-08-31: T7 — `test-parallel-identity.R` gained a two-class case at `event_level = "second"`: serial and 2-daemon runs, both completing every fold, `last_dispatch()` asserted `"parallel"`, whole objects `identical()`. Its pool start registered in `helper-time-budget.R`. Discrimination proven by dropping `event_level` from the leaning dispatch wrapper's call to the worker, a daemon-path-only defect: the new test went red and the serial-path tests stayed green. `devtools::test()` 1737 pass, 0 fail.
- 2026-08-31: T8 — `event_level` documented on both orchestrators; the "Differences from calling tune directly" section rewritten from "there is deliberately no `control` argument" to three lists — settable (`event_level`, reaching both control objects), forced (`allow_par = FALSE` on inner tuning), and not offered, naming why each remaining `control_grid()` slot would have nothing to act on here. NEWS entry added, `devtools::document()` run, `air format .` clean. `devtools::test()` 1737 pass, 0 fail.
- 2026-08-31: T9 — `devtools::check()` Status OK, 0 errors, 0 warnings, 0 notes, duration 2m 34.1s, tests `[71s/112s]`. No NOTE to justify. That test leg is the figure M34 recorded (`64s/100s`), not the 561s standalone / `[341s/599s]` the ROADMAP's slow-suite candidate row records for 2026-08-31; the row's phenomenon did not reproduce here.
- 2026-08-31: all tasks done, suite and check clean; status set to review.
- 2026-08-31: /milestone-review returned M35 to in-progress at step 1: AC6 fails. `origin/main` had moved 6 commits since the branch was cut (external PR #30, merged on GitHub); after merging it in, `devtools::test()` is 5 FAIL / 1730 PASS, all in `test-ci-workflows.R:54,64,65,66,78` — commit 72c3be2 replaced the two-job pkgdown workflow (`build` + `deploy`) with a single `pkgdown` job and left the test asserting the old job names, so `main` itself is red. Nothing in M35's own diff is implicated; the fix is a discovered task in the T0 class. Draft PR opened: https://github.com/tidymodels/nestedtune/pull/43.
- 2026-08-31: minor amendment — added discovered task T10, same class as T0. `origin/main`'s commit 72c3be2 replaced `pkgdown.yaml`'s `build` + `deploy` job pair with a single `pkgdown` job that builds and deploys in one checkout; `test-ci-workflows.R` still asked `job_uses()` for the two vanished job names, so both its tests fell over (`job_uses()` returning `NULL`, then a subscript-out-of-bounds on the empty `checkout`). Nothing in M35's diff is implicated. Implementation gate chose repairing the test over restoring the two-job workflow (the rewrite is main's deliberate change and matches the r-lib template), landing it on this branch rather than a separate hotfix (AC6 cannot pass while the suite is red, and T0 set the precedent), and re-siting the block-boundary self-test on `pr-commands.yaml`.
- 2026-08-31: T10 — `test-ci-workflows.R` repaired. The ordering test now reads the `pkgdown` job and asserts what it always asserted: a checkout precedes `github-pages-deploy-action` in the job's steps. The old boundary guard (`build`'s `upload-artifact` must not appear in `deploy`'s steps) is vacuous with one job that is also the file's last, so the `job_uses()` self-test moved to `pr-commands.yaml`, whose `document` and `style` jobs run in sequence and end with the same `pr-push` step — one occurrence is what proves the read stopped at the boundary. The file header's account of the PR #17 bug is unchanged; a paragraph records that the checkout is now the single job's own first step. Discrimination proven by planting each defect separately: unbounding the block (`end <- length(lines)`) turned the boundary test red at two `pr-push` occurrences and left the ordering test green; deleting the checkout step from `pkgdown.yaml` turned the ordering test red and left the boundary test green. `air format .` clean, `devtools::test()` 1736 pass, 0 fail.
- 2026-08-31: minor amendment — added discovered task T11. After the T10 repair, `devtools::check()` was Status 1 NOTE: `Non-standard file/directory found at top level: 'README.Rmd'`. `origin/main`'s commit 72c3be2 added `README.Rmd` and three `.Rbuildignore` entries but not its own; the profile's consistency gate requires a new top-level file to have one.
- 2026-08-31: T11 — `^README\.Rmd$` appended to `.Rbuildignore`. `devtools::check()` Status OK, 0 errors, 0 warnings, 0 notes, duration 2m 53.7s, tests `[82s/125s]`. No NOTE to justify.
- 2026-08-31: all tasks done, suite and check clean on the merged branch; status set to review again.
- 2026-08-31: /milestone-review returned M35 to in-progress at step 4: the consistency gate FAILs `weight caps` — 155 plan-owned lines against the <150 cap, Acceptance criteria 54 and Tasks 46 the heaviest, pushed over by the T10 and T11 amendments; both sections are plan-owned so the compression is an implement-side amendment. Everything else gathered fresh passed: `devtools::test()` 1736 pass 0 fail, `devtools::check()` Status OK 0/0/0, `document()` no diff, `pkgdown::check_pkgdown()` clean, NEWS entry present, branch level with `origin/main`. The three review lenses ran; the [O] lens returned 11 ranked findings, of which the documented by-hand recipes on both orchestrators (`R/nested-tune-grid.R:93-104`, `R/nested-final-fit.R:106-118`) and `DESIGN.md`'s architecture paragraph state a pre-M35 shape the change falsified. All 11 are recorded in the Review section. Second defect return on this milestone.
- 2026-08-31: amendment criteria audit ran in FULL mode (user-facing tier), three rounds, each a fresh [O] reader that authored none of the wording under audit. Every round returned the same compression verdict: no binding clause dropped or weakened, and no place made satisfiable by code the old wording would have failed. Round 1 returned 5 findings on the first compression, round 2 returned 5 on the repaired text, round 3 returned 7 on the final text. Fixed across the rounds: AC2 was satisfiable by code that failed every outer fold, its per-fold equality vacuous and its difference clause having no values to compare, so it gained "complete every outer fold"; AC1's "each test asserts the abort's message and the call it names" bound an instrument, replaced by the deliverable property (the abort names the orchestrator as its call and diagnoses the value); the first compression dropped `c("first", "second")` from AC1, so an implementation refusing `"second"` would have satisfied it; "diagnosing the rejected value" was false for three of AC1's four forms, `check_event_level()` emitting `{.obj_type_friendly}` rather than `{.val}` outside the length-1 non-`NA` character case; AC2's "the values reported at `"first"` and `"second"` differ" is falsified by correct code, `roc_auc` being byte-identical at the two levels; AC4 cited `R/nested-final-fit.R:100-112` for a recipe block that runs 106-118; AC4's "(T5's inner guard)" pointed at a guard that lives in AC4's own test (`test-event-level.R:309`), not the fixture helper.
- 2026-08-31: substantive amendment adopted at the mini gate — `## Acceptance criteria` compressed from 54 lines to 46, the plan-owned body from 155 to 147, clearing the <150 cap the consistency gate FAILed. What was removed is rationale the work log records: AC1's `test-nested-tune-grid-checks.R` style pointer, AC2's "the metric computed by yardstick directly", AC3's `select_best()` mechanism sentence and its symmetry disclaimer, AC4's "not the seeding" clause and its tune-defaults justification for naming the metric set, AC5's `test-parallel-identity.R` pairing citation and its mode-independence disclaimer — the two disclaimers consolidated into one sentence in AC2. Repairs adopted with it, each at the user's selection: AC1 regained `c("first", "second")` and now says "the rejected value or its type"; AC4's citation moved to `R/nested-final-fit.R:106-118`; AC2's difference clause, tightened to a per-fold universal that T5's guard does not underwrite, was narrowed back to "on at least one fold (T5's guard)". A narrowing throughout: no criterion was added and no criterion's promise extended to a property or domain it did not previously bind (D-118).
- 2026-08-31: the round-3 audit's six inherited findings are held for review disposition, not repaired here — each repair would widen the criteria set on a milestone with two recorded defect returns (D-118), and T12 is the follow-up home for the documentation one. (a) AC1's call-name and diagnosis clauses are asserted for one exemplar per orchestrator, not all four forms. (b) AC1's four forms leave `check_event_level()`'s `NULL` and `character(0)` branches unbound (Review finding 9). (c) AC4 quantifies over "the metric values" while the test compares `collect_metrics()`, the resample-averaged summary, so a defect preserving the mean satisfies it. (d) AC4's line citation will drift when T12 rewrites that block, and `test-event-level.R`'s O2 header still cites the old `100-112`. (e) AC5 binds the parallel run's `last_dispatch()` but not the serial run's, so leaked daemons would leave the identity holding and establishing nothing; `test-parallel-identity.R:490` does assert it. (f) No criterion binds documentation correctness, which is what T12 repairs.
- 2026-08-31: minor amendment — added discovered task T12, carrying review findings 1, 2 and 3. Both documented by-hand recipes and `cairn/DESIGN.md`'s architecture paragraph describe the pre-M35 shape this milestone's own change falsified; finding 1 was confirmed by execution, the documented recipe returning fold 1's sens/spec pair transposed against the package's 0.967 / 0.0909 at `"second"`.
- 2026-08-31: T12 — `event_level` added to both documented by-hand recipes and to `cairn/DESIGN.md`'s architecture paragraph. `nested_tune_grid()`'s recipe gained it on the inner `control_grid()` and gained the `control_last_fit()` argument its `last_fit()` line never carried; `nested_final_fit()`'s gained it on the inner `control_grid()`, reflowed so the fenced block keeps its line count and AC4's `106-118` citation stays exact. `test-event-level.R`'s O2 header, which cited the pre-M35 `100-112`, now cites `106-118` too. Verified by execution on the two-class fixture at `event_level = "second"`, seed 42, fold 1: the package reports sens 0.8333 / spec 0.4545 / roc_auc 0.6364, and the recipe as now documented returns the same three. Discrimination proven by deleting the `control_last_fit()` line again — the recipe then returns sens 0.4545 / spec 0.8333, the pair transposed, which is review finding 1 reproduced. `devtools::document()` run, `air format .` clean, `devtools::test()` 1736 pass, 0 fail.
- 2026-08-31: all tasks done. `devtools::test()` 1736 pass, 0 fail; `devtools::check()` Status OK, 0 errors, 0 warnings, 0 notes, duration 2m 48.7s, tests `[80s/121s]`. No NOTE to justify. `cairn_validate` weight caps PASS at 147 plan-owned lines. Status set to review; third time.
- 2026-08-31: /milestone-review third pass — all six criteria verified with fresh evidence and ticked; consistency gate PASS (cairn_validate 16/16, document no-diff, pkgdown clean, air clean, check 0/0/0). Three lenses ran: [S] blame no finding, [S] prior-review 4, [O] diff-bug 10. Nothing meets the return floor; disposition goes to the approval gate.

## Decisions

## Review

### 2026-08-31 — returned to in-progress at the consistency gate

**Gate failure.** `cairn_validate.py` exits 1 on `weight caps`: the milestone's
plan-owned body is 155 lines against the <150 cap (heaviest first: Acceptance
criteria 54, Tasks 46, Scope 31). The two amendments that added T10 and T11 took
it past the 149 lines the AC3/AC4/AC5 rewrite left. Both over-cap sections are
plan-owned, so the compression is `/milestone-implement`'s under the amendment
protocol, not a review-side edit. Advisory alongside it, not a failure: the
sizing tripwire at 12 tasks.

**What did pass, gathered fresh on the merged branch.** `devtools::test()` FAIL
0 / PASS 1736. `devtools::check()` Status OK, 0 errors, 0 warnings, 0 notes,
duration 2m 49.4s, tests `[80s/123s]`. `devtools::document()` leaves no diff.
`pkgdown::check_pkgdown()` reports no problems. NEWS.md carries the
`event_level` entry. README.Rmd and README.md are both at the default branch's
own commit and in sync. No `DESIGN.md` principle changed, so `cairn_impact.py`
was not owed. The branch is level with `origin/main`. No acceptance-criterion
checkbox was ticked: the gate failed before per-criterion evidence was recorded,
and AC fencing gives no tick without its evidence line.

**Review fan-out.** Three fresh-context lenses, distinct evidence bases. The [S]
blame-history lens reports no finding: the RNG contract holds because
`check_event_level()` runs before the seed draw on both orchestrators, the
`...` barrier extension matches how `param_info` was added, the parallel
threading is positionally consistent, and the T10 relocation of the CI-workflow
boundary guard keeps its discriminating power. The [S] prior-review lens reports
no finding: no archived `## Review` finding on the touched files is
reintroduced, and the one PR carrying real inline comments touches no file in
this diff. The [O] diff-bug lens confirms `event_level` reaches every hop on
both orchestrators and both dispatch shapes, and reports 11 findings, ranked:

1. `R/nested-tune-grid.R:93-104` — the documented "Fold `i` is exactly:" recipe
   still shows `last_fit()` with no control and `control_grid(allow_par =
   FALSE)` with no `event_level`, so it no longer reproduces a fold. Confirmed
   by execution on the milestone's fixture at `"second"`, fold 1: the package
   reports sens 0.967 / spec 0.0909, the documented recipe returns the pair
   transposed.
2. `R/nested-final-fit.R:106-118` — the same omission in the final-fit
   by-hand recipe; AC4's own test had to add `event_level` to make the
   reconstruction agree, so the test follows a recipe the docs do not state.
3. `cairn/DESIGN.md:237-239` — the Architecture description still names a
   `last_fit()` with no control, i.e. the pre-M35 shape.
4. `R/nested-tune-grid.R:435-450` — the outer `control_last_fit()` now asserts
   `allow_par = TRUE`, and the roxygen "Forced:" paragraph says only that inner
   tuning is serial; the justification sits in a code comment. Inert today.
5. `tests/testthat/test-fixture-cache.R:230+` — the signature list that claims
   to enumerate every fixture signature gained none of M35's four `cls_*`
   entries, and no listed signature varies `event_level`.
6. The milestone's `## Decisions` is empty and no D-entry records choosing a
   narrow `event_level` argument over tune's `control` object.
7. Every internal hop defaults `event_level = "first"`, so a dropped argument
   degrades silently rather than erroring; matches `param_info`'s style.
8. `tests/testthat/helper-drift-manifest.R:85-88` — the T0 lookbehind guards
   only the left side of a rendering, though its comment claims both sides.
9. `tests/testthat/test-event-level.R:145-160` — `NULL` and `character(0)` are
   refused but never exercised, and T1's work-log line overstates the bullets.
10. `tests/testthat/test-event-level.R:66` — `cls_runs()` takes `d` unused.
11. AC3 and AC5 are non-vacuous only by reference to the fixture guard and to
    AC2/AC4; the criteria disclose this themselves.

Disposition of the findings goes to the maintainer at the next review's gate.
Findings 1, 2 and 3 are the ones an implement pass should carry: 1 and 2 are
user-facing prose that the milestone's own change falsified.

### 2026-08-31 — third review pass: all criteria verified

Evidence gathered fresh on the branch, level with `origin/main` (0 behind, 19
ahead; `origin/main` has not moved since the merge recorded in the work log).

**Per criterion.**

- AC1 — `test-event-level.R`'s two refusal tests are green. Each of the four
  forms (`"third"`, `1L`, `c("first", "second")`, `NA_character_`) is refused by
  both orchestrators with a message naming `"first"` or `"second"`; the abort's
  call is `nested_tune_grid` / `nested_final_fit` respectively, and the message
  carries the rejected value (`"third"`) or its type (`"an integer"`). A second
  test shows `.Random.seed` unchanged across the refusal, so nothing is fitted.
- AC2 — green. On the two-class fixture both runs report `.completed` TRUE on
  every outer fold, and for each fold the reported `sens` equals the rate
  counted from a refit of `.selected` under `.outer_fit_seed` with no tune
  scoring function involved; `yardstick::sens_vec()` read beside it agrees. The
  per-fold assertion that `sens` at `"first"` differs from `sens` at `"second"`
  holds on all three folds.
- AC3 — green. `.selected` is `identical()` between the two runs, every fold
  completed, and on each fold sens@"second" == spec@"first" and
  spec@"second" == sens@"first".
- AC4 — green. `collect_metrics(extract_tune_results(fit))` at `"second"` is
  `identical()` to the hand-run `tune::tune_grid()` under
  `control_grid(allow_par = FALSE, event_level = "second")` seeded by the
  documented recipe. Against the same object at `"first"`, `roc_auc` agrees
  candidate for candidate while `sens` and `spec` are exchanged, with at least
  one candidate's two estimates differing.
- AC5 — green. `test-parallel-identity.R`'s new two-class case at
  `event_level = "second"` completes every fold in both runs, `last_dispatch()`
  reports `"serial"` then `"parallel"`, and the two objects are `identical()`.
- AC6 — green. `devtools::test()` FAIL 0 / WARN 0 / SKIP 0 / PASS 1736.
  `devtools::check()` Status OK — 0 errors, 0 warnings, 0 notes; duration
  2m 48.7s, tests `[78s/121s]`. No NOTE to justify.

The two test files were also run on their own to name the criteria they carry:
`test-event-level.R` 62 assertions, 0 failures; `test-parallel-identity.R` all
green.

**Consistency gate — PASS.** `cairn_validate.py` exits 0, all 16 checks PASS
including `weight caps` (147 plan-owned lines) and `coverage complete`; 19
advisories, none a gate failure (the 18 references-staleness lines, unchanged,
and the 13-task sizing tripwire). No `DESIGN.md` principle (IP/GP) changed —
only the Architecture prose — so `cairn_impact.py` was not owed. Toolchain
checks from the `r-package` profile's `consistency-gate` slot:
`devtools::document()` leaves no diff (`git status` clean after it);
`pkgdown::check_pkgdown()` reports no problems; `NEWS.md` carries the
`event_level` entry; README.Rmd/README.md are the default branch's own and in
sync; `.Rbuildignore` gained `^README\.Rmd$` and `check()` reports no
non-standard-file NOTE; `air format --check .` clean; `devtools::check()` clean.

**Review fan-out.** Three fresh-context lenses, distinct evidence bases.

*Scope note the [O] lens surfaced and the others inherited:* the lenses were
pointed at `main..HEAD`, and the local `main` is 6 commits behind
`origin/main`. M35's diff is `origin/main..HEAD` — 23 files. Findings against
`.github/`, `_pkgdown.yml`, `README.*` and `DESCRIPTION` are therefore about
commits already on the default branch (external PR #30), not this milestone's
work.

*[S] blame-history lens — no finding.* The outer `last_fit()` has carried no
control object since M02 (`39d2f68`); M35 closes that gap deliberately. D-010
("no `control` argument") is not violated — no generic `control` argument is
added. D-011/D-016's RNG contract is untouched, `allow_par = FALSE` is still
hard-coded on every inner `control_grid()`, M34's `...`-barrier placement is
followed, the mocked `fold_task()` was updated in lockstep with the signature,
and `DESIGN.md`'s architecture prose now matches the code.

*[S] prior-review-record lens — 4 findings (P1–P4).*

*[O] diff-bug lens — 10 findings (O1–O10).* It confirms `event_level` reaches
every hop on both orchestrators and all three dispatch shapes, that
`check_event_level()` runs before the seed draw on both entry points, and that
ten input shapes are all refused sensibly. It reports no defect that changes a
reported number.

**Findings and disposition.** Ranked as reported.

| # | Finding | Disposition |
|---|---|---|
| O1 | `R/nested-tune-grid.R:443-446` — the comment justifying the new outer control object says `allow_par` "is left at tune's own default rather than forced off the way the inner run's is". In tune 2.1.0 `control_last_fit()`'s `allow_par` default is `FALSE` (verified at review: `function(verbose = FALSE, event_level = "first", allow_par = FALSE)`), so the comment tells a reader the opposite of what is true. DESIGN's "keep `tune` serial within the outer loop" convention is satisfied here only by an upstream default the package does not pin, and the roxygen "Forced:" paragraph never says the outer fit is serial. | recommend **fix now** — behaviour is already correct, so pinning `allow_par = FALSE` and correcting the comment is zero-risk |
| O2 | `tests/testthat/helper-drift-manifest.R:76-88` — T0's guard prefixes `(?<![0-9.,])`, blocking a match on the *tail* of a longer number but not the *head*: `9.13` still matches inside `9.134`, `150 B` inside `150 Bytes`. The comment claims both sides. (Prior review's finding 8, still open.) | recommend **fix now** — one regex and its comment |
| O3 | `tests/testthat/test-fixture-cache.R:230-238` — the list titled "the key separates every fixture signature this suite asks for" gained none of M35's four `cls_*` signatures, and no pair in it differs only by `event_level`, so the separation the new tests depend on is assumed rather than pinned. (Prior review's finding 5.) | recommend **follow-up** — candidate row |
| O4 | `tests/testthat/test-event-level.R:170-183` — AC1's "before anything is fitted" is pinned by a `.Random.seed`-unchanged assertion against `nested_tune_grid()` only, never `nested_final_fit()`. The property itself holds: verified at review by direct execution — `nested_final_fit(..., event_level = "third")` errors and leaves `.Random.seed` identical. | recommend **fix now** — three lines closing an AC-evidence gap |
| O5 | `tests/testthat/test-parallel-identity.R:471` — the new test is labelled "BC1", already used at `:23` and `:81` in the same file; three tests reporting as BC1 makes a failure line ambiguous. The sibling M34 test names its origin ("BC6: … (M34, AC4)"). | recommend **fix now** — rename to BC7 |
| O6 | `R/nested-tune-grid.R:296-297` — the "Not offered" paragraph justifies withholding `verbose` with "output from inside a mirai daemon is not shown", but the function runs serially whenever no daemons are configured, and there `control_grid(verbose = TRUE)` would print. The stated reason does not cover the default path. | recommend **fix now** — user-facing prose |
| O7 | `tests/testthat/test-event-level.R:66` — `cls_runs(d, nested, wf)` takes `d` and never uses it. | recommend **fix now** — trivial |
| O8 | Every internal hop defaults `event_level = "first"` (`R/parallel.R:200`, `:929`, `R/nested-tune-grid.R:401`, `R/nested-final-fit.R:253`), so a hop that stopped threading it would degrade silently rather than error. | recommend **reject** — matches how `param_info` was added (M34); a convention observation, not a regression, and T7's daemon test covers today's hops |
| O9 | The milestone's `## Decisions` is empty and no D-entry records choosing a narrow `event_level` argument over accepting tune's `control` object, though the plan gate recorded it with a falsifier and the roxygen now asserts the stance publicly. (Prior review's finding 6, still open.) | recommend **fix now** — a D-entry |
| O10 | `R/nested-tune-grid.R:293-295` calls `pkgs` and `workflow_size` "inert under `allow_par = FALSE`". True for `workflow_size`; `pkgs` is redundant serially but the fold runs inside a mirai daemon on the parallel path, where the claim holds only because the daemon pre-flight already requires the namespace — a different guarantee than the sentence gives. | recommend **fix now** — bundled with O6's prose pass |
| P1 | `.github/workflows/pkgdown.yaml` — a single `pkgdown` job both runs `build_site_github_pages()` (executing the ref's vignette and example code) and carries job-level `permissions: contents: write`. M17's review split exactly this into a read-only `build` job and a separate `deploy` job for exactly this reason (F2, fixed). | **out of scope, follow-up** — the file is not in M35's diff (`origin/main..HEAD` touches no `.github/` file); it arrived on the default branch with external PR #30. Recommend a candidate row, and it is the one with a security edge |
| P2 | `.github/workflows/pkgdown.yaml` — `extra-packages: any::pkgdown, local::.` reintroduces the ad-hoc `any::pkgdown` line D-022 rejected, making `DESCRIPTION`'s `Config/Needs/website` declaration decorative again (M17 F1). | **out of scope, follow-up** — same origin as P1; fold into the same candidate row |
| P3 | Upstream PR tidymodels/nestedtune#30 carries an unresolved inline comment from `topepo` on the `pkgdown.yaml` hunk that deleted the split-job and guard steps: "I wasn't sure if any of this should be retained." | **out of scope, follow-up** — same origin; the same candidate row is where the question gets answered |
| P4 | `R/parallel.R:364` — the comment "That signature has since grown `...` and `param_info` (M34), neither of which carries a bound" was not updated for `event_level`, which M35 adds to the same signature. M34's own review caught and fixed this exact drift one milestone earlier. Confirmed by reading the line. | recommend **fix now** — one line |

**Return floor.** No finding demonstrates an acceptance criterion failing, and
none is a load-bearing defect in what the package does for a user: O1 is a
comment that misdescribes correct behaviour, O4's property holds under
execution, and P1–P3 are pre-existing on the default branch. Status stays
`review`; disposition goes to the maintainer at the approval gate.

