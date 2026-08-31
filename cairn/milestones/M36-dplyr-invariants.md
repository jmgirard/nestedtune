<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M36: Removing an outer fold's row stops producing a `nested_results`

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4
- **Branch/PR:** `m036-dplyr-invariants` / [#45](https://github.com/tidymodels/nestedtune/pull/45)

## Goal

Give `nested_results` the subclass invariants tune's `tune_results` declares, so
a dplyr verb that changes the row set returns a bare tibble instead of an object
still claiming the design it came from.

## Scope

Surface tier: **user-facing** — the deliverable is S3 method behavior on an
exported class that callers reach through ordinary dplyr verbs.

**In:** the dplyr compatibility method `dplyr_reconstruct()` on
`nested_results`, enforcing tune#221's invariant set — rows cannot be added or
removed, rows can be reordered, columns can be added and reordered, and every
column `new_nested_results()` writes must be present and hold the values it
held. `dplyr_row_slice()` and `dplyr_col_modify()` were planned alongside it;
dplyr's defaults for both delegate to `dplyr_reconstruct()`, measured at the
implementation gate, so one method covers the verbs (D-031). `dplyr` joins
Imports (D-031).
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

- [x] AC1 `?nested_tune_grid`'s `@return` states the four invariants above and
      that an operation violating them returns a bare tibble; the sentence
      "Subsetting rows carries both attributes unchanged" is gone from it.
- [x] AC2 Applying each of `filter`, `slice`, `arrange`, `mutate`, `select`,
      `rename`, `relocate`, `group_by`, `ungroup`, `bind_rows`, `bind_cols`,
      `left_join` and `[` to a completed 3-fold `nested_results` returns an
      object that either (a) carries class `nested_results`, with `outer_label`,
      `grid` and `metrics` identical to the source object's and
      `folds_attempted`/`folds_completed` equal to `nrow()` and
      `sum(.completed)` of the rows returned, or (b) carries no `nested_results`
      class at all. Each of those thirteen verbs is asserted by name in
      `tests/testthat/test-dplyr-compat.R`.
- [x] AC3 Every row-removing and row-adding form in the set `filter(.completed)`,
      `slice(1)`, `slice(-1)`, `head(1)`, `x[1, ]`, `x[c(TRUE, FALSE, FALSE), ]`,
      `x[-1, ]` and `bind_rows(x, x)` returns a bare tibble, asserted form by
      form; and none of the returned objects prints
      `Outer resamples: 3-fold cross-validation`.
- [x] AC4 `NEWS.md` records the `[.nested_results` behavior change and the new
      dplyr methods, under D-003's pre-1.0 waiver of the deprecation cycle.
- [x] AC5 `cairn/PROFILE.md`'s verify slot is clean (`devtools::test()`), and
      the fuller pre-review check it names (`devtools::check()`) passes with 0
      errors and 0 warnings, any NOTE justified in the review record.

## Coverage

- AC1 → T4
- AC2 → T1, T3
- AC3 → T1, T3
- AC4 → T4
- AC5 → T5

## Tasks

- [x] T1 Write `tests/testthat/test-dplyr-compat.R`: the thirteen-verb table with
      each verb's expected branch stated in the table, plus AC3's eight
      row-changing forms. Record which verbs fail against the current code —
      `dplyr::slice(res, 1)` is known to keep the class with the parent's
      `outer_label`, measured 2026-08-31 — so the file demonstrably fails before
      T3.
- [x] T2 Settle the dependency shape and write the `cairn/DECISIONS.md` entry:
      `dplyr` into Imports (recommended — it is already installed under `tune`
      and `rsample`, and Suggests plus `vctrs::s3_register()` would let AC2 and
      AC3 skip vacuously on a machine without it), whether the vctrs half comes
      too (planned Out), and the invariant set itself, which supersedes D-010's
      class shape only in what `[` returns.
- [x] T3 Factor the invariant rule out of `[.nested_results`
      (`R/nested-results.R:69-105`) into one helper; register
      `dplyr_reconstruct.nested_results()` against it — T2 measured that
      dplyr's defaults for the other two generics delegate to it — and rewrite
      `[` to delegate. Keep the `has_results_columns()` column gate.
- [x] T4 Roxygen: the invariants into `?nested_tune_grid`'s `@return`, the
      obsolete row-subset sentence out (`R/nested-tune-grid.R:81-83`); NEWS
      entry; `devtools::document()`.
- [x] T5 Register the new test file in the suite's worst-case budget ledger if
      its declared bound needs one; run `devtools::test()` and
      `devtools::check()`.
- [x] T6 Fix the two confirmed behavior defects the review returned, with a test
      apiece. `reconstruct_results()` must promote the keep branch back to a
      tibble the way `bare_results()` already promotes the bare one, so the five
      verbs dplyr hands a bare data frame (`filter`, `mutate`, `arrange`,
      `bind_cols`, `left_join`) stop returning `c("nested_results",
      "data.frame")`; and `can_reconstruct_results()` must stop comparing the
      two record-column sets for equality, which drops the class when a caller
      adds a column matching `^id`. Assert tibble-ness in both branches, and
      assert an added `id`-prefixed column keeps the class.
- [x] T7 The three record fixes the same return directed: a caveat in
      `?nested_tune_grid`'s `@return` naming the dplyr path as where the rule is
      enforced (`rename()` bypasses it); `bare_results()`'s comment loses its
      unreachable "so a grouped result stays grouped" reason; and the two
      rewritten test titles in `test-nested-results-print.R` and
      `test-nested-tune-grid-failures.R` stop claiming subsetting coverage they
      no longer have.
- [ ] T8 Delete the stale `@details` sentence in `R/nested-tune-grid.R:170-172`
      promising that subsetting recomputes `folds_attempted` and
      `folds_completed`, which the new rule makes false, and re-run
      `devtools::document()` so `man/nested_tune_grid.Rd` loses it too. Replace
      it with whatever the surrounding paragraph still needs — the
      `.completed`-column sentence beside it is still true. Add a test that
      fails on the claim: a row subset's five attributes are already asserted
      `NULL` in `test-nested-tune-grid-failures.R`, so widen the roxygen grep
      guard rather than duplicating it if the suite has one.
- [ ] T9 Settle how `record_columns()` identifies the design's own id columns,
      against D-031's "every column `new_nested_results()` writes" (O6), and fix
      the three defects the current `^id` grep leaves. Narrowing the match to
      what rsample actually names (`^id$|^id[0-9]+$`) is the alternative T6
      recorded against and is what stops a caller-added `id_junk` list column
      from becoming an `order()` key on a repeated design (O2) and stops
      `ideal`/`id_extra` from being unremovable once added (O3); weigh it
      against recording the constructor's id columns on the object. Add the
      `length(id_cols) == 0L` guard so an id-less template cannot make the value
      comparison vacuous (O5). Tests first, each red before the fix: a repeated
      design (`id`/`id2` with a tie) taking an added `^id`-prefixed list column
      through two verbs; the add-then-remove round trip for `ideal`, `id_extra`
      and `extra`; the id-less-template case on `can_reconstruct_results()`
      directly; and `expect_bare()` in the compat table's `bare` branch so it
      asserts `tbl_df` like the AC3 blocks do (O7).

## Work log

- 2026-08-31: created by /milestone-plan, from [#32](https://github.com/tidymodels/nestedtune/issues/32) (topepo).
- 2026-08-31: plan gate chose tune#221's strict invariant (a row-count change drops the class) over extending M04's existing `[` behavior (keep the class, recompute the counts) because #32 asks for the strict answer in so many words and it is what tune and rsample already declare; the cost is an API change to `[.nested_results`, waived by D-003. Falsified by a caller or a downstream package depending on a row subset staying a `nested_results`.
- 2026-08-31: plan gate chose dplyr-only over dplyr-plus-vctrs because the reproduced defect is on the dplyr path and the vctrs half roughly doubles the diff; the vctrs methods go to a candidate row. Falsified by a `vec_rbind()` or `vec_ptype2()` path reaching the same stale-attribute state the dplyr methods now block.
- 2026-08-31: [O] criteria audit ran in **full** mode (declared tier user-facing) and returned six findings, all disposed here: the `?nested_results` topic does not exist (retargeted to `?nested_tune_grid`, AC1); AC2's universal quantified over the test file's own table rather than the class (verbs now named literally, table construction moved to T1); AC2 branch one demanded attributes identical to source, which IP4 forbids for the counts (counts now promised against the rows returned); a vacuous-skip leak if dplyr landed in Suggests (T2 recommends Imports and states the leak); AC3's row-removal family stood on two exemplars (widened to eight forms across index, verb and addition); AC5 named a pre-existing NOTE set `cairn/PROFILE.md` does not record (cut to the profile's own verify and check slots, budget registration moved to T5).
- 2026-08-31: T1 — `tests/testthat/test-dplyr-compat.R` written and run against the current code: 10+ failures, the named forms being `slice(1)`, `mutate(.completed = FALSE)`, `rename(fold = id)`, `bind_rows(x, x)`, `x[1, ]` and `filter(.completed)` on a partial run (all keep the class), plus `mutate`/`relocate`/`select(everything())` returning a `nested_results` whose `outer_label` is `NULL`. Both fixtures are cache hits off existing signatures (2 builds, 11 requests). The suite is red at this checkpoint by design.
- 2026-08-31: T2 — implementation gate settled three open choices, all as recommended, and D-031 records them: `dplyr (>= 1.1.0)` into Imports (not Suggests plus load-time registration, which would let the new tests skip vacuously); the invariant set is every column `new_nested_results()` writes, the two per-fold seed columns included; and one method, `dplyr_reconstruct.nested_results()`, rather than the three the plan named — measured that dplyr's default `dplyr_row_slice()` and `dplyr_col_modify()` both route through it, `bind_rows()` included, which is also why tune registers only the one. T3's wording is amended to match. The `vctrs` half stays Out. Suite still red pending T3.
- 2026-08-31: T3 — the rule is `can_reconstruct_results()`/`reconstruct_results()`/`bare_results()` in `R/nested-results.R`; `dplyr_reconstruct.nested_results()` registers against it and `[.nested_results` delegates to it. Four existing tests encoded the old `[` and were rewritten to the new contract (a row subset now sheds the class and its whole record; a column subset dropping the two seed columns does too), with a new `as_fold_subset()` helper for the two print tests that need a classed one-or-two-fold object for a reason other than `[`. `test-dots-barrier.R`'s method probe now classifies by formals rather than by an exemption list, since `dplyr_reconstruct(data, template)` has no `...` to fence and R refuses the argument itself.
- 2026-08-31: T3 — `dplyr::rename()` is measured to bypass the rule: it is `set_names()`, so it reaches the class through `names<-` and vctrs, and renaming `id` leaves a classed object on which `collect_metrics(summarize = FALSE)` dies inside vctrs. tune sheds the class there because it ships the vctrs methods this milestone leaves Out. AC2's disjunction is satisfied either way, so the test asserts it as the disjunction and the finding went to the existing vctrs candidate row rather than widening scope.
- 2026-08-31: T3 — `bare_results()` promotes a plain data frame back to a tibble: dplyr hands `dplyr_reconstruct()` a bare data frame for `slice()` and `bind_rows()`, and subtraction alone turned a sliced tibble into a `data.frame`.
- 2026-08-31: T4 — the four invariants and the bare-tibble branch are in `?nested_tune_grid`'s `@return`; the "Subsetting rows carries both attributes unchanged" sentence is gone; `NEWS.md` records the `[` change, the verbs that keep the class, and `dplyr` becoming a hard dependency; `devtools::document()` run.
- 2026-08-31: amendment — Scope (In) rewritten at a mini gate to the shape the implementation gate chose and D-031 records: one registered method rather than three, the invariant set widened from the five columns `has_results_columns()` names to every column `new_nested_results()` writes, and `dplyr` into Imports named in scope. No acceptance criterion changed; the four invariants AC1 points at are the same four.
- 2026-08-31: correction — the T1 line above says both fixtures were cache hits off existing signatures. The partial one was; the completed one was not — it keyed separately from `test-nested-tune-grid-results.R`'s builder and the run-wide report showed the fit paid for twice. `compat_results()` now builds the run the way `test-nested-results-print.R` does, which is the suite's most-requested completed fixture, and the report is clean.
- 2026-08-31: T5 — no budget row is owed: `test-suite-hygiene.R`'s ledger covers the daemon files by name and `test-dplyr-compat.R` makes no wait-shaped call. `devtools::test()` clean (0 failures; the run-wide cache report is 37 signatures, 37 builds, 119 requests, with no fixture built twice), `devtools::check()` `Status: OK` — 0 errors, 0 warnings, 0 notes — and `pkgdown::check_pkgdown()` finds no problems.
- 2026-08-31: status → review.
- 2026-08-31: T6 — both defects reproduced first on a hand-built 3-fold object (`filter`, `mutate`, `arrange`, `bind_cols`, `left_join` all returned `nested_results,data.frame`; `mutate(id_extra = 1)` and `mutate(ideal = 1)` both shed the class), then fixed. The tibble promotion moved out of `bare_results()` into `as_results_tbl()` and both branches call it. `can_reconstruct_results()` now reads the record off the **template** only and asks that every one of those columns be present in `data` holding the same values, so a caller-added column is not looked at — chosen at a gate over narrowing `record_columns()`'s `^id` grep, which measures the same but keeps two symmetric sets. Tests first, red at 31 failures: `expect_kept()` and `expect_bare()` both assert `tbl_df`, a block names the five bare-data-frame verbs and asserts `mutate(res, extra = 1)[, "id"]` is a tibble rather than a bare vector, and a block asserts `id_extra`, `ideal` and `extra` all keep the class. `test-dplyr-compat.R` FAIL 0 / PASS 156; `devtools::test()` over the suite exits clean.
- 2026-08-31: T7 — the `@return` gains a paragraph naming `dplyr_reconstruct()` as where the rule is enforced and `rename()` as the operation that never reaches it, told as a gap rather than a fourth invariant; `bare_results()`'s "so a grouped result stays grouped" reason went with T6's restructure, since the promotion it justified now lives in `as_results_tbl()`; and the two overclaiming titles are now "an outer scheme the object does not name is left unprinted" (`test-nested-results-print.R`) and "a results object holding no completed fold refuses to summarize" (`test-nested-tune-grid-failures.R`), each with a comment saying the object is the helper's rather than `[`'s. `devtools::document()` rewrote `man/nested_tune_grid.Rd` only. Suite: FAIL 0, WARN 0, SKIP 0, PASS 1911; 37 fixture signatures over 37 builds, none built twice.
- 2026-08-31: defect return 1 closed — `devtools::check()` `Status: OK`, 0 errors, 0 warnings, 0 notes, 2m 43.8s. Status → review.
- 2026-08-31: review — all five criteria passed with fresh evidence and the consistency gate is green, but the [O] lens returned two confirmed behavior defects the criteria do not reach and the maintainer judged load-bearing at the gate: `reconstruct_results()` keeps the class while dropping the tibble classes for the five verbs dplyr hands a bare data frame, and `can_reconstruct_results()`'s set-equality over `^id`-matching names drops the class when a caller adds an `id`-prefixed column, contradicting the "columns may be added" invariant the docs and NEWS both state. Approval withheld; status → in-progress for T6 and T7. Defect return 1. F4 absorbed into the vctrs candidate row, F7 rejected as refuted, the D-030 comment-block finding rejected as pre-existing.
- 2026-08-31: review round 2 — all five criteria re-verified against T6/T7's code (test 1911 PASS / 0 FAIL, check Status: OK 0/0/0) and the consistency gate is green. Three lenses ran; the [O] lens returned seven findings, all confirmed on re-measurement: a stale `@details` sentence still promising the old subsetting behavior, and a family of four rooted in `record_columns()`'s `^id` grep (a hard `order()` error on a repeated design, an added `^id` column that cannot be removed again, a vacuous check under an id-less template, a divergence from the constructor's own id rule), plus two more paths leaving the record readable and one test-rigor gap. Presented at the merge gate.
- 2026-08-31: review round 2 — approval withheld at the merge gate; status → in-progress for T8 and T9. No acceptance criterion failed; the return is under the floor's second limb, the maintainer judging the shipped help page's now-false subsetting sentence (O1), the hard `order()` error a caller-added `^id` list column raises on a repeated design (O2) and the added `^id` column that cannot be removed again (O3) load-bearing for users. O5, O6 and O7 fold into T9 as the same helper's remaining gaps; O4 goes to the vctrs candidate row with round 1's F4. Defect return 2.

## Decisions

## Review

Reviewed 2026-08-31 on `m036-dplyr-invariants` at 7d0b0ea, PR
[#45](https://github.com/tidymodels/nestedtune/pull/45). `origin/main` had not
moved since the branch was cut, so no merge was needed before gathering
evidence.

### Acceptance criteria

- AC1 — `?nested_tune_grid`'s `@return` carries a "What an operation on the
  object may and may not do" block stating the invariants as three bullets
  covering the four clauses (rows reorderable but never added or removed;
  columns addable and reorderable; every listed column present holding the
  values it held) and naming the bare-tibble branch for anything else.
  `grep -rn "Subsetting rows carries" R/ man/ NEWS.md` returns nothing, so the
  obsolete sentence is gone from the roxygen and the generated `.Rd` alike.
- AC2 — `tests/testthat/test-dplyr-compat.R` names all thirteen verbs literally
  in `dplyr_compat_table()`: `filter`, `slice`, `arrange`, `mutate`, `select`,
  `rename`, `relocate`, `group_by`, `ungroup`, `bind_rows`, `bind_cols`,
  `left_join` and `[`, sixteen entries in all, with `mutate`, `select` and `[`
  carried in both directions. `expect_kept()` asserts branch (a) as the
  criterion words it — class present, `outer_label`/`grid`/`metrics` identical
  to the source, `folds_attempted` equal to `nrow(out)` and `folds_completed`
  to `sum(out$.completed)` — and branch (b) is asserted as the absence of the
  class. `devtools::test()` on a completed 3-fold fixture: FAIL 0, WARN 0,
  SKIP 0, PASS 1851, so no entry skipped vacuously.
- AC3 — all eight forms are asserted one `test_that()` block apiece, so a
  failure names its form: `filter(.completed)` on a partial run,
  `slice(1)`, `slice(-1)`, `head(1)`, `x[1, ]`, `x[c(TRUE, FALSE, FALSE), ]`,
  `x[-1, ]` and `bind_rows(x, x)`. A ninth block asserts none of the eight
  prints `Outer resamples: 3-fold cross-validation`, over text captured from
  both `print()` and the cli stream so a bare tibble's empty cli capture cannot
  pass the negative for the wrong reason; each form's text is asserted
  non-empty first, and the source object is the passing control, shown to
  print the line. Green in the same FAIL 0 / SKIP 0 run.
- AC4 — `NEWS.md`'s dev section opens with a "Breaking:" bullet naming the
  `[.nested_results` change by example (`slice()`, `head()`, `x[1, ]`,
  `x[-1, ]`, a `filter()` dropping a failed fold, `bind_rows()`), stating what
  the old behavior returned, and a following paragraph naming the verbs that
  keep the class; a second bullet records `dplyr` becoming a hard dependency.
  No deprecation warning ships, per D-003's pre-1.0 waiver. No milestone
  numbers appear in the entry.
- AC5 — `devtools::test()`: FAIL 0, WARN 0, SKIP 0, PASS 1851.
  `devtools::check()`: `Status: OK`, 0 errors, 0 warnings, 0 notes, duration
  5m 39.1s. No NOTE to justify.

No `Driving RR:` is declared, so the projection-vs-outcome comparison no-ops.

### Consistency gate

- `cairn_validate.py` exit 0 — every check PASS, including `coverage complete`,
  `binding criteria` and `scaffold present`. 18 advisory WARNs, all the standing
  `references staleness` set, unchanged by this milestone. The `release window`
  advisory did not fire.
- No `DESIGN.md` principle changed (the file is not in the diff), so
  `cairn_impact.py --changed` was skipped.
- Toolchain checks, from the `r-package` profile's `consistency-gate` slot:
  `devtools::document()` produces no diff (working tree after the run holds only
  this milestone file); `NAMESPACE` and `man/` are regenerated, not hand-edited;
  `README.Rmd`/`README.md` are untouched by the branch and unchanged since their
  last knit; `pkgdown::check_pkgdown()` — no problems found; `NEWS.md` carries
  the milestone's user-visible changes with no milestone numbers; no new
  top-level file, so no `.Rbuildignore` entry is owed; `devtools::check()`
  `Status: OK`, 0/0/0.

### Independent review

The diff touches executable surface, so all three lenses ran fresh-context, each
on its own evidence base.

**[S] blame-history** — no conflict. The four rewritten test files each drop an
assertion for a reason D-031 records; `as_fold_subset()` keeps the M20-era
print and `collect_metrics` assertions alive without routing through a `[` that
no longer yields a classed subset. Independently confirmed that `group_by()` and
`ungroup()` shed the class through dplyr's own `grouped_df` rebuild rather than
through this package's rule, so the table's expectation for them is not a
latent bug.

**[S] prior-PR-comments** — no regression. Archived findings on these files
(M20 F1 and F2, M03 F1, M34's dots-barrier exemption, M22 P1) are each carried
forward rather than reintroduced; the `[` rewrite removes the M20 hazard
(which `NextMethod()` reaches) instead of resurrecting it. The GitHub probe
found two real inline comments repo-wide, both on workflow files this branch
does not touch, so the thread walk was skipped.
**[O] diff-bug** — seven findings, ranked by the lens most severe first. Each
was re-run against the implementation before triage; verdicts below are this
session's own measurements on a hand-built 3-fold `nested_results`, not the
lens's account.

- F1 (CONFIRMED) — the keep branch drops the tibble classes.
  `reconstruct_results()` promotes nothing, while `bare_results()` does, so a
  verb that hands `dplyr_reconstruct()` a bare data frame returns
  `c("nested_results", "data.frame")`. Measured: `filter()`, `mutate()`,
  `arrange()`, `bind_cols()` and `left_join()` all come back with
  `is_tibble()` FALSE; `select()`, `relocate()` and `[` stay tibbles, so the
  class is a tibble subclass for some verbs and not others. User-visible
  consequence measured: `mutate(res, extra = 1)[, "id"]` reaches
  `[.data.frame`, whose `drop = TRUE` default returns a bare character vector,
  where `res[, "id"]` returns a one-column tibble. Contradicts DESIGN.md's
  "a plain tibble carrying class `nested_results`". Untested in both
  directions — `expect_kept()` asserts class, attributes and counts only.
- F2 (CONFIRMED) — adding a column named `id...` drops the class.
  `record_columns()` greps `^id` to find the design's own id columns, and
  `can_reconstruct_results()` compares the two record-column sets for equality,
  so a caller-added `id`-prefixed column is in `data`'s set and not
  `template`'s. Measured: `mutate(res, id_extra = 1)` and
  `mutate(res, ideal = 1)` both return a bare tibble, while
  `mutate(res, extra = 1)` keeps the class. Contradicts the invariant the
  `@return`, `NEWS.md` and D-031 all state, and `id`-prefixed names are what a
  caller joins in to label folds.
- F3 (CONFIRMED) — the `@return` states the rule unconditionally, but
  `rename()` bypasses it. `dplyr::rename()` is `set_names()`, reaching the class
  through `names<-` and vctrs, so `rename(res, fold = id)` returns a
  `nested_results` with no `id` column — an object the class's own
  `has_results_columns()` gate would reject. The scope call is D-031's and
  stands; the documented contract does not carry the caveat.
- F4 (CONFIRMED) — `group_by()` sheds the class but keeps the whole record.
  Measured: `group_by(res, id)` returns a `grouped_df` still carrying `grid`,
  `outer_label` and `folds_attempted`, because `bare_results()` is the only
  place the attributes are stripped and `group_by()` never routes through it.
  Same root cause as F3: a path that never reaches `dplyr_reconstruct()`.
  `ungroup()` does clear them.
- F5 (CONFIRMED) — `bare_results()`'s comment says the class is subtracted
  rather than replaced "so a grouped result stays grouped", but F4 shows no
  `grouped_df` ever carries the class, so the stated reason is unreachable.
  Harmless as code; a later reader may rely on it.
- F6 (PLAUSIBLE) — two rewritten tests no longer exercise the path their titles
  name. `as_fold_subset()` hand-stamps a classed object with `outer_label`
  omitted, a state `reconstruct_results()` can no longer produce, so "the outer
  scheme is dropped rather than misreported after subsetting" no longer tests
  subsetting. The assertions are still worth keeping; the titles overclaim.
- F7 (REFUTED) — the lens read `dplyr (>= 1.1.0)` as narrowing installability
  for no recorded cause. `tune` is already an Import and its own DESCRIPTION
  requires `dplyr (>= 1.1.0)`, so the floor costs no installation anything.

One further finding from the gate itself, outside the lenses: D-030 sits inside
`cairn/DECISIONS.md`'s trailing `<!-- Template:` comment block, so the entry is
present to a heading grep but renders nowhere. Pre-existing — `git show
main:cairn/DECISIONS.md` puts the `<!-- Template:` line at 892 and D-030 at 894
— and not introduced by this diff.

### Triage

Presented at the merge-approval gate 2026-08-31; approval withheld. The
maintainer judged F1 and F2 load-bearing defects in what the package does for
its users — the return-floor's second limb — so the milestone returns to
`in-progress` rather than being patched at the gate, because both need new test
coverage as well as a code change.

- F1 — fix, as T6. Returns the milestone.
- F2 — fix, as T6. Returns the milestone.
- F3 — fix, as T7: a caveat in the `@return` naming the dplyr path as where the
  rule is enforced.
- F4 — follow-up. Absorbed into the existing `vctrs compatibility methods`
  candidate row, whose promotion condition it satisfies: `group_by()` is the
  first measured path reaching the stale-attribute state, where `rename()` only
  reached a broken object.
- F5 — fix, as T7. The comment goes with the code T6 touches.
- F6 — fix, as T7: the two test titles stop claiming subsetting coverage.
- F7 — rejected. Refuted at verification: `tune` is already an Import and its
  own DESCRIPTION requires `dplyr (>= 1.1.0)`, so the floor narrows no
  installation.
- The D-030 comment-block finding — rejected here as out of scope: pre-existing
  on the default branch and not introduced by this diff. Left for a separate
  tracking fix, since editing it is a records question the milestone does not
  own.

Defect returns on M36: 1.


### Round 2 (2026-08-31, after defect return 1)

Re-reviewed at 2f7c600 on `m036-dplyr-invariants`, PR
[#45](https://github.com/tidymodels/nestedtune/pull/45). `origin/main` had still
not moved (0 behind, 8 ahead), so no merge preceded the evidence below. Round
1's evidence above is superseded by this pass, which re-ran every criterion
against the code T6 and T7 changed.

#### Acceptance criteria

- AC1 — `?nested_tune_grid`'s `@return` carries the "What an operation on the
  object may and may not do" block: three bullets covering the four clauses
  (rows reorderable, never added or removed; columns addable and reorderable;
  every listed column present holding the values it held), the bare-tibble
  branch named with examples, and T7's paragraph naming `dplyr_reconstruct()`
  as where the rule is enforced and `rename()` as the gap.
  `grep -rn "Subsetting rows carries" R/ man/ NEWS.md` exits 1, so the obsolete
  `@return` sentence is gone from roxygen and the generated `.Rd` alike. (A
  different stale sentence survives in `@details` — finding O1 below; AC1 as
  written quantifies over the `@return` and passes.)
- AC2 — `dplyr_compat_table()` in `tests/testthat/test-dplyr-compat.R` names all
  thirteen verbs literally over seventeen entries, `mutate`, `select` and `[`
  carried in both directions. `expect_kept()` asserts branch (a) as the
  criterion words it — class present, `outer_label`/`grid`/`metrics` identical
  to the source, `folds_attempted` equal to `nrow(out)`, `folds_completed` to
  `sum(out$.completed)` — and now `tbl_df` besides (T6); branch (b) is the
  absence of the class. `devtools::test()`: FAIL 0, WARN 0, SKIP 0, PASS 1911,
  so no entry skipped vacuously.
- AC3 — all eight row-changing forms are asserted one `test_that()` block
  apiece, so a failure names its form: `filter(.completed)` on a partial run,
  `slice(1)`, `slice(-1)`, `head(1)`, `x[1, ]`, `x[c(TRUE, FALSE, FALSE), ]`,
  `x[-1, ]`, `bind_rows(x, x)`. A ninth block asserts none of the eight prints
  `Outer resamples: 3-fold cross-validation`, over text captured from both
  `print()` and the cli stream, each form's text asserted non-empty first and
  the source object shown as the passing control. Green in the same FAIL 0 /
  SKIP 0 run.
- AC4 — `NEWS.md`'s dev section opens with a "Breaking:" bullet naming the
  `[.nested_results` change by example (`slice()`, `head()`, `x[1, ]`,
  `x[-1, ]`, a `filter()` dropping a failed fold, `bind_rows()`), states what
  the old behavior returned, and follows with the verbs that keep the class; a
  second bullet records `dplyr` becoming a hard dependency. No deprecation
  warning ships, per D-003's pre-1.0 waiver. No milestone numbers appear.
- AC5 — `devtools::test()`: FAIL 0, WARN 0, SKIP 0, PASS 1911; fixture cache 37
  signatures over 37 builds, none built twice. `devtools::check()`:
  `Status: OK`, 0 errors, 0 warnings, 0 notes, duration 2m 52.3s. No NOTE to
  justify.

No `Driving RR:` is declared, so the projection-vs-outcome comparison no-ops.

#### Consistency gate

- `cairn_validate.py` exit 0 — every check PASS, `coverage complete`,
  `binding criteria` and `scaffold present` included. 18 advisory WARNs, all the
  standing `references staleness` set, unchanged by this milestone. The
  `release window` advisory did not fire.
- No `DESIGN.md` principle changed (the file is not in the diff), so
  `cairn_impact.py --changed` was skipped.
- `r-package` profile `consistency-gate` slot: `devtools::document()` leaves a
  clean working tree; `NAMESPACE` and `man/` are regenerated, not hand-edited;
  `README.Rmd`/`README.md` are untouched by the branch; `pkgdown::check_pkgdown()`
  — no problems found; `NEWS.md` carries the user-visible changes with no
  milestone numbers; no new top-level file, so no `.Rbuildignore` entry is owed;
  no newly exported object, so no `_pkgdown.yml` row is owed
  (`NAMESPACE` gains only `S3method(dplyr_reconstruct,nested_results)` and its
  `importFrom`); `devtools::check()` `Status: OK`, 0/0/0.

#### Independent review

Executable surface is touched, so all three lenses ran fresh-context on distinct
evidence bases.

**[S] blame-history** — no undisclosed conflict. Every removal traces to D-031
and is disclosed in `NEWS.md`, the `@return` and this file; D-010 is narrowed by
D-031 rather than contradicted; D-003 covers the break. It flagged as
completeness observations the two gaps the record already carries — `group_by()`
still reaching the stale-attribute state (round 1's F4, on the vctrs candidate
row) and `rename()` bypassing the rule (round 1's F3, now a documented caveat) —
and noted that `as_fold_subset()` indirects two former `[` tests, which T7's
title rewrite discloses rather than restores. Nothing new.

**[S] prior-review** — no regression. M34's dots-barrier exemption still holds
(`[.nested_results` keeps its `...` and its `NextMethod()`; the formals-based
branch is additive); M20 F1's lesson about `NextMethod()` reaching either `[`
method is strengthened, not undone, since `reconstruct_results()` re-derives the
record itself; M22 P1 is on `nested_final_fit`, untouched. It confirmed T6 and
T7 match round 1's triage exactly. The GitHub probe found one real inline
comment repo-wide, on a workflow file this branch does not touch, and a walk of
every PR touching these files found no non-bot inline comments, so there is no
thread-level surface.

**[O] diff-bug** — seven findings, ranked by the lens most severe first. Each was
re-measured this session against the implementation on a hand-built 3-fold and a
hand-built repeated-design object; the verdicts are those measurements, not the
lens's account.

- O1 (CONFIRMED) — a now-false sentence survives in the shipped help page.
  `R/nested-tune-grid.R:170-172` and `man/nested_tune_grid.Rd:197` still say
  "Subsetting rows recomputes `folds_attempted` and `folds_completed` for the
  rows kept, so the counts always describe the object in hand." That is the
  pre-M36 behavior; a row subset now sheds the class and all five attributes.
  AC1 and its grep were both scoped to the `@return` and to the other sentence's
  exact wording, so neither reached this one. Measured consequence: the same
  topic promises `attr(res[1:2, ], "folds_attempted")` is `2L` a few paragraphs
  above the new invariants block, where the code returns `NULL`.
- O2 (CONFIRMED) — a caller-added `^id`-prefixed list column hard-errors on a
  repeated design. `record_columns()` finds id columns by `grepl("^id", ...)`,
  and dplyr calls `dplyr_reconstruct()` a second time with the *modified* frame
  as template, so the added column joins `id_cols` and becomes an `order()` key.
  Measured on `id = c("Repeat1", "Repeat1", "Repeat2")`, `id2`:
  `mutate(x, id_junk = list(c(1, 2)))` raises
  `unimplemented type 'list' in 'listgreater'` from inside
  `can_reconstruct_results()`, naming no user-facing function. It needs a tie in
  the first id column, so it hits repeated designs and not plain v-fold — the
  same call on a unique-id 3-fold object returns a `nested_results` normally.
  T6's tests cover only atomic added columns (`id_extra`, `ideal`).
- O3 (CONFIRMED) — a caller-added `^id`-prefixed column cannot be removed again.
  Because the record is read off the template and includes anything matching
  `^id`, the column is protected as if the constructor had written it. Measured:
  `select(mutate(res, ideal = 1), -ideal)` returns `tbl_df`, while
  `select(mutate(res, extra = 1), -extra)` returns `nested_results` — the same
  round trip, class kept for one name and lost for the other. The documented
  "columns may be added or reordered" invariant implies an added column is the
  caller's to drop.
- O4 (CONFIRMED) — two more paths join `group_by()` in leaving the record
  readable. `bare_results()` is the only place the attributes are stripped, so
  anything shedding the class without reaching `dplyr_reconstruct()` keeps them.
  Measured on a 3-fold object: `group_by()`, `rowwise()` and
  `tibble::as_tibble()` all return an object with `nested_results` gone and
  `outer_label = "3-fold cross-validation"`, `folds_attempted = 3L` still
  readable. Round 1 deferred this on `group_by()` alone; the other two widen it.
  The compat table's `group_by` entry asserts only the class absence, so it
  passes over the stale attributes.
- O5 (CONFIRMED, unreachable today) — an id-less template makes the value
  comparison vacuous. `id_cols` is then `character(0)`,
  `do.call(order, list())` is `integer(0)`, and both `in_id_order()` results are
  zero-length and `identical()`. Measured: a template whose id column is named
  `fold` accepts a `data` with every record value different. `has_results_columns()`
  is applied to `data`, never `template`, so nothing on this path guarantees an
  id column. Not reachable through the public API — a `rename()`-broken object
  fails the `data`-side gate instead — but a one-line `length(id_cols) == 0L`
  guard closes it.
- O6 (CONFIRMED, no reachable case found) — `record_columns()` re-derives the id
  columns by `^id` grep while the constructor takes them as
  `setdiff(names(resamples), c("splits", "inner_resamples"))`, so an rset
  carrying a label column not spelled `id*` would be constructor-written and
  unprotected, diverging from D-031's stated set. No such rset exists in
  rsample's current conventions.
- O7 (CONFIRMED, test rigor) — the compat table's `bare` branch asserts only
  `expect_false(inherits(...))`, where the standalone AC3 blocks use
  `expect_bare()`, which also asserts `tbl_df`. A table-only bare verb losing its
  tibble classes — round 1's F1 defect, in the other branch — would pass. The
  lens also noted the `filter (rows kept)` entry runs against the completed
  fixture, so it is a no-op filter; the row-dropping direction is covered by
  AC3's own block.

O2, O3, O5 and O6 share one root cause: `record_columns()` identifies the
design's id columns by `^id` prefix rather than by what the constructor wrote.
T6 recorded a gate choice between the template-only read that shipped and
narrowing that grep, on the ground that the two "measure the same"; O2 and O3
are residue the narrowing alternative would not have left, since `id_junk`,
`ideal` and `id_extra` all stop matching `^id$|^id[0-9]+$`.

#### Triage (round 2)

Presented at the merge-approval gate 2026-08-31; approval withheld. No
acceptance criterion failed, so the return is under the floor's second limb: the
maintainer judged O2 and O3 load-bearing defects in what the package does for
its users, and O1 a user-facing contradiction in the shipped help page. All
three need new test coverage as well as a code or doc change, so they return the
milestone rather than being patched at the gate.

- O1 — fix, as T8. Returns the milestone.
- O2 — fix, as T9. Returns the milestone.
- O3 — fix, as T9. Returns the milestone.
- O4 — follow-up. Absorbed into the existing `vctrs compatibility methods`
  candidate row alongside round 1's F4, which it widens from `group_by()` alone
  to `rowwise()` and `tibble::as_tibble()`. Filed at the post-merge hygiene pass.
- O5 — fix, as T9. The guard belongs in the same helper T9 rewrites.
- O6 — fix, as T9. How the design's own id columns are identified is exactly
  what T9 settles, and D-031's "every column the constructor writes" is the
  yardstick the divergence is measured against.
- O7 — fix, as T9's test work. The table's `bare` branch asserts `tbl_df` too,
  so the branch cannot pass over the defect its sibling branch is guarded for.

Defect returns on M36: 2.
