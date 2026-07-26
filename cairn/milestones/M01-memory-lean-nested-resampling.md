# M01: Memory-lean nested resampling structure

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP2, GP1, GP3, GP4
- **Branch/PR:** `m01-memory-lean-nested-resampling` · https://github.com/jmgirard/nestedtune/pull/1

## Goal

Ship an exported nested-resampling constructor whose object size does not grow
with the outer fold count, producing splits row-identical to
`rsample::nested_cv()`.

## Scope

**In:** The R package skeleton (DESCRIPTION, NAMESPACE, `R/`, `tests/testthat/`,
LICENSE, NEWS.md, `_pkgdown.yml`, CI). One exported constructor that builds the
nested structure by **index composition** — inner splits are built with
`rsample::make_splits()` over the *original* data and reassembled into an inner
`rset` that keeps the inner specification's own class, `id` columns, and
attributes, rather than being built over a materialized analysis frame. RNG
fidelity so inner splits match rsample's for the same seed and spec. Tests for
content identity, memory scaling, and every error branch. Roxygen docs for the
export. _(amended 2026-07-25)_

**Out:**
- Outer-loop orchestration, `tune` integration, collected results (G1–G3, G5) →
  the next milestone, planned separately; this one deliberately ships no loop.
- Reporting the diagnosis upstream on rsample#283 → candidate row.
- Variance estimation (G6), tune#969 posture (G7) → existing candidate rows.
- Parallelism and any `tune` dependency → deferred with the orchestration work.

## Acceptance criteria

- [x] AC1 — `devtools::check()` clean: 0 errors, 0 warnings, NOTEs justified in
      the review evidence.
- [x] AC2 — For a fixed seed and inner/outer spec, every inner analysis set and
      every inner assessment set is row-identical to the corresponding set from
      `rsample::nested_cv()`, compared as retrieved data frames. This is the
      reference-implementation oracle (GP2).
- [x] AC3 — Object size grows with the outer fold count only through index
      vectors, never through retained copies of the data. Measured at
      v = 2, 5, 10, 50 with the inner spec held fixed, the fitted size increase
      per additional outer fold is less than 0.25× the size of the source data,
      and is at least 5× shallower than the same measurement on
      `rsample::nested_cv()`, whose slope is ≈1× the source data per outer
      fold. Both measurements are recorded. _(amended 2026-07-25)_
- [x] AC4 — The measured size at each v matches an analytic prediction
      (one shared copy of the data, plus the index vectors implied by the
      scheme) within a stated tolerance. This is the analytic oracle, the second
      independent type GP2 requires beside AC2.
- [x] AC5 — Stratified and grouped inner specs either produce splits meeting
      AC2, or are refused with a `cli_abort()` naming the limitation; the
      chosen behavior is documented and each error branch is fired by a test.
- [x] AC6 — Every exported object has roxygen docs and a `_pkgdown.yml`
      reference row; `devtools::document()` produces no diff.

## Coverage

- AC1 → T1, T7
- AC2 → T2, T3, T4
- AC3 → T6
- AC4 → T6
- AC5 → T5
- AC6 → T1, T7

## Tasks

- [x] T1 — Scaffold the package: DESCRIPTION (rsample in Imports; testthat,
      lobstr, mlbench in Suggests, per D-006), roxygen NAMESPACE, MIT LICENSE,
      NEWS.md, `_pkgdown.yml`, `.Rbuildignore` entries, and the usethis CI pair
      (`check-standard`, `test-coverage`).
- [x] T2 — Write the failing content-identity tests first: build the same scheme
      with `rsample::nested_cv()` and with the (not yet existing) constructor
      under one seed, and compare every inner analysis/assessment set.
- [x] T3 — Implement the index-composition core: given an outer `rset` and an
      inner spec, compose outer-analysis indices with inner indices and build
      each inner split via `rsample::make_splits(list(analysis =, assessment =),
      data = <original>)`, reassembled into the inner spec's own `rset`.
- [x] T4 — RNG fidelity: evaluate the inner spec against each outer fold's
      analysis frame built transiently, harvest its indices, remap them through
      the outer analysis index vector, and discard the frame — so the same seed
      yields the same splits as rsample while nothing materialized is retained.
      (RB tripwire: ip-touching — IP2 reproducibility; settled at the gate.)
- [x] T5 — Support stratified and grouped inner specs under AC2; fire and test
      every `cli_abort()` branch the constructor does have (bad `outside`/
      `inside` arguments, outer bootstrap).
- [x] T6 — Memory benchmark test across v = 2, 5, 10, 50 measuring both the new
      constructor and `rsample::nested_cv()`, asserting AC3's flatness and AC4's
      analytic prediction; commit the generator per the profile's fixture
      provenance rule.
