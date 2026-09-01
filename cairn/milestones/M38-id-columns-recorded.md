# M38: A results object's own fold-label columns, recorded rather than guessed

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4
- **Branch/PR:** `m038-id-columns-recorded` — https://github.com/tidymodels/nestedtune/pull/47

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

- [x] AC1. `new_nested_results()` records, as an attribute on the object, the
      column names it took from the design — `setdiff(names(resamples),
      c("splits", "inner_resamples"))` — and `id_columns()` returns that
      record. The recorded value is `"id"` for a 3-fold `nested_resamples()`
      design and `c("id", "id2")` for a 3-fold repeated-twice one.
- [x] AC2. The three defects the M36 review measured on 2026-08-31 no longer
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
- [x] AC3. Replacing a recorded fold-label column with a value that cannot be
      ordered returns a bare tibble instead of aborting from inside the rule:
      `dplyr::mutate(res, id = list(c(1, 2), 3, 4))` is a `tbl_df` carrying no
      `nested_results` class and raises no condition — pre-milestone, an
      abort, `unimplemented type 'list' in 'orderVector1'`.
- [x] AC4. At each of the six methods `NAMESPACE` registers for
      `nested_results` whose body calls the rule, `reconstruct_results()` —
      `dplyr_reconstruct`, `[`, `vec_restore`, `names<-`, `rbind` and
      `vec_cast` (that last registered on the class pair) — a caller column
      carrying each of the five names `id2`, `id0`, `id9`, `ideal` and
      `id_extra` gets the same answer that method gives a caller column named
      `extra`: the same class vector, the same `grid`, `metrics`,
      `outer_label`, `folds_attempted`, `folds_completed` and recorded label
      columns, and the same values in every column but the caller's. Asked on
      `res` (a 3-fold design) and on `rep_res` (a 3-fold repeated-twice
      design, the one AC1's second recorded value is measured on), and for
      both an atomic and a list-valued column — less one (name, design) pair:
      `id2` is a column a repeated design itself carries, so on `rep_res` that
      name replaces a recorded column rather than adding a caller's. Each
      method is asked in one stated shape, with `y` the object carrying the
      caller's column and `bare` the same object with the class taken off:
      `dplyr_reconstruct(bare, y)`, `y[rep(TRUE, nrow(y)), ]`,
      `vec_restore(bare, y)`, `names(y) <- names(y)`, `rbind(y)` and
      `vec_cast(y, y)`.
- [x] AC5. `NEWS.md` and `nested_tune_grid()`'s `@return` state that a column
      you add is read as a fold label only when the resampling design itself
      carries a column of that name, and `NEWS.md`'s M36 sentence narrowing
      the claim to "unless you name it `id` or `id` followed by digits" is
      gone.
- [x] AC6. The `verify` slot of `cairn/PROFILE.md` is clean —
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

- [x] T1. Regression tests for AC2(a), AC2(b), AC2(c) and AC3, red on the
      current tree, each recording in a comment the output measured
      2026-08-31 (`tests/testthat/test-dplyr-compat.R`, beside the M36 cases
      at `:101`, `:223` and `:428`).
- [x] T2. Test for AC1: the recorded value on a 3-fold design and on a
      repeated one, and that `id_columns()` returns it.
- [x] T3. Record the design's columns in `new_nested_results()`
      (`R/nested-results.R:8-38`), add the attribute to `run_attributes()`
      (`:224`) so `stamp_results()` and `copy_results_attributes()` carry it
      and `bare_results()` strips it, and route `id_columns()` (`:91`),
      `record_columns()` (`:97`), `has_results_columns()` (`:547`),
      `fold_ids()` (`:792`), `can_reconstruct_results()` (`:121`) and
      `template_record()` (`:373`) through the record taken from the object or
      the template. `can_reconstruct_results()` and `vec_restore()` take the
      record from the *template*, never from the rows in hand, since dplyr
      hands the rule a bare frame for half the verbs.
- [x] T4. Guard the `do.call(order, ...)` key in `can_reconstruct_results()`
      (`:139-142`) so a recorded column that is not an atomic vector returns
      `FALSE` rather than reaching `order()`.
- [x] T5. The AC4 sweep: six methods × five names × {`res`, `rep_res`} ×
      {atomic, list-valued} less the `id2` × `rep_res` pair — 108 cells, each
      asserting the method's answer equals its answer for `extra`. Fix what it
      reds.
- [x] T6. Mutation check: restore `grep("^id[0-9]*$", names(x))` as the
      derivation and record in the work log which of T1's, T2's and T5's tests
      go red.
- [x] T7. `NEWS.md` bullet and the `@return` invariants text rewritten to what
      the code now does; `devtools::document()`, `air format .`.
- [x] T8. D-entry: the design's columns are recorded at construction and the
      invariant record is read from that record, superseding M36's
      milestone-local decision and amending the clause D-031 fixed.

## Work log

- 2026-08-31: created by /milestone-plan.
- 2026-08-31: criteria audit ran in **full** mode (user-facing tier), fresh-context [O] reader, eleven findings. Fixed here: AC2's mandated test comment and AC1's "asserted on two designs" bound instruments, not the deliverable; AC2(a) was unsatisfiable, since `collect_metrics(summarize = FALSE)` returns one row per fold *and* metric and the fixture uses two, so `$id` is six values; AC4 cited the `@return` as enumerating five doors where it says four; AC5's removal clause named two files but the M36 sentence is only in `NEWS.md`; AC1 mapped only to an implementation task; AC4's matrix varied door and name but not form, omitting the repeated-design and list-column axes the M36 defects arrived on; AC4's `rbind` cell could not discriminate; AC4's "at every door" and its five spellings were bounded by recall, now by `NAMESPACE` and by a stated list; AC1's "every site reads that record" was a source-structure property over an unenumerated domain. Sent to the gate: whether every column the constructor copies is a fold-label column.
- 2026-08-31: plan gate chose recording the constructor's own column set over deriving the label set from a narrower rule, because any narrowing rule is a name pattern again and three M36 review rounds each bought only the next name; falsified by a design whose non-`splits`/`inner_resamples` columns are not all fold labels, which `check_nested()` currently admits (sent to a candidate row).
- 2026-08-31: plan gate chose one attribute travelling in `run_attributes()` over a second private carrier beside `nestedtune_template_record`, because the record describes the call rather than the rows and the three copy sites already carry `run_attributes()` whole; falsified by a path that must preserve the record onto a prototype without the run's description.
- 2026-08-31: implement gate — the sweep's `id2` × `rep_res` cell was dropped (a repeated design carries `id2` itself, so writing it there replaces a recorded column rather than adding a caller's), and the two-label-column fixture is built through the constructor from a real repeated design rather than by restamping a fitted three-fold run.
- 2026-08-31: T1 — four regression tests added to `test-dplyr-compat.R`, all red on the branch point; `repeated_results()` added to `helper-orchestration.R`. Measured on the default branch: AC2(a) gave `c("Fold1, x", "Fold2, x", "Fold3, x")`, AC2(b) a `tbl_df`, AC2(c) an abort `unimplemented type 'list' in 'listgreater'`, AC3 an abort `unimplemented type 'list' in 'orderVector1'`.
- 2026-08-31: T3, T4 — `new_nested_results()` records `id_columns`, which joins `run_attributes()` and is carried by `stamp_results()` and `copy_results_attributes()` and stripped by `bare_results()`; `id_columns()`, `record_columns()`, `has_results_columns()`, `fold_ids()`, `can_reconstruct_results()` and `template_record()` now take the object rather than a name vector, and `can_reconstruct_results()` reads the record off the template and refuses a label column `order()` cannot take. Six stale comments in `test-dplyr-compat.R` corrected and `repeated_shape()` retired.
- 2026-08-31: T2 — `tests/testthat/test-id-columns.R` added with three AC1 blocks; `repeated_results()` split into `repeated_design()` + `results_from()` so a design labelled some other way can be built.
- 2026-08-31: T5's sweep is written in the same file but stays unchecked until the AC4 amendment clears its fresh reader.
- 2026-08-31: AC4 amended at a mini gate. Two exclusions the plan made were measured false: `rbind(x)` keeps the class and separates the fixed code from the broken (`id0` list column on the repeated fixture — bare under the name pattern, kept under the record), and `vec_cast.nested_results.nested_results` is a sixth registered method whose body calls the rule and separates them the same way. The criterion now names six methods anchored to `NAMESPACE` + a `reconstruct_results()` call, states what "the same answer" is a projection over, pins each method's call shape, and names the `rep_res` fixture as AC1's. T5's cell arithmetic moved to T5, where the instrument belongs. `rbind(x, x)` stays out of the sweep because it sheds the class for the rows it adds whatever the column is called.
- 2026-08-31: the amended AC4 went to a fresh-context [O] reader in **full** mode, five findings, all fixed here: four of six call shapes were unpinned and the choice decided runnability (`vec_cast(y, res)` refuses as a loss of precision) and discrimination (`dplyr_reconstruct` against an un-mutated template passes in the broken code too); "the six methods that route a caller's column through the rule" read as exhaustive with "the rule" undefined; two clauses stated instrument sensitivity rather than class behavior; the `names<-` probe put the tested name only in the data, so all 18 of its cells were true by construction; and "AC1's" mis-cited a fixture AC1 does not name. The `names<-` probe changed to an identity name assignment over an object already carrying the caller's column.
- 2026-08-31: T5 — the sweep runs 108 cells (six methods × five names × two designs × two forms, less the `id2` × `rep_res` pair), all green; nothing had to be fixed for it.
- 2026-08-31: T6 — mutation check, the name pattern restored as the derivation. 30 of the sweep's 108 cells go red, five at every one of the six methods, and all 30 are list-valued: no atomic cell separates the two derivations, which is the sweep's weakest axis. Three of T1's four blocks go red (AC2(a), AC2(b), AC2(c)); AC3's does not, because its fault is the `order()` guard rather than the derivation, and it was measured red on the branch point instead. Of T2's three blocks, "recorded under whatever name it has" and "travels with the class" go red; "the constructor records the columns" does not, since the pattern and the record agree on a design rsample named. A second mutation — the constructor stops writing the attribute — reds that block along with thirteen others.
- 2026-08-31: T7, T8 — the M36 `NEWS.md` bullet rewritten to what the code now does and a second bullet added for the `order()` fault, the `@return` invariants section given the sentence AC5 asks for, `devtools::document()` run, `air format .` clean; D-036 recorded. A doc block in `test-id-columns.R` guards the promise in all three files and the removal of M36's narrowing sentence.
- 2026-08-31: all tasks done, status to review. `devtools::document()` produces no diff, `air format .` clean, `cairn_validate` all checks passed (18 references-staleness advisories, unchanged), and `devtools::check()` was OK — 0 errors, 0 warnings, 0 notes, 10m26s — run on the tree at `a89741b` plus one comment-only edit in `R/nested-results.R`.- 2026-08-31: review started; PR #47 opened as a draft. AC1, AC2, AC3 and AC5 verified with fresh evidence; AC4 and AC6 pending the test suite and `devtools::check()`, both running.
- 2026-08-31: correcting the T6 entry above (IP4: superseded, not edited). Re-running the same mutation — `id_columns()` back to `grep("^id[0-9]*$", names(x), value = TRUE)` — over the sweep's own doors reds **60 of 108 cells, 30 atomic and 30 list**, not the 30 list-valued cells that entry recorded. The atomic cells do separate the two derivations, through the `id_columns` projection `door_answer()` compares (`tests/testthat/test-id-columns.R:105`), so the entry's conclusion that "no atomic cell separates the two derivations, which is the sweep's weakest axis" is wrong in both halves. Mutating only the copy the package's internals call, and leaving the copy the sweep's comparison resolves to, reproduces the recorded 30 exactly; mutating both gives 60 (M38 review O2).
- 2026-08-31: review fix-now work — `orderable()` in `can_reconstruct_results()` now refuses a label column carrying a `dim`, with a regression test for the matrix case (M38 review O4); the T6 mutation figure superseded above (O2); O1 and O8 absorbed into the existing `check_nested()` candidate row. `devtools::test()` 2330 passing, `devtools::check()` OK, `cairn_validate` all checks passed.

