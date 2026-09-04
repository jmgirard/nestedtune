# M59: Every driver refuses a design whose inner splits are not rsplits, do not share the outer fold's frame or its analysis set, or index rows the outer fold holds out

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP1, IP2, GP3, GP4
- **Resolves:** —
- **Surface tier:** user-facing — an entry refusal every tuning driver raises, its help page and NEWS
- **Branch/PR:** —

## Goal

The five orchestrators refuse, at the call the user wrote and before any fold runs, a nested design whose inner splits are not `rsplit`s, whose inner splits do not all carry one frame that is the outer split's own frame or that split's analysis set, or whose whole-frame inner splits index a row the outer split holds out, naming every offending position.

## Scope

**In:** three rules added to `check_nested()` (`R/checks.R`), run after the D-047 rules: every element of each fold's inner `splits` list is an `rsplit`; every inner split of a fold carries one frame `identical()` to the outer split's `$data` or to `rsample::analysis()` of that split (the shape `nested_resamples()` builds and the shape `rsample::nested_cv()` builds); an inner split carrying the outer frame has an `in_id` and a non-`NA` `out_id` inside the outer split's `in_id`. One class (`nestedtune_bad_design`), the driver's call, every offending fold, split and index named, no frame interpolated into a message. The suite's failure fixtures `break_fold()` and `break_inner_split()` rebuilt inside the design's own frame. `@param resamples`, NEWS, the `R/parallel.R` fat-path comment, and a decision entry superseding D-047's consequence clause.

**Out:** the parallel fat path and `is_fold_payload()`'s shared-frame clause stay as the lean gate the dispatch tests drive with stand-in payloads (gate choice, 2026-09-04) — removing them is a candidate row only if a later milestone wants the deletion. Index range against the frame (an index past the frame's end, a negative index) is left to `rsample::analysis()` and `last_fit()`, which refuse at the fold as `test-nested-tune-grid-failures.R` asserts, and an analysis-framed inner split (`nested_cv()`) gets no index rule for the same reason. Two label columns sharing a name, and every other shape M55 left out, stay in the rows M55 named.

## Acceptance criteria

- [ ] AC1: Each of the five drivers (`nested_tune_grid()`, `nested_tune_bayes()`, `nested_tune_race_anova()`, `nested_tune_race_win_loss()`, `nested_tune_sim_anneal()`) refuses at entry, before any fold runs, with condition class `nestedtune_bad_design` and `conditionCall()` naming the driver, a design in which an element of some fold's inner `splits` list is not an `rsplit`; the message names every offending fold and split position. Shown by tests planting the defect as a string, as a bare list and as an `rset`, at the first, the last and all three outer folds of `det_nested()`, and at the first and the last inner split.
- [ ] AC2: Under the same class and call, each driver refuses a design in which a fold's inner splits do not all carry one frame that is `identical()` to the outer split's `$data` or to `rsample::analysis()` of that split; the message names every offending fold and, for a fold whose splits disagree among themselves, every split. Shown by tests planting, at the first, the last and all three outer folds of `det_nested()`: every inner split on a foreign frame; one inner split on a foreign frame; the outer split replaced by one over a foreign frame.
- [ ] AC3: Under the same class and call, each driver refuses a design in which an inner split carrying the outer split's own frame has an `in_id`, or a non-`NA` `out_id`, holding a row index outside the outer split's `in_id`; the message names every offending fold, split and index. Shown by tests planting an outer-assessment row and an index past the frame's end, each into `in_id`, into `out_id`, and into both, at the first, the last and all three outer folds of `det_nested()`.
- [ ] AC4: `check_nested()` returns its argument invisibly for each of these well-formed designs: a `nested_resamples()` design; an `rsample::nested_cv()` design built on a data.frame and one built on a tibble; an `rsample::nested_cv()` design whose outer `rset` is an evaluated `manual_rset()` with a repeated row; `det_nested()` and `repeated_design()`. And `nested_tune_grid()` completes every fold (`.completed` all `TRUE`) on the data.frame and the tibble `nested_cv()` designs, serially.
- [ ] AC5: `@param resamples` on `nested_tune_grid()` (inherited by the four sibling pages) states the three rules and their refusal class, and one `NEWS.md` entry states them.
- [ ] AC6: `devtools::document()` produces no diff; `devtools::test()` is clean with no new skips; `devtools::check()` reports 0 errors, 0 warnings, 0 notes.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T1, T2
- AC5 → T4
- AC6 → T3, T5

## Tasks