- [x] T7 — Roxygen docs for the export, `_pkgdown.yml` row, `document()` no-diff,
      NEWS.md entry, `devtools::check()` clean.

## Work log

- 2026-07-25: created by /milestone-plan; G4 ledger correction made at plan time rather than queued as a task (current knowledge is corrected where it sits).
- 2026-07-25: DESIGN.md principle definitions reformatted to the `- IPn:` bullet form cairn_validate parses; wording unchanged, no principle added, retired, or renumbered.
- 2026-07-25: /milestone-implement started on branch `m01-memory-lean-nested-resampling`; rsample 1.3.2, lobstr 1.2.1, mlbench 2.1.10 installed locally (R 4.6.1).
- 2026-07-25: feasibility spike confirmed index composition is row-identical to rsample and removes the whole O(V) data-copy term (LetterRecognition, inner v=5: rsample 2.16x→57.46x, lean 1.16x→8.50x across v=2..50).
- 2026-07-25: AC3 amended at the question gate — the original ratio bound is unreachable because inner splits store index vectors whose cost equals rsample's; the amended criterion bounds the per-fold slope instead. Approved by the user.
- 2026-07-25: T4 reworded from a stand-in frame to transient materialization, and T5 from support-or-refuse to support, both settled at the question gate; export name and class recorded as D-008.
- 2026-07-25: T1 done — package skeleton (DESCRIPTION, MIT LICENSE, NEWS.md, `_pkgdown.yml`, `.Rbuildignore`, `R/`, `tests/testthat/`) and the usethis CI pair; `document()` writes NAMESPACE and the package Rd, `load_all()` clean. `devtools::test()` still aborts "No test files found" until T2 — expected, not a failure.
- 2026-07-25: dependency gate — `cli` and `rlang` added to Imports, recorded as D-009 amending D-006; both are already rsample dependencies, so no practical weight is added.
- 2026-07-25: T2 done — 6 content-identity tests against `rsample::nested_cv()` (v-fold/v-fold, v-fold/bootstrap, repeated outer, pre-evaluated outer rset, class + spec attributes, deliberate row-name divergence), all red on "could not find function". Red is T2's intended state; the verify slot's clean-test bar applies from T3 on.
- 2026-07-25: minor plan amendment — a README is deferred to T7 with the rest of the user-facing docs rather than added at T1; it will be hand-written `README.md` with no `README.Rmd`, so the consistency gate's knit check is a deliberate no-op.
- 2026-07-25: T3 done — `nested_resamples()` implemented and exported; all 6 identity tests green plus 3 new ones for inner-rset identity (221 assertions, 0 failures).
- 2026-07-25: milestone-local decision on row-name divergence superseded — the premise was false, `analysis()` renumbers on retrieval either way, so AC2 is now asserted with exact `expect_identical()`.
- 2026-07-25: Scope amended at a mini gate — inner splits are reassembled into the spec's own rset rather than `manual_rset()`, which was measured to drop the inner class, the spec attributes, and a repeated spec's `id2` column. Approved by the user.

