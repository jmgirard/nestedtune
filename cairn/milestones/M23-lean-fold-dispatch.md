# M23: A worker is sent the fold, not six copies of the data

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP2, GP4
- **Branch/PR:** `m23-lean-fold-dispatch` / https://github.com/jmgirard/nestedtune/pull/24

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

- [x] AC1 On the T1 fixture — 5000 rows x 21 columns, outer `v = 5`, inner
      `v = 5`, a formula workflow, fixed seed — the total bytes one run
      serializes, counting each fold's `.x` element **and** the `.args` list sent
      with it, is at most 25% of the same total measured by the same harness on
      the pre-milestone revision. Baseline recorded in the work log at T1.
- [x] AC2 The payload-size claim is confirmed by two oracles that share no
      arithmetic. **Closed form:** `length(serialize(p, NULL))` for each `.x`
      element `p` is within 15% of a prediction computed in the test from the
      scalars `n`, `v`, `inner_v` alone — never from lengths read off `p` —
      namely 4 bytes per integer for the outer split's analysis index plus an
      analysis and an assessment index per inner split. **Copy count:**
      `grepRaw(sentinel, serialize(p, NULL), all = TRUE, fixed = TRUE)` finds the
      data's own wire bytes 0 times in `p` and exactly 1 time across `p` plus its
      `.args`, against 6 and 6 on the pre-milestone revision.
- [x] AC3 For the outer split and the inner `rset` of every fold in the fixture
      design, rehydrating a leaned payload returns an object `identical()` to the
      one the serial branch passes. Asserted in-process, with no daemon.
- [x] AC4 Under `mirai::daemons(2)`, `nested_tune_grid()` with a `ranger`
      workflow returns a result `identical()` to the same call under
      `mirai::daemons(0)` for the same seed (IP2), and every daemon-gated test
      this milestone adds proves it executed rather than skipped, via the
      assertion-count check in `test-suite-hygiene.R`.
- [x] AC5 Both guards are shown to fail when the thing they guard is removed:
      deleting the worker-side rehydration turns the suite red, and reinstating
      the pre-milestone fat payload turns AC1's and AC2's guards red. Both
      mutations run and recorded.
- [x] AC6 `nested_tune_grid()`'s roxygen states that dispatching a fold sends one
      copy of the data rather than one per inner split, and the oracle-record
      header of the asserting test file names AC2's two guards as the tests of
      that claim.
- [x] AC7 The profile `verify` slot is clean: `devtools::test()` passes and
      `devtools::document()` is current after the roxygen change.
- [x] AC8 A design from `rsample::nested_cv()`, whose folds share no single
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

_Evidence gathered fresh at review on 2026-07-30, by command. PR
https://github.com/jmgirard/nestedtune/pull/24._

- **AC1** — `benchmarks/dispatch-payload-size.R` accounting on the T1 fixture,
  before and after, counting each fold's `.x` element and the `.args` list sent
  with it: 25,714,635 B -> 5,720,370 B = **22.2%**, under the 25% bar. The
  after-figure's `.args` includes the 203,790 B task closure that srcrefs add
  under `pkgload::load_all()`; from an installed library, where srcrefs are
  absent, the same accounting reads 18.3%. Both under the bar. Asserted in the
  suite by `a leaned run puts under a quarter of the pre-milestone bytes on the
  wire`, which recomputes its own baseline rather than freezing one.
- **AC2** — both oracles pass in `test-parallel-payload.R`. Closed form: each
  leaned payload within 15% of the prediction from `n`/`v`/`inner_v` alone
  (predicted 96,000 B). Copy count: 6 copies in the pre-milestone payload, 0 in
  the leaned one, exactly 1 across the payload plus its `.args`.
- **AC3** — `rehydrating a leaned payload returns the serial path's own objects`
  asserts `identical()` on the whole payload, not on chosen fields, for every
  fold of the fixture design. Passes.
