<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M18: A misspecified call fails as nestedtune's own error

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP3
- **Branch/PR:** `m18-argument-guards` · https://github.com/jmgirard/nestedtune/pull/19

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

- [x] **AC1.** `nested_resamples()` refuses an `inside` specification that
      evaluates to something other than an `rset`, on **every** outer fold, via
      `cli::cli_abort()` naming the attempted call; the raised condition's
      `conditionCall()` is the user's `nested_resamples()` call. Baseline:
      `inside = list()` returns a `nested_resamples` object whose
      `inner_resamples[[1]]` has class `list` and errors only at print
      (`'list' object cannot be coerced to type 'double'`, `pretty.default`).
- [x] **AC2.** A failure raised *during* evaluation of `outside` or `inside`
      reports a message carrying no value from the frame: the same failure
      raised on a 30-row and a 3,000-row frame of identical shape produces
      identical messages, **each under 500 characters**. The length bound is
      part of the criterion — R truncates conditions at 8,190 bytes, so
      equality alone is satisfiable today with no fix. Baseline:
      `outside = nrow()` on a 30×2 frame gives 1,194 characters of deparsed data.
- [x] **AC3.** `nested_tune_grid()` and `nested_final_fit()` refuse a workflow
      carrying no model spec with a message naming `{.arg object}` and an `i`
      bullet **stating the remedy**, as every other check in `R/checks.R` does;
      the raised condition's `conditionCall()` is the user's call. Baseline:
      both raise workflows' "The workflow does not have a model spec." with
      `conditionCall()` equal to `workflows::extract_spec_parsnip(object)`.
- [x] **AC4.** A fixture exists on which the caller's metric set and **tune's
      default metric set's first metric** (`rmse` for regression) select
      different candidates in every outer fold, with the caller's first metric
      outside `{rmse, rsq}` (`mae`) so the metric *names* differ too. A test
      asserts that `nested_tune_grid()`'s `.selected` and `.metrics`, and
      `nested_final_fit()`'s `collect_metrics(x$tuning)`, each reflect the
      caller's metric set rather than tune's default.
- [x] **AC5.** Deleting the `metrics` argument from each of the three
      in-process sites that pass it — `tune::tune_grid()` at
      `R/nested-tune-grid.R:295`, `tune::last_fit()` at `:317`, and
      `tune::tune_grid()` at `R/nested-final-fit.R:201` — one at a time turns
      `Rscript -e 'devtools::test()'` red. A three-row ledger in this file names
      each site, the failing test, and the assertion that caught it.
- [x] **AC6.** The profile's `verify` slot is clean and its review-time check
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

- [x] **T1.** In `inner_resamples_from_split()` (`R/nested-resamples.R:138`),
      evaluate `cl` with the analysis frame bound to a name in a child
      environment rather than inlined, and refuse a non-`rset` result. The guard
      inspects the **existing** per-fold evaluation — a pre-pass over fold 1
      would draw from the RNG a second time and change every design the function
      returns (`vfold_cv()` consumes the stream). Test first.
- [x] **T2.** Apply the same non-inlining evaluation to `outside`
      (`R/nested-resamples.R:70`). Test first.
- [x] **T3.** Add a no-model-spec branch to `check_workflow()` ahead of
      `workflows::extract_spec_parsnip()` (`R/checks.R:30`); it inherits the
      user's call from the existing `call = rlang::caller_env()` default, so
      both entry points are covered by the one branch. Test first.
- [x] **T4.** Build the separating fixture in `helper-orchestration.R`:
      heavy-tailed regression data plus `metric_set(mae, rmse)`, searched at the
      **outer-fold** level (a whole-data proxy is not sufficient — it reports
      separation the nested design does not have). Generated in the helper, per
      the existing provenance pattern.
- [x] **T5.** Add the metric-delivery assertions for `nested_tune_grid()` and
      `nested_final_fit()` on that fixture.
- [x] **T6.** Run the three-site mutation inversion, one site at a time,
      restoring each; record the ledger.
- [x] **T7.** `NEWS.md` entries for the two new refusals; `devtools::document()`;
      full `devtools::check()`.

## Work log

