# M16: The suite's worst case fits inside the CI budget

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** `m16-suite-worst-case-budget` / https://github.com/jmgirard/nestedtune/pull/15

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

- [x] AC1 `HangTraceReporter` emits a `start` and a matching `end` line naming
      both the file and the `test_that()` description, to unbuffered `stderr()`,
      alongside the per-file lines M14 ships; a test drives a two-block fixture
      through the reporter and asserts both blocks appear, paired and named. The
      class is reachable from a test file, which it is not where M14 left it.
- [x] AC2 A committed ledger, `benchmarks/test-time-budget.R`, lists every
      declared wait bound reachable from `test-parallel-classify.R`,
      `test-parallel-detection.R`, `test-parallel-identity.R` and
      `test-parallel-interrupt.R` — each with its `file:line`, its seconds, and
      the test that pays it — and prints a per-file worst-case total. Each wait
      contributes its own declared seconds; an enclosing `setTimeLimit()` never
      caps that contribution, because M14 established by execution that it does
      not interrupt a blocked `mirai` wait.
- [x] AC3 A test fails when a `collect_bounded(`, `daemons_load_status(`,
      `setTimeLimit(`, `check_daemons_can_load(`, `start_daemons(` or
      `start_mixed_daemons(` call in those four files or in `helper-parallel.R`
      carries no ledger row, by the parse-token method `test-suite-hygiene.R`
      already uses, so a new unbudgeted wait cannot land silently.
- [x] AC4 The ledger's worst-case total for `test-parallel-classify.R` is under
      480 seconds and at most half the pre-milestone figure, which the ledger
      records beside it; the other three files' totals are recorded without a
      ceiling, `test-parallel-identity.R`'s cross-referenced to its candidate row.
- [x] AC5 The pool at `test-parallel-classify.R:213` binds an ephemeral port
      (`tcp://127.0.0.1:0`) rather than the hardcoded 45997, and its test still
      asserts what it asserted: a set pool with zero connections classifying as
      `no_response` rather than as a load failure.
- [x] AC6 With `expect_lt(elapsed, 15)` at `test-parallel-classify.R:198`
      inverted to force a failure, the run shows positively that the block's
      `stop_mirai(busy)` already ran before the aborting assertion — teardown
      silence is not evidence, since the block's own `on.exit(daemons(0))` runs
      on abort and the teardown stays silent today, pre-fix. A positive control
      that deliberately leaks a pool shows `teardown-zz-nothing-survives.R` does
      fire, so its silence in the first run means something.
- [x] AC7 The profile's `verify` slot is clean and its `consistency-gate` slot's
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
- [x] T7 Append the dated superseding note to
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
- 2026-07-27: review actioned F3 (85) — named `MIXED_DAEMONS_BOUND_S`, added a call-site cross-check for copied bounds (verified by inversion), corrected the ledger header's over-claim. Suite 1239 pass, check 0/0/0, budget unchanged at 408.7 s. F1/F2/F4/F5 logged below threshold.
- 2026-07-27: T7 done — superseding note appended to the stress ledger (the per-test-hook claim, plus the two suspects execution refuted); the wrong paragraph left standing as the dated record it is. `devtools::document()` no diff; `devtools::check()` 0 errors, 0 warnings, 0 notes, tests 69s/114s under check — which also proves the runner's `source()` of the new helper resolves under `R CMD check`. No NEWS entry: nothing user-visible changed.
- 2026-07-27: implement gate chose keeping the bound table in `tests/testthat/helper-time-budget.R` over a benchmarks-only ledger, because `benchmarks/` is `.Rbuildignore`d so AC3's guard would skip under `R CMD check` — where an unbudgeted wait costs a 20-minute job; falsified by the guard proving unrunnable from a test file.
- 2026-07-27: implement gate chose 60 s + 60 s for `prime_daemons()` and `warm_daemons()` over 90/45 and over leaving 180 s, landing the file near 428 s against AC4's 480 s ceiling; falsified by a warmup overrun that the 120 s probe budget does not absorb.
- 2026-07-27: criteria audit ([O], fresh context) returned three defective criteria — AC4's unsatisfiable "at least half", AC3's token list omitting `start_daemons(`, AC6's teardown-silence holding pre-fix — plus AC1 unbuildable where M14 left the reporter and a fourth daemon file omitted; all fixed before the gate.

## Decisions

## Review

Fresh evidence, gathered 2026-07-27 on `m16-suite-worst-case-budget` at PR #15.

- **AC1** — `test-hang-trace.R` 3 tests / 11 assertions pass. Emitted lines observed
  directly: `start test-demo.R`, `start test-demo.R :: alpha block`,
  `end test-demo.R :: alpha block`, same pair for `beta block`, `end test-demo.R` —
  per-test markers named and paired, bracketed by the per-file markers M14 ships.
  The class is reachable from a test file (the tests import it from the helper),
  and `R CMD check` passing proves the runner's `source()` resolves.
