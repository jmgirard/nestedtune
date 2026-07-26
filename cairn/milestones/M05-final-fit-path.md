# M05: The final model is its own object

- **Status:** in-progress
- **Priority:** high
- **Depends on:** M02
- **Driving RR:** RR02
- **Principles touched:** IP1, IP2, IP3, GP1, GP2, GP3
- **Branch/PR:** m05-final-fit-path

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

- [ ] AC1: `nested_final_fit()` is exported and returns a `nested_final_fit`
      object holding the trained workflow, the selected parameters, and the
      tuning results; `extract_workflow()` on it satisfies
      `workflows::is_trained_workflow()`.
- [ ] AC2: under one seed its selected parameters and its predictions are
      `expect_identical()` to a hand-written tune pipeline over the same inner
      specification on the full data (reference-implementation oracle), and to a
      direct `fit()` of the finalized workflow under a one-row grid that forces
      the selection (invariant oracle) — two independent oracle types, recorded
      by the provenance header in the asserting test file (GP2).
- [ ] AC3: the same seed produces an identical fit, and `.Random.seed` and
      `RNGkind()` are unchanged after the call — on success and on error alike —
      asserted with `ranger`, whose randomness flows through R's RNG (IP2).
- [ ] AC4: `collect_metrics()`, `show_best()`, and `select_best()` have no
      method for the class and error rather than returning a number readable as
      the model's own performance; `print()` says in words that this object's
      performance is the nested estimate from `nested_tune_grid()`, pinned by a
      snapshot (IP3).
- [ ] AC5: every `cli_abort()` branch on the new path is fired by a test,
      including a design carrying no usable `inside` specification.
- [ ] AC6: `devtools::test()` and `devtools::check()` are clean (0 errors, 0
      warnings), `devtools::document()` produces no diff, and the new export has
      a `_pkgdown.yml` row and a NEWS entry.
- [ ] AC7 (BC1): `nested_final_fit()` draws its two seeds in one
      `sample.int(.Machine$integer.max, 2)` call at entry; the kind-pinned tuning
      seed is applied **before** the stored `inside` specification is evaluated,
      which is before `tune_grid()` runs; the kind-pinned fit seed is applied
      immediately before the full-data `fit()`; both seeds are exposed on the
      returned object; and the roxygen states the hand-replication recipe with
      the rset-construction step inside the tuning seed's scope.
- [ ] AC8 (BC2): Before M05 merges, `cairn/DECISIONS.md` carries a decision entry
      reconciling IP1's middle clause with the shipped behavior — either amending
      the clause so "never on the full dataset" scopes to preprocessing that
      feeds a reported estimate (with the final model's training preprocessing
      explicitly outside it), or recording the maintainer's reading that the
      existing text already permits it. The entry names IP1 and M05.
- [ ] AC9 (BC3): The reference-implementation oracle derives its expected seeds
      from the documented contract via its own `set.seed()` and
      `sample.int(.Machine$integer.max, 2)` call, asserts them equal to the
      object's exposed seeds, constructs the inner rset itself under the first
      seed per the documented recipe, and reads neither seeds nor resamples off
      the returned object.
- [ ] AC10 (BC4): `print.nested_final_fit()` output contains no numeric value
      derived from the stored tuning run, and the roxygen states that metrics
      computed from the stored tuning run are selection-time quantities,
      optimistically biased as a performance claim, naming the nested estimate as
      what to report instead.
- [ ] AC11 (BC5): A stored `inside` call that fails to re-evaluate at final-fit
      time (at minimum: a free variable absent from the evaluation environment)
      is raised as a `cli_abort` naming the stored call, fired by a test; the
      roxygen states that the specification is re-evaluated at call time.
- [ ] AC12 (BC6): The error-path RNG-restoration test triggers its failure after
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
- [ ] T8: `_pkgdown.yml` row, NEWS entry, DESIGN.md Function Families and
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
- 2026-07-26: T8 in progress — pkgdown row, NEWS entries, and DESIGN.md Function Families + Architecture written; `devtools::check()` still running, so T8 stays unchecked until it comes back clean.
- 2026-07-26: RR02 triage — rec 1, 2, 3, 4, 8, 9, 10 applied; rec 5 (`fit_best()` oracle strand) and rec 12 (print pointer to fold selections) applied at the user's choice; rec 11 (`extract_` accessor for the stored tuning run) deferred to a candidate row, a documented slot sufficing pre-1.0; rec 6 (mlr3 oracle) and rec 7 (size-matched final tuning) rejected on RR02's own reasoning.

## Decisions

- 2026-07-26: RR02 (archived) answers Q1–Q8 and is the record; its verdicts bind
  here as AC7–AC12, D-015 (IP1 narrowed), and D-016 (seed scope). The two that
  changed the plan rather than confirming it: the inner rset build is a third
  stochastic stage (Q4), and IP1's text forbade what its intent permits (Q2).

## Review
