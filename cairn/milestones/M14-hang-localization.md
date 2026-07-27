# M14: A hang says where it happened

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Branch/PR:** `m14-hang-localization`

## Goal

When the test suite stops making progress, the surviving CI log names the test
file it stopped in, and nothing the fixtures start outlives the suite.

## Scope

**In:** A per-file progress line, emitted unbuffered from the running test
process so it survives a job killed mid-suite; a committed check that every
mirai wait under `tests/` routes through the bounded collector rather than a
blocking one; establishing by execution whether the hand-spawned daemon
fixtures actually orphan `Rscript` processes, and closing that only if they do;
a suite-end assertion that no daemon pool or fixture-spawned process survives;
and a stress harness, runnable locally and on demand against macOS CI, that
loops the daemon-using files to attempt reproduction.

**Out:** Any change to `R/` — the confirmed defect where an interrupted run
leaves folds executing is M15, and the standing refusal of a per-fold time
limit (`R/nested-tune-grid.R:153-157`) is untouched by both. Bounding the test
that drives a real dispatch: `setTimeLimit()` cannot interrupt a blocked mirai
collect (established at this plan's gate), and the subprocess route needs
`callr` in Suggests, declined at that gate — the CI cap plus AC1's line is the
answer instead. Diagnosing the hang's actual cause, which stays a `candidate`
row until something localizes it. Sharing one daemon pool across
`test-parallel-identity.R` — its own existing candidate row.

## Acceptance criteria

- [ ] AC1 A reporter passed from `tests/testthat.R` writes one unbuffered line
      to `stderr()` at the start and end of every test file, naming the file and
      an absolute timestamp. Evidence: a local `R CMD check` killed mid-suite
      whose surviving `testthat.Rout` names the last file started and carries no
      end line for it. The evidence records whether helper, setup, and teardown
      files are covered, since testthat exposes no per-file hook for them.
- [ ] AC2 A committed check fails when any mirai wait under `tests/` does not
      route through `collect_bounded()` (`helper-parallel.R:17`) — including the
      blocking `[` collect at `test-parallel-classify.R:33`, which this
      milestone converts. Proven by inversion: reintroducing a direct wait turns
      the check red, and the inversion is recorded in the Review section.
- [ ] AC3 A committed probe establishes by execution, against a named mirai
      version, whether an `Rscript` daemon spawned by `start_mixed_daemons()`
      (`helper-parallel.R:129-138`) survives its host when the fixture's failure
      path is taken. If it survives, the fixture records and kills its spawned
      PIDs and a test asserts they are gone; if `autoexit` already reaps it, the
      probe's recorded output is the evidence and the fixture is unchanged.
- [ ] AC4 A `teardown-` file sorting after every other teardown file fails the
      suite when a daemon connection, or a process AC3 found to survive,
      outlives the last test file. Proven by inversion: leaving a pool up turns
      the suite red. Its failure surfaces as an error after the testthat
      summary, and the evidence states that it cannot fire when a test file
      hangs.
- [ ] AC5 A stress harness outside the built package (`.Rbuildignore`d) runs the
      three daemon-using test files in a fresh R process per iteration, kills any
      iteration exceeding a per-iteration deadline and records it as a hang
      rather than waiting on it, and reports per-file wall-clock. A
      `workflow_dispatch`-only macOS workflow runs the same harness on CI, where
      the hang has actually occurred. Its ledger over at least 50 local
      iterations and at least one CI invocation is committed, and the ROADMAP's
      diagnosis candidate row is rewritten to what the ledger showed —
      to the reproduction if it reproduced, and otherwise to the iteration count
      and platforms that failed to, so the next attempt does not repeat this one.
- [ ] AC6 `cairn/PROFILE.md`'s `test-doctrine` slot replaces its claim that the
      20-minute cap "caps a hang, never diagnoses one" with what localizes one
      after this milestone, and states the bound this milestone did not get —
      that no R-side deadline interrupts a wedged mirai collect.
- [ ] AC7 The `verify` slot is clean: `devtools::test()` passes, and
      `devtools::check()` is clean (0 errors, 0 warnings; NOTEs justified).

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T4
- AC5 → T5, T6, T7
- AC6 → T8
- AC7 → T1, T2, T3, T4, T5, T6, T8

## Tasks

- [x] T1 Add a reporter to `tests/testthat.R` wrapping the check reporter,
      writing `start`/`end` lines to `stderr()`; verify by killing a local
      `R CMD check` mid-suite and reading the surviving `testthat.Rout`.
- [x] T2 Convert `test-parallel-classify.R:33`'s `[` collect to
      `collect_bounded()`; add the source-scanning check and red it by
      inversion.
- [x] T3 Write the orphan probe against `start_mixed_daemons()`'s failure path;
      fix the fixture only if the probe shows a survivor.
- [x] T4 Add the last-sorting `teardown-` file; red it by leaving a pool up.
- [ ] T5 Write the stress harness with its per-iteration kill deadline; add the
      `.Rbuildignore` entry.
- [ ] T6 Add the `workflow_dispatch`-only macOS workflow invoking the harness;
      run it once. Keep the four `paths-ignore` blocks `.github/ci-usage.py`
      compares in agreement.
- [ ] T7 Run the harness locally to 50 iterations; commit the ledger and rewrite
      the ROADMAP candidate row to what it showed.
- [ ] T8 Correct the `test-doctrine` slot.

## Work log

- 2026-07-27: created by /milestone-plan.
- 2026-07-27: plan gate chose the CI cap plus a progress line over a bounded subprocess for the real-dispatch test, because bounding it needs `callr` in Suggests and `setTimeLimit()` was shown by execution not to interrupt a blocked mirai collect; falsified by a bound that works without a new dependency, or by the maintainer accepting the dependency later.
- 2026-07-27: plan gate chose a harness that runs both locally and on macOS CI over a local-only one, because the hang has occurred only on CI and a clean local result would prove little; falsified by a local reproduction, which would make the CI leg redundant.
- 2026-07-27: plan chose an unbuffered stderr line from a `tests/testthat.R` reporter over per-file edits or a stdout line, because R buffers stdout to file and a killed process loses the tail — the recipe-failure lines that did survive the real hang came through stderr; falsified by evidence that stdout is flushed per line under `R CMD check`.
- 2026-07-27: plan chose a probe-then-fix shape for the orphan `Rscript` daemons over asserting the leak outright, because `mirai::daemon()` defaults to `autoexit = TRUE` and the leak is unestablished; falsified by the probe finding a survivor, which converts it to a fix.
- 2026-07-27: T1 done. `HangTraceReporter` in `tests/testthat.R` writes a timestamped start/end line per test file to `stderr()`, beside `CheckReporter` in a `MultiReporter`. AC1 evidence: a local `R CMD check` whose test process was killed at 19:22:50 left a `testthat.Rout.fail` ending `start test-nested-results-plot.R` with no matching end, every earlier file paired.
- 2026-07-27: T3 done, and it answers no. `benchmarks/probe-daemon-orphans.R` on mirai 2.7.2 / nanonext 1.10.1: both hand-spawned daemons gone after the host was torn down, `survivors after teardown: none`. `autoexit = TRUE` reaps them, so `start_mixed_daemons()` is unchanged — the suspected orphan leak was an assumption, and asserting it would have added a green test that proved nothing. The probe also reproduced the RR03/M07 startup death in passing: only 1 of 2 connections was reached, the empty-library daemon dying before it could dial.
- 2026-07-27: T4 done. `teardown-zz-nothing-survives.R` errors when the suite finishes with any daemon connection up, sorting after `teardown-fixture-cache.R` so it cannot suppress that report. Inversion: a probe test leaking `daemons(1)` failed the run with the intended message. Its process half is dropped on T3's finding — there is nothing to count.
- 2026-07-27: T2 done. `collect_bounded()` now takes a single mirai as well as a map, `test-parallel-classify.R`'s bare `[` collect routes through it, and its `on.exit` teardown is registered before the pool it tears down. `test-suite-hygiene.R` checks the rule over parse tokens rather than text, so the comments naming `map[]` and `collect_mirai()` are not findings. Inversion: restoring the `[` collect failed the check at `test-parallel-classify.R:38`.
- 2026-07-27: implementation gate chose declaring `R6` in Suggests over the stock `ProgressReporter$new(file = stderr())`, because the latter carries no clock and the .Rout dump reaches the job log with every line stamped alike; recorded as D-021; falsified by a reporter hook that timestamps without a subclass.
- 2026-07-27: two mechanism corrections found by execution before they could ship — `check_reporter()` returns the string "Check" and not an object, so `MultiReporter` needs `CheckReporter$new()`; and R6 members are locked, so replacing a method on a stock `Reporter` instance is not an available route to avoiding the dependency.
- 2026-07-27: criteria audit (fresh-context [O], pre-gate) returned findings on 6 of 7 drafted criteria; fixed before the gate: the stderr/reporter mechanism, the inverted routes-through-`collect_bounded()` check replacing an ungreppable ban, the orphan claim demoted to a probe, the harness's per-iteration kill and `.Rbuildignore` entry, the last-sorting teardown file, and a non-reproduction obligation split out as AC6.

## Decisions

## Review
