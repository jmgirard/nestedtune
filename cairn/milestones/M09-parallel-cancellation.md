# M09: A stopped run reports nothing, not a partial estimate

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4, IP2
- **Branch/PR:** `m09-parallel-cancellation` · https://github.com/jmgirard/nestedtune/pull/9

## Goal

A parallel run cancelled from outside aborts, instead of recording the folds
that never ran as folds that were attempted and failed.

## Scope

**In:** `classify_fold_result()` (`R/parallel.R:155`) learns to tell a
cancelled task from a dead worker. `stop_mirai()` resolves every task in a
`mirai_map` to bare `errorValue` 20 — classed only `errorValue`/`try-error`,
never `miraiInterrupt` — so today they fall through to
`failed_fold("worker", ...)` and the run returns an estimate over folds that
were never given a chance to run. Code 20 joins the existing `miraiInterrupt`
branch and aborts with class `nestedtune_cancelled` inheriting
`nestedtune_interrupted`, letting `nested_tune_grid()`'s `on.exit()`
(`R/nested-tune-grid.R:201`) restore the caller's RNG state. M09-D1 found the
boundary the milestone must not cross: `errorValue` 19 covers both a daemon
dying mid-fold — which RR03 verified is a genuine fold failure — and a
`daemons(0)` teardown, and nothing in the returned value separates them, so 19
keeps today's behaviour and the limit is documented rather than guessed at.

**Out:** the pre-flight probe's daemon coverage and timeout messaging → M10.
Per-fold timeouts stay rejected (RR03 Q4); not reopened here. Cutting what each
worker must serialize → candidate row. Remote-pool behaviour → candidate row.

## Acceptance criteria

- [x] AC1: An execution-verified table records what mirai returns for a task
      cancelled by `stop_mirai()` (in-flight and queued), for `daemons(0)` with
      tasks outstanding, and for a killed daemon — on the mirai version in the
      test library, named. Committed in this file's Decisions section.
- [x] AC2: `classify_fold_result()` aborts with class `nestedtune_cancelled`,
      inheriting `nestedtune_interrupted`, on `errorValue` 20 — the one
      cancellation signal M09-D1 found to be distinguishable — and the caller's
      `.Random.seed` and `RNGkind()` are restored afterwards. Both fired by
      test. *(RB tripwire: ip-touching — IP4; reading settled at the M09 plan
      gate.)*
- [x] AC3: `errorValue` 19 still becomes a recorded worker failure — the
      existing BC3 test (`tests/testthat/test-parallel-identity.R:232`) passes
      unmodified — and the roxygen states the limit M09-D1 found: `daemons(0)`
      mid-run is indistinguishable from a daemon dying mid-fold, so a pool torn
      down that way is recorded as fold failures, not an abort. Classification
      stays positive-by-shape: no `inherits(x, "condition")`, no
      `conditionMessage()` on a bare `errorValue`.
- [x] AC4: No partial `nested_results` object is constructed on the abort path
      — the cancelled run returns nothing at all, tested.
- [x] AC5: Each new guard proven by inversion: deleting the cancellation branch
      reddens the AC2 tests, recorded in the work log.
- [x] AC6: The "Parallel execution" roxygen section
      (`R/nested-tune-grid.R:99`) says what a cancelled run does, distinguished
      from a fold whose worker died; `NEWS.md` entry added.
- [x] AC7: Profile `verify` slot clean — `devtools::document()` no diff,
      `devtools::test()` and `devtools::check()` clean.

## Coverage

- AC1 → T1
- AC2 → T2, T3, T4
- AC3 → T2, T3
- AC4 → T4
- AC5 → T5
- AC6 → T6
- AC7 → T6

## Tasks

- [x] T1: Probe by execution what mirai hands back for each cancellation path
      above, and for a killed daemon, against the installed mirai. Record the
      table and the version. Do not infer the codes from the candidate row.
- [x] T2: Write the failing tests first, in
      `tests/testthat/test-parallel-classify.R`: `errorValue` 20 →
      `nestedtune_cancelled`, and caught by a `nestedtune_interrupted` handler;
      `errorValue` 19 → recorded worker failure.
- [x] T3: Add a positive cancellation predicate to `classify_fold_result()`
      (`R/parallel.R:155`), beside the `miraiInterrupt` branch and above the
      `failed_fold()` fallback. Allowlist code 20 only; anything unrecognized
      keeps the `failed_fold()` default. Classify by the shape expected, never
      by asking whether the value is an error (M07 lesson).
- [x] T4: End-to-end test in `test-parallel-identity.R`, alongside BC4: cancel
      a real dispatched run, assert the abort, the restored RNG state and kind,
      and that no `nested_results` is returned. Bound it so a failure is an
      error, never a hang.
- [x] T5: Inversion pass — remove the branch, confirm T2/T4 redden, restore and
      diff. Log the result.