- [ ] T1: Tests first. Extend `malformed_designs()` (`tests/testthat/helper-orchestration.R:1991`) with the AC1–AC3 plantings — each recording the folds, splits and indices the refusal must name — and add the AC4 controls beside M55's; the grid-driver block in `test-nested-tune-grid-checks.R` asserting class, call and every planted position, one block per other driver in its checks file; the AC4 completion runs. Red.
- [ ] T2: `check_inner_splits()` in `R/checks.R`, called last in `check_nested()` (after `check_label_values()`, `:206`): the `rsplit` rule; the one-frame rule, `identical()` against `split$data` first (a pointer fast path for `nested_resamples()` designs) and against `rsample::analysis(split)` only when the outer split's indices lie in its frame, since M54 leaves an out-of-range outer index to `last_fit()`; the containment rule for whole-frame splits over `in_id` and non-`NA` `out_id`; one class, the driver's call, every position; no frame in any message (the M05/M45 lesson). Green.
- [ ] T3: Re-vehicle the fixtures on the 2026-09-04 probe: `break_fold(stage = "inner tuning")` empties every inner split's `in_id` (the fold fails at inner tuning with tune's "All models failed" note), `break_fold(stage = "outer fit")` appends an index past the frame's end to the outer split's `in_id` (tuning completes, `last_fit()` refuses, as the appended case at `test-nested-tune-grid-failures.R:725` already shows), `break_inner_split()` empties one inner split's `in_id` (the fold completes on a truncated design). Replace the three assertions naming the recipe's foreign-variable message (`test-nested-tune-grid-failures.R:65,77,281`) with tune's new note text; run the 13 files `grep -l 'break_fold\|break_inner_split' tests/testthat/test-*.R` lists.
- [ ] T4: `@param resamples` (`R/nested-tune-grid.R:36-50`), the NEWS entry, the `is_fold_payload()` comment (`R/parallel.R:108-118`, which also still says the check asks only for the class and a row) rewritten to say the gate now serves stand-in payloads and defence in depth; `devtools::document()`; append the decision entry superseding D-047's consequence clause, above the template block in `cairn/DECISIONS.md` (the M33 lesson).
- [ ] T5: Full `devtools::test()`, `devtools::check()`, `air format --check` on every touched file before the review push (the M56 lesson).

## Work log

- 2026-09-04: created by /milestone-plan, promoting the candidate row "Refuse an inner `rset` built over a frame other than its outer split's, and inner splits that are not `rsplit`s" (M19 Out, M38 Out, M55 Out) at the user's choice, ahead of the row's stated promotion condition. Probes this day: a hand-built inner split whose `in_id` holds an outer-assessment row runs to completion unrefused; a `nested_cv()` inner frame is `identical()` to `rsample::analysis()` of its outer split on a data.frame and on a tibble; the identity check costs 0.38 s for ten folds of a 1e6 × 11 `nested_cv()` design; emptying inner or outer `in_id`s reproduces the three fixture outcomes inside the design's own frame.
- 2026-09-04: criteria audit ran in full mode ([O] fresh reader): eight findings. Fixed — the drafted "outer fit" fixture (an emptied outer `in_id`) would have tripped AC3's own containment rule, replaced by an appended out-of-range outer index; the fixture-helper criterion and the source-comment clause bound instrument state and moved to T3 and T4; AC1's plantings gained form variety (string, bare list, `rset`); AC3's gained an index past the frame's end; the test-local `valid_folds()` left AC4's controls and a driver-level completion run joined them; "14 files" corrected to 13. Judgments — the fat path's purpose and D-047's clause went to the gate; an analysis-framed inner split's index range stays Out.
- 2026-09-04: plan gate chose including the index containment rule over a candidate row because a whole-frame inner split reaching an outer-assessment row is the IP1 breach in check form and runs unrefused today; falsified by an rsample-built design the rule refuses.
- 2026-09-04: plan gate chose `identical()` against the outer frame and its `analysis()` over a row-count-and-names shape check because a same-shape wrong frame is exactly the case the parallel fat path exists for; falsified by the entry cost dominating a real run, which the 0.38 s per ten folds at 1e6 rows argues against.
- 2026-09-04: plan gate chose rewriting `break_fold()` and `break_inner_split()` over rewriting their 43 call sites because the helpers own the vehicle and the call sites assert outcomes; falsified by a call site that depended on the foreign frame itself rather than on the stage that fails.
- 2026-09-04: plan gate chose superseding D-047's consequence clause while keeping the fat path over deleting the fat path because the dispatch tests drive `dispatch_folds()` with stand-in payloads that need the gate, and the clause stays as defence in depth; falsified by the fat path taking a real design after the check ships, which would mean the check has a hole.

## Decisions

## Review