## Decisions

- 2026-08-31: recorded as D-036 — the design's columns are recorded at construction and every reader takes the label set from that record.

## Review

Fresh evidence, run 2026-08-31 on the branch at `e34b2c6` (default branch `main`
at `f4db8f4`, an ancestor of the branch, so nothing to merge in). PR
https://github.com/tidymodels/nestedtune/pull/47.

- AC1 — `attr(res, "id_columns")` is `"id"` and `id_columns(res)` returns it; on
  the repeated fixture both are `c("id", "id2")`. Each equals
  `setdiff(names(design), c("splits", "inner_resamples"))` measured on the same
  two designs. The constructor writes the attribute at `R/nested-results.R:36`
  from the `id_cols` it copied the columns by (`:10`).
- AC2 — measured on `res` (3-fold) and `rep_res` (3-fold repeated twice):
  (a) `unique(collect_metrics(mutate(res, id2 = "x"), summarize = FALSE)$id)` is
  `c("Fold1", "Fold2", "Fold3")`; (b) `select(mutate(res, id2 = 1), -id2)` has
  class `c("nested_results", "tbl_df", "tbl", "data.frame")`, identical to the
  same round trip on `extra`; (c) `mutate(rep_res, id0 = as.list(...))` returns
  a `nested_results` and no longer aborts.
