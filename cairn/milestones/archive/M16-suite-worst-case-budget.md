# M16: The suite's worst case fits inside the CI budget

**Status:** done (2026-07-27, PR #15 https://github.com/jmgirard/nestedtune/pull/15)

**Goal:** The daemon tests' worst case is a declared number that fits well inside
the CI job cap, and a run that stops names the test it stopped in.

**Outcome:** The 2026-07-27 stall was probably never a wedge — `test-parallel-classify.R`
typically runs 12.0 s but its declared waits permitted **1008.7 s** against a 20-minute cap,
so it was running its own legal worst case. Both structural suspects died by execution at the plan
gate: a busy port errors in 0.03 s, and `daemons(0)` returns in 0.21 s with a live task (explaining
the orphan `R`, not the stall). `tests/testthat/helper-time-budget.R` now declares every wait bound with
its `file:line`, and three guards fail on an unbudgeted call, a stale row, and a bound drifted from its
call site. Cuts — prime 120→60 s, warm 180→60 s, the probe option 300→120 s, an explicit bound on the
largest wait (300 s inherited invisibly) — took classify **1008.7→408.7 s** and all four daemon files
**4743.7→1983.7 s**. `HangTraceReporter` moved to a helper (a test cannot see what the runner defines) and
gained per-test markers, so a killed job's last unmatched `start` names the block. Plus an ephemeral port
for the hardcoded 45997, and a cancel a failed assertion cannot skip.

**Decisions:** none promoted; D-020 and D-021 untouched — only the test helper's settings moved.

**Review:** Three lenses, 5 findings, 1 actioned. F3(85) the ledger's copied seconds went unchecked while its
header claimed they could not drift — fixed with a named constant, a call-site cross-check verified by
inversion, and an honest header. F1(58)/F2(25)/F4(30)/F5(40) logged. Corrected the record: testthat *does*
expose `start_test`/`end_test`. Standing: identity declares 1200.0 s, exactly the cap.