- **AC4** — full suite run fresh at review: 0 failures, 0 errors, and **0 skips**
  (`parallel-identity`, `parallel-payload`, `parallel-interrupt`,
  `parallel-classify`, `suite-hygiene` all executed). The identity suite's
  serial-vs-parallel `identical()` comparison passes on the new dispatch path.
  The clause's "every daemon-gated test this milestone adds" is satisfied by the
  one such test added, `a daemon receives the payload the serial branch would
  have passed`, which ran rather than skipped.
- **AC5** — both mutations re-run at review, not carried over from implement.
  Removing the worker-side rehydration errors `test-parallel-payload.R:213`.
  Reinstating the fat payload reddens seven assertions across all three guards:
  closed form (68, 71), copy count (88, 89), the wire ratio (138), and the
  rsample-design copy count and round trip (157, 158).
- **AC6** — `man/nested_tune_grid.Rd` carries the one-copy-per-fold claim; the
  oracle-record header of `test-parallel-payload.R` names both guards (O1
  closed-form, O2 copy count) as the tests the claim rests on.
- **AC7** — `devtools::test()` clean; `devtools::document()` produces no diff;
  `devtools::check()` **0 errors, 0 warnings, 0 notes**.
- **AC8** — `a design whose folds share no frame is leaned too` passes: for an
  `rsample::nested_cv()` design the fold's own analysis frame is confirmed not
  to be the shared one, its copy count goes 5 -> 1, and the round trip is
  `identical()`.

**Consistency gate.** `cairn_validate` — all 16 checks PASS, 8 advisories OK, one
advisory WARN: `sizing (split tripwires)` reports 8 acceptance criteria against
the >7 tripwire. Not a gate failure; the eighth was added at the implement gate
when `rsample::nested_cv()` designs were found to need their own handling.
Toolchain slot: `document()` no-diff clean, `pkgdown::check_pkgdown()` no
problems, no `README.Rmd` in this repo, NEWS.md entry present and free of
milestone numbers, `check()` clean with no new top-level file NOTEs. No
`DESIGN.md` principle changed, so `cairn_impact` does not apply.

**CI on PR #24** — green on every platform: ubuntu release / devel / oldrel-1,
macos-latest, windows-latest, build, and test-coverage.

**Returns to `/milestone-implement`:** none. This is a first pass; the thrash
rule does not fire.

### Findings

Three fresh-context lenses. The blame-history and prior-PR-comments lenses
reported **zero findings** each — the first confirming the M03/M07/M15 comment
blocks it was pointed at are byte-identical to `main` and that M16's ledger
discipline is honoured, the second probing the GitHub review-comment API (empty)
and reading the archived `## Review` sections for M07, M09, M10, M12, M14, M15,
M16 and M20. The diff-bug lens reported 16, scored by a fresh scorer that did not
generate them.

**Actioned (scored >= 80), all four fixed on the branch:**

- **F1 (93) — the one-frame-per-fold invariant was assumed but unenforced.**
  `lean_payload()` takes the inner frame off `splits[[1]]` and
  `rehydrate_payload()` writes it back onto every inner split, which is sound
  only if they shared it. `check_nested()` never checked that, so a
  `manual_rset()` of splits over different frames was admitted and then tuned on
  the wrong rows in parallel and the right ones serially — demonstrated by
  execution: serial chose `min_n = 15` / rmse 0.960, `daemons(2)` chose
  `min_n = 5` / rmse 1.15, `identical()` FALSE. A direct IP2 breach and an IP1
  exposure wherever the substituted frame holds outer assessment rows. Fixed by
  making `is_fold_payload()` verify the invariant, so such a design takes the fat
  path — slower and correct. Re-verified: the same design now dispatches
  `parallel` and returns a result `identical()` to serial.
