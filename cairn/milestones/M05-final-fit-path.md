# M05: The final model is its own object

- **Status:** review
- **Priority:** high
- **Depends on:** M02
- **Driving RR:** RR02
- **Principles touched:** IP1, IP2, IP3, GP1, GP2, GP3
- **Branch/PR:** m05-final-fit-path · https://github.com/jmgirard/nestedtune/pull/5

## Goal

Ship `nested_final_fit()`, which re-runs the tuning procedure on the complete
dataset and hands back the resulting model as its own object, so a user can
deploy a model without ever reading the nested estimate as that model's score.

## Scope

**In:** a `nested_final_fit(object, resamples, grid, metrics)` export returning
the `nested_final_fit` class reached with `extract_workflow()`, plus the roxygen
IP3 obliges — shape per D-014, seed order per D-016. It re-evaluates the
design's stored `inside` specification against the full data, tunes, selects,
finalizes, and fits every row; validation reuses `R/checks.R`.

**Out:** the long-form guide → M06. `predict()`/`augment()` and an
`extract_`-family accessor for the stored tuning run → candidate rows.
Storing the workflow on `nested_results`, and an `inside` override argument →
both refused, the latter at the pre-implementation gate. Parallelism → the
existing candidate.

## Acceptance criteria

- [x] AC1: `nested_final_fit()` is exported and returns a `nested_final_fit`
      object holding the trained workflow, the selected parameters, and the
      tuning results; `extract_workflow()` on it satisfies
      `workflows::is_trained_workflow()`.
- [x] AC2: under one seed its selected parameters and its predictions are
      `expect_identical()` to a hand-written tune pipeline over the same inner
      specification on the full data (reference-implementation oracle), and to a
      direct `fit()` of the finalized workflow under a one-row grid that forces
      the selection (invariant oracle) — two independent oracle types, recorded
      by the provenance header in the asserting test file (GP2).
- [x] AC3: the same seed produces an identical fit, and `.Random.seed` and
      `RNGkind()` are unchanged after the call — on success and on error alike —
      asserted with `ranger`, whose randomness flows through R's RNG (IP2).
- [x] AC4: `collect_metrics()`, `show_best()`, and `select_best()` have no
      method for the class and error rather than returning a number readable as
      the model's own performance; `print()` says in words that this object's
      performance is the nested estimate from `nested_tune_grid()`, pinned by a
      snapshot (IP3).
- [x] AC5: every `cli_abort()` branch on the new path is fired by a test,
      including a design carrying no usable `inside` specification.
- [x] AC6: `devtools::test()` and `devtools::check()` are clean (0 errors, 0
      warnings), `devtools::document()` produces no diff, and the new export has
      a `_pkgdown.yml` row and a NEWS entry.
- [x] AC7 (BC1): `nested_final_fit()` draws its two seeds in one
      `sample.int(.Machine$integer.max, 2)` call at entry; the kind-pinned tuning
      seed is applied **before** the stored `inside` specification is evaluated,
      which is before `tune_grid()` runs; the kind-pinned fit seed is applied
      immediately before the full-data `fit()`; both seeds are exposed on the
      returned object; and the roxygen states the hand-replication recipe with
      the rset-construction step inside the tuning seed's scope.
- [x] AC8 (BC2): Before M05 merges, `cairn/DECISIONS.md` carries a decision entry
      reconciling IP1's middle clause with the shipped behavior — either amending
      the clause so "never on the full dataset" scopes to preprocessing that
      feeds a reported estimate (with the final model's training preprocessing
      explicitly outside it), or recording the maintainer's reading that the
      existing text already permits it. The entry names IP1 and M05.
- [x] AC9 (BC3): The reference-implementation oracle derives its expected seeds
      from the documented contract via its own `set.seed()` and
      `sample.int(.Machine$integer.max, 2)` call, asserts them equal to the
      object's exposed seeds, constructs the inner rset itself under the first
      seed per the documented recipe, and reads neither seeds nor resamples off
      the returned object.
- [x] AC10 (BC4): `print.nested_final_fit()` output contains no numeric value
      derived from the stored tuning run, and the roxygen states that metrics
      computed from the stored tuning run are selection-time quantities,
      optimistically biased as a performance claim, naming the nested estimate as
      what to report instead.
