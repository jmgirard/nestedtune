<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M18: A misspecified call fails as nestedtune's own error

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP3
- **Branch/PR:** —

## Goal

Every argument shape the package refuses is refused by the package, at the call
the user wrote, and the `metrics` argument is provably delivered to each
in-process call that consumes it.

## Scope

**In:**

- `nested_resamples()` refuses an `inside` specification that does not produce an
  `rset`. Today `inside = list()` raises nothing: it returns a design whose
  `inner_resamples[[1]]` has class `list`, first symptomatic at print time.
- `nested_resamples()` stops inlining `data` into the calls it evaluates
  (`R/nested-resamples.R:70`, `:142`), so a failing specification no longer
  deparses the frame into its message. `eval_inside_spec()` (`R/checks.R:212`)
  already does this on the final-fit path; construction never got the fix.
- `check_workflow()` (`R/checks.R:30`) refuses a workflow carrying no model spec
  before `workflows::extract_spec_parsnip()` can raise its own error.
- A fixture and assertions under which deleting `metrics` from any of the three
  in-process call sites that pass it turns the suite red.

**Out:**

- The parallel delivery site (`R/parallel.R:86`, mirai `.args`) — no serial test
  reaches it and a daemon-backed one lands in the file M16 measured as the
  suite's worst case → candidate row.
- Changing the shared `reg_metrics()` fixture — on `make_reg_data()` every
  candidate metric selects alike, so the churn buys no detection → candidate row.
- The unread `attr(out, "metrics")` (`R/nested-results.R:27`, `:76`) → candidate
  row.
- Retaining the inner tuning run on `nested_results` → candidate row.

## Acceptance criteria

- [ ] **AC1.** `nested_resamples()` refuses an `inside` specification that
      evaluates to something other than an `rset`, on **every** outer fold, via
      `cli::cli_abort()` naming the attempted call; the raised condition's
      `conditionCall()` is the user's `nested_resamples()` call. Baseline:
      `inside = list()` returns a `nested_resamples` object whose
      `inner_resamples[[1]]` has class `list` and errors only at print
      (`'list' object cannot be coerced to type 'double'`, `pretty.default`).
- [ ] **AC2.** A failure raised *during* evaluation of `outside` or `inside`
      reports a message carrying no value from the frame: the same failure
      raised on a 30-row and a 3,000-row frame of identical shape produces
      identical messages, **each under 500 characters**. The length bound is
      part of the criterion — R truncates conditions at 8,190 bytes, so
      equality alone is satisfiable today with no fix. Baseline:
      `outside = nrow()` on a 30×2 frame gives 1,194 characters of deparsed data.
- [ ] **AC3.** `nested_tune_grid()` and `nested_final_fit()` refuse a workflow
      carrying no model spec with a message naming `{.arg object}` and an `i`
      bullet **stating the remedy**, as every other check in `R/checks.R` does;
      the raised condition's `conditionCall()` is the user's call. Baseline:
      both raise workflows' "The workflow does not have a model spec." with
      `conditionCall()` equal to `workflows::extract_spec_parsnip(object)`.
- [ ] **AC4.** A fixture exists on which the caller's metric set and **tune's
      default metric set's first metric** (`rmse` for regression) select
      different candidates in every outer fold, with the caller's first metric
      outside `{rmse, rsq}` (`mae`) so the metric *names* differ too. A test
      asserts that `nested_tune_grid()`'s `.selected` and `.metrics`, and
      `nested_final_fit()`'s `collect_metrics(x$tuning)`, each reflect the
      caller's metric set rather than tune's default.
- [ ] **AC5.** Deleting the `metrics` argument from each of the three
      in-process sites that pass it — `tune::tune_grid()` at
      `R/nested-tune-grid.R:295`, `tune::last_fit()` at `:317`, and
      `tune::tune_grid()` at `R/nested-final-fit.R:201` — one at a time turns
      `Rscript -e 'devtools::test()'` red. A three-row ledger in this file names
      each site, the failing test, and the assertion that caught it.
- [ ] **AC6.** The profile's `verify` slot is clean and its review-time check
      passes: `devtools::test()` green, `devtools::document()` no diff,
      `devtools::check()` 0 errors / 0 warnings.

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T3
- AC4 → T4, T5
- AC5 → T4, T5, T6
- AC6 → T7

## Tasks

- [ ] **T1.** In `inner_resamples_from_split()` (`R/nested-resamples.R:138`),
      evaluate `cl` with the analysis frame bound to a name in a child
      environment rather than inlined, and refuse a non-`rset` result. The guard
      inspects the **existing** per-fold evaluation — a pre-pass over fold 1
      would draw from the RNG a second time and change every design the function
      returns (`vfold_cv()` consumes the stream). Test first.
- [ ] **T2.** Apply the same non-inlining evaluation to `outside`
      (`R/nested-resamples.R:70`). Test first.
- [ ] **T3.** Add a no-model-spec branch to `check_workflow()` ahead of
      `workflows::extract_spec_parsnip()` (`R/checks.R:30`); it inherits the
      user's call from the existing `call = rlang::caller_env()` default, so
      both entry points are covered by the one branch. Test first.
- [ ] **T4.** Build the separating fixture in `helper-orchestration.R`:
      heavy-tailed regression data plus `metric_set(mae, rmse)`, searched at the
      **outer-fold** level (a whole-data proxy is not sufficient — it reports
      separation the nested design does not have). Generated in the helper, per
      the existing provenance pattern.
- [ ] **T5.** Add the metric-delivery assertions for `nested_tune_grid()` and
      `nested_final_fit()` on that fixture.
- [ ] **T6.** Run the three-site mutation inversion, one site at a time,
      restoring each; record the ledger.
- [ ] **T7.** `NEWS.md` entries for the two new refusals; `devtools::document()`;
      full `devtools::check()`.

## Work log

- 2026-07-30: created by /milestone-plan.
- 2026-07-30: absorbs three candidate rows — M01 F7 (78, unguarded `inside` at construction), M02 F6 (75, preprocessor-only workflow), M05 F1 (78, metric set equal to tune's default) — all logged below their reviews' action threshold and promoted here.
- 2026-07-30: criteria audit ([O], fresh context) returned 8 wording problems; 5 fixed here (AC1 quantifier + T1 pre-pass RNG hazard, AC2's shape-dependent baseline and its vacuous byte-identity property, AC3's contentless `i` hint, AC4's undefined "tune's default", Coverage AC5→T4,T5,T6) and 1 routed to the gate (three named sites vs nine actual). It refuted the author's flagged risk: all three named sites go red on a separating fixture, `.selected` included.
- 2026-07-30: plan gate chose serial-only metric-delivery proof over including the mirai `.args` site (`R/parallel.R:86`) because a daemon-backed test lands in the file M16 measured as the suite's worst case; falsified by evidence that the parallel path can drop `metrics` independently of the serial path.
- 2026-07-30: plan gate chose a purpose-built separating fixture over changing the shared `reg_metrics()` because on `make_reg_data()` every candidate metric selects alike, so the global change would re-record snapshots across ~6 files and still not catch the `tune_grid()` site; falsified by a second milestone needing the same separation from a different fixture.
- 2026-07-30: plan chose guarding inside the existing per-fold evaluation over a construction-time pre-pass because a pre-pass draws from the RNG again and changes every design returned; falsified by evidence that a specification can produce an `rset` on fold 1 and not on a later fold at a cost the per-fold guard does not catch.

## Decisions

## Review
