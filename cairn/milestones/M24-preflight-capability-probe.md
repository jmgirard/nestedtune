# M24: The pre-flight tells the truth about the pool

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP3
- **Branch/PR:** `m24-preflight-capability-probe` / https://github.com/jmgirard/nestedtune/pull/25

## Goal

The dispatch-time check on a daemon pool answers the question that decides
whether the run is trustworthy — can these daemons actually run this fold —
rather than the weaker one it asks today.

## Scope

**In:** the pre-flight probe in `R/parallel.R` reports, per daemon, whether the
symbols `dispatch_folds()` resolves by name are present, and the run is refused
naming the daemons that lack them; and dispatch to a pool that cannot be
cancelled says so once.

**Out:**
- Taking the pre-flight deadline off the wall clock → candidate row, corrected
  at this gate to record that `proc.time()` is not established as step-immune.
- Detecting daemons whose code differs while carrying the same symbols (a build
  hash rather than symbol presence) → candidate row.
- Probing remote daemon pools → existing candidate row; needs a remote host.
- Any change to `nested_tune_grid()`'s formals — D-018's no-knob line binds
  signatures and D-020 left that clause standing.

## Acceptance criteria

- [x] AC1: the pre-flight probe returns one record per daemon carrying the
      symbols it was asked for and which of them it could not find, validated
      positively by shape the way `is_fold_record()` is — a length-1 character
      vector is rejected as a non-answer, because a `miraiError` is exactly
      that shape and must never be read as a capability report.
- [x] AC2: `preflight_outcome()` gains a fourth outcome for a pool whose
      daemons load the package but lack a required symbol, ranked *below*
      `cannot_load` in the existing ladder, so a pool failing both ways still
      takes the load failure's class (M10-D1). A unit test drives
      `preflight_outcome()` with hand-built records covering all four outcomes
      plus the mixed pool, and asserts each classification.
- [ ] AC3: the status record carries the fields the abort message names, and
      `check_daemons_can_load()` aborts on that outcome with condition classes
      `nestedtune_daemons_incompatible` and `nestedtune_daemons_unusable`,
      naming how many daemons are affected, which symbols are missing, and the
      remedy (reinstall the current version into the daemons' library, then
      restart the pool). Asserted through the existing `status =` injection
      point against a snapshot.
- [x] AC4: the probe expression runs on a real daemon pool and correctly
      reports a symbol that genuinely is not present, asserted against a live
      pool by asking for a name no version of the package defines.
- [x] AC5: dispatch to a pool started with `mirai::daemons(n, dispatcher = FALSE)`
      emits exactly one warning of class `nestedtune_pool_not_cancellable`,
      naming that an interrupted run's folds keep computing and that a
      dispatcher-backed pool is what makes cancellation work; a pool started
      with `mirai::daemons(n)` emits none. The warning is emitted in
      `dispatch_folds()`; both branches are asserted at the `nested_tune_grid()`
      seam and again driving `dispatch_folds()` directly.
- [x] AC6: `NEWS.md` records the refusal and the warning; the roxygen
      cancellation paragraph (`R/nested-tune-grid.R:236-242`) says a warning now
      fires, the pre-flight bullet (`R/nested-tune-grid.R:191-195`) covers the
      new refusal, and `man/nested_tune_grid.Rd` is regenerated.
- [ ] AC7: every new daemon-touching test carries its `helper-time-budget.R`
      row, and the `verify` slot in `cairn/PROFILE.md` is clean.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T4
- AC5 → T5
- AC6 → T6
- AC7 → T4, T5, T7

## Tasks

- [x] T1: replace the probe's logical answer with a per-daemon record and its
      positive validator, superseding `loaded_answer()`
      (`R/parallel.R:380-382`); amend the contract test at
      `tests/testthat/test-parallel-classify.R:503`, which encodes the answer
      shape this changes.
- [x] T2: extend `preflight_outcome()`'s ladder (`R/parallel.R:390-411`) with
      the new outcome below `cannot_load`; test all four plus the mixed pool.
