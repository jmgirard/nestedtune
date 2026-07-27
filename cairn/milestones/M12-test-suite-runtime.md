# M12: Fitting time only where an assertion needs it

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Branch/PR:** `m12-test-suite-runtime` / https://github.com/jmgirard/nestedtune/pull/12

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

- [x] AC1 `benchmarks/profile-tests.R` is committed and prints elapsed seconds
      per test file, a suite total, and testthat's pass/fail/skip counts;
      `benchmarks/test-timing-baseline.md` records its output on the pre-change
      tree together with the commit measured, R version, OS, the `NOT_CRAN`
      setting, which of `lobstr`/`mlbench`/`ranger`/`vdiffr` are installed,
      whether the package is loaded once for all files or per file, and the
      median of three runs.
- [x] AC2 Re-running `benchmarks/profile-tests.R` on the finished branch, on the
      same machine and R version and under every condition AC1 records, gives a
      median suite total at most 60% of the baseline median; both medians appear
      in the Review section.
- [x] AC3 `devtools::test()` reports 0 failures, and `git diff <default>..HEAD --
      tests/` shows no `test_that()` block removed and no `skip_*()` call added
      **to a test that existed before this milestone**; the diff summary appears
      in the Review section.
- [x] AC4 The memoised helper keys on a value hash of the workflow, design, grid,
      metrics **and the RNG seed in force at the request**; a cache hit is
      `identical()` to the first build and re-signals the conditions that build
      emitted. A full `devtools::test()` run reports no signature built more than
      once, and the request/build table appears in the Review section.
- [x] AC5 For each of the six converted files named in Scope, a single named
      mutation to a function that file's own assertions target makes that file
      fail **while leaving at least one other converted file passing**; each
      file, its mutation, and the failing test appear in the Review section.
- [x] AC6 Both workflow jobs declare `timeout-minutes: 20`, visible in both
      committed workflow files at the branch head; a run on the branch completes
      both jobs within it; `cairn/PROFILE.md`'s divergence list names this third
      divergence from the stock shape.
