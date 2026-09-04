# M56: The results class, the extract defaults and the final-fit page close the M37, M34 and M51 review findings

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4, GP1
- **Resolves:** —
- **Surface tier:** user-facing — exported class methods and help pages
- **Branch/PR:** `m056-results-class-and-help-page-findings` · https://github.com/tidymodels/nestedtune/pull/66

## Goal

Close the review findings on `R/nested-results.R`, the two `extract_` default methods and the final-fit and finetune help pages that the M37, M34 and M51 reviews deferred.

## Scope

**In:** the print method on a columnless class token; the class shed on a duplicate-name column add; a cheap rename path; the no-method message on the `extract_` defaults; a racing and an annealing branch in the `?nested_final_fit` recipe; the finetune version the `workflow_size` classification was read on; NEWS.

**Out:** re-templating `vec_cast.nested_results.nested_results()` on `to` (stamping the destination's run description onto the source's rows makes an object describe a run it did not come from, IP4) and re-templating `rbind.nested_results()` (a bare first argument already yields a bare table) → the trimmed M37 candidate row. A top-level `param_info` attribute (it rides inside the `procedure` record every fold carries; promotion condition unmet) → the trimmed M34 row. A finetune floor bump → that row too, taken as the gate's rejected alternative. The test-file and CI findings → M57.

## Acceptance criteria

- [ ] AC1: `print(vctrs::vec_cbind_frame_ptype(res))` on a `nested_results` object returns without error and emits neither the outer-label header line nor a fold-count line; a test in `tests/testthat/test-vctrs-compat.R` asserts it.
- [ ] AC2: `vctrs::vec_cbind(res, tibble::tibble(splits = seq_len(nrow(res))), .name_repair = "minimal")` returns a bare tibble carrying none of the attributes `results_attributes()` and `template_attributes()` name; a test asserts it.
- [ ] AC3: `names<-` on a `nested_results` returns the object with its class and every attribute intact when each record column keeps its name, and a bare tibble when a record column is renamed; a test loops the rename over every column `record_columns(res)` names and over one non-record column.
- [ ] AC4: `extract_tune_results(1, foo = 1)` and `extract_scored_candidates(1, foo = 1)` signal a condition of class `nestedtune_no_extract_method`; a test asserts the class for each generic.
- [ ] AC5: The `?nested_final_fit` reproducibility recipe carries a branch for each entry of `tuner_registry`, and a test reads `man/nested_final_fit.Rd` and asserts each registry entry's tuning function appears as a call (`<name>(`) inside the recipe's code block.
- [ ] AC6: `NEWS.md` carries one entry for the `extract_` default-method change and one compatibility note for the vctrs changes, each naming behavior a test in this milestone enforces.
- [ ] AC7: `devtools::document()` leaves the tree clean, and `devtools::test()` and `devtools::check()` pass.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T4
- AC5 → T5
- AC6 → T6
- AC7 → T7

## Tasks

- [x] T1: In `print.nested_results()` (`R/nested-results-print.R:82`), after the dots check, return after `print_rows()` when `has_results_columns(x)` is false, skipping the header and `candidate_sets()`; run `print(vctrs::vec_cbind_frame_ptype(res))` first to confirm which call errors today; test beside the token test at `tests/testthat/test-vctrs-compat.R:142`.
- [x] T2: Add `anyDuplicated(names(x)) > 0L` to the shed disjunction in `vec_restore.nested_results()` (`R/nested-results.R:363-374`); extend `expect_no_record()` (`tests/testthat/test-vctrs-compat.R:33-41`) to loop over `c(results_attributes(), template_attributes())`; test mirroring the block at `:276` with `.name_repair = "minimal"`.
- [x] T3: In `names<-.nested_results()` (`R/nested-results.R:603-609`), compare the record columns' names before and after and return the object unchanged when they survive, else `bare_results(out)`, with a comment on why the name check suffices; loop test over `record_columns(res)` and one non-record column.
- [x] T4: Swap `check_dots_empty()` and `abort_no_extract_method()` in both default methods (`R/nested-final-fit-extract.R:86-96`, `:175-179`), keeping the `current_env()` comment valid; test with `rlang::catch_cnd()` on each generic.
- [x] T5: Add a racing branch (`tune_race_anova()`/`tune_race_win_loss()`, grid, `control_race()`) and an annealing branch (`tune_sim_anneal()`, `iter`, `initial`, `control_sim_anneal()`) to the recipe at `R/nested-final-fit.R:130-148`, cross-checked against `reference_anneal_final_fit()` and the racing reference loop; add "read on finetune 1.3.0" beside the `workflow_size` sentence in `R/nested-tune-sim-anneal.R:154-168` and `R/nested-tune-race.R:136-147`; `devtools::document()`; test over `man/nested_final_fit.Rd` and `tuner_registry`.
- [x] T6: NEWS entries per AC6.
- [x] T7: `devtools::document()`, `devtools::test()`, `devtools::check()`.

