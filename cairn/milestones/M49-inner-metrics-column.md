# M49: Each outer fold keeps its inner search's metrics in place of `.grid`

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4, GP4
- **Resolves:** #57 closes
- **Branch/PR:** m049-inner-metrics-column · https://github.com/tidymodels/nestedtune/pull/59

## Goal

A `nested_results` carries, per outer fold, the inner tuning run's `collect_metrics()` table in a `.inner_metrics` column
in place of `.grid`, so a user can compute the best candidate or plot a Bayesian search's trajectory from the object.

## Scope

**In:** user-facing tier — the exported results class changes columns. The fold worker records
`tune::collect_metrics(tuned)` as `.inner_metrics` (the Bayesian table carrying `.iter`); a fold that tuned and then
failed its outer fit keeps its table; a fold that scored nothing carries a zero-row table with a completed fold's columns,
built without calling `collect_metrics()` on it (it raises when every candidate fails — the M03 lesson). `.grid` is
removed from the constructor, the invariant set, `has_results_columns()`, the readers, the docs and the vignette; the
print and summary candidate-set comparison derives each fold's candidate set from the distinct parameter rows of
`.inner_metrics` (metric columns, `.config` and `.iter` dropped), keeping `candidate_key()`'s value comparison, which is
what tells apart per-fold random grids that share `.config` labels. `.selected` is unchanged. D-043 supersedes D-031's
column list and D-023's `.grid` clause and records that `extract_scored_candidates()` keeps its candidate shape. Size:
measured 2026-09-02 on a 5-fold `mtcars` ranger grid of 10 candidates and 2 metrics, the summarized table is 3,872 B
against 3,368 B for `.grid` and `.selected` together (GP4); the M23 payload tests measure outbound dispatch only.

**Out:** dropping `.selected` (gate: kept — it records what the fold's outer fit used under `select_best()`'s tie rules,
and DESIGN.md calls retained selections first-class); an `autoplot()` view of the inner trajectory → candidate row;
reshaping `extract_scored_candidates()` to the metrics table → recorded in D-043, not done; a `nested_results` method
for that generic → not planned; a user control on the inner run → M48.

## Acceptance criteria

- [x] AC1: Each completed fold's `.inner_metrics` is identical to `tune::collect_metrics()` of the inner tuning run re-run
      by hand under the fold's tuning seed, for both tuners, the Bayesian table carrying `.iter`; a fold that tuned and
      then failed its outer fit keeps its table; a fold that scored nothing carries a zero-row table with the columns of
      a completed fold's; a candidate that scored on some inner resamples and failed on others appears with `n` below
      the inner resample count; each asserted by a test — one fixture per tuner, the failure shapes on the existing
      `break_*` fixtures. (RB tripwire: ip-touching)
- [x] AC2: `.grid` is gone from the constructor, the invariant column set, `has_results_columns()`, the print and summary
      candidate-set comparison, the vignette, README and every help page:
      `grep -rnE '(^|[^A-Za-z])\.grid' R/ tests/ vignettes/ man/ README.Rmd` matches nothing, and NEWS is the only
      remaining mention. (RB tripwire: ip-touching)
- [x] AC3: `.selected` is built as before and its readers are untouched: `git diff <base>..HEAD --
      R/nested-results-agreement.R R/nested-results-plot.R` is empty, the vignette's selection section is unchanged,
      and the snapshot files for print, summary, agreement and plot carry no edit.
- [x] AC4: The print and summary candidate-set comparison renders as before on the existing snapshots — equal sets,
      differing sets (the per-fold random grid whose folds share `.config` labels), a partial run, and the Bayesian
      rendering — with no snapshot edit, each fold's candidate set derived from the distinct parameter rows of
      `.inner_metrics`.