- [x] AC11 (BC5): A stored `inside` call that fails to re-evaluate at final-fit
      time (at minimum: a free variable absent from the evaluation environment)
      is raised as a `cli_abort` naming the stored call, fired by a test; the
      roxygen states that the specification is re-evaluated at call time.
- [x] AC12 (BC6): The error-path RNG-restoration test triggers its failure after
      the entry snapshot (inside the guarded region), not via argument
      validation; and a test asserts `identical()` results for the same seed
      whether the caller's generator at entry is default Mersenne-Twister or
      L'Ecuyer-CMRG.

### Deviations from RR02

| Criterion | Departure | Why |
|---|---|---|
| AC12 (BC6) | The ambient-kind clause is asserted at the internal worker with the two seeds supplied, rather than at `nested_final_fit()` from a user-visible seed. | D-011 draws the entry seeds from the caller's current stream, and that draw is kind-dependent — measured: `set.seed(77); sample.int(.Machine$integer.max, 2)` gives `1251063725 1556411193` under Mersenne-Twister and `1253652724 1031889291` under L'Ecuyer-CMRG. Identical results across kinds from one user-visible seed is therefore unsatisfiable unless the entry draw stops honouring D-011, and IP2 claims kind-independence nowhere. What the kind pin does buy — everything downstream of the seeds being kind-independent — is asserted in full, in the idiom `test-nested-tune-grid-rng.R` already uses. BC6's error-path clause is met as written. Chosen by the user at the amendment gate over pinning the kind before the entry draw. |

## Coverage

- AC1 → T2, T3
- AC2 → T4
- AC3 → T5
- AC4 → T6
- AC5 → T1
- AC6 → T7, T8
- AC7 → T2, T7
- AC8 → T9
- AC9 → T4
- AC10 → T6, T7
- AC11 → T1, T7
- AC12 → T5

## Tasks

- [x] T1: extend `R/checks.R` — reuse the four existing checks, add one
      refusing a design with no `inside` call and one wrapping its
      re-evaluation so a failure aborts naming the stored call; test every
      branch.
- [x] T2: implement `nested_final_fit()` in `R/nested-final-fit.R` in D-016's
      order — two seeds at entry, tuning seed, evaluate `inside`, tune, select,
      finalize, fit seed, `fit()` on all rows; RNG restored via
      `set_fold_seed()`/`restore_rng()` (`R/nested-tune-grid.R:342`).
- [x] T3: add `new_nested_final_fit()` carrying the workflow, selection, tuning
      run, and both seeds, plus the `extract_workflow()` method; test the
      extracted workflow is trained.
