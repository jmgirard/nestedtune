<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M39: `print()` shows the object, `summary()` says what it means

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, IP4
- **Branch/PR:** `m039-print-tibble-summary-split`

## Goal

Printing a `nested_results` shows a user it is a tibble of outer folds, and the
annotations M04 built move behind `summary()`.

## Scope

Surface tier: **user-facing** — all three methods are exported API and their
output is what a user meets.

**In:** rewrite `print.nested_results()` to the shape of
`tune:::print.tune_results()` (header, outer-scheme line, the object's own rows,
a failure count, the disagreement line, a pointer to `summary()`); add
`summary.nested_results()` + `print.summary.nested_results()` carrying M04's
four section builders and the IP3 sentence; fix the fold-label indexing defect
in the relocated failure section (M38 review O8); re-point the print tests and
snapshot; NEWS, roxygen, `_pkgdown.yml`.

**Out:** the `nested_final_fit` half — `summary.nested_final_fit()` and its
print method → M40, which mirrors the object shape this milestone fixes.
`print.nested_final_fit()` is untouched by either: it holds no rows to reveal
and its bullets are RR02 Q7's answer, which neither milestone reopens.
The same `fold_ids()`-then-index shape at `R/nested-results.R:790`, `:810`,
`R/nested-tune-grid.R:734` and `R/nested-results-plot.R:247` → the
`check_nested()` candidate row, which already owns M38 review O1 and O8's
siblings. A tabular selection-frequency API → issue #36's candidate row, which
`summary.nested_results`'s returned object is built to serve later. Moving
`tibble` to Imports → stays refused; D-037 records why.

## Acceptance criteria

- [ ] AC1. Printing a `nested_results` emits, in this order: a header naming
      the object; a line naming the outer resampling scheme when
      `attr(x, "outer_label")` is non-NULL, and no such line when it is NULL;
      the object's own rows, rendered by the print method its classes dispatch
      to once `nested_results` is removed from them; one line naming how many
      outer folds have `.completed` FALSE, emitted only when that count exceeds
      zero; the line `print_candidate_sets()` emits when `same_candidates()` is
      FALSE over the completed folds' `.grid`, and no such line when it is TRUE;
      and one line naming `summary()`. It emits no other line.
- [ ] AC2. `summary()` on a `nested_results` returns an object of class
      `summary.nested_results`, and printing that object emits what
      `print_design()`, `print_failures()`, `print_selection()` and
      `print_estimate()` emit today, less `print_selection()`'s call to
      `print_candidate_sets()`, which AC1 keeps in `print()` and which this
      output does not repeat — together with the IP3 sentence
      `print.nested_results()` currently emits after `print_estimate()`.
- [ ] AC3. `summary()` on a `nested_results` with at least one `.completed`
      FALSE signals a condition of class `nestedtune_partial_summary` and still
      returns its object; with every `.completed` TRUE it signals no condition.
      It never aborts, including where every fold failed — `collect_metrics()`'s
      `check_any_completed()` abort is not inherited, because a description of a
      failed run is what M04 built and M03 recorded.
- [ ] AC4. Where a `nested_results`' recorded `id_columns` cannot label its
      rows, `print()` and `print(summary())` name each failed fold by its row
      position rather than raising or emitting a truncated label, in all three
      forms the record takes: an attribute of length zero; one naming a column
      the object no longer carries; and one naming several columns of which
      some are absent — the third being the form `fold_ids()` answers wrongly
      today rather than raising.
- [ ] AC5. Over the objects that running
      `tests/testthat/test-nested-results-print.R` passes to a print or summary
      method, no call to `print.nested_results()` or
      `print.summary.nested_results()` raises, and none warns except where AC3
      requires it. That run is the sweep; the claim is over what it covers.
- [ ] AC6. Each of the three methods this milestone adds or changes —
      `print.nested_results()`, `summary.nested_results()`,
      `print.summary.nested_results()` — has a roxygen `@return` clause naming
      what it returns, verified by reading the three blocks in
      `R/nested-results-print.R`.
- [ ] AC7. `cairn/PROFILE.md`'s `verify` slot is clean, and its fuller
      pre-review check (`check-r-package`) passes.

## Coverage

- AC1 → T2
- AC2 → T1
- AC3 → T1
- AC4 → T3
- AC5 → T4
- AC6 → T5
- AC7 → T4, T5

## Tasks

- [ ] T1. `summary.nested_results()` returning a classed object, and
      `print.summary.nested_results()` rendering it: move `print_design()`,
      `print_failures()`, `print_selection()`, `print_estimate()` and the IP3
      sentence (`R/nested-results-print.R:71-76`) behind them, and route
      `warn_partial_summary()` (`R/nested-results.R:789`) to the summary
      request without its `check_any_completed()` sibling.
