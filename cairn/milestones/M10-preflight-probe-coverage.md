# M10: The startup check inspects every worker and says what went wrong

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP3
- **Branch/PR:** `m10-preflight-probe-coverage` · https://github.com/jmgirard/nestedtune/pull/10

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

- [x] AC1: The probe reaches every connected daemon. Evidence is two-layered:
      a unit test at the decision seam with fabricated per-daemon answers (all
      good → pass; one bad → abort), plus one real mixed-pool test that starts
      daemons with differing library paths per RR03 Q5's verified `R_LIBS`
      mechanism, `skip_on_cran()`.
- [x] AC2: A timeout aborts with a message naming non-response, carrying no
      "install the package" remedy; a genuine load failure keeps the existing
      install/prime remedies. Both branches fired by test, each with its own
      condition class.
- [x] AC3: `getOption("nestedtune.preflight_timeout")` raises and lowers the
      bound; unset yields 30000 ms; a non-positive or non-numeric value is
      refused with `cli_abort()`. All four tested. `nested_tune_grid()`'s
      formals are unchanged, asserted against a recorded signature (D-018).
- [x] AC4: Every probe stays bounded — no test in the suite can hang. The real
      mixed-pool test completes within its own stated bound, asserted, so
      M07's 39-minute `R CMD check` hang cannot recur.
- [x] AC5: Each new guard proven by inversion, recorded in the work log.
- [x] AC6: The "Parallel execution" roxygen bullet stating a fixed 30 seconds
      (`R/nested-tune-grid.R:135`) is corrected to describe the option and the
      per-daemon coverage; `NEWS.md` entry added.
- [x] AC7: Profile `verify` slot clean — `devtools::document()` no diff,
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
- [x] T6: Inversion pass on each guard; roxygen bullet + `NEWS.md`;
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
- 2026-07-27: T6 — inversion pass: nine guards mutated one at a time, each reddening the test that claims it (per-daemon coverage, the two class pairs, the shared parent class, the mixed-pool extra bullet, finiteness, positivity, the documented default, answer-shape validation, and the `formals()` pin); harness in the session scratchpad, working tree verified identical to HEAD afterwards.
- 2026-07-27: T6 — roxygen "Parallel execution" bullets rewritten for per-daemon coverage, the two causes, the option, and the cold-load cost; `NEWS.md` entries added; `devtools::document()` regenerated `man/nested_tune_grid.Rd`.
- 2026-07-27: `R CMD check` surfaced the fix's real cost — six dispatch tests failed because the probe now waits for every daemon to cold-load the package rather than for whichever was free, exceeding 30 s on a loaded machine. Default held at 30 s per D-020 (M10-D3); documented for users, and the fixtures now warm the daemons and set a generous bound.
- 2026-07-27: verify slot clean on the final tree — `devtools::test()` 1164 passing / 0 failures / 0 skips; `devtools::check()` Status: OK (0 errors, 0 warnings, 0 notes); `cairn_validate` all checks passed.
- 2026-07-27: review — three fresh-context lenses; blame-history and prior-PR-comments returned no findings, diff-bug [O] returned six, all verified by execution. Scorer actioned F1 (85, bound validated lazily so an invalid option dispatched the probe first and the abort named an internal) and F4 (88, a raised bound rendered as "3e+05 ms"). F2/F3/F5/F6 scored below 80 and were fixed anyway — F2 and F5 gated AC3 and AC5 as written, F3 and F6 were false statements in comment and message. F7 (52) rejected with reason.
- 2026-07-27: review — inversion re-run over 14 guards (nine from implement plus five for the review fixes): 14/14 reddened, tree restored. Re-verified on the final tree: `devtools::document()` no diff, `devtools::test()` 1164 passing / 0 failures / 0 skips, `devtools::check()` Status: OK, `cairn_validate` all checks passed.
- 2026-07-26: two test defects found while landing the above — M07's unresponsive-pool test pointed at a URL reporting *zero* connections, so it never reached the deadline path at all (replaced by a connected-but-busy daemon, which does), and an `options()["name"]` restore names its element `NA` when the option is unset, leaking the last bad value into every later test in the file.

## Decisions

### M10-D3 (2026-07-27): The 30 s default stands, and the cold-load cost is documented rather than absorbed

Asking every daemon changed what the bound has to cover. The probe is what
makes each daemon load the package, so the first call against a cold pool now
waits for the slowest cold load rather than for whichever daemon happened to be
free — under `R CMD check` on a loaded machine that exceeded 30 s and failed six
dispatch tests. Considered and rejected: raising the default. D-020 fixed it at
30 s and AC3 pins it; the option exists precisely for environments needing more;
and a default chosen to survive a saturated CI machine would be a poor default
everywhere else. Instead the cost is documented where a user meets it (roxygen
and `NEWS.md`: the first call is the slow one, later calls in the session reuse
what the daemons already loaded), and the fixtures warm the daemons so suite
timing measures dispatch rather than package loading.

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

Reviewed 2026-07-27 on `m10-preflight-probe-coverage` at PR #10. Evidence is
fresh, by command, on the final tree.

