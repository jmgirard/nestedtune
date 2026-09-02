# M44: `agreement()` tabulates what the outer folds selected

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, IP4, GP3
- **Branch/PR:** m044-agreement

## Goal

A user asks a `nested_results` how often each candidate was selected across
the outer folds and gets a table back, keyed by the whole selected parameter
combination, most frequent first.

## Scope

User-facing tier: the deliverable is an exported generic, its method and its
help page. Issue [#36](https://github.com/tidymodels/nestedtune/issues/36)
(topepo), absorbing the candidate row added 2026-08-31. The facts are on the
object (`.selected`, one row per fold from `tune::select_best()`); `summary()`
prints them per parameter and `autoplot(type = "parameters")` draws them; what
is missing is the table.

**In:**
- `agreement()`, an S3 generic this package owns (the D-023 shape: a
  `nested_results` method and a default that aborts as a classed condition),
  in `R/nested-results-agreement.R`. One row per distinct combination of the
  selected parameter values, the parameter columns as `.selected` carries them,
  `n` the count of completed folds that chose it, `prop` = `n` over the
  completed fold count; `.config` dropped, being a per-run label (M21: folds
  can search different grids). Rows by `n` descending, ties in the order the
  combination first appears in the object's own row order.
- A partial run is tabulated with the warning `summary()` gives, worded for a
  table; an all-failed run aborts through `check_any_completed()` as the other
  accessors do (IP4). A workflow with nothing to tune gives zero rows.
- Help page with the IP3 sentence: the most frequent row is not the final
  model's parameters (D-014 rejected that vote); `nested_final_fit()` is.
- D-entry recording the name and the owned-generic choice, citing D-023.

**Out:**
- A long-form `tidy()` method (one row per fold per parameter) → declined at
  the gate; `.selected` and `autoplot()` already carry that shape. No row.
- Per-parameter marginals → `summary()` prints them; not duplicated here.
- A `nested_final_fit` method → the object holds one selection; nothing to
  tabulate.

## Acceptance criteria

- [ ] AC1: `agreement()` is an exported S3 generic with a `nested_results`
      method and a default method; calling `agreement()` on a `tune_results`,
      a data frame and a list each signals an error of class
      `nestedtune_no_agreement_method` whose message describes the object in
      the form `abort_no_extract_method()` uses and names `nested_results` as
      the class that answers; `agreement(res, foo = 1)` signals
      `rlib_error_dots_nonempty`.
- [ ] AC2: On the three-fold `det_nested(d)` fixture (`num_comp` 3, 3, 3)
      `agreement(res)` returns a tibble with columns `num_comp`, `n`, `prop`
      and no `.config`, holding one row, `n = 3L`, `prop = 1`; on the four-fold
      `split` fixture (`num_comp` 4, 4, 4, 3) two rows in this order:
      `num_comp = 4` with `n = 3L`, `prop = 0.75`, then `num_comp = 3` with
      `n = 1L`, `prop = 0.25`; on each, `sum(n)` equals the completed fold
      count.
- [ ] AC3: Identity is the whole tuple, and ordering follows the rows: on the
      three-fold fixture with a second parameter column added to every
      selection in the test so that folds 1 and 3 carry the same pair and fold
      2 differs only in the second parameter, two rows: the shared pair with
      `n = 2L`, then fold 2's with `n = 1L`; on that object reordered as
      `res[c(2, 1, 3), ]` with fold 3's selection changed to a third pair, three
      rows with `n = 1L` each in the object's row order (fold 2's first); and
      on the three-fold fixture with two folds' `.config` labels edited to
      differ, still one row with `n = 3L`.
- [ ] AC4: On the partial-parameter fixture (one completed fold's selection
      carries only `.config`), that fold forms its own row with `num_comp` `NA`
      and `n = 1L`, separate from the folds that chose a value; on the
      NA-selected fixture, the fold that selected `NA` counts as one row with
      `num_comp` `NA`; on each, `sum(n)` equals the completed fold count.
- [ ] AC5: On the one-fold-failed fixture `agreement()` signals a condition of
      class `nestedtune_partial_summary` whose message says the table covers 2
      of 3 outer folds and whose call is the `agreement()` call, and returns
      rows whose `n` sum to `2L` with `prop` over 2; on the every-fold-failed
      fixture it signals the error `check_any_completed()` signals for
      `collect_metrics()`, of the same class; on a results object whose every
      completed fold's selection carries only `.config` it returns a zero-row
      tibble with columns `n` and `prop` and signals no condition of class
      `nestedtune_partial_summary`.
- [ ] AC6: `man/agreement.Rd`, as `devtools::document()` regenerates it,
      carries a `\value` section naming the `n` and `prop` columns and the
      ordering, a sentence stating that the most frequent combination is not
      the final model's parameters and naming `nested_final_fit()`, and an
      `\examples` section guarded by `@examplesIf rlang::is_installed(c("recipes",
      "yardstick"))` that builds a `nested_results` and calls `agreement()` on
      it; `_pkgdown.yml` lists `agreement` under "Running the loop";
      `NEWS.md` carries one entry stating that `agreement()` reports how often
      each candidate was selected across the outer folds; `DESCRIPTION`
      is unchanged.
