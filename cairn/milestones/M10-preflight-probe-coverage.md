# M10: The startup check inspects every worker and says what went wrong

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP3
- **Branch/PR:** —

## Goal

The pre-flight check reaches every connected daemon and distinguishes one that
cannot load the package from one that did not answer in time.

## Scope

**In:** two defects in `daemons_can_load()` / `check_daemons_can_load()`
(`R/parallel.R:110`). The probe submits a single `mirai::mirai()` task, which
one daemon takes — so in a heterogeneous pool (a respawned daemon, differing
library paths) one loadable daemon passes the check for all of them, and the
rest return opaque worker failures. And its one message covers two different
outcomes: a timeout is reported with install-and-prime remedies, telling a user
to install what they already have. The 30 s bound becomes overridable by
`options(nestedtune.preflight_timeout = ...)`, default unchanged (D-020).

**Out:** cancellation classification → M09. Remote daemon pools stay unprobed
beyond what the mechanism reaches (RR03 Q5) — documented, not engineered, and
kept as its own candidate row. Caching the probe across calls is refused, not
deferred: a pool can change between calls, so it runs per parallel dispatch.
Per-fold timeouts stay rejected (RR03 Q4). No argument is added to
`nested_tune_grid()` — D-018's line holds.

## Acceptance criteria

- [ ] AC1: The probe reaches every connected daemon. Evidence is two-layered:
      a unit test at the decision seam with fabricated per-daemon answers (all
      good → pass; one bad → abort), plus one real mixed-pool test that starts
      daemons with differing library paths per RR03 Q5's verified `R_LIBS`
      mechanism, `skip_on_cran()`.
- [ ] AC2: A timeout aborts with a message naming non-response, carrying no
      "install the package" remedy; a genuine load failure keeps the existing
      install/prime remedies. Both branches fired by test, each with its own
      condition class.
- [ ] AC3: `getOption("nestedtune.preflight_timeout")` raises and lowers the
      bound; unset yields 30000 ms; a non-positive or non-numeric value is
      refused with `cli_abort()`. All four tested. `nested_tune_grid()`'s
      formals are unchanged, asserted against a recorded signature (D-018).
- [ ] AC4: Every probe stays bounded — no test in the suite can hang. The real
      mixed-pool test completes within its own stated bound, asserted, so
      M07's 39-minute `R CMD check` hang cannot recur.
- [ ] AC5: Each new guard proven by inversion, recorded in the work log.
- [ ] AC6: The "Parallel execution" roxygen bullet stating a fixed 30 seconds
      (`R/nested-tune-grid.R:135`) is corrected to describe the option and the
      per-daemon coverage; `NEWS.md` entry added.
- [ ] AC7: Profile `verify` slot clean — `devtools::document()` no diff,
      `devtools::test()` and `devtools::check()` clean.

## Coverage

- AC1 → T1, T2, T3, T5
- AC2 → T2, T3
- AC3 → T4
- AC4 → T1, T5
- AC5 → T6
- AC6 → T6
- AC7 → T6

## Tasks

- [ ] T1: Establish by execution how to reach every daemon — whether
      `mirai::everywhere()` returns per-daemon results and honours a timeout,
      versus submitting one probe task per connected daemon. Bound every probe
      used, including the exploratory ones. Record the finding.
- [ ] T2: Failing tests first, in `tests/testthat/test-parallel-classify.R`:
      all-good answers pass; one bad answer aborts naming how many daemons
      could not load; no answer in time aborts with the distinct message.
- [ ] T3: Rewrite `daemons_can_load()` to return a three-way outcome (all
      loaded / some cannot load / no answer in time) and branch
      `check_daemons_can_load()`'s `cli_abort()` on it. Keep the outcome
      injectable as an argument, as `ok` is today, so both failure branches stay
      reachable without breaking a library path.
- [ ] T4: Read the bound from `getOption("nestedtune.preflight_timeout",
      30000L)`, validate it, and test unset/raised/lowered/invalid. Add the
      formals-unchanged assertion.
- [ ] T5: The real mixed-pool test in `test-parallel-detection.R`: two daemons,
      differing `R_LIBS`, `skip_on_cran()`, bounded so a failure errors rather
      than hangs.
- [ ] T6: Inversion pass on each guard; roxygen bullet + `NEWS.md`;
      `devtools::document()`, then `devtools::test()` and `devtools::check()`
      clean.

## Work log

- 2026-07-26: created by /milestone-plan — promotes the M07 review candidate rows scored 68 and 60; the option-not-argument choice was settled at the plan gate and recorded as D-020.

## Decisions

## Review
