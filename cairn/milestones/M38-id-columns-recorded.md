# M38: A results object's own fold-label columns, recorded rather than guessed

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4
- **Branch/PR:** —

## Goal

`nested_results` reads its own fold-label columns off a record the constructor
wrote, so a column a caller adds is never mistaken for one the design named.

## Scope

Surface tier: **user-facing** — the deliverable is the behavior of an exported
class under dplyr, vctrs and base verbs, plus the help page and `NEWS.md` that
document it.

**In:** `new_nested_results()` records the column names it took from the
design; `id_columns()` returns that record instead of matching
`^id[0-9]*$` against the object's current names, and the readers that ask it —
`record_columns()`, `has_results_columns()`, `fold_ids()`,
`can_reconstruct_results()`, `template_record()` — take the answer from the
object or the template rather than from a name. The record travels with the
run's description (`run_attributes()`), so `stamp_results()` and
`copy_results_attributes()` carry it and `bare_results()` strips it. The
comparison in `can_reconstruct_results()` refuses rather than aborts when a
recorded column cannot be ordered. `NEWS.md` and the `@return` say what the
code then does.

Every column the constructor copies from the design — everything beside
`splits` and `inner_resamples` — is one set: the invariant record, the fold
label, and the order key are all read from it, so no name pattern survives.

**Out:** tightening `check_nested()` (`R/checks.R:129`) to refuse a design
carrying columns beside `splits`, `inner_resamples` and `^id`-named ones →
candidate row, added by this plan. The seven M37 review findings deferred to
their own candidate row stay there.

## Acceptance criteria

- [ ] AC1. `new_nested_results()` records, as an attribute on the object, the
      column names it took from the design — `setdiff(names(resamples),
      c("splits", "inner_resamples"))` — and `id_columns()` returns that
      record. The recorded value is `"id"` for a 3-fold `nested_resamples()`
      design and `c("id", "id2")` for a 3-fold repeated-twice one.
- [ ] AC2. The three defects the M36 review measured on 2026-08-31 no longer
      occur, on `res` (a 3-fold design) and `rep_res` (3-fold repeated twice):
      (a) `unique(collect_metrics(dplyr::mutate(res, id2 = "x"), summarize =
      FALSE)$id)` is `c("Fold1", "Fold2", "Fold3")` — pre-milestone,
      `c("Fold1, x", "Fold2, x", "Fold3, x")`;
      (b) `dplyr::select(dplyr::mutate(res, id2 = 1), -id2)` is a
      `nested_results`, the answer the same round trip on `extra` gives —
      pre-milestone, a `tbl_df`;
      (c) `dplyr::mutate(rep_res, id0 = as.list(seq_len(nrow(rep_res))))` is a
      `nested_results` — pre-milestone, an abort, `unimplemented type 'list'
      in 'listgreater'`.
- [ ] AC3. Replacing a recorded fold-label column with a value that cannot be
      ordered returns a bare tibble instead of aborting from inside the rule:
      `dplyr::mutate(res, id = list(c(1, 2), 3, 4))` is a `tbl_df` carrying no
      `nested_results` class and raises no condition — pre-milestone, an
      abort, `unimplemented type 'list' in 'orderVector1'`.
- [ ] AC4. At each of the four S3 methods `NAMESPACE` registers on
      `nested_results` that route a caller's column through the rule —
      `dplyr_reconstruct`, `[`, `vec_restore`, `names<-` — a caller column
      carrying each of the five names `id2`, `id0`, `id9`, `ideal` and
      `id_extra` gets the same answer that method gives a caller column named
      `extra`, on both `res` and `rep_res` and for both an atomic and a
      list-valued column. `rbind` is the fifth registered method and is
      excluded from this sweep: it sheds the class whatever the column is
      called, so its cells cannot tell the fixed code from the broken code.
- [ ] AC5. `NEWS.md` and `nested_tune_grid()`'s `@return` state that a column
      you add is read as a fold label only when the resampling design itself
      carries a column of that name, and `NEWS.md`'s M36 sentence narrowing
      the claim to "unless you name it `id` or `id` followed by digits" is
      gone.
