# M13: The rsample diagnosis reaches its maintainers

- **Status:** in-progress
- **Priority:** low
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Branch/PR:** `m13-rsample-283-report`

## Goal

rsample's maintainers get the cause of issue #283 and the correction to its
headline figure, in a form they can act on without re-deriving it.

## Scope

**In:** A committed reprex measuring nested-design object size under an explicit
10×10 scheme and under the 5×2 scheme issue #283's prose describes, against a
named rsample version; a committed draft comment naming
`inside_resample()`'s `as.data.frame()` as the cause and explaining how the 13×
figure arose; and a handoff line naming the target for the maintainer to post.

**Out:** Posting the comment — that is the maintainer's to do, and doing it
before review would publish figures irreversibly ahead of the gate that checks
them. Opening a pull request against rsample; the issue asks for a diagnosis,
and a fix upstream is a separate conversation. Any change to `nestedtune`
itself: M01 already ships the lean constructor this diagnosis explains.

## Acceptance criteria

- [ ] AC1 A committed reprex script measures object size under an explicit
      `vfold_cv(v = 10)`/`vfold_cv(v = 10)` scheme and under the 5×2 scheme the
      issue's prose describes, showing the 13× figure attaches to the former and
      not the latter; it records the rsample version, R version, OS, and seed.
- [ ] AC2 The reprex's measured figures are corroborated by a closed-form
      storage model for `rsample::nested_cv()` — one shared copy of the data,
      one materialized analysis frame per outer fold, and the outer and inner
      index vectors — recomputed in the reprex with explicit arithmetic. The
      model is first validated against the already-committed *measured* rsample
      figure of 11.373× at v=10/inner-5
      (`tests/testthat/test-nested-resamples-memory.R:87`), then applied to the
      10×10 and 5×2 schemes; the agreement or the gap is stated in the Review
      section. Measurement (live) and the model (closed-form) are the ≥2
      independent oracle types GP2 requires for a number the package is about
      to publish.
- [ ] AC3 A committed draft comment states that `inside_resample()`'s
      `as.data.frame()` is the cause; that the 13× figure came from
      `vfold_cv(times = 5)`/`(times = 2)` falling into `...` because
      `vfold_cv()` has no `times` argument, so both levels defaulted to `v = 10`;
      and that current rsample rejects that call via `check_dots_empty()`. It
      cites AC1's figures for both schemes.
- [ ] AC4 The milestone file carries a handoff line naming rsample#283 as the
      target; the comment URL is recorded there once the maintainer posts it.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T4

## Tasks

- [x] T1 Write `benchmarks/rsample-283-reprex.R`: build both schemes explicitly
      on `LetterRecognition`, measure with `lobstr::obj_size()` as
      `test-nested-resamples-memory.R` does, record versions/OS/seed.
- [ ] T2 Derive the rsample-side closed-form model in the reprex, validate it
      at v=10/inner-5 against the committed 11.373×, and apply it to both
      schemes; state the agreement or the gap.
- [ ] T3 Draft the comment as `benchmarks/rsample-283-comment.md`; show it
      verbatim at the review gate before anything is committed as final.
- [ ] T4 Add the handoff line; leave the URL slot for the maintainer to fill.

## Work log

- 2026-07-27: created by /milestone-plan.
- 2026-07-27: plan gate chose ending at a committed draft plus handoff over posting within the milestone, because the post is irreversible and public and would precede the review that validates its figures; falsified by nothing short of the maintainer delegating the post explicitly.
- 2026-07-27: plan gate chose re-measuring both schemes explicitly over re-running the issue's original reprex, because current rsample rejects that call via `check_dots_empty()` (G4) so it cannot be run at all; falsified by evidence that an rsample version accepting the original call is the right comparison target.
- 2026-07-27: branch `m13-rsample-283-report` cut from `main` at `74068e3`; status → in-progress.
- 2026-07-27: substantive amendment at the implement question gate — AC2 named `analytic_size()` (the *lean* model, 2.633× at v=10/inner-5) as the source of 11.373×, which is in fact the *measured* rsample figure at `test-nested-resamples-memory.R:87`, and at inner-5 rather than the 10×10 the criterion asked it to corroborate. AC2 and T2 now require an rsample-side closed-form model derived in the reprex, validated against that measured 11.373×, then applied to both schemes; live + closed-form are GP2's two types.
- 2026-07-27: T1 — `benchmarks/rsample-283-reprex.R` measures both schemes on `LetterRecognition` (rsample 1.3.2, R 4.6.1, aarch64-apple-darwin25.4.0, seed 35222): 10×10 = 33,715,400 B over 10 outer folds = **12.749×**; 5×2 = 13,871,840 B over 5 outer folds = **5.245×**. The issue's own call errors under 1.3.2 (`rlib_error_dots_nonempty`, naming `times = 5`), recorded by the script rather than worked around. Suite clean, 1247 pass.
- 2026-07-27: implement gate chose `benchmarks/rsample-283-comment.md` as the draft comment's home over the milestone file, because archiving compresses the milestone to ≤25 lines exactly when the maintainer goes to post it; and kept the rsample-side model in the benchmark script only, per Scope Out — a test on an external package's internals would fail this suite for upstream reasons.

## Decisions

## Review
