# M47: `predict()` and `augment()` on a `nested_final_fit`

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, GP1
- **Resolves:** —
- **Branch/PR:** m047-final-fit-predict-augment · https://github.com/tidymodels/nestedtune/pull/56

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

- [x] AC1: `predict(final, new_data, ...)` returns a result `identical()` to
      `predict(extract_workflow(final), new_data, ...)` under each argument set the test names, asserted
      by `tests/testthat/test-nested-final-fit-predict.R` on the suite's three fixture modes: the
      regression fixture at the default type and at `type = "conf_int", level = 0.9`; the
      classification fixture at `type = "class"` and `type = "prob"`, gated by
      `skip_if_no_engines(stochastic = TRUE)` as `test-event-level.R` gates its final fit; the
      censored-regression fixture at `type = "survival"` with `eval_time`, gated by
      `skip_if_no_censored()` as `test-eval-time.R` gates its final fit.
- [x] AC2: `augment(final, new_data, eval_time)` returns a result `identical()` to
      `augment(extract_workflow(final), new_data, eval_time)` on the same three fixtures under the
      method's own formals (`new_data`, and `eval_time` on the censored fixture), asserted in the same
      file.
- [x] AC3: Argument handling, asserted in the same file. `predict(final, new_data, nonesuch = 1)`
      raises the same error, by message, that `predict(extract_workflow(final), new_data, nonesuch
      = 1)` raises — parsnip's `check_pred_type_dots()` refusal, identified by its wording ("not used
      to pass args to the model function's predict function"; parsnip 1.6.0 prints the literal
      placeholder `bad_args` rather than the argument's name, so the claim is about the refusal, not
      the name it reports); `predict(final)` with no `new_data` fails with the same message as
      `predict(extract_workflow(final))` with no `new_data` (R's missing-argument error in both, the
      workflow forcing `new_data` before use), so the method adds no error of its own; `augment(final,
      new_data, nonesuch = 1)` raises `rlib_error_dots_nonempty`.
- [x] AC4: The help page documenting both methods states that augmenting the rows the model was
      trained on yields in-sample residuals that are not this model's performance, that the number to
      report is `collect_metrics()` on the results object the fit was built from, and that
      `augment()` refuses extra arguments where workflows' method ignores them; and `augment` is
      re-exported, so `nestedtune::augment(final, new_data)` works with `tune` not attached, asserted
      by a test in the same file.
- [x] AC5: `_pkgdown.yml`'s "The final model" section lists the new help topic and the re-exports page
      lists `augment`; NEWS.md carries an entry for the two methods; `README.Rmd` and
      `vignettes/nested-cv.Rmd` call `predict(final, ...)` where they call
      `predict(extract_workflow(final), ...)` today (`README.Rmd:121`, `vignettes/nested-cv.Rmd:328`),
      the vignette sentence at `:324-326` reworded to say the object predicts directly and still naming
      `extract_workflow()` as the way to the workflow itself; `README.md` regenerated from `README.Rmd`.
- [x] AC6: The refusals stand: `tune::collect_metrics()`, `tune::show_best()` and `tune::select_best()`
      on a `nested_final_fit` each still raise the refusal tune's own default method raises, asserted
      by a test in the same file, each message matching tune's default wording (`No .* exists for`,
      tune 2.1.0) rather than R's "no applicable method", which is how D-010's and D-014's
      consequences clauses describe the same refusal; with a registry read
      (`getNamespaceInfo(asNamespace("nestedtune"), "S3methods")`) showing no method of this package
      registered on any of the three.
- [x] AC7: The profile's verify slot: `devtools::document()` produces no diff, `devtools::test()`
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
- [x] T4: Docs: `_pkgdown.yml` row under "The final model"; NEWS entry; `R/nested-final-fit.R:49`
      (`@return`, "better reached with"), `:185` (`@examples`) and `:195` (`@seealso`); `README.Rmd:121`
      then `devtools::build_readme()`; `vignettes/nested-cv.Rmd:324-328`; `cairn/DESIGN.md:73-74`
      (function family) and the architecture paragraph naming `new_nested_final_fit()`.