- AC3 — `mutate(res, id = list(c(1, 2), 3, 4))` returns class
  `c("tbl_df", "tbl", "data.frame")`, does not inherit `nested_results`, and a
  `withCallingHandlers` trap over every condition class caught none.
- AC4 — the six methods the criterion names are exactly the six whose bodies
  call `reconstruct_results()`: `dplyr_reconstruct` (`R/nested-results.R:256`),
  `[` (`:265`), `vec_restore` (`:295`), `vec_cast.nested_results.nested_results`
  (`:482`), `rbind` (`:544`) and `names<-` (`:562`); `NAMESPACE:3-27` registers
  each. The sweep in `tests/testthat/test-id-columns.R:154` runs
  5 names x 2 forms x 6 methods on `res` plus 4 x 2 x 6 on `rep_res` = 108
  comparison cells, each `expect_identical` against the method's answer for
  `extra` over the projection at `:96-107`. Run alone: 132 expectations, 0
  failed — the 108 cells plus the 24 reference controls asserting the reference
  answer kept the class. Its discrimination was re-measured at review by
  restoring `grep("^id[0-9]*$", names(x), value = TRUE)` as the derivation: 60
  of the 108 cells go red, 30 atomic and 30 list.
- AC5 — `NEWS.md:43-60` carries the sentence "A results object now records the
  columns its resampling design labelled the folds with, so a column you add is
  read as a fold label only when the design itself carries a column of that
  name", and a second bullet for the `order()` fault.
  `man/nested_tune_grid.Rd:99-106` (from the `@return` in
  `R/nested-tune-grid.R`) says the same. `grep -rn "followed by digits|unless
  you name it" NEWS.md man/ R/` returns nothing, so M36's narrowing sentence is
  gone.
