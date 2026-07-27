# Stress ledger, and the run that finally located the hang

Two records (M14 T7 / AC5). The deliberate hunt found nothing; an ordinary CI
job on M14's own pull request found everything.

## The localization — PR #13, 2026-07-27

`test-coverage` on ubuntu, run 30303761053, cancelled by the 20-minute cap.
M14's `HangTraceReporter` was in place, and the surviving log ends:

```
[hang-trace] 2026-07-27T20:46:35.534 start test-parallel-classify.R
```

with no matching `end`. All 20 files before it paired cleanly, the last being
`test-nested-tune-grid-rng.R` at 20:46:35.533. **The suite sat in
`test-parallel-classify.R` from 20:46:35 until the cap killed the job at
21:03:15 — about 17 minutes.** The job's cleanup then reported
`Terminate orphan process: pid (6158) (R)` alongside two `sh`, the same orphan
signature the first occurrence left on 2026-07-27.

Three prior occurrences produced no such evidence at all: everything before the
suite passing, `* checking tests ...`, then silence. This is the first one that
says where.

What it rules out: the bare `[` collect this same milestone removed from that
file. The wedge happened on a tree that already carried the fix.

What it does not yet distinguish, all inside that one file:

- the fixed-port pool at `:213`, `mirai::daemons(url = "tcp://127.0.0.1:45997")`
  — a hardcoded port, unavailable or in `TIME_WAIT` on a reused runner;
- the busy-pool test at `:160-201`, whose racy `expect_lt(elapsed, 15)` aborts
  the block before its own `mirai::stop_mirai(busy)`, tearing a pool down with a
  live 20-second task outstanding and the time limit already lifted;
- the suite-wide `options(nestedtune.preflight_timeout = 300000L)`
  (`helper-parallel.R`), which lets a degraded pool burn five minutes per
  dispatch without technically hanging.

The next instrumentation step is per-*test* granularity within that file.
testthat exposes no per-test hook a reporter can use for this, so the file
carries it by hand.

## The deliberate hunt — 50 iterations, nothing

Run twice, because the first shape was wrong.

**First attempt (superseded).** `test_local()`, one test file per process,
pkgload-loaded: 50 iterations × 3 files = 150 runs, 0 hangs, 57 minutes. M14's
review found the shape did not match the failure — under `R CMD check` the
package is *installed* (so `prime_daemons()` is a no-op rather than real work)
and every test file shares *one* process (so each daemon file inherits the pool
state its predecessors left). Neither held here, and the localization above
confirms the concern was the right one: the wedge is in a file this harness ran
in isolation.

**Second attempt.** All three daemon files together in one process per
iteration, against an installed copy — what `test_check()` does. 50 iterations,
600 s kill deadline, macOS `aarch64-apple-darwin25.4.0`, R 4.6.1, mirai 2.7.2 /
nanonext 1.10.1. Median 22.6 s per iteration, 122 passing assertions each, 0
skipped. Result recorded below.

A note on why the second shape is also faster: with the package installed,
`prime_daemons()` stops loading it into every daemon by hand. That the faithful
configuration is the cheaper one is convenient and was not the reason for it.

## What the hunt does and does not establish

It does not clear the code, and after the localization it is clearly the weaker
of the two records here. What it prices is the local route: an intermittent
wedge that four CI occurrences produced did not reproduce in 50 faithful local
iterations, so volume on a maintainer's machine is not the lever. The
instrumented CI job is.
