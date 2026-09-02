# M46: `nested_final_fit()` re-runs the procedure a result recorded

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** M45
- **Driving RR:** —
- **Resolves:** —
- **Principles touched:** IP2, IP3, IP4, GP2, GP3
- **Branch/PR:** m046-final-fit-recorded-procedure

## Goal

A user hands `nested_final_fit()` the workflow and the `nested_results` whose
estimate they will report, and the model comes back from the same search that
estimate describes — grid or Bayesian — re-run over the full data.

## Scope

Surface tier: user-facing — an exported function's signature changes (D-041,
pre-1.0 under D-003) and the results object gains a recorded inner
specification.

**In:** `nested_final_fit(object, results, ...)`; the design's `inside` call
recorded on every `nested_results` by both orchestrators and carried through
`run_attributes()`; the procedure, the inner specification and the data read
from the results object, refusing one that lacks the record or has no rows;
the Bayesian final-fit path through M45's tuner description; oracles, RNG and
read-nothing-else tests; print, summary and `extract_scored_candidates()` for
a Bayesian final fit; docs and the vignette's final-fit section.

**Out:** `predict()`/`augment()` on `nested_final_fit` → existing ROADMAP
candidate row (added 2026-07-26). A final fit from a design alone, restating
the procedure → gone (D-041); `tune::fit_best()` and `tune::last_fit()` cover
that need. A results object built before this milestone → refused, not
migrated (pre-1.0).

## Acceptance criteria

