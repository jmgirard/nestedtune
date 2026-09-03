# M52: The test suite runs its files in parallel and fits its CI caps with headroom

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Branch/PR:** `m052-parallel-test-files`

## Goal

The suite's CI legs finish well inside their caps by running test files in
parallel, with the hang trace and the daemon guards intact.

## Scope

**Tier:** internal — tests, the test runner and the two CI workflows; no
external consumer of the repo relies on any of it.

**In:** `Config/testthat/parallel: true` and a `Config/testthat/start-first`
list in `DESCRIPTION`; `HangTraceReporter` declaring parallel support so the
`MultiReporter` in `tests/testthat.R` keeps running under `R CMD check`;
`TESTTHAT_CPUS` set per runner in `.github/workflows/R-CMD-check.yaml` and
`.github/workflows/test-coverage.yaml`; any daemon test whose elapsed bound
fails under CPU contention revisited with its budget row re-pointed in the
same commit; `benchmarks/profile-tests.R` pinned to serial so its per-file
figures keep the baseline's conditions; the PROFILE test-doctrine slot stating
the setting and where the worker count is set. Baseline at plan time (2026-09-03,
last green runs): `test-coverage` step 17m10s against a 20-minute job cap, the
suite 1013s of it under covr; `check-r-package` step 26.9 min on windows, 25.2
devel, 21.7 ubuntu release, 18.0 oldrel-1, 15.5 macOS, against a 30-minute step
cap; local serial `devtools::test()` over 10 minutes.

**Out:** raising any `timeout-minutes` — the M16/M48 lesson; the fallback if
AC1 or AC2 misses is a gated amendment, not a silent cap move. Trimming the
Bayesian, racing and annealing fixtures, and sharing one mirai pool across
`test-parallel-identity.R` → the standing pool-sharing candidate row (M12 Out),
left with its own promotion condition. The M34 row's four review findings →
that row, which this milestone trims to them. Cutting the PR matrix → its own
row. The CI-records row (three workflows, cap numbers in PROFILE) → unchanged
beyond the sentences this milestone adds.

## Acceptance criteria

- [ ] AC1: On the milestone's PR head, the `test-coverage` workflow's
      `Test coverage` step completes with conclusion `success` in 12 minutes or
      less, read as `completedAt - startedAt` from
      `gh run view <run-id> --json jobs`.
- [ ] AC2: On the same PR head, every leg the `R-CMD-check` workflow's
      `gh run view <run-id> --json jobs` lists completes its
      `Run r-lib/actions/check-r-package@v2` step with conclusion `success` in
      20 minutes or less, read the same way.
- [ ] AC3: The `R-CMD-check` and `test-coverage` workflows are green on three
      runs of the milestone's final head — the PR's own run and two
      `gh run rerun` of it — with no job cancelled at a `timeout-minutes` cap.
- [ ] AC4: `as.data.frame(testthat::test_local(".", reporter =
      testthat::ListReporter$new()))` on the branch reports zero failures, and
      its rows with `skipped > 0` equal, by `file` and `test`, the rows the
      same command reports on the default branch at the branch point.
- [ ] AC5: Under `devtools::check()`, the check directory's
      `tests/testthat.Rout` carries a `[hang-trace] … start <file>` line and a
      matching `end <file>` line for every file
      `list.files("tests/testthat", "^test-.*\\.R$")` names.
- [ ] AC6: `devtools::document()` produces no diff; `devtools::test()` and
      `devtools::check()` report 0 errors and 0 warnings.

## Coverage

- AC1 → T3, T5, T6
- AC2 → T3, T5, T6
- AC3 → T4, T6
- AC4 → T3, T4
- AC5 → T2, T3
- AC6 → T3, T4, T7

## Tasks

- [x] T1: Record the baseline in the work log: per-file seconds from
      `benchmarks/profile-tests.R 1` on this machine (serial) and from the
      `[hang-trace]` lines of the last green `test-coverage` run (33710255888),
      and the check-step durations of run 33715373356 — one line each.
- [x] T2: `HangTraceReporter` (`tests/testthat/helper-hang-trace.R`) declares
      `capabilities = list(parallel_support = TRUE, parallel_updates = TRUE)`
      and prints each `start` on first sight and each `end` once, since live
      mode re-announces the file and block before every forwarded event;
      `tests/testthat.R` composes its reporter through a helper function that
      sets `parallel_updates` on the composite, and `test-hang-trace.R` asserts
      both declarations and one live start/end pair per file and block under a
      two-worker run.
