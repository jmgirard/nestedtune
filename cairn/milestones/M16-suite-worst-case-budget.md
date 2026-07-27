# M16: The suite's worst case fits inside the CI budget

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m16-suite-worst-case-budget`

## Goal

The daemon tests' worst case is a declared number that fits well inside the CI
job cap, and a run that stops names the test it stopped in.

## Scope

**In:** Per-test `start`/`end` markers from `HangTraceReporter`
(`tests/testthat.R`) via testthat's `start_test`/`end_test` hooks — verified at
this plan gate to fire per block carrying the test's description, which the
localization record says is unavailable. A committed budget ledger enumerating
every declared wait bound reachable from the four daemon test files, each with
its `file:line`, and a parse-token guard that fails on an unbudgeted wait. Cutting
those bounds — the suite-wide option at `helper-parallel.R:81`, `prime_daemons()`'s
120 s and `warm_daemons()`'s 180 s, and the unbounded `check_daemons_can_load()`
at `test-parallel-classify.R:467` — so the localized file's worst case is a
fraction of M12's 20-minute cap. The hardcoded port at `:213` and the busy-pool
teardown at `:160-201`.

**Out:** The package's own 30 s `nestedtune.preflight_timeout` default and D-020's
option design — only what the test helper sets changes here. The two pre-M14
occurrences (52 and 40 minutes), which predate `collect_bounded()` and may be a
second, genuinely unbounded phenomenon → stays on the hang candidate row, trimmed
to that remainder. Sharing one pool across `test-parallel-identity.R`, whose eight
pool restarts dominate its own worst case → its existing candidate row. Taking the
pre-flight deadline off the wall clock → its existing candidate row. Any change to
`R/parallel.R`'s production bounds.

## Acceptance criteria

- [ ] AC1 `HangTraceReporter` emits a `start` and a matching `end` line naming
      both the file and the `test_that()` description, to unbuffered `stderr()`,
      alongside the per-file lines M14 ships; a test drives a two-block fixture
      through the reporter and asserts both blocks appear, paired and named. The
      class is reachable from a test file, which it is not where M14 left it.
- [ ] AC2 A committed ledger, `benchmarks/test-time-budget.R`, lists every
      declared wait bound reachable from `test-parallel-classify.R`,
      `test-parallel-detection.R`, `test-parallel-identity.R` and
      `test-parallel-interrupt.R` — each with its `file:line`, its seconds, and
      the test that pays it — and prints a per-file worst-case total. Each wait
      contributes its own declared seconds; an enclosing `setTimeLimit()` never
      caps that contribution, because M14 established by execution that it does
      not interrupt a blocked `mirai` wait.
- [ ] AC3 A test fails when a `collect_bounded(`, `daemons_load_status(`,
      `setTimeLimit(`, `check_daemons_can_load(`, `start_daemons(` or
      `start_mixed_daemons(` call in those four files or in `helper-parallel.R`
      carries no ledger row, by the parse-token method `test-suite-hygiene.R`
      already uses, so a new unbudgeted wait cannot land silently.
- [ ] AC4 The ledger's worst-case total for `test-parallel-classify.R` is under
      480 seconds and at most half the pre-milestone figure, which the ledger
      records beside it; the other three files' totals are recorded without a
      ceiling, `test-parallel-identity.R`'s cross-referenced to its candidate row.
- [ ] AC5 The pool at `test-parallel-classify.R:213` binds an ephemeral port
      (`tcp://127.0.0.1:0`) rather than the hardcoded 45997, and its test still
      asserts what it asserted: a set pool with zero connections classifying as
      `no_response` rather than as a load failure.
- [ ] AC6 With `expect_lt(elapsed, 15)` at `test-parallel-classify.R:198`
      inverted to force a failure, the run shows positively that the block's
      `stop_mirai(busy)` already ran before the aborting assertion — teardown
      silence is not evidence, since the block's own `on.exit(daemons(0))` runs
      on abort and the teardown stays silent today, pre-fix. A positive control
      that deliberately leaks a pool shows `teardown-zz-nothing-survives.R` does
      fire, so its silence in the first run means something.
- [ ] AC7 The profile's `verify` slot is clean and its `consistency-gate` slot's
      full check too (`cairn/PROFILE.md`), and
      `benchmarks/stress-daemon-ledger.md` carries a dated superseding note
      correcting its per-test-hook claim rather than a silent rewrite.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T2, T4
- AC5 → T5
- AC6 → T6
- AC7 → T7

## Tasks

- [x] T1 Move `HangTraceReporter` (`tests/testthat.R:33-48`) into a helper so a
      test file can see it, sourcing it from `tests/testthat.R`; extend it with
      `start_test`/`end_test`; add the two-block fixture test asserting paired,
      named lines. R6 is already in Suggests for it (D-021).
- [x] T2 Author `benchmarks/test-time-budget.R`: enumerate each bound with its
      `file:line` and payer, print per-file totals, and record the pre-milestone
      figures before anything is cut.
- [x] T3 Add the parse-token guard in `test-suite-hygiene.R` tying every wait call
      in the four daemon files and `helper-parallel.R` to a ledger row.
- [x] T4 Cut the bounds: the option at `helper-parallel.R:81` from 300 s to 120 s,
      `prime_daemons()`'s and `warm_daemons()`'s `collect_bounded()` seconds, and
      the unbounded `check_daemons_can_load()` at `test-parallel-classify.R:467`;
      restore the option by hand, never via `options()["name"]` (M10's trap);
      re-run T2.
- [x] T5 Bind the `:213` pool to an ephemeral port and confirm its assertions hold.
- [x] T6 Reorder the busy-pool teardown at `:160-201` so cancellation precedes any
      assertion that can abort the block; verify by inverting the assertion.
- [ ] T7 Append the dated superseding note to
      `benchmarks/stress-daemon-ledger.md`, and run the profile's `verify` and
      `consistency-gate` checks.

## Work log

- 2026-07-27: created by /milestone-plan.
- 2026-07-27: plan gate chose bounding and budgeting the declared waits over more instrumentation-and-wait, because execution refuted both structural suspects (a busy-port `daemons()` errors in 0.03 s, `daemons(0)` returns in 0.21 s with a live task) and the file's declared worst case of ~1009 s matches the observed ~17-minute stall against a typical 12.0 s; falsified by a recurrence after the budget is cut.
- 2026-07-27: plan gate chose counting each wait's declared seconds over the smallest covering bound, because M14 established `setTimeLimit()` does not interrupt a blocked `mirai` wait so crediting it would flatter the total on the path that stalls; falsified by evidence that `setTimeLimit()` does bound the waits in these files.
- 2026-07-27: plan gate chose 120 s for the helper's pre-flight option over 90 s and 60 s, because it is 4x the 30 s the helper records as having been exceeded on a loaded check machine and still clears the 480 s ceiling; falsified by a run exceeding a 120 s probe budget on a loaded runner.
- 2026-07-27: plan gate chose trimming the hang candidate row to its pre-M14 remainder over absorbing it whole, because the 52- and 40-minute occurrences predate `collect_bounded()` and may be a genuinely unbounded second phenomenon; falsified by evidence those stalls shared the bounded-slow cause.
- 2026-07-27: T1 done — `HangTraceReporter` moved to `tests/testthat/helper-hang-trace.R` (a test cannot see what the runner defines) and extended with `start_test`/`end_test`; 3 tests, 11 assertions, including a subclassed reporter that suppresses `end_test` to show the unmatched-start shape a killed job leaves. PROFILE's hang-locating line repointed. Suite clean, 1227 pass.
- 2026-07-27: T2 done — bound ledger in `tests/testthat/helper-time-budget.R`, thin reporter in `benchmarks/test-time-budget.R`; `helper-parallel.R`'s four bounds named as constants both files read, so they cannot drift. Pre-M16 measured: classify 1008.7 s (confirming the plan-gate arithmetic), identity 3000.0 s, interrupt 615.0 s, detection 120.0 s — ~79 minutes across four files against a 20-minute cap.
- 2026-07-27: T3 and T4 done, committed together because T3's ceiling assertions are red until T4 cuts the bounds and a checkpoint is never committed red. The guard checks both directions (no unbudgeted call, no stale row) and found three sites the hand census missed: `test-parallel-identity.R:166` and the two `collect_bounded()` calls inside `start_daemons()`. Cuts: prime 120->60 s, warm 180->60 s, the suite-wide option 300->120 s, and an explicit 60 s bound at the file's largest wait, which was 300 s inherited invisibly from the option. Classify 1008.7 -> 408.7 s, under the 480 s ceiling and under half. Suite clean, 1233 pass.
- 2026-07-27: T5 and T6 done. The `:213` pool binds an ephemeral port; the busy-pool test cancels explicitly before its first assertion AND registers an unconditional `on.exit` cancel ahead of the pool teardown. AC6 evidence by execution: without a cancel the task is still unresolved after `daemons(0)` (TRUE) and with it resolved (FALSE) — the live-task leak, direct rather than inferred from teardown silence. Positive control: a deliberately leaked pool makes `teardown-zz-nothing-survives.R` fire, so its silence is informative. Suite clean, 1233 pass.
- 2026-07-27: implement gate chose keeping the bound table in `tests/testthat/helper-time-budget.R` over a benchmarks-only ledger, because `benchmarks/` is `.Rbuildignore`d so AC3's guard would skip under `R CMD check` — where an unbudgeted wait costs a 20-minute job; falsified by the guard proving unrunnable from a test file.
- 2026-07-27: implement gate chose 60 s + 60 s for `prime_daemons()` and `warm_daemons()` over 90/45 and over leaving 180 s, landing the file near 428 s against AC4's 480 s ceiling; falsified by a warmup overrun that the 120 s probe budget does not absorb.
- 2026-07-27: criteria audit ([O], fresh context) returned three defective criteria — AC4's unsatisfiable "at least half", AC3's token list omitting `start_daemons(`, AC6's teardown-silence holding pre-fix — plus AC1 unbuildable where M14 left the reporter and a fourth daemon file omitted; all fixed before the gate.

## Decisions

## Review