- 2026-07-30: created by /milestone-plan.
- 2026-07-30: absorbs three candidate rows — M01 F7 (78, unguarded `inside` at construction), M02 F6 (75, preprocessor-only workflow), M05 F1 (78, metric set equal to tune's default) — all logged below their reviews' action threshold and promoted here.
- 2026-07-30: criteria audit ([O], fresh context) returned 8 wording problems; 5 fixed here (AC1 quantifier + T1 pre-pass RNG hazard, AC2's shape-dependent baseline and its vacuous byte-identity property, AC3's contentless `i` hint, AC4's undefined "tune's default", Coverage AC5→T4,T5,T6) and 1 routed to the gate (three named sites vs nine actual). It refuted the author's flagged risk: all three named sites go red on a separating fixture, `.selected` included.
- 2026-07-30: plan gate chose serial-only metric-delivery proof over including the mirai `.args` site (`R/parallel.R:86`) because a daemon-backed test lands in the file M16 measured as the suite's worst case; falsified by evidence that the parallel path can drop `metrics` independently of the serial path.
- 2026-07-30: plan gate chose a purpose-built separating fixture over changing the shared `reg_metrics()` because on `make_reg_data()` every candidate metric selects alike, so the global change would re-record snapshots across ~6 files and still not catch the `tune_grid()` site; falsified by a second milestone needing the same separation from a different fixture.
- 2026-07-30: plan chose guarding inside the existing per-fold evaluation over a construction-time pre-pass because a pre-pass draws from the RNG again and changes every design returned; falsified by evidence that a specification can produce an `rset` on fold 1 and not on a later fold at a cost the per-fold guard does not catch.
- 2026-07-30: /milestone-implement — branch `m18-argument-guards` cut from `main` at `1c7ae56`; status `planned` → `in-progress`.
- 2026-07-30: implement gate — one open choice, how to detect a missing model spec: `workflows` does not export `has_spec()` and `:::` fails `R CMD check`, and its error is a bare `rlang_error` with no subclass to discriminate on, so the user chose the structural check over catch-and-relabel.
- 2026-07-30: minor amendment — T1 and T2 committed together. They are one edit region and AC2's test spans both, so neither passes the profile's verify slot on its own; task text unchanged.
- 2026-07-30: T1+T2 — new internal `eval_spec()` binds the frame to a name instead of inlining it (both `outside` and `inside`), and the `inside` rset guard sits in the per-fold evaluation. Verified by execution that bind-by-name is byte-identical to inlining under a matched seed, fingerprint included, so no design changes.
- 2026-07-30: T1 guard proven by inversion — disabling the rset check turned 3 tests red; restored and re-verified. The per-fold test was vacuous on first draft (keyed to frame size, and the small fold was fold 1); re-keyed to the call count and now asserts the third fold was reached.
- 2026-07-30: T1+T2 verify slot clean — `devtools::test()` `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 1255 ]`.
- 2026-07-30: T3 — `check_workflow()` refuses a workflow with no model spec ahead of `extract_spec_parsnip()`, inheriting the user's call from the existing `call = rlang::caller_env()` default, so one branch covers both entry points. Proven by inversion: disabling it turned 2 tests red, restored to 0. No test depended on workflows' own wording. Verify slot clean — `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 1261 ]`.
- 2026-07-30: T4 — the criteria audit's proposed separating fixture did not reproduce (0 of 3 outer folds separated at its stated seeds), so the fixture was found by own search over (data seed × design seed) at the outer-fold level: `sep_data(seed = 10)` + `sep_nested(seed = 21)`, heavy-tailed `rt(df = 1.2)` noise, `metric_set(mae, rmse)`, separating in 3 of 3 folds. Verified through the drivers, not through hand-rolled `tune_grid()` calls.
- 2026-07-30: T5 — `test-metrics-argument.R` leads with a test asserting the fixture still separates, so the other three cannot pass vacuously against a future tune whose defaults changed; the same vacuity trap caught in T1's per-fold test. File runs ~8 s.
- 2026-07-30: T6 ledger row 1/3 — site `tune::tune_grid()` in `nested_fold_fit()` (`R/nested-tune-grid.R:292`); deleting `metrics` fails `test-metrics-argument.R:71` (`.selected` vs the reference loop resolving `mae`) and `:36` (fixture separation); 4 failures.
- 2026-07-30: T6 ledger row 2/3 — site `tune::last_fit()` in `nested_fold_fit()` (`R/nested-tune-grid.R:317`); deleting `metrics` fails `test-metrics-argument.R:50` (`.metrics$.metric` equals `c("mae", "rmse")`) and `:28` (metric names differ); 4 failures.
- 2026-07-30: T6 ledger row 3/3 — site `tune::tune_grid()` in `final_fit_worker()` (`R/nested-final-fit.R:197`); deleting `metrics` fails `test-metrics-argument.R:85` (`collect_metrics(x$tuning)$.metric`); 1 failure.
- 2026-07-30: T6 — all three sites red one at a time, baseline restored to `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 39 ]` on the filtered set; the plan-time worry that site 1 was unobservable through `nested_results` is refuted — `.selected` catches it on a separating fixture.
- 2026-07-30: AC5 line-number drift, logged not amended — the criterion names `R/nested-tune-grid.R:295`/`:317` and `R/nested-final-fit.R:201`; the calls actually sit at `:292`, `:317` and `:197`. Each site is identified unambiguously by function and call in the same clause, so the substance is unchanged and the plan-owned text is left alone.
- 2026-07-30: review incident — `8a3dac8` committed and pushed a review-time mutation by mistake: `git add -A` ran while the AC5 inversion was mid-flight and swept in site 2 with `metrics` deleted from `tune::last_fit()`. Restored in `d876c9a`; `R/`, `tests/` and `NEWS.md` verified byte-identical to `ca3ec82`, the tree the criterion evidence was gathered against. History left intact rather than rewritten. CI re-run on the corrected head.
- 2026-07-30: T7 partial — `NEWS.md` carries three entries for the user-visible refusals (the metrics work is test-only and gets none); `devtools::document()` produces no diff. `devtools::check()` still running at checkpoint time, so T7 stays unticked.

## Decisions

## Review

_2026-07-30. PR #19. Every criterion executed fresh against the loaded package,
never recalled from the implementation run._

**AC1 — verified.** `nested_resamples(d, outside = vfold_cv(v = 2), inside = list())`
raises ``​`inside` did not produce an <rset>.`` with `✖ `list()` gave a list.` and an
`i` bullet naming the per-fold requirement; `conditionCall()[[1]]` is
`nested_resamples`. Every-fold coverage is pinned by
`test-nested-resamples-specs.R` keyed to call count, asserting the third fold was
reached; disabling the guard turns 3 tests red.

**AC2 — verified.** Same failure at 30 and 3,000 rows, identical frame shape:
`outside = nrow()` gives byte-identical messages at 131 characters, `inside = nrow()`
at 130. Both identical and both under the 500-character bound (baseline 1,194).

**AC3 — verified.** Both entry points raise ``​`object` has no model specification.``
with `✖ The workflow carries a preprocessor only.` and
`i Add one with `workflows::add_model()`.`; `conditionCall()[[1]]` is
`nested_tune_grid` and `nested_final_fit` respectively, not
`workflows::extract_spec_parsnip`. Disabling the branch turns 2 tests red.

**AC4 — verified.** On `sep_data(seed = 10)` / `sep_nested(seed = 21)`: caller's
metric names `mae, rmse` against tune's default `rmse, rsq`; caller's first metric
`mae` is outside `{rmse, rsq}`; selections `1, 2, 2` against `3, 1, 3` — different in
all 3 of 3 outer folds. `nested_final_fit()`'s `collect_metrics(x$tuning)` carries
`mae, rmse`.

**AC5 — verified.** Mutation inversion re-run fresh at review, one site at a
time, each restored before the next. Ledger:

| site | failures | caught by |
|---|---|---|
| `tune::tune_grid()` in `nested_fold_fit()` | 4 | `test-metrics-argument.R:71` (`.selected` vs the reference loop resolving `mae`), `:36` (fixture separation) |
| `tune::last_fit()` in `nested_fold_fit()` | 4 | `test-metrics-argument.R:50` (`.metrics$.metric` equals `c("mae", "rmse")`), `:28` (metric names differ) |
| `tune::tune_grid()` in `final_fit_worker()` | 1 | `test-metrics-argument.R:85` (`collect_metrics(x$tuning)$.metric`) |

Baseline with all three restored: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 39 ]` on the
filtered set. The plan-time concern that site 1 was unobservable through
`nested_results` — which retains no inner tuning run — is refuted: `.selected`
catches it on a separating fixture.

**AC6 — verified.** `devtools::check(document = FALSE)` **Status: OK** — 0 errors,
0 warnings, 0 notes, 4m 43.8s; its `Running 'testthat.R'` leg passed.
`devtools::document()` produces no diff in `man/` or `NAMESPACE`.

### Consistency gate

`cairn_validate` exit 0 — 16 checks PASS, 8 advisories OK. `cairn_impact` skipped:
`cairn/DESIGN.md` is untouched by this milestone, which works under GP2/GP3 without
amending either. Profile `consistency-gate` slot: `document()` no diff; generated
files unedited; no `README.Rmd` in this repo so the knit check is a no-op;
`pkgdown::check_pkgdown()` reports "No problems found"; `NEWS.md` carries entries
for the user-visible refusals and names no milestone number; `check()` reports no
NOTEs, so no `.Rbuildignore` gap.

### Independent review — three lenses, then a scorer

26 candidate findings, unfiltered, from an [O] diff-bug lens, an [S] blame-history
lens and an [S] prior-review lens; scored by a fresh [S] scorer that generated none
of them. The prior-review lens found **zero regressions** and confirmed M18 is a
superset of M02 F6 (which named only `nested_tune_grid()`; AC3 covers both drivers).
Its GitHub inline-comment probe returned empty, so no per-PR walk — consistent with
M91's measurement.

**Actioned (scored ≥ 80), all fixed on the branch:**

- **D1 (92)** — the `sep_*` fixture's 3-of-3 separation was a property of the default
  generator triple: measured 1 of 3 under `normal.kind = "Box-Muller"` and 0 of 3
  under `RNGkind("L'Ecuyer-CMRG")` or `sample.kind = "Rounding"`, while the helper
  comment claimed reproducibility. Both helpers now pin the full triple as
  `reference_nested_loop()` does (D-011) and restore the caller's kinds; re-verified
  3 of 3 under all five configurations.
- **C2 (88)** — the no-model-spec `x` bullet told an *empty* workflow it "carries a
  preprocessor only", and the test pinned that wording as correct. Bullet is now
  conditional on `length(object$pre$actions)`; both shapes asserted.
- **B1 (87)** — the comment above the rset guard said the guard lives in `eval_spec()`.
  It does not.
- **E4 (85)** — `test-metrics-argument.R` asserts against recorded oracle O1 but
  carried no provenance header, so a ≥2-types audit reading declared locations would
  not see it. Header added.
- **A2 (83)** — binding the data to a name changes `parent.frame()` identity inside a
  specification. Inherent to the approach the plan chose; **not fixed**, candidate row
  raised.
- **E5 (82)** — repeated byte-identical builds bypassed M12's fixture cache and were
  therefore invisible to the `builds > 1` report built to detect exactly that. Now
  memoised; the five affected files run in 11 s together, against the ~20.9 s the lens
  measured for this file alone. The work log's earlier "~8 s" was an unmeasured
  estimate and is wrong.

Mutation inversion re-run after these edits, since they changed the asserting tests:
all three sites still red (4, 4, 1), baseline `[ FAIL 0 | PASS 41 ]`.

**Also fixed though sub-threshold**, being one-line and verified true: BH1 (76, the
`eval_inside_spec()` comment this milestone falsified), E7 (68, unseeded fixtures in
the AC2 test), F2/F3/F5 (NEWS overstated the baseline as "thousands", omitted the
chained-cause change, and named only the preprocessor-only shape).

**Logged, not actioned (below 80):** E2 (32) assertion weaker than its comment;
E3 (38) loop-gated assertions, cannot fire; E6 (42) — fixed anyway, since memoising
made the `sep_*` signature cache-routed and the completeness claim then genuinely
false; G3 (42) AC5's site count, the extra `R/parallel.R` sites being signature-level
and not silent; D4 (45) — fixed anyway, one line; A1 (55) `.nestedtune_data` shadowing
a same-named caller binding; B3 (55) a zero-split rset passes the class guard; C4 (55)
the fallback comment overstates robustness; F4 (52) NEWS phrasing; G1 (32) `environment()`
vs `rlang::current_env()`; G2 (60) neither refusal documented in roxygen; C3 (35) and
B4 (35) both concern `check_nested()` and the model-without-preprocessor shape, which
this diff does not touch; G4 (12) and BH2 (8) already logged; BH3 (15) a lesson-retirement
note for post-merge hygiene.
