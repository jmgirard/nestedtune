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
- [x] AC5: The profile's verify slot is clean on the branch:
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

- [x] T5: In `fixture_key()`'s failure path, name a positional deep argument by its position (`` `object` `` where named, `position 2` where not); extend the depth test with a request built the way `memoised()` builds one — the deep value positional — expecting the error to name that position. (M42 review O3.)
- [x] T6: In the derived axis test, state one fact independently of `formals()`: expect `object` and `resamples` among the enumerated axes for both orchestrators, failing naming what is missing; and flag a registry entry with no matching formal, naming it. Plant both defects and record each red run. (M42 review O1, O9.)
- [x] T7: Brace the `nest()` loop so `air format --check` is clean; correct the helper comment's figure to the sorted-argument depth the guard measures (30 against 40, 2026-09-01) and pin the test-file comment's figure the same way; extend the depth test to refuse at 40 levels, key at 39, and key `nest(39)` and `nest(38)` apart. (M42 review O2, O6, O7.)

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
- 2026-09-01: T5 — the failure path locates deep arguments over the unsorted request and labels each by name, or `position <i>` where the slot has none. Measured before the fix: a positional deep value passed through `memoised()` reaches the guard already named (`match.call()` names it), so the unnamed shape is a direct `fixture_key()` call, which this test file makes; T5's test covers both shapes (direct positional names `position 1`; through `memoised()` names `object`). On the returned guard (helper at 83d9317) the new test file goes red at the `position 1` expectation: the guard's error escapes the `expect_error()` because its message ("argument(s) `` nest past") does not match, 52 pass, 1 error; clean run 57 pass.
- 2026-09-01: T6 — the axis test expects `object` and `resamples` among the enumerated axes and flags registry entries with no matching formal, both naming what is missing. Planted defects on scratch copies: axes minus `object` → 4 failures ("nested_tune_grid()'s enumerated formals lack `object`", "the registry holds variant(s) for no formal of nested_tune_grid(): `object`", and the same pair for `nested_final_fit()`); a `bogus` registry entry → 2 failures naming `bogus`, one per orchestrator.
- 2026-09-01: T7 — `nest()`'s loop braced; `air format --check` clean on both files. Measured on the branch: the sorted argument list keys at 39 levels and refuses at 40 and 41; `det`, `sep` and `unstable` sorted-argument lists are 30 levels, the `det` workflow 28. Helper comment and test-file comment both carry 30 against 40, dated 2026-09-01 at M42. Depth test now refuses `nest(40)`, keys `nest(39)`, and keys `nest(39)` and `nest(38)` apart. `devtools::test()`: 0 failures, 0 errors, 0 skips, 2716 pass, 43 signatures / 43 builds / 170 requests. `devtools::check()`: 0 errors, 0 warnings, 0 notes. T5-T7 land in one commit: the depth test was rewritten as one block, so the three diffs share its hunk. Status → review.
- 2026-09-01: review round 1 — defect return 1 of M42: AC3 failed (the depth guard names no argument on a positional request, the shape every real `memoised()` call takes). Status → in-progress; T5-T7 hold the return's fixes; AC3's box unticked pending re-verification.

## Decisions

## Review

