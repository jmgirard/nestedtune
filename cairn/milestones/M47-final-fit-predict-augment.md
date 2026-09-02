# M47: `predict()` and `augment()` on a `nested_final_fit`

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, GP1
- **Resolves:** —
- **Branch/PR:** m047-final-fit-predict-augment

## Goal

A user calls `predict()` and `augment()` on the object `nested_final_fit()` returns and gets what the
trained workflow inside it gives, without reaching for `extract_workflow()` first.

## Scope

**Tier:** user-facing — two exported S3 methods and a re-exported generic, consumed by every user of
the final fit. Lineage: the M05 Out candidate row ("`predict()` and `augment()` methods on
`nested_final_fit`", added 2026-07-26), absorbed here; D-014's consequences clause recorded the two as
not shipped in M05 with `extract_workflow()` the door, a deferral rather than a rejection, so no entry
supersedes it.

**In:** `predict.nested_final_fit(object, new_data, type = NULL, opts = list(), ...)` and
`augment.nested_final_fit(x, new_data, eval_time = NULL, ...)`, each delegating to `x$workflow`
(`R/nested-final-fit.R`, `new_nested_final_fit()`); `...` forwarded on `predict()` because parsnip's
`check_pred_type_dots()` already refuses any name it does not take, fenced on `augment()` because
`workflows::augment.workflow()` swallows its dots unread (both verified 2026-09-02, workflows 1.3.0,
parsnip 1.6.0). `augment` imported from tune and re-exported beside `collect_metrics()`
(`R/reexports.R`). One help page for both methods carrying the IP3 caveat. pkgdown row, NEWS, README
and vignette examples switched to the direct call, DESIGN's function-family and architecture lines
updated. Tests on the suite's regression, classification and censored-regression fixtures.

**Out:** any prediction-shaped method on `nested_results` (IP3; D-010's refusal stands, no row); any
metric-producing generic on `nested_final_fit` (D-014; AC6 asserts the refusals still hold); a
no-`new_data` form like `tune::augment.last_fit()`'s, since a final fit holds no held-out rows (not
wanted; no row); the rest of the final-fit backlog — a final fit from a results object whose every
fold failed — stays on its own candidate row.

## Acceptance criteria

- [ ] AC1: `predict(final, new_data, ...)` returns a result `identical()` to
      `predict(extract_workflow(final), new_data, ...)` under each argument set the test names, asserted
      by `tests/testthat/test-nested-final-fit-predict.R` on the suite's three fixture modes: the
      regression fixture at the default type and at `type = "conf_int", level = 0.9`; the
      classification fixture at `type = "class"` and `type = "prob"`, gated by
      `skip_if_no_engines(stochastic = TRUE)` as `test-event-level.R` gates its final fit; the
      censored-regression fixture at `type = "survival"` with `eval_time`, gated by
      `skip_if_no_censored()` as `test-eval-time.R` gates its final fit.
- [ ] AC2: `augment(final, new_data, eval_time)` returns a result `identical()` to
      `augment(extract_workflow(final), new_data, eval_time)` on the same three fixtures under the
      method's own formals (`new_data`, and `eval_time` on the censored fixture), asserted in the same
      file.
- [ ] AC3: Argument handling, asserted in the same file. `predict(final, new_data, nonesuch = 1)`
      raises an error whose message names `nonesuch` as an argument the model's predict function does
      not take (parsnip's wording, which the test matches); `predict(final)` with no `new_data` raises
      the error the workflow's own `predict()` raises for a missing `new_data`; `augment(final,
      new_data, nonesuch = 1)` raises `rlib_error_dots_nonempty`.
- [ ] AC4: The help page documenting both methods states that augmenting the rows the model was
      trained on yields in-sample residuals that are not this model's performance, that the number to
      report is `collect_metrics()` on the results object the fit was built from, and that
      `augment()` refuses extra arguments where workflows' method ignores them; and `augment` is
      re-exported, so `nestedtune::augment(final, new_data)` works with `tune` not attached, asserted
      by a test in the same file.
- [ ] AC5: `_pkgdown.yml`'s "The final model" section lists the new help topic and the re-exports page
      lists `augment`; NEWS.md carries an entry for the two methods; `README.Rmd` and
      `vignettes/nested-cv.Rmd` call `predict(final, ...)` where they call
      `predict(extract_workflow(final), ...)` today (`README.Rmd:121`, `vignettes/nested-cv.Rmd:328`),
      the vignette sentence at `:324-326` reworded to say the object predicts directly and still naming
      `extract_workflow()` as the way to the workflow itself; `README.md` regenerated from `README.Rmd`.
- [ ] AC6: The refusals stand: `tune::collect_metrics()`, `tune::show_best()` and `tune::select_best()`
      on a `nested_final_fit` each still raise R's "no applicable method" error, asserted by a test in
      the same file, with a registry read (`getNamespaceInfo(asNamespace("nestedtune"), "S3methods")`)
      showing no method of this package registered on any of the three.
- [ ] AC7: The profile's verify slot: `devtools::document()` produces no diff, `devtools::test()`
      passes, and `devtools::check()` reports 0 errors, 0 warnings and no NOTE the previous check on
      the default branch did not carry.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2, T3
- AC4 → T2
- AC5 → T4
- AC6 → T1
- AC7 → T5

## Tasks

- [x] T1: Tests first, `tests/testthat/test-nested-final-fit-predict.R`: a final fit on each fixture
      (regression via `det_workflow()`/`final_results()`, classification as
      `test-event-level.R:236-262` builds one, censored as `test-eval-time.R:480-500` builds one, each
      `memoised()`), the identity assertions of AC1 and AC2, the three argument cases of AC3, the
      re-export call of AC4, and AC6's refusals with the registry read. Red before T2.
- [x] T2: The methods in `R/nested-final-fit-extract.R` (or a new `R/nested-final-fit-predict.R`):
      `predict.nested_final_fit()` forwarding `...` to `predict(x$workflow, ...)`,
      `augment.nested_final_fit()` with `rlang::check_dots_empty()` delegating to
      `augment(x$workflow, new_data, eval_time = eval_time)`; `@importFrom tune augment`, the re-export
      in `R/reexports.R`; one roxygen page (`@rdname predict.nested_final_fit`) with the IP3 caveat and
      the GP1 dots divergence; `devtools::document()`.
- [x] T3: `tests/testthat/test-dots-barrier.R:73` — add `predict.nested_final_fit` to
      `DOTS_EXEMPT_METHODS` with a comment giving the reason (its `...` reaches the workflow, where
      parsnip refuses unknown names); `augment.nested_final_fit` stays probed.
- [ ] T4: Docs: `_pkgdown.yml` row under "The final model"; NEWS entry; `R/nested-final-fit.R:49`
      (`@return`, "better reached with"), `:185` (`@examples`) and `:195` (`@seealso`); `README.Rmd:121`
      then `devtools::build_readme()`; `vignettes/nested-cv.Rmd:324-328`; `cairn/DESIGN.md:73-74`
      (function family) and the architecture paragraph naming `new_nested_final_fit()`.
- [ ] T5: Verify slot per `cairn/PROFILE.md`: `document()` no diff, `test()` clean, `check()` with the
      NOTE comparison of AC7 recorded in the work log.

## Work log

- 2026-09-02: created by /milestone-plan. Full-mode criteria audit ([O] fresh reader) returned 11 findings: fixed the classification gate, the unclassed parsnip error wording, AC2's upstream-property clause and its tension with AC3, the pkgdown re-exports gap, README regeneration and the vignette sentence, moved the dots-barrier exemption to T3 (instrument property), added AC6 (refusals stand), narrowed AC7; judgment calls on probe breadth answered by adding the `conf_int`/`level` probe.
- 2026-09-02: plan gate chose forwarding `...` on `predict()` and fencing it on `augment()` over fencing both with an explicit `eval_time` formal because parsnip already refuses unknown names on the forwarded path while workflows swallows augment's dots; falsified by a parsnip release that stops validating predict's dots, or a workflows release that starts reading augment's.
- 2026-09-02: plan gate chose shipping `augment()` with the IP3 caveat on its help page over shipping `predict()` alone or escalating to a review brief, because a per-row residual is not a performance number and the documentation obligation IP3 carries is met by the caveat; falsified by a user reading `.resid` on the training rows as the model's estimate despite the page.
- 2026-09-02: plan gate chose switching README and vignette to the direct call over leaving `extract_workflow()` examples, because the direct call is the one obvious path (GP3); no evidence class named — a presentation choice.
- 2026-09-02: plan gate chose absorbing the M05 candidate row with no new D-entry over annotating D-014, because its "not shipped in M05" clause was a deferral; falsified by a later reading of that clause as a rejection, which would then take a superseding entry.
- 2026-09-02: T1 — `tests/testthat/test-nested-final-fit-predict.R` written on the three fixtures; red on the branch as expected (`predict` falls to no-applicable-method, `augment` not found), 6 fixtures built.
- 2026-09-02: T2 — `R/nested-final-fit-predict.R` (both methods, one help page `predict.nested_final_fit` with the IP3 caveat and the dots divergence), `augment` re-exported in `R/reexports.R`; `document()` run. T3 — `predict.nested_final_fit` added to `DOTS_EXEMPT_METHODS` with its reason. Predict and dots-barrier files green.
- 2026-09-02: amendment pending (substantive, AC3 and AC6): parsnip 1.6.0's `check_pred_type_dots()` prints the literal placeholder `bad_args` instead of the argument's name, so AC3's "names `nonesuch`" clause is unsatisfiable; tune 2.1.0 refuses `collect_metrics()`/`show_best()`/`select_best()` through its own default methods ("No `<generic>()` exists for ..."), never R's "no applicable method", so AC6's failure identity was wrong. Tests written to the corrected identities; amended wording sent to a fresh [O] reader for the full-mode audit before the mini gate.

## Decisions

## Review
