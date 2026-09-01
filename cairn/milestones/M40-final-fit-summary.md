<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M40: A `nested_final_fit` answers `summary()` the way its sibling does

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** M39
- **Driving RR:** —
- **Principles touched:** IP3
- **Branch/PR:** `m040-final-fit-summary`

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

- [ ] AC1. `print.nested_final_fit()` emits byte-identical output before and
      after this milestone for the objects
      `tests/testthat/test-nested-final-fit-print.R` constructs.
- [ ] AC2. `summary()` on a `nested_final_fit` returns an object of class
      `summary.nested_final_fit` whose printing names the selected parameters
      and states where the model's honest estimate comes from.
- [ ] AC3. The text `print.summary.nested_final_fit()` emits contains none of
      the `mean` and `std_err` values `tune::collect_metrics(x$tuning)`
      reports, at the digit precisions the scan at
      `tests/testthat/test-nested-final-fit-print.R:30-53` applies.
- [ ] AC4. Both methods this milestone adds — `summary.nested_final_fit()` and
      `print.summary.nested_final_fit()` — have a roxygen `@return` clause
      naming what they return, verified by reading the two blocks in
      `R/nested-final-fit-print.R`.
- [ ] AC5. `cairn/PROFILE.md`'s `verify` slot is clean, and its fuller
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
- [ ] T2. Roxygen and `@return`, NAMESPACE, `NEWS.md`, `_pkgdown.yml`
      reference index.
- [ ] T3. Extend `tests/testthat/test-nested-final-fit-print.R` with the
      summary blocks and the AC1 byte-identity assertion; re-record
      `tests/testthat/_snaps/nested-final-fit-print.md`.

## Work log

- 2026-08-31: created by /milestone-plan, split out of M39 when two sizing tripwires fired on the single-milestone draft (9 acceptance criteria against the >~7 mark, and this half shippable on its own).
- 2026-08-31: criteria audit ran in FULL mode (user-facing tier) as part of M39's two passes, which read these criteria in their M39 numbering (AC4, AC5). Pass 2 returned two findings on them, both fixed here: AC5's promise quantified over "any number in the stored tuning run" where the named scan enumerates only `mean` and `std_err` of `collect_metrics()`, and it bound a returned object where the scan reads printed text. The citation was corrected from `:29-52` to `:30-53`.
- 2026-09-01: implement question gate chose mirroring M39's component shape for the summary object (`tuning_label`, `candidates`, `selection`, `estimate = NULL`) over a selection-only object or one also carrying the workflow, so both halves of the API answer `summary()` with objects a caller reads the same way; and the shared-`@rdname` topic layout with usage-labelled `@return` clauses ("`summary()` returns …", "`print()` returns …") plus an `@examplesIf` block, which mirrors M39's page structure without repeating its two unlabelled `\value` paragraphs. M39's own pages are untouched, staying with their ROADMAP candidate row.
- 2026-09-01: T1 — `summary.nested_final_fit()` and `print.summary.nested_final_fit()` in `R/nested-final-fit-print.R`. `selected_label()` now renders from `summary_final_selection()`, the same extraction the summary object stores, so `print()` and `summary()` cannot come to describe one selection differently; its output is unchanged. `tuning_scheme_label()` takes `pretty()` on `x$tuning` under the same `tryCatch` guard `outer_scheme_label()` uses (measured: "3-fold cross-validation"), and the candidate count comes from `scored_candidates()`, which swallows its own errors by construction — so neither print path can raise. `devtools::test()` clean: FAIL 0, WARN 0, SKIP 0, PASS 2400.
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
