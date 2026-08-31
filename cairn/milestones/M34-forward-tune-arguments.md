# M34: The arguments a caller can hand through to `tune`

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP1, GP3
- **Branch/PR:** `m034-forward-tune-arguments`

## Goal

Give the three exported entry points the `...` barrier tidymodels signatures
carry, forward `param_info` to `tune`, and stop every exported method
swallowing an argument it does not understand.

## Scope

User-facing tier: every deliverable here is an exported signature or the
error a user sees when they mistype an argument.

**In:** `...` immediately after the last required argument of
`nested_tune_grid()`, `nested_final_fit()` and `nested_resamples()`, fenced
with `rlang::check_dots_empty()`; a `param_info` argument on the two
orchestrators, forwarded unchanged to `tune::tune_grid()` on both the serial
and the mirai path; `check_dots_empty()` on every registered S3 method whose
`...` is documented "Not used"; `collect_metrics.nested_results()`'s
`summarize` moved after `...` to match `tune`'s own method.

**Out:** `eval_time` on `tune_grid()`/`last_fit()` → candidate row (honest
verification needs a censored fixture and a `censored` dependency gate).
A `control` argument → candidate row (amends D-010's clause and trades
against GP3). Partial name matching against formals preceding `...`
(`nested_tune_grid(wf, resample = folds)` still matches `resamples`) → not
addressed; R's own matching rule, and no fence sees it.

## Acceptance criteria

- [ ] AC1 `names(formals())` is asserted for each of `nested_tune_grid()`,
      `nested_final_fit()` and `nested_resamples()`, and each has `...`
      immediately after its last required argument, so `grid`, `metrics` and
      `param_info` match by name only.
- [ ] AC2 Each of those three functions raises an error naming its own call
      when passed `nonesuch = 1`; one test per function.
- [ ] AC3 `param_info` reaches `tune::tune_grid()` unchanged: a workflow whose
      tuned parameter has a wide default range, run with a `param_info`
      restricting it to a narrow interval, gives a `.selected` value inside
      that interval on every completed outer fold of `nested_tune_grid()` and
      in `nested_final_fit()`'s `selected`, where the same call without
      `param_info` puts at least one value outside it.
- [ ] AC4 A `nested_tune_grid()` run with `param_info` supplied is
      `identical()` on its fold records serial and at 2 mirai workers (IP2).
- [ ] AC5 Every method the package registers whose `...` is documented "Not
      used" fences it with `rlang::check_dots_empty()`. The domain is read at
      test time from the package's registered S3 methods, minus the single
      named exemption `[.nested_results`, whose `...` reaches `NextMethod()`;
      each method in that domain is called with `nonesuch = 1` and errors.
- [ ] AC6 `formals(getS3method("collect_metrics", "nested_results"))` is
      `(x, ..., summarize = TRUE)`; a grep for `collect_metrics(` over `R/`,
      `tests/`, `vignettes/` and the roxygen sources returns no call passing a
      second positional argument.
- [ ] AC7 The changelog carries an entry for the breaking signature changes,
      and `devtools::check()` is clean per `cairn/PROFILE.md`'s gate — 0
      errors, 0 warnings, NOTEs justified — with the full suite passing.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T1, T2, T3
- AC3 → T2, T4
- AC4 → T4
- AC5 → T5
- AC6 → T6
- AC7 → T7

## Tasks

- [x] T1 Test-first: assert the three formals vectors and the three
      `nonesuch = 1` errors; they fail against today's signatures.
- [x] T2 Add `...` + `check_dots_empty()` and `param_info` to
      `nested_tune_grid()` ([R/nested-tune-grid.R:300](R/nested-tune-grid.R:300))
      and `nested_final_fit()` ([R/nested-final-fit.R:174](R/nested-final-fit.R:174));
      thread `param_info` to the `tune::tune_grid()` calls at
      [R/nested-tune-grid.R:359](R/nested-tune-grid.R:359) and
      [R/nested-final-fit.R:237](R/nested-final-fit.R:237). Add `...` to
      `nested_resamples()` ([R/nested-resamples.R:60](R/nested-resamples.R:60)).
- [x] T3 Update every in-repo positional call site the new barrier breaks —
      `R/`, `tests/`, roxygen examples, `vignettes/` — found by grep, not by
      recall.
- [x] T4 Carry `param_info` through `dispatch_folds()`
      ([R/parallel.R:194](R/parallel.R:194)) and `nested_fold_fit()` to the
      daemon path; write the serial/2-worker identity test.
- [x] T5 Fence the nine "Not used" methods; write the NAMESPACE-enumerated
      probe test with `[.nested_results` named as the exemption.
