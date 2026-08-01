# M26: The backend question has a measured answer before the design settles

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP4
- **Branch/PR:** —

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

- [ ] T1: Install `mori` 0.2.2; read its source, docs, and tune#1188; record the
      transfer mechanism and whether it has any RNG surface at all.
- [ ] T2: Write `benchmarks/probe-mori-dispatch.R` — a standalone fold-dispatch
      replica sending one design's folds by value and via `mori`, at ≥ 2 worker
      counts, RNG kind pinned as `set_fold_seed()` does (`R/nested-tune-grid.R:620`).
- [ ] T3: Run the probe; record identity results and wire bytes, counting copies
      by `grepRaw()` as M23 did rather than inferring them from a total.
- [ ] T4: Map findings onto D-011, D-018, M23's numbers, and the two adjacent
      candidate rows; state the same-machine consequence.
- [ ] T5: Author the synthesis note from `templates/synthesis-note.md`; add its
      `INDEX.md` bullet.
- [ ] T6: Draft the maintainer-facing note under `benchmarks/`, unposted.
- [ ] T7: Run the profile's `verify` slot; add a ROADMAP candidate row for
      adopting `mori` if the findings warrant one.

## Work log

- 2026-07-31: created by /milestone-plan.
- 2026-07-31: criteria audit ([O], fresh context) returned two findings here — AC2's "mori-carrying daemon pool" was satisfiable by a pool that never sent an object through mori, and its only reachable evidence conflicted with the Scope Out ban on editing `R/parallel.R`; AC5 was existence-only with nothing constraining per-claim marking. AC2 went to the gate, AC5 was fixed to M27 AC5's wording.
- 2026-07-31: plan gate chose a standalone probe replica over patching `R/parallel.R` on the branch and reverting, because the milestone stays research-only and a half-reverted runtime edit is the worse failure; falsified by the replica and `dispatch_folds()` being shown to differ in a way that changes the identity result.

## Decisions

## Review