- [x] T6: Roxygen section + `NEWS.md`; `devtools::document()`, then
      `devtools::test()` and `devtools::check()` clean.

## Work log

- 2026-07-26: created by /milestone-plan — promotes the M07 review candidate row scored 78; sequencing and the IP4 reading were both settled at the plan gate, with escalation to an RB declined.
- 2026-07-26: in-progress on `m09-parallel-cancellation`. Gate settled two open choices: abort only on an allowlist of cancellation signals (unrecognized values keep today's failed-fold default, so completed folds are never discarded — M03's reason); and cancellation gets condition class `nestedtune_cancelled` inheriting `nestedtune_interrupted`, so existing handlers are untouched. RB escalation offered on the ip-touching criterion and declined again.
- 2026-07-26: T1 done — M09-D1 records the probe table; script kept at `benchmarks/probe-mirai-cancellation.R` (build-ignored). Finding contradicts the plan: `daemons(0)` yields errorValue 19, the same value a dying daemon yields, so AC2 and AC3 as written now conflict — amendment gate next.
- 2026-07-26: amendment gate — Scope/In, AC2 and AC3 amended and T2/T3 reworded, on M09-D1's finding that errorValue 19 cannot separate a `daemons(0)` teardown from a dying daemon. Abort is allowlisted to code 20; 19 keeps today's failed-fold behaviour and the limit is documented. Escalation offered and declined.
- 2026-07-26: T2 done — five tests added to `test-parallel-classify.R`. Two are red by design (code 20 must abort under both class names); three pass already, pinning behaviour T3 must not break: 19 stays a fold failure, a miraiError stays a fold failure, and a real interrupt stays a plain interrupt. Suite is red until T3.
- 2026-07-26: T3 done — `is_cancelled_value()` allowlists errorValue 20 by positive shape validation (`is.integer()` is what excludes the empty-string interrupt and the character miraiError, rather than branch ordering); `classify_fold_result()` aborts on it with `c("nestedtune_cancelled", "nestedtune_interrupted")`. Full suite green: 1105 pass, 0 fail, 0 skip.
- 2026-07-26: T4 done — end-to-end test on real daemons. Cancellation needs an actor outside a host that is blocked in `collect_mirai()`, so only that actor is substituted: the map is really dispatched and really stopped, and collect/classify/abort/unwind all run unmocked. Asserts the abort, both condition classes, `result` still NULL, RNG state and kind restored, and bounded elapsed. 50 pass in the file.
- 2026-07-26: T5 done — two inversions, both red. Deleting the abort branch reddens 2 tests in `test-parallel-classify.R` and 2 in `test-parallel-identity.R`; dropping `is.integer()` from the shape check reddens 2. The second inversion found a real defect and earned a test: R coerces in `==`, so a miraiError whose message is the string "20" equals the cancel code, and without the type check one unlucky error message would abort the run and discard every completed fold. Suite green: 1115 pass, 0 fail, 0 skip.
- 2026-07-26: T6 done — roxygen "Parallel execution" rewritten (the old line calling an interrupt the only non-failure was wrong once cancellation joined it) plus the documented `daemons(0)` limit; two NEWS entries. `devtools::document()` idempotent; `devtools::check()` 0 errors / 0 warnings / 0 notes in 5m5s.
- 2026-07-26: all tasks done, status `review`. Suite 1115 pass / 0 fail / 0 skip; `devtools::check()` clean.
- 2026-07-26: review — three lenses (two clean), four scored findings, three fixed on the branch (F2 82, F3 87, F1 78-actioned-anyway), F4 33 rejected with reason. Review also found two T2 tests that only passed because an earlier test loaded mirai as a side effect; fixed. Re-verified: 1110 pass / 0 fail / 0 skip, check 0/0/0, cairn_validate clean.

## Decisions

### M09-D1 (2026-07-26): mirai's cancellation signals, by execution

Probed on mirai 2.7.2 / nanonext 1.10.1, R 4.6.1. Every wait deadline-bounded;
`$data` read only once resolved.

| Trigger | Classes | Value | `nng_error` | `is_mirai_error` | `conditionMessage()` |
|---|---|---|---|---|---|
| `stop_mirai()`, task in flight | `errorValue/try-error` | 20 | Operation canceled | FALSE | raises |
| `stop_mirai()`, task queued | `errorValue/try-error` | 20 | Operation canceled | FALSE | raises |
| `stop_mirai()` on a `mirai_map`, both tasks | `errorValue/try-error` | 20 | Operation canceled | FALSE | raises |
| `daemons(0)`, task in flight | `errorValue/try-error` | 19 | Connection reset | FALSE | raises |
| daemon killed mid-task | `errorValue/try-error` | 19 | Connection reset | FALSE | raises |
| `stop()` raised inside the task | `miraiError/errorValue/try-error` | — | — | TRUE | works |