- [x] AC7 `devtools::test()` and `devtools::check()` clean (0 errors, 0 warnings;
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
- [x] T5 Convert `test-nested-tune-grid-failures.R` (24.3 s). The nested
      `expect_warning()` at `:102`–`:103` and `:122` is what AC4's condition
      replay exists for — verify it fails without replay.
- [x] T6 Convert `test-nested-tune-grid-results.R`, `test-nested-final-fit-print.R`,
      `test-nested-final-fit-results.R`; swap `test-nested-tune-grid-leakage.R:88`
      to the `:10` stub; collapse `test-parallel-identity.R:208`/`:214`.
- [x] T7 Mutation-sensitivity pass over the six converted files, one mutation
      each, each leaving another converted file green; record and revert.
- [x] T8 Re-measure (median of three), record both medians and the `tests/` diff
      summary; `devtools::test()` and `devtools::check()` clean.
- [x] T9 Add `timeout-minutes: 20` to both workflow jobs; amend `PROFILE.md`'s
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
- 2026-07-27: T5 done. `test-nested-tune-grid-failures.R` 35.9 s -> 16.1 s, 56 pass / 0 fail; 18 requests over 12 signatures -- the file genuinely uses many distinct broken designs, so it deduplicates less than the others. The `finalize_workflow` mocked block at `:333` is deliberately left unwrapped: its call is byte-identical to unmocked ones elsewhere, so caching it would cross the mock boundary in both directions.
- 2026-07-27: T5 verified condition replay is load-bearing. With the replay line disabled, `test-nested-tune-grid-failures.R:102` fails both nested expectations ("Expected `memoised(...)` to throw a warning with class <nestedtune_failed_folds>" and "Expected `expect_warning(...)` to throw a warning"); restored and green.
- 2026-07-27: T6 done, single-file timings: tune-grid-results 13.1 -> 4.1 s (38 pass), final-fit-print 3.0 -> 0.7 s (58), final-fit-results 2.4 -> 0.9 s (14), leakage 1.8 -> 0.2 s (57), parallel-identity 63.1 -> 34.0 s (49). `record_handoffs()` now returns the assembled object beside the handoffs, so the leakage test that read `res$id`/`res$splits` uses the stub instead of thirty real fits; `test-parallel-identity.R` takes its object by assigning inside `expect_warning()` rather than re-running the fit.
- 2026-07-27: T7 done, and committed as `benchmarks/mutation-sensitivity.R` so review re-derives it rather than reading a transcript. All six converted files fail their own named mutation while their control passes: plot / `from_folds()` k+1 (3 failures); print / `selection_values()` value<-NA (8); failures / `own_note()` type "error"->"failure" (1); tune-grid-results / `collect_metrics.nested_results()` summarize default TRUE->FALSE (21); final-fit-print / `selected_label()` " = "->": " (2); final-fit-results / `new_nested_final_fit()` fit_seed seeds[[2]]->seeds[[1]] (1). Every mutation reverted; tree clean.
- 2026-07-27: T9 done. `timeout-minutes: 20` on the `R-CMD-check` and `test-coverage` jobs; PROFILE.md's divergence list now names three, the third being the cap.
- 2026-07-27: T8 done. Re-measured at `7bf17e8` under every AC1 condition: suite total 108.0 s against the 327.3 s baseline, **33.0%** (AC2 ceiling 60%). 1199 pass / 0 fail / 0 skip. `devtools::check()` clean: 0 errors, 0 warnings, 0 notes. Fixture cache over a full run: 22 fixtures, 22 builds, 78 requests -- none built twice.
- 2026-07-27: AC3 amended at a mini gate, from "no `skip_*()` call added" to "no `skip_*()` call added to a test that existed before this milestone". Measured: 0 `test_that()` blocks removed, 12 added, 0 skips removed, 2 added -- both in the new `test-fixture-cache.R` (`:125`, `:193`), guarding the two tests that build real workflow and design objects with the same `skip_if_no_engines()` every other file uses. The criterion exists to stop the speedup being bought by switching existing tests off; new tests guarded by the repo's own convention are not that, and dropping the guards would make `R CMD check` error on a machine without the Suggests.
- 2026-07-27: all tasks done, status to review. PROFILE.md compressed back under its 120-line cap after the third divergence pushed it to 125. Branch pushed; AC6's second half (a run completing inside the cap) needs the PR, since the `push` trigger fires only on the default branch.
- 2026-07-27: implement gate chose a `teardown-` file for AC4's request/build table over a last-alphabetical test file or the profiler alone, and chose wrapping the existing call (`memoised(nested_tune_grid(...))`) over typed per-function wrappers, so the function under test stays visible at every call site and one helper serves both entry points.

## Decisions

## Review

Verified 2026-07-27 at `06c3867` on the branch, PR #12. Every figure below was
produced by command in this session, not carried from implementation.

- **AC1** — `benchmarks/profile-tests.R` and `benchmarks/test-timing-baseline.md`
  are both committed (`git ls-tree HEAD benchmarks/`). The script prints seconds
  per test file, a suite total, and testthat's pass/fail/skip counts. The
  baseline records commit `d095bae`, R 4.6.1, macOS Tahoe 26.5.2, testthat 3.3.2,
  `NOT_CRAN=true`, `lobstr`/`mlbench`/`ranger`/`vdiffr` all installed, the package
  loaded once for all files via `pkgload::load_all()`, and the median of three runs.
- **AC2** — re-run at `06c3867` under every AC1 condition, same machine and R
  version: **median suite total 125.6 s against the baseline's 327.3 s = 38.4%**,
  inside the 60% ceiling. (Two earlier re-measures taken while review subagents
  competed for CPU read 134.5 s and 137.8 s, 41.1% and 42.1% — inside the ceiling
  either way; 125.6 s is the quiet-machine figure at the reviewed commit.)
- **AC3** — `devtools::test()`: 1207 pass, 0 fail, 0 skip. `git diff main..HEAD --
  tests/` over 11 files: **0 `test_that()` blocks removed**, 16 added, **0
  `skip_*()` calls removed**, 6 added — every added skip in the new
  `test-fixture-cache.R`, none in a file that existed before this milestone, per
  the criterion as amended at the 2026-07-27 gate.
- **AC4** — the key is a hash of the canonical form of the callee, every matched
  argument, the caller-scoped names the design's inner specification resolves,
  and the RNG state in force (`fixture_key()`). `test-fixture-cache.R` asserts a
  hit is `identical()` to the build, re-signals its conditions, and leaves the
  RNG where a build would. A full `devtools::test()` run reports **22 fixtures,
  22 builds, 78 requests — none built more than once**; the table is below.
- **AC5** — `Rscript benchmarks/mutation-sensitivity.R`: *ALL SENSITIVE*. Each
  converted file fails a single named mutation to a function its own assertions
  target, while its control file passes. plot / `from_folds()` k+1 → 3 failures,
  first "a panel says so when fewer folds contributed to it than completed";
  print / `selection_values()` value←NA → 8, "unanimous selection is distinguished
  from disagreement"; failures / `own_note()` `"error"`→`"failure"` → 1, "the
  failing stage and its cause are recorded"; tune-grid-results /
  `collect_metrics.nested_results()` summarize TRUE→FALSE → 21, "collect_metrics()
  summarizes across outer folds"; final-fit-print / `selected_label()` `" = "`→`": "`
  → 2, "printing names the selection and where the estimate lives";
  final-fit-results / `new_nested_final_fit()` fit_seed seeds[[2]]→seeds[[1]] → 1,
  "the final fit returns a trained workflow inside its own object".
- **AC6** — `timeout-minutes: 20` is present in both committed workflow files at
  the branch head (`git show HEAD:.github/workflows/R-CMD-check.yaml`, likewise
  test-coverage.yaml); `PROFILE.md` names three divergences, the third being the
  cap. Run 30292076043 completed every job inside it: macOS 4m43s, windows 8m1s,
  ubuntu 6–7 min, test-coverage 4m41s. **The earlier run 30288158779 did not** —
  its macOS job hung inside `test_check("nestedtune")` (`* checking tests ...` at
  17:14:53, silence to cancellation at 17:31:47, everything before the suite
  passing) and the cap killed it at 20 minutes. That is the intermittent hang the
  ROADMAP candidate describes, recurring: same signature, same platform, on a tree
  whose four other jobs passed in 6–8 minutes and whose macOS job passed in 4m43s
  on re-run. The cap turned a 52-minute hang into a 20-minute one, which is what
  it was installed to do; it did not diagnose it, and the candidate row's stated
  promotion condition — any recurrence — is now met.
- **AC7** — `devtools::test()` 0 failures; `devtools::check()` **0 errors, 0
  warnings, 0 notes** (Status: OK, 3m 19s).

### Consistency gate

`cairn_validate.py` exit 0, all checks passed (`weight caps` needed two
compression passes over `PROFILE.md`, which the third divergence and then the
restored M11 clause pushed over its 120-line cap; final 118). No DESIGN.md
principle changed, so `cairn_impact` was not run. Profile `consistency-gate`
slot: `devtools::check()` clean including `document()` no-diff and
`.Rbuildignore` NOTEs (0 notes); `benchmarks/` is `.Rbuildignore`d; no new
exports, so no `_pkgdown.yml` row and no NEWS entry is owed — the change is
entirely test-side and user-invisible.

### Independent review

Three fresh-context reviewers (diff-bug [O], blame-history [S], prior-review [S])
returned 10 findings; a separate [S] scorer rated each. Six scored ≥80 and were
actioned, all fixed on the branch in `06c3867`:

- **A (90)** the key identified the callee by deparsed name, so two files
  memoising same-named local builders collided and the second was silently served
  the first's value → the key now hashes the function's canonical form.
- **B (93)** the caller environment was absent from the key while
  `nested_final_fit()` re-evaluates its design's inner specification there, so a
  request from a frame lacking a name the specification uses could be served a
  hit where a real call aborts → the key now includes what those names resolve to.
- **C (92)** only warnings and messages were replayed, so an `rlang::signal()`
  diagnostic was observed on a build and missed on a hit → all conditions are
  captured and replayed; `replay_condition()`'s unreachable error branch removed.
- **E (82)** `order(names(args))` errored on a call whose matched arguments were
  all unnamed → guarded.
- **H (82)** the `PROFILE.md` line-cap compression dropped the clause recording
  M11's actioned finding F1 (cancellation reclaims the tail, not the whole run) →
  restored.
- **I (80)** the new CI-cap comment claimed the slowest honest leg was "well under
  12 minutes" when the record shows an ordinary windows leg at 11m54s and one job
  in 394 over 20 minutes that still finished → both the workflow comment and
  `PROFILE.md` now state the cost the cap actually carries.

Four scored below 80 and were logged rather than actioned: **F (78)** the
profiler's missing-file guard was unreachable and would abort instead of
reporting NA; **D (75)** the mutation harness's `on.exit()` never fires at script
top level and would have mis-reverted if it had; **J (60)** the AC3 amendment
loosens rather than tightens, flagged for the gate to ratify explicitly; **G (45)**
the "no `memoised()` under a mock" rule is enforced by comment only, speculative
about a future mock. D and F were fixed anyway — both are two-line false-safety
claims in scripts this milestone authored, the same class as I. G is rejected as
speculative; today's single mocked site is self-protecting because its call is
byte-identical to a fixture twenty sites share, so wrapping it would fail loudly.
J goes to the approval gate.

Fixing A also surfaced a constraint worth naming: hashing the builder by value
expands its lexical environment, so a builder closing over mutable state re-keys
every time that state changes. Package functions live in a namespace, which the
canonical form takes by name, so the real call sites are unaffected — but the
cache test's own double had to move its counter out of file scope, and the
helper's header says so.

### Fixture cache over a full run

22 fixtures, 22 builds, 78 requests. Heaviest rows: the canonical `det` fixture
31 requests / 1 build; `break_fold(..., 2L, "outer fit")` 7/1; the
`test-nested-tune-grid-results.R` helper 6/1; `nested_final_fit` with metrics 4/1;
the unstable design 4/1; `break_every_fold` 3/1. The remainder are single-request
fixtures, most of them the distinct broken designs
`test-nested-tune-grid-failures.R` needs.