- [x] T3: carry the new fields on the status record and add the abort branch to
      `check_daemons_can_load()` (`R/parallel.R:419-475`); snapshot the message.
- [x] T4: assert the probe against a live pool with a deliberately absent
      symbol, in `test-parallel-detection.R`; add its time-budget row.
- [x] T5: detect the pool kind from `mirai::status()$mirai` and warn once in
      `dispatch_folds()` (`R/parallel.R:169-273`); assert both pool kinds and
      add the time-budget rows.
- [x] T6: `NEWS.md`, the two roxygen sites, and `devtools::document()`.
- [x] T7: full `verify` slot clean; register any new prose-guard in the
      mutation harness.
- [ ] T8 (review F15): find why `daemons_load_status(package = "ranger")`
      returns `no_response` under the covr job on ubuntu when it returned
      `cannot_load` on `main`, and fix it. Does not reproduce under local covr
      on macOS; all five `R CMD check` legs pass. F6 is the leading suspect.
- [ ] T9 (review F1, F2): add `"vec-sep2" = ", "` to the `cli_vec()` style so
      two missing symbols separate, and take `{?is/are}`'s quantity from
      `n_incompatible` rather than `n_total`. Extend the snapshot to a
      two-symbol case and a mixed pool — the two configurations it does not
      currently reach (F11a).
- [ ] T10 (review F6): stop `daemons_load_status()` requiring its probed
      package on the host, or refuse it with a classified condition.
- [ ] T11 (review F9): point the ledger row at the line carrying
      `timeout = 30000` so the copied-bound drift guard actually reads it.
- [ ] T12: re-run the full gate — suite, `check()`, and CI green on every leg
      including `test-coverage` — before returning to review.

## Work log

