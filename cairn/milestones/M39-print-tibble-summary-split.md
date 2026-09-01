<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M39: `print()` shows the object, `summary()` says what it means

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, IP4
- **Branch/PR:** `m039-print-tibble-summary-split` / https://github.com/tidymodels/nestedtune/pull/48

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

- [x] AC1. Printing a `nested_results` emits, in this order: a header naming
      the object; a line naming the outer resampling scheme when
      `attr(x, "outer_label")` is non-NULL, and no such line when it is NULL;
      the object's own rows, rendered by the print method its classes dispatch
      to once `nested_results` is removed from them; one line naming how many
      outer folds have `.completed` FALSE, emitted only when that count exceeds
      zero; the line `print_candidate_sets()` emits when `same_candidates()` is
      FALSE over the completed folds' `.grid`, and no such line when it is TRUE;
      and one line naming `summary()`. It emits no other line.
- [x] AC2. `summary()` on a `nested_results` returns an object of class
      `summary.nested_results`, and printing that object emits what
      `print_design()`, `print_failures()`, `print_selection()` and
      `print_estimate()` emit today, less `print_selection()`'s call to
      `print_candidate_sets()`, which AC1 keeps in `print()` and which this
      output does not repeat — together with the IP3 sentence
      `print.nested_results()` currently emits after `print_estimate()`.
- [x] AC3. `summary()` on a `nested_results` with at least one `.completed`
      FALSE signals a condition of class `nestedtune_partial_summary` and still
      returns its object; with every `.completed` TRUE it signals no condition.
      It never aborts, including where every fold failed — `collect_metrics()`'s
      `check_any_completed()` abort is not inherited, because a description of a
      failed run is what M04 built and M03 recorded.
- [x] AC4. Where a `nested_results`' recorded `id_columns` cannot label its
      rows, `print(summary())` names each failed fold by its row position
      rather than raising or emitting a truncated label, and `print()` on the
      same object raises nothing, over the objects the AC4 block in
      `tests/testthat/test-nested-results-print.R` builds for the three forms
      the record takes: an attribute of length zero; one naming a column the
      object no longer carries; and one naming several columns of which some
      are absent — the third being the form `fold_ids()` answered wrongly
      before this milestone rather than raising. Those objects are the domain;
      the claim is over them.
- [x] AC5. Over the objects that running
      `tests/testthat/test-nested-results-print.R` passes to a print or summary
      method, no call to `print.nested_results()` or
      `print.summary.nested_results()` raises, and none warns except where AC3
      requires it. That run is the sweep; the claim is over what it covers.
- [x] AC6. Each of the three methods this milestone adds or changes —
      `print.nested_results()`, `summary.nested_results()`,
      `print.summary.nested_results()` — has a roxygen `@return` clause naming
      what it returns, verified by reading the three blocks in
      `R/nested-results-print.R`.
- [x] AC7. `cairn/PROFILE.md`'s `verify` slot is clean, and its fuller
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

- [x] T1. `summary.nested_results()` returning a classed object, and
      `print.summary.nested_results()` rendering it: move `print_design()`,
      `print_failures()`, `print_selection()`, `print_estimate()` and the IP3
      sentence (`R/nested-results-print.R:71-76`) behind them, and route
      `warn_partial_summary()` (`R/nested-results.R:789`) to the summary
      request without its `check_any_completed()` sibling.
- [x] T2. Rewrite `print.nested_results()` (`R/nested-results-print.R:60`) to
      the AC1 shape: strip the subclass and dispatch for the rows, keep
      `print_candidate_sets()`, add the failure count and the `summary()`
      pointer.
- [x] T3. Fix the fold-label defect in the relocated failure section for all
      three record forms (M38 review O8), at `fold_ids()`
      (`R/nested-results.R:835`) or at its caller.
- [x] T4. Re-point `tests/testthat/test-nested-results-print.R`'s 18 blocks
      onto the print/summary split, add the AC3 and AC4 blocks, re-record
      `tests/testthat/_snaps/nested-results-print.md`.
