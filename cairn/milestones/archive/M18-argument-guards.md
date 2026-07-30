# M18: A misspecified call fails as nestedtune's own error

**Status:** done (2026-07-30, PR #19 https://github.com/jmgirard/nestedtune/pull/19)

**Goal:** Every argument shape the package refuses is refused by the package, at the
call the user wrote, and `metrics` is provably delivered to each in-process consumer.

**Outcome:** `nested_resamples()` gains `eval_spec()`, binding the frame to
`.nestedtune_data` in a child environment rather than inlining it into the evaluated
call, and refuses a non-`rset` `inside` in `inner_resamples_from_split()` — per fold, so
no pre-pass disturbs the RNG stream. `check_workflow()` refuses a missing model spec via
`is.null(object$fit$actions$model)` before `workflows::extract_spec_parsnip()`, covering
both drivers. New `sep_*` fixtures and `test-metrics-argument.R` separate the caller's
metric set from tune's default on names and per-fold selection, so a dropped `metrics`
argument fails.

**Decisions:** none milestone-local. Implement gate chose the structural
`$fit$actions$model` probe over re-labelling workflows' error (`has_spec()` unexported).

**Review:** three lenses, 26 findings, scored independently; prior-review lens found zero
regressions. Actioned ≥80: D1 (92) fixture separated only under the default RNG triple;
C2 (88) wrong bullet for an empty workflow, pinned by its own test; B1 (87) misplaced
comment; E4 (85) missing oracle header; A2 (83) `parent.frame()` change, kept as a
candidate row; E5 (82) builds bypassed the fixture cache.