## Work log

- 2026-09-03: created by /milestone-plan from the M37, M34 and M51 candidate rows; the criteria audit ran in full mode on a fresh [O] reader and returned findings on AC1 (narrowed to the header and fold-count lines), AC2 (helper clause moved to T2), the dropped cast/rbind criterion (IP4), AC3 (loop over record columns), AC5 (call, not mention), AC6 (narrowed to two entries), and none on AC4 and AC7.
- 2026-09-03: plan gate chose stating the finetune version in the two help pages over raising the finetune floor because the adding version is unnamed in finetune's NEWS and a re-pin installs a newer finetune for every racing and annealing user; falsified by a user on finetune between 1.0.1 and the adding version reaching a `workflow_size` error the pages do not explain.
- 2026-09-03: plan gate dropped the `vec_cast` re-templating (the audit found it would stamp the destination's run description onto rows it did not produce, IP4) and the `rbind` re-templating (no observable change) rather than implement them; falsified by a user reaching a cast whose result carries the wrong id columns.
- 2026-09-03: T1 done; `print()` on the columnless token wrote the label line and then errored on `.completed` (reproduced before the fix); the method now returns after the rows when `has_results_columns()` is false; test beside the token test in `test-vctrs-compat.R`; vctrs-compat and results-print files clean.
- 2026-09-03: T2 done; the minimal-repair clash kept the class through both doors (reproduced before the fix), so the duplicate-name rule went into `vec_restore.nested_results()` as planned and, as a discovered sub-task, into `can_reconstruct_results()`, which is the door `bind_cols()` reaches; `expect_no_record()` now covers the template attributes; compat files clean.
- 2026-09-03: T3 done; `names<-.nested_results()` returns `NextMethod()`'s object when every record column keeps its name and no name is duplicated, else `bare_results()`; the loop test covers the eight record columns, one added column renamed, and one added column renamed onto `splits`; compat files clean.
- 2026-09-03: T4 done; both `extract_` defaults abort with `nestedtune_no_extract_method` before any dots check (the dots error came first before the fix, reproduced); the test asserts the class on each generic with `foo = 1` and that the methods still refuse a stray argument; extract file clean.
- 2026-09-03: T5 done; the recipe gained a racing branch (both racers, `grid`, the recorded `control_race()` as is) and an annealing branch (`iter`, `initial`, the recorded `control_sim_anneal()` as is), argument names checked against finetune 1.3.0's workflow methods and the two reference final fits; the racing and annealing pages say the `workflow_size` classification was read on finetune 1.3.0 (its adding version is absent from finetune's NEWS, grep on the installed file); `document()` run; the Rd test in `test-tuner-registry.R` finds each registry name as a call in the recipe's one code block; registry and control-slots files clean.
- 2026-09-03: T6 done; two NEWS entries, one on the `extract_` refusal order (enforced by the T4 test) and one compatibility note covering the token print, the duplicate-name shed through both doors and the rename rule (the T1, T2 and T3 tests).
- 2026-09-03: full `devtools::test()` found the two `extract_` defaults failing `test-dots-barrier.R`'s AC5 loop, which fed every registered method a list and expected the dots refusal; the loop now expects those two to refuse the object by `nestedtune_no_extract_method`, named in a `NO_METHOD_DEFAULTS` list; per-task runs above were filtered to the touched files, the full suite ran once here (0 failures after the fix).
- 2026-09-03: T7 done; `document()` leaves the tree clean, full `devtools::test()` 0 failures, `devtools::check()` 0 errors, 0 warnings, 0 notes; status set to review.

## Decisions

## Review
