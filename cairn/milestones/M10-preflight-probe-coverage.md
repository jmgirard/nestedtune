# M10: The startup check inspects every worker and says what went wrong

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP3
- **Branch/PR:** `m10-preflight-probe-coverage`

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

- [x] T1: Establish by execution how to reach every daemon — whether
      `mirai::everywhere()` returns per-daemon results and honours a timeout,
      versus submitting one probe task per connected daemon. Bound every probe
      used, including the exploratory ones. Record the finding.
- [x] T2: Failing tests first, in `tests/testthat/test-parallel-classify.R`:
      all-good answers pass; one bad answer aborts naming how many daemons
      could not load; no answer in time aborts with the distinct message.
- [x] T3: Rewrite `daemons_can_load()` to return a three-way outcome (all
      loaded / some cannot load / no answer in time) and branch
      `check_daemons_can_load()`'s `cli_abort()` on it. Keep the outcome
      injectable as an argument, as `ok` is today, so both failure branches stay
      reachable without breaking a library path. (Renamed to
      `daemons_load_status()`: it returns a record, not a yes/no.)
- [x] T4: Read the bound from `getOption("nestedtune.preflight_timeout",
      30000L)`, validate it, and test unset/raised/lowered/invalid. Add the
      formals-unchanged assertion.
- [x] T5: The real mixed-pool test in `test-parallel-detection.R`: two daemons,
      differing `R_LIBS`, `skip_on_cran()`, bounded so a failure errors rather
      than hangs.
- [ ] T6: Inversion pass on each guard; roxygen bullet + `NEWS.md`;
      `devtools::document()`, then `devtools::test()` and `devtools::check()`
      clean.

## Work log

- 2026-07-26: created by /milestone-plan — promotes the M07 review candidate rows scored 68 and 60; the option-not-argument choice was settled at the plan gate and recorded as D-020.
- 2026-07-26: T1 — `mirai::everywhere()` returns a `mirai_map` with one element per connected daemon (distinct pids at n=3, verified), queues behind a busy daemon rather than skipping it, and answers plain `FALSE` where the package is absent; it carries no `.timeout`, so the bound is a poll on `unresolved()` to a deadline then `stop_mirai()`, after which every element collects as `errorValue` 20 (M09's allowlisted ECANCELED) and the pool stays usable — all verified by execution under a shell-level timeout.
- 2026-07-26: T1 — AC1 names RR03 Q5's `R_LIBS` mechanism for the mixed pool; verified insufficient where packages live in the *site* library (both daemons still loaded the target). `R_LIBS_SITE` **and** `R_LIBS_USER` pointed at a scratch library holding only symlinked mirai+nanonext gives a daemon that starts yet cannot load the target. Differing library paths — AC1's substance — is unchanged; the env var is corrected.
- 2026-07-26: implement question gate — condition-class structure, mixed-pool reporting, and `Inf` refusal settled; recorded as M10-D1 and M10-D2.
- 2026-07-26: T2, T3 — `daemons_can_load()` replaced by `daemons_load_status()` + `preflight_outcome()` + `loaded_answer()`, reaching every daemon through `everywhere()` and classifying each answer TRUE / FALSE / no-answer; `check_daemons_can_load()` branches on that record with M10-D1's two class pairs. Renamed because it now returns a record rather than a yes/no. Answers are read per element from `$data` rather than by collecting the map, since collecting blocks until every element resolves — so the bound holds however mirai behaves.
- 2026-07-26: T4 — bound read from `getOption("nestedtune.preflight_timeout", 30000L)` and validated; unset, raised, lowered, invalid, and `Inf` all tested, plus a literal `formals(nested_tune_grid)` assertion (D-018).
- 2026-07-26: T5 — the real heterogeneous pool lands in `test-parallel-detection.R` via `lean_library()` + `start_mixed_daemons()`; passes with two daemons on differing library paths, `setTimeLimit()`-bounded and asserting its own 150 s bound. Whole parallel suite: 103 assertions, 0 failures, 0 skips with `NOT_CRAN` set.
- 2026-07-26: two test defects found while landing the above — M07's unresponsive-pool test pointed at a URL reporting *zero* connections, so it never reached the deadline path at all (replaced by a connected-but-busy daemon, which does), and an `options()["name"]` restore names its element `NA` when the option is unset, leaking the last bad value into every later test in the file.

## Decisions

### M10-D1 (2026-07-26): Two named causes under one shared class, and a mixed pool names both

The pre-flight outcome is now per-daemon, so a pool can fail two ways at once.
Settled at the implement gate: a genuine load failure aborts with class
`c("nestedtune_daemons_cannot_load", "nestedtune_daemons_unusable")`, a
non-answer with `c("nestedtune_daemons_no_response",
"nestedtune_daemons_unusable")`, and a pool showing both aborts on the
load-failure class with one message naming both counts — installing is the
actionable fix, and staying silent on the non-answer would only make the user
rediscover it after fixing the install. Rejected: two sibling classes with no
shared parent (nothing left to catch for "the check failed"); subclassing the
timeout under `nestedtune_daemons_cannot_load` on M09's cancelled/interrupted
precedent (a timeout would then answer to a name asserting it could not load —
the exact confusion this milestone exists to fix). The existing class name keeps
its meaning, so a handler written against M07 still works.

### M10-D2 (2026-07-26): The pre-flight timeout must be finite

`getOption("nestedtune.preflight_timeout")` refuses `Inf` alongside non-positive
and non-numeric values. AC3 names only the latter two, and `Inf` is both numeric
and positive — but honouring it would let a user switch the bound off entirely,
reinstating the unbreakable hang the bound exists to convert into an error
(M07's 39-minute `R CMD check`). A user needing longer sets a large finite
value, which serves the same need without giving up AC4. This adds a guard to
AC3 rather than changing what it demands.

## Review
