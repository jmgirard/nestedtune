# M55: Every driver refuses a design whose inner resamples are empty, whose fold labels do not uniquely name its folds, or whose columns are not an rsample design's

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Resolves:** —
- **Branch/PR:** `m055-design-entry-checks`

## Goal

The five orchestrators refuse, at the call the user wrote and before any fold runs, a nested design whose inner `rset` has no rows, whose fold labels hold an `NA` or repeat across rows, or whose label columns are not what rsample's readers would find — naming every offending position.

## Scope

User-facing tier: the refusals fire from the five exported drivers, and the `resamples` contract is documented for their callers.

**In:** `check_nested()` (`R/checks.R:108`), called at the entry of `nested_tune_grid()`, `nested_tune_bayes()`, `nested_tune_race_anova()`, `nested_tune_race_win_loss()` and `nested_tune_sim_anneal()`, gains three refusals: an `inner_resamples` element that is an `rset` with zero rows; a label column (any column beside `splits` and `inner_resamples`) whose name does not match `(^id$)|(^id[1-9]$)` — the pattern rsample's and tune's `col_starts_with_id()` read id columns by (rsample 1.3.2, tune 2.1.0) — or that is neither character nor factor; and label values that are `NA` or a label tuple two rows share. Every refusal `check_nested()` raises, the two existing element-class refusals included, carries the condition class `nestedtune_bad_design`, the exported driver's call, and every offending position or column. The `resamples` documentation, shared by the five drivers through `@inheritParams nested_tune_grid`, states the contract; `NEWS.md` records the refusals. D-047 records the contract and annotates D-036's consequences clause.