- [x] T5: Verify slot per `cairn/PROFILE.md`: `document()` no diff, `test()` clean, `check()` with the
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
- 2026-09-02: T4 — pkgdown row, NEWS entry, `nested_final_fit()` roxygen (`@return`, example, `@seealso`), README.Rmd/README.md (`build_readme()`, one line changed), vignette sentence and chunk, DESIGN function-family line and constructor paragraph; `document()` no further diff, `pkgdown::check_pkgdown()` no problems.
- 2026-09-02: full-mode criteria audit of the amended AC3/AC6 ([O] fresh reader) returned one minor instrument finding (AC3's "so the name is not asserted" aside) and two failure-identity gaps (AC3's clauses 1 and 2 could not tell parsnip's refusal or the workflow's missing-argument error from one the method raised itself), plus the note that D-010's and D-014's consequences clauses call the refusal "no applicable method"; all three wording recommendations applied, the delegation-pin comparison added to the AC3 test.
- 2026-09-02: amendment (substantive) accepted at the mini gate: AC3 and AC6 reworded to the failures parsnip 1.6.0 and tune 2.1.0 actually raise (text as now in the Acceptance criteria section); no criterion added, removed or reordered.
- 2026-09-02: T5 — first `devtools::check()` carried one NOTE (no visible global `predict` in the new method); fixed by calling `stats::predict()`, as `stats::sd()` is already called elsewhere without a DESCRIPTION change. On the committed tree 791c927: `air format .` no change, `devtools::document()` no diff, `devtools::test()` 0 failed / 0 warnings, `devtools::check()` 0 errors / 0 warnings / 0 notes (8m14s) against M46's 0-note baseline. Status → review.

## Decisions

## Review

Review opened 2026-09-02 on the branch tip 7958754 (no default-branch movement since the cut: `git log HEAD..origin/main` empty). Draft PR #56.

**Acceptance criteria (fresh evidence, 2026-09-02):**