**AC1 — the probe reaches every connected daemon.** Both layers executed.
Seam, with fabricated per-daemon answers: "a pool where every daemon loaded
passes" and "one loadable daemon no longer passes the check for the whole pool"
(asserts the abort names "1 of 3"). Real heterogeneous pool: "the probe reaches
every daemon, not just a loadable one" builds two hand-spawned daemons on
genuinely different libraries and asserts total 2 / cannot_load 1 / no_answer 0;
it ran for real (detection file 21 passing, 0 skips, `NOT_CRAN` set). Inversion
"look only at the first answer" → RED. **Deviation recorded:** AC1 names RR03
Q5's `R_LIBS` mechanism; that was verified insufficient where packages live in
the site library — both daemons still loaded the target — so the test uses
`R_LIBS_SITE` + `R_LIBS_USER` + `--vanilla`, and asserts as a precondition that
the two daemons' `.libPaths()` actually differ. The criterion's substance,
differing library paths in a real pool, is met; the named mechanism was wrong.

**AC2 — the two causes are distinct.** "a timeout is not reported as a package
that cannot be loaded" asserts the message carries no `/install/i` and the
condition is `nestedtune_daemons_no_response` and *not*
`nestedtune_daemons_cannot_load`; "a load failure keeps the install and prime
remedies" asserts both remedies survive; "both causes answer to one shared
class" covers the parent. Inversions "the two causes collapse" and "the shared
parent class is dropped" → both RED.

**AC3 — the option raises and lowers the bound.** All four cases tested, plus
`Inf` (M10-D2): unset → 30000; raised → 90000; lowered → 500; refused for
"soon", -1, 0, NA, length-2, TRUE, and Inf. `formals(nested_tune_grid)` pinned
literally to `c("object", "resamples", "grid", "metrics")` (D-018). Review found
the option was evidenced only at the accessor and added "the probe reads its
bound from the option, not from the constant" (F2). Inversions: finiteness,
positivity, moved default, grown signature, and probe-wired-to-constant → all
RED.

**AC4 — every probe stays bounded.** `daemons_load_status()` polls to a deadline,
calls `stop_mirai()`, then reads each element's `$data`, which yields
`unresolvedValue` rather than waiting — so no collect blocks. The test fixtures'
two collects go through `collect_bounded()` for the same reason, and the daemon
tests carry `setTimeLimit()`. The real mixed-pool test asserts its own bound
(`expect_lt(elapsed, 150)`). Verified live rather than by argument: an unbounded
`map[]` in the fixtures did hang the suite past 20 minutes during implement and
was found and fixed. `R CMD check` completed in 4m15s, tests 143s.

**AC5 — each new guard proven by inversion.** 14 of 14 reddened: the nine from
implement plus five added at review (zero-answer guard, probe-reads-the-option,
validate-before-dispatch ordering, package naming, scientific notation). Each
mutation applied to the real file, the one test that claims it run alone, file
restored; working tree verified identical to HEAD afterwards.

**AC6 — docs.** The "Parallel execution" roxygen bullet that stated a fixed 30
seconds is replaced by three bullets covering per-daemon coverage, the two
distinct causes, the option, and the first-call cold-load cost; four `NEWS.md`
entries added. `man/nested_tune_grid.Rd` regenerated.

**AC7 — profile verify slot clean.** `devtools::document()` no diff;
`devtools::test()` 1164 passing / 0 failures / 0 warnings / 0 skips;
`devtools::check()` Status: OK (0 errors, 0 warnings, 0 notes) — run twice, before
and after the review fixes. `cairn_validate` all checks passed.

### Independent review

Three fresh-context lenses. **Blame-history [S]:** no findings — verified M07's
hang bound, M09's `errorValue` 20/19 contract, and the D-011/D-016 identity
assertions untouched. **Prior-PR-comments [S]:** no findings; RR03's BC1, BC3–BC5
and BC8 either untouched or still present verbatim, and the GitHub inline-comment
probe returned empty. **Diff-bug [O]:** six findings, each verified by execution.

Scored by a fresh [S] scorer. Actioned (≥80): **F1 (85)** the bound was validated
lazily, so an invalid option dispatched the probe to every daemon before erroring,
and the abort named the internal `daemons_load_status()` rather than the user's
call — fixed by forcing the bound first and threading `call`. **F4 (88)** a raised
bound rendered as "3e+05 ms" in the very bullet telling the user to raise it —
fixed with `format(scientific = FALSE)`.

Below the 80 threshold, logged; four fixed anyway because two of them gated
criteria as written and two were cheap corrections of false statements: **F2 (76)**
nothing pinned that the probe uses the option — fixed, as AC3 says the option
raises and lowers *the bound*. **F3 (70)** a comment asserted the opposite of
measured behaviour and contradicted its neighbour — corrected. **F5 (68)** the
`total == 0L` guard was never inverted — test added, AC5 says *each* new guard.
**F6 (48)** the abort hard-coded `nestedtune` while the probe takes a `package`
argument, so the mixed-pool test's own abort was false — now names the package
probed. **F7 (52) rejected:** `prime_daemons()`/`warm_daemons()` discard
`collect_bounded()`'s result, so a cancelled prime reads as success. Real but
test-infra only, and the deadlines (120 s / 180 s) do not fire in practice; the
bounded collect already removes the hang it would otherwise cause.
