# M14: A hang says where it happened

**Status:** done (2026-07-27, PR #13 https://github.com/jmgirard/nestedtune/pull/13)

**Goal:** When the suite stops making progress, the surviving CI log names the
test file it stopped in, and nothing the fixtures start outlives the suite.

**Outcome:** `HangTraceReporter` (`tests/testthat.R`) writes a timestamped start/end
line per test file to unbuffered `stderr()`, surviving a kill where the buffered check
reporter does not. **It caught the hang during this milestone's own review** — PR #13's
coverage job died at the 20-minute cap, its log ending `start test-parallel-classify.R`
with no `end`, locating a wedge three prior occurrences left no trace of. Also: every
mirai wait under `tests/` routes through `collect_bounded()`, enforced by
`test-suite-hygiene.R` over parse tokens; `teardown-zz-nothing-survives.R` fails on a
surviving pool; `probe-daemon-orphans.R` disproved the suspected orphan leak; a stress
harness and an on-demand macOS workflow hunt it — 50 iterations, 0 hangs.

**Decisions:** D-021 (`R6` to Suggests; the stock `ProgressReporter` has no clock).
AC5 amended at a gate — GitHub will not dispatch a workflow absent from the default
branch, so the first macOS run is owed post-merge.

**Review:** Three lenses, 12 findings. Actioned F2(86) harness used `test_local` where
the hang needs `test_check`'s installed one-process shape, F12(86) stale ROADMAP line
refs, F1(84) scan missed `call_mirai`, F4(80) a run that tested nothing reported clean.
Five sub-threshold fixed, two being PROFILE clauses a prior review installed.