- [x] AC5: `.inner_metrics` is in the dplyr/vctrs invariant set and in `has_results_columns()`: called directly with
      the original as template, `dplyr_reconstruct()` and `vec_restore()` return a bare tibble for a frame lacking the
      column, and for one whose table on a completed fold other than the first is replaced by a zero-row table or by
      the same table with one row dropped; `[` returns a bare tibble for the column subset
      `setdiff(names(x), ".inner_metrics")`, and a single-argument `rbind()` for a still-classed object from which the
      column was removed beforehand; and a frame lacking the column fails `has_results_columns()`; asserted by tests.
- [x] AC6: `extract_scored_candidates()` on a regression grid fit, a Bayesian fit and a censored-regression fit
      scoring a dynamic survival metric returns one row per candidate the fit's tuning run scored, carrying the
      tuned-parameter columns and `.config`, `.iter` added on the Bayesian fit, and no other column — so the `.eval_time`
      column the base commit's accessor carried on the survival fit, the first pooled row's evaluation time per
      `.config`, is absent; asserted for the regression fit by
      `expect_setequal(names(cand), c("num_comp", ".config"))` and `expect_identical(nrow(cand), nrow(det_grid()))` in
      `test-nested-final-fit-extract.R`, for the Bayesian fit by a column-set assertion beside the `.iter` assertion in
      `test-nested-final-fit-oracles.R`, and for the survival fit by a column-set test. Its help page describes that
      shape without reference to `.grid`, says the evaluation-time column is dropped and points at
      `collect_metrics(extract_tune_results(x))` for it, and NEWS names the dropped column.
- [x] AC7: The profile's verify slot is clean; NEWS carries the breaking-change entry; DESIGN.md's results-object
      description names `.inner_metrics`; D-043 is appended.

## Coverage

- AC1 → T1, T2, T7
- AC2 → T3, T4
- AC3 → T4
- AC4 → T3
- AC5 → T5
- AC6 → T4, T8
- AC7 → T6

## Tasks

- [x] T1: Tests first: extend the hand-run oracles (`test-nested-tune-grid-oracles.R` O3, `test-nested-tune-bayes-oracles.R`)
      to `.inner_metrics`; the tuned-then-failed, nothing-scored and partial-inner-split shapes in
      `test-nested-tune-grid-failures.R`; the zero-row prototype.
- [x] T2: Fold worker: `nested_fold_fit()` (`R/nested-tune-grid.R:643-652`) and `failed_fold()` (`:802-820`) record the
      table; `new_nested_results()` (`R/nested-results.R:26-31`) writes `.inner_metrics`; `scored_candidates()`
      (`R/nested-tune-grid.R:669-736`) becomes the derivation of a candidate set from the table, `join_iteration()`
      retired where `collect_metrics()` already carries `.iter`.
- [x] T3: Readers: `print_candidate_sets()` and `candidate_key()` (`R/nested-results-print.R:329-393`) and summary's
      candidate counts (`:230`) read the derived sets; the snapshot files stay byte-identical.
- [x] T4: The `.grid` sweep: roxygen on both orchestrators and the extract accessor page, the vignette
      (`vignettes/nested-cv.Rmd:232-247` reads `.selected` only), the fold stand-ins in the payload and classify tests,
      the 21 test files the sweep listed; run the AC2 grep.
- [x] T5: Invariants: `record_columns()` (`R/nested-results.R:121-134`) and `has_results_columns()` (`:608-613`); the
      removal and mutation probes in `test-dplyr-compat.R` and `test-vctrs-compat.R` across the four doors.
- [x] T6: NEWS, DESIGN.md, D-043 (drafted at plan), verify slot.

- [x] T7: Zero-row prototype (F1, F2): type each parameter column from the grid data frame when one was given, else
      from `param_info`, else the workflow's dials set; add `.eval_time` only when the metric set carries a dynamic or
      integrated survival metric; tests on a regression run given `eval_time`, a static-only censored run, and an engine
      parameter with no dials object, each asserting the prototype identical in names and types to a completed fold's.
