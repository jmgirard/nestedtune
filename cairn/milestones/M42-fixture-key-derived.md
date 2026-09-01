# M42: The fixture key's separation test, derived from the orchestrators' own arguments

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Branch/PR:** m042-fixture-key-derived · https://github.com/tidymodels/nestedtune/pull/51

## Goal

The test that pins what the fixture cache's key separates enumerates its
domain from the orchestrators' formal arguments at run time, instead of from
a hand-written list of signatures.

## Scope

Surface tier: internal — the deliverable is test tooling under
`tests/testthat/` that no consumer of the package relies on.

**In:**

- Replace the hand-listed test "the key separates every fixture signature
  this suite asks for" (`tests/testthat/test-fixture-cache.R:231-359`) with
  one whose domain is `setdiff(names(formals(f)), "...")` for each of
  `nested_tune_grid` and `nested_final_fit`: for every formal, two requests
  differing only in that argument key differently under `fixture_key()`.
  Variant values live in a registry keyed by formal name; a formal with no
  registered variant fails the test naming the formal, so the next argument
  added to an orchestrator cannot go unpinned the way `event_level` and
  `eval_time` did.
- A request-time guard in `fixture_key()` (`helper-orchestration.R:846`):
  a request whose arguments' canonical form reaches `canonical_form()`'s
  depth cut (the `"<depth>"` marker, past 40 levels) aborts naming the
  argument. Measured at plan time: the deepest real fixture is 28 levels,
  so today no request trips it.
- The helper header comment that cites the old test
  (`helper-orchestration.R`, the "test-fixture-cache.R pins that" line in
  the `canonical_form()` preamble) describes the derived test instead.

**Out:**

- Redesigning what the key hashes (`canonical_form()`,
  `inside_spec_bindings()`, the RNG state). A collision the derived test
  reveals in a real fixture goes through the implement amendment protocol.
- Pinning that fixture *families* (`det`, `unstable`, `sep`, `cls`, `srv`,
  the `break_*` designs) key apart. No procedure enumerates the families, so
  the milestone does not claim it; the per-argument axes cover what the
  M35 and M41 findings asked for.
