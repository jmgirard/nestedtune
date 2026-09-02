# M46: `nested_final_fit()` re-runs the procedure a result recorded

**Status:** done (2026-09-02, PR #55 https://github.com/tidymodels/nestedtune/pull/55)

**Goal:** A user hands `nested_final_fit()` the workflow and the `nested_results` whose estimate they will report, and the
model comes back from the same search that estimate describes — grid or Bayesian — re-run over the full data.

**Outcome:** `nested_final_fit(object, results, ...)` (D-041). `check_results_record()` (`R/checks.R`) refuses under one class
`nestedtune_bad_results`, before the seed draw, a non-`nested_results`, a missing `inside`/`procedure` record (both origins named, not
migrated) and a zero-row prototype; `procedure_tuner()` (`R/tuner.R`) rebuilds M45's tuner description from the `procedure` attribute;
`check_grid_params(recorded = TRUE)` judges the recorded grid against the workflow, naming `object` and `results`. Both orchestrators
stamp `attr(resamples, "inside")` as `inside`, carried by `run_attributes()` and `stamp_results()`. The object carries `procedure`;
`print()`/`summary()` name the procedure for both tuners, scored counts from the candidate record beside the requested ones (`initial`,
`initial_requested`, `iterations_completed`, `iterations_requested`; `NULL` on a grid fit), M40's constant re-agreed as
`PRINT_AS_AGREED_M46`. Oracles: the grid reference fed the recorded procedure, `reference_bayes_final_fit()` (`save_workflow = TRUE` on
the test's call only), the `iter = 0` grid identity, `fit_best()` on the reference run under the pinned fit seed; IP2 on a Bayesian
result; the read-nothing-but-splits probe by attribute surgery. Docs, vignette, README, NEWS, DESIGN. RB05/RR05 archived.

**Decisions:** D-041. Milestone-local (RR05 Q1–Q4): the O5 strand on the reference run, never the package's controls; both tuners' print
lines, four counts as summary components; one refusal class, three messages; the function kept, reopened only on a tune refit-the-record path.

**Review:** one round, three lenses; history and prior-review clean. Diff lens: twelve — fixed at the gate two Bayesian RNG identity
tests comparing a fixture-cache hit with itself, the recorded-grid refusal naming a `grid` formal the signature lacks, the Bayesian
page's missing final-fit pointer, a degrade-to-zero sentence, the singular wordings, a dead parameter, two cosmetics; deferred accepting
a results object whose every fold failed (candidate row); rejected three. The M42 fixture-key lesson extended; nothing graduated.