- [ ] T2. Rewrite `print.nested_results()` (`R/nested-results-print.R:60`) to
      the AC1 shape: strip the subclass and dispatch for the rows, keep
      `print_candidate_sets()`, add the failure count and the `summary()`
      pointer.
- [x] T3. Fix the fold-label defect in the relocated failure section for all
      three record forms (M38 review O8), at `fold_ids()`
      (`R/nested-results.R:835`) or at its caller.
- [ ] T4. Re-point `tests/testthat/test-nested-results-print.R`'s 18 blocks
      onto the print/summary split, add the AC3 and AC4 blocks, re-record
      `tests/testthat/_snaps/nested-results-print.md`.
- [ ] T5. Roxygen and `@return` for the three methods, NAMESPACE, `NEWS.md`,
      `_pkgdown.yml` reference index. D-037 is already recorded.

## Work log

- 2026-08-31: created by /milestone-plan.
- 2026-08-31: criteria audit ran in FULL mode (user-facing tier), twice. Pass 1 returned findings on 7 of 7 drafted criteria; three escalated to the gate (DESIGN.md:121-123's disagreement convention, the RR02 Q7 bullets on `nested_final_fit`, D-034's Suggests placement of tibble) and the rest fixed in place. Pass 2 over the post-gate revision returned findings on 7 of 8, all with one clear answer and all fixed: wrong line citations in AC2/AC5, a double-emitted disagreement line, an undecided zero-completed case in AC3, a proxy domain in AC5, a third unprobed record form in AC6, an instrument-bound AC7, and a miscount plus a non-verifying `R CMD check` clause in AC8.
- 2026-08-31: plan gate chose relying on dplyr's transitive load of tibble over moving tibble to Imports, because dplyr is already in Imports and loading it loads tibble's namespace (verified this session: a class-stripped print renders `# A tibble: 3 x k`), so the declaration buys no install-time guarantee D-034 did not already have; falsified by dplyr dropping tibble from its own Imports, or by a print rendering as a data frame in any supported configuration.
- 2026-08-31: plan gate chose leaving `print.nested_final_fit()` untouched over splitting its bullets into `summary()`, because the object holds no rows to reveal so topepo's stated complaint does not reach it, and the bullets are RR02 Q7's recorded answer; falsified by a user report that the final-fit print is itself crowded, or by topepo asking for the split explicitly.
- 2026-08-31: two sizing tripwires fired on the single-milestone draft (9 acceptance criteria against the >~7 mark, and the `nested_final_fit` task shippable on its own), so the `summary.nested_final_fit()` half was split into M40 with `Depends on: M39` rather than compressed; nothing was discarded.
- 2026-08-31: plan gate chose keeping one disagreement line in `print()` over a tune-exact print, because DESIGN.md:121-123 records surfacing fold disagreement in default output as a convention and no D-entry supersedes it; falsified by evidence that the line crowds the default output, which DESIGN.md:209-212 already names as the trade.
- 2026-08-31: implementation gate chose the shared `fold_ids()` as the fallback site over a print-path-only repair; recorded in Decisions with its out-of-scope consequence.
- 2026-08-31: minor amendment, task order — T3 runs first (independent of the split and leaves the suite green), then T1, then T2 and T4 in one commit because T2's rewrite invalidates the print blocks T4 re-points and the verify slot must be clean at each check-off, then T5. No task's content changed.
- 2026-08-31: T3 done. `fold_ids()` (`R/nested-results.R`) falls back to `paste("row", seq_len(nrow(x)))` when the recorded `id_columns` is empty or names any column the object no longer carries; measured before the fix, the three forms gave `character(0)`, `NULL` and the truncated `"Repeat1, "`. Four new assertions plus a passing control in `tests/testthat/test-id-columns.R`, red before and green after. Suite: 2334 pass, 0 fail, 0 warn, 0 skip.
- 2026-08-31: plan chose fixing M38 review O8 here over leaving it to the `check_nested()` row, because this milestone relocates `print_failures()` and the M33 lesson is that a move invalidates every `file:line` citation the repo's records hold; falsified by the fix proving to need `check_nested()`'s entry-gate refusal to be coherent.

## Decisions

### Where the unusable-label-record fallback lives

`fold_ids()` itself falls back to row positions, so every caller of it gets the
repair, not only the print and summary path. Chosen at the implementation gate
over a second fallback on the print path alone: `fold_ids()` is the one place
the class answers "what are the fold labels", and a second answer beside it is
the duplication the recorded `id_columns` attribute was introduced to remove.

Consequence, stated because Scope puts these callers Out: the four sites Scope
names — `warn_partial_summary()`, `per_fold_metrics()`,
`plot_selection_frequency()`'s fold levels and `nested-tune-grid.R`'s failure
list — stop raising or emitting a truncated label on such an object as a side
effect, earlier than the `check_nested()` candidate row planned. No work is
done at those sites and none of them is tested here; the candidate row keeps
the entry-gate refusal it owns.

## Review