- [x] T4: `tests/testthat/test-nested-final-fit-oracles.R` with its provenance
      header — the contract-derived reference oracle, the forced-selection
      invariant oracle, and a `tune::fit_best()` strand (RR02 rec 5;
      `save_workflow = TRUE` on the test's own `tune_grid()`), on `ranger`.
- [x] T5: `tests/testthat/test-nested-final-fit-rng.R` — same-seed identity,
      seed sensitivity, net-zero exit including the fresh-session branch,
      error-path restoration triggered inside the guarded region, and
      ambient-kind independence.
- [x] T6: `print.nested_final_fit()` in `R/nested-final-fit-print.R` showing no
      number from the tuning run and pointing at the nested run's `.selected` for
      comparison (RR02 B3); tests that tune's ranking generics have no method.
- [x] T7: roxygen — the replication recipe, what to report instead and why, the
      stored run's selection-time bias, re-evaluation of `inside` at call time
      with literals as the safe form, and repeated-call identity (RR02 B2);
      cross-link from `R/nested-tune-grid.R:11`.
- [x] T8: `_pkgdown.yml` row, NEWS entry, DESIGN.md Function Families and
      Architecture updated, full check clean.
- [x] T9: record RR02's IP1 and RNG-contract findings as D-015 and D-016 and
      amend IP1's middle clause in DESIGN.md.

## Work log

- 2026-07-26: created by /milestone-plan.
- 2026-07-26: in-progress on branch m05-final-fit-path, cut from main at 4d78627.
- 2026-07-26: pre-implementation gate — a design with no re-runnable `inside` is refused, as planned, so no scope change; `extract_workflow()` registers against tune's re-export of hardhat's generic, so no DESCRIPTION change and no dependency gate.
- 2026-07-26: at the user's choice the IP1/IP2 reading behind T2 and T5 goes to a Review Brief before any code is written; no task started yet.
- 2026-07-26: blocked on RB02 (`cairn/reviews/RB02-final-fit-path.md`), 8 questions on the final-fit path's correctness, IP1 reading, RNG contract, and oracle independence.
- 2026-07-26: RB02 committed on this branch rather than the default branch, deviating from /milestone-brief step 2 — the branch already carried M05 at in-progress, so flipping the status on main would have left the two mirrors disagreeing and conflicted at merge.
- 2026-07-26: ingested RR02 — BC1–BC6 added verbatim as AC7–AC12; Scope compressed to stay under the cap; T9 added and done; RB/RR pair archived; status back to in-progress.
- 2026-07-26: T1-T3 landed together — the new abort branches are only reachable through the export, so checks, function, and constructor share one commit. `nested_final_fit()` re-runs the inner spec on all rows in D-016's seed order and returns a class carrying the workflow, selection, tuning run, and both seeds; `extract_workflow()` is re-exported alongside `collect_metrics()`.
- 2026-07-26: the `inside` re-evaluation guard fired on the repo's own `det_nested()` helper, whose `v` is a function parameter — exactly RR02 B1. Tests build designs with literals via a new `final_nested()` helper; substituting argument values at construction is now a candidate row.
- 2026-07-26: T4 — three oracle strands green (contract-derived reference, single-candidate invariant, `tune::fit_best()` tail).
- 2026-07-26: inversion showed the reference oracle did NOT guard D-016's ordering as RR02 assumed — swapping the rset construction outside the tuning seed's scope left selection and predictions unchanged because the selected `min_n` was stable across both fold sets. Added a direct assertion on the resamples the tuning run saw; that one reddens under the mutation.
- 2026-07-26: T5 — RNG suite green. BC6's ambient-kind clause is unsatisfiable at the exported function (the entry draw reads the caller's stream and is itself kind-dependent, measured), so the body after the seed draw is split into `final_fit_worker()` and the property is asserted there; deviation table added at the user's choice at the amendment gate.
- 2026-07-26: T6 — print shows the selection and points at the nested estimate and at `.selected`, never a number from the stored tuning run; that absence is asserted against every metric the run offers rather than assumed. tune's three ranking generics refuse, two through defaults tune wrote and one through dispatch failure.
- 2026-07-26: T7 — roxygen carries the replication recipe, what to report and why, the stored run's selection-time bias, the re-evaluation caveat, and repeated-call identity. `nested_results`' print now names `nested_final_fit()` instead of saying to fit separately; that snapshot change is the only one, reviewed line by line before accepting.
- 2026-07-26: T8 done — `devtools::check()` clean (0 errors, 0 warnings, 0 notes), `document()` produces no diff, `pkgdown::check_pkgdown()` finds no problems. All tasks complete; status to review.
- 2026-07-26: T8 in progress — pkgdown row, NEWS entries, and DESIGN.md Function Families + Architecture written; `devtools::check()` still running, so T8 stays unchecked until it comes back clean.
- 2026-07-26: RR02 triage — rec 1, 2, 3, 4, 8, 9, 10 applied; rec 5 (`fit_best()` oracle strand) and rec 12 (print pointer to fold selections) applied at the user's choice; rec 11 (`extract_` accessor for the stored tuning run) deferred to a candidate row, a documented slot sufficing pre-1.0; rec 6 (mlr3 oracle) and rec 7 (size-matched final tuning) rejected on RR02's own reasoning.

- 2026-07-26: review fan-out — two lenses clean; [O] diff-bug found 6. F5 (90) and F4 (87) fixed on the branch: five unfired shared abort branches added, and the four deterministic-engine RNG tests moved to `ranger` as AC3 requires. F1 (78), F2 (65), F3 (52), F6 (48) logged; F1 became a candidate row. The AC5 evidence line overclaimed and is corrected.

## Decisions

- 2026-07-26: RR02 (archived) answers Q1–Q8 and is the record; its verdicts bind
  here as AC7–AC12, D-015 (IP1 narrowed), and D-016 (seed scope). The two that
  changed the plan rather than confirming it: the inner rset build is a third
  stochastic stage (Q4), and IP1's text forbade what its intent permits (Q2).