- [ ] AC7: `devtools::document()` leaves no diff, `devtools::test()` is clean,
      `air format .` changes nothing, `devtools::check()` reports 0 errors, 0
      warnings and 0 notes, and `pkgdown::check_pkgdown()` passes.

## Coverage

- AC1 → T1
- AC2 → T1
- AC3 → T2
- AC4 → T2
- AC5 → T2
- AC6 → T3
- AC7 → T4

## Tasks

- [x] T1: `R/nested-results-agreement.R`: generic, default aborting through a
      helper shaped like `abort_no_extract_method()`
      (`R/nested-final-fit-extract.R:181`) with class
      `nestedtune_no_agreement_method`, and the method: `check_dots_empty()`,
      `check_any_completed()`, the partial warning, then stack the completed
      folds' selections (M06 lesson: `do.call(rbind, ...)`, never `$` on the
      column) via `selection_params()`, drop `.config`, count with
      `vctrs::vec_count()` or `dplyr::count()` preserving first-appearance
      order, sort by `n` descending stably, `prop = n / completed`, return
      `new_tbl()`. Tests for AC1 and AC2 in `test-nested-results-agreement.R`.
- [x] T2: Edge tests (AC3–AC5): the two-column, reordered and `.config`-edited
      objects built by editing the three-fold fixture's `.selected` elements
      as `test-nested-results-print.R:620-680` does; the partial-parameter and
      NA-selected shapes; `break_fold()` / `break_every_fold()` for AC5.
      `warn_partial_summary()` (`R/nested-results.R:814`) gains a noun so its
      message says "table" here; `check_any_completed()` gets an `action` for
      this caller if it needs one. Any missing-parameter subtlety a test finds
      is recorded in the work log, not silently resolved.
- [x] T3: Roxygen with `@return`, the IP3 sentence, an `@examplesIf` block
      mirroring `R/nested-results-print.R`'s; `_pkgdown.yml` row; NEWS entry;
      `DESIGN.md` Function Families gains the method beside `collect_metrics()`.
- [ ] T4: `air format .`; `devtools::document()`, `devtools::test()`,
      `devtools::check()`, `pkgdown::check_pkgdown()` (AC7).

## Work log

- 2026-09-01: created by /milestone-plan.
- 2026-09-01: criteria audit ran in full mode ([O] reader): 15 findings — AC3 unsatisfiable on its fixture; AC2 named the wrong fixtures and a `table()` comparison contradicting its ordering; the all-failed run warned where every other accessor aborts; missing-parameter and NA-selected folds, ties and `.config` collapse unprobed; instrument clauses (test filename, example's last call); "no warning" over-broad; NOTEs unpinned; the name and the nothing-tuned shape open — twelve fixed in the criteria as written, three settled at the gate.
- 2026-09-01: plan gate chose the name `agreement()` over `consensus()` (reads as one winner, the modal-vote reading D-014 rejected), `collect_selections()` (tune's `collect_` family stacks rows rather than tallying) and a long-form `tidy()` method (an import plus a dependency decision for a shape `.selected` already holds); falsified by users reading `agreement()` as a single scalar measure rather than a table.
- 2026-09-01: plan gate chose zero rows for a run with nothing tuned over one row for the empty tuple, because it matches `summary()`'s "No tuned parameters" and claims no candidate exists; falsified by a caller needing `sum(n)` to hold on such a run.
- 2026-09-01: plan gate chose aborting on an all-failed run, through `check_any_completed()`, over warning and returning an empty table, because `collect_metrics()`, `summary()` and `autoplot()` already refuse there (IP4); falsified by a caller who needs an empty table to loop over.
- 2026-09-01: the gate declined a long-form `tidy()` method; no candidate row, at the user's choice.
- 2026-09-01: checkpoint, half-done: `R/nested-results-agreement.R`, its 68-expectation test file (AC1–AC5 all asserted and passing on the file alone), `warn_partial_summary(noun)`, the pkgdown row, NEWS entry and DESIGN line are written; T1–T3 stay unticked until the full `devtools::test()` run finishes clean.
- 2026-09-01: T1 done — generic, default (`abort_no_agreement_method()`, class `nestedtune_no_agreement_method`) and method; counting by `vctrs::vec_count(sort = "location")` then a stable `order(-count)`, folds stacked with `vctrs::vec_rbind()` over one-row frames so a fold lacking a parameter fills `NA` by common type. Full `devtools::test()`: 2816 pass, 0 fail, 0 warn.
- 2026-09-01: T2 done — AC3–AC5 tests; `warn_partial_summary()` gained `noun = "summary"`, `check_any_completed()` is called with `action = "tabulate"`. One subtlety found: `rbind()` of two row-subsets sheds the class (the vctrs template rule), so the reordered fixture is built by the single subset `paired[c(2, 1, 3), ]` the criterion names. No missing-parameter subtlety beyond the planned `NA` row.
- 2026-09-01: T3 done — roxygen (claims checked against the example's output: two rows, `num_comp` 1 then 2, `n` 2 and 1, `prop` 0.667 and 0.333), `_pkgdown.yml` row, NEWS entry, DESIGN Function Families line; D-039 was written at planning.

## Decisions

## Review
