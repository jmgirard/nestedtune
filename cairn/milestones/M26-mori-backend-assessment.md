# M26: The wire figure survives re-derivation

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP2, GP4
- **Branch/PR:** `m26-mori-backend-assessment` · https://github.com/jmgirard/nestedtune/pull/27

## Goal

The per-fold wire comparison between the current dispatch and a mori-shaped one
is measured as mirai actually serializes it, in the state a user actually runs,
and the probe asserts its own headline rather than printing it.

## Scope

**In:** Re-cut after three returns; both thrash triggers fired and this is the
measurement half of the split. The apparatus stays — the probe captures what
`dispatch_folds()` hands `mirai_map()` by interception — and what changes is
what is measured and what is asserted. Four failures of one shape (a published
figure or its explanation not surviving re-derivation) are answered by pinning
identities a script checks: the single-stream serialization mirai really
performs, the installed-package state, a gap identity that closes to the byte,
two oracles per figure, and a machine-readable manifest so no document
transcribes a number by hand.

**Out:** The note, the maintainer draft, the lessons harvest, the handoff and
the M23 candidate row → M29, which consumes this milestone's manifest. Adopting
`mori` — a dependency gate and D-entry of its own. Changing `R/`. The
mirai-vs-`future` question.

## Acceptance criteria

- [x] AC1: The probe publishes per-fold wire cost as **one** serialization of
      the object mirai hands `request()`, captured from the intercepted call
      rather than assembled from a named shape (mirai wraps `.f`/`.x`/`.args`
      with `._expr_.`, `._globals_.` and more, so a hardcoded member list goes
      stale). It computes the sum of separately-serialized parts as well and
      asserts the two differ, so publishing the sum fails rather than passes.
- [x] AC2: Figures are measured against the package **installed to a temporary
      library**, not modelled from captured closures: the probe builds and
      installs, loads from there, and captures. It asserts source references are
      absent from the captured closures, so a run that silently measured the
      development state fails. A `pkgload::load_all()` figure may be shown
      beside it, labelled development-only.
- [x] AC3: The probe asserts a closing identity for its own headline — the
      difference between the two routes' published totals equals the sum of the
      terms named as explaining it, **to the byte**, with the assertion naming
      each term. A single-stream measurement has no rounding, so the tolerance
      is zero.
- [x] AC4: Every published figure records in the manifest the independent
      oracles asserted for it, and the probe asserts that every figure not
      marked `derived` carries at least two that share no arithmetic. The
      closed-form lean-payload prediction is asserted against M23's own 5% band
      (`tests/testthat/test-parallel-payload.R:67`) and copy counts come from
      `count_data_copies()`; where neither mechanism reaches a figure a third is
      used and named. A `derived` figure is one computed wholly from other
      published figures, which inherit the oracles; the manifest marks which,
      and a document may not rest a claim on a `derived` figure alone.
- [x] AC5: The probe writes every figure it publishes to a committed
      machine-readable manifest, so a document can cite a measured value rather
      than transcribe one. Development-state figures are marked in the manifest
      as install-dependent and excluded from any later drift check.
- [x] AC6: Each published measurement names the fixture it was taken on, and the
      probe emits that attribution into the manifest beside the figure.
- [x] AC7: The `verify` slot of `cairn/PROFILE.md` is clean and
      `devtools::check()` passes.

## Coverage

- AC1 → T2, T3
- AC2 → T1, T3
- AC3 → T4
- AC4 → T5
- AC5 → T6
- AC6 → T6
- AC7 → T7

## Tasks

- [x] T1: Add a temp-library install step to the probe (`R CMD INSTALL` to a
      throwaway lib, load from there), and assert source references are absent
      from the captured closures.
- [x] T2: Change the capture to record the object mirai hands `request()`,
      rather than reassembling `.f`/`.x`/`.args`; read mirai 2.7.2's
      `do_mirai()` to find the interception point that yields it.
- [x] T3: Publish the single-stream total; compute the sum-of-parts too and
      assert they differ.
- [x] T4: Derive the gap identity and assert it closes to the byte, naming each
      term in the assertion.
- [x] T5: Wire both oracles to every published figure; assert the closed form
      against M23's 5% band.
- [x] T6: Emit the manifest — every figure, its fixture, and an
      install-dependent flag.