- [x] T6 Move `summarize` after `...` in
      [R/nested-results.R:209](R/nested-results.R:209); fix the call sites the
      grep finds.
- [x] T7 Roxygen for the new arguments, `document()`, changelog entry,
      `devtools::check()`.

## Work log

- 2026-08-30: created by /milestone-plan.
- 2026-08-30: criteria audit ran in **full** mode ([O] fresh-context reader,
  user-facing tier). Returned nine findings; seven fixed here before the
  criteria were written — AC2's demonstration named `.selected` on
  `nested_final_fit()`, which has no folds; AC4's "forwards or fences"
  contradicted its own universal probe; AC1's "any unmatched name" is
  unenumerable under R's partial matching; AC6's 0-NOTE floor was stricter
  than PROFILE.md's own gate; the parallel path went unnamed by the
  `param_info` criterion, which AC4 now binds. Two went to the question gate
  (`eval_time`'s verification, the `collect_metrics` argument order).
- 2026-08-30: plan gate chose forwarding `param_info` only over also
  forwarding `eval_time` and `control`, because `eval_time`'s only honest
  verification needs a `censored` fixture and its own dependency gate, and
  `control` amends D-010's clause and trades against GP3 — both are candidate
  rows; falsified by a user needing a dynamic survival metric or `save_pred`.
- 2026-08-30: plan gate chose a behavioural `param_info` test (restricted
  range changes what every fold selects) over a mock-capture test asserting
  the argument arrived, because a capture binds the harness rather than the
  deliverable and testthat binding-mocks do not reach a mirai daemon;
  falsified by no parameter range being narrowable enough to separate the two
  grids on a fixture the suite can afford.
- 2026-08-30: implementation gate chose `param_info` ahead of `grid` and
  `metrics` in both orchestrator signatures, mirroring `tune::tune_grid()`'s own
  order, over appending it last; all three sit behind `...` and match by name
  only, so the choice is what the signature reads like.
- 2026-08-30: implementation gate chose a local `check_param_info()` beside the
  existing checks over letting `tune` reject a bad `param_info`, so a mistyped
  argument fails before the first fold rather than after it.
- 2026-08-30: T1 wrote `tests/testthat/test-dots-barrier.R` — the three formals
  vectors, the three `nonesuch = 1` errors asserted by condition class, the
  NAMESPACE-registry method probe, and the `collect_metrics()` positional scan
  with its planted-defect control. Ten failures against today's signatures.
- 2026-08-30: T2/T3/T5/T6 landed in one commit. Each is a piece of one
  signature change and no intermediate state is green — `check_dots_empty()`
  on `nested_tune_grid()` breaks the mocked `fold_task` stubs until the
  parallel path carries `param_info` too, and the T1 file asserts all four at
  once.
- 2026-08-30: T3 found no in-repo call site the barrier breaks. A parser-based
  scan over `R/`, `tests/`, `vignettes/` and the roxygen sources (57 files)
  counted unnamed arguments per call and reported one hit, in a prose comment
  in `helper-orchestration.R` rather than in code.
- 2026-08-30: minor amendment — `param_info`'s carry through `dispatch_folds()`
  and `fold_task()`, planned as T4, landed with T2: `dispatch_folds()` is the
  only route to `tune::tune_grid()`, serial path included, so T2 could not
  reach it any other way. T4 keeps the serial/2-worker identity test.
- 2026-08-30: seven test stubs of `fold_task()`/`nested_fold_fit()` grew the
  `param_info` argument, and `test-parallel-classify.R`'s recorded formals
  literal was updated; the three time-budget ledger rows for that file moved
  three lines with it.
- 2026-08-30: T4 wrote AC3's behavioural test (`test-param-info.R`) and AC4's
  identity test (`test-parallel-identity.R` BC6, with its time-budget ledger
  row). AC3's fixture is the continuous `threshold` tunable on an integer grid:
  restricted to [0.05, 0.15] every fold selects ~0.05, unrestricted every fold
  selects ~0.99. Both checks were shown able to fail — dropping the forward
  from the two `tune_grid()` calls reds AC3's two tests, and blanking
  `param_info` in the daemon `.args` alone reds BC6.
- 2026-08-31: T7 documented `...` and `param_info` on all three entry points,
  ran `document()`, and added three NEWS entries — two naming the breaking
  signature changes, one the new argument.
- 2026-08-31: implementation gate added `dials` to Suggests (D-029) after
  `devtools::check()` warned that the new tests reach into an undeclared
  namespace. Rejected alternative: overwriting the parameter object's `range`
  field, which needs no declaration and binds the test to a dials internal.
- 2026-08-31: `devtools::check()` clean — 0 errors, 0 warnings, 0 notes; full
  suite green (`testthat.R` 64s/100s under check).

## Decisions

## Review