- [x] T8: `candidate_set()` and `.eval_time` (F3): decide whether the final-fit accessor keeps base's `.eval_time`
      column on a dynamic-survival fit or the drop is intended; amend AC6's wording at the step-6 gate to match (and to
      name the assertions, not the file, as what stays unchanged), with a censored test either way.
- [x] T9: `fake_tuning()` cleanup (F4) and the `show_best()` roxygen sentence (F7): scope the S3 registration to the
      test and reword the sentence to what `.inner_metrics` supports and how it relates to `.selected`.

## Work log

- 2026-09-02: created by /milestone-plan from issue #57 (topepo, 2026-09-02).
- 2026-09-02: criteria audit ran in full mode by a fresh [O] reader; for M49 it returned: the column was never named (now `.inner_metrics`, gate); AC2's grep matched `expand.grid` in the vignette and README (pattern fixed); deriving candidate sets from distinct `.config` rows would collapse the differing-grid snapshot whose folds share labels (derived from parameter rows instead); AC3 rested on green tests rather than unchanged output (now an empty diff and unchanged snapshots); `has_results_columns()` omitted from AC5 (added); the partial-inner-split case unprobed (added to AC1); the final-fit accessor's shape left implicit (settled: kept, recorded in D-043).
- 2026-09-02: plan gate chose keeping `.selected` over dropping it for an on-the-fly `slice_min()` because it records what the outer fit used under `select_best()`'s tie rules and DESIGN.md's selection-stability stance names it; falsified by evidence that recomputing from `.inner_metrics` always reproduces it.
- 2026-09-02: plan chose leaving `extract_scored_candidates()` unchanged over reshaping it to the metrics table because nothing on the final fit is broken and the divergence is one sentence in D-043; falsified by a user comparing the two surfaces row for row.
- 2026-09-02: gate: proceed without escalation on the ip-touching criteria (the hand-run `collect_metrics()` oracle is available); one candidate derivation over the metrics table, the final fit applying it to `collect_metrics()` of its tuning run. T1: `.inner_metrics` oracles on both hand-run loops, the outer-fit-failed, nothing-scored (both branches), partial-inner-split and Bayesian nothing-scored shapes; red on the missing column until T2.
- 2026-09-02: T2–T5 code landed together (a fold worker writing `.inner_metrics` leaves the readers and invariants red until they read it): `inner_metrics()` records `collect_metrics()` or a workflow-built zero-row prototype, `candidate_set()` derives the candidate set from a table and serves the final fit through `scored_candidates()`, `join_iteration()` and the per-resample pooling retired; readers and invariants swapped; the `.grid` sweep ran and the AC2 grep is empty; T5 probes written; T6 NEWS and DESIGN drafted. Checkpoint while the full suite runs; checkboxes wait on the verify slot. AC5's change-through-`[`-and-`rbind()` clause found unconstructible (those doors self-template); amended wording out to a fresh [O] reader before the mini gate.
- 2026-09-02: amendment (substantive, narrowing) — AC5 rewritten at a mini gate: the change-through-`[`-and-`rbind()` clause was unconstructible, those doors taking the object they act on as their own template. Two fresh [O] readings in full mode: the first returned four findings (probe forms and fold location, `vec_restore()` call form, the two doors' constructions split, a home for the self-template gap), the second two findings and an ambiguity (exact `[` subset, single-argument `rbind()`, a completed fold); all applied, the final text user-approved. Two hand-built-run tests (final-fit print counts, the bookkeeping wrapper) rewritten over a `fake_tuning()` stand-in whose `collect_metrics()` is a table given by hand.
- 2026-09-02: T2–T6 checked off on the verify slot: `devtools::document()` no diff, `air format .` no diff, `devtools::test()` clean in full (an earlier full run failed the three daemon files whose hand-built fold records still carried `grid`, and `test-suite-hygiene.R` on the time-budget ledger's `test-parallel-classify.R` line numbers, which `fake_fold_record()`'s eight new lines had shifted — both fixed). AC2 grep matches nothing; the AC3 diff and snapshot diff are empty. Status → review.
- 2026-09-02: review opened: PR #59 drafted; AC evidence gathering in progress (suite, check and three reviewers running).
- 2026-09-02: review step 6 checkpoint: suite, check and gate green; [O] F1–F3 confirmed by execution as criterion breaches on censored, `eval_time` and engine-parameter inputs outside the fixtures; disposition to the gate.
- 2026-09-02: review step 7: gate declined the merge; defect return 1 of M49 — [O] F1 and F2 demonstrate AC1's zero-row clause failing (prototype columns and types diverge from a completed fold's on `eval_time` without a dynamic survival metric and on an engine parameter without a dials object), F3 demonstrates AC6 failing on a dynamic-survival final fit (`.eval_time` dropped); F4 and F7 fix on the same return; F5 rejected (unreachable), F6 resolved by measurement, F8 rejected (tracking prose), F9 noted, F10 rejected (cosmetic). Tasks T7–T9 added; status → in-progress; PR #59 stays draft.
- 2026-09-02: T7: `empty_inner_metrics()` types each parameter column from the grid data frame, else `param_info`, else the workflow's dials set, and adds `.eval_time` only when the metric set holds a dynamic survival metric (or none was given on a censored-regression workflow, tune's default there being `brier_survival`); T7's "dynamic or integrated" was measured wrong on tune 2.1.0 — an integrated-only set gets no `.eval_time` — so the code and tests follow the measurement. Three tests in `test-nested-tune-grid-failures.R` (regression given `eval_time`; censored static-only, with dynamic and default-metric controls; ranger `max.depth` typed integer and double from the grid) were red on the branch before the fix and green after. T9: `fake_tuning()` schedules the method's removal from tune's S3 table on the calling block's exit, with a test that it leaves; the `show_best()` roxygen sentence now says ranking by `mean` reproduces `.selected` except on ties, which `select_best()` resolved. `devtools::document()` regenerated `nested_tune_grid.Rd`; `air format .` clean; full `devtools::test()` clean.
- 2026-09-02: T8 amended-AC6 wording went to two fresh [O] readers in full mode before the mini gate: the first returned seven findings (zero-candidate case, the survival trigger, an instrument-bound and factually off evidence clause, an unasserted ordering clause, unbounded domain, D-043 staleness, direction narrowing); the second, on the revised text, eight (dynamic metric unnamed on the survival fit, the base column's meaning, the zero-candidate clause unasserted, D-043, GP1 wants the drop said on the help page, the Bayesian probe checks `.iter` only, base-commit provenance on the regression assertions, NEWS). All applied except the first reader's "dynamic or integrated", contradicted by measurement; the gate decides the drop.
- 2026-09-02: amendment (substantive, narrowing) — AC6 rewritten at a mini gate, the user choosing the `.eval_time` drop over restoring the base column: base identity gives way to a named column set on three fit kinds, the evidence named per assertion, the help page and NEWS told to say the column is dropped. Twice audited by fresh [O] readers before writing (the line above).
- 2026-09-02: T8 code landed: the help page's `@return` names the per-metric columns dropped, `.eval_time` among them, and points at `collect_metrics(extract_tune_results(x))`; NEWS names the dropped column; a survival column-set test in `test-nested-final-fit-extract.R` and a Bayesian column-set assertion in `test-nested-final-fit-oracles.R`. The three touched files are green; checkpoint while the full suite runs, the T8 tick and status waiting on it.
- 2026-09-02: T8 checked off on the verify slot: `devtools::document()` no diff, `air format .` no diff, full `devtools::test()` clean with no failure, warning or skip line. All of T7–T9 done; status → review for the second round.

- 2026-09-02: review round 2 opened: branch pushed, PR #59 still draft; AC1–AC7 evidenced and ticked on a clean 3,675-pass suite; gate checks green save `devtools::check()`, still running; three reviewers returned (G1–G12, one [S] overlap with G3); checkpoint before the check lands and the gate.
## Decisions

- 2026-09-02: a record column altered under the class — `x$.inner_metrics[[1]] <- ...`, which tibble's `$<-` reattaches the class after without consulting the reconstruct rule — passes `[` and `rbind()`, which compare the object against itself; the template-taking doors refuse it. Pre-existing for every record column, recorded at the rule (`R/nested-results.R`) rather than fixed: intercepting `$<-` and `[[<-` is a fifth and sixth door the invariants D-031 fixed do not name, a candidate for a later milestone if a user meets it.
- 2026-09-02: D-043's sentence that the final-fit accessor keeps its candidate shape means the parameter columns and `.config`: on a survival fit the base accessor also carried `.eval_time`, one arbitrary time per candidate, which `candidate_set()` drops with the other per-metric columns. Not a shape the accessor promised, so D-043 stands unannotated; NEWS and the help page name the dropped column.

## Review

_Round 2, evidence gathered 2026-09-02 on branch `m049-inner-metrics-column` at 14a8465 (origin/main at 15c07d9, unmoved since the cut; PR #59 draft, pushed). Full `devtools::test()`: 3,675 pass, 0 fail, 0 warn, 0 skip. Round 1 (at 8df4c7e) ended in defect return 1; its evidence is superseded by the lines below._

- AC1 — verified. Grid: `test-nested-tune-grid-oracles.R` "an integer grid records the candidates that fold actually expanded" asserts each fold's `.inner_metrics` identical to `tune::collect_metrics()` of a hand re-run under the fold's seed. Bayesian: `test-nested-tune-bayes-oracles.R` "per-fold metrics and selections match a hand-rolled Bayesian reference loop", `.iter` included. Failure shapes in `test-nested-tune-grid-failures.R`: "a fold that failed at the outer fit keeps the grid its tuning scored" (table kept), "a fold that scored nothing records an empty table, never NULL" (zero-row, a completed fold's columns), "a fold that completed on a truncated inner design keeps tune's notes" (every `n` below 3 on the partial fold, 3 on the full one); the round-1 F1/F2 shapes now covered by "a regression fold that scored nothing carries no .eval_time for an eval_time it was given", "a censored fold that scored nothing carries .eval_time under a dynamic metric only" and "an engine parameter with no dials object is typed from the grid"; Bayesian zero-row with `.iter` in `test-nested-tune-bayes-results.R`. The [O] reviewer re-ran the prototype against real `collect_metrics()` output on six metric-set shapes and matched names and types. All green in the run above.
- AC2 — verified. `grep -rnE '(^|[^A-Za-z])\.grid' R/ tests/ vignettes/ man/ README.Rmd` exits 1 with no match; a repo-wide sweep outside `cairn/` finds `.grid` only in NEWS.md. `record_columns()` and `has_results_columns()` name `.inner_metrics`; print and summary read `candidate_sets()` over `.inner_metrics`.
- AC3 — verified. `git diff origin/main..HEAD -- R/nested-results-agreement.R R/nested-results-plot.R` is 0 bytes; the diff over `vignettes/` and `tests/testthat/_snaps/` is empty.
- AC4 — verified. No `_snaps/` edit and `test-nested-results-print.R` plus `test-nested-tune-bayes-results.R` green, covering equal sets, the differing per-fold random grid sharing `.config` labels, a partial run and the Bayesian rendering; `candidate_sets()` derives each completed fold's set from `candidate_set(.inner_metrics)` and `candidate_key()` drops `.config` and `.iter` before comparing parameter values.
- AC5 — verified. `record_columns()` and `has_results_columns()` list `.inner_metrics`; `test-dplyr-compat.R` ".inner_metrics is in the record dplyr_reconstruct() checks" and "has_results_columns() requires .inner_metrics", `test-vctrs-compat.R` ".inner_metrics is in the record vec_restore() and rbind() check" probe the missing column, the zero-row and one-row-dropped replacement on a non-first completed fold, the `[` column subset and the single-argument `rbind()`; all green.
- AC6 — verified against the amended text. Regression: `test-nested-final-fit-extract.R` lines 46 and 53 carry `expect_identical(nrow(cand), nrow(det_grid()))` and `expect_setequal(names(cand), c("num_comp", ".config"))`. Bayesian: `test-nested-final-fit-oracles.R` line 276 `expect_setequal(names(cand), c("df1", "df2", ".config", ".iter"))` beside the `.iter` assertion. Survival: "a survival fit's candidates carry no evaluation-time column" asserts the run's own table carries `.eval_time` with one row per candidate and time, and the accessor `c("dist", ".config")` with one row per candidate. The help page names the parameter columns and `.config` (`.iter` on a Bayesian fit) without `.grid`, names `.eval_time` among the per-metric columns that go, and points at `collect_metrics(extract_tune_results(x))`; NEWS names the dropped column. Wording of the help sentence is round-2 finding G3, fixed at the gate.
- AC7 — verified. `devtools::document()` no diff, `air format .` no diff, `devtools::test()` clean (above). NEWS.md's first bullet is the breaking-change entry. DESIGN.md's `new_nested_results()` paragraph names `.inner_metrics`. D-043 is appended.
- Driving RR: none, so no projection-vs-outcome pairs.

### Consistency gate

- `cairn_validate.py`: all checks passed, 18 references-staleness advisories only (the standing set). No IP/GP text changed, so `cairn_impact.py --changed` is skipped.
- `devtools::document()`: no diff. `air format .`: no diff. README.Rmd and README.md untouched on the branch. `pkgdown::check_pkgdown()`: no problems found. NEWS has the entry, no milestone number in user-facing text. No new top-level files. `devtools::check()`: pending at this write.

### Independent review

_Gate 2026-09-02: return to in-progress on F1–F3 (the defect return counted above in the work log); F4 and F7 fix-now on the return; F5, F8, F10 rejected; F6 resolved; F9 noted._

- [S] blame-history: no findings; checked the M03 collect_metrics guard, M21's per-fold record, M45's `join_iteration()` retirement (tune 2.1.0's `collect_metrics()` carries `.iter` natively), M21 review F1/F2 ordering, M37 probes, D-031/D-036 invariant set, D-043 scope, all respected.
- [S] prior-review record: no findings; archives M21, M36–M39, M45, LESSONS.md and D-023/031/032/036/043 read; the GitHub probe found one real inline comment (PR #30, a workflow file), the walk of PRs #22, #45–#47, #51, #54, #58 returned none.
- [O] diff-bug: ten findings, ranked by the reviewer, each verified against the implementation before triage (dispositions at the gate):
  - F1 (verified by execution, tune 2.1.0): `empty_inner_metrics()` adds `.eval_time` whenever `eval_time` was given, but tune adds it only for dynamic or integrated survival metrics. A regression run with `eval_time = c(1, 2)` and a censored run scoring `concordance_survival` alone each get a warning from tune and a `collect_metrics()` table without `.eval_time`, while the prototype carries one, so a fold that scores nothing on such a run does not carry a completed fold's columns (AC1's zero-row clause, outside the `break_*` fixtures). A dynamic-metric run matches, column for column and type for type.
  - F2 (verified by execution): a tuned engine parameter with no dials object (`set_engine("rpart", maxcompete = tune())` with an explicit grid) is typed `logical(0)` in the prototype where a completed fold's table has `integer`; `empty_inner_metrics()` is handed the workflow only, never `param_info` or the grid. Same clause of AC1.
  - F3 (verified by reading the base commit and by execution): base `scored_candidates_impl()` dropped only `.metric`, `.estimator` and `.estimate`, so on a dynamic-survival final fit its table carried `.eval_time`; `candidate_set()` drops it by name, so `extract_scored_candidates()` on such a fit has one column fewer than at base (AC6's "returns what it returns at the base commit", on a censored run no test covers).
  - F4 (verified by reading): `fake_tuning()` in `helper-orchestration.R` registers an S3 method into tune's namespace with no cleanup.
  - F5: a tuned parameter named `mean`, `n` or `std_err` would vanish from the candidate set; the reviewer measured it unreachable (tune's own `collect_metrics()` breaks first).
  - F6 (resolved by execution): the code comment's `.eval_time` position (`.estimator`, `.eval_time`, `mean`) was measured on a dynamic-survival run and holds.
  - F7: the roxygen sentence pointing at `tune::show_best()` for "the fold's best candidate" names a generic not callable on the plain tibble and does not say it may differ from `.selected` under tie rules.
  - F8: the Scope's size comparison sets the summarized table against `.grid` and `.selected` together though `.selected` is kept; tracking prose.
  - F9: the print snapshots elide the tibble body, so "no snapshot edit" cannot see the column rename; the "Candidates searched" line is the operative AC4 evidence and holds.
  - F10: `candidate_sets()` is derived on every `print()` and `summary()` call; cosmetic.

#### Round 2 (2026-09-02, at 14a8465)

- [S] blame-history: no findings; seven informational checks — the M03 `collect_metrics()` guard intact in `inner_metrics()`, the M21 list-valued-column ordering lesson kept in `candidate_set()`, `join_iteration()` retired against the hand-rolled Bayesian oracle, the per-resample pooling superseded by `collect_metrics()`'s own aggregation, the `.eval_time` drop disclosed in NEWS and the help page, the T7 typing fix traced, the `fake_tuning()` cleanup sound.
- [S] prior-review record: one finding, the same as G3 below (the help sentence reads as inclusion); F1, F2, F4, F7 confirmed fixed; no contradiction with D-023/031/032/035/036 or LESSONS.
- [O] diff-bug: twelve findings, ranked by the reviewer; dispositions at the gate:
  - G1: `candidate_sets()` on the `print()`/`summary()` path derives through `candidate_set()`, which has no `tryCatch` of its own (the wrapper is `scored_candidates()`, which those callers bypass), on a method whose comment promises never to raise (M21 F1). No raising input found; the guard's absence is the finding.
  - G2: `empty_inner_metrics()` is called outside every `tryCatch` in `nested_fold_fit()` and, in `R/parallel.R`, after `collect_mirai()` has returned every fold; its internals are each guarded, no raise constructed.
  - G3: the help sentence "Everything tune wrote per metric goes with them: ..., the `.eval_time` column too" reads as inclusion; AC6 asks the page to say the column is dropped. NEWS says it plainly.
  - G4: `R/nested-results-print.R:389` still cites `scored_candidates_impl()`, deleted on this branch; `test-nested-results-print.R:30` names `scored_candidates()` where the test now asserts of `candidate_set()`.
  - G5: `candidate_sets()` was inserted between `print_candidate_sets()`'s comment block and the function, orphaning the comment.
  - G6: `empty_param_column()` falls back to `logical(0)` for an unrecognized dials type — the F2 wrong type, as the default.
  - G7: `empty_param_columns()` ignores the grid's names when the parameter set is a zero-row data frame; no input found reaching it.
  - G8: `fake_tuning()`'s `env = parent.frame()` default schedules removal on a wrapping helper's frame if one is ever introduced; the shapes in use clean up, verified by execution.
  - G9: the engine-free tests now stub `collect_metrics()` through `fake_tuning()`, so the raw `tune_results` shape is exercised only in engine-gated tests; not a criterion breach.
  - G10: `candidate_sets()` recomputed on both print and summary (round-1 F10 restated).
  - G11: D-043 carries no trace of the `.eval_time` drop; the round-1 gate chose to leave it unannotated, the milestone's Decisions section recording it.
  - G12: NEWS's column list omits `.metric` and `.estimator`, which the roxygen lists.