- [x] T7: Run the profile's `verify` slot and `devtools::check()`.

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
- 2026-07-31: rework — probe rebuilt at M23's ACTUAL fixture (`fixture_design()`, v=5, inner_v=5, `set.seed(2)`), which is what D2/D3 were about. Corrected figures per fold: fat 5,141,166 B / 6 copies (matching M23's test-locked `6L`), lean 98,346 + 1,132,051 = 1,230,397 B / 1 copy, mori ~100,589 B / 0 copies, a 12.2x improvement on lean rather than the 13.5x the wrong fixture gave.
- 2026-07-31: rework — the fat route now reconciles to M23's committed total: 25,714,635 / 5 = 5,142,927 B/fold against 5,141,166 measured, a 1,761 B difference that is exactly the workflow term this count excludes. The lean route deliberately does NOT reconcile to the byte and the note says why: its `.args` carries the worker closure, whose size is srcref- and therefore install-dependent (291,491 B under `load_all()` here against M23's recorded 202,363 B).
- 2026-07-31: rework — D5 fixed: the claim that the worker closure cancels across routes was false (`R/parallel.R:250-256` adds `worker`/`shared` only on the leaning branch), so it is now counted as a lean-route cost in both probe and note, which is why the lean total rose from the earlier understated figure.
- 2026-07-31: rework — D4 fixed by measurement rather than assertion: the '~30-byte region name' was the name's own length, not the wire cost. Measured 19-character name, 267 B for one shared object, ~175 B per additional reference; the probe now reports this and the note states it.
- 2026-07-31: rework — D9/P6 fixed: `is_fold_payload()` is reclassified from leanness machinery to the one-frame-per-fold invariant gate (M23 review F1, scored 93), in note, ROADMAP row, draft and probe header. `morify_payload()` now asserts the invariant instead of assuming it. The draft flags this as the caveat it would 'flag hardest', since a 12x number invites deleting the whole block.
- 2026-07-31: rework — D1 fixed, the worst of the set: tune#1188 was filed by EmilHvitfeldt, not the tune maintainer, and the draft addressed to topepo credited Emil's benchmark to Max. The note names the author correctly and the draft carries an explicit audience note.
- 2026-07-31: rework — vacuity gaps closed (D10, D11): the probe asserts per run that the daemon reports `is_shared()` TRUE and the host's own region name, so an ALTREP fallback to by-value can no longer pass as success; and it asserts every fold completed and `stopifnot()`s the identity booleans, so a run in which all arms failed identically, or diverged, aborts rather than printing and exiting 0.
- 2026-07-31: rework — D6/D8/D14/D20 fixed: `helper-parallel.R` is now sourced (the script previously ran only as a side effect of `load_all()` sourcing every helper); the ambient RNG triple is pinned and restored; the closed-form oracle is evaluated (96,000 predicted against 98,346 measured) restoring GP2's independent pair; and `load_all()` is now unconditional rather than preferring an installed copy.
- 2026-07-31: rework — D7 fixed: the note now carries its own 'How the probe differs from `dispatch_folds()`' section, which is what AC2 asked for and the script header alone did not satisfy. D12 fixed: mori's Windows Win32 path and its `R (>= 4.3)` floor against this package's `R (>= 4.1)` are recorded as P9. D13 fixed: #1188's host-side `mem_alloc` 6.22 MB -> 16.5 GB datum now appears in the open question it bears on. D16 fixed: the draft's tags are now only `[measured]`/`[inferred]`, 8 and 3.
- 2026-07-31: rework — below-threshold findings taken anyway where cheap: D17 (`on.exit` daemon and RNG restoration, plus `prune_shared()`), D18 (`collect_mirai()` matching the real dispatcher rather than `map[]`), D21 (`wire_report()` now asserts the mori payload resolves to the same rows before believing its bytes), D15 (`~` marks on the non-reproducible mori figures in note and draft). D19 left: the draft cites the two uncommitted reply drafts and now says so inline. D23 refuted at review and correctly left alone.
- 2026-07-31: rework verified — probe reruns clean and asserts its own findings (exit 0); `devtools::test()` FAIL 0 | WARN 0 | SKIP 0 | PASS 1615. Status back to review.
- 2026-07-31: review RETURNED the milestone a second time (return 2 of this milestone). AC3 unverified: the fat route now reconciles exactly to M23's committed total, but the lean row is inflated ~291,000 B because `mirai_map()` charges `.f` per task exactly as `.args` and the non-leaning branch sends `fold_task` as `.f`, so the published 12.2x is an accounting artifact. Gates were clean throughout. 26 deduplicated findings, 9 scored >=80. Thrash trigger (b) fires: AC3 has failed twice by two mechanisms of one shape, and the plan gate's recorded alternative (measure the real path rather than a replica) is what the rule asks be reconsidered.
- 2026-07-31: rework 2, APPROACH CHANGE per thrash trigger (b). The wire section no longer reconstructs the payload and `.args` by hand; it runs the package's own `dispatch_folds()` and intercepts `mirai::mirai_map()` to record exactly what it was handed (`.f`, one `.x` element, `.args`). Both prior AC3 failures were failures of the reconstruction, not of the measurement, so the reconstruction is gone. This needed no `R/` edit — the interception is `assignInNamespace()` in the probe, restored on exit.
- 2026-07-31: rework 2 — E1 fixed, and the captured numbers differ from every hand-built figure so far. Real per-fold: `.f` 291,418 + `.x` 98,346 + `.args` 1,133,735 = 1,523,499 B / 1 copy. The replica had never counted `.f` at all, understating the real lean cost by ~291 kB. Modelled mori bundle carrying the SAME closure: 291,491 + 100,589 + 1,761 = 393,841 B / 0 copies. Ratio **3.87x**, not 12.2x. Two terms explain all of it: the closure (291,491 B) is common and cancels; the data (840,540 B) is what lean carries and mori does not.
- 2026-07-31: rework 2 — E3 fixed: P10's non-reproducibility claim was false. The region name is fixed-width 19 characters and the modelled mori bundle measured 100,589 B in three separate processes with three distinct names. P10 is retagged `Untouched` and the `~` marks are gone; what does move between environments is the srcref-laden closure, which both routes carry equally.
- 2026-07-31: rework 2 — E4 fixed and verified: a top-level `on.exit()` in an `Rscript` registers against a frame that never returns, so it silently never fires. Replaced with `reg.finalizer(environment(), ..., onexit = TRUE)`, which does run at session exit — confirmed by execution to fire after a `stopifnot()` abort. The RNG triple, the daemon pool and `prune_shared()` are all in that handler now.
- 2026-07-31: rework 2 — E2 fixed (the note's self-contradiction removed with the paragraph that caused it), E7 fixed (only `daemon_symbol_manifest()` takes `package`; `daemon_probe_expr()` has no formals and `check_daemons_can_load()` no `package` parameter, so probing a second package is new machinery — P7 and the ROADMAP row now say so, and M24 F6's host-side constraint is recorded), E8 fixed (INDEX now reads 10-row P1-P10), E11 fixed (draft tags now 6 `[measured]` / 6 `[inferred]`, with the same-machine caveat and the R-floor read correctly marked inferred), E12 fixed (40 lines, `R/parallel.R:140-179`, not ~60 which reached into the predicate the same paragraph says must stay), E14 fixed (ROADMAP now pins `is_fold_payload()` to `:118-138`).
- 2026-07-31: rework 2 — below-threshold taken: E9 (the closed form is now ASSERTED against M23's own 5% band, 96,000 predicted vs 98,346 measured, and both copy counts are asserted rather than printed), E13 (P6 now records that the predicate's fat-path fallback has no mori analogue and adoption must say what replaces it), E19 (`share()` idempotence comment corrected — it is idempotent on an already-shared object, not on the original).
- 2026-07-31: rework 2 — E5/E6 surfaced a finding about M23's own record rather than this milestone's: M23's committed 5,783,645 B never counted `.f`, and the closure grew from the 202,363 B at `R/parallel.R:246` to 291,491 B measured now, `R/parallel.R` having gone from 26,759 B at M23 to 39,066 B at M24. The note states both rather than smoothing the non-reconciliation, and the stale figure is left for its own candidate row rather than corrected here.
- 2026-07-31: rework 2 verified — probe exit 0 with all assertions passing including the two new ones; `devtools::test()` FAIL 0 | WARN 0 | SKIP 0 | PASS 1615; `cairn_validate` exit 0. Status back to review.
- 2026-07-31: review RETURNED the milestone a third time. AC3 fails again: the note's gap explanation accounts for 840,540 B of an actual 1,129,658 B gap because the lean route carries the worker closure twice (`.f` wrapper plus `.args$worker`) where the modelled mori row carries it once. Third appearance of the D5/E1 defect, each time fixed in the table and left in the prose. The note also claims a ROADMAP filing that does not exist. Thrash triggers (a) third return and (b) same criterion by a new mechanism of one shape BOTH fire; routing to `/milestone-plan` per (a), carrying (b)'s diagnosis.
- 2026-08-01: RE-CUT by /milestone-plan after three returns; both thrash triggers had fired. Tasks and criteria are superseded wholesale and every criterion is unticked. The apparatus survives — capture what `dispatch_folds()` really hands `mirai_map()` — and what changes is what is measured and asserted.
- 2026-08-01: the re-cut's cause, found by the pass-3 diff lens and verified by execution: summing separately-serialized `.f`/`.x`/`.args` double-counts 290,626 B of shared srcfile structure. Sum 1,523,499 against one serialization 1,232,873. mirai performs ONE serialization per task, so every figure published across three passes measured an object mirai never sends.
- 2026-08-01: second cause, also verified: with source references stripped (the installed state `install.packages()` produces by default), the lean route is 941,437 B. Every ratio published so far was a `pkgload::load_all()` development artifact presented as the adoption case.
- 2026-08-01: criteria audit ([O], fresh context) over the combined 11-criterion draft returned eleven findings. Taken directly: AC1's bundle shape was hardcoded and wrong — mirai wraps `.f`/`.x`/`.args` inside `list(._expr_., ._globals_., ...)` before `request()`, so the criterion now pins the identity rather than the members; AC1's assertion was a tautology, replaced with sum-vs-single-stream inequality; AC2's "assert the totals differ" was satisfiable only by an empirical outcome that depends on session `keep.source`, replaced with asserting srcref STATE; AC3's tolerance had no stater, now zero to the byte since a single-stream measurement does not round. Split and install-mechanism and oracle questions went to the gate.
- 2026-08-01: plan gate chose measuring an actual temp-library install over `removeSource()` on captured closures, because a post-hoc model of the installed state is the reconstruct-then-publish shape that failed on passes 1 and 2; falsified by the install step proving unreproducible across platforms while the stripped model agrees with it.
- 2026-08-01: plan gate chose restoring a second oracle over recording its omission as a GP2 trade, because four passes have now shown single-mechanism wire figures failing; falsified by the two oracles agreeing trivially because one is derived from the other.
- 2026-08-01: plan gate chose splitting the write-up into M29 over one milestone, because both sizing tripwires fired; falsified by M29 proving unable to write anything without re-opening the measurement.
- 2026-08-01: T1 — the probe now installs the working tree to a throwaway library (`R CMD INSTALL --with-keep.source=no`, `R_KEEP_PKG_SOURCE=no` set explicitly so a developer's `~/.Renviron` cannot reintroduce srcrefs) and measures that copy; `R_LIBS` is prepended so daemons find it, since `prime_daemons()` deliberately no-ops off a dev package (`helper-parallel.R:52`). srcref state is asserted on both captured closures rather than inferred from a size comparison, which would pass or fail on session `keep.source`.
- 2026-08-01: T1 — the installed state changes the headline, confirming the re-cut's second stated cause. The worker closure is 524 B installed against 291,491 B under `load_all()`, and the `.f` wrapper 451 B against 291,418 B; the lean bundle is 941,687 B and the ratio 9.13x, where three passes published 3.87x. Every earlier figure was a development artifact presented as the adoption case.
- 2026-08-01: T2 — read mirai 2.7.2: `mirai_map()` calls `do_mirai()` per element, which builds `data <- c(list(.f=, .x=elem, .args=, .mirai_within_map=TRUE), list(._expr_.=, ._globals_.=))` and hands that ONE list to `request(..., send_mode = 1L)`. Intercepted by rebinding `do_mirai` to an environment adding only a capturing `request`, mirai's own body asserted `identical()` — so the bundle is assembled by mirai, not reconstructed here. `request` itself cannot be replaced: it is imported from nanonext and has no binding in mirai's namespace.
- 2026-08-01: T2 — the interception found a defect the old `mirai_map()` seam could not see: `dispatch_folds()` reaches `request()` BEFORE any fold does, because its pre-flight probe uses `mirai::everywhere()`, which routes through `do_mirai()` too. Capturing the first call published the pre-flight bundle as a fold's wire cost. The shim now discriminates on `.mirai_within_map`, the member `mirai_map()` alone sets, and passes everything else through to the real `request`.
- 2026-08-01: T3 — single stream 941,687 B lean / 103,119 B mori; sum-of-parts 941,837 / 103,139, asserted to differ so publishing the sum fails. Honest qualification the note must carry: the sum-vs-single-stream error is 150 B (0.0%) in the installed state, not the 290,626 B the re-cut recorded — that figure was shared srcfile structure between two srcref-laden closures, so cause 1 is subsumed by cause 2 and is not independently material once installed.
- 2026-08-01: T4 — the gap explanation is now a ladder the script walks, one substitution per rung, rather than a sentence: `.f` wrapper to worker +11 B, `.x` blanked payload to shared-region payload +2,249 B, `.args` dropping `shared` and `worker` -840,828 B, telescoping to -838,568 B exactly (`identical()`, tolerance zero). The ladder is asserted to land on the modelled mori bundle, and the dominant rung is cross-checked against the frame serialized alone (840,828 vs 840,540 B, 0.0%).
- 2026-08-01: `devtools::test()` FAIL 0 | WARN 0 | SKIP 0 | PASS 1615 on a quiet machine. An earlier run scored FAIL 1 at `test-parallel-interrupt.R:82` (`interrupted` FALSE) while the probe was running concurrently — that test kills its own process with SIGINT and its comments warn it races the pre-flight on a loaded machine, so the concurrent `R CMD INSTALL` plus two daemon pools is the likely cause. No `R/` or test file was touched by this milestone.
- 2026-08-01: T5 — the criterion's named pair does not reach every figure, so two further oracles were built rather than the gap papered over: frame-size INVARIANCE for the shared-reference costs (a 4x frame shares for 268 B against 268 B, 0.0%, while by value it is 640,187 B), and `removeSource()` STRIP-INVARIANCE for the worker closure (byte count `identical()` after stripping, so the srcref-state walk cannot have missed srcrefs in a corner of the language tree). Both share no arithmetic with the copy count.
- 2026-08-01: AMENDMENT (substantive, gated) — AC4 replaced. As planned it required the closed form and the copy count behind every published figure; two of nine figures are computed wholly from other published figures (`ratio_lean_over_mori` = lean/mori, `sum_of_parts_overstatement_bytes` = two measurements of one bundle subtracted) and any second mechanism for them reads the arithmetic that produced them. The replacement marks those `derived`, has them inherit their sources' oracles, and makes the bar script-checked: every non-derived figure asserts >= 2 independent oracles, and a derived figure must name published non-derived sources, so derivation cannot chain. User chose the amendment over dropping the two figures, the ratio being the headline a reader wants.
- 2026-08-01: T6 — `benchmarks/mori-wire-manifest.json` emitted and committed: 9 figures (7 measured, 2 derived), each with its value, its fixture, its asserted oracles, an `install_dependent` flag and its derivation. Hand-written JSON rather than a jsonlite dependency; validated as parseable. Published: lean 941,687 B, mori 103,119 B, gap 838,568 B, ratio 9.13x, lean payload 98,346 B, shared reference 268 B, marginal 176 B, worker closure 524 B, sum-of-parts overstatement 150 B.
- 2026-08-01: review RETURNED the milestone a fourth time. AC1 unverified (its assertion is a type tautology, `identical()` on an integer against a double, so it cannot fail); AC4 unverified (three manifest oracle strings name assertions that do not exist); AC5 unverified (the four headline figures embed the worker closure and are marked not install-dependent). Gates clean throughout and the manifest regenerated with a zero diff. Trigger (a) holds at return 4 with a re-cut already spent; trigger (b) fires a third time with a changed diagnosis — the measurement is sound and what now fails is claims that do not correspond to what was checked.
- 2026-08-01: review fixed F15/P1 (80) in place: `fixture_design()` moved from `test-parallel-payload.R` to `helper-payload-size.R` so the probe can source it instead of re-typing the design, and the renumbered budgeted wait was corrected in `helper-time-budget.R`. Suite green, 1615 passing. Also added `mori_bundle_independent`, a member-by-member construction that gives AC3's identity a half that can actually fail.
- 2026-08-01: PARKED as `blocked` at the user's decision after return 4. Blocker: not an external dependency but a standing maintainer judgment — four passes have each fixed the previous layer and introduced the next at one remove from the numbers, and re-planning was already spent at the re-cut, so the remedy is a view on that pattern rather than another pass at the seven open findings. Unblocks when the maintainer decides how the claims around a measurement are to be kept true, or elects to escalate the question. The measurement, the manifest and the seven findings are committed on the branch; PR #27 stays draft.
- 2026-08-01: T7 — `devtools::document()` no diff; `devtools::test()` FAIL 0 | WARN 0 | SKIP 0 | PASS 1615; `devtools::check()` **Status: OK**, 0 errors / 0 warnings / 0 notes in 4m 0.6s; `cairn_validate` exit 0, all hard checks PASS. Probe exits 0 with every assertion passing. Status to review. Advisory not owned by this milestone: `sizing (split tripwires)` flags M29 at 8 acceptance criteria against the 7 tripwire, inherited from the re-cut plan and amendable only through M29's own plan gate.
- 2026-08-01: /milestone-implement resumed the existing branch after the re-cut. `origin/main` had moved (`3acd9e6`, a candidate row closed) and was merged in; the merge guard first refused `git merge main` reading the direction backwards, and the user approved retrying against the remote ref. The two tune#969 reply drafts were committed at the same gate — `benchmarks/tune-1188-mori-findings.md:7` cites both by path and neither was tracked (D19/78 pass 1, E18/55 pass 2, unfixed through three passes). PR #27 is reused rather than reopened, retitled at review.
- 2026-08-01: UNBLOCKED at the maintainer's decision (gate this session): finish mechanically rather than drop or escalate. The recorded view on keeping claims true: the manifest is the only citable record, every manifest claim string must be backed by an assertion the probe itself runs, and all remaining prose leaves M26 — M29 was downscoped at the same gate to correcting the internal note only (external draft dropped), to be applied through M29's own plan gate. Context: the package is being ported (M28), so production-preparedness prose has lost its audience.
- 2026-08-01: rework 3 — F1/AC1 fixed: the sum-vs-single-stream assertion was a type tautology (`!identical()` on integer vs double); now a strict value inequality (`sum_of_parts > single stream`) on both rows, which fails when they agree. F4 fixed: the `identical(body(patched), body(orig))` "staleness guard" that `environment<-` makes unfalsifiable is removed; the comment now points at the bundle-shape assertion as the real guard. F8/AC4 fixed: the three manifest oracle strings with no assertion behind them now have them — the payload counted alone (0 copies, plus 1 in `.args$shared`), the shared object's stream (0 copies), and the four-reference list (0 copies).
- 2026-08-01: rework 3 — F6/AC5 fixed: `lean_bundle_bytes`, `mori_bundle_bytes`, `gap_bytes` and `ratio_lean_over_mori` are now marked `install_dependent: true` — they embed the worker closure this milestone measured at 524 B installed against 291,491 B in dev, so their values follow the build state; the manifest's `package_state` names which state they were taken in.
- 2026-08-01: rework 3 — F24/F25/F26 document corrections, current knowledge in place and marked: the ROADMAP mori row now carries the manifest's installed-state figures (941,687 / 103,119 / 9.13x) and the data-dominated gap explanation, replacing the refuted dev-state 3.87x and the disproved "closure cancels" sentence; the note's measurement section carries a superseded-figures correction banner pointing at the manifest, P10's fixed-width region-name claim is corrected to pid-dependent (19 and 20 chars measured), and the false "filed as a ROADMAP candidate" sentence is corrected (no row was filed; none is owed — the under-report dissolves in the installed state). The unposted draft gets a do-not-post banner; its fate is M29's.
- 2026-08-01: rework 3 verified — probe exit 0 with every figure re-derived byte-identically (the manifest diff is exactly the four flag flips and one reworded oracle string); `devtools::test()` FAIL 0 | WARN 0 | SKIP 0 | PASS 1615; `devtools::check()` **Status: OK**, 0 errors / 0 warnings / 0 notes; `cairn_validate` exit 0, all hard checks PASS (the 18 references-staleness advisories are shelf-wide and pre-existing). Status back to review.

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

### Second pass, 2026-07-31 — returned again (return 2)

Gates all clean: `devtools::check()` **Status: OK**; `devtools::test()` 1615 pass;
`cairn_validate` exit 0; `document()` no diff; probe exit 0 with its own assertions passing.

**AC1 verified** — note present with Provenance, 12 dated observations, `INDEX.md` bullet
(`references index<->disk` PASS). The bullet's *content* is wrong (E8) but it exists.
**AC2 verified** — probe standalone, 0 files changed under `R/`, both routes at 2 and 3
workers, ambient RNG triple pinned at `probe:119` before fixture construction, and the note
now carries its own "How the probe differs from `dispatch_folds()`" section (`:68`), which is
what failed last pass.
**AC3 NOT verified** — the note states the premise for each of D-011, D-018 and M23's wire
cost, and the fat route now reconciles exactly (25,714,635/5 = 5,142,927 against 5,141,166
measured; the 1,761 B difference is M23's own per-fold `.args`, measured at 1,761 B). But the
lean row is inflated by ~291,000 B: `mirai_map()` charges `.f` per task exactly as `.args`
(`R/parallel.R:243` says so), and the non-leaning branch sets `.f = fold_task` (`:259`), so the
fat route pays the closure too. The published 12.2x is an accounting artifact; a uniform
convention gives 9.3x (excluded both sides) or 3.1x (included both sides).
**AC4 verified** — P6 records the same-machine boundary; Disposition names both rows.
**AC5 verified on its letter** — every claim carries one of the two permitted tags (8
`[measured]`, 3 `[inferred]`), unlike last pass's third category. Four tags are misapplied
(E11), actioned as a defect rather than a criterion failure.
**AC6 verified** — check OK, suite 1615, document no diff.

Three lenses again, deduplicated to 26 findings, scored by a fourth agent that generated none.
**9 scored >= 80 and are actioned; 17 logged below threshold.**

Actioned: E1 (93) the worker closure is charged to lean only though every route pays it via
`.f`, inflating the lean row and the 12.2x headline in note, ROADMAP row, work log and the
external draft · E3 (90) P10's "moves a few bytes per run" is false at the published fixture —
100,589 B in three processes with three distinct region names, the name being fixed-width 19
characters; the earlier variance came from the pre-rework fixture and was carried forward
unchecked · E12 (87) the draft's "about 60 lines" is `118-179`, which includes the very
predicate the same paragraph says must be kept; `lean_payload()` + `rehydrate_payload()` is 40
lines · E8 (85) `INDEX.md` says "9-row premise ledger (P1-P9)" against P1-P10 · E2 (84) the
note contradicts itself, `:123` "neither the fat nor the mori route pays" against `:144-145`
"route-independent in kind" · E7 (84) `daemon_probe_expr <- function()` has no formals, so
P7's "parameterized by `package`" is half false — this was D24 (62) last pass, cleared on a
premise that is wrong · E11 (82) four draft tags misapplied, including a documentation read
tagged `[measured]` · E14 (82) the ROADMAP row pins `is_fold_payload()` to `R/parallel.R:118-179`
in the sentence arguing it is not one of the three functions that range covers · E4 (80) the
probe's top-level `on.exit()` never fires in `Rscript`, so the RNG restore and daemon cleanup
the D8/D17 rework claims are dead code.

Logged below threshold: E13 (76) the "not leanness machinery at all" reclassification overshoots
M23's record · E17 (76) no HANDOFF block, against M13's precedent · E10 (72) unbounded
`collect_mirai()` · E19 (72) `share()` is not idempotent on the original, so regions accumulate ·
E5 (70) the lean reconciliation cites 202,363 B where 216,119 B closes the arithmetic · E6 (70)
M24 raised the closure cost to 291,491 B and the stale 202,363/203,790 records were left standing ·
E9 (70) wire findings printed not asserted, and a 960-vs-2,704 oracle disagreement passes silently ·
E16 (68) nothing harvested to LESSONS despite 34/50 lines used · E22 (66) unanchored ratio ·
E20 (60) transport check adjacent to the measured path · E21 (60) the mori byte figure has one
oracle · E25 (58) "5 R functions" is the exported count · E26 (58) the sibling benchmark keeps the
loading idiom this probe calls a defect · E18 (55) draft cites untracked files · E15 (45) and
E23 (45) superseded figures in IP4 history, correct handling · E24 (40) established convention.

**Thrash trigger (b) fires.** AC3 has now failed twice, each by a new mechanism of the same
shape: a published wire figure that does not survive re-derivation (pass 1, the wrong fixture;
pass 2, the closure accounting). The plan gate recorded its rejected alternative as "a standalone
probe replica over patching `R/parallel.R` on the branch and reverting", with the falsifier
"the replica and `dispatch_folds()` being shown to differ in a way that changes the identity
result". The replica did differ from `dispatch_folds()` in a way that changed a result — the
wire result rather than the identity result — so the recorded falsifier was aimed one axis away
from where the failure landed. That alternative is what trigger (b) asks be reconsidered.

### Third pass, 2026-07-31 — returned again (return 3). Thrash triggers (a) AND (b) both fire.

Gates all clean for the third time: `devtools::check()` **Status: OK**; `devtools::test()` 1615 pass;
`cairn_validate` exit 0; `document()` no diff; probe exit 0 with every assertion passing. The
approach change worked on its own terms — the captured figures are internally consistent, every
row sum is exact, the ratio re-derives, and all three documents agree.

**AC3 fails a third time, by a third mechanism of the same shape.** The note's explanatory
sentence says the gap is explained by "the closure, 291,491 B, common to both rows and
cancelling; and the data, 840,540 B". Measured: 1,523,499 - 393,841 = **1,129,658**, not 840,540.
The lean route carries the closure TWICE — the wrapper `.f` at 291,418 B plus `.args$worker` at
291,491 B — where the modelled mori row carries it once, so 289,118 B of the gap, 26% of it, is
unexplained by the sentence that claims to explain all of it. The same defect was D5 (90) on
pass 1 and E1 (93) on pass 2; both times it was corrected in the table and left standing in the
prose, and it has now reached the unposted external draft.

Also verified: the note states the M23 under-reporting finding "is filed as a ROADMAP candidate
rather than corrected here". No such row exists — the Candidates list gained exactly one row this
milestone, for mori adoption. A finding is recorded as tracked and is not.

**Trigger (a): third return.** Per the rule this is a mis-planned milestone and no further retry
is queued under the current plan; it routes through `/milestone-plan`. The work log records an
approach change but no re-cut, so re-plan-or-split is still the available remedy.

**Trigger (b), second firing.** AC3 has now failed three times, each by a new mechanism of one
shape: a published wire figure that does not survive re-derivation. Pass 1 the fixture, pass 2 the
closure attribution in the table, pass 3 the closure attribution in the prose. The measurement
itself is now sound; what keeps failing is the prose written over it. That is the diagnosis a
re-cut should carry in: the criterion asks the note to *state* a comparison, and three passes
suggest the stating, not the measuring, is what needs a different shape — a criterion that pins a
derivable identity rather than a narrative would be checkable by script.

Two lenses of three reported before this verdict was recorded; the diff-bug and prior-review
lenses were still running and their findings are not in this list. The disposition does not turn
on them: the criterion failure above is verified by execution, and the return threshold is
reached regardless.

**Third lens reported after the verdict; findings appended rather than lost.** It confirmed the
closure decomposition independently by re-running the capture (289,118 B, 25.6% of the gap,
unexplained) and added four that sharpen the re-cut: the probe header claims "the WIRE section
hand-rolls nothing at all" while the mori row is hand-assembled and the fixture design hand-rebuilt,
and the note contradicts this eight lines after asserting it; the fixture *design* is re-typed at
`probe:361-366` while the header claims it is sourced, leaving open the exact drift that produced
pass 1's mislabelled fixture, because `fixture_design()` lives in a test file nothing can source;
the headline totals and the 3.87x ratio are printed by `cat()` with nothing cross-checking them
across the four files they appear in, against a note that says the probe "asserts its own findings
rather than printing them"; and M12 review D (75) already recorded that a top-level `on.exit()`
never fires, fixed in `benchmarks/mutation-sensitivity.R` and never harvested, so M26 paid to
rediscover it. Each of these is an argument for the same re-cut: an identity a script checks,
not a sentence a reader checks.

It also cleared the interception technique explicitly: the mutation is host-side only, restored by
a function-frame `on.exit()`, and cannot reach a daemon, so M07's mocked-binding trap and M12's
daemon-substitution lesson do not fire. Driving `dispatch_folds()` rather than replicating it
satisfies M07 F2 rather than regressing it, and the wire section now asserts the leaning branch was
taken, closing M23 F2's mutation-insensitivity concern for this script.

### Fourth pass, 2026-08-01 — returned again (return 4). Trigger (a) holds; trigger (b) fires a third time.

Gates all clean for the fourth time: `devtools::check()` **Status: OK** (0/0/0, 4m 9.6s);
`devtools::test()` FAIL 0 | WARN 0 | SKIP 0 | PASS 1615; `cairn_validate` exit 0; `document()` no
diff; probe exit 0. Re-running the probe regenerated `benchmarks/mori-wire-manifest.json` with a
**zero diff** — every figure re-derived identically, which is the one thing the re-cut set out to buy
and did buy.

**AC1 — NOT verified.** The criterion requires the probe to compute the sum of separately-serialized
parts "and assert the two differ, so publishing the sum fails rather than passes". The assertion is
`!identical(lean_total, sum_of_parts(lean_bundle))` at `probe:593-596`. `wire_bytes()` returns an
**integer** and `sum_of_parts()` a **double**, and `identical()` is type-strict, so the expression is
unconditionally TRUE whatever the byte counts are — verified by execution (`identical(100L, 100)` is
FALSE). The criterion names its own failure mode and the assertion has no failing state. This is the
second tautology to occupy AC1's slot: the re-cut's own criteria audit recorded replacing a
tautology here, and the replacement is one too.
**AC2 — verified.** The probe installs the working tree to a temporary library
(`R CMD INSTALL --with-keep.source=no`, `R_KEEP_PKG_SOURCE=no` set explicitly) and asserts srcref
state on both captured closures. The detector was mutation-tested at review: TRUE on a closure parsed
with `keep.source = TRUE`, FALSE with it off and FALSE after `removeSource()`, so the assertion is
not vacuous.
**AC3 — verified, with its strength stated.** The probe asserts the gap decomposition closes to the
byte, naming each term. Recorded plainly because three passes died here: the telescoping assertion
**cannot fail** — the rungs chain, so the deltas sum to the gap as arithmetic. Review added a
falsifiable companion (`mori_bundle_independent`, built member-by-member in mirai's order rather than
by substitution) and that is what now carries the criterion, together with the `.args`-rung
cross-check against the frame serialized alone.
**AC4 — NOT verified.** The amended criterion requires the manifest to record "the independent
oracles **asserted** for it", and the registry's own comment repeats that oracles are "checks that
have been ASSERTED for this figure, never merely computed beside it". `count_data_copies()` is called
three times in the whole script and asserted only on `lean_bundle` and `mori_bundle`
(`probe:703-704`). Three manifest oracle strings therefore describe assertions that do not exist:
`lean_payload_bytes` oracle 2, `shared_reference_bytes` oracle 1, `shared_marginal_bytes` oracle 1.
The script's own AC4 check counts strings rather than assertions, so it passes over the gap.
**AC5 — NOT verified.** The criterion requires development-state figures marked install-dependent.
`lean_bundle_bytes`, `mori_bundle_bytes`, `gap_bytes` and `ratio_lean_over_mori` all contain the
worker closure — the figure this milestone measured at 524 B installed against 291,491 B under
`load_all()` — and all four are marked `install_dependent: false`, while `worker_closure_bytes`
alone is marked true. The four headline figures are the install-dependent ones.
**AC6 — verified.** Every manifest figure names a fixture; the two fixture strings distinguish the
wire figures from the shared-reference ones.
**AC7 — verified.** Gates as above.

Three lenses again, deduplicated to 47 findings, scored by a fourth agent that generated none.
**9 scored >= 80; 2 of those were fixed during this pass and 7 remain open.**

Actioned and open: F1 (92) AC1's assertion is a type tautology · F24 (92) the ROADMAP row, the
assessment note and the maintainer draft all publish 1,523,499 / 393,841 / 3.87x / 291,491 against
this same diff's manifest at 941,687 / 103,119 / 9.13x / 524 · F25 (88) the ROADMAP row reproduces
verbatim the "the closure is common and cancels" sentence pass 3 disproved · F8 (86) three manifest
oracles were never asserted · F4 (85) `stopifnot(identical(body(patched), body(orig)))` cannot fail,
because `environment<-` never touches a body, yet is described as a staleness guard · F26 (85) the
note's P10 asserts a fixed-width 19-character region name while the probe in the same diff measures
it pid-dependent at 19 and 20 · F6 (82) the four headline figures' install-dependence flags are
inverted.

Fixed during this pass: F15/P1 (80) the fixture design was re-typed inline against a header claiming
it was sourced — pass 1's exact failure mechanism, raised by the pass-3 lens and never triaged.
`fixture_design()` moved from `test-parallel-payload.R` (a test file nothing can source) to
`helper-payload-size.R`, and the probe now calls it, so the suite's design and the published figures
are one definition. The move renumbered a budgeted wait and staled a time-budget ledger row, exactly
as LESSONS records from M16/M21; the ledger row was renumbered in the same pass and the suite is
green.

Logged below threshold, 38 findings, the nearest: F7 (78) `sum_of_parts_overstatement_bytes` is
marked derived but its value uses an unpublished quantity · F11 (78) the `.args`-rung 5% band is
~42,000 B against a 524 B term, too slack to detect what it guards, and is mislabelled "closed-form" ·
F17c (78) the probe measures with base `serialize()` (XDR) rather than nanonext's `send_mode = 1L`
encoder, and nothing checks they agree · F27 (78) "the WIRE section hand-rolls nothing at all" is
still false and still stale · F13 (76) the published per-fold cost is fold 1 only and nothing says so ·
F20 (68) the manifest records no package version, SHA or timestamp, so a drift check cannot tell
drift from a different revision · F30 (68) six work-log claims describe tautological assertions as
real checks · F32 (65) the manifest's 175.6667 is transcribed as 176 in the work log and 175 in the
note.

**Trigger (a) holds — this is return 4, past the third-return threshold.** The work log already
records a re-cut spent on this milestone, so re-plan-or-split is the move that just failed and is not
offered again.

**Trigger (b) fires a third time, and the diagnosis has changed.** The measurement is now sound: the
figures re-derive, the manifest regenerates byte-identically, and the fixture is sourced rather than
retyped. What fails now is a different layer of the same shape — **claims that do not correspond to
what was checked**. An assertion string in a manifest with no assertion behind it (F8), a flag that
names a property the figure does not have (F6), a `stopifnot` that cannot fail described as a guard
(F1, F4), and three documents publishing figures the same commit refutes (F24, F25, F26). Four passes
have now been spent, and each fixed the previous layer while introducing the next at one remove from
the numbers. The plan gate's recorded alternatives are all about how to *measure*; none is about how
the claims around the measurement are kept true, which is what has failed four times.

### Fifth pass, 2026-08-01 — after the unblock and rework 3

Gates: `devtools::check()` **Status: OK** (0 errors / 0 warnings / 0 notes); `devtools::test()`
FAIL 0 | WARN 0 | SKIP 0 | PASS 1615; `devtools::document()` no diff; `cairn_validate` exit 0, all
hard checks PASS (advisories: M29's inherited sizing tripwire, the 18 pre-existing shelf-wide
staleness lines); probe exit 0 with every assertion passing and every figure re-derived
byte-identically — the manifest diff against pass 4 is exactly the four intended flag flips plus one
reworded oracle string, no value moved.

- **AC1 — verified.** Single-stream capture unchanged from pass 4 (bundle intercepted at
  `request()`, member shape asserted, probe:543-549). The sum-vs-differ assertion is now
  `sum_of_parts(bundle) > total` on both rows (probe:599-602); the pass-4 type tautology is gone.
  Falsifiability verified by execution this pass: `941687L > 941687` evaluates FALSE, so the
  `stopifnot` aborts when the two agree — the assertion has a failing state and the measured
  overstatement is 150 B lean / 20 B mori.
- **AC2 — verified.** Temp-library install (`R CMD INSTALL --with-keep.source=no`,
  `R_KEEP_PKG_SOURCE=no`) unchanged from pass 4; this run's log: "source references in the captured
  closures: .f FALSE, .args$worker FALSE", asserted at probe:565. Detector mutation-tested at pass 4.
- **AC3 — verified, strength as recorded at pass 4.** The telescoping identity closes to the byte
  naming each rung; the falsifiable half is `mori_bundle_independent` (member-by-member in mirai's
  order, `identical()` to both the ladder endpoint and the substituted bundle, probe:665-669) plus
  the `.args`-rung cross-check (840,828 vs 840,540 B, 0.0%).
- **AC4 — verified.** Every manifest oracle string now maps to an assertion the probe runs, checked
  string-by-string this pass: lean bundle (copy-count probe:709 == 1; `.args` rung vs frame :694),
  mori bundle (copy-count :710 == 0; ladder identity :667-668), lean payload (closed form :704, 96,000
  vs 98,346, 2.4%, inside M23's 5% band; payload counted alone :711 == 0), gap (ladder :683; rung
  cross-check :694), shared reference and marginal (copy-counts :404-406 == 0 single and across four
  refs, new this pass; 4x invariance :430, 268 vs 268 B, 0.0%), worker closure (srcref walk :565;
  strip-invariance :747). Each pair shares no arithmetic. The two derived figures name only
  non-derived published sources, asserted probe:763-767.
- **AC5 — verified.** Manifest committed and machine-readable (parsed with jsonlite this pass: 9
  figures, 7 measured, 2 derived). The install-dependent marks now cover every figure whose value
  embeds the worker closure — the four headline figures joined `worker_closure_bytes` and the
  overstatement; `lean_payload_bytes` and the two shared-reference figures, which carry no closure,
  stay drift-checkable.
- **AC6 — verified.** Every figure names its fixture; the two fixture strings separate the wire
  figures (M23's `fixture_design()`) from the shared-reference ones (10000x1 frame).
- **AC7 — verified.** Gates as above, run fresh this session.