- **AC2** — `benchmarks/test-time-budget.R` runs and prints per-file totals over a
  ledger of 47 rows covering all four daemon files plus `helper-parallel.R`, each
  with `file:line`, seconds and payer. The summing convention is stated in the
  ledger header and in the report's own output.
- **AC3** — verified by inversion, not by a green run. Deleting the ledger row for
  `test-parallel-classify.R:38` makes the guard FAIL naming exactly that site;
  restoring it returns 8/8 green. The reverse direction (a row pointing at no call)
  is a second test. A `expect_gt(length(found), 20L)` floor stops the guard passing
  by finding nothing.
- **AC4** — measured 408.7 s for `test-parallel-classify.R`, against the 480 s
  ceiling and a recorded 1008.7 s pre-M16 figure: under the ceiling and under half.
  Verified by inversion too — restoring `WARM_DAEMONS_BOUND_S` to 180 s makes both
  assertions fail. The other three files are reported without a ceiling
  (identity 1200.0, interrupt 255.0, detection 120.0) and identity carries its
  candidate-row cross-reference in the ledger.
- **AC5** — `test-parallel-classify.R:236` binds `tcp://127.0.0.1:0`; no hardcoded
  port remains in the file. The test's own assertions are unchanged and the whole
  file passes (94 assertions, 0 failures).
- **AC6** — positive observation, not teardown silence. By execution: without the
  cancel the task is still unresolved after `daemons(0)` (TRUE — the orphan);
  with it, resolved (FALSE). Positive control: a deliberately leaked pool makes
  `teardown-zz-nothing-survives.R` fire, so its silence is informative. The
  `on.exit` cancel is registered with `after = FALSE`, ahead of the pool teardown.
- **AC7** — `devtools::test()` 1233 pass / 0 fail / 0 warn / 0 skip.
  `devtools::check()` Status OK, 0 errors / 0 warnings / 0 notes.
  `devtools::document()` no diff; `pkgdown::check_pkgdown()` no problems; no
  README.Rmd to knit; no NEWS entry owed (nothing user-visible changed).
  `benchmarks/stress-daemon-ledger.md` carries the dated superseding note.

**Consistency gate.** `cairn_validate` all checks passed (exit 0). Toolchain slot
(`r-package`): document no-diff, pkgdown clean, full check clean, changelog not
owed. No `DESIGN.md` principle changed, so `cairn_impact` is not run.

**Returns:** none. This is M16's first pass through review.

**Independent review — three lenses, then a Sonnet scorer.**
The [O] diff-bug lens independently re-derived the parse-token census (48 rows,
one per wait-shaped token across all five files) and the arithmetic (408.678
post, 1008.678 pre) — both reconcile — and verified the mirai claims by
execution. The [S] blame-history lens found nothing undone: every cut is named in
Scope and reasoned in the work log, and D-021's substance is untouched by the
reporter's move. The [S] prior-review lens found no regression; its probe showed
the repo has no inline PR comments at all, so `milestones/archive/` was the only
surface. 5 findings, 1 at or above the action threshold.

**Actioned — F3 (85): the ledger's copied seconds were unchecked while its header
claimed they could not drift.** Only the constant-derived rows were drift-proof;
108.7 s of classify's 408.7 s were literals copied from call-site arguments, and
raising `daemons_load_status(timeout = 60000)` to `600000` left every guard green
with the printed total frozen. Fixed three ways: `start_mixed_daemons()`'s bound
is now the named constant `MIXED_DAEMONS_BOUND_S` (it lived in the very file the
comment promised could not drift); a new test re-reads each explicit `timeout =`
/ `seconds =` argument from source and fails when the row disagrees (verified by
inversion — raising :496 to 600000 now reports "declares 60 s but the call site
says 600 s"); and the header now states which rows are constant-derived, which
are copied-and-checked, and the two the cross-check cannot reach.

**Logged below threshold, not actioned (4).**
- F1 (58) — the guard's `setdiff()` deduplicates, so two wait calls collapsed onto
  one physical line would be satisfied by a single ledger row. Real but
  narrow-trigger; no such pair exists today.
- F2 (25) — `BUDGETED_FILES` is a fixed five-file list, so a new daemon test file
  would go unbudgeted silently. AC3 enumerated those files by name, so this is
  future-proofing beyond what was asked.
- F4 (30) — the ledger does not charge `R/parallel.R:91`'s unbounded
  `collect_mirai()`. Already named with rationale in `test-suite-hygiene.R` and
  ruled out by Scope Out; a third statement would be redundant.
- F5 (40) — the reporter prints no grand total and does not remark that identity's
  1200.0 s equals the cap. The Review section states it verbatim; AC4 sets no
  ceiling there by design.

**Side effect worth recording.** The bound cuts reach every daemon file, not only
the localized one: declared worst case across the four fell 4743.7 s -> 1983.7 s.
`test-parallel-identity.R` is 1200.0 s, exactly the 20-minute job cap, and stays
the subject of its own candidate row.
