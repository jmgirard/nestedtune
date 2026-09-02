# M47: `predict()` and `augment()` on a `nested_final_fit`

**Status:** done (2026-09-02, PR #56 https://github.com/tidymodels/nestedtune/pull/56)

**Goal:** A user calls `predict()` and `augment()` on the object `nested_final_fit()` returns and gets what the trained
workflow inside it gives, without reaching for `extract_workflow()` first.

**Outcome:** `predict.nested_final_fit(object, new_data, type = NULL, opts = list(), ...)` and
`augment.nested_final_fit(x, new_data, eval_time = NULL, ...)` in `R/nested-final-fit-predict.R`, each delegating to
`x$workflow`; `predict()` forwards `...` (parsnip's `check_pred_type_dots()` refuses a name outside its seven-name allowlist,
so it is exempted in `DOTS_EXEMPT_METHODS`), `augment()` fences them with `check_dots_empty()` because workflows' method
lets them vanish. `augment` re-exported from tune. One help page, `predict.nested_final_fit`, with the IP3 section "Residuals
on the training rows are not performance" pointing at `collect_metrics()`. pkgdown row, NEWS, README and vignette switched to
`predict(final, ...)`, DESIGN updated. Tests on the regression, classification and censored fixtures assert `identical()`
against the workflow's own call; AC6 asserts `collect_metrics()`/`show_best()`/`select_best()` still refuse the object.

**Decisions:** none milestone-local beyond the plan-gate choices in the work log: forward `predict()`'s dots and fence
`augment()`'s; ship `augment()` under the IP3 caveat; absorb the M05 candidate row with no D-entry, D-014's "not shipped in
M05" clause read as a deferral. AC3 and AC6 amended mid-implementation to the failures parsnip 1.6.0 and tune 2.1.0 raise.

**Review:** one round, three lenses; history and prior-review clean. Diff lens: nine — fixed at the gate the allowlist claim
("any name the model does not take" narrowed to "outside parsnip's short list" in roxygen, header, exemption comment and
NEWS), the missing upstream pin on `augment()`'s dots, a session precondition asserted as an expectation, a bare `catch_cnd()`,
`@return`'s column order, NEWS entry order; rejected a `workflows` floor (1.1.4 added the formal; the tune floor pulls later),
a dash style, and running `augment()` in the vignette. The M28 upstream-claims lesson extended; nothing graduated.
