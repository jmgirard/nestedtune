# M02: Outer-loop orchestration

- **Status:** review
- **Priority:** high
- **Depends on:** M01
- **Driving RR:** RR01
- **Principles touched:** IP1, IP2, IP3, GP1, GP3
- **Branch/PR:** `m02-outer-loop-orchestration` · https://github.com/jmgirard/nestedtune/pull/2

## Goal

Run the nested loop end to end — inner tuning, selection, outer fit and score —
returning a collected-results object that retains each outer fold's chosen
parameters.

## Scope

**In:** One exported entry point taking a workflow, the memory-lean nested
structure from M01, a grid, and a metric set. Per outer fold it calls
`tune::tune_grid()` on that fold's inner `rset` with
`control_grid(allow_par = FALSE)`, then `select_best()`,
`finalize_workflow()`, and `last_fit()` on the outer split — delegating every
step rather than reimplementing it. A results object retaining per-fold metrics
*and* per-fold selected parameters, with a `collect_metrics()` method. Outer
bootstrap refused outright. Serial execution. Docs, NEWS.md, pkgdown rows.

**Out:** parallelism over outer folds, failed-fold handling (IP4), print/summary surfacing of
selection instability, the separate final-fit path IP3 implies, variance estimation (G6), and
tune#969 posture (G7) — each already a ROADMAP candidate row carrying its reason; the first is
planned once this milestone's results object exists and its real shape is known.

## Acceptance criteria

- [x] AC1 — `devtools::check()` clean: 0 errors, 0 warnings, NOTEs justified in the review evidence.
- [x] AC2 — Per-fold metrics match a hand-rolled `tune_grid()` → `select_best()` → `finalize_workflow()`
      → `last_fit()` reference loop under a fixed seed. Reference-implementation oracle (GP2); AC16 fixes the construction.
- [x] AC3 — With a single-candidate grid, per-fold metrics match `tune::fit_resamples()` on the outer
      `rset` — nothing to select, so nested CV degenerates to ordinary CV. Invariant oracle, GP2's second type; AC17 fixes the engine.
- [x] AC4 — IP1 checked, not asserted: for every outer fold, the rows seen by inner tuning and by the
      outer fit are disjoint from that fold's assessment rows, verified by a test instrumenting membership.
- [x] AC5 — The results object retains each outer fold's selected parameters, and `collect_metrics()`
      returns both per-fold and summarized metrics.
- [x] AC6 — An outer bootstrap is refused with `cli_abort()`, deliberately stricter than rsample's
      warning (GP3); every error branch is fired by a test.
- [x] AC7 — Every exported object has roxygen docs and a `_pkgdown.yml` reference row;
      `devtools::document()` produces no diff; NEWS.md records the user-visible change.
- [x] AC8 (BC1): `nested_tune_grid()` derives all per-fold seeds from the caller's RNG
      state at entry in a single documented `sample.int()` call producing one
      tuning seed and one outer-fit seed per outer fold, assigned by fold position;
      no seed is drawn inside the fold loop or worker.
- [x] AC9 (BC2): Each fold's work seeds the RNG with its own seeds and a pinned kind:
      the tuning step runs after `set.seed(<tuning seed>, kind = "Mersenne-Twister",
      normal.kind = "Inversion", sample.kind = "Rejection")` and `last_fit()` runs
      immediately after the same call form with that fold's outer-fit seed.
- [x] AC10 (BC3): The returned `nested_results` object exposes each fold's tuning seed
      and outer-fit seed, and the exported documentation states the
      hand-replication contract in terms of those seeds.
- [x] AC11 (BC4): On exit (including on error), `.Random.seed` and the full `RNGkind()`
      triple equal their entry values; a test asserts that draws following the
      call are identical to draws with the call absent. If `.Random.seed` does not
      exist at entry, the function neither errors nor leaves the session without a
      valid RNG state.