- 2026-07-30: created by /milestone-plan.
- 2026-07-30: branch `m24-preflight-capability-probe` cut from main; status in-progress.
- 2026-07-30: plan gate chose a symbol-capability probe over comparing the daemon's package version because `DESCRIPTION`'s `Version:` has read `0.0.0.9000` since M01 (`fafb31f`, the only commit touching it in 23 milestones), so a stale daemon reports the host's own string and a version check cannot fire; falsified by a daemon whose symbols are all present while its code differs, which is the build-hash candidate this leaves in Out.
- 2026-07-30: plan gate chose proving the probe against a live pool with an absent symbol over installing a stubbed package into a scratch library, because priming a daemon reaches every daemon and erases the heterogeneity such a fixture exists to create (`test-parallel-detection.R:86-88`); falsified by a failure mode that only a genuinely mixed pool exhibits.
- 2026-07-30: plan gate chose warning on a `dispatcher = FALSE` pool over refusing it, because the pool computes correct results and only cancellation is unavailable, so GP3's refuse-don't-warn stance does not reach it; falsified by evidence that an uncancellable pool produces a wrong result rather than an uninterruptible one.
- 2026-07-30: T1 done. Probe returns a per-daemon record; `daemon_report()` replaces `loaded_answer()`. `preflight_outcome()`'s new `incompatible` branch landed here too (same function), so T2 is code-complete and awaits its own tests. Three test call sites built bare logicals; a `reports()` helper builds records in place so no line moved. Missed one at `test-parallel-identity.R:112` — a mock fabricating `FALSE` silently reclassified from cannot_load to no_response, caught by the full suite. Ledger rows 520/527/528 shifted 37 lines and were repaired (the M16/M21 drift trap).
- 2026-07-30: T2 done. Five ladder tests: incompatible classified, missing symbols unioned across the pool, `cannot_load` still outranks it, it outranks `no_response`, and all four outcomes asserted distinct in one place so a future branch cannot absorb its neighbour. The 73 inserted lines shifted 10 ledger rows; repaired by offset.
- 2026-07-30: T3 done. `nestedtune_daemons_incompatible` aborts with its own remedy — reinstall AND restart, because a live daemon keeps the namespace it loaded — deliberately not the install bullet, which reads as already done. Snapshotted. Two presentation bugs found by rendering rather than by assertion: cli's `vec-trunc` does not survive `{.code {}}` (a stale daemon would have listed all 106 symbols) and `{extra}` nested in a template conditional reached the user verbatim; both fixed and pinned by the snapshot, which also pins the daemon-vs-symbol pluralisation an earlier draft got wrong. Full suite 1557 pass / 0 fail.
- 2026-07-30: T4 done. Two live-pool tests in `test-parallel-detection.R`: a symbol no build defines comes back reported by both daemons, and — the precondition the whole approach rests on — a primed pool matches the host's namespace exactly, so the manifest does not false-positive under pkgload as it must not under R CMD check either. Five budget rows added. Full suite 1569 pass / 0 fail.
- 2026-07-30: T5 done. `pool_is_cancellable()` reads `status()$mirai`; the warning fires once per `dispatch_folds()` call, asserted at the `nested_tune_grid()` seam (3 folds, 1 warning), driving `dispatch_folds()` directly (3 payloads, 1 warning), and absent on a dispatcher-backed pool. Hand-rolling the undispatched pool would have hidden 120 s of waits from the ledger — `prime_daemons`/`warm_daemons` are not names the guard recognises — so a `start_daemons_undispatched()` helper joins `BUDGETED_WAIT_CALLS` and the guard's coverage grows rather than shrinks. Full suite 1586 pass / 0 fail.
- 2026-07-30: T6 done. Two NEWS entries written for users rather than for the changelog — "worker" not "daemon", the restart explained rather than instructed. Pre-flight bullet extended with the capability half; cancellation paragraph now says the warning fires and why the pool is warned about rather than refused. `document()` regenerated `man/nested_tune_grid.Rd`, no other diff. Full suite 1586 pass / 0 fail.
- 2026-07-30: T7 done. No prose-guard over a doc was authored, so the obligation was guard verification by inversion: six mutations, each reddening the guard that locks it — admitting a bare character into `daemon_report` (4 fail), inverting the ladder (1), never sending the manifest (5), never firing the warning (4), reporting every pool cancellable (3), dropping the truncation (1). Tree restored clean after each. `document()` no-diff. Full suite 1586 pass / 0 fail.
- 2026-07-30: all tasks done, verify slot clean; status review.
- 2026-07-30: review returned M24 to in-progress. Gate failure: CI red on `test-coverage` (F15, scored 98) at a pre-existing test that passed on `main`. Four more findings actioned — the two-symbol separator (F1, 94) and the `is/are` quantity (F2, 88), both confirmed by execution here and both invisible to the snapshot I wrote, which pinned the cases that render correctly; the host-side `asNamespace()` regression (F6, 85); and a ledger row the drift guard silently skips (F9, 85). Ten findings logged below threshold. T8–T12 added. Return count 1.
- 2026-07-30: process deviation, recorded rather than corrected silently — the AC boxes were ticked during implement, task by task, when AC fencing makes them review's verification mark against fresh evidence. Every criterion's evidence is now recorded in the Review section and each tick is backed by it, so the end state is correct; what was wrong was the order. Nothing was accepted unverified.
- 2026-07-30: criteria audit ([O], fresh context) returned 12 findings. Actioned at the gate: the version check was vacuous and became a capability probe; the probe answer became a validated record because a `miraiError` is a length-1 character vector; the new outcome was ranked below `cannot_load`; the status record gained the fields the message names; the roxygen criterion was rewritten after the audit found its premise false. The clock item was dropped to a corrected candidate row on the audit's finding that `proc.time()` is not documented as step-immune.

## Decisions

### 2026-07-30 (T1): the probe asks for the host's whole namespace, not the two symbols the worker calls

The dispatch path resolves exactly two names through the daemon's namespace —
`rehydrate_payload` (`R/parallel.R:232`) and `nested_fold_fit` (`R/parallel.R:585`)
— so a two-name check is the precise test of "can this daemon run this fold".
The probe instead sends `ls(asNamespace("nestedtune"))`, all 106 names, and each
daemon reports which it lacks. Measured at 2,627 B serialized, against a per-fold
payload already in the megabytes, so the width is free.