- 2026-09-01, PR #51. Default branch unmoved since the branch was cut (`git fetch`; `main` at cf89a1d, the branch's base).
- AC1 — verified. The test-time enumeration `setdiff(names(formals(f)), "...")` yields `object, resamples, param_info, grid, metrics, event_level, eval_time` for both orchestrators (printed from a fresh `load_all()` session). `testthat::test_file()` on the committed `test-fixture-cache.R`: the derived test passes 16 expectations, 0 failures — one registry check plus seven per-formal distinct-key expectations per orchestrator, each pair keyed at seed 2.
- AC2 — verified. Planted defect run on a scratch copy (the `eval_time` registry entry removed, repo untouched): 2 failures, "nested_tune_grid() has formal(s) with no registered variant value: `eval_time`" and the same for `nested_final_fit()`; 14 other expectations pass.
- AC3 — verified. `fixture_key()` scans the sorted arguments' canonical form for `"<depth>"` and aborts with class `fixture_key_depth` naming the argument (`helper-orchestration.R`, diff read). The unit test "a request nested past the depth cut is refused, naming the argument" passes both expectations: a 45-level `object` errors matching "argument(s) `object` nest past"; the 30-level control keys to a 32-hex hash.
- AC4 — verified. `git diff main..HEAD` removes the test "the key separates every fixture signature this suite asks for" whole; `grep` for its title and for the old preamble phrase "asserts every distinct fixture signature" over `tests/testthat/*.R` returns nothing.
- AC5 — verified. `devtools::test()` on the branch: 0 failures, 0 warnings, 0 skips, 2708 pass; fixture cache report 43 signatures / 43 builds / 170 requests, no `fixture_key_depth` error on any real request. `devtools::check()`: 0 errors, 0 warnings, 0 notes, tests [134s/185s].
- Consistency gate. `cairn_validate.py` exit 0, all checks pass, advisories only (the standing 18 references-staleness warnings; release window closed). No DESIGN principle touched, so `cairn_impact.py` skipped. Toolchain slot: `devtools::document()` leaves no diff; README.Rmd untouched on the branch and README.md newer than it, so in sync; `pkgdown::check_pkgdown()` no problems; no new top-level files; NEWS.md needs no entry — the diff is test tooling with no user-visible change (internal tier); `check()` clean as above.
- Review fan-out: three fresh-context reviewers spawned ([O] diff-bug, [S] blame-history, [S] prior-review). Findings and triage below.
- Findings, ranked by each lens (verbatim texts in the review-round transcript; substance here). **[O] diff-bug, 11 findings.** O1: the derived domain `setdiff(names(formals(f)), "...")` can silently empty — an orchestrator turned into a generic drops six of seven axes with the test green; nothing pins the enumeration non-empty (Check discrimination: a domain that can silently empty must be shown non-empty). O2: `air format --check` reports "Would reformat" on `test-fixture-cache.R` (the unbraced `for` at the depth test's `nest()`), against DESIGN's air convention. O3: the depth guard names no argument on a positional request — `names(ordered)` is NULL or "" for unnamed slots, so the message reads "argument(s)  nest past" / "argument(s) `` nest past"; `memoised()` passes `as.list(call)[-1L]` and every real call passes the workflow and design positionally, so the one shape a real hit would take names nothing. O4: deleting the family test loses the deep-difference separation (`break_fold()` variants, `sep`/`unstable`, `final_nested()`) the depth guard exists to protect; the `resamples` axis is the shallow `v = 4`. O5: only the arguments are guarded; `canonical_form(inside_spec_bindings(args, env))` can truncate identically and is unbounded. O6: two derived figures are wrong against what the guard measures — the sorted args list is 30 levels for `det`, `sep`, `unstable` (the workflows 28), so the margin is 10, and the test-file comment's "12 levels" carries no date pin. O7: the depth test's control asserts a hash shape, not discrimination at 30 levels, and neither side of the cut (39 keys, 40 refuses) is tested. O8: `base_request()` names all seven formals while real requests are mostly positional, which is what hid O3. O9: the registry check is one-directional — a formal removed from an orchestrator leaves a stale registry entry unflagged. O10: `has_depth_marker()` cannot tell the marker from a literal length-1 `"<depth>"` value in a real fixture. O11: the PR-URL header edit was uncommitted at the time of the read. **[S] blame-history, 3 findings.** S1: the real fixture families (`break_*`, `sep`, `unstable`) had verified pairwise separation and now have none, disclosed in the plan's Out but not in the code comments. S2: no test now keys two different recipe-based workflows apart, the case `canonical_form()`'s environment-expansion rationale cites. S3: the helper preamble no longer gestures at the family coverage the old comment described. **[S] prior-review: no prior-review evidence contradicted, zero findings** — the diff resolves the M35 O3 / M41 R6 deferral; the GitHub probe found one real inline comment, on PR #30's pkgdown workflow, and PRs #43 and #50 carry no threads.
- Verification at the gate. O2 reproduced (`air format --check`: Would reformat). O3 reproduced with a two-formal stand-in: fully positional → "argument(s)  nest past", partially named → "argument(s) `` nest past". O7's boundary measured: 39 levels keys, 40 and 41 refuse. O6 measured: `det` sorted-args list 30 levels, workflow 28.
- Triage. **O3 — defect return under the return floor:** AC3 promises an error naming the offending argument and, inside `fixture_key()`'s domain, a positional request names none; T5. **O1 — fix in the same round** (T6): pin one fact stated independently of `formals()`. **O9 — fix with O1** (T6): flag stale registry entries naming them. **O2, O6, O7 — fix in the same round** (T7): brace the loop; correct both figures to the sorted-args depth and pin the test-file figure; test both sides of the cut and discrimination inside it. **O8 — absorbed by T5's test**, which keys a positional request. **O4, S1, S2, S3 — rejected as the plan's declared Out** (fixture-family separation; the code comments state what the derived test does and claim nothing about families); the family axis and S2's recipe pair go to a follow-up candidate row at the hygiene pass (search-first: the fixture-cache row at ROADMAP line 27 is the one M42 retires, so the follow-up is a new row citing it). **O5 — follow-up**, same row: the guard's extension to `inside_spec_bindings()` is a redesign of what is guarded, the plan's Out. **O10 — rejected:** inherent to a sentinel design, and a literal `"<depth>"` value in a fixture is not a shape this suite builds. **O11 — already committed** (73eb055).
- Round 2, 2026-09-01, PR #51 (draft). Default branch still at cf89a1d, the branch's base; branch at b248823 pushed and matching origin.
- AC1 — re-verified on the branch after T5-T7. Enumeration from a fresh `load_all()`: `object, resamples, param_info, grid, metrics, event_level, eval_time` for both orchestrators. `testthat::test_file()` on the committed `test-fixture-cache.R`: the derived test passes 20 expectations, 0 failures, 0 errors — three registry/enumeration checks plus seven per-formal distinct-key expectations per orchestrator.
- AC2 — re-verified. Planted defect on a scratch copy outside the repo (the `eval_time` registry entry removed): 2 failures, "nested_tune_grid() has formal(s) with no registered variant value: `eval_time`" and the same for `nested_final_fit()`; the other 18 expectations pass, no errors.
- AC3 — verified on the returned guard. Direct calls: a 45-level named `object` aborts with class `fixture_key_depth` and "argument(s) `object` nest past"; the same value unnamed in slot 1 aborts naming "position 1"; two unnamed deep slots name "position 1, position 2". The depth test passes all 6 expectations (named, positional, through `memoised()` arriving named, refuse at 40, key at 39, `nest(39)` and `nest(38)` key apart).
- AC4 — re-verified. `git diff origin/main..HEAD` removes `test_that("the key separates every fixture signature this suite asks for"` (1 deletion hunk); `grep` for that title and for "asserts every distinct fixture signature" over `tests/testthat/*.R` returns nothing.
