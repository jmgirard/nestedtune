# M52: The test suite runs its files in parallel and fits its CI caps with headroom

- **Status:** planned
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Branch/PR:** —

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

- [ ] T1: Record the baseline in the work log: per-file seconds from
      `benchmarks/profile-tests.R 1` on this machine (serial) and from the
      `[hang-trace]` lines of the last green `test-coverage` run (33710255888),
      and the check-step durations of run 33715373356 — one line each.
- [ ] T2: `HangTraceReporter` (`tests/testthat/helper-hang-trace.R`) declares
      `capabilities = list(parallel_support = TRUE, parallel_updates = FALSE)`;
      `test-hang-trace.R` asserts it and that the `MultiReporter` composed as
      `tests/testthat.R` composes it reports parallel support. In parallel mode
      the reporter runs in the parent, so its lines still reach the parent's
      stderr; verify by execution before writing the assertion.
- [ ] T3: `DESCRIPTION` gains `Config/testthat/parallel: true` and
      `Config/testthat/start-first:` naming the slowest files from T1;
      `benchmarks/profile-tests.R` sets `TESTTHAT_PARALLEL=FALSE` so it keeps
      measuring serial per-file cost. Run AC4's command on both branches at
      `TESTTHAT_CPUS=4`; fix what the parallel run reveals (a helper assuming
      one process, a shared path, a port) — each fix one work-log line.
- [ ] T4: Contention: run `devtools::test()` three times at `TESTTHAT_CPUS=4`;
      an elapsed-bound assertion that fails (`test-parallel-classify.R:268`,
      `test-parallel-detection.R:104`, the metrics-delivery ceiling) gets its
      bound revisited with `helper-time-budget.R`'s row re-pointed in the same
      commit and a work-log line naming the old and new figures — never
      loosened silently.
- [ ] T5: Both workflows set `TESTTHAT_CPUS` — 4 on ubuntu and windows, 3 on
      macOS, via a `matrix.config.os` ternary in `R-CMD-check.yaml`; the covr
      job's subprocess inherits it. Compare the PR's Codecov total with the
      default branch's last figure (work-log line); a drop past one percentage
      point means covr lost a worker's counters and is a defect to fix, not to
      note.
- [ ] T6: Measure on the PR head: read AC1 and AC2 from `gh run view --json
      jobs`, then `gh run rerun` twice for AC3 — pushing nothing in between,
      since every push restarts the matrix (M50 lesson).
- [ ] T7: Records: the PROFILE test-doctrine slot states the parallel setting,
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

## Decisions

## Review