## Review

_2026-07-26. Evidence gathered fresh by command on branch `m05-final-fit-path`,
PR #5. Test counts are per-file runs of `devtools::test(filter = ...)`._

**Per-criterion evidence.**

- AC1 — `test-nested-final-fit-results.R`, 14 passing. Asserts the
  `nested_final_fit` class, its five named elements, `extract_workflow()`
  satisfying `workflows::is_trained_workflow()`, a one-row selection drawn from
  the grid asked for, a `tune_results` tuning run, and two distinct integer
  seeds. A third test reads the fitted mould and confirms `nrow(predictors)`
  equals `nrow(data)` — the final fit trains on every row, not on an outer
  analysis set.
- AC2 — `test-nested-final-fit-oracles.R`, 7 passing. Reference strand:
  selection and predictions `expect_identical()` to `reference_final_fit()`.
  Invariant strand: a one-row grid gives predictions `expect_identical()` to a
  direct `fit()` of the finalized workflow, on the deterministic engine so no
  seed enters the comparison. Oracle records O3/O4/O5 head the file per the
  DESIGN Conventions.
- AC3 — `test-nested-final-fit-rng.R`, 22 passing. Same-seed identity across
  selection, predictions, and the tuning run's metrics; `.Random.seed` and
  `RNGkind()` identical before and after on the success path, on the error
  path, and from a non-default ambient kind; a follow-up `runif(3)` matching a
  run with the call absent. All seven tests on `ranger`, with a
  seed-sensitivity test guarding against a vacuous pass. _(Four of them ran on
  the deterministic engine until review finding F4; AC3 says `ranger`, so they
  were moved rather than the criterion read charitably.)_
- AC4 — `test-nested-final-fit-print.R`, 58 passing. `collect_metrics()`,
  `show_best()`, and `select_best()` all error on the class (two through
  defaults tune wrote, one through dispatch failure). Print states the estimate
  belongs to `nested_tune_grid()`; snapshot recorded.
- AC5 — `test-nested-final-fit-checks.R`, 22 passing. Every `cli_abort()` branch
  reachable through `nested_final_fit()` is fired: the three new ones (no
  `inside` attribute, an `inside` that fails to re-evaluate, one that evaluates
  to a non-rset) and all the shared ones — non-workflow, already-fitted
  workflow, missing engine package, non-design, zero-row design, missing `id`
  column, outer bootstrap, non-design grid, zero-row grid, unknown grid column,
  tuned parameter with no grid column, non-`metric_set` metrics. _(An earlier
  draft of this line claimed every shared check was fired when five branches
  were not; review finding F5 caught the overclaim and the five were added.)_
- AC6 — `devtools::check(document = TRUE)`: **Status OK, 0 errors, 0 warnings,
  0 notes** (3m 11s, `testthat.R` 110s). `devtools::document()` leaves `man/`
  and `NAMESPACE` clean. `_pkgdown.yml` carries a "The final model" section
  with `nested_final_fit` and `print.nested_final_fit`; `NEWS.md` carries three
  entries.
- AC7 (BC1) — code at `R/nested-final-fit.R`: one
  `sample.int(.Machine$integer.max, 2L)` at entry; `set_fold_seed(seeds[[1L]])`
  precedes `eval_inside_spec()`, which precedes `tune_grid()`;
  `set_fold_seed(seeds[[2L]])` immediately precedes `parsnip::fit()`. Both
  seeds exposed as `$tuning_seed` / `$fit_seed`. The oracle asserts the seed
  layout against contract-derived values, and asserts the folds the tuning run
  saw — **verified by inversion**: moving the rset build outside the tuning
  seed's scope reddens that assertion (1 failure) and leaves the rest green.
  Roxygen carries the replication recipe with the build step inside the scope.
- AC8 (BC2) — `cairn/DECISIONS.md` D-015 narrows IP1's middle clause, naming
  IP1 and M05. `cairn_impact.py IP1` lists 19 references; every one was read and
  none relies on the absolute wording that was narrowed — the two in
  append-only history (D-013's consequence line, M01's archive summary) remain
  true under the amended text, so nothing is left diverging.
- AC9 (BC3) — `reference_final_fit()` in `helper-orchestration.R` runs its own
  `set.seed(seed)` and `sample.int(.Machine$integer.max, 2L)`, builds its own
  rset under the first seed, and spells out the inner specification. It reads
  nothing off the returned object; the object's seeds are an assertion target,
  never an input.
