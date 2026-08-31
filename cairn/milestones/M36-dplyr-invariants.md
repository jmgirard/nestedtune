<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M36: Removing an outer fold's row stops producing a `nested_results`

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4
- **Branch/PR:** —

## Goal

Give `nested_results` the subclass invariants tune's `tune_results` declares, so
a dplyr verb that changes the row set returns a bare tibble instead of an object
still claiming the design it came from.

## Scope

Surface tier: **user-facing** — the deliverable is S3 method behavior on an
exported class that callers reach through ordinary dplyr verbs.

**In:** dplyr compatibility methods (`dplyr_reconstruct()`, `dplyr_row_slice()`,
`dplyr_col_modify()`) on `nested_results`, enforcing tune#221's invariant set —
rows cannot be added or removed, rows can be reordered, columns can be added and
reordered, the columns `has_results_columns()` names must be present.
`[.nested_results` (`R/nested-results.R:69-105`) is rewritten to delegate to the
same rule, which changes its behavior: it keeps the class on a row subset today
and will stop. The `@return` sentence that promises a row subset carries `grid`
and `metrics` unchanged (`R/nested-tune-grid.R:81-83`) goes with it. Closes
[#32](https://github.com/tidymodels/nestedtune/issues/32).

**Out:** vctrs compatibility methods (`vec_restore`, `vec_ptype2`, `vec_cast`),
which tune#221 shipped alongside → ROADMAP candidate row. `nested_final_fit` is
not a tibble subclass and is untouched. The `print()`/`summary()` split (#34),
the selection-frequency method (#36) and the generalized tuning interface (#35)
→ their own candidate rows. The daemon package-loading bug (#37) → `/hotfix`.

## Acceptance criteria

- [ ] AC1 `?nested_tune_grid`'s `@return` states the four invariants above and
      that an operation violating them returns a bare tibble; the sentence
      "Subsetting rows carries both attributes unchanged" is gone from it.
- [ ] AC2 Applying each of `filter`, `slice`, `arrange`, `mutate`, `select`,
      `rename`, `relocate`, `group_by`, `ungroup`, `bind_rows`, `bind_cols`,
      `left_join` and `[` to a completed 3-fold `nested_results` returns an
      object that either (a) carries class `nested_results`, with `outer_label`,
      `grid` and `metrics` identical to the source object's and
      `folds_attempted`/`folds_completed` equal to `nrow()` and
      `sum(.completed)` of the rows returned, or (b) carries no `nested_results`
      class at all. Each of those thirteen verbs is asserted by name in
      `tests/testthat/test-dplyr-compat.R`.
- [ ] AC3 Every row-removing and row-adding form in the set `filter(.completed)`,
      `slice(1)`, `slice(-1)`, `head(1)`, `x[1, ]`, `x[c(TRUE, FALSE, FALSE), ]`,
      `x[-1, ]` and `bind_rows(x, x)` returns a bare tibble, asserted form by
      form; and none of the returned objects prints
      `Outer resamples: 3-fold cross-validation`.
- [ ] AC4 `NEWS.md` records the `[.nested_results` behavior change and the new
      dplyr methods, under D-003's pre-1.0 waiver of the deprecation cycle.
- [ ] AC5 `cairn/PROFILE.md`'s verify slot is clean (`devtools::test()`), and
      the fuller pre-review check it names (`devtools::check()`) passes with 0
      errors and 0 warnings, any NOTE justified in the review record.

## Coverage

- AC1 → T4
- AC2 → T1, T3
- AC3 → T1, T3
- AC4 → T4
- AC5 → T5

## Tasks

- [ ] T1 Write `tests/testthat/test-dplyr-compat.R`: the thirteen-verb table with
      each verb's expected branch stated in the table, plus AC3's eight
      row-changing forms. Record which verbs fail against the current code —
      `dplyr::slice(res, 1)` is known to keep the class with the parent's
      `outer_label`, measured 2026-08-31 — so the file demonstrably fails before
      T3.
- [ ] T2 Settle the dependency shape and write the `cairn/DECISIONS.md` entry:
      `dplyr` into Imports (recommended — it is already installed under `tune`
      and `rsample`, and Suggests plus `vctrs::s3_register()` would let AC2 and
      AC3 skip vacuously on a machine without it), whether the vctrs half comes
      too (planned Out), and the invariant set itself, which supersedes D-010's
      class shape only in what `[` returns.
- [ ] T3 Factor the invariant rule out of `[.nested_results`
      (`R/nested-results.R:69-105`) into one helper; register
      `dplyr_reconstruct.nested_results()`, `dplyr_row_slice.nested_results()`
      and `dplyr_col_modify.nested_results()` against it, and rewrite `[` to
      delegate. Keep the `has_results_columns()` column gate.
- [ ] T4 Roxygen: the invariants into `?nested_tune_grid`'s `@return`, the
      obsolete row-subset sentence out (`R/nested-tune-grid.R:81-83`); NEWS
      entry; `devtools::document()`.
- [ ] T5 Register the new test file in the suite's worst-case budget ledger if
      its declared bound needs one; run `devtools::test()` and
      `devtools::check()`.

## Work log

- 2026-08-31: created by /milestone-plan, from [#32](https://github.com/tidymodels/nestedtune/issues/32) (topepo).
- 2026-08-31: plan gate chose tune#221's strict invariant (a row-count change drops the class) over extending M04's existing `[` behavior (keep the class, recompute the counts) because #32 asks for the strict answer in so many words and it is what tune and rsample already declare; the cost is an API change to `[.nested_results`, waived by D-003. Falsified by a caller or a downstream package depending on a row subset staying a `nested_results`.
- 2026-08-31: plan gate chose dplyr-only over dplyr-plus-vctrs because the reproduced defect is on the dplyr path and the vctrs half roughly doubles the diff; the vctrs methods go to a candidate row. Falsified by a `vec_rbind()` or `vec_ptype2()` path reaching the same stale-attribute state the dplyr methods now block.
- 2026-08-31: [O] criteria audit ran in **full** mode (declared tier user-facing) and returned six findings, all disposed here: the `?nested_results` topic does not exist (retargeted to `?nested_tune_grid`, AC1); AC2's universal quantified over the test file's own table rather than the class (verbs now named literally, table construction moved to T1); AC2 branch one demanded attributes identical to source, which IP4 forbids for the counts (counts now promised against the rows returned); a vacuous-skip leak if dplyr landed in Suggests (T2 recommends Imports and states the leak); AC3's row-removal family stood on two exemplars (widened to eight forms across index, verb and addition); AC5 named a pre-existing NOTE set `cairn/PROFILE.md` does not record (cut to the profile's own verify and check slots, budget registration moved to T5).

## Decisions

## Review