- [x] T3: `DESCRIPTION` gains `Config/testthat/parallel: true` and
      `Config/testthat/start-first:` naming the slowest files from T1;
      `benchmarks/profile-tests.R` sets `TESTTHAT_PARALLEL=FALSE` so it keeps
      measuring serial per-file cost. Run AC4's command on both branches at
      `TESTTHAT_CPUS=4`; fix what the parallel run reveals (a helper assuming
      one process, a shared path, a port) — each fix one work-log line.
- [x] T4: Contention: run `devtools::test()` three times at `TESTTHAT_CPUS=4`;
      an elapsed-bound assertion that fails (`test-parallel-classify.R:268`,
      `test-parallel-detection.R:104`, the metrics-delivery ceiling) gets its
      bound revisited with `helper-time-budget.R`'s row re-pointed in the same
      commit and a work-log line naming the old and new figures — never
      loosened silently.
- [x] T5: Both workflows set `TESTTHAT_CPUS` — 4 on ubuntu and windows, 3 on
      macOS, via a `matrix.config.os` ternary in `R-CMD-check.yaml`; the covr
      job's subprocess inherits it. Compare the PR's Codecov total with the
      default branch's last figure (work-log line); a drop past one percentage
      point means covr lost a worker's counters and is a defect to fix, not to
      note.
- [x] T6: Measure on the PR head: read AC1 and AC2 from `gh run view --json
      jobs`, then `gh run rerun` twice for AC3 — pushing nothing in between,
      since every push restarts the matrix (M50 lesson).
- [x] T7: Records: the PROFILE test-doctrine slot states the parallel setting,
      the `start-first` list's purpose and where `TESTTHAT_CPUS` is set, beside
      the cap numbers it already carries; `.github/ci-usage-baseline.md` only
      if a number it states changed. No NEWS entry: nothing user-facing moves.

## Work log

- 2026-09-03: created by /milestone-plan. Criteria audit ran in reduced mode
  (internal tier) on a fresh [O] reader: four findings, all the same
  instrument-property clause ("recorded in the Review section") on AC1, AC2,
  AC3 and AC6 — removed, recording moved to the review procedure; AC4
  consolidated onto one command; bounded-promise and proportionality clean.
- 2026-09-03: plan gate chose parallel test files over trimming fixtures and
  sharing the daemon pool because the gain is bounded by the largest file
  rather than by surgery on the IP2 batteries, and over raising the caps
  because the M16/M48 lesson names a leg nearing its cap as a suite to make
  faster; falsified by a CI run at `TESTTHAT_CPUS=4` whose covr step still
  exceeds 12 minutes, or by daemon tests that cannot hold an elapsed bound
  under contention on three runs.
- 2026-09-03: plan gate chose the 12-minute / 20-minute bar over a stricter
  8 / 15 because runner core counts and contention are unmeasured; falsified
  by the PR's first run landing under 8 and 15, which would say the bar was
  slack.
- 2026-09-03: implement started; branch `m052-parallel-test-files` cut from
  the pushed default branch. Gate (one question): the hang trace takes
  testthat's live-update mode, not the burst replay T2 named — measured on a
  three-file fixture at two workers, burst replay stamped a finished file's
  lines within 1 ms of each other and would print nothing for a file that
  never finishes, while live mode kept a 1.0 s sleeping block's start and end
  1.08 s apart. T2's wording refined to match (minor amendment).
- 2026-09-03: T2 — reporter rewritten with first-sight bookkeeping (live mode
  had printed four to five `start` lines per block and a fresh `start` for a
  block already ended, measured); `check_reporter_with_hang_trace()` builds
  the runner's composite because `MultiReporter` sets `parallel_support` on
  itself and leaves `parallel_updates` at the base default, and testthat reads
  both off the composite. Two tests added; planting `parallel_updates = FALSE`
  on the composite redded both (one failure each), helper restored. Ran green
  serially and nested inside a two-worker run.
- 2026-09-03: T1 baseline, local serial (`benchmarks/profile-tests.R 1` on the
  b0d76a4 tree, R 4.6.1, 18 cores): 1396.7 s over 56 files, wall 1400.9 s;
  bayes-oracles 160.4, parallel-identity 144.5, race-rng 120.8, bayes-rng
  104.9, race-oracles 103.0, bayes-results 73.6, sim-anneal-rng 70.4,
  grid-failures 68.2, sim-anneal-oracles 62.8, grid-oracles 52.7; every other
  file under 41 s.
- 2026-09-03: T1 baseline, covr trace (run 33710255888, `[hang-trace]` file
  pairs): 1013.2 s over 56 files; parallel-identity 154.1, bayes-oracles
  111.2, race-rng 60.0, final-fit-oracles 59.0, bayes-rng 57.4, race-oracles
  48.9, sim-anneal-rng 46.9, bayes-results 41.5, grid-failures 35.3,
  final-fit-rng 32.7, sim-anneal-oracles 31.3, eval-time 30.9; the rest under
  26 s. `Test coverage` step 17m10s.