- [x] AC12 (BC5): DESCRIPTION declares `tune (>= 2.0.0)`.
- [x] AC13 (BC6): Same-seed identity is asserted with a stochastic engine whose
      randomness flows through R's RNG (ranger via Suggests, test skipped if
      unavailable): two runs under the same `set.seed()` produce `identical()`
      per-fold metrics and `identical()` selected parameters; a companion
      assertion shows a different seed changes the metrics.
- [x] AC14 (BC7): The per-fold computation is an internal function of (outer split,
      inner rset, fold seeds, static inputs) only; a test executes the folds
      through it in a permuted order and asserts per-fold results `identical()`
      to the driver's in-order output.
- [x] AC15 (BC8): A test asserts the per-fold worker's output for fixed seeds is
      `identical()` regardless of the caller's RNG kind and state at its
      invocation (at minimum: default Mersenne-Twister state and an
      L'Ecuyer-CMRG state).
- [x] AC16 (BC9): The AC2 reference-loop test derives its expected fold seeds from the
      documented contract (its own `set.seed()` + `sample.int()` call, not the
      driver's output), asserts they equal the exposed seeds, and then asserts
      the hand-rolled `tune_grid()` → `select_best()` → `finalize_workflow()` →
      `last_fit()` loop reproduces per-fold metrics and selected parameters
      `identical()`ly, in both a deterministic-engine and a stochastic-engine
      variant.
- [x] AC17 (BC10): The AC3 single-candidate-grid invariant against
      `tune::fit_resamples()` is asserted with a deterministic engine; no
      criterion claims stochastic-engine identity with `fit_resamples()`.

## Coverage

- AC1 → T1, T9
- AC2 → T2, T3, T4
- AC3 → T2, T3
- AC4 → T8
- AC5 → T5, T6
- AC6 → T7
- AC7 → T9
- AC8 → T4
- AC9 → T4
- AC10 → T5
- AC11 → T4, T10
- AC12 → T1
- AC13 → T10
- AC14 → T4, T10
- AC15 → T10
- AC16 → T2, T3
- AC17 → T2

## Tasks

- [x] T1 — Add `tune (>= 2.0.0)`, `workflows`, and `parsnip` to DESCRIPTION
      Imports per D-007 and the RR01 version floor, and `ranger` to Suggests for
      the stochastic-engine tests. (The unused-declared-dependency confirmation
      needs the code that uses them, so it runs at T9.)
- [x] T2 — Write the failing oracle tests first: the reference-loop equivalence
      (AC2/AC16, deterministic and stochastic variants, seeds derived from the
      documented contract) and the single-candidate-grid invariant (AC3/AC17,
      deterministic engine only).
- [x] T3 — Implement the per-fold step: `tune_grid()` on the inner `rset` with
      `control_grid(allow_par = FALSE)`, `select_best()`,
      `finalize_workflow()`, then `last_fit()` on the outer split.
- [x] T4 — Implement the serial driver over outer folds per D-011: draw
      `2 * n_folds` seeds at entry, run each fold through a pure per-fold worker
      seeded with the kind triple pinned, and restore the caller's RNG state and
      kind on exit (including on error). (RB tripwire: ip-touching — IP2;
      settled by RR01.)
- [x] T5 — Results object: class, constructor, and storage of per-fold metrics
      alongside each fold's selected parameters and its two seeds.
- [x] T6 — `collect_metrics()` method returning per-fold and summarized metrics.
- [x] T7 — Input validation: refuse an outer bootstrap, and validate the
      workflow, grid, and metric-set arguments; test every `cli_abort()` branch.
- [x] T8 — Leakage test: instrument row membership per outer fold and assert
      inner tuning and the outer fit never touch that fold's assessment rows.
      (RB tripwire: ip-touching — IP1.)
- [x] T9 — Roxygen docs (including the hand-replication contract and IP2's
      R-RNG scope), `_pkgdown.yml` rows, NEWS.md entry, `document()` no-diff,
      `devtools::check()` clean with no unused declared dependency.
- [x] T10 — RNG test battery per RR01: same-seed identity and seed sensitivity
      on a stochastic engine, permuted fold-order invariance, ambient-state
      independence of the per-fold worker, and the net-zero exit-state pin.

## Work log

- 2026-07-25: created by /milestone-plan, absorbing the orchestration candidate row.
- 2026-07-25: /milestone-implement started; branch `m02-outer-loop-orchestration` cut from main.
- 2026-07-25: question gate — entry point, results class, and the `control` argument settled (D-010 + milestone-local entry); T4's RNG scheme escalated to /milestone-brief on the user's selection (IP2 tripwire).
- 2026-07-25: blocked on RB01 (per-outer-fold RNG streams, T4). RB committed on the milestone branch rather than the default branch, since M02's branch was already open — keeps this milestone's tracking on one branch.
- 2026-07-25: ingested RR01 ([F] Fable subagent, tune 2.1.0 installed and probed by execution). Applied: Scheme A′ (D-011), tune version floor, `ranger` in Suggests, deterministic engine for AC3 and both variants for AC2, the seeds-as-contract oracle construction. Rejected with reason (RR recs 2, 3, 7): L'Ecuyer streams, inherited state, and a `seed` argument. Deferred: B4 → ROADMAP candidate. BC1–BC10 ingested verbatim as AC8–AC17; no deviations.
- 2026-07-25: dependency gate — user approved the `tune (>= 2.0.0)` floor and `ranger` in Suggests (D-012); user also elected to carry M02 as one milestone despite the 17-criteria / 10-task split tripwires.
- 2026-07-25: T1 done — DESCRIPTION declares tune (>= 2.0.0), workflows, parsnip in Imports and ranger in Suggests; `devtools::test()` clean (549 pass). Minor task edit: the unused-dependency confirmation moved to T9, which is where code using them exists.
- 2026-07-25: T2 done — oracle tests written and failing for the right reason ("could not find function nested_tune_grid", 3 errors). O1 (live reference loop, deterministic + stochastic) and O2 (fit_resamples invariant) recorded in the test file header per DESIGN Conventions. Suite is intentionally red until T3–T5 land; the verify slot's clean-before-checkoff gate cannot bind a task whose product is a failing test. Second dependency gate: `recipes` and `yardstick` to Suggests (D-013). Signature confirmed as `nested_tune_grid(object, resamples, grid, metrics)` — corrects D-010's parenthetical, which named the second argument `workflow`; substance of D-010 unchanged.
- 2026-07-25: T3 and T5 done — `nested_tune_grid()` plus the `nested_fold_fit()` worker, the `nested_results` constructor, `collect_metrics()`, and the argument checks landed across R/nested-tune-grid.R, R/nested-results.R, R/checks.R, R/reexports.R. All three T2 oracles pass first run; full suite 572 pass, 0 fail. T4/T6/T7 code is present but stays unchecked until its own tests exist (T10 for the RNG contract, T6/T7 for the method and error branches). Results object is a hand-built tibble rather than an import of `tibble` — one line of `structure()` against a dependency.
- 2026-07-25: T4, T6, T7, T8, T10 done — RNG battery (order invariance, ambient-state independence, net-zero exit, error path, fresh session), leakage instrumentation via a mocked handoff that catches split/inner mis-pairing, `collect_metrics()` both modes, and every `cli_abort()` branch. Suite 701 pass, 0 fail. Inversion check: dropping the kind pin from `set_fold_seed()` reddens the ambient-state test, so it has power. `check_workflow()` uses `workflows::is_trained_workflow()` — trained-ness is a field, not a class, and the first attempt tested `inherits(x, "trained_workflow")`, which never fires.
- 2026-07-25: T9 done — roxygen (Reproducibility and Differences-from-tune sections carry the hand-replication contract and IP2's R-RNG scope), `_pkgdown.yml` rows for `nested_tune_grid`, the `collect_metrics` method and reexports, NEWS.md entries. `document()` no-diff; `check_pkgdown()` clean; `devtools::check()` 0 errors / 0 warnings / 0 notes. The unused-`parsnip` NOTE T1 anticipated was resolved by giving the import a real use — `parsnip::required_pkgs()` refuses a missing engine package up front instead of failing inside fold 1. A companion unknown-mode check was written and removed: `workflows::workflow()` already refuses such a spec, so the branch was unreachable and could not be fired by a test.
- 2026-07-25: all ten tasks done; status → review. Suite 702 pass / 0 fail; `devtools::check()` 0/0/0; `document()` no-diff; `check_pkgdown()` clean; `cairn_validate` green apart from the accepted sizing advisory. Open concern for review: DESIGN.md's Function Families and Architecture sections still read "(none yet — the package has no source)", which has been false since M01 and is now two exports out of date.
- 2026-07-26: merge approved by the user at the review gate for PR #2, but not executed — CI's `ubuntu-latest (release)` job has been stalled in `setup-r-dependencies` for 40+ minutes (the same job took 4m48s on the prior run of this branch, and its five siblings are green). An in-progress job cannot be re-run, so the merge waits rather than proceeding on a pending check. Approval stands; no `.merge-approved` marker written yet.
- 2026-07-25: /milestone-review — all 17 criteria evidenced and ticked; CI green on all six jobs; three-lens fan-out returned six findings, three actioned (F3 missing-id structural corruption, F1 NA-fold summary poisoning, F4 oracle assertions weaker than AC16 requires), three logged below threshold with F5 absorbed into the existing variance-estimation candidate and F6 given its own row. Both actioned code fixes verified by inversion.
- 2026-07-25: DESIGN.md Function Families and Architecture written from the code as it now stands, and the design-interview provenance note's "no source yet" clause corrected in place with a dated mark — current knowledge, fixed where it sits rather than appended to. Resolves the open concern raised at the review handoff; no code touched, checks unaffected.
- 2026-07-25: plan amendment (substantive) — AC1–AC7 and Scope Out compressed in one pass to fit the 150-line cap after the BC ingestion; no criterion dropped, AC2/AC3 shed detail now carried more precisely by AC16/AC17. T1/T2/T4/T5/T9 refined and T10 added for the RNG test battery.

## Decisions

- 2026-07-25: `nested_tune_grid()` takes no `control` argument in M02 — it
  builds `control_grid(allow_par = FALSE)` internally. One obvious path (GP3)
  and fewer branches to verify; adding the argument later is not a breaking
  change, so the choice is cheap to revisit once the parallelism milestone
  knows what it needs. The forced `allow_par = FALSE` is a GP1 divergence and
  is documented in the roxygen rather than left silent.

## Review

_2026-07-25. All evidence below re-run at review time on branch
`m02-outer-loop-orchestration` @ d6420c3, never recalled from implementation._

**Driving RR projection vs outcome (RR01).** RR01's binding criteria state
their own tolerance verbatim: "every equality below is exact (`identical()`),
same process, same platform, same package versions — no numeric tolerance is
granted or needed." RR01 carries no numeric projection (no figure, rate, or
factor), so there is no numeric pair to juxtapose. Measured against that stated
tolerance: every `identical()` assertion in the AC8–AC17 tests passes exactly.
_(Corrected after the fan-out: this line first claimed no assertion had been
relaxed to `equal`. That was false — the AC16 and AC17 tests used
`expect_equal()`, which carries testthat's 1.5e-8 numeric tolerance. Finding F4
caught it; the tests now use `expect_identical()` and pass, so the claim is true
as it now reads — 2026-07-25.)_

### Criterion evidence

- AC1 — `devtools::check(document = FALSE)` re-run at review, 5m02s.
  `Status: OK` — 0 errors, 0 warnings, 0 notes. No NOTEs to justify. The
  unused-`parsnip` NOTE seen mid-implementation is gone: the import is used by
  `check_model_spec()`.
- AC2 — `test-nested-tune-grid-oracles.R`, "per-fold metrics and selections
  match a hand-rolled reference loop": pass. The reference loop lives in
  `helper-orchestration.R` and shares no code with the driver.
- AC3 — same file, "a single-candidate grid degenerates to `fit_resamples()`":
  pass. Whole file 23 assertions, 0 failures.
- AC4 — `test-nested-tune-grid-leakage.R`: 57 assertions, 0 failures. Covers
  disjointness of each fold's held-out rows from its inner tuning and outer
  fit, and the split↔inner pairing the driver hands over.
- AC5 — `test-nested-tune-grid-results.R`: 30 assertions, 0 failures. Per-fold
  `.selected` retained; `collect_metrics()` verified in both modes, the
  summarized mean and standard error recomputed independently in the test.
- AC6 — `test-nested-tune-grid-checks.R`: 21 assertions, 0 failures. The outer
  bootstrap is refused via `cli_abort()` on an `rsample::nested_cv()` design
  that rsample itself only warns about; every `cli_abort()` branch in
  `R/checks.R` is fired.
- AC7 — `devtools::document()` then `git status --porcelain man NAMESPACE`:
  empty, so no diff. `pkgdown::check_pkgdown()`: "No problems found."
  `NEWS.md` carries three entries for the user-visible change.
- AC8 — the only `sample.int()` in the package is `R/nested-tune-grid.R:121`,
  at entry and outside the fold loop, drawing `2L * n`. No `set.seed()` or
  draw occurs inside `nested_fold_fit()`. Positional assignment at
  `R/nested-results.R:18-19` (`seq(1L, by = 2L)` / `seq(2L, by = 2L)`).
- AC9 — `set_fold_seed()` (`R/nested-tune-grid.R:173-179`) passes
  `kind = "Mersenne-Twister"`, `normal.kind = "Inversion"`,
  `sample.kind = "Rejection"`. Called at `:145` immediately before
  `tune::tune_grid()` and at `:160` immediately before `tune::last_fit()`.
- AC10 — `.tuning_seed` and `.outer_fit_seed` columns present on the returned
  object (asserted in `test-nested-tune-grid-results.R`); the roxygen
  `@section Reproducibility` states the hand-replication contract as a runnable
  block in terms of those two columns.
- AC11 — `on.exit(restore_rng(...), add = TRUE)` at `:119`, registered before
  any fold runs. Three tests pass: net-zero exit (state, kind, and a following
  `runif()` matching a run without the call), restore after a fold errors, and
  a session with no `.Random.seed` left with a valid one.
- AC12 — `DESCRIPTION` Imports reads `tune (>= 2.0.0)`.
- AC13 — `test-nested-tune-grid-rng.R`, same-seed identity on the ranger
  engine: `identical()` on per-fold metrics and selected parameters; companion
  seed-sensitivity assertion shows a different seed changes both.
- AC14 — same file, order-invariance: folds driven through
  `nested_fold_fit()` in reversed order reproduce the driver's in-order output
  `identical()`ly.
- AC15 — same file, ambient-state independence: the worker's output for fixed
  seeds is `identical()` from a default Mersenne-Twister state, from an
  L'Ecuyer-CMRG state, and from a mid-stream state. Inversion check recorded
  during implementation: removing the kind pin reddens this test, so it has
  power.
- AC16 — the AC2 test derives expected seeds from its own `set.seed()` +
  `sample.int()` per the documented contract, asserts they equal the exposed
  columns *before* comparing any metric, then asserts metrics and selections
  match; run in both a deterministic and a stochastic variant, both pass.
- AC17 — the AC3 test uses the RNG-free recipe/lm engine only. No test asserts
  stochastic-engine identity with `fit_resamples()`.

### Consistency gate

- `cairn_validate.py`: exit 0. All checks PASS, including `binding criteria`
  (AC8–AC17 string-match RR01's BC1–BC10) and `coverage complete`. One
  advisory: `sizing (split tripwires)` — 17 acceptance criteria against a ~7
  tripwire. Advisory only, and the maintainer elected at the implementation
  gate to carry M02 as one milestone rather than split it.
- `cairn_impact.py`: skipped — no `DESIGN.md` principle (IPn/GPn) changed.
  DESIGN.md's Function Families and Architecture sections were filled in, and
  the interview provenance note corrected, but no principle text moved.
- CI on PR #2: all six jobs pass — ubuntu release / devel / oldrel-1,
  windows release, macos release, and test-coverage.
- Profile `consistency-gate` slot (`r-package`): `document()` no-diff ✓;
  generated files not hand-edited ✓; no README.Rmd in the repo, so the knit
  check is a no-op; `check_pkgdown()` ✓; `NEWS.md` entry present ✓; no new
  top-level files needing `.Rbuildignore` entries ✓; `devtools::check()` clean
  ✓.

### Independent fresh-context review

Three reviewers, distinct evidence bases, none of which had seen the
implementation; then a fourth agent scored every surviving finding.

- **[S] blame-history** (git log/blame on modified regions, D-entries,
  LESSONS, M01's archive): no findings. Confirmed the M01→M02 RNG divergence
  is the one D-011 authorized, and that M01's pinning test is untouched.
- **[S] prior-PR-comments**: no findings. Archived `## Review` sections and
  RB01/RR01 checked; the GitHub inline-comment probe returned `[]`, so the
  thread walk was correctly skipped. Verified BC1–BC10 are implemented as
  RR01 specified, with no undocumented deviation.
- **[O] diff-bug**: six findings, below with scores.

**Actioned (scored ≥ 80):**

- F3, score 92 — `check_nested()` accepted a design with `splits` and
  `inner_resamples` but no `id` column; the whole loop then ran to completion
  before `new_tbl()` assembled an object whose columns disagreed in length,
  aborting only when printed. Fixed: an `id*` column is now required, so the
  call fails in a second rather than after every fold's compute. Regression
  test added; inverting the fix reddens it.
- F1, score 85 — `collect_metrics(summarize = TRUE)` used bare `mean()` and
  `sd()` while reporting `n` as the raw fold count, so one `NA` fold (an outer
  assessment set with a single class gives `roc_auc = NA`) produced a row
  reporting `mean = NA` with `n = 3`. A silent GP1 divergence from
  `tune::estimate_tune_results()`. Fixed to drop `NA` folds and count only
  contributing ones. Two regression tests added; inverting the fix reddens
  them.
- F4, score 85 — AC16 requires `identical()`, but the AC16 and AC17 tests
  asserted `expect_equal()`, which carries a 1.5e-8 numeric tolerance. Fixed:
  all three oracle comparisons now use `expect_identical()` and pass, so the
  binding criterion is met as written rather than approximately. The
  projection-vs-outcome line above, which had claimed otherwise, is corrected
  in place.

**Logged, below the action threshold (surfaced, not actioned):**

- F6, score 75 — a preprocessor-only workflow aborts from
  `workflows::extract_spec_parsnip()` rather than from one of this package's
  own `cli_abort()` calls with a hint. Accurate message, inconsistent
  discipline; a UX gap, not a correctness bug.
- F5, score 73 — `std_err` (naive `sd/sqrt(n)` across outer folds) ships in
  the default `collect_metrics()` output while variance estimation is Scope
  Out here and parked as contested under GP5. Kept because it mirrors tune's
  column set, but that reason is unstated in the roxygen. Real tension; a
  candidate row rather than a rushed fix.
- F2, score 65 — `order_of <- match(keys[first], keys[first])` was provably
  always the identity permutation, making five index applications no-ops.
  Below threshold, but it sat inside the exact block F1 required rewriting, so
  leaving provably dead code there while editing around it made no sense; the
  variable is gone as a side effect of F1's fix rather than as its own action.

Post-fix verification: `devtools::test()` 711 pass / 0 fail;
`devtools::check()` 0 errors / 0 warnings / 0 notes; `document()` no-diff.