- 2026-07-25: T4 done — 5 RNG-fidelity tests (same seed identical, different seed differs, RNG stream left in the same position as rsample, every inner split shares the caller's data by address via lobstr, indices confined to the outer analysis set). 272 assertions, 0 failures.

- 2026-07-25: T5 done — stratified and grouped inner and outer specs all match `rsample::nested_cv()` with no special handling, plus group-integrity, character-vs-factor strata, and NA-row coverage; all 4 `cli_abort()` branches fired, and the zero-/one-row edge cases pinned to rsample's own message. 469 assertions, 0 failures.

- 2026-07-25: T6 done — memory benchmark on LetterRecognition (inner v=5), size as multiples of the 2.645 MB source: lean 1.186/1.734/2.649/9.965 vs rsample 2.156/5.612/11.373/57.458 at v=2/5/10/50. Slopes per outer fold: lean 0.183, rsample 1.152 (6.3x shallower). The analytic model predicts every measured size within 0.72%, well inside the 2% tolerance asserted.
- 2026-07-25: DESIGN.md Conventions gained the oracle-records pointer the validation doctrine requires — its absence in a repo with numeric work is itself an audit finding. Records live in headers in the asserting test file.

- 2026-07-25: T7 done — roxygen docs, `_pkgdown.yml` reference row, NEWS.md entries, and a hand-written README.md. `devtools::check()` is 0 errors / 0 warnings / 0 notes; `pkgdown::check_pkgdown()` clean after adding the pkgdown URL to DESCRIPTION.
- 2026-07-25: two check WARNINGs fixed at T7 — an `@section` title containing `rsample::nested_cv()` in backticks made roxygen emit a malformed Rd section, and NEWS.md's `# nestedtune (development version)` heading was unparseable by R's news reader (now `# nestedtune 0.0.0.9000`).

- 2026-07-25: all 7 tasks complete; `devtools::test()` 476 passing / 0 failures, `devtools::check()` 0/0/0, `document()` no-diff, `pkgdown::check_pkgdown()` clean, `cairn_validate` all green. Status in-progress -> review.

- 2026-07-25: review fan-out found 7 findings; 4 scored >=80 and were fixed on the branch (IP1 leakage via a prebuilt `outside` rset, missing per-split `$id`, lost split subclass, overclaiming docs). 3 below threshold logged; F7 added as a ROADMAP candidate. Suite 476 -> 549 assertions.

## Decisions

- **Transient materialization, not a stand-in frame** (2026-07-25, question
  gate). Each outer fold's analysis frame is built, handed to the inner spec,
  and discarded; only indices are kept. The stand-in frame the plan proposed
  also reproduced rsample's indices for plain specs, but supporting
  `strata`/`group` would mean extracting those column names from the user's
  unevaluated call. Transient materialization gets them for free and cannot
  silently diverge. Nothing materialized is retained, so AC3/AC4 are unaffected.
- **Row names diverge from `rsample::nested_cv()` by design** (2026-07-25).
  rsample's `inside_resample()` calls `as.data.frame(src)`, which renumbers rows
  `1..n`, so its inner splits index a renumbered frame and `analysis()` returns
  rows named `1..n`. nestedtune's inner splits index the original data, so
  retrieved rows keep their original names. AC2's "row-identical" is read as
  identity of the rows themselves; tests compare with row names normalized and
  assert the divergence deliberately rather than tolerating it silently.
- **Supersedes the entry above: there is no row-name divergence** (2026-07-25,
  found at T3). The premise was wrong. `rsample::analysis()` and
  `assessment()` renumber row names on retrieval, so it is not observable that
  nestedtune's splits index the original data while rsample's index a
  materialized frame — the retrieved frames are identical including attributes.
  The tests therefore compare with `expect_identical()` and no normalization,
  which is a stronger form of AC2 than the entry above proposed.
- **Inner rsets keep their spec's identity, not `manual_rset()`'s**
  (2026-07-25, Scope amended at a mini gate). `manual_rset()` was measured to
  drop the inner spec's class, its spec attributes, and — for a repeated inner
  spec — the whole `id2` column. The remapped splits are instead swapped into
  the rset the spec produced. Its `fingerprint` is the one attribute recomputed:
  it describes rsample's indices, and carrying it over would be a stale claim.

## Review

Evidence gathered fresh at review on R 4.6.1 / rsample 1.3.2, by command.

- **AC1** — `devtools::check(document = TRUE, args = "--no-manual")` run fresh: **Status: OK — 0 errors, 0 warnings, 0 notes** (22s). No NOTEs to justify.
- **AC2** — `test-nested-resamples-identity.R`: 221 assertions, 0 failures. Inner analysis and assessment sets compared to `rsample::nested_cv()` with `expect_identical()` and no normalization, across v-fold/v-fold, v-fold/bootstrap, a repeated outer scheme, and a pre-evaluated outer `rset`. `test-nested-resamples-specs.R` (197 assertions) extends the same comparison to stratified and grouped specs. Live reference-implementation oracle, recomputed at test time, not frozen.
- **AC3** — Measured fresh on `mlbench::LetterRecognition` (20000 x 17, 2.645 MB), inner v = 5, as multiples of source-data size: v=2 lean 1.186 / rsample 2.156; v=5 1.734 / 5.612; v=10 2.649 / 11.373; v=50 9.965 / 57.458. Per-outer-fold slope: lean **0.1829** (bound < 0.25), rsample **1.1521** (the criterion's approx-1-copy-per-fold), **6.30x shallower** (bound >= 5x). Both measurements recorded here and in the asserting test's oracle header.
- **AC4** — Analytic prediction `size(data) + 4 * n * (v - 1) * (inner_v + 1)`, derived from what the structure must hold rather than from the code. Max `|measured / analytic - 1|` = **0.72%** across v = 2, 5, 10, 50, against the **2%** tolerance the test asserts. A negative-control test asserts the same model does *not* fit `rsample::nested_cv()`'s sizes, so it cannot pass by fitting anything.
- **AC5** — Chosen behavior is **support**, not refusal. Stratified and grouped inner specs match `rsample::nested_cv()` under AC2's comparison, as do stratified and grouped *outer* specs; a group-integrity test confirms no group straddles an inner split. Documented in the roxygen `Differences from rsample` section and in NEWS.md. All four `cli_abort()` branches fired by tests (non-data-frame `data`; non-`rset` `outside`; outer bootstrap, as a call *and* as a prebuilt object; non-call `inside`), plus zero-row and one-row edge cases pinned to rsample's own message. 197 assertions, 0 failures.
- **AC6** — `devtools::document()` produces no diff against the committed tree. The single export `nested_resamples` has `man/nested_resamples.Rd` and a `_pkgdown.yml` reference row; `pkgdown::check_pkgdown()` reports no problems.

### Consistency gate

- `cairn_validate`: exit 0, all checks passed (16 PASS, 7 advisory OK).
- No `DESIGN.md` IP/GP principle changed — only a Conventions line was added — so `cairn_impact` is skipped.
- r-package `consistency-gate` slot: `document()` no diff; `NAMESPACE` and `man/` regenerate from roxygen; `pkgdown::check_pkgdown()` clean; NEWS.md carries the user-visible entries and no milestone numbers appear in user-facing text; no `.Rbuildignore` gaps (`check()` reported 0 NOTEs); full `check()` clean. No `README.Rmd` exists, so the knit check is a deliberate no-op recorded at T1.
- CI on PR #1: all six jobs pass — macOS release, Windows release, ubuntu release, ubuntu devel, ubuntu oldrel-1, and test-coverage. Re-run green on the review-fix commit; `check()` and `cairn_validate` also re-run clean after the fixes.

### Independent review fan-out

Three fresh-context lenses, then a Sonnet scorer that did not generate the findings.

- **[S] prior-PR-comments:** no prior-review evidence — `milestones/archive/` holds only `.gitkeep` and the GitHub inline-comment probe returned empty. Zero findings, a clean no-op for the repo's first code milestone.
- **[S] blame-history:** zero findings. Verified the shipped code against D-006/D-009 (dependency set), D-008 (export name and class), the AC3 and Scope amendments, the superseded row-name decision, and D-005's carve-out; found no contradiction and no leftover of an abandoned approach.
- **[O] diff-bug:** seven findings, all reproduced by execution in the main session before scoring.

Actioned (score >= 80), all four fixed on the branch:

- **F1 (88) — IP1 leakage.** A pre-evaluated `outside` rset built on a *different* data frame had its indices remapped onto `data`, drawing inner analysis rows from the outer assessment set — 22 leaked rows in the reproduction, where `rsample::nested_cv()` leaks none because it ignores `data` for an rset. A row-count mismatch constructed silently and failed later with an out-of-range error naming nothing the user typed. **Fixed:** `nested_resamples()` now refuses when the rset's data is not the data it was handed, per GP3.
- **F2 (85) — inner splits lacked `$id`.** Rebuilding splits with `make_splits()` bypassed the per-split id tibble rsample attaches, so `labels()` returned a 0x0 tibble and `rsample::add_resample_id()` errored — falsifying D-002's premise that each inner element is an ordinary `rset` tune accepts. **Fixed** with F3.
- **F3 (82) — inner splits lost their subclass.** `vfold_split` became bare `rsplit`, so `rsample:::internal_calibration_split()` (tune's post-processing path) errored; the outer splits kept their class, leaving the object internally inconsistent. **Fixed:** rsample's own split objects are now kept and only their `data`/`in_id`/`out_id` fields rewritten, which closes F2 and F3 together. Verified: class and names match, the calibration generic returns `vfold_split_cal`, `add_resample_id()` works; the only residual differences are the three index-bearing fields, which is what the package exists to change.
- **F5 (80) — docs overclaimed.** DESCRIPTION, NEWS.md, README.md, and the roxygen said the splits were "identical" and the object a "drop-in substitution". **Fixed:** narrowed to what is verified — the splits select the same rows, retrieved frames are identical, and each inner split carries the same class and resample id.

Logged, below the 80 threshold, not actioned:

- **F4 (68)** — the AC2 oracle compares retrieved frames and the inner rset's attributes but never the split objects, which is why F2/F3 went unnoticed. AC2's wording is satisfied, so this is a scope-of-oracle gap; the F2/F3 regression test now covers it incidentally.
- **F7 (78)** — an `inside` expression evaluating to a non-`rset` surfaces rsample's internal "Split and ID vectors have different lengths" rather than a `cli_abort()`. Added as a ROADMAP candidate row.
- **F6 (55)** — the analytic model's header overstated its independence. Corrected in place anyway, since it is one comment: charging both index vectors is structural for splits that index the whole data, because the complement is not derivable there.

No acceptance criterion and no gate check failed, so the milestone stayed at `review` and the four findings were fixed on the branch per the fan-out's fix-now disposition.