- 2026-09-03: T1 baseline, check steps (run 33715373356, `completedAt -
  startedAt`): windows 26m56s, devel 25m10s, ubuntu release 21m42s, oldrel-1
  17m59s, macOS 15m32s.
- 2026-09-03: T3 — `Config/testthat/parallel: true` and an eleven-file
  `start-first` list (the ten files over 50 s locally plus final-fit-oracles,
  59 s under covr where the fixture cache is cold), order checked through
  `find_test_scripts()`; `benchmarks/profile-tests.R` sets
  `TESTTHAT_PARALLEL=FALSE`. AC4's command at `TESTTHAT_CPUS=4`: branch 569
  rows, 0 failed, 0 skipped, wall 818 s while the default-branch run shared
  the machine; default branch (scratch worktree of origin/main, serial) 567
  rows, 0 failed, 0 skipped; skip rows equal (both empty), the two extra rows
  the T2 tests. The parallel run revealed nothing to fix.
- 2026-09-03: checkpoint while T4's three runs execute — T5's workflow edits
  (`TESTTHAT_CPUS` 4/4/3 via the os ternary, 4 on the covr job; runner core
  counts read from GitHub's hosted-runner sizes page) and T7's PROFILE
  test-doctrine text (folded into the divergences bullet, header comment
  compressed, 119 lines) landed early; neither task ticks until its remaining
  half (T5's Codecov comparison, T7's ci-usage-baseline decision) is done.
- 2026-09-03: T4 — three `devtools::test()` runs at `TESTTHAT_CPUS=4`, none
  of my other processes running: 569 rows, 4790 expectations, 0 failed, 0
  skipped on every run; walls 648, 495 and 143 s, per-file sums 2497, 1944
  and 555 s against the 1397 s serial baseline — the machine carried other
  load throughout (load average 6–9 read afterwards with two R processes
  alive), so the figures are noise around an unmeasured true cost. No
  elapsed bound failed; `helper-time-budget.R` untouched.
- 2026-09-03: T5 — PR #62 opened at head 02d254a; its
  `test-coverage` run 33725075689 reports `nestedtune Coverage: 97.51%`
  against 97.51% on the default branch's last run 33710255888: no drop, so
  covr kept every worker's counters. The job started 4 test processes and
  the trace paired all 56 files, suite span 533.1 s under covr.
- 2026-09-03: T6, first run on the PR head: `Test coverage` step 9.23 min
  (AC1 bar 12); `check-r-package` steps windows 17.25, ubuntu release 14.52,
  oldrel-1 11.73, macOS 11.60, devel 9.68 min (AC2 bar 20), every leg
  `success`. Neither landed under the plan's 8 / 15 falsifier, so the bar
  stands. AC3's two reruns follow.
- 2026-09-03: T6, AC3 — two `gh run rerun` of both runs, nothing pushed
  between. Attempt 2: coverage step 11.43 min; check legs windows 16.30,
  devel 15.48, ubuntu release 14.82, oldrel-1 14.02, macOS 13.33. Attempt 3:
  coverage 11.87; windows 16.00, devel 14.92, oldrel-1 14.47, ubuntu release
  13.68, macOS 11.62. Every job `success` on all three attempts, none
  cancelled. The coverage step's three readings (9.23, 11.43, 11.87) sit
  inside 0.13 min of the 12-minute bar at worst — headroom on that job is
  thin, and it never gates a merge (PROFILE).
- 2026-09-03: T7 — PROFILE test-doctrine slot text landed in the checkpoint
  commit (divergences bullet now six, hang-trace bullet names the live mode);
  `.github/ci-usage-baseline.md` states run counts and machine-minutes over a
  July window, none of which this milestone changes, so it is untouched; no
  NEWS entry.

## Decisions

- 2026-09-03: The hang trace runs in testthat's live-update mode under
  parallel test files. testthat offers the parent-side reporter two replay
  modes; burst replay (the plan's `parallel_updates = FALSE`) stamps a whole
  file's lines when the file finishes and prints nothing for a file that
  hangs, which is the case the trace exists for. Live mode re-announces the
  file and block before every event, so the reporter prints each `start` on
  first sight and each `end` once; the composite in `tests/testthat.R`
  declares the mode because testthat reads it off the reporter it is handed,
  not off the members. Falsified by a testthat release whose live loop stops
  calling `start_file`/`start_test` before each event, which would make the
  bookkeeping inert but not wrong.

## Review
