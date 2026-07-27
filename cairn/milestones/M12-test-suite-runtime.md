# M12: Fitting time only where an assertion needs it

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Branch/PR:** `m12-test-suite-runtime`

## Goal

No test fits a model whose result no assertion reads, and no CI job can run
longer than an answer is worth waiting for.

## Scope

**In:** A memoised fixture layer in `tests/testthat/helper-orchestration.R` so an
identical tuning run is built once per suite run rather than once per test, and
the conversion of the six files that rebuild fixtures identically —
`test-nested-results-plot.R` (24 runs, 17 of one signature),
`test-nested-results-print.R` (21 / 12), `test-nested-tune-grid-failures.R`
(19 / 3 plus 6 and 3 of two `break_fold` signatures),
`test-nested-tune-grid-results.R` (8 / 6), `test-nested-final-fit-print.R`
(4 / 4), `test-nested-final-fit-results.R` (3 / 2). Also: replacing the real
30-fit run at `test-nested-tune-grid-leakage.R:88` with the `record_handoffs()`
stub already defined at `:10`, which satisfies both of its assertions; collapsing
the byte-identical pair at `test-parallel-identity.R:208`/`:214`; a committed
profiling script and baseline under `benchmarks/`; and `timeout-minutes` on both
workflow jobs.

**Out:** The oracle files' duplicated reference runs
(`test-nested-tune-grid-oracles.R`, `test-nested-final-fit-oracles.R`) — that
duplication *is* the oracle under GP2, and removing it would remove the check.
Sharing a worker pool across `test-parallel-identity.R`'s tests, which would
recover most of its 40.5 s but risks leaked worker state corrupting the IP2
guarantee those tests exist to prove → declined at the plan gate, back to a
ROADMAP candidate row. Shrinking any fixture whose size its assertion depends on,
including `test-nested-results-print.R:288`'s five-fold unanimity snapshot.

## Acceptance criteria

- [ ] AC1 `benchmarks/profile-tests.R` is committed and prints elapsed seconds
      per test file, a suite total, and testthat's pass/fail/skip counts;
      `benchmarks/test-timing-baseline.md` records its output on the pre-change
      tree together with the commit measured, R version, OS, the `NOT_CRAN`
      setting, which of `lobstr`/`mlbench`/`ranger`/`vdiffr` are installed,
      whether the package is loaded once for all files or per file, and the
      median of three runs.
- [ ] AC2 Re-running `benchmarks/profile-tests.R` on the finished branch, on the
      same machine and R version and under every condition AC1 records, gives a
      median suite total at most 60% of the baseline median; both medians appear
      in the Review section.
- [ ] AC3 `devtools::test()` reports 0 failures, and `git diff <default>..HEAD --
      tests/` shows no `test_that()` block removed and no `skip_*()` call added;
      the diff summary appears in the Review section.
- [ ] AC4 The memoised helper keys on a value hash of the workflow, design, grid,
      metrics **and the RNG seed in force at the request**; a cache hit is
      `identical()` to the first build and re-signals the conditions that build
      emitted. A full `devtools::test()` run reports no signature built more than
      once, and the request/build table appears in the Review section.
- [ ] AC5 For each of the six converted files named in Scope, a single named
      mutation to a function that file's own assertions target makes that file
      fail **while leaving at least one other converted file passing**; each
      file, its mutation, and the failing test appear in the Review section.
- [ ] AC6 Both workflow jobs declare `timeout-minutes: 20`, visible in both
      committed workflow files at the branch head; a run on the branch completes
      both jobs within it; `cairn/PROFILE.md`'s divergence list names this third
      divergence from the stock shape.
- [ ] AC7 `devtools::test()` and `devtools::check()` clean (0 errors, 0 warnings;
      NOTEs justified), per the profile's `verify` and `consistency-gate` slots.

## Coverage

- AC1 → T1
- AC2 → T1, T3, T4, T5, T6, T8
- AC3 → T3, T4, T5, T6, T8
- AC4 → T2
- AC5 → T7
- AC6 → T9
- AC7 → T8

## Tasks

- [x] T1 Write `benchmarks/profile-tests.R` (load once, time each file, report
      counts, median of three) and commit `benchmarks/test-timing-baseline.md`
      with every condition AC1 lists. `benchmarks/` is already `.Rbuildignore`d.
- [x] T2 Add the memoised fixture helper to `helper-orchestration.R`: value-hash
      key including the seed, condition capture and replay on hit, per-signature
      request/build counters, plus a test that a hit is `identical()` to the
      build and re-signals its conditions.
- [x] T3 Convert `test-nested-results-plot.R` (56.8 s) — 17 identical runs, 4
      `break_fold` outer-fit, 2 unstable, 1 `break_every_fold`.