- AC6 — on the tree carrying the review fix below: `devtools::test()` gives
  `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 2330 ]`, exit 0 (2326 before the fix's
  test); `devtools::document()` exit 0 leaving `man/` and `NAMESPACE` with no
  git diff; `devtools::check()` `Status: OK` in 9m 59.5s — 0 errors, 0 warnings,
  0 notes.

### Consistency gate

`cairn_validate.py` exit 0 — all 16 checks PASS, 5 advisories OK, one WARN
(`references staleness`, the same 18 pages, unchanged by this milestone); the
`release window` advisory did not fire. `DESIGN.md` is untouched, so
`cairn_impact.py --changed` does not apply. Toolchain half, from the
`consistency-gate` slot of `cairn/PROFILE.md`: `devtools::document()` produces
no diff; `NAMESPACE`/`man/` are generated, not hand-edited; README.Rmd and
README.md are untouched by the diff and unchanged; `pkgdown::check_pkgdown()`
passes; `NEWS.md` carries the two user-visible entries; no new top-level files,
and `check()` reports no NOTEs.

### Independent review

Three fresh-context reviewers, none of which wrote the code, on distinct
evidence: an [O] diff-bug lens on `git diff main...HEAD` against the criteria,
DESIGN.md and DECISIONS.md; an [S] blame-history lens on `git log`/`git blame`
of the modified lines; an [S] prior-review lens on the archived `## Review`
sections touching these files. The history lens and the prior-review lens each
reported no findings; the prior-review lens ran the GitHub probe, found one real
inline comment on an unrelated file, walked PRs #45–47 and got empty threads.
The [O] lens reported ten, ranked. Every one is logged below with its
disposition.

