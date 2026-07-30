# M19: A malformed design is refused at the driver, not at the tenth fold

**Status:** done (2026-07-30, PR #20 https://github.com/jmgirard/nestedtune/pull/20)

**Goal:** Both drivers refuse a malformed design or a preprocessor-less workflow at the call the user wrote, not at the tenth fold.

**Outcome:** `check_nested()` gains `check_column_class(resamples, column, class,
hint)` over both list columns — every `splits` element an `rsplit`, every
`inner_resamples` element an `rset` — naming the column, the first offending
position and the type held. Its hint is per-column: `rsample::nested_cv()` builds a
design whatever `inside` returned, where `nested_resamples()` refuses it (M18).
`check_workflow()` gains a no-preprocessor branch guarded by `has_preprocessor()`,
asking `formula`/`recipe`/`variables` by name — `add_case_weights()` files under
`pre$actions` too. `eval_inside_spec()` takes the driver's call, so its aborts stop
naming `final_fit_worker()`.

**Decisions:** none milestone-local. Plan gate settled three: one design-validity
rule across both drivers (so `nested_final_fit()` refuses parts it never reads);
refusal over warn-and-continue (GP3, D-003); absorbing the `eval_inside_spec()` fix.

**Review:** blame-history and prior-review zero findings; diff-bug 14, scored
independently. Actioned >= 80: F1 (92) case weights slipped the new preprocessor
guard, reopening the degradation it closed; F2 (84) the `inner_resamples` hint was
false for the design it fires on; F6 (80) the final-fit tests missed a wrong
position or type. Five sub-threshold ones also fixed — logged as a deviation.
