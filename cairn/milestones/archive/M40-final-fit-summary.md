# M40: A `nested_final_fit` answers `summary()` the way its sibling does

**Status:** done (2026-09-01, PR #49 https://github.com/tidymodels/nestedtune/pull/49)

**Goal:** `summary()` on a `nested_final_fit` returns the shape M39 gave
`nested_results`, so both halves of the API answer the generic.

**Outcome:** `summary.nested_final_fit()` returns an object holding
`tuning_label`, `candidates`, `selection` and an always-`NULL` `estimate`;
`print.summary.nested_final_fit()` renders it and says under "Estimate",
where a number would be, that this model has none of its own and the nested
one is what to report. `final_selection_values()` is the single unrendered
extraction the stored component and the print label both render from, via
`as.character()` (matching the results side's `selection_values()`) and
`format()` respectively. `print.nested_final_fit()` is untouched, pinned
byte-identical by a `PRINT_BEFORE_M40` literal rather than by the snapshot a
print change would re-record. With roxygen, NAMESPACE, NEWS and a pkgdown row.

**Decisions:** `estimate` is carried and set to `NULL` rather than omitted, so
a caller meets a recorded fact instead of a missing name. None cross-cutting.

**Review:** three-lens; blame-history and prior-review found nothing, diff-bug
seven. Fixed at the gate: `selection` rendered with `format()`, so it was lossy
and followed `options(digits)` (F1), its test exercised only an integer and
could not see that (F4), and the NEWS component list (F7). Four rejected.