- The other findings on the grouped M34 candidate row (the dots-barrier
  probe guard, the suite's wall-clock) stay on that row.

## Acceptance criteria

- [x] AC1: For every formal argument that
      `setdiff(names(formals(nested_tune_grid)), "...")` and
      `setdiff(names(formals(nested_final_fit)), "...")` enumerate at test
      time, `tests/testthat/test-fixture-cache.R` holds a passing
      expectation that two requests to that orchestrator differing only in
      that argument, keyed at the same RNG state, produce different
      `fixture_key()` values.
- [x] AC2: A formal that either enumeration in AC1 yields with no registered
      variant value fails that test with a failure message naming the
      formal.
- [x] AC3: `fixture_key()` refuses a request whose sorted arguments'
      canonical form contains the `"<depth>"` marker, with an error naming
      the offending argument; a unit test in
      `tests/testthat/test-fixture-cache.R` covers an argument nested past
      the cut.
- [x] AC4: The hand-listed test at
      `tests/testthat/test-fixture-cache.R:231-359` is removed, and the
      helper header comment in `tests/testthat/helper-orchestration.R` no
      longer cites it.
- [ ] AC5: The profile's verify slot is clean on the branch:
      `devtools::test()` passes with no failures, and `devtools::check()`
      reports 0 errors, 0 warnings, 0 notes.

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T3
- AC4 → T1, T4
- AC5 → T4

## Tasks

- [x] T1: In `tests/testthat/test-fixture-cache.R`, replace the test at
      lines 231-359 with the derived axis test. A base request per
      orchestrator from the `det_*` family; a `signature_variants` registry
      (named list, one entry per formal, each returning the alternate value:
      `stoch_workflow()` for `object`, `det_nested(d, v = 4)` for
      `resamples`, `narrow_param_info()` for `param_info`, a different grid,
      `NULL` metrics, `"second"` for `event_level`, `1` for `eval_time`).
      The test computes the formals via `setdiff(names(formals(f)), "...")`,
      fails naming any formal absent from the registry, then keys base and
      variant at the same seed per formal and expects distinct keys, for
      both orchestrators. Skip guard as the old test's
      (`skip_if_no_engines(stochastic = TRUE)`).
- [x] T2: Plant two defects and record each red run in the work log before
      restoring: remove `eval_time` from the registry (expect the failure to
      name `eval_time`), and mutate `fixture_key()` to drop `eval_time` from
      `args` before hashing (expect the `eval_time` pair's expectation to
      fail). Both must be red for the reason claimed, not merely red.
- [x] T3: Add the depth guard to `fixture_key()`: scan the canonical form of
      the sorted arguments for the `"<depth>"` marker
      (`rapply(..., how = "unlist")` or a recursive walk) and
      `rlang::abort()` naming the argument that carried it. Unit test with an
      argument nested 41+ levels deep expecting the error and its named
      argument. Run the full `devtools::test()` and confirm no real request
      trips the guard.
- [x] T4: Rewrite the `helper-orchestration.R` preamble line that cites the
      old test; run `devtools::test()` and `devtools::check()`; record
      results in the work log.

## Work log

- 2026-09-01: created by /milestone-plan from the fixture-cache candidate row (M34 finding 5, M35 O3, M41 R6; dispositioned promote-to-milestone at M41's hygiene pass).
- 2026-09-01: criteria audit ran in reduced mode ([O] fresh reader). Two findings: AC3's "full suite run reports no such error" clause bound check output — moved to T3 and the criterion narrowed to the guard plus its unit test; AC4's verify-slot clause likewise flagged — kept as its own AC5 at the gate, on the template's standing mandate.
- 2026-09-01: plan gate chose deriving the axes from `formals()` over extending the hand list because a hand list is fixed by what the author recalled and missed `event_level` and `eval_time` twice; falsified by a key collision on an axis `formals()` does not enumerate (a caller-scoped binding or an RNG-state difference).
- 2026-09-01: plan gate chose deriving the axes over deleting the test outright because the builds report catches duplicate builds, never a wrongly shared one; falsified by the report catching a planted shared-run defect on its own.
- 2026-09-01: plan gate chose a request-time abort in `fixture_key()` over a teardown-time warning for the depth guard because the teardown prints after every assertion has already read a possibly mis-served fixture; falsified by a real fixture legitimately exceeding the cut, which would then need the cut raised rather than the request refused.
- 2026-09-01: plan-time measurement — canonical-form depth of every fixture family's workflow, design and metric set: workflows 22-28, designs 10-12, metric sets 12, the orchestrators 8; no `"<depth>"` marker on any.
- 2026-09-01: T1 — the hand-listed test replaced by the derived axis test (7 formals × 2 orchestrators, each pair keyed at seed 2); the `param_info` variant is built inline from `dials::num_comp()` since no `narrow_param_info()` helper exists. File header comment updated to match.
- 2026-09-01: T2 — defect A (registry without `eval_time`) red: 2 failures, "nested_tune_grid() has formal(s) with no registered variant value: `eval_time`" and the same for `nested_final_fit()`. Defect B (`fixture_key()` drops `eval_time` before hashing) was GREEN on the first test shape: `fixture_key()` forces `args` lazily and `det_nested()` reseeds, so a request built inside the call keyed on RNG state, and two `det_workflow()` builds without a reseed carried different `step_pca()` ids — every pair separated on something other than the axis. Test amended to seed before each build and key pre-built requests; defect B then red on exactly the `eval_time` pair for both orchestrators (2 failures, 45 pass); clean run 47 pass.
- 2026-09-01: T3 — `fixture_key()` scans the sorted arguments' canonical form for `"<depth>"` and aborts (class `fixture_key_depth`) naming the argument(s), located by re-forming each argument alone on the failure path only. Unit test: a 45-level list under `object` errors naming `object`; the 30-level control keys to a 32-hex hash. Guard disabled (`has_depth_marker()` forced FALSE): the error expectation alone red (1 failure, 48 pass). Full `devtools::test()`: no failures, no skips, 43 signatures / 43 builds / 170 requests, no depth error on any real request.
- 2026-09-01: T4 — `canonical_form()` preamble now describes the derived per-formal test. `devtools::test()`: no failures, no skips (run before T3's commit, on the final code). `devtools::check()`: 0 errors, 0 warnings, 0 notes, tests [124s/191s]. Status → review.

## Decisions

## Review

- 2026-09-01, PR #51. Default branch unmoved since the branch was cut (`git fetch`; `main` at cf89a1d, the branch's base).
- AC1 — verified. The test-time enumeration `setdiff(names(formals(f)), "...")` yields `object, resamples, param_info, grid, metrics, event_level, eval_time` for both orchestrators (printed from a fresh `load_all()` session). `testthat::test_file()` on the committed `test-fixture-cache.R`: the derived test passes 16 expectations, 0 failures — one registry check plus seven per-formal distinct-key expectations per orchestrator, each pair keyed at seed 2.
- AC2 — verified. Planted defect run on a scratch copy (the `eval_time` registry entry removed, repo untouched): 2 failures, "nested_tune_grid() has formal(s) with no registered variant value: `eval_time`" and the same for `nested_final_fit()`; 14 other expectations pass.
- AC3 — verified. `fixture_key()` scans the sorted arguments' canonical form for `"<depth>"` and aborts with class `fixture_key_depth` naming the argument (`helper-orchestration.R`, diff read). The unit test "a request nested past the depth cut is refused, naming the argument" passes both expectations: a 45-level `object` errors matching "argument(s) `object` nest past"; the 30-level control keys to a 32-hex hash.
- AC4 — verified. `git diff main..HEAD` removes the test "the key separates every fixture signature this suite asks for" whole; `grep` for its title and for the old preamble phrase "asserts every distinct fixture signature" over `tests/testthat/*.R` returns nothing.