- [x] T5. Roxygen and `@return` for the three methods, NAMESPACE, `NEWS.md`,
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
- 2026-08-31: implementation gate chose a returned bundle of computed pieces over a thin wrapper recomputing at print time; recorded in Decisions, and it binds M40's mirror.
- 2026-08-31: T1 done. `summary.nested_results()` and `print.summary.nested_results()` added in `R/nested-results-print.R`; the four section builders now read from the bundle `new_summary_nested_results()` computes, and `warn_partial_summary()` routes to `summary()` without `check_any_completed()`. `print.nested_results()` renders through the same bundle and its output is unchanged at this task — the existing snapshot passing un-rerecorded is the control. Six new blocks in `tests/testthat/test-nested-results-print.R`. Suite: 2366 pass, 0 fail, 0 warn, 0 skip.
- 2026-08-31: T2 and T4 done in one commit, as the reorder line above records. `print.nested_results()` now emits header, outer-scheme line when the object names one, the rows (class stripped, rendered through `cli::cli_verbatim()` so the method writes to one stream), the not-completed count when it exceeds zero, the candidate-set line, and the `summary()` pointer — and nothing else. `tests/testthat/test-nested-results-print.R` regrouped into print blocks, summary blocks, the AC4 record-form block and the shape block; snapshot deleted and re-recorded (4 print shapes, 5 summary shapes). Suite: 2398 pass, 0 fail, 0 warn, 0 skip.
- 2026-08-31: T5 done. Roxygen rewritten for `print.nested_results()` and authored for the summary pair, each with its own `@return`; `NAMESPACE` and `man/` regenerated; three `NEWS.md` entries; `summary.nested_results` added to `_pkgdown.yml` (the print method rides its alias, and `check_pkgdown()` finds no problems). Two prose claims the split falsified were corrected where they sit: `cairn/DESIGN.md`'s convention line, which said print methods carry the procedure sentence, and `vignettes/nested-cv.Rmd`, which said the print method had summarized the selections — the vignette now shows `summary(res)` beside `res`. `R CMD check`: 0 errors, 0 warnings, 0 notes.
- 2026-08-31: all five tasks checked; status to review. Suite 2398 pass / 0 fail / 0 warn / 0 skip; `devtools::check()` 0 errors, 0 warnings, 0 notes; `pkgdown::check_pkgdown()` no problems.
- 2026-08-31: plan chose fixing M38 review O8 here over leaving it to the `check_nested()` row, because this milestone relocates `print_failures()` and the M33 lesson is that a move invalidates every `file:line` citation the repo's records hold; falsified by the fix proving to need `check_nested()`'s entry-gate refusal to be coherent.

