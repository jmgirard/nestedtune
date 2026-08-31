# M34: The arguments a caller can hand through to `tune`

**Status:** done (2026-08-31, PR #42 https://github.com/tidymodels/nestedtune/pull/42)

**Goal:** Give the three exported entry points the `...` barrier tidymodels signatures carry, forward `param_info` to `tune`, and stop every exported method swallowing an argument it does not understand.

**Outcome:** `nested_tune_grid()`, `nested_final_fit()` and `nested_resamples()` take
`...` after their required arguments, fenced with `rlang::check_dots_empty()`, so
`grid`, `metrics` and the new `param_info` match by name only and a mistyped argument errors
naming its own call. R does not partial-match past `...`, so abbreviations (`met` for
`metrics`) also break; both changes are in NEWS. `param_info` is validated by a local
`check_param_info()` before the first fold and forwarded unchanged to `tune::tune_grid()`
on both orchestrators, reaching daemons through `dispatch_folds()`/`fold_task()`'s
`.args`. Nine registered methods fence their `...`, `[.nested_results` the exemption (its
`...` reaches `NextMethod()`), the domain read from the package's own S3 registry.
`collect_metrics.nested_results()` is now `(x, ..., summarize)`.

**Decisions:** D-029 (`dials` joins Suggests so the tests can name a range).

**Review:** Three lenses; blame-history and prior-review found nothing, the diff lens ranked ten. Five fixed at the gate: AC6's file scan silently narrowed to `tests/` under
`R CMD check` (now skips), D-029 sat inside DECISIONS.md's commented template block, nine
methods still documented `...` as ignored, NEWS omitted the abbreviation break, and an
`R/parallel.R` comment claimed the signature was unchanged. Four deferred to a candidate
row, F9 rejected as the plan gate's own choice; the suite's unexplained 561s against a
recorded 64s/100s rides the same row.
