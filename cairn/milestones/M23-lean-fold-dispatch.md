# M23: A worker is sent the fold, not six copies of the data

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP2, GP4
- **Branch/PR:** —

## Goal

Dispatching an outer fold to a mirai daemon sends one copy of the data instead
of one per inner split, so the leanness `nested_resamples()` achieves in memory
survives the process boundary.

## Scope

**In:** Leaning each fold's dispatch payload — `$data` stripped from the outer
split and from every inner split — with one copy of the data travelling in
`mirai_map()`'s `.args` and reattached on the worker before `nested_fold_fit()`
runs. A committed harness that measures what a dispatch actually serializes, and
two independent oracles guarding the result in the suite.

Changed on the **parallel branch of `dispatch_folds()` only**; the serial branch
keeps passing the objects it passes today, so serial results are provably
unmoved and IP2's parallel-vs-serial comparison keeps a fixed reference.

**Out:**
- Trimming `recipe$template`, which retains the full training data and rides in
  `.args` once per fold (measured 847,146 B against 840,540 B of data, 1 sentinel
  copy) → candidate row. It is surgery on a recipes-owned object, a different
  risk under GP1 than reshaping our own payload.
- Pushing the data into daemons once per run via `mirai::everywhere()` →
  candidate row. It beats this milestone's shape only when folds outnumber
  daemons, and it makes the user's pool stateful across runs.
- Any change to `nested_tune_grid()`'s signature (D-018) or a new option
  (D-020). None is needed.

## Acceptance criteria

- [ ] AC1 On the T1 fixture — 5000 rows x 21 columns, outer `v = 5`, inner
      `v = 5`, a formula workflow, fixed seed — the total bytes one run
      serializes, counting each fold's `.x` element **and** the `.args` list sent
      with it, is at most 25% of the same total measured by the same harness on
      the pre-milestone revision. Baseline recorded in the work log at T1.
- [ ] AC2 The payload-size claim is confirmed by two oracles that share no
      arithmetic. **Closed form:** `length(serialize(p, NULL))` for each `.x`
      element `p` is within 15% of a prediction computed in the test from the
      scalars `n`, `v`, `inner_v` alone — never from lengths read off `p` —
      namely 4 bytes per integer for the outer split's analysis index plus an
      analysis and an assessment index per inner split. **Copy count:**
      `grepRaw(sentinel, serialize(p, NULL), all = TRUE, fixed = TRUE)` finds the
      data's own wire bytes 0 times in `p` and exactly 1 time across `p` plus its
      `.args`, against 6 and 6 on the pre-milestone revision.
- [ ] AC3 For the outer split and the inner `rset` of every fold in the fixture
      design, rehydrating a leaned payload returns an object `identical()` to the
      one the serial branch passes. Asserted in-process, with no daemon.
- [ ] AC4 Under `mirai::daemons(2)`, `nested_tune_grid()` with a `ranger`
      workflow returns a result `identical()` to the same call under
      `mirai::daemons(0)` for the same seed (IP2), and every daemon-gated test
      this milestone adds proves it executed rather than skipped, via the
      assertion-count check in `test-suite-hygiene.R`.
- [ ] AC5 Both guards are shown to fail when the thing they guard is removed:
      deleting the worker-side rehydration turns the suite red, and reinstating
      the pre-milestone fat payload turns AC1's and AC2's guards red. Both
      mutations run and recorded.
- [ ] AC6 `nested_tune_grid()`'s roxygen states that dispatching a fold sends one
      copy of the data rather than one per inner split, and the oracle-record
      header of the asserting test file names AC2's two guards as the tests of
      that claim.
- [ ] AC7 The profile `verify` slot is clean: `devtools::test()` passes and
      `devtools::document()` is current after the roxygen change.

## Coverage

- AC1 → T1, T3, T4
- AC2 → T2, T3, T4
- AC3 → T2, T3
- AC4 → T4, T5
- AC5 → T6
- AC6 → T7
- AC7 → T8

## Tasks

- [ ] T1 Commit a measurement harness reporting, per outer fold, the serialized
      bytes of the `.x` element, of the `.args` list, and the sentinel copy
      count. Run it on the pre-milestone revision and record the baseline in the
      work log.
- [ ] T2 Write the failing tests first: AC2's closed-form bound and copy count,
      and AC3's round-trip identity for the outer split and the inner `rset`.
- [ ] T3 Add the lean/rehydrate pair to `R/parallel.R` — strip `$data` from the
      outer split and each inner split, carry the inner `rset`'s ids and classes,
      reattach on the worker.
- [ ] T4 Wire them into the parallel branch of `dispatch_folds()`
      (`R/parallel.R:64-118`): lean the payloads before `mirai_map()`, add the
      data to `.args`, and rehydrate in `fold_task()` (`R/parallel.R:428-438`)
      before `nested_fold_fit()`. Leave the serial branch at line 68 untouched.
- [ ] T5 Run the parallel identity suite under `ranger` at two above-threshold
      daemon counts; confirm `identical()` and that the daemon-gated tests are
      counted rather than skipped.
- [ ] T6 Mutation-verify both guards per AC5, and record what each mutation did.
- [ ] T7 Roxygen the dispatch claim on `nested_tune_grid()`, and name AC2's two
      guards in the asserting test file's oracle-record header.
- [ ] T8 Re-anchor any `file:line` rows in the time-budget ledger that moved, and
      run the profile `verify` slot clean.

## Work log

- 2026-07-30: created by /milestone-plan.
- 2026-07-30: measured baseline before scoping, per the candidate row's "measure before designing". Data 840,540 B; one fold's payload 5,141,166 B = 6.12x, literally 6 copies by sentinel count; five payloads 25,705,830 B. `lobstr::obj_size()` reports 946.94 kB for the same payload, so the in-memory measure is blind to this defect (M13's shared-content lesson).
- 2026-07-30: read `mirai::mirai_map` (mirai 2.7.2) — `.args` is serialized once per task, not once per run, so the floor for this shape is one data copy per fold.
- 2026-07-30: plan gate chose lean payloads with the data in `.args` over also preloading daemons via `mirai::everywhere()` because the latter makes the user's pool stateful across runs and only wins when folds outnumber daemons; falsified by a measured run where per-fold `.args` transfer, not the payload, is the dominant cost for a formula workflow.
- 2026-07-30: plan gate chose leaving `recipe$template` out over trimming it because it is surgery on a recipes-owned object whose other readers of that copy are unestablished (GP1); falsified by evidence that no recipes code path reads `template` for its rows.
- 2026-07-30: settled autonomously — the change lands on the parallel branch only, rejecting a single lean path shared with serial, because IP2's parallel-vs-serial test does real work only while serial stays the untouched reference; falsified by a rehydration defect that a serial-path comparison could not see.
- 2026-07-30: criteria audit ([O], fresh context) returned six findings on the six drafted criteria: AC1 measured only `.x` while the data it moves lands in `.args`; AC2's bar was unreachable on a recipe fixture and named no fixture; AC3 was already satisfied by pre-milestone code; AC4 over-specified capture inside the worker; AC5 could not fail; AC6 named a guard structurally unable to test its claim. Also flagged: one oracle type where the repo's precedent for size claims uses two, and skip-vacuity on the daemon-gated tests. AC1/AC3/AC4/AC5/AC6 and both cross-cutting findings fixed before the gate; the fixture and bar became gate questions.

## Decisions

## Review