- **O1 — a classed object with no `id_columns` record corrupts
  `collect_metrics(summarize = FALSE)`.** Confirmed by measurement: stripping
  the attribute off a classed object gives a returned tibble reporting 0 rows
  with column lengths 0, 6, 6, 6, because `fold_ids()` (`R/nested-results.R:824`)
  answers `character(0)` and `per_fold_metrics()` builds `new_tbl()` from it.
  The only path to such an object is deserializing one built before this branch,
  or hand-building one past `new_nested_results()`. **Follow-up** — absorbed,
  with O8, into the existing candidate row for tightening `check_nested()`
  (search-first: same pass over the entry gate and the constructor), rather than
  a new row, which would have put `ROADMAP.md` over its line cap.
- **O2 — the T6 mutation figure in the work log is wrong.** Confirmed by
  re-running the mutation: 60 of 108 cells red, 30 atomic and 30 list, not the
  30 list-valued cells recorded, and the atomic cells do discriminate. **Fixed
  now** — superseding work-log line above (IP4: the T6 entry is not edited).
- **O3 — a design column that is not a fold label is now recorded as one.**
  Confirmed: a design carrying an extra `note` column gives
  `id_columns = c("id", "note")` and fold labels `"Fold1, a"`. **Rejected** —
  out-of-scope taxonomy: this is the intentional change the plan called for,
  stated in Scope Out, recorded in D-036's consequences, and filed as its own
  candidate row for tightening `check_nested()`.
- **O4 — the new `order()` guard admits a matrix.** Confirmed:
  `is.atomic()` is `TRUE` for a matrix, `order()` on a 3x2 matrix returns a
  length-6 permutation, both sides index out to the same NA padding, and
  `mutate()` on such an object returned a `nested_results`. A defect inside an
  intentional change. **Fixed now** — `is.null(dim(...))` added to `orderable()`
  (`R/nested-results.R:164-170`), with a regression test asserting the matrix
  case is bare (`tests/testthat/test-dplyr-compat.R:551`); the pre-fix
  measurement above is its planted defect.
- **O5 — `vec_ptype2` copies one side's record when two differently-labelled
  runs meet.** **Rejected** — the same shape the pre-existing `grid`/`metrics`
  copying has, latent by the reviewer's own account, and D-035's measurements
  record nothing in the package reaching the lattice asymmetry.
- **O6 — `has_results_columns()`'s defaulted `id_cols` could be misread by a
  future call site.** **Rejected** — both existing call sites pass the
  template's record; a hypothetical future mistake is not a defect in the diff.
- **O7 — the attribute name `id_columns` is unprefixed.** **Rejected** —
  `grid`, `metrics` and `outer_label` set that precedent on the same object; no
  partial-match hazard exists.
- **O8 — the constructor accepts a design with no label columns.** **Follow-up**
  — absorbed into the same candidate row as O1.
- **O9 — AC5's doc guard skips under `R CMD check`.** **Rejected as already
  handled** — true and the test says so in its own comment, but AC5's evidence
  above is a direct read of `NEWS.md` and `man/nested_tune_grid.Rd` plus a grep
  for the removed sentence, not the check run.
- **O10 — `results_from()` sets `.notes = NULL` rather than tune's 0-row
  tibbles.** **Rejected** — a fixture nit on a helper nothing in the sweep or
  the AC blocks reads.

No finding demonstrates an acceptance criterion failing, so the return floor is
not reached: O4 falls outside AC3's domain (a matrix is a value `order()` takes,
which is why the guard let it past), and O1, O2 and O3 name no criterion.