**Out:** an inner `rset` built over a frame other than its outer split's, and inner splits that are not `rsplit`s → the trimmed candidate row (the parallel path already routes the first down the fat path, `R/parallel.R:105-118`). An `inner_resamples` length that disagrees with the row count → dropped as impossible, a data frame's columns sharing one row count. Refusing malformed results objects at the readers → DESIGN.md Known issues (M53's acceptance). A design built by `nested_resamples()` with a malformed `outside` → the constructor's own refusals (M18), unchanged here.

## Acceptance criteria

- [ ] AC1: A design in which any `inner_resamples` element is an `rset` with zero rows is refused by each of the five drivers with a condition of class `nestedtune_bad_design`; one test per driver plants a zero-row `rset` (`rsample::manual_rset(list(), character(0))`) at the first and at the last position of `det_nested(d)` (three outer rows) in turn, asserts the class each time, and asserts the unaltered fixture is not refused.
- [ ] AC2: A design whose label columns hold an `NA`, or in which two rows carry the same label tuple, is refused by each of the five drivers with a condition of class `nestedtune_bad_design`; one test per driver plants an `NA` at the first and at the last position of `det_nested(d)` in turn, and a copy of row 1's tuple at the last position, asserting the class each time; a control asserts `repeated_design()` (`tests/testthat/helper-orchestration.R:583`; `id` repeats across repeats while the `(id, id2)` tuple is unique) is not refused.
- [ ] AC3: A design with a label column that is neither character nor factor, or with a label column whose name does not match `(^id$)|(^id[1-9]$)`, is refused by each of the five drivers with a condition of class `nestedtune_bad_design`; one test per driver plants, once before `id` and once after it in column order, an integer `id`, a character `weights`, a numeric `weights` and a list `extra`, asserting the class each time; a control asserts a `nested_resamples()` design and an `rsample::nested_cv()` design carrying `id` and `id2` are not refused.
- [ ] AC4: Every refusal `check_nested()` raises — enumerated as every `cli_abort()` call reached from its body, listed by grep over `R/checks.R` — carries the class `nestedtune_bad_design`, carries as its `call` the exported driver the user called (the race pair naming `nested_tune_race_anova()` or `nested_tune_race_win_loss()`, never their shared internal), and names every offending position or column; tests plant offenders at all three positions of `det_nested(d)` for each row-wise refusal, the two element-class refusals included, and assert all three positions appear in the message; plant two offending columns for the column refusals and assert both names appear; and assert `conditionCall()` names each of the five drivers.
- [ ] AC5: Each design the suite's fixture constructors build — `det_nested()`, `valid_folds()` (`test-nested-tune-grid-checks.R:4`), `repeated_design()`, and `nested_resamples()` and `rsample::nested_cv()` called directly — returns invisibly from `check_nested()`, asserted by a test naming each; and `devtools::test()` is clean.
- [ ] AC6: `NEWS.md` states the five refusals (zero-row inner `rset`; `NA` label; repeated label tuple; label column not character or factor; label column named outside the id pattern), and the `resamples` parameter documentation of `nested_tune_grid()` states the contract those refusals enforce; `devtools::document()` produces no diff and `devtools::check()` reports 0 errors, 0 warnings, 0 notes.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T1, T2, T3
- AC3 → T1, T2, T3
- AC4 → T1, T2, T3
- AC5 → T1, T2, T4
- AC6 → T4

## Tasks

- [x] T1: Tests first. Add `malformed_designs(d)` to `tests/testthat/helper-orchestration.R`, returning the named planted designs of AC1–AC4 built from `det_nested(d)` (each defect form at first and last position, and at all three positions for the every-position assertions), and extend `tests/testthat/test-nested-tune-grid-checks.R` with the grid driver's refusals, message-position and `conditionCall()` assertions, and the AC5 controls. Run `devtools::test()`; the new tests are red, the two existing element-class tests (`:283`, `:340`) are extended and red on the missing class.
- [x] T2: `R/checks.R`: extend `check_nested()` with `check_inner_rows()`, `check_label_columns()` and `check_label_values()`; give `check_column_class()` and the three new helpers one message shape naming every offending position or column, class `nestedtune_bad_design`, and `call = call`; confirm the race drivers' `call` reaches the condition (`R/nested-tune-race.R:275`). `devtools::test()` clean.
- [x] T3: One test block per driver in `test-nested-tune-bayes-checks.R`, `test-nested-tune-race-checks.R` (both race exports) and `test-nested-tune-sim-anneal-checks.R` over `malformed_designs(d)`, asserting class and `conditionCall()` per driver. `devtools::test()` clean.
- [ ] T4: `@param resamples` at `R/nested-tune-grid.R:36` states the contract; `NEWS.md` entry; the comment at `R/parallel.R:112` re-read against the new `check_nested()`. `devtools::document()`, `devtools::test()`, `devtools::check()` clean.

## Work log

- 2026-09-03: created by /milestone-plan from the candidate row "Refuse a design for more than its two columns' element classes" (M19 Out, M38 Out); the row's "inner_resamples length mismatched to nrow(resamples)" item dropped as impossible for a data frame, the rest of its remainder trimmed into the row.
- 2026-09-03: criteria audit ran in full mode ([O] fresh reader): eleven findings; nine fixed in place (fixture and positions named, probes crossed by form and position with a character non-id column added, every-position assertions over all three fixture rows, the race pair's `call`, the existing refusals gaining the class, AC5 rewritten from a skip-count comparison to named fixture constructors, the refusal count corrected to five, documentation scope settled by `@inheritParams`); two posed at the gate (the name rule against D-036; the existing refusals' shape).
- 2026-09-03: plan gate chose the reader pattern `(^id$)|(^id[1-9]$)` over rsample's constructor prefix `^id` and over no name rule because tune's and rsample's readers ignore a column outside it, so a design carrying one would be misread downstream either way; falsified by an rsample or tune release whose readers find id columns by another rule.
- 2026-09-03: plan gate chose refusing `NA` and repeated label tuples alongside the type rule over the type rule alone because repeated labels make `autoplot()` abort and `NA` labels make fold rows unattributable; falsified by a design rsample itself builds whose label tuples legitimately repeat.
- 2026-09-03: plan gate chose bringing the two existing element-class refusals to the new shape (every position, one class) over leaving them because one class lets callers catch every design refusal alike; falsified by a caller shown to depend on the old first-position message text.
- 2026-09-03: /milestone-implement started; branch `m055-design-entry-checks` cut from `main` at bd3e105 (synced with origin); question gate skipped, the plan gate having settled the three open choices.
- 2026-09-03: T1 done: `malformed_designs()` (25 planted records: the two element-class defects, the empty inner rset and the NA label each at first, last and all three rows; the repeated tuple at last and at all three; an integer `id` in place, and an integer `id2`, a character and a numeric `weights` and a list `extra` each before and after `id`; one design carrying two offending columns) and four grid-driver tests (every planting refused with the class, the call and every position; each defect named; the four whole-object refusals carry the class; five named well-formed designs pass `check_nested()` invisibly and unchanged). Red before T2: 107+ failures on the missing class and the first-only positions; the AC3 "integer `id` before and after `id`" clause read as an integer `id` in place plus an integer `id2` on either side, since one design cannot carry two `id` columns.
- 2026-09-03: catch-up: the full suite at T2 was red in `test-drift-manifest.R` alone, on the 2026-09-03 triage commit (089ff94) having compressed the mori candidate row past two figures its drift-check declaration still declares; fixed on `main` as two docs-only commits (6f189ff, 44ec8ac; the row carries the two figures and the phrase the perturbation test anchors on), merged into the branch.
- 2026-09-03: T2 done: `check_nested()` gains `is_id_name()` (the readers' pattern, cited to rsample 1.3.2 and tune 2.1.0), `check_inner_rows()`, `check_label_columns()` and `check_label_values()` (NA rows reported as such, not also as repeats; `vctrs::vec_duplicate_detect()` over the label frame); `check_column_class()` names every offending element; all ten `cli_abort()` calls carry `class = "nestedtune_bad_design"`. The race pair reaches it with `call = call` from the export's frame (`R/nested-tune-race.R:275`), unchanged. Grid checks file green; full suite green apart from the drift file above.
- 2026-09-03: T3 done: one block per driver file over `malformed_designs(d)` (the race block loops both exports through `race_call()`), asserting the class, that fitting never began, and `conditionCall()` naming the export; the three files green.

## Decisions

## Review
