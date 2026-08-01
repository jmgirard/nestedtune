# M26: The backend question has a measured answer before the design settles

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP4
- **Branch/PR:** `m26-mori-backend-assessment`

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
- [ ] T6: Draft the maintainer-facing note under `benchmarks/`, unposted.
- [ ] T7: Run the profile's `verify` slot; add a ROADMAP candidate row for
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

## Decisions

## Review