- [x] T4 Convert `test-nested-results-print.R` (49.0 s) — 12 identical, 3
      `break_fold`, 2 `break_every_fold`, 2 unstable; leave `:288` alone.
- [ ] T5 Convert `test-nested-tune-grid-failures.R` (24.3 s). The nested
      `expect_warning()` at `:102`–`:103` and `:122` is what AC4's condition
      replay exists for — verify it fails without replay.
- [ ] T6 Convert `test-nested-tune-grid-results.R`, `test-nested-final-fit-print.R`,
      `test-nested-final-fit-results.R`; swap `test-nested-tune-grid-leakage.R:88`
      to the `:10` stub; collapse `test-parallel-identity.R:208`/`:214`.
- [ ] T7 Mutation-sensitivity pass over the six converted files, one mutation
      each, each leaving another converted file green; record and revert.
- [ ] T8 Re-measure (median of three), record both medians and the `tests/` diff
      summary; `devtools::test()` and `devtools::check()` clean.
- [ ] T9 Add `timeout-minutes: 20` to both workflow jobs; amend `PROFILE.md`'s
      "Two divergences" line to three.

## Work log

- 2026-07-27: created by /milestone-plan.
- 2026-07-27: plan gate chose suite-level memoisation of identical fixtures over shrinking fixtures (fewer folds/rows/grid rows) because shrinking changes what each assertion is evidence for and churns snapshots, while memoisation leaves every assertion intact; falsified by evidence that a cache hit and a fresh build can differ observably — a fixture whose value or signalled conditions depend on state the key does not capture.
- 2026-07-27: plan gate chose memoisation over committing pre-built fixtures as `.rds` because a frozen fixture stops exercising the code path it is meant to cover, so a package regression would leave the tests green; falsified by evidence that building fixtures dominates runtime even after deduplication.
- 2026-07-27: plan gate chose leaving `test-parallel-identity.R`'s worker pools alone over sharing one pool across its tests, because leaked worker state would corrupt exactly the IP2 reproducibility guarantee those tests prove; falsified by evidence that a shared pool is observably clean between tests — a probe showing no carried state across a pool reuse.
- 2026-07-27: plan gate chose folding the CI hang cap into this milestone over a separate milestone, because both changes bound CI wall-clock and review as one PR; falsified by the two proving to need independent review or revert.
- 2026-07-27: T1 done. Baseline at `d095bae`, median of three: suite total 327.3 s, 1175 pass / 0 fail / 0 skip. The six converted files hold 211.0 s (64.5%); AC2's 60% ceiling is 196.4 s, so the conversions must save at least 130.9 s.
- 2026-07-27: implement gate chose a canonical-form value hash for the cache key over a caller-declared label or a setup-file fixture, after measuring that `rlang::hash()` differs between two identically-constructed workflows and between two `metric_set()` calls (self-referential quosure and closure environments serialize by unstable reference numbering); the canonical form was stable across all 5 fixture signatures and discriminated all 11 distinguishing pairs probed. Falsified by a signature pair the form fails to separate — which `test-fixture-cache.R` is written to catch.
- 2026-07-27: T2 done. `memoised()`, `canonical_form()`, `fixture_key()` and `fixture_cache_report()` in helper-orchestration.R; `test-fixture-cache.R` (19 assertions) and `teardown-fixture-cache.R`. Suite 1194 pass / 0 fail / 0 skip.
- 2026-07-27: T3 done. `test-nested-results-plot.R` 95.7 s -> 8.7 s, 68 pass / 0 fail; 24 requests over 4 signatures (17 / 4 / 2 / 1), matching the plan's count exactly.
- 2026-07-27: T4 done. `test-nested-results-print.R` 60.9 s -> 12.3 s, 49 pass / 0 fail; 21 requests over 12 signatures. `:288`'s five-fold unanimity fixture is wrapped, not shrunk.
- 2026-07-27: report regrouped after T4 found the source-text grouping lying: `test-nested-tune-grid-failures.R` spells seven different designs as `nested_tune_grid(det_workflow(d), nested, ...)`, rebinding `nested` per test, so grouping by call text reported seven correct builds as key instability. Rows now group by the canonical form of what was built, so `builds > 1` means one fit was paid for twice however it was spelled.
- 2026-07-27: implement gate chose a `teardown-` file for AC4's request/build table over a last-alphabetical test file or the profiler alone, and chose wrapping the existing call (`memoised(nested_tune_grid(...))`) over typed per-function wrappers, so the function under test stays visible at every call site and one helper serves both entry points.

## Decisions

## Review
