# M26: The backend question has a measured answer before the design settles

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP4
- **Branch/PR:** `m26-mori-backend-assessment` · https://github.com/jmgirard/nestedtune/pull/27

## Goal

Before the August call, we know by measurement whether `mori` changes the
reproducibility and dispatch story this package's parallel path rests on.

## Scope

**In:** `mori` 0.2.2 (CRAN, "share R objects across processes on the same
machine via a shared memory name"), proposed for tune in tune#1188 with a
measured 18.9 GB → 4.23 GB peak-RSS drop on `fit_resamples()`. Read its source
and docs and record what it does and does not change about how an object
reaches a mirai daemon. Measure serial/parallel identity and per-fold wire cost
through a standalone probe. Map the findings onto the seed contract (D-011),
the backend choice (D-018), and M23's measured payload numbers. Record the
same-machine boundary. Commit a synthesis note; draft the maintainer-facing
material.

**Out:** Adopting `mori` — any `DESCRIPTION` change is its own dependency gate
and D-entry (tracking-rules), so it becomes a ROADMAP candidate here. Changing
`R/parallel.R`'s dispatch path → deferred until adoption is decided.
Benchmarking mirai against `future` or other schedulers → the multi-level
parallelism question, which stays for the call. Anything about the outer loop's
shape → M27.

## Acceptance criteria

- [ ] AC1: A committed synthesis note at
      `cairn/references/mori-backend-assessment.md`, authored from
      `templates/synthesis-note.md`, records what `mori` does and does not
      change about how an R object reaches a mirai daemon, pinned to `mori`
      0.2.2 and `mirai` 2.7.2, carrying a Provenance block and its `INDEX.md`
      bullet, with every claim about this repo's own state dated
      `— observed YYYY-MM-DD`.
- [ ] AC2: A standalone probe under `benchmarks/` — reimplementing the
      fold-dispatch shape rather than editing `R/` — sends one nested design's
      folds to a mirai pool both through `mori` and through the existing
      by-value path, at ≥ 2 worker counts under a pinned RNG kind, and the note
      records whether the two runs are `identical()` to serial. The finding
      counts whichever way it comes out, including `mori` touching no RNG
      surface at all; the note states which of the probe's shape differs from
      `dispatch_folds()` (`R/parallel.R:190`).
- [ ] AC3: The note states, for each of D-011's two-kind-pinned-seeds contract,
      D-018's backend choice, and M23's measured per-fold wire cost
      (25,714,635 B → 5,783,645 B on a 5-fold 5,000×21 fixture), whether `mori`
      leaves the premise untouched or would change it, each pinned to the
      D-entry or `file:line` it rests on.
- [ ] AC4: The note records `mori`'s same-machine boundary and names its
      consequence for the ROADMAP candidate row on probing remote mirai daemon
      pools, and for the `mirai::everywhere()` preload row that answers the same
      question a third way.
- [ ] AC5: An unposted draft for the maintainer exists under `benchmarks/`,
      marking each claim as measured here or inferred.
- [ ] AC6: The `verify` slot of `cairn/PROFILE.md` is clean.

## Coverage

- AC1 → T1, T5
- AC2 → T2, T3
- AC3 → T4, T5
- AC4 → T1, T4
- AC5 → T6
- AC6 → T7

## Tasks

- [x] T1: Install `mori` 0.2.2; read its source, docs, and tune#1188; record the
      transfer mechanism and whether it has any RNG surface at all.
- [x] T2: Write `benchmarks/probe-mori-dispatch.R` — a standalone fold-dispatch
      replica sending one design's folds by value and via `mori`, at ≥ 2 worker
      counts, RNG kind pinned as `set_fold_seed()` does (`R/nested-tune-grid.R:620`).
- [x] T3: Run the probe; record identity results and wire bytes, counting copies
      by `grepRaw()` as M23 did rather than inferring them from a total.
- [x] T4: Map findings onto D-011, D-018, M23's numbers, and the two adjacent
      candidate rows; state the same-machine consequence.
- [x] T5: Author the synthesis note from `templates/synthesis-note.md`; add its
      `INDEX.md` bullet.
- [x] T6: Draft the maintainer-facing note under `benchmarks/`, unposted.
- [x] T7: Run the profile's `verify` slot; add a ROADMAP candidate row for
      adopting `mori` if the findings warrant one.

## Work log

- 2026-07-31: created by /milestone-plan.
- 2026-07-31: criteria audit ([O], fresh context) returned two findings here — AC2's "mori-carrying daemon pool" was satisfiable by a pool that never sent an object through mori, and its only reachable evidence conflicted with the Scope Out ban on editing `R/parallel.R`; AC5 was existence-only with nothing constraining per-claim marking. AC2 went to the gate, AC5 was fixed to M27 AC5's wording.
- 2026-07-31: plan gate chose a standalone probe replica over patching `R/parallel.R` on the branch and reverting, because the milestone stays research-only and a half-reverted runtime edit is the worse failure; falsified by the replica and `dispatch_folds()` being shown to differ in a way that changes the identity result.
- 2026-07-31: T1 — mori 0.2.2 is 5 R functions, each a bare `.Call()` into 2,245 lines of C (`share`/`map_shared`/`is_shared`/`shared_name`/`prune_shared`); transport is POSIX shared memory behind ALTREP, and an ALTREP serialization hook makes a shared object travel as its ~30-byte region name. No RNG surface: `unif_rand|norm_rand|GetRNGstate|PutRNGstate|R_unif|rand|srand|random` match nothing in `src/*.c` or `src/*.h`, and no R-level function is stochastic.
- 2026-07-31: T1 — `share()` succeeded in-process on every object this package dispatches, `identical()` holding each time, contrary to the doc's "environments, closures, language objects returned unchanged": data.frame 24,259 B -> 308 B, rsplit 25,879 -> 272, inner rset 77,932 -> 547, whole design 311,556 -> 744, workflow 1,532 -> 255 (serialized lengths, 500x6 fixture, v=3/v=3). Cross-process fidelity is unproven by this and is what T2/T3 must settle.
- 2026-07-31: T2 — `benchmarks/probe-mori-dispatch.R` runs three arms over one design/workflow/grid/seed: the package's own `dispatch_folds()` serial branch, its parallel branch, and a mori replica. Only the third is hand-rolled; all three return `nested_fold_fit()` records, so `identical()` compares like with like. Engine is ranger, never lm, per M02's vacuity trap. Three stated differences from `dispatch_folds()`: no leaning (the point — mori needs none), no pre-flight/cancellation guard, no `record_dispatch()` seam.
- 2026-07-31: T3 — identity holds: mori-dispatched fold records are `identical()` to the serial reference at 2 and 3 workers, as is the real by-value path. Wire cost per fold, data-bearing terms only, M23's 5000x21 v=5/v=3 fixture: fat 3,427,624 B / 4 copies, lean 65,744 + 840,540 = 906,284 B / 1 copy, mori 67,253 B / 0 copies — mori is 13.5x leaner than M23's lean path and puts no copy of the data on the wire at all. Figures exclude the workflow/grid/metrics/worker closure, which ride in `.args` identically on all three routes and cancel; that exclusion is why these do not sum to M23's committed 5,783,645 B.
- 2026-07-31: T3 — the mori route is NOT byte-reproducible (3,525 vs 3,529 across runs): a shared object serializes as its region name and the name encodes the creating process. The copy count is exact on every route, which is why it carries the claim. Recorded in the probe rather than left for a reader to trip over.
- 2026-07-31: T3 — a daemon needs NO mori preload, against the natural assumption: R records the owning package on an ALTREP class and loads that namespace itself on deserialize, verified by execution (a daemon with mori merely installed reported `is_shared()` TRUE, the host's own region name, and a correct column sum). The probe's `everywhere(loadNamespace('mori'))` was therefore removed as dead weight implying a false requirement; identity still held at both worker counts without it. What a daemon does need is mori INSTALLED, the same requirement class `check_daemons_can_load()` (`R/parallel.R:543`) already handles for nestedtune.
- 2026-07-31: T4 — D-011 untouched: seeds are drawn host-side (`R/nested-tune-grid.R:318`) and travel as integers, `set_fold_seed()` runs worker-side, and mori has no RNG surface to perturb either through. D-018 untouched, and for a reason worth stating: mori is not a scheduler and not an alternative to mirai but an object-transport mechanism composing with it, so it does NOT bear on the mirai-vs-future question — that stays open.
- 2026-07-31: T4 — M23's premise would change, but conditionally, not wholesale. mori takes the per-fold data cost to 0 copies without `lean_payload()`/`rehydrate_payload()`/`is_fold_payload()` (`R/parallel.R:118-179`, ~60 lines) at all. It cannot replace them, though: mori is same-machine, so a pool with remote daemons cannot map the host's region and the by-value lean path has to stay as the remote fallback. Adoption would make M23's machinery conditional, never obsolete — which is the reading a bare 13.5x would invite and the one to head off.
- 2026-07-31: T4 — the `mirai::everywhere()` preload candidate row is dominated on its own terms if mori is adopted: that shape buys one-copy-per-daemon with daemon state, cleanup and a stale-object hazard, where mori is one-copy-per-machine with no daemon state, automatic GC and lazy mapping, and its motivation (cutting per-fold `.args` transfer) is exactly what mori zeroes. The remote-daemon-pool row is the constraint above and gains a reason to stay open.
- 2026-07-31: T5 — `cairn/references/mori-backend-assessment.md` committed with its `INDEX.md` bullet; 9-row premise ledger (P1-P9) tagged Untouched/Changed/Conditional/Out of reach, plus a Disposition mapping every row and five dated open questions. `cairn_validate` clean, and the page does not join the staleness advisory: its Extraction status carries a `read directly` verification claim with a date.
- 2026-07-31: T4 — rsample#283 and M01 are untouched, contrary to the natural reading that shared memory answers the memory gap: `nested_cv()`'s cost is analysis frames materialized IN-PROCESS before any parallelism, where mori addresses transfer to daemons. Different axis, and the note says so explicitly. Unmeasured and flagged: `share()` writes the frame into a shared region, so the host transiently holds original plus shared copy; peak host memory under mori is not measured here, and tune#1188's 18.9 GB -> 4.23 GB is their whole-tree figure on `fit_resamples()`, not ours.
- 2026-07-31: T6 — `benchmarks/tune-1188-mori-findings.md` drafted and unposted, following through on the mori offer in `tune-969-reply-2.md`. Every claim marked [measured] or [inferred]; written without em dashes per the standing request (checked mechanically). It leads with the two caveats rather than the 13.5x, because the ratio alone invites the deletion reading P6 rules out.
- 2026-07-31: T7 — `devtools::test()` clean on the branch: FAIL 0 | WARN 0 | SKIP 0 | PASS 1615 (the `step_pca()` errors in the output are the deliberate failed-fold fixtures). No `R/` file was touched by this milestone, so the suite is the same one main carries; it is run as evidence that the branch changed nothing, not that anything new is covered.
- 2026-07-31: T7 — ROADMAP candidate row added for routing fold data through mori, carrying P6's remote fallback as a stated condition rather than an afterthought, and cross-referencing the `mirai::everywhere()` preload row it would supersede. Search-first sweep done at plan time; no existing row covers adoption.
- 2026-07-31: review opened draft PR #27; main had not moved, so no merge into the branch was needed. Review in progress: AC evidence gathered, three lenses and `devtools::check()` still running at this checkpoint.
- 2026-07-31: review RETURNED the milestone (return 1 of this milestone). AC2 unverified twice over (the note never states the probe's divergences from `dispatch_folds()`; no ambient RNG kind is pinned), AC3 unverified (figures attributed to M23's fixture come from v=5/inner_v=3, not M23's v=5/inner_v=5, and the published 4-copy count contradicts M23's test-locked 6), AC5 unverified (a claim tagged `[not measured]`, a third category AC5 does not permit). Gates themselves were clean: `check()` Status OK, `cairn_validate` exit 0, suite 1615 passing. Three lenses produced 25 deduplicated findings; 14 scored >=80 and are actioned, 11 logged below threshold.

## Decisions

## Review

**Reviewed 2026-07-31. Returned to `in-progress`: three acceptance criteria unverified.**
PR #27 (draft). Local `devtools::check()` **Status: OK** (0 errors, 0 warnings, 0 notes).
`devtools::document()` no diff. `cairn_validate` exit 0, all hard checks PASS, 18 pre-existing
staleness advisories (this page not among them). No NEWS entry owed: nothing user-visible shipped.

### Acceptance criteria

- **AC1 — verified.** Note at `cairn/references/mori-backend-assessment.md` with Provenance block,
  `INDEX.md` bullet (bullet form, `references index<->disk` PASS), 11 `— observed 2026-07-31` stamps.
- **AC2 — NOT verified, two independent shortfalls.** (i) The criterion requires *the note* to state
  how the probe's shape differs from `dispatch_folds()`; the three differences appear only in the probe
  header, and the note carries no such enumeration (grep). (ii) The criterion requires ">= 2 worker
  counts **under a pinned RNG kind**"; the probe never calls `RNGkind()` — `set.seed()` is bare at
  `:98`, `:229`, `:264`. The worker-side pin it cites is the package's own, inherited rather than
  asserted, so the requirement is met only vacuously.
- **AC3 — NOT verified.** The note addresses all three premises, but its supporting figures are
  attributed to "M23's own fixture" and are not from it: the probe builds v=5/inner_v=**3** under
  `set.seed(1)`, where M23's `fixture_design()` (`tests/testthat/test-parallel-payload.R:40`) is
  v=5/inner_v=**5** under `set.seed(2)`. Confirmed by closed form (`predicted_lean_bytes(5000,5,3)`
  = 64,000 against measured 65,744; inner_v=5 would be 96,000) and by rebuilding at M23's true fixture,
  which yields 6 copies / 5,141,166 B — matching M23's test-locked `expect_identical(..., 6L)` at
  `test-parallel-payload.R:145` and contradicting the published 4 copies / 3,427,624 B.
- **AC4 — verified.** P6 records the same-machine boundary; the Disposition names both the
  remote-daemon-pool row and the `mirai::everywhere()` preload row.
- **AC5 — NOT verified.** The draft exists and is marked unposted, but AC5 requires each claim marked
  measured-here *or* inferred, and one claim carries a third tag (`[not measured]`) the legend never
  declares; three further tags are wrong in the other direction (a structural argument tagged
  `[measured]`, a documentation-read tagged `[measured, then inferred]`, a verified negative search
  tagged `[inferred]`).
- **AC6 — verified.** `devtools::test()` FAIL 0 | WARN 0 | SKIP 0 | PASS 1615; full `check()` OK.

### Independent review — three fresh-context lenses, then a scorer

Diff-bug **[O]**, blame-history **[S]**, prior-review **[S]**; findings deduplicated to 25 and scored
by a fourth **[S]** agent that generated none of them. **14 scored >= 80 and are actioned; 11 scored
below threshold and are logged, not discarded.**

Actioned, descending: D1 (95) tune#1188 attributed to "the tune maintainer" when its author is
EmilHvitfeldt, and the draft addressed to topepo says "**Your** 18.9 GB to 4.23 GB figure",
misattributing a colleague's benchmark · D2 (92) fixture mislabelled as M23's throughout note, ROADMAP
row, work log and draft · D3 (91) published pre-M23 copy count of 4 contradicts M23's test-locked 6 ·
D5 (90) the claim that the worker closure "cancels" across routes is false — `worker`/`shared` enter
`.args` only inside `if (leaning)` (`R/parallel.R:250-256`), so it is a lean-route-only cost and the
M23 reconciliation is mis-explained · D7 (88) AC2's note requirement · D9 (87) `is_fold_payload()` is
the IP2/IP1 correctness gate (M23 F1, scored 93), not leanness machinery, yet note and draft count it
among the "~60 lines" mori removes · D4 (86) the "~30-byte region name" is off by an order of magnitude
(measured: 19-char name, 257 B shared object, ~165 B per extra reference) · D10 (86) no daemon-side
check that mori transport occurred, so an ALTREP fallback to by-value would leave all arms `identical()` ·
D8 (85) ambient RNG kind never pinned · D12 (85) note omits mori's Windows Win32 path and its
`R (>= 4.3)` floor against this package's `R (>= 4.1)` · D6 (84) the probe cannot run as committed —
`start_daemons()`/`without_pkgload_warning()` come from `helper-parallel.R`, never sourced, so the
note's "re-derivable by `Rscript ...`" claim is false · D16 (84) four inaccurate claim tags in the
draft · D11 (80) nothing asserts folds completed or that the identity booleans were TRUE · D14 (80)
the GP2 oracle pair share one mechanism; M23's certified closed form is never evaluated.

Logged below threshold: D18 (78) unbounded `mapped[]` collect · D19 (78) draft cites an untracked file ·
D17 (76) daemon pool and shared regions leak on the error path · D15 (75) 67,253 B stated flatly
outside P9 · D21 (74) `wire_report()` payloads unvalidated · D20 (72) may measure an installed package ·
D13 (68) omits #1188's host-side `mem_alloc` datum · D22 (64) mostly mitigated, the by-value arm is the
real dispatcher · D24 (62) P7's reading is defensible — `daemon_symbol_manifest()` and
`daemon_probe_expr()` are parameterized by `package` · D25 (45) wrapped Extraction status, validation
passes · D23 (25) refuted: `R/nested-tune-grid.R:318` is exactly the `sample.int()` draw, so the note's
P1 citation is correct.

Verified clean: no `R/` file touched; `mori_task` is a faithful replica of `fold_task`; identity
reproduces at 2 and 3 workers; the `.args`-per-task accounting matches M23's convention; oracles reused
from the helper rather than re-implemented; draft contains zero em dashes; D-011/IP2 and D-018 analysis
sound; P8's rsample#283 distinction correct.