- 2026-08-31: review ran on PR #48. `origin/main` was already merged into the branch's base (0 commits behind), so no re-merge was needed. Six criteria verified with fresh evidence and ticked: AC1 over four objects covering its four switches, AC2 and AC3 over the summary pair, AC5 over an instrumented run of `test-nested-results-print.R` (27 blocks, 127 assertions, 58 print-method calls, 0 warnings), AC6 by reading the three roxygen blocks, AC7 against the five green `check-r-package` legs. `cairn_validate.py` exit 0; `document()` no diff; `check_pkgdown()` no problems; `cairn_impact.py` skipped, no IP/GP principle changed.
- 2026-08-31: a local `devtools::check()` reports one error, `test-parallel-interrupt.R:102`. Not this branch's: the identical assertion fails with the identical message in a detached worktree at `origin/main`, the test file is untouched by the diff, it passes standalone twice and under `devtools::test()`, and all five CI legs are green. Recorded rather than fixed.
- 2026-08-31: three-lens review fan-out. Blame-history and prior-review returned no findings. Diff-bug returned nine, all logged with dispositions in the Review section: one rejected as already-true prose, one rejected as pre-existing, two to follow-up rows, three fix-now carried back with this return, one put to the maintainer, and one returning the milestone.
- 2026-08-31: amendment return: AC4 — "`print()` and `print(summary())` name each failed fold by its row position rather than raising or emitting a truncated label". AC1 requires `print()` to emit a count of incomplete folds and no line naming any fold, so post-split `print()` never calls `fold_ids()` and names no fold by any label; the two criteria contradict each other and the work follows AC1. Status to in-progress for that amendment alone.
- 2026-08-31: criteria audit ran in FULL mode over the amended AC4 wording, twice, each pass a fresh-context reader that did not author it. Pass 1 returned five findings; three with one clear answer were fixed in place (the object domain was unbounded and the milestone's own review finding O7 names an object inside it on which `print()` raises; both "today" anchors were already false, T3 having fixed the form AC4 called wrong; the conditional AC2 draft was offered pre-ticked while requiring unwritten work), and two thoroughness findings were declined. Pass 2 over the revision returned three more with one clear answer, all fixed: "warns nothing" bound a property the pre-amendment AC4 did not, AC5 already promising it over a superset domain; the trailing domain phrase read as evidence rather than scope without AC5's disambiguating sentence; and the conditional AC2 draft still compared against `origin/main`'s output on the very objects AC4's fallback changes.
- 2026-08-31: amendment return: AC4 — "Where a `nested_results`' recorded `id_columns` cannot label its rows, `print(summary())` names each failed fold by its row position rather than raising or emitting a truncated label, and `print()` on the same object raises nothing, over the objects the AC4 block in `tests/testthat/test-nested-results-print.R` builds for the three forms the record takes: an attribute of length zero; one naming a column the object no longer carries; and one naming several columns of which some are absent — the third being the form `fold_ids()` answered wrongly before this milestone rather than raising. Those objects are the domain; the claim is over them." Chosen at the mini gate over rewording it differently or leaving it; the box stays unticked for review to verify afresh. No task changed and Coverage still reads AC4 → T3.
- 2026-08-31: mini gate chose logging M39 review O1 as a candidate row over repairing the `x$.notes` pointer here, because the repair falsifies AC2 as written and this milestone had already returned once for a wrong promise; AC2 stands ticked and unamended, and the drafted AC2 amendment is not written.
- 2026-08-31: review findings O3, O5 and O9 fixed as carried: `print_candidate_sets()`'s comment now describes the caller `print.nested_results()` gives it rather than the selection lines that moved behind `summary()`; `summary.nested_results()`'s `@return` names `outer_label` and `grids`, the two components it returns and the clause omitted; and both `[summary()]` links plus `print.nested_results()`'s `@seealso` now point at `[summary.nested_results()]` rather than resolving to `base::summary`.
- 2026-08-31: amendment done; status back to review. Suite 2398 pass / 0 fail / 0 warn / 0 skip; `devtools::document()` regenerated the two `man/` pages the roxygen fixes touched and nothing else.
- 2026-09-01: re-review gate failed. `cairn_validate.py` exits 1 on `weight caps`: `cairn/ROADMAP.md` is 60 lines against the cap of <60, pushed over by the one candidate row this branch adds for review finding O1 on a file that was at 59 on `origin/main`. Every acceptance criterion was re-driven fresh at `e285b64` first and all seven hold, AC4 among them under its amended wording, so the return is the cap alone; the remedy is the graduate-or-prune one the cap's own rule states, and the three-lens fan-out was not reached. Status to in-progress.
- 2026-09-01: the cap gate cleared. The four published-site candidate rows in `cairn/ROADMAP.md` — the Node-20 SHA pins, the deploy job no pull request can exercise, the two-name site-hygiene list and the `/dev/` mode question — were grouped into one row keeping every promotion trigger, chosen at the gate over pruning the measured-false CI-matrix row or dropping this branch's own O1 row; 60 lines to 57, 42,710 B to 42,328, nothing discarded. `cairn_validate.py` now exits with all checks passed. Suite 2398 pass / 0 fail / 0 warn / 0 skip, unchanged, and no R source, roxygen or test file was touched. Status back to review.

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

### The shape `summary()` returns

`summary.nested_results()` returns a list of class `summary.nested_results`
holding the pieces its printing renders — `requested`, `completed`,
`failures` (id and stage per failed fold), `selection` (one character vector
per tuned parameter, one entry per completed fold), `grids` and `estimate` —
computed once by `new_summary_nested_results()`. Chosen at the implementation
gate over a thin wrapper around the results object that recomputes at print
time: a caller reaching for a number gets one without re-deriving it, and the
selection-frequency candidate row has something to build on. M40 mirrors this
shape for `nested_final_fit`.

Correcting the entry above, which named a function this package does not have:
the plot-side caller of `fold_ids()` is `selection_frame()`
(`R/nested-results-plot.R`) and the fold-level factor beside it, not
`plot_selection_frequency()`. Nothing else in that entry changes.

## Review

Fresh evidence gathered 2026-08-31 on `m039-print-tibble-summary-split` at
`db159f0`, against PR #48. Every figure below is from a command run this
session; the scripts live in the session scratchpad and each is described by
what it did rather than pasted.

### Acceptance criteria

- AC1 — **verified.** Drove `print()` over four hand-built `nested_results`
  covering the criterion's four switches and read back every emitted line via
  `cli::cli_fmt()`. Label present + all completed + equal grids: header,
  `Outer resamples:` line, the tibble rows (`# A tibble: 2 x 6` and two data
  rows, so the class strip dispatches to tibble's method), the `summary()`
  pointer — four items, no failure count, no candidate line. `outer_label`
  NULL: identical less the `Outer resamples:` line. One fold not completed:
  adds `1 of 2 outer folds did not complete.` between rows and pointer.
  Differing grids: adds `Candidates searched: 3 5 - the folds did not search
  the same grid` in the same slot. No line outside the enumeration appeared in
  any of the four.
- AC2 — **verified.** `class(summary(x))` is `summary.nested_results`.
  Printing it emits the four M04 sections in order — `Outer folds: n
  requested, m completed`; the per-fold `... failed during <stage>.` lines
  plus the `x$.notes` pointer; the `Selected parameters` heading and its
  lines; the `Estimate (m of n outer folds)` heading and its metric lines —
  followed by the procedure sentence naming `nested_final_fit()`. On the
  differing-grids object whose `print()` emitted the candidate line, the
  summary output does not repeat it: the disagreement line appears once in the
  pair, in `print()`.
- AC3 — **verified.** With one fold not completed, `summary()` signals a
  condition of class `nestedtune_partial_summary` / `rlang_warning` /
  `warning` / `condition` and, with the warning muffled, still returns an
  object of class `summary.nested_results`. With every fold completed, an
  instrumented handler counting every non-message condition counted 0. With
  every fold failed it returned a `summary.nested_results` rather than
  aborting, and printing it emits `0 completed`, both failure lines, `No outer
  fold completed, so nothing was selected.` and `... so there is no estimate.`
- AC4 — **not verified; the criterion is wrong (amendment return).** Built the
  three record forms on an object with one failed fold: a length-zero
  `id_columns`, one naming a column the object does not carry, and one naming
  two columns of which one is absent. In all three, `print(summary())` named
  the failed fold `row 2` and the control with a usable record still named it
  `Fold2`, so the fallback fires on the unusable record and not otherwise —
  the `print(summary())` half holds. The `print()` half does not, and cannot:
  AC4 requires `print()` to "name each failed fold by its row position", while
  AC1 requires `print()` to emit a *count* of incomplete folds and no line
  naming any fold. Post-split `print()` never calls `fold_ids()` at all, so it
  names no fold by any label. The two criteria contradict each other; the work
  follows AC1, which is the right behaviour, and AC4's `print()` clause is the
  defect. Measured, not reinterpreted: `print()` on all three forms raised
  nothing and warned nothing, and the AC4 test block
  (`test-nested-results-print.R:558-560`) asserts only `expect_no_error()` and
  `expect_no_warning()` for `print()`, doing its naming assertion on
  `summary_text()`. Ticking this box would require reading "name each failed
  fold by its row position" as "does not raise", which is the charitable
  reading the never-reinterpret rule forbids. Routed to a gated criterion
  amendment; see the work-log line.
- AC5 — **verified over the criterion's domain.** Wrapped both print methods
  with a handler recording every condition, then ran
  `tests/testthat/test-nested-results-print.R` with `NOT_CRAN=true`: 27 blocks,
  127 passing assertions, 0 failures, 0 errors, 0 skips; 58 calls into the two
  methods intercepted. Zero warnings from either method. One raise was
  recorded, and it is not over an object in the criterion's domain: it is the
  `check_dots_empty()` abort that `test-nested-results-print.R:441-443` asserts
  with `expect_error()` on `print(summary(res), foo = 1)` — a rejected `...`
  argument, not an object the file passes to a print method. No call over an
  object raised.
- AC6 — **verified by reading the three roxygen blocks in
  `R/nested-results-print.R`.** `print.nested_results()` at line 37: "`x`,
  invisibly." `summary.nested_results()` at line 130: "An object of class
  `summary.nested_results`: a list holding the outer design's requested and
  completed fold counts, the failed folds with the stage each failed at, the
  parameter values the completed folds selected, and the metric estimates
  averaged across them." `print.summary.nested_results()` at line 150:
  "`print()` returns `x`, invisibly."
- AC7 — **verified.** The `verify` slot is clean: `devtools::document()`
  produced no diff (the only modified path afterwards is this milestone file),
  and `devtools::test()` exited 0. The fuller pre-review check the criterion
  names, `check-r-package`, is the `r-lib/actions/check-r-package@v2` step at
  `.github/workflows/R-CMD-check.yaml:119`, and it passes on all five legs of
  PR #48 — ubuntu devel (9m48s), ubuntu release (8m54s), ubuntu oldrel-1
  (9m7s), macOS release (8m13s), Windows release (10m59s) — alongside pkgdown,
  test-coverage, codecov and format-suggest, all green.

  Recorded because it looks like a failure and is not: a local
  `devtools::check()` on this machine reports `1 error | 0 warnings | 0 notes`,
  the error being `test-parallel-interrupt.R:102` ("an interrupted run leaves
  no fold executing", `interrupted` FALSE where TRUE was expected). It is not
  this branch's. The same check run in a detached worktree at `origin/main`
  fails the identical assertion with the identical message
  (`1 error | 0 warnings | 1 note` there, so the branch is a note better), and
  the test file is untouched by the diff. It also passes standalone under
  `test_file()` twice and under `devtools::test()`, so it reproduces only in
  this machine's `R CMD check` subprocess, where the test signals `SIGINT` to
  its own pid. CI runs the same check on five platforms and none of them sees
  it.

### Consistency gate

- `cairn_validate.py`: exit 0, all 16 PASS checks pass (`coverage complete` and
  `scaffold present` among them), 5 advisory OKs, one WARN — the same 18
  `references/` pages recording no verification claim, unchanged by this
  milestone. The `release window` advisory did not fire.
- `cairn_impact.py`: skipped. The milestone's `DESIGN.md` edit is a bullet in
  the conventions prose above the numbered blocks (the IP block starts at
  `DESIGN.md:154`), so no IP/GP principle changed.
- `devtools::document()`: no diff — the only modified path afterwards is this
  milestone file.
- `NAMESPACE` and `man/` regenerate from roxygen; the no-diff `document()` run
  above is that check.
- README.Rmd is present and untouched by the diff, so README.md cannot be out
  of sync with it.
- `pkgdown::check_pkgdown()`: "No problems found."
- `NEWS.md` carries three entries for this milestone's user-visible changes,
  naming no milestone numbers.
- No new top-level files, so no `.Rbuildignore` entry is owed.

### Independent fresh-context review

Surface tier is user-facing and the diff touches R sources, so the full
three-lens fan-out ran, each lens on its own evidence base.

- **[S] blame-history** — no findings. It traced the relocated M04 sections,
  the dropped `check_any_completed()` inheritance, the `fold_ids()` fallback,
  the moved candidate-set line and the Suggests placement of tibble back to the
  archived milestone, D-entry or acceptance criterion that anticipated each,
  and reported no contradiction of prior intent.
- **[S] prior-review** — no findings. It read the `## Review` sections of the
  M04, M36 and M38 archives and `LESSONS.md`, and confirmed the diff
  reintroduces none of M04's F1/F2/F3, none of M36's defects, and is the
  milestone doing M38's deferred O8 rather than regressing it. Its GitHub probe
  found one real inline comment in the repo's history, on an unrelated file;
  per-PR walks of #4, #22, #42, #45 and #47 returned empty.
- **[O] diff-bug** — nine ranked findings, below.

### Findings and disposition

Ranked as the reviewer ranked them. Every finding is recorded with its
disposition, including the rejected ones (IP3).

- **O1. `print(summary(x))` points the reader at `x$.notes`, which the printed
  object does not have.** `print_failures()` (`R/nested-results-print.R:236`)
  emits ``See `x$.notes` for what went wrong.`` Before the split the printed
  object was the results object and the advice was executable; the object bound
  to `x` in `print.summary.nested_results()` is the summary bundle, whose
  components are `outer_label`, `requested`, `completed`, `failures`,
  `selection`, `grids` and `estimate`. `s$.notes` is `NULL`. Confirmed in the
  AC2 evidence above, where the line appears in the summary output.
  `test-nested-results-print.R:377` asserts the line with
  `expect_match(txt, "See .*\\$\\.notes")`, so it passes on text that is now
  misleading. **Disposition: for the maintainer at the gate.** It is a real
  defect inside an intentional change, so the out-of-scope taxonomy does not
  cover it — but AC2 pins this output to "what `print_failures()` emits today",
  so repairing the sentence falsifies AC2 as written. Either the fix rides a
  second amended clause, or the finding becomes a follow-up row and AC2 stands.
- **O2. The `DESIGN.md` convention on selection instability was said to be
  stale.** **Disposition: rejected.** The bullet
  (`cairn/DESIGN.md:124-126`) reads "default print/summary surfaces
  disagreement between folds", naming both surfaces; after the split `summary()`
  surfaces selection disagreement and `print()` surfaces candidate-set
  disagreement, so the sentence is still true of the pair it names. The
  neighbouring bullet needed its M39 correction because it said "print methods"
  and named a sentence that moved; this one does not.
- **O3. `print_candidate_sets()`'s comment describes a context that no longer
  exists.** `R/nested-results-print.R:267-276` says the line is "printed here
  rather than in the design block because it qualifies the lines above it: a
  reader comparing what each fold selected is entitled to know...". In
  `print.nested_results()` there are no selection lines above it — those moved
  behind `summary()`. The comment was true of the caller it had and is false of
  the caller this diff gave it. **Disposition: fix now, carried to the return** (a comment rewrite, no
  behaviour change) — the amendment return below stops review before fix-now
  work is committed, so it travels back to `/milestone-implement` with it.
- **O4. AC4's `print()` clause contradicts AC1 and cannot be satisfied.**
  **Disposition: amendment return** — see the AC4 evidence line above and the
  work-log line. This is the finding that returns the milestone.
- **O5. `summary()`'s `@return` omits two components it returns, one of which
  nothing reads.** `R/nested-results-print.R:129-135` enumerates the counts,
  failures, selections and estimates; the bundle also carries `outer_label`
  (`:177`) and `grids` (`:185`). Confirmed by grep that `$grids` is read nowhere
  under `R/` — `print.nested_results()` computes the candidate-set line from
  `x$.grid[x$.completed]` directly (`:71`). The milestone's Decisions section
  lists `grids` as deliberate forward-looking state for the
  selection-frequency candidate row, so it is not dead by accident.
  **Disposition: fix now, carried to the return** (complete the `@return`;
  AC6 is satisfied either way, since it asks for a clause naming what is
  returned and one is present).
- **O6. `utils::capture.output()` is used with `utils` undeclared in
  DESCRIPTION.** `R/nested-results-print.R:91`. The reviewer verified this does
  not trip `R CMD check`, because `tools:::.check_packages_used` excludes
  standard packages, and the check evidence below agrees. **Disposition:
  follow-up** — adding `utils` to Imports is a dependency change, and
  tracking-rules makes any dependency change a question gate plus a D-entry,
  which is not review-side work.
- **O7. `print()` raises on an `NA` in `.completed`.** `sum(!x$.completed)` is
  `NA` and `if (failed == 0L)` errors. **Disposition: rejected as
  out-of-scope** — the reviewer confirmed `main` raises on the same input at
  `print_estimate()`, so the diff did not introduce it; it is a pre-existing
  issue, and the same object shape is what the `check_nested()` candidate row
  already owns.
- **O8. Four print snapshots are now pinned to pillar's exact table
  rendering.** A pillar or tibble release that changes column widths or the
  `# i N more variables:` line breaks four snapshots for reasons outside this
  package, and D-037's stated falsifier covers tibble disappearing rather than
  tibble reformatting. **Disposition: follow-up** — it is the accepted cost of
  D-037 and belongs on a candidate row as a maintenance tripwire, not in this
  milestone.
- **O9. The `@return`/description links to `summary()` resolve to
  `base::summary`.** `R/nested-results-print.R:24` and `:29` write `[summary()]`,
  which renders as `\link[=summary]{summary()}`, and
  `print.nested_results()`'s `@seealso` (`:61`) lists only `nested_tune_grid()`
  and `collect_metrics()`. Discoverability of the new method is the premise of
  the split. **Disposition: fix now, carried to the return** (point both at
  `[summary.nested_results()]` and add it to `@seealso`).

### Outcome

Six of seven criteria verified with fresh evidence and ticked. AC4 is not
ticked: the criterion as written contradicts AC1, and the work follows AC1.
That is evidence about the promise rather than about the work, so the milestone
returns for a gated criterion amendment (`/milestone-implement` step 6) and
re-review, and the merge gate is not reached. No merge approval was requested
and none was given.

### Round 2 — re-review after the AC4 amendment

Fresh evidence gathered 2026-09-01 at `e285b64`, against PR #48. `origin/main`
was 0 commits behind, so no re-merge was needed. The amendment commit's only
source change is documentation and comments (`git diff db159f0..HEAD --
R/nested-results-print.R` touches roxygen text, a `@seealso` list and one
internal comment), so every criterion was re-driven against it rather than
inherited from round 1.

- AC1 — **verified.** Re-drove `print()` over the same four objects covering
  the criterion's four switches, reading back every line via `cli::cli_fmt()`.
  Label + all completed + equal grids: header, `Outer resamples: 3-fold
  cross-validation`, `# A tibble: 3 x 9` and three data rows, the `summary()`
  pointer. `outer_label` NULL: identical less that line. One fold not
  completed: adds `1 of 3 outer folds did not complete.` between rows and
  pointer. Differing grids (`same_candidates()` FALSE, checked): adds
  `Candidates searched: 5, 5, 5 - the folds did not search the same grid` in
  the same slot. No line outside the enumeration in any of the four.
- AC2 — **verified.** `class(summary(x))` is `summary.nested_results`. Printing
  it emits the four M04 sections in order plus the procedure sentence naming
  `nested_final_fit()`. On the differing-grids object, whose `print()` emitted
  the candidate line, the summary output does not repeat it.
- AC3 — **verified.** One fold not completed: the only condition signalled is
  class `nestedtune_partial_summary`, and the call still returns a
  `summary.nested_results`. Every fold completed: an instrumented handler
  counting every non-message condition counted 0. Every fold failed: returned a
  `summary.nested_results` rather than aborting, printing `0 completed`, three
  failure lines, `No outer fold completed, so nothing was selected.` and `...
  so there is no estimate.`
- AC4 — **verified over the criterion's stated domain.** Built the three record
  forms the AC4 block builds, on an object with one failed fold. In all three,
  `print()` raised nothing and `print(summary())` named the failed fold `row 2`
  with no truncated `Fold1, ` label. The passing control with the record the
  constructor writes named it `Fold2` and never said `row 2`, so the fallback
  is reached by the record being unusable rather than by every object.
- AC5 — **verified over the criterion's domain.** Wrapped both print methods
  with a condition-recording handler and ran
  `tests/testthat/test-nested-results-print.R` under `NOT_CRAN=true`: 27
  blocks, 127 passing assertions, 0 failures, 0 errors, 0 skips; 58 calls into
  the two methods intercepted; 0 warnings. One raise, and not over an object in
  the domain: the `check_dots_empty()` abort the file asserts with
  `expect_error()` on `print(summary(res), foo = 1)`, a rejected argument.
- AC6 — **verified by reading the three roxygen blocks in
  `R/nested-results-print.R`.** `@return` at `:38` ("`x`, invisibly."), at
  `:132` (the `summary.nested_results` bundle, now naming the outer label and
  the per-fold candidate grid the amendment added) and at `:153` ("`print()`
  returns `x`, invisibly.").
- AC7 — **verified.** `devtools::document()` produced no diff;
  `devtools::test()` ran 2398 pass / 0 fail / 0 warn / 0 skip. The
  `check-r-package` legs on PR #48 at `e285b64`: ubuntu release, ubuntu
  oldrel-1 and macOS release green, ubuntu devel and Windows release still
  pending at the time of this gate failure (pkgdown, test-coverage, codecov and
  format-suggest all green). The two pending legs are the one part of AC7 this
  round did not see finish; the amendment commit changed only documentation and
  comments.

Toolchain consistency-gate checks all pass: `document()` no diff (so `NAMESPACE`
and `man/` are not hand-edited), README.Rmd untouched by the diff,
`pkgdown::check_pkgdown()` "No problems found.", three `NEWS.md` entries naming
no milestone numbers, no new top-level files.

**Universal cairn-file check fails, and the milestone returns.**
`cairn_validate.py` exits 1 on `weight caps`: `cairn/ROADMAP.md` is 60 lines
against a cap of <60. The branch is what pushed it over — `git diff
origin/main..HEAD -- cairn/ROADMAP.md` adds exactly one line, the candidate row
this milestone filed for review finding O1, on a file that was at 59 of 60 on
`origin/main`. Every other check passes (16 PASS, `coverage complete` and
`scaffold present` among them; the only advisory is the standing 18
`references/` pages recording no verification claim, unchanged here, and the
`release window` advisory did not fire). `cairn_impact.py` skipped: no IP/GP
principle changed. The three-lens fan-out was not reached; the gate stops
review before it.