- **F2 (90) — nothing proved the dispatch path leans at all.** Forcing
  `is_fold_payload()` to return FALSE — turning the milestone into a production
  no-op — left all 55 assertions green, because every byte oracle calls
  `lean_payload()` directly and an un-leaned payload is indistinguishable from a
  leaned-then-rehydrated one. Fixed with a test asserting the gate recognises
  real fold payloads from both constructors and rejects the stand-in shapes.
- **F3 (85) — the closed-form band did not catch the bug its header claimed.**
  Dropping one inner split measures 81,796 B against a 96,000 B prediction, a
  14.8% deviation that passed the `< 0.15` band by 0.2%. Band tightened to 0.05
  against a measured 2.4% margin.
- **F4 (82) — the helper said the benchmark sources it; the benchmark did not.**
  It carried its own copies of all five oracles, already diverged by one
  `stopifnot`, in the comment citing M16's drift lesson. The benchmark now
  sources the helper, and gained the "after" measurement it lacked, so both
  halves of the work-log figure are reproducible by running it.

**Fixed opportunistically though below threshold**, being one-line changes to the
predicate F1 and F2 required rewriting anyway: **F7 (55)** `all(logical(0))` is
TRUE, so an empty dispatch reached `payloads[[1L]]` and a subscript error after
the pre-flight had paid its round trip — now length-guarded; **F8 (60)** the
predicate used `$`, which partial-matches, so it would have answered a payload
carrying `splits`/`inner_resamples` — now `[[` and `%in% names()`, the
discipline `is_fold_record()` uses and which its comment claimed parity with.

**Logged, not actioned (scored < 80).** Twelve findings, surfaced rather than
dropped: F15 (70) NEWS and roxygen state the identity claim unconditionally —
dissolved by F1's fix, since the invariant is now enforced; F6 (62) a daemon
running a pre-M23 installed copy reports every fold as a worker failure and the
`requireNamespace()` pre-flight cannot distinguish it; F9 (58) one odd fold
disables leaning for the whole run, `all()` being all-or-nothing where per-fold
would do; F5 (50) no end-to-end daemon identity test for `rsample::nested_cv()`
designs, the shape AC8 was added for, verified manually to hold; F13 (45)
`lean_payload()` open-codes `split_data()`; F14 (45) `shared` is fold 1's frame
by fiat, a performance-only concern if fold 1 is the odd one out; F16 (40) the
rehydration mutation fails inside `vapply` rather than as a named assertion;
F10 (30) `identical()` treats `0` and `-0` as equal; F11 (30) `outer_data` and
`inner_data` are reserved payload names with no collision guard; F12 (25)
stripping the worker's environment now silently applies to a mocked `fold_task`.

**Re-verified after the fixes:** full suite 0 failures, `devtools::check()` 0
errors / 0 warnings / 0 notes, `cairn_validate` all checks pass. The time-budget
guard caught its own case along the way — the inserted tests moved
`start_daemons` from line 180 to 224 and staled the ledger anchor, exactly the
M16/M21 failure it exists to catch; re-anchored.

**AC1 re-measured after the fixes**, from the committed harness: 25,714,635 B ->
5,783,645 B = **22.5%**, under the 25% bar. The figure carries the srcref-laden
task closure `pkgload::load_all()` produces; from an installed library it is
18.3%.

**Coverage.** Codecov failed the first push after the fixes — 94.82% of the diff
hit against a 98.23% target — and named the branch nothing exercised: a fold
whose *outer* frame is not the shared one, which F5 and F14 both circled and
which had been verified only by hand. Two tests closed it: one covering that
branch through `lean_payload()`/`rehydrate_payload()`, one covering each of the
gate's refusal clauses with payloads carrying the right field names and the wrong
contents. Final: **100.00% of the diff hit**, project 98.30% (+0.07% against
base). The time-budget guard fired twice more while these landed, each time
because an inserted test moved the `start_daemons` anchor — re-anchored each
time, which is the guard doing its job.

**Final CI on PR #24, all green:** ubuntu release / devel / oldrel-1, macos,
windows, build, test-coverage, codecov/patch, codecov/project.