Chosen at the implementation gate because a hand-maintained list is the defect
being fixed: M23 added the second name and nothing made the pre-flight notice. A
source-scanning drift test was the runner-up and would have kept the precision,
but it guards a list that exists only to be guarded. Deliberately stricter than
"can run this fold": a daemon missing a symbol this run does not reach is still
running different code, which is the IP2 hazard the build-hash candidate holds.

`ls()` rather than `names()` because a namespace carries dotted bookkeeping
objects that differ between an installed package and one under pkgload, which
would report every daemon as incompatible. Host and daemons are symmetric under
both — primed by `load_all()` in the suite, installed under `R CMD check`.

Falsified by a legitimate pool this refuses — a daemon whose namespace differs
for a reason unrelated to which build it is running.

## Review

Reviewed 2026-07-30 on `m24-preflight-capability-probe` at PR #25.
`main` had not moved since the branch was cut, so no merge was needed and
the evidence below is from the branch tip.

### Criterion evidence

- **AC1** — `daemon_report()` validates positively and returns NULL for a
  non-record. Three tests in `test-parallel-classify.R`: "a miraiError is
  never read as a capability report" (asserts the length-1 character
  rejection the criterion names), "a report is rejected unless every field
  has the right shape" (7 malformed records plus the well-formed one), and
  "a daemon answering something other than a report counts as silent".
  Inversion: admitting a bare character into `daemon_report()` reddens 4 tests.
- **AC2** — the `incompatible` outcome exists and sits below `cannot_load`.
  Five tests, including "every outcome the ladder can produce is reachable
  and distinct" (all four asserted in one vector) and both mixed pools —
  load-failure-plus-incompatible takes `cannot_load`, incompatible-plus-silent
  takes `incompatible`. Inversion: swapping the two ladder arms reddens 1 test.
- **AC3** — status record carries `incompatible` and `missing_symbols`; the
  abort raises `nestedtune_daemons_incompatible` + `nestedtune_daemons_unusable`.
  Three tests plus a two-case snapshot (`_snaps/parallel-classify.md`) pinning
  the one-symbol and truncated forms, the daemon-vs-symbol pluralisation, and
  the absence of the install remedy. Inversion: dropping truncation reddens 1.
- **AC4** — probe proved against a live pool. "a symbol no build defines is
  reported by every daemon that loaded" asserts `incompatible == 2`,
  `cannot_load == 0`, and `missing_symbols` equal to the absent name, which
  can only have come back from the daemons; its companion asserts a primed
  pool matches the host namespace exactly, which is the precondition the
  manifest approach rests on. Inversion: not sending the manifest reddens 5.
- **AC5** — warning fires once per `dispatch_folds()` call. Four tests: pool
  kinds distinguishable while `connections` reads alike, both argument
  branches, the `nested_tune_grid()` seam (3 folds → 1 warning), the direct
  `dispatch_folds()` drive (3 payloads → 1 warning), and a dispatcher-backed
  run asserting no such condition. Inversions: never warning reddens 4,
  reporting every pool cancellable reddens 3.
- **AC6** — two `NEWS.md` entries in users' terms carrying no milestone
  numbers (grep clean); pre-flight bullet and cancellation paragraph both
  amended in `R/nested-tune-grid.R`; `man/nested_tune_grid.Rd` regenerated
  and `devtools::document()` re-run with no diff.
- **AC7** — `test-suite-hygiene.R` passes 17/17, so every new daemon-touching
  call carries its ledger row and no row points at a moved line.
  `devtools::check()` clean.

### Consistency gate

