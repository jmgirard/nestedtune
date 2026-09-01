<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M40: A `nested_final_fit` answers `summary()` the way its sibling does

- **Status:** review
- **Priority:** normal
- **Depends on:** M39
- **Driving RR:** —
- **Principles touched:** IP3
- **Branch/PR:** `m040-final-fit-summary` / [#49](https://github.com/tidymodels/nestedtune/pull/49)

## Goal

`summary()` on a `nested_final_fit` returns the same shape of object M39 gave
`nested_results`, so both halves of the API answer the generic.

## Scope

Surface tier: **user-facing** — both methods are exported API and their output
is what a user meets.

**In:** `summary.nested_final_fit()` returning a classed object and
`print.summary.nested_final_fit()` rendering it, mirroring the shape M39 fixed;
roxygen, NAMESPACE, NEWS, `_pkgdown.yml`; tests and snapshot.

**Out:** `print.nested_final_fit()` is untouched — the object holds no rows to
reveal, so topepo's complaint in
[#34](https://github.com/tidymodels/nestedtune/issues/34) does not reach it, and
its bullets are RR02 Q7's recorded answer under the DESIGN convention at
`cairn/DESIGN.md:117-120`. Reopening that → a candidate row, on evidence the
final-fit print is itself crowded. `predict()`/`augment()` methods on the class
→ the existing M05 candidate row, which D-014 already answered.

## Acceptance criteria

- [x] AC1. `print.nested_final_fit()` emits byte-identical output before and
      after this milestone for the objects
      `tests/testthat/test-nested-final-fit-print.R` constructs.
- [x] AC2. `summary()` on a `nested_final_fit` returns an object of class
      `summary.nested_final_fit` whose printing names the selected parameters
      and states where the model's honest estimate comes from.
- [x] AC3. The text `print.summary.nested_final_fit()` emits contains none of
      the `mean` and `std_err` values `tune::collect_metrics(x$tuning)`
      reports, at the digit precisions the scan at
      `tests/testthat/test-nested-final-fit-print.R:30-53` applies.
- [x] AC4. Both methods this milestone adds — `summary.nested_final_fit()` and
      `print.summary.nested_final_fit()` — have a roxygen `@return` clause
      naming what they return, verified by reading the two blocks in
      `R/nested-final-fit-print.R`.
- [x] AC5. `cairn/PROFILE.md`'s `verify` slot is clean, and its fuller
      pre-review check (`check-r-package`) passes.

## Coverage

- AC1 → T3
- AC2 → T1
- AC3 → T1, T3
- AC4 → T2
- AC5 → T2, T3

## Tasks

- [x] T1. `summary.nested_final_fit()` + `print.summary.nested_final_fit()` in
      `R/nested-final-fit-print.R`, reusing `selected_label()`
      (`R/nested-final-fit-print.R:57`) and the object shape M39 established.
- [x] T2. Roxygen and `@return`, NAMESPACE, `NEWS.md`, `_pkgdown.yml`
      reference index.
- [x] T3. Extend `tests/testthat/test-nested-final-fit-print.R` with the
      summary blocks and the AC1 byte-identity assertion; re-record
      `tests/testthat/_snaps/nested-final-fit-print.md`.

## Work log

- 2026-08-31: created by /milestone-plan, split out of M39 when two sizing tripwires fired on the single-milestone draft (9 acceptance criteria against the >~7 mark, and this half shippable on its own).
- 2026-08-31: criteria audit ran in FULL mode (user-facing tier) as part of M39's two passes, which read these criteria in their M39 numbering (AC4, AC5). Pass 2 returned two findings on them, both fixed here: AC5's promise quantified over "any number in the stored tuning run" where the named scan enumerates only `mean` and `std_err` of `collect_metrics()`, and it bound a returned object where the scan reads printed text. The citation was corrected from `:29-52` to `:30-53`.
- 2026-09-01: implement question gate chose mirroring M39's component shape for the summary object (`tuning_label`, `candidates`, `selection`, `estimate = NULL`) over a selection-only object or one also carrying the workflow, so both halves of the API answer `summary()` with objects a caller reads the same way; and the shared-`@rdname` topic layout with usage-labelled `@return` clauses ("`summary()` returns …", "`print()` returns …") plus an `@examplesIf` block, which mirrors M39's page structure without repeating its two unlabelled `\value` paragraphs. M39's own pages are untouched, staying with their ROADMAP candidate row.
- 2026-09-01: T1 — `summary.nested_final_fit()` and `print.summary.nested_final_fit()` in `R/nested-final-fit-print.R`. `selected_label()` now renders from `summary_final_selection()`, the same extraction the summary object stores, so `print()` and `summary()` cannot come to describe one selection differently; its output is unchanged. `tuning_scheme_label()` takes `pretty()` on `x$tuning` under the same `tryCatch` guard `outer_scheme_label()` uses (measured: "3-fold cross-validation"), and the candidate count comes from `scored_candidates()`, which swallows its own errors by construction — so neither print path can raise. `devtools::test()` clean: FAIL 0, WARN 0, SKIP 0, PASS 2400.
- 2026-09-01: T2 — roxygen with usage-labelled `@return` clauses on both new methods (verified in `man/summary.nested_final_fit.Rd:21-29`, which renders "`summary()` returns …" and "`print()` returns …" as separate paragraphs), NAMESPACE regenerated by `devtools::document()` (`S3method(summary,nested_final_fit)`, `S3method(print,summary.nested_final_fit)`), a `NEWS.md` entry, a `summary.nested_final_fit` row in `_pkgdown.yml`'s "The final model" section, and a `@seealso` link to the new topic from `print.nested_final_fit()`. `pkgdown::check_pkgdown()`: no problems found. `devtools::test()` clean: FAIL 0, WARN 0, SKIP 0, PASS 2400.
- 2026-09-01: T3 — five blocks appended to `tests/testthat/test-nested-final-fit-print.R` (the existing blocks, AC3's cited scan at :30-53 included, are untouched and unmoved). AC1 is pinned twice: the pre-existing `print()` snapshot block is a pure-insertion no-op against `main` (`git diff main -- tests/testthat/_snaps/nested-final-fit-print.md` shows 23 insertions, 0 deletions), and a new `PRINT_BEFORE_M40` literal asserts the 838 bytes the method emitted at d6ff85f under `local_reproducible_output()`. The literal exists because the snapshot is the artifact a print change would re-record, so accepting a new snapshot would satisfy a snapshot-pinned criterion and falsify the promise at once; the two captures were compared across a `main` worktree and this branch and were byte-identical. AC3's digit scan is re-run against the summary's printed text. A structure-built stub covers the no-tuned-parameters and no-`pretty()`-label branches without an engine. `devtools::test()` clean: FAIL 0, WARN 0, SKIP 0, PASS 2464 (up from 2400).
- 2026-09-01: all three tasks checked; `devtools::check()` clean (0 errors, 0 warnings, 0 notes; `Running 'testthat.R' [68s/110s] OK`) and `pkgdown::check_pkgdown()` reports no problems. Status set to review. No plan amendments were needed: every acceptance criterion is met as written.
- 2026-08-31: plan gate chose leaving `print.nested_final_fit()` untouched over splitting its bullets into `summary()`, because the object holds no rows to reveal so topepo's stated complaint does not reach it, and the bullets are RR02 Q7's recorded answer; falsified by a user report that the final-fit print is itself crowded, or by topepo asking for the split explicitly.

## Decisions

### The `estimate` component is carried and set to `NULL`

`summary.nested_final_fit` lists `estimate = NULL` rather than omitting the
name. A `nested_final_fit` has no performance estimate of its own (IP3), and
recording that positively is the habit IP4 asks of the loop: what is true is
written down, never left to be inferred from a name that is not there. It also
keeps the component list a shape-for-shape mirror of `summary.nested_results`,
so a caller reading either meets the same names.

Falsified by: a caller for whom the always-`NULL` name is a trap rather than a
record — e.g. code that tests `is.null(s$estimate)` to decide which summary
class it holds, where a missing name would have failed loudly instead.

## Review

Reviewed 2026-09-01 on `m040-final-fit-summary` against `main` at d6ff85f;
PR [#49](https://github.com/tidymodels/nestedtune/pull/49). Diffstat: 10 files,
433 insertions, 22 deletions.

### Acceptance criteria

- AC1 — met. `devtools::test()` clean (FAIL 0, WARN 0, SKIP 0, PASS 2464); the
  `AC1: printing a final fit is unchanged by summary() existing` block passes,
  comparing `print.nested_final_fit()` under `local_reproducible_output()`
  against the `PRINT_BEFORE_M40` literal captured at d6ff85f. Independently,
  `git diff main --numstat -- tests/testthat/_snaps/nested-final-fit-print.md`
  is 23 insertions, 0 deletions, so the pre-existing print snapshot was not
  re-recorded.
- AC2 — met. The `AC2: summary() returns a classed object naming what was
  selected` block passes: `expect_s3_class(s, "summary.nested_final_fit")`,
  component names `tuning_label`/`candidates`/`selection`/`estimate`,
  `s$candidates` read off `extract_scored_candidates()` rather than written
  out, and the printed text matching `num_comp: 3`, `no performance estimate of
  its own`, and `nested_tune_grid`.
- AC3 — met. The `AC3: the summary shows no number from the stored tuning run`
  block passes: it collects `tune::collect_metrics(final$tuning)`, asserts the
  value set is non-empty, and scans the summary's printed text for every `mean`
  and `std_err` at 3 to 6 digits — the same scan the existing print block at
  :30-53 applies.
- AC4 — met, by reading the two blocks in `R/nested-final-fit-print.R`.
  `summary.nested_final_fit()` (block ending :105) carries a `@return` naming
  the class and its four components; `print.summary.nested_final_fit()` (block
  ending :116) carries `@return` "`print()` returns `x`, invisibly." Both
  render as separate paragraphs in `man/summary.nested_final_fit.Rd`.
- AC5 — met. `verify` slot: `Rscript -e 'devtools::document()'` produces no
  diff and `Rscript -e 'devtools::test()'` is clean (FAIL 0, WARN 0, SKIP 0,
  PASS 2464). Fuller pre-review check: `Rscript -e 'devtools::check()'` is
  `Status: OK` — 0 errors, 0 warnings, 0 notes, duration 2m 36.1s, with
  `Running 'testthat.R' [70s/113s] OK`.

### Consistency gate

- `cairn_validate.py` exit 0, all checks PASS; 18 advisory warnings, all the
  standing `references staleness` ones, no `release window` advisory.
- No `DESIGN.md` principle changed by this diff, so `cairn_impact.py` does not
  apply.
- `r-package` profile `consistency-gate`: `devtools::document()` produces no
  diff; `pkgdown::check_pkgdown()` reports no problems; `NEWS.md` carries the
  milestone's user-visible entry; `README.Rmd`/`README.md` untouched by the
  diff; no new top-level files, so no `.Rbuildignore` entry is owed.

### Independent review

Three fresh-context reviewers, distinct evidence bases: an Opus diff-bug lens
over `git diff main..HEAD`, a Sonnet blame-history lens over the modified
lines' history, and a Sonnet prior-review lens over the archived `## Review`
sections touching these files. Blame-history reported no findings: the
`selected_label()` refactor preserves the `.config` drop and the M05 output,
`print.nested_final_fit()`'s body is untouched, and `tuning_scheme_label()`'s
omission of the class-stripping `outer_scheme_label()` does is correct because
`x$tuning` is a single-level `tune_results`. Prior-review reported no findings:
M34's `@param ...` wording, M22's `@return`-names-a-missing-component lesson and
its names-only-agreement-test lesson, and M39's bidirectional `@seealso` are all
honored rather than reintroduced; the GitHub inline-comment probe found one real
thread, on an unrelated workflow file, so the per-PR walk was skipped. The
diff-bug lens reported seven, ranked below with dispositions.

1. `summary(final)$selection` renders with `format()` where the sibling
   `selection_values()` (`R/nested-results-print.R:395`) uses `as.character()`,
   so the stored component is lossy and follows `options(digits)`. Confirmed
   directly: `0.0031622776601683794` stores as `"0.003162278"`, against the
   sibling's `"0.00316227766016838"`, and becomes `"0.00316"` under
   `options(digits = 3)`. A caller comparing the two summaries' selections
   gets a spurious mismatch on every continuous parameter.
   **Recommended disposition:** fix now — render the stored scalars with
   `as.character()`, mirroring the sibling, while `selected_label()` keeps
   `format()` so `print.nested_final_fit()` stays byte-identical, plus a
   regression test over a continuous parameter. Not a return-floor finding: no
   acceptance criterion binds the component's precision.
2. `print_final_estimate()` never reads `s$estimate`, so a hand-built object
   holding a value would still print the no-estimate sentence, and the stub
   test's `estimate = NULL` assertion proves nothing.
   **Recommended disposition:** reject — the component is `NULL` by construction for
   every object `summary.nested_final_fit()` can produce (the milestone's own
   Decisions section), so there is no value for the method to read; the
   hand-built counterexample is not a reachable state.
3. `tuning_scheme_label()` catches `error` but not `warning`, where the file's
   comment says nothing here raises.
   **Recommended disposition:** reject — a warning is not a raise, so the comment is
   accurate as written; the class-stripping difference from
   `outer_scheme_label()` is correct for a single-level object, as the
   blame-history lens independently found.
4. AC2's test asserts `s$selection` only for `num_comp`, an integer, the one
   type where `format()` and `as.character()` agree, so finding 1 was
   invisible to the suite.
   **Recommended disposition:** fix with finding 1 — a test exercising a
   continuous value, shown red against the `format()` rendering first.
5. All five acceptance-criterion boxes were unticked while the status read
   `review`.
   **Recommended disposition:** reject as out of scope — the boxes are the review
   phase's to tick against fresh evidence, which is what this section records.
6. The Estimate block says "The tuning run above has metrics" while
   `print_final_design()` drops the tuning line when `tuning_label` is `NULL`.
   **Recommended disposition:** reject — the design block always emits the candidate
   count, so "above" still refers to the tuning run.
7. `NEWS.md` omits the `estimate` component and calls the stored strings
   "values".
   **Recommended disposition:** fix now — name the `estimate` component in the
   entry.

No Driving RR, so no projection-vs-outcome pairs. No gate failure and no
return-floor finding: every criterion passed as written on fresh evidence, and
no reported finding demonstrates a criterion failing.
