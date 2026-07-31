# M23: A worker is sent the fold, not six copies of the data

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP2, GP4
- **Branch/PR:** `m23-lean-fold-dispatch`

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
- [ ] AC8 A design from `rsample::nested_cv()`, whose folds share no single
      frame, is leaned too: with the sentinel taken from one fold's own inner
      analysis frame, the copy count across that fold's `.x` element plus its
      `.args` is exactly 1, against `inner_v` on the pre-milestone revision, and
      AC3's round-trip identity holds for such a design.

## Coverage

- AC1 → T1, T3, T4
- AC2 → T2, T3, T4
- AC3 → T2, T3
- AC4 → T4, T5
- AC5 → T6
- AC6 → T7
- AC7 → T8
- AC8 → T2, T3, T4

## Tasks

- [x] T1 Commit a measurement harness reporting, per outer fold, the serialized
      bytes of the `.x` element, of the `.args` list, and the sentinel copy
      count. Run it on the pre-milestone revision and record the baseline in the
      work log.
- [x] T2 Write the failing tests first: AC2's closed-form bound and copy count,
      and AC3's round-trip identity for the outer split and the inner `rset`.
- [x] T3 Add the lean/rehydrate pair to `R/parallel.R` — set `$data` to `NULL` on
      the outer split and on each inner split in place, so every other attribute
      survives untouched, and reattach on the worker. Each payload carries its
      fold's inner frame only when that frame is not the shared one `.args`
      already holds, which is what covers designs from `rsample::nested_cv()`.
- [x] T4 Wire them into the parallel branch of `dispatch_folds()`
      (`R/parallel.R:64-118`): lean the payloads before `mirai_map()`, add the
      data to `.args`, and rehydrate in `fold_task()` (`R/parallel.R:428-438`)
      before `nested_fold_fit()`. Leave the serial branch at line 68 untouched.
- [x] T5 Run the parallel identity suite under `ranger` at two above-threshold
      daemon counts; confirm `identical()` and that the daemon-gated tests are
      counted rather than skipped.
- [x] T6 Mutation-verify both guards per AC5, and record what each mutation did.
- [x] T7 Roxygen the dispatch claim on `nested_tune_grid()`, and name AC2's two
      guards in the asserting test file's oracle-record header.
- [x] T8 Re-anchor any `file:line` rows in the time-budget ledger that moved, and
      run the profile `verify` slot clean.

## Work log

- 2026-07-30: created by /milestone-plan.
- 2026-07-30: measured baseline before scoping, per the candidate row's "measure before designing". Data 840,540 B; one fold's payload 5,141,166 B = 6.12x, literally 6 copies by sentinel count; five payloads 25,705,830 B. `lobstr::obj_size()` reports 946.94 kB for the same payload, so the in-memory measure is blind to this defect (M13's shared-content lesson).
- 2026-07-30: read `mirai::mirai_map` (mirai 2.7.2) — `.args` is serialized once per task, not once per run, so the floor for this shape is one data copy per fold.
- 2026-07-30: plan gate chose lean payloads with the data in `.args` over also preloading daemons via `mirai::everywhere()` because the latter makes the user's pool stateful across runs and only wins when folds outnumber daemons; falsified by a measured run where per-fold `.args` transfer, not the payload, is the dominant cost for a formula workflow.
- 2026-07-30: plan gate chose leaving `recipe$template` out over trimming it because it is surgery on a recipes-owned object whose other readers of that copy are unestablished (GP1); falsified by evidence that no recipes code path reads `template` for its rows.
- 2026-07-30: settled autonomously — the change lands on the parallel branch only, rejecting a single lean path shared with serial, because IP2's parallel-vs-serial test does real work only while serial stays the untouched reference; falsified by a rehydration defect that a serial-path comparison could not see.
- 2026-07-30: criteria audit ([O], fresh context) returned six findings on the six drafted criteria: AC1 measured only `.x` while the data it moves lands in `.args`; AC2's bar was unreachable on a recipe fixture and named no fixture; AC3 was already satisfied by pre-milestone code; AC4 over-specified capture inside the worker; AC5 could not fail; AC6 named a guard structurally unable to test its claim. Also flagged: one oracle type where the repo's precedent for size claims uses two, and skip-vacuity on the daemon-gated tests. AC1/AC3/AC4/AC5/AC6 and both cross-cutting findings fixed before the gate; the fixture and bar became gate questions.

- 2026-07-30: implement gate found the plan's "one copy in `.args`" incomplete — `nested_tune_grid()` also accepts `rsample::nested_cv()` designs (`R/checks.R:115`), whose folds each materialize their own inner analysis frame (measured: inner1 frame 1333 of 2000 rows, not the outer split's data, and different from inner2's). Invariant holding for both constructors: within one fold every inner split shares one frame. Amended at the gate — AC8 added, T3 rewritten, coverage extended.
- 2026-07-30: `identical()` has a pointer fast path (0.04 ms vs 1.05 ms per call on a 32 MB frame), so "is this the shared frame?" is decided per fold at no measurable cost; an equal-but-distinct frame answering TRUE is sound here, since substituting one for the other is what rehydration does anyway.
- 2026-07-30: minor refinement — the lean form sets `$data` to `NULL` in place rather than reconstructing the inner `rset` from ids and classes, so every other attribute survives by construction and AC3's `identical()` round-trip is exact rather than reassembled.

- 2026-07-30: T1 baseline, `benchmarks/dispatch-payload-size.R`, R 4.6.1 / rsample 1.3.2 / mirai 2.7.2, fixture n=5000 x 21, v=5, inner_v=5. `nested_resamples` design: payload 5,141,166 B per fold, 6 copies of the data by sentinel count, `.args` 1,761 B per fold, TOTAL WIRE 25,714,635 B. `rsample::nested_cv` design: payload 4,285,186 B per fold, 1 shared copy plus 5 of the fold's own analysis frame, TOTAL WIRE 21,434,735 B. Closed-form prediction for a leaned payload: 96,000 B.
- 2026-07-30: the harness measured `.args` at 26,549,958 B until its own workflow was pinned — a formula built inside a function carries that function's frame, and R serializes an ordinary environment by contents while `globalenv()` and namespaces go by reference (the mechanism M12's hashing lesson records). Realistic value is 1,761 B. Left in the script as a named trap rather than silently fixed, since a user building a formula in a data-holding scope pays it for real.

