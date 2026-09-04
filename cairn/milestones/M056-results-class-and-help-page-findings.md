# M56: The results class, the extract defaults and the final-fit page close the M37, M34 and M51 review findings

- **Status:** in-progress
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

- [x] AC1: `print(vctrs::vec_cbind_frame_ptype(res))` on a `nested_results` object returns without error and emits neither the outer-label header line nor a fold-count line; a test in `tests/testthat/test-vctrs-compat.R` asserts it.
- [x] AC2: `vctrs::vec_cbind(res, tibble::tibble(splits = seq_len(nrow(res))), .name_repair = "minimal")` returns a bare tibble carrying none of the attributes `results_attributes()` and `template_attributes()` name; a test asserts it.
- [ ] AC3: `names<-` on a `nested_results` returns the object with its class and every attribute intact when each record column keeps its name, and a bare tibble when a record column is renamed; a test loops the rename over every column `record_columns(res)` names and over one non-record column.
- [x] AC4: `extract_tune_results(1, foo = 1)` and `extract_scored_candidates(1, foo = 1)` signal a condition of class `nestedtune_no_extract_method`; a test asserts the class for each generic.
- [x] AC5: The `?nested_final_fit` reproducibility recipe carries a branch for each entry of `tuner_registry`, and a test reads `man/nested_final_fit.Rd` and asserts each registry entry's tuning function appears as a call (`<name>(`) inside the recipe's code block.
- [x] AC6: `NEWS.md` carries one entry for the `extract_` default-method change and one compatibility note for the vctrs changes, each naming behavior a test in this milestone enforces.
- [x] AC7: `devtools::document()` leaves the tree clean, and `devtools::test()` and `devtools::check()` pass.

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
- [x] T8: In `can_reconstruct_results()`, `vec_restore.nested_results()` and `names<-.nested_results()` (`R/nested-results.R`), count duplicates over the record names only (each required name present exactly once), never over every name; add a test that a clash between two non-record columns, through `vec_cbind(.name_repair = "minimal")` and through `names<-`, keeps the object and its attributes (review F1, AC3).
- [x] T9: Reorder the `?nested_final_fit` recipe so the Bayesian branch, the one that assigns `control$seed`, comes last, and its comment says the racing and annealing branches use the recorded control untouched; `devtools::document()` (review F2).
- [x] T10: NEWS: the token-print sentence names the banner as what still prints, and the duplicate-name sentence names the record-column rule T8 ships (review F3).
- [ ] T11: Test tidy-ups: replace the vacuous "did not complete" assertion in the AC1 test with one that the output holds only the banner and the rows (F4); the AC5 passing control reads the section's whole prose, not its first node (F7); the section loop breaks on its match and stops cleanly on a NULL section (F9).
- [ ] T12: A milestone-local decision line: the duplicate shed is the second fault D-035's "one thing" did not anticipate, and `names<-` decides on the names alone because base `names<-` relabels and never moves a value (F10, H1).
- [ ] T13: `devtools::document()`, `devtools::test()`, `devtools::check()` after T8-T12.

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
- 2026-09-03: /milestone-review: gate presented with the [O] findings F1-F10 and the [S] findings H1-H2; F1 confirmed by command and demonstrates AC3 failing inside its domain. defect return 1 of M56 (return floor, F1): status in-progress; T8-T13 added. Dispositions — fix now in the return: F1, F2, F3, F4, F7, F9, F10/H1; rejected: F5 (latent, no live object reaches the gate), F6 (AC1 met as written; an IP4 observation on the token's row count), F8 (registry names equal the tuner fields by construction), H2 (intentional, tested, in NEWS).
- 2026-09-03: T8 done; `duplicated_record_names()` counts duplicates over the record's names alone and the three doors call it (the non-record clash shed the record through all three before the fix, reproduced); the test adds a clash between two caller-added columns through `vec_cbind()`, `bind_cols()` and `names<-`, each keeping the object and its attributes; compat and results files clean.
- 2026-09-03: T9 done; the recipe now runs grid, racing, annealing, then Bayesian, so the `control$seed` assignment sits below every branch that uses the recorded control untouched, and each untouched branch says so; `document()` rewrote `man/nested_final_fit.Rd`; registry file clean.
- 2026-09-03: T10 done; the compatibility note says the banner and the rows print, that a name shared outside the record leaves the object as it is, and that `names<-` keeps the object on a duplicate outside the record.

## Decisions

## Review

- 2026-09-03: default branch unmoved since the cut (`git fetch`; `origin/main` at the branch base); branch pushed; draft PR #66 opened, `Resolves:` is `—` so no closing lines.
- AC1: verified 2026-09-03 — `print(vctrs::vec_cbind_frame_ptype(res))` on the three-fold fixture returns without error; the output carries no "Outer resamples" line and no "did not complete" line, while the same method on the full object writes the label line; the test "printing the frame prototype emits neither the outer label nor a fold count" in `test-vctrs-compat.R` asserts it.
- AC2: verified 2026-09-03 — `vec_cbind(res, tibble(splits = 1:3), .name_repair = "minimal")` and the `bind_cols()` door both return a plain `tbl_df` with none of the ten attributes `results_attributes()` and `template_attributes()` name; the test "vec_cbind() sheds the class when minimal name repair duplicates a record column" asserts it through both doors.
- AC3: NOT ticked — the loop evidence passes (each of the nine record columns renamed sheds class and attributes; a non-record column renamed keeps the object with attributes identical; the test "names<- sheds the record for every record column and keeps it for a column outside it" asserts it), but the [O] reviewer's finding 1 was reproduced by command: with two added non-record columns renamed onto one name, every record column keeps its name and the object still comes back bare, because the three doors test `anyDuplicated()` over every name rather than over the record's. A case inside the criterion's domain fails; disposition at the gate.
- AC4: verified 2026-09-03 — `extract_tune_results(1, foo = 1)` and `extract_scored_candidates(1, foo = 1)` each signal a `nestedtune_no_extract_method` condition; the test "an object with no method is refused as such whatever rides in the dots" asserts the class for each generic and that the methods on a final fit still refuse a stray argument.
- AC5: verified 2026-09-03 — the Reproducibility section of `man/nested_final_fit.Rd` holds one code block, and each of the five `tuner_registry` names (`tune_grid`, `tune_bayes`, `tune_race_anova`, `tune_race_win_loss`, `tune_sim_anneal`) appears in it as a call; the test "the final-fit reproducibility recipe calls every registry tuner" in `test-tuner-registry.R` asserts it, with the installed-help fallback the [O] reviewer ran under `R CMD check`.
- AC6: verified 2026-09-03 — `NEWS.md` opens with an entry on the `extract_` refusal order (the AC4 test) and a compatibility note on the token print, the duplicate-name shed and the rename rule (the AC1, AC2 and AC3 tests); wording defects in both are findings 1 and 3 below.
- AC7: verified 2026-09-03 — `devtools::document()` left the tree clean (`git status` empty); full `devtools::test()` 0 failures, 0 warnings, 0 skips, 5688 passes; `devtools::check()` 0 errors, 0 warnings, 0 notes.
- Driving RR: none; no projection-vs-outcome pairs.
- Consistency gate 2026-09-03: `cairn_validate.py` exit 0, all checks passed, 19 advisories (M57 sizing tripwire, 18 references staleness) — not gate failures; no principle changed, `cairn_impact` skipped; `document()` no diff; README.Rmd and README.md last changed in the same commit; `pkgdown::check_pkgdown()` no problems; NEWS carries the milestone's user-visible changes; no new top-level files; `check()` clean as above.
- Independent review 2026-09-03, three lenses on PR #66's diff. [S] prior-review-record: no findings — the diff closes exactly the M37, M34 and M51 deferred findings as those reviews described; the PR-thread walk over every merged PR touching these files found no inline review comments. [S] blame-history: H1 — `names<-.nested_results()` drops the value comparison D-032 said it shares with `dplyr_reconstruct()`, with no decision line recorded; H2 — the two `extract_` defaults become named exceptions to M34's every-method dots fence (tested, in NEWS). [O] diff-bug, ranked: F1 — the duplicate-name rule in `can_reconstruct_results()`, `vec_restore.nested_results()` and `names<-.nested_results()` runs over every name, so a clash between two non-record columns sheds the run record (confirmed; contradicts AC3 as written); F2 — the recipe's racing and annealing branches sit below `control$seed <- fit$tuning_seed`, so read top-to-bottom they stamp a seed onto a control that has none, contradicting their own comments (confirmed); F3 — the NEWS token-print entry says "the rows alone" but the `cli_h1` banner still prints (confirmed), and the duplicate-name sentence describes a narrower rule than ships (F1); F4 — the AC1 test's "did not complete" assertion is vacuous on a zero-failure object; F5 — the print early return is gated on `!has_results_columns()`, broader than columnless, latent (no live object reaches it); F6 — the token prints `# A tibble: 3 × 0`, the fold count as a row count under the banner (IP4 observation, AC1 met); F7 — the AC5 passing control reads only the section's first text node; F8 — the AC5 loop iterates registry names rather than each entry's `tuner` field; F9 — the section loop has no `break` and no clean stop on a NULL section; F10 — no decision entry for the duplicate shed D-035 did not anticipate.
- conversation: PR #66 — empty read (no reviews, no comments, no unresolved threads).
- gate 2026-09-03: user chose the return; fix now F1, F2, F3, F4, F7, F9, F10/H1 as T8-T12; rejected F5, F6, F8, H2 with the reasons in the work log; no follow-up rows.