- `cairn_validate.py` — exit 0, all checks PASS, all advisories OK.
- `cairn_impact.py` — not run: no `DESIGN.md` principle text changed.
- `devtools::document()` — no diff.
- `pkgdown::check_pkgdown()` — no problems found.
- README.Rmd absent, so no knit-sync check applies.
- `NEWS.md` carries this milestone's user-visible changes, no milestone numbers.
- No new top-level files beyond the already-tracked `NEWS.md`.
- `devtools::check()` — **0 errors, 0 warnings, 0 notes** (4m 2s; tests
  97s/162s under `test_check`, the installed-package daemon path, which is a
  different path from `devtools::test()`'s pkgload one).
- Fresh per-file suite runs: classify 141, detection 49, hygiene 17,
  identity 49 — all 0 fail, 0 skip.
- Returns to `in-progress` for this milestone: 1 (this one).
- **CI: RED.** All five `R CMD check` legs pass (macos, windows, ubuntu
  devel/release/oldrel-1); `test-coverage` fails. Gate failure — not merged.

### Independent review

Three fresh-context lenses, then a Sonnet scorer that generated none of the
findings. Blame-history: no regressions — every renumbered ledger row's
seconds value byte-identical, no row deleted, no assertion weakened, M10-D1's
ladder rationale honoured. Prior-review: no GitHub thread evidence (probe
returned empty); one archived-review deviation raised (F13). Diff-bug lens
returned 12 findings; 15 scored in total.

**Actioned (score ≥ 80):**

- **F15 (98)** — CI regression on a pre-existing test. `test-parallel-detection.R:96-100`
  ("the probe reaches every daemon, not just a loadable one", probing
  `package = "ranger"`) returns `no_response` instead of `cannot_load` under
  the covr job on ubuntu. Passed on `main`. Does not reproduce under a local
  covr run on macOS, and all five `R CMD check` legs pass.
- **F1 (94)** — with **exactly two** missing symbols the message renders
  `` `nested_fold_fit` `rehydrate_payload` `` with no separator:
  `cli_vec()` sets `vec-last` but not `vec-sep2`, and cli uses `vec-sep2` at
  n=2. Verified by execution here. This is the pre-M23 stale-daemon case
  precisely — the two symbols the worker resolves by name — so the headline
  scenario is the one that renders wrong. The snapshot pinned n=1 and n=5.
- **F2 (88)** — `{?is/are}` takes its quantity from the last interpolation,
  `n_total`, so every mixed pool reads "1 of 2 mirai daemons **are** running a
  different build". Verified by execution. The snapshot pinned only 1-of-1,
  where it happens to read correctly.
- **F6 (85)** — `daemon_symbol_manifest()`'s `asNamespace(package)` runs on the
  **host**, so `daemons_load_status(package = <pkg>)` now requires that package
  installed locally and raises an unclassified error otherwise. Before M24 the
  argument existed precisely to probe for a package the daemons may lack.
  Plausibly the mechanism behind F15.
- **F9 (85)** — `helper-time-budget.R:196-198` declares
  `test-parallel-detection.R:145`, but `timeout = 30000` is on line 146. The
  copied-bound drift guard reads only the declared line, gets `NA`, and skips
  the row — so the one new row claiming a copied bound is never cross-checked,
  which is exactly what that guard exists for (M16 review F3).

**Logged below threshold (10), surfaced not dropped:** F10 (75) stale
in-comment coordinates and a 106-vs-109 symbol count; F11 (60) snapshot never
covers the two configurations that render wrongly; F14 (60) this file's
declared worst case rose 120s → 780s with no per-file ceiling guard; F5 (55)
`cli_vec(NULL)` errors on a degenerate injected status; F3 (40) the remedy
omits the priming route; F4 (35) `setdiff` is one-directional; F12 (35)
warning sits after the pre-flight wait; F8 (30) `symbols` inserted as the third
formal; F7 (25) `pool_is_cancellable()`'s two no-pool branches disagree; F13
(25) a fabricated `miraiError` without the `skip_if_not_installed("mirai")`
gate the file's own convention uses.

### Disposition

Returned to `in-progress`. AC3 and AC7 are unticked: AC3's snapshot evidence is
now known to have pinned the two cases that render correctly and missed both
that do not, and AC7's ledger row is not actually being cross-checked. The
remaining criteria keep their evidence.
