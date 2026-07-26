# M01: Memory-lean nested resampling structure

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP1, GP3, GP4
- **Branch/PR:** —

## Goal

Ship an exported nested-resampling constructor whose object size does not grow
with the outer fold count, producing splits row-identical to
`rsample::nested_cv()`.

## Scope

**In:** The R package skeleton (DESCRIPTION, NAMESPACE, `R/`, `tests/testthat/`,
LICENSE, NEWS.md, `_pkgdown.yml`, CI). One exported constructor that builds the
nested structure by **index composition** — inner splits are built with
`rsample::make_splits()` over the *original* data and assembled with
`manual_rset()`, rather than over a materialized analysis frame. RNG fidelity so
inner splits match rsample's for the same seed and spec. Tests for content
identity, memory scaling, and every error branch. Roxygen docs for the export.

**Out:**
- Outer-loop orchestration, `tune` integration, collected results (G1–G3, G5) →
  the next milestone, planned separately; this one deliberately ships no loop.
- Reporting the diagnosis upstream on rsample#283 → candidate row.
- Variance estimation (G6), tune#969 posture (G7) → existing candidate rows.
- Parallelism and any `tune` dependency → deferred with the orchestration work.

## Acceptance criteria

- [ ] AC1 — `devtools::check()` clean: 0 errors, 0 warnings, NOTEs justified in
      the review evidence.
- [ ] AC2 — For a fixed seed and inner/outer spec, every inner analysis set and
      every inner assessment set is row-identical to the corresponding set from
      `rsample::nested_cv()`, compared as retrieved data frames. This is the
      reference-implementation oracle (GP2).
- [ ] AC3 — Measured object-size ratio to the source data does **not** grow with
      the outer fold count: measured at v = 2, 5, 10, 50 with the inner spec
      held fixed, the ratio at v = 50 is no greater than the ratio at v = 2
      times a small stated constant. The same measurement on
      `rsample::nested_cv()` is recorded alongside and does grow with v.
- [ ] AC4 — The measured size at each v matches an analytic prediction
      (one shared copy of the data, plus the index vectors implied by the
      scheme) within a stated tolerance. This is the analytic oracle, the second
      independent type GP2 requires beside AC2.
- [ ] AC5 — Stratified and grouped inner specs either produce splits meeting
      AC2, or are refused with a `cli_abort()` naming the limitation; the
      chosen behavior is documented and each error branch is fired by a test.
- [ ] AC6 — Every exported object has roxygen docs and a `_pkgdown.yml`
      reference row; `devtools::document()` produces no diff.

## Coverage

- AC1 → T1, T7
- AC2 → T2, T3, T4
- AC3 → T6
- AC4 → T6
- AC5 → T5
- AC6 → T1, T7

## Tasks

- [ ] T1 — Scaffold the package: DESCRIPTION (rsample in Imports; testthat,
      lobstr, mlbench in Suggests, per D-006), roxygen NAMESPACE, MIT LICENSE,
      NEWS.md, `_pkgdown.yml`, `.Rbuildignore` entries, and the usethis CI pair
      (`check-standard`, `test-coverage`).
- [ ] T2 — Write the failing content-identity tests first: build the same scheme
      with `rsample::nested_cv()` and with the (not yet existing) constructor
      under one seed, and compare every inner analysis/assessment set.
- [ ] T3 — Implement the index-composition core: given an outer `rset` and an
      inner spec, compose outer-analysis indices with inner indices and build
      each inner split via `rsample::make_splits(list(analysis =, assessment =),
      data = <original>)`, assembled with `manual_rset()`.
- [ ] T4 — RNG fidelity: evaluate the inner spec against a placeholder frame
      carrying only the columns that spec references, harvest its indices, and
      remap them through the outer analysis index vector — so the same seed
      yields the same splits as rsample without materializing the analysis set.
      (RB tripwire: ip-touching — IP2 reproducibility.)
- [ ] T5 — Handle stratified and grouped inner specs: support them under AC2, or
      refuse with a clear `cli_abort()`; test every branch either way.
- [ ] T6 — Memory benchmark test across v = 2, 5, 10, 50 measuring both the new
      constructor and `rsample::nested_cv()`, asserting AC3's flatness and AC4's
      analytic prediction; commit the generator per the profile's fixture
      provenance rule.
- [ ] T7 — Roxygen docs for the export, `_pkgdown.yml` row, `document()` no-diff,
      NEWS.md entry, `devtools::check()` clean.

## Work log

- 2026-07-25: created by /milestone-plan; G4 ledger correction made at plan time rather than queued as a task (current knowledge is corrected where it sits).
- 2026-07-25: DESIGN.md principle definitions reformatted to the `- IPn:` bullet form cairn_validate parses; wording unchanged, no principle added, retired, or renumbered.

## Decisions

## Review