- [ ] AC6. The `verify` slot of `cairn/PROFILE.md` is clean —
      `devtools::test()` passing and `devtools::document()` run — and
      `devtools::check()` is clean at review (0 errors, 0 warnings).

## Coverage

- AC1 → T2, T3
- AC2 → T1, T3
- AC3 → T1, T4
- AC4 → T5
- AC5 → T7
- AC6 → T3, T4, T5, T7

## Tasks

- [ ] T1. Regression tests for AC2(a), AC2(b), AC2(c) and AC3, red on the
      current tree, each recording in a comment the output measured
      2026-08-31 (`tests/testthat/test-dplyr-compat.R`, beside the M36 cases
      at `:101`, `:223` and `:428`).
- [ ] T2. Test for AC1: the recorded value on a 3-fold design and on a
      repeated one, and that `id_columns()` returns it.
- [ ] T3. Record the design's columns in `new_nested_results()`
      (`R/nested-results.R:8-38`), add the attribute to `run_attributes()`
      (`:224`) so `stamp_results()` and `copy_results_attributes()` carry it
      and `bare_results()` strips it, and route `id_columns()` (`:91`),
      `record_columns()` (`:97`), `has_results_columns()` (`:547`),
      `fold_ids()` (`:792`), `can_reconstruct_results()` (`:121`) and
      `template_record()` (`:373`) through the record taken from the object or
      the template. `can_reconstruct_results()` and `vec_restore()` take the
      record from the *template*, never from the rows in hand, since dplyr
      hands the rule a bare frame for half the verbs.
- [ ] T4. Guard the `do.call(order, ...)` key in `can_reconstruct_results()`
      (`:139-142`) so a recorded column that is not an atomic vector returns
      `FALSE` rather than reaching `order()`.
- [ ] T5. The AC4 sweep: four methods × five names × {`res`, `rep_res`} ×
      {atomic, list-valued}, each cell asserting the method's answer equals
      its answer for `extra`. Fix what it reds.
- [ ] T6. Mutation check: restore `grep("^id[0-9]*$", names(x))` as the
      derivation and record in the work log which of T1's, T2's and T5's tests
      go red.
- [ ] T7. `NEWS.md` bullet and the `@return` invariants text rewritten to what
      the code now does; `devtools::document()`, `air format .`.
- [ ] T8. D-entry: the design's columns are recorded at construction and the
      invariant record is read from that record, superseding M36's
      milestone-local decision and amending the clause D-031 fixed.

## Work log

- 2026-08-31: created by /milestone-plan.
- 2026-08-31: criteria audit ran in **full** mode (user-facing tier), fresh-context [O] reader, eleven findings. Fixed here: AC2's mandated test comment and AC1's "asserted on two designs" bound instruments, not the deliverable; AC2(a) was unsatisfiable, since `collect_metrics(summarize = FALSE)` returns one row per fold *and* metric and the fixture uses two, so `$id` is six values; AC4 cited the `@return` as enumerating five doors where it says four; AC5's removal clause named two files but the M36 sentence is only in `NEWS.md`; AC1 mapped only to an implementation task; AC4's matrix varied door and name but not form, omitting the repeated-design and list-column axes the M36 defects arrived on; AC4's `rbind` cell could not discriminate; AC4's "at every door" and its five spellings were bounded by recall, now by `NAMESPACE` and by a stated list; AC1's "every site reads that record" was a source-structure property over an unenumerated domain. Sent to the gate: whether every column the constructor copies is a fold-label column.
- 2026-08-31: plan gate chose recording the constructor's own column set over deriving the label set from a narrower rule, because any narrowing rule is a name pattern again and three M36 review rounds each bought only the next name; falsified by a design whose non-`splits`/`inner_resamples` columns are not all fold labels, which `check_nested()` currently admits (sent to a candidate row).
- 2026-08-31: plan gate chose one attribute travelling in `run_attributes()` over a second private carrier beside `nestedtune_template_record`, because the record describes the call rather than the rows and the three copy sites already carry `run_attributes()` whole; falsified by a path that must preserve the record onto a prototype without the run's description.

## Decisions

## Review