- 2026-07-30: T2-T4 done. Suite green, 0 failures. Measured after-state on the T1 fixture: `nested_resamples` design 25,714,635 -> 4,705,635 B (18.3%, 5.5x); `rsample::nested_cv` design 21,434,735 -> 7,988,195 B (37.3%, 2.7x), the difference being that fold's own materialized analysis frame, which AC1's bar does not cover and AC8's copy count does.
- 2026-07-30: two corrections to the plan's "serial branch untouched" premise, both found by the suite rather than by reading. `fold_task()` is shared by BOTH branches, so adding a parameter to it broke every serial test; and `dispatch_folds()` is driven directly by test-parallel-interrupt.R with stand-in payloads carrying neither split nor inner rset. Resolved by leaning only when every payload is positively recognised as a fold payload (`is_fold_payload()`), and by wrapping rehydration around `fold_task` rather than inside it. The serial branch's own call is byte-identical to before.
- 2026-07-30: the wrapper's first form resolved `fold_task` by name inside the daemon and silently bypassed `local_mocked_bindings()`, turning BC3's daemon-kill test green while the mock never ran — M07's lesson is that the mock reaches a daemon precisely because the function is captured by value and serialized. The worker is now passed by value through `.args`, which also means a mock receives rehydrated payloads instead of having to hand-roll rehydration itself.
- 2026-07-30: the worker closure measured 202,363 B per fold under `pkgload::load_all()` against 524 B re-parsed — srcrefs are serialized with a function and their presence depends on how the package was installed, not on the run. `removeSource()` at dispatch makes the wire cost the same either way. Same class of measurement trap as the harness's formula environment at T1.

- 2026-07-30: T5 done. Full suite green with no skips — parallel-classify, parallel-identity, parallel-interrupt, parallel-payload and suite-hygiene all executed. AC4's anti-skip clause was vacuous as written, since this milestone's byte oracles need no daemons, so a daemon-gated test was added that asserts the payload a worker actually receives has been rehydrated on both the outer split and the inner splits and is back to three fields.
- 2026-07-30: T6 done, both mutations. Removing the worker-side rehydration errors the daemon test. Reinstating the fat payload reddens seven assertions across all three guards — closed-form size (68, 71), copy count (88, 89), the wire ratio (138), and the rsample-design copy count and round trip (157, 158). Recorded because the default reporter caps at 10 failures and silently truncated the first two attempts to five of the seven: a mutation check read off a capped reporter under-reports which guards fire.
- 2026-07-30: T7-T8 done. Roxygen states the one-copy-per-fold claim and names the two objects it does not reach (a recipe's retained data, a formula's captured environment). `test-parallel-payload.R` added to the budget ledger's file list with a `start_daemons` row. `R CMD check` clean: 0 errors, 0 warnings, 0 notes.
- 2026-07-30: `utils::removeSource()` on the worker closure was implemented, measured (203,790 B against 524 B), and then REMOVED — `utils` is not in Imports and adding a dependency mid-implementation needs its own gate. The gain is development-only, since an installed package carries no srcrefs, and the same closure was already serialized as `.f` before this milestone, so it is outside AC1's accounting on both sides. Recorded as a candidate row at review.
- 2026-07-30: final AC1 measurement, T1 fixture. Task closure excluded on both sides, as the criterion's accounting has it: 25,714,635 -> 4,702,950 B = 18.3%. Included on both sides under `load_all`: 26,733,585 -> 5,721,900 B = 21.4%. Under the 25% bar either way.

## Decisions

## Review
