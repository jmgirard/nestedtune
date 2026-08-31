# M35: The factor level a caller can name as the event

- **Status:** in-progress
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

- [ ] AC1: `nested_tune_grid()` and `nested_final_fit()` each take
      `event_level` after `...`, defaulting to `"first"`. A value outside
      `c("first", "second")` — a wrong string, a non-character, a length-2
      character vector, `NA_character_` — is refused by both before anything is
      fitted, and each test asserts the abort's message and the call it names,
      the way `tests/testthat/test-nested-tune-grid-checks.R` asserts the
      existing checks.
- [ ] AC2: `nested_tune_grid()` passes a `tune::control_last_fit()` carrying
      the caller's `event_level` to the outer scoring fit. On the two-class
      fixture the sensitivity it reports for each completed outer fold equals
      the value obtained by refitting that fold's `.selected` candidate on the
      fold's analysis set under its recorded `.outer_fit_seed`, predicting the
      assessment set, and calling `yardstick::sens_vec()` at that same
      `event_level` — the metric computed by yardstick directly, no `tune`
      scoring function involved. The values reported at `"first"` and
      `"second"` differ.
- [ ] AC3: on the two-class fixture, the two `nested_tune_grid()` runs at the
      same seed under `yardstick::metric_set(roc_auc, sens, spec)` complete
      every outer fold, have `.selected` identical, and on every fold the
      sensitivity at `event_level = "second"` equals the specificity at
      `"first"` and the specificity at `"second"` equals the sensitivity at
      `"first"`. `roc_auc` leads the set so that selection is level-invariant:
      `select_best()` reads the tuned object's first metric name, and under a
      `sens`-led set the two runs select different candidates and the identity
      fails on correct code. The criterion establishes symmetry, not which
      level is which; AC2 is the absolute anchor.
- [ ] AC4: `nested_final_fit()` sets the caller's `event_level` on its inner
      `tune::control_grid()`. On the two-class fixture under
      `yardstick::metric_set(roc_auc, sens, spec)`, the tuning run
      `extract_tune_results()` returns at `"second"` reports the metric values
      a `tune::tune_grid()` the test runs itself reports under
      `control_grid(allow_par = FALSE, event_level = "second")`, seeded by the
      by-hand recipe `R/nested-final-fit.R:100-112` documents — the object's
      own `tuning_seed`, kind-pinned, inner rset built inside that seed's
      scope — so what is checked is what tune did with the setting, not the
      seeding. Against the same object at `"first"`, `roc_auc` agrees
      candidate for candidate while each candidate's `sens` and `spec` are
      exchanged, at least one candidate's two estimates differing (T5's inner
      guard). Under tune's classification defaults there is no such
      difference, which is why the set is named.
- [ ] AC5: on the two-class fixture under `metric_set(roc_auc, sens, spec)`
      and `event_level = "second"`, a `nested_tune_grid()` run at 2 mirai
      daemons and the serial run at the same seed complete every fold, the
      parallel run reporting `last_dispatch()` as `"parallel"` — the pairing
      every identity test in `tests/testthat/test-parallel-identity.R` uses,
      without which the comparison is serial against serial — and the two are
      `identical()` as whole objects. This establishes mode-independence, not
      correctness: a level dropped on both paths preserves the identity, and
      AC2 and AC4 are the anchors for that.
- [ ] AC6: `devtools::test()` clean, and `devtools::check()` clean — 0 errors,
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