- [ ] AC1: `nested_final_fit(object, results, ...)` takes a `nested_results` in place of the design and procedure arguments; the inner specification comes from a new `inside` attribute both orchestrators record from `attr(resamples, "inside")` and `run_attributes()` carries, the data from the `splits` column, and the procedure from M45's `procedure` attribute together with `attr(results, "metrics")`. A `results` lacking `inside` or `procedure`, or with zero rows, is refused before any fitting with its own condition class naming the user's call; `object` is still checked by `check_workflow()`; the former `grid`, `param_info`, `metrics`, `event_level` and `eval_time` formals are gone and any of them is a `check_dots_empty()` error.
- [ ] AC2 (live oracle; RB tripwire: no-oracle — the trade M45's work log records): for a grid result, the selected parameters, the tuning run's `in_id` splits and `predict()` on held-out rows are identical to the hand-rolled reference final fit `helper-orchestration.R` holds, fed the recorded procedure; for a Bayesian result, the same three are identical to a reference that sets the tuning seed with the kind pinned, evaluates the inner specification (D-016's order), calls `tune::tune_bayes()` with the recorded `iter`, `initial`, `objective` and `control_bayes(seed = <the tuning seed>, allow_par = FALSE)` — its initial set drawn inside that call from the same stream — selects, finalizes, sets the fit seed and fits on every row.
- [ ] AC3 (invariant oracle): the final fit of a `nested_tune_bayes(iter = 0, initial = k, param_info = p)` result and that of a `nested_tune_grid(grid = g, param_info = p)` result are identical in selection, tuning splits and predictions, `g` being `dials::grid_space_filling(p, size = k)` on the integer-only fixture where the draw is seed-independent; and `tune::fit_best()` on `extract_tune_results()` of a Bayesian final fit reproduces its predictions, the strand `test-nested-final-fit-oracles.R` records as O5.
- [ ] AC4 (IP2): for a Bayesian result, the same seed gives an identical final fit and a different seed a different one, the worker's output does not depend on the ambient kind, the caller's RNG state and kind are restored on completion and on error, and a session with no `.Random.seed` is left with a valid one; and the final fit reads nothing from the fold rows but `splits` — a test overwrites every other fold-row column (`.metrics`, `.selected`, `.grid`, `.notes`, `.completed`, `.tuning_seed`, `.outer_fit_seed` and the label columns) by assignment on the unclassed columns, re-stamps the class and attributes rather than going through a verb, and gets the same selection, splits and predictions.
- [ ] AC5: `print()` and `summary()` on a Bayesian `nested_final_fit` name the procedure with the initial count, the iterations actually completed read as the tuning run's largest `.iter`, and the requested `iter` shown separately as requested; `extract_scored_candidates()` returns the `.iter`-bearing candidate table M45's `scored_candidates()` derives.
- [ ] AC6 (docs): the help pages of `nested_final_fit()`, its print and summary methods and both orchestrators' final-fit pointers, and the vignette's final-fit section, show the new signature; `NEWS.md` carries the entry; `cairn/DESIGN.md`'s final-fit family line and architecture paragraph are updated.
- [ ] AC7: `Rscript -e 'devtools::document()'` produces no diff, `Rscript -e 'devtools::test()'` is clean, and `Rscript -e 'devtools::check()'` reports 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2
- AC2 → T3
- AC3 → T3
- AC4 → T4
- AC5 → T5
- AC6 → T6
- AC7 → T7

## Tasks

- [ ] T1: Record `inside`: `new_nested_results()` (`R/nested-results.R:8`) stamps `attr(resamples, "inside")` as `inside`, which joins `run_attributes()` (`R/nested-results.R:259`); `expect_kept()` and `expect_record_kept()` gain it; a test shows a design carrying no `inside` yields a result whose attribute is `NULL`.
- [ ] T2: The signature (RB tripwire: irreversible-api — D-041; ip-touching — IP3). `nested_final_fit(object, results, ...)` in `R/nested-final-fit.R:210`: `check_results_record()` in `R/checks.R` refusing a missing `inside` or `procedure` and zero rows, each with a class; the procedure attribute rebuilt into M45's tuner description; `final_fit_worker()` unchanged in shape. Re-point `test-nested-final-fit-checks.R` and every caller in `tests/testthat/` and `vignettes/` found by `grep -rn 'nested_final_fit(' tests vignettes R`.
- [ ] T3: Oracles in `test-nested-final-fit-oracles.R` (provenance header extended): the grid reference fed the recorded procedure; `reference_bayes_final_fit()` for AC2; the AC3 invariant; the O5 strand on a Bayesian final fit.
- [ ] T4: `test-nested-final-fit-rng.R` extended with AC4's properties on a Bayesian result, and the corruption test built by attribute surgery (a verb would strip the class, `R/nested-results.R:128-186`).
- [ ] T5: `print.nested_final_fit()` and `summary.nested_final_fit()` (`R/nested-final-fit-print.R`) name the procedure, iterations completed read from the tuning run; `extract_scored_candidates()` on a Bayesian final fit; snapshots rendered and read before approval (M08 lesson).
- [ ] T6: Roxygen for the new signature on every page that shows the old one (`grep -rn 'nested_final_fit(' R vignettes`), the vignette's final-fit chunk re-run, `NEWS.md`, DESIGN's final-fit family line and architecture paragraph.
- [ ] T7: `air format .`, `devtools::document()`, `devtools::test()`, `devtools::check()`.

## Work log

- 2026-09-01: created by /milestone-plan alongside M45, from the same gate; its criteria went through M45's full-mode audit (29 findings over both files; the M46 ones fixed here: `procedure` must carry `metrics`/`param_info`/`event_level`/`eval_time` for a re-run to be the estimate's procedure; a zero-row prototype must be refused; a fitted workflow is compared by selection, splits and predictions; the reference names D-016's order and the internal initial draw; the corruption probe covers every fold-row column but `splits` and is built by attribute surgery; printed iteration counts come from the run, not the request).
- 2026-09-01: plan gate chose `nested_final_fit(object, results)` over mirroring the orchestrators' arguments with a method switch because the mirror lets a user restate a procedure other than the estimate's, which is the reading IP3 exists to forbid, and over a candidate row because the recorded procedure M45 adds is shaped for this reader; falsified by a user needing a final fit with no nested run in hand, which `tune::fit_best()` and `tune::last_fit()` already serve.
- 2026-09-02: /milestone-implement started; branch cut from main at 9d84882. Question gate: AC3's O5 strand as written needs `fit_best()` on the final fit's own extracted run, and tune 2.1.0's `fit_best()` refuses a run tuned without `save_workflow = TRUE` (measured 2026-09-02: the package's controls do not set it, and the existing grid O5 strand runs it on the reference's run instead). The user escalated that question via /milestone-brief rather than choosing between saving the workflow on the final-fit path and amending AC3, and folded the other two gate questions into the same brief: whether the grid final fit's print also names its procedure (M40's hand-pinned bytes) and whether the results-record refusal carries one condition class or one per shape. No code written; T1-T7 wait on the report.

## Decisions

## Review