Two findings the plan did not have. **20 is unambiguous** and is what the real
code path yields — `collect_mirai()` on a stopped `mirai_map` returns 20 for
every task, not just the in-flight one. **19 is ambiguous and cannot be split:**
tearing the pool down with `daemons(0)` and a daemon dying mid-fold produce the
same value with the same classes. The candidate row's premise that a cancelled
run is code 20 is right for `stop_mirai()` and wrong for `daemons(0)`.

Nothing here inherits `"condition"` and `conditionMessage()` raises on all six
`errorValue` rows, confirming M07's lesson for the cancellation shapes too.

## Review

Verified 2026-07-26 on PR #9. Every line below is fresh execution, not recall.

- **AC1** — M09-D1 in this file holds the probe table: six triggers, on mirai
  2.7.2 / nanonext 1.10.1, R 4.6.1, script at
  `benchmarks/probe-mirai-cancellation.R`. The diff-bug reviewer independently
  re-probed two cases it did not cover (`daemons(0)` against a `mirai_map` with
  queued tasks; both triggers under `dispatcher = FALSE`) and got 19/19/20/20,
  matching the documented split.
- **AC2** — executed: code 20 yields
  `nestedtune_cancelled/nestedtune_interrupted/rlang_error/error/condition`.
  End-to-end on two real daemons, `.Random.seed` and `RNGkind()` both restored.
- **AC3** — code 19 returns `completed = FALSE`, `location = "worker"`; the BC3
  test is unmodified (the diff of `test-parallel-identity.R` is purely
  additive, confirmed by the prior-review lens). No `inherits(x, "condition")`
  and no `conditionMessage()` on a bare `errorValue` anywhere in the new path.
  The roxygen states the `daemons(0)` limit.
- **AC4** — `expect_null(result)` proven to discriminate: with the abort branch
  removed the assertion reddens. It did not before review — see F2.
- **AC5** — three inversions, all red. Removing the abort branch reddens 2 in
  `test-parallel-classify.R` and 3 in `test-parallel-identity.R`; dropping
  `is.integer()` from the shape check reddens 1.
- **AC6** — "Parallel execution" section rewritten, `NEWS.md` carries two
  entries. Corrected during review — see F1.
- **AC7** — `devtools::document()` idempotent; `devtools::test()` 1110 pass /
  0 fail / 0 skip; `devtools::check()` 0 errors / 0 warnings / 0 notes (4m48s).
  `cairn_validate` all checks pass.

### Consistency gate

`cairn_validate` exit 0, every check PASS or OK. Profile `consistency-gate`
slot: `document()` no-diff verified; no generated file hand-edited. No
DESIGN.md principle changed, so `cairn_impact` does not apply.

### Independent review

Three fresh-context lenses. **Blame-history [S]** and **prior-PR-comments [S]**
both reported no findings — the latter confirmed the diff regresses none of
RR03's binding criteria BC3/BC4/BC5 and that the GitHub comment probe returned
empty. **Diff-bug [O]** reported four, scored by a fresh [S] scorer:

- **F2 (82) — fixed.** `expect_null(result)`, the assertion carrying AC4, passed
  against pre-milestone code and pinned nothing: `tryCatch(condition = identity)`
  caught the failed-folds *warning* the old path emits, unwinding before the
  assignment completed and leaving `result` NULL either way. Narrowed to
  `error = identity`; inversion now reddens it.
- **F3 (87) — fixed.** The end-to-end test was not bounded, contrary to T4:
  `system.time()` reports elapsed time only after the call returns, so it could
  flag a slow run but never prevent a hang — the M07-D6 failure mode. Replaced
  with `setTimeLimit(elapsed = 60, transient = TRUE)`.
- **F1 (78) — fixed despite scoring below the threshold.** The new roxygen said
  "interrupting the call raises a `nestedtune_interrupted` condition", which is
  false: mirai's own documentation states that class arises when an ongoing
  *task* is interrupted, while interrupting the host call unwinds the blocking
  wait before any worker value is classified. Actioned below threshold because
  the claim was verified wrong against mirai's docs during review, and it was
  prose this milestone introduced. Reworded to describe both routes accurately.
- **F4 (33) — rejected.** Claimed an unmodified bullet about a whole-pool death
  is contradicted by M09-D1. It is not: RR03 Q4 verified that tasks still
  *queued* when every daemon dies remain unresolved indefinitely, which is what
  the bullet describes; M09-D1 probed a single in-flight task, a different case.

### Found during review, outside the lenses

`conditionMessage.miraiError` is registered by **mirai's** namespace, so two
tests added at T2 that fabricated a `miraiError` and routed it through
`classify_fold_result()` passed only because an earlier test in the same file
loads mirai as a side effect of `skip_if_not_installed()`. Where mirai is absent
— CRAN's `noSuggests` flavor, which this repo has been bitten by once — they
would error rather than skip. One was redundant with the existing real-miraiError
test and was deleted; the other now asserts on `is_cancelled_value()` directly,
which needs no mirai and still reddens under inversion.