- AC1 — `devtools::test(filter = "nested-final-fit-predict")`: the three AC1 blocks pass with no skip (35 expectations in the file, all dots under the summary reporter), so the classification and censored fixtures ran rather than skipped; each block asserts `identical()` against `predict(extract_workflow(final), ...)` under the named argument sets (default and `conf_int`/`level = 0.9`; `class` and `prob`; `survival` with `eval_time`), each with a control showing the argument reached the model. PASS.
- AC2 — same run: the three AC2 blocks pass, `identical()` against `augment(extract_workflow(final), ...)` on the same fixtures, `eval_time` on the censored one with its control. PASS.
- AC3 — same run: `nonesuch = 1` on `predict()` yields an error matching parsnip's "not used to pass args to the model function's predict function" wording, message identical to the workflow's own; `predict(final)` with no `new_data` raises a message identical to `predict(extract_workflow(final))`'s and naming `new_data`; `augment(final, d, nonesuch = 1)` raises `rlib_error_dots_nonempty` with `augment` as the call. PASS.
- AC4 — `man/predict.nested_final_fit.Rd` carries the section "Residuals on the training rows are not performance" stating in-sample residuals are not this model's performance and that `collect_metrics()` on the results object is the number to report, and the `...` entry stating `augment()` refuses what workflows' method lets vanish; the AC4 test block passes with `package:tune` absent from `search()` and `augment` in `getNamespaceExports("nestedtune")`. PASS.
- AC5 — `_pkgdown.yml` "The final model" lists `predict.nested_final_fit`; `man/reexports.Rd` lists `augment` under tune; NEWS.md's first entry names both methods; `README.Rmd:121` and `README.md:119` read `predict(final, new_data = mtcars[1:3, ])`; `vignettes/nested-cv.Rmd:324-326` says the object predicts directly and names `extract_workflow()` for the workflow itself, `:329` calls `predict(final, ...)`; `pkgdown::check_pkgdown()` no problems; no milestone id in user-facing text. PASS.
- AC6 — same run: the AC6 block passes, each of `collect_metrics()`, `show_best()`, `select_best()` raising a message matching `No <generic>() exists for`, and the registry read shows none of the three registered on `nested_final_fit` while `extract_workflow` is. PASS.
- AC7 — on the committed tree c78bc60 (the gate fixes included): `devtools::document()` no diff; `devtools::test()` exit 0, 46 files, no failure, skip or warning mark; `devtools::check()` 0 errors / 0 warnings / 0 notes in 8m45s, against the same 0-note result on 7958754 (9m43s) and M46's 0-note baseline, so no NOTE the default branch did not carry. PASS.
- README sync: `devtools::build_readme()` on the branch tip leaves `README.md` unchanged (git diff empty). `devtools::document()` no diff. `cairn_validate.py` exit 0, all checks pass, 18 references-staleness advisories only. No DESIGN principle text changed (no IP/GP-numbered line in the DESIGN diff), so `cairn_impact` is skipped.
- 2026-09-02 gate fixes (from the [O] diff-bug lens, findings 1-5 and 7; commit follows): roxygen `...` entry, file header and the dots-barrier exemption comment narrowed from "refuses any name the model does not take" to "refuses a name outside parsnip's own short list" (parsnip 1.6.0's `check_pred_type_dots()` allowlist: `interval`, `level`, `std_error`, `quantile_levels`, `time`, `eval_time`, `increasing`; a listed name the model cannot use is passed on and may be ignored), NEWS wording matched; the AC3 augment test gained the upstream pin (`augment(extract_workflow(final), d, nonesuch = 1)` raises no error, workflows 1.3.0); the AC4 test's `package:tune` check became `skip_if()`; the no-`new_data` test catches `classes = "error"` like its sibling; `@return` now says prediction columns come first, then `new_data` (confirmed: `.pred`, `.resid`, `mpg`); the NEWS Breaking entry moved above the feature entry. `air format .`, `document()`; predict and dots-barrier files green.

**Independent review (three fresh-context lenses, 2026-09-02), findings ranked as reported, disposition at the gate:**

- [O] diff-bug lens, 9 findings. (1) The dots-barrier exemption and the `...` help text said parsnip refuses "any name the model's predict method does not take"; parsnip 1.6.0 refuses names outside a seven-name allowlist and silently ignores a listed name the model cannot use (`level` without `type = "conf_int"` returns point predictions) — fix now: wording narrowed in roxygen, file header, exemption comment and NEWS, and the `level` advice now names `type = "conf_int"`. (2) The augment side of the dots divergence had no delegation pin, so the documented upstream property ("workflows' method lets the argument vanish") and the plan's falsifier were untested — fix now: `expect_null()` on the workflow's own call added to the AC3 augment test. (3) `expect_false("package:tune" %in% search())` fails rather than skips when a developer attached tune — fix now: `skip_if()`. (4) The no-`new_data` test caught conditions bare where its sibling catches `classes = "error"` — fix now. (5) `@return` said `augment()` returns `new_data` with prediction columns bound on; workflows binds predictions first — fix now, confirmed `.pred`, `.resid`, `mpg`. (6) No `workflows` version floor although `augment.nested_final_fit()` passes `eval_time` by name — rejected: workflows added that formal in 1.1.4 (its NEWS), and the `tune (>= 2.0.0)` floor pulls a later workflows (tune 2.1.0 requires >= 1.3.0), so no reachable install lacks it; a floor is a dependency change and would need its own gate. (7) NEWS put the feature above the Breaking entry — fix now, entries reordered. (8) `--` beside a literal em dash in the vignette prose — rejected: pre-existing style the file already carries at `:308-309`. (9) The vignette names `augment()` but only runs `predict()` — rejected: AC5 scoped the vignette to the predict switch and the help page example runs `augment()`; open to the maintainer at the gate.
- [S] blame-history lens, 0 defects. Confirmed D-014's "not shipped in M05" clause reads as a deferral, the removed "better reached with" phrase was superseded in lockstep with DESIGN, D-014's refusals still hold (AC6), the dots divergence matches M34's barrier design, and the IP3 risk of `augment()` is the logged plan-gate acceptance. One note, no action: D-010/D-014 describe the refusal as "no applicable method" while tune 2.1.0 raises its own default-method wording — pre-existing, and AC6's text already records the discrepancy.
- [S] prior-review-record lens, no prior-review evidence of a regression: LESSONS.md read whole (the M42 memoised-identity lesson checked against the new file's fixtures: identities are between two direct calls), the archive grepped for the touched files and read at 11 hits (M34's dots-documentation finding not reintroduced), the GitHub probe found one real inline comment on an unrelated workflow file and none on any PR touching these files.