- AC10 (BC4) — the print test collects every metric the stored tuning run
  offers and asserts each is absent from the output at 3–6 decimal digits,
  rather than assuming absence. Roxygen names those metrics selection-time
  quantities, optimistically biased as a performance claim, and names the
  nested estimate as what to report.
- AC11 (BC5) — `eval_inside_spec()` re-raises with the deparsed call and the
  original as `parent`; fired by a test using a design built in a `local()`
  whose `v` is gone. Roxygen states the specification is re-evaluated at call
  time and asks for literals.
- AC12 (BC6) — the error-path test fails inside the guarded region (the
  `inside` re-evaluation, which runs after the snapshot and after a
  `set.seed()`), not via argument validation; a second test repeats it from an
  L'Ecuyer-CMRG ambient kind. The ambient-kind clause is asserted at
  `final_fit_worker()` per the recorded deviation above.

**Projection vs outcome (Driving RR: RR02).** RR02 carries no numeric
projections; it states "every equality below is exact (`identical()` /
`expect_identical()`) … no numeric tolerance is granted or needed". Every
equality it binds was asserted with `expect_identical()` and held exactly, so
there is no shortfall to accept.

**Independent review.** Three fresh-context lenses. [S] blame-history: no
findings — the diff is additive in `R/checks.R`, `R/reexports.R`, and
`helper-orchestration.R`, touches only prose in `nested-tune-grid.R`, and the
IP1 amendment is a recorded decision rather than a silent contradiction. [S]
prior-review: no findings — the GitHub inline-comment probe returned empty, and
no archived `## Review` finding from M01–M04 or binding criterion from RR01 is
regressed. [O] diff-bug: six findings, scored by a fresh [S] scorer.

Actioned (>= 80), both fixed on the branch:

- **F5 (90)** — "AC5 ('every `cli_abort()` branch on the new path is fired by a
  test') is met for the three new branches but not for five shared branches now
  reachable through `nested_final_fit()`: `check_model_spec()`'s
  missing-engine-package abort, `check_nested()`'s missing-`id`-column and
  bootstrap-outer aborts, `check_grid()`'s zero-row-data-frame abort, and
  `check_grid_params()`'s 'no column for tuned parameter' abort." Fixed: three
  new tests fire all five. The scorer also flagged this review's own AC5
  evidence line as an overclaim; it is corrected above.
- **F4 (87)** — "the net-zero-exit, error-path-restoration, non-default-kind,
  and fresh-session tests all use `det_workflow()`/`det_grid()` (PCA + `lm`),
  not `ranger`, contrary to AC3's explicit 'asserted with `ranger`'." Fixed:
  all seven tests in the file now use the stochastic engine. The finding notes
  the assertions were not vacuous either way — this is the literal-text rule,
  not a correctness hole.

Logged below threshold, not actioned (4):

- F1 (78) — no test discriminates whether `metrics` reaches `tune_grid()`,
  because every fixture's metric set equals tune's regression default; a
  dropped argument would leave the suite green.
- F2 (65) — shared check messages name `nested_tune_grid()` and describe
  per-fold fitting when raised from the final-fit path.
- F3 (52) — `eval_inside_spec()`'s advice bullet asserts a scope diagnosis for
  every re-evaluation error, including ones that are not scope problems.
- F6 (48) — the no-number print guard probes only fixed-decimal renderings, so
  a low-precision display of a tuning metric would evade it.

F1 is the substantive one of the four and became a candidate row.

**Consistency gate.** `cairn_validate.py` exit 0 — 16 PASS, 6 advisories OK,
1 WARN (`sizing`: 12 acceptance criteria against the >7 tripwire; not split,
because AC7–AC12 are RR-bound refinements of existing tasks and add no
shippable slice). `cairn_impact.py IP1` reconciled above. Profile
`consistency-gate` slot: `document()` no diff; generated files not hand-edited;
no `README.Rmd` in the repo, so the knit check no-ops; `check_pkgdown()` reports
no problems; `NEWS.md` has this milestone's user-visible entries; no new
top-level files, and `_pkgdown.yml` was already in `.Rbuildignore`; full
`check()` clean.
