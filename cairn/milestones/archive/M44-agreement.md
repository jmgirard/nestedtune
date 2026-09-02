# M44: `agreement()` tabulates what the outer folds selected

**Status:** done (2026-09-01, PR #53 https://github.com/tidymodels/nestedtune/pull/53)

**Goal:** A user asks a `nested_results` how often each candidate was selected across the outer folds and
gets a table back, keyed by the whole selected parameter combination, most frequent first.

**Outcome:** `agreement()` (`R/nested-results-agreement.R`), an exported S3 generic with a `nested_results`
method and a default that aborts with class `nestedtune_no_agreement_method` through
`abort_no_agreement_method()`, shaped like `abort_no_extract_method()`. The method stacks the completed
folds' selections over `selection_params()` with `vctrs::vec_rbind()` (a fold lacking a parameter fills
`NA`), counts with `vctrs::vec_count(sort = "location")`, orders by `n` descending with ties in first-
appearance order, adds `prop = n / completed`, and drops `.config`. A parameter id `n` or `prop` is refused
with class `nestedtune_agreement_name_collision`; nothing tuned gives a zero-row `n`/`prop` tibble; a
partial run warns through `warn_partial_summary(noun = "table")` (the helper gained `noun`); an all-failed
run aborts through `check_any_completed(action = "tabulate")`. Help page with the not-the-final-model
sentence and an engines-guarded example, `_pkgdown.yml` row, NEWS entry, DESIGN line. Answers issue #36.

**Decisions:** D-039 (the name, the owned-generic shape, `.config` dropped, zero rows when nothing tuned).

**Review:** one round, three-lens fan-out. History and prior-review lenses: no findings. Diff lens: seven;
fixed at the gate the silent overwrite of a parameter named `n` or `prop`, the help page's silence on a
no-value fold sharing the `NA` row with a fold that selected `NA`, its unconditional `sum(n)` claim, and a
test for a partial untuned run; rejected the multi-row selection and type-disagreeing folds (hand-edited
objects only) and the all-failed test's class comparison (criterion met as written). Nothing graduated.
