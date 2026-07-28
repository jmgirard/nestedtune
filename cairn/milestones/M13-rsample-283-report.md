# M13: The rsample diagnosis reaches its maintainers

- **Status:** review
- **Priority:** low
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Branch/PR:** `m13-rsample-283-report` / https://github.com/jmgirard/nestedtune/pull/18

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

- [x] AC1 A committed reprex script measures object size under an explicit
      `vfold_cv(v = 10)`/`vfold_cv(v = 10)` scheme and under the 5×2 scheme the
      issue's prose describes, showing the 13× figure attaches to the former and
      not the latter; it records the rsample version, R version, OS, and seed.
- [x] AC2 The reprex's measured figures are corroborated by a closed-form
      storage model for `rsample::nested_cv()` — one shared copy of the data,
      one materialized analysis frame per outer fold, and the outer and inner
      index vectors — recomputed in the reprex with explicit arithmetic. The
      model is first validated against the already-committed *measured* rsample
      figure of 11.373× at v=10/inner-5
      (`tests/testthat/test-nested-resamples-memory.R:86`), then applied to the
      10×10 and 5×2 schemes; the agreement or the gap is stated in the Review
      section. Measurement (live) and the model (closed-form) are the ≥2
      independent oracle types GP2 requires for a number the package is about
      to publish.
- [x] AC3 A committed draft comment states that `inside_resample()`'s
      `as.data.frame()` is the cause; that the 13× figure came from
      `vfold_cv(times = 5)`/`(times = 2)` falling into `...` because
      `vfold_cv()` has no `times` argument, so both levels defaulted to `v = 10`;
      and that current rsample rejects that call via `check_dots_empty()`. It
      cites AC1's figures for both schemes.
- [x] AC4 The milestone file carries a handoff line naming rsample#283 as the
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
- [x] T2 Derive the rsample-side closed-form model in the reprex, validate it
      at v=10/inner-5 against the committed 11.373×, and apply it to both
      schemes; state the agreement or the gap.
- [x] T3 Draft the comment as `benchmarks/rsample-283-comment.md`; show it
      verbatim at the review gate before anything is committed as final.
- [x] T4 Add the handoff line; leave the URL slot for the maintainer to fill.

## Work log

- 2026-07-27: created by /milestone-plan.
- 2026-07-27: plan gate chose ending at a committed draft plus handoff over posting within the milestone, because the post is irreversible and public and would precede the review that validates its figures; falsified by nothing short of the maintainer delegating the post explicitly.
- 2026-07-27: plan gate chose re-measuring both schemes explicitly over re-running the issue's original reprex, because current rsample rejects that call via `check_dots_empty()` (G4) so it cannot be run at all; falsified by evidence that an rsample version accepting the original call is the right comparison target.
- 2026-07-27: branch `m13-rsample-283-report` cut from `main` at `74068e3`; status → in-progress.
- 2026-07-27: substantive amendment at the implement question gate — AC2 named `analytic_size()` (the *lean* model, 2.633× at v=10/inner-5) as the source of 11.373×, which is in fact the *measured* rsample figure at `test-nested-resamples-memory.R:87`, and at inner-5 rather than the 10×10 the criterion asked it to corroborate. AC2 and T2 now require an rsample-side closed-form model derived in the reprex, validated against that measured 11.373×, then applied to both schemes; live + closed-form are GP2's two types.
- 2026-07-27: T1 — `benchmarks/rsample-283-reprex.R` measures both schemes on `LetterRecognition` (rsample 1.3.2, R 4.6.1, aarch64-apple-darwin25.4.0, seed 35222): 10×10 = 33,715,400 B over 10 outer folds = **12.749×**; 5×2 = 13,871,840 B over 5 outer folds = **5.245×**. The issue's own call errors under 1.3.2 (`rlib_error_dots_nonempty`, naming `times = 5`), recorded by the script rather than worked around. Suite clean, 1247 pass.
- 2026-07-27: T2 — closed-form model `rsample_size() = data_bytes*v + 4n(v-1)*inner_v` added to the reprex (v analysis frames + outer/inner analysis indices; `out_id` is `NA` on both, verified). It sits under all three measurements as an overhead-free model must: 10×5 −0.11%, 10×10 −0.20%, 5×2 −0.06%. The live 10×5 re-measurement reproduces the committed 11.373× to +0.00%. Contrast with the committed lean model is one term: `data_bytes*v` vs `data_bytes` — (v−1) copies of the data, which is the diagnosis.
- 2026-07-27: T2 — the issue's 2022 figure (34,434,200 B) exceeds today's 10×10 (33,715,400 B) by 718,800 B against a predicted 720,000 B for ten explicit integer row-names vectors; `.row_names_info()` on an analysis frame now returns −18000 (compact). The phenomenon is unchanged; only row-name storage moved.
- 2026-07-27: T3 — `benchmarks/rsample-283-comment.md` drafted, marked not-posted in its own header. Three source facts re-verified by execution before drafting: `vfold_cv()`'s formals are `v`/`repeats` with `check_dots_empty()` on its first line, `bootstraps()` is the one carrying `times` (and is the landing-page example the issue says it adapted), and `inside_resample()` is two lines whose first is `call_modify(cl, data = as.data.frame(src))`.
- 2026-07-27: T4 — handoff recorded in the milestone-local Decisions section naming rsample#283 as the target, with the comment URL left unfilled; it is appended as a dated work-log line once the maintainer posts, since the Decisions section is history and never edited (IP4).
- 2026-07-27: all four tasks checked; `devtools::test()` clean (FAIL 0 | WARN 0 | SKIP 0 | PASS 1247) and the reprex re-runs clean; status → review. No prose-guard authored, so no fresh-context guard reader is owed.
- 2026-07-27: review — supersedes the T2 amendment line above on one point (history is never edited, IP4): the committed 11.373× anchor is at `tests/testthat/test-nested-resamples-memory.R:86`, not `:87`, which holds the v=50 row. Corrected in the reprex header and the Review section; AC2's own citation is plan-owned and still says `:87`.
- 2026-07-27: review — three lenses, 27 deduped findings, scorer fetched the live issue and refuted two on their premises. Four scored ≥80: F1 (92) and F2 (88) rewrote the draft's fix section, which recommended the `make_splits()` path M01 abandoned; F18 (82) removed an unsound falsification claim; F11 (88) fixed where review is permitted to. 23 logged below threshold, three of them fixed incidentally.
- 2026-07-27: gated amendment (review finding F11, 88) — AC2's provenance citation corrected from `test-nested-resamples-memory.R:87` to `:86`, the line actually holding the 11.373× anchor; `:87` holds the v=50 row (57.458). Substance of the criterion unchanged; the milestone returned to in-progress for the edit because review may not write plan-owned text, and back to review immediately after. User authorized this at the review gate, choosing to fix rather than record the defect.
- 2026-07-27: review findings F5 (76) and F4 (74) fixed at user request despite scoring below the action threshold, because both are verifiably wrong statements about rsample's API inside text addressed to rsample's maintainers: `times` is carried by six exported functions rather than `bootstraps()` alone, and `vfold_cv()`'s formals include `strata`/`breaks`/`pool` beyond `v`/`repeats`. The draft now names `v` as the fold count and `times` as the corresponding argument on the Monte-Carlo and bootstrap family.
- 2026-07-27: implement gate chose `benchmarks/rsample-283-comment.md` as the draft comment's home over the milestone file, because archiving compresses the milestone to ≤25 lines exactly when the maintainer goes to post it; and kept the rsample-side model in the benchmark script only, per Scope Out — a test on an external package's internals would fail this suite for upstream reasons.

## Decisions

- 2026-07-27: **HANDOFF — target https://github.com/tidymodels/rsample/issues/283.** The body to post is `benchmarks/rsample-283-comment.md` below its `---` rule; re-run `benchmarks/rsample-283-reprex.R` first if rsample has moved past 1.3.2, since the comment quotes that version's figures. Posting is the maintainer's act and no script here takes it. **Comment URL: _(unposted as of 2026-07-27; append a dated work-log line recording it once posted)_.**

## Review

### Acceptance criteria — fresh evidence

- **AC1 — met.** `Rscript benchmarks/rsample-283-reprex.R`, run 2026-07-27, prints its own provenance line: R 4.6.1, aarch64-apple-darwin25.4.0, rsample 1.3.2, mlbench 2.1.10, lobstr 1.2.1, seed 35222. Both schemes are built with explicit `vfold_cv(v = )` calls: 10×10 = 33,715,400 B / **12.749×** over 10 outer folds; 5×2 = 13,871,840 B / **5.245×** over 5. The 13× attaches to the former — 12.749× reconciles to the issue's reported 13.020× through the script's drift term (718,800 B measured against 720,000 B predicted for ten explicit row-names vectors) — and cannot attach to the latter, which is less than half of it. The script also records that the issue's own call no longer runs at all under 1.3.2 (`rlib_error_dots_nonempty`, naming `times = 5`).
- **AC2 — met; the model agrees, and the residuals carry the right sign.** `rsample_size()` is recomputed from four explicit terms (shared data; `v` materialized analysis frames; outer analysis indices; inner analysis indices — `out_id` verified `NA` on both split levels), collapsing to `data_bytes*v + 4n(v-1)*inner_v`. Validated at the anchor first: the same run re-measures **11.373×** at v=10/inner-5, reproducing the committed figure at `tests/testthat/test-nested-resamples-memory.R:86` to **+0.00%**, and the model predicts 11.361× there, **−0.10%** against it. Applied to the two reported schemes it gives 12.722× against a measured 12.749× (**−0.20%**) and 5.242× against 5.245× (**−0.06%**). The gap is stated rather than merely small: the model is under every measurement, which is the only direction a storage-only accounting may err — it charges data and index vectors and nothing for the `rsplit` lists and tibbles themselves. A model running *over* would mean the structure holds less than the diagnosis claims. Two independent oracle types back each published figure per GP2: **live** (`lobstr::obj_size()` on a structure rsample builds at run time) and **closed-form** (the arithmetic above, independent of rsample's implementation).
- **AC3 — met, all four clauses located in `benchmarks/rsample-283-comment.md`.** The cause: lines 42–52 quote `inside_resample()`'s body and state that `as.data.frame()` on an `rsplit` materializes the fold's analysis set, leaving `v - 1` extra copies of the dataset. The `times` story: lines 20–24 state `vfold_cv()` has no `times` argument (its arguments are `v` and `repeats`), that `times` belongs to `bootstraps()` — the landing-page example the issue says it adapted — that in 2022 it fell into `...`, and that both levels took `v = 10`; line 25 adds the reprex's own corroboration, `34,434,200 / nrow = 3,443,420` implying a divisor of 10. Current rejection: line 29 names `check_dots_empty()` and lines 31–36 quote the resulting error verbatim. Both schemes' figures: the table at lines 76–79 carries 12.749× and 5.245× with their byte counts. Each source fact was re-verified by execution before drafting, not taken from the tracking record.
- **AC4 — met, with one carry-forward.** The milestone-local `## Decisions` section carries the handoff naming https://github.com/tidymodels/rsample/issues/283 as the target, pointing at the postable body and requiring a re-run if rsample moves past 1.3.2. The URL slot is explicitly unfilled. Carry-forward: that section is history and is never edited (IP4), so the URL arrives as an appended work-log line — and since the milestone is archived at `done` *before* the maintainer posts, the archive summary must carry the handoff forward or the pointer is lost at the moment it is needed.

No `Driving RR:` on this milestone, so the projection-vs-outcome record no-ops.

### Consistency gate

- Universal: `cairn_validate.py` exit 0 — 16 CHECKs PASS, 8 advisories OK. No principle changed, so `cairn_impact.py` was not run.
- CI on PR #18: all checks pass — `R CMD check` on ubuntu (release, devel, oldrel-1), macos and windows; test-coverage; codecov patch and project; pkgdown build (deploy correctly skipped off the default branch).
- Toolchain (`r-package` `consistency-gate` slot): `devtools::check()` **Status: OK** (0 errors, 0 warnings, 0 notes; tests 67s/114s). `devtools::document()` produces no diff. `pkgdown::check_pkgdown()` — "No problems found". No `README.Rmd` in this repo, so the knit check is a clean no-op. No new top-level files: both additions sit under `benchmarks/`, already `.Rbuildignore`d. No `NEWS.md` entry, correctly — the diff touches no package code and nothing user-visible changed.

### Independent fresh-context review

Three lenses (an [O] diff-bug reviewer on the diff, an [S] blame-history reviewer, an [S] prior-review reviewer on the archived `## Review` sections), then an [S] scorer holding the diff and the plan. 27 deduped candidate findings; the blame and prior-review lenses each independently corroborated one of the diff reviewer's. The scorer fetched the live issue and **refuted two findings on their premises**: the reporter does say "I adapted that example" (F6, 22), and the issue does report both 34,434,200 B and 3,443,420 B from executed code rather than back-computing either (F10, 12).

**Actioned — scored ≥80:**

- **F1 (92) — fixed.** The draft's "Scope of the fix" recommended `make_splits()` + `manual_rset()` as reachable "without touching internals", the one actionable sentence in the comment, while linking to this repo as evidence. `R/nested-resamples.R:144-147` records the opposite: rebuilding from scratch drops the split subclass and the per-split `id` tibble that `labels()`/`add_resample_id()` read, and `manual_rset()` drops `id2`; M01's review scored that F2 (85) and F3 (82) and abandoned the path, and `cairn/LESSONS.md:16` is the standing lesson. Section rewritten to describe what the package actually ships — rewriting `data`/`in_id`/`out_id` on rsample's own splits — and to carry the `make_splits()` trap as an explicit caveat.
- **F2 (88) — fixed with F1.** "The resulting splits are row-identical to the current ones" was asserted of a construction never built here; `rsample:::new_manual_rset` hardcodes `subclass = c("manual_rset","rset")`, which `test-nested-resamples-identity.R:101` would fail. Row-identity now attaches to the field-rewriting form, which is what the identity suite actually tests.
- **F18 (82) — fixed.** The script claimed a model running over would falsify the diagnosis. It would not: the data term over-predicts on its own — the ten analysis frames at v=10 measure 23,776,840 B against the term's 23,801,760 B, because `lobstr` charges the shared factor-level strings once — so the net undershoot is a cancellation against the omitted per-object overhead, not a bound. Comment rewritten to say so.
- **F11 (88) — fixed, in two steps.** The GP2 anchor was cited as `test-nested-resamples-memory.R:87`, which holds the v=50 row (57.458); 11.373 is at `:86`. Introduced by this milestone's own AC2 amendment. Review fixed the reprex header and this section directly. AC2's own citation is plan-owned and amend-via-gate — review may not write it — so the milestone returned to `in-progress` for a one-character gated amendment at the user's decision, then straight back to `review`; the work-log records both. The T2 work-log line is history under IP4 and is superseded, never edited, so `:87` still appears there and in this paragraph as description of the error rather than as a live citation.

**Logged, below the action threshold (23 findings).** Three were fixed incidentally by the F1/F2 rewrite, and two more were fixed at the user's explicit direction at the merge gate; all five are marked so.
F3 (78) 3.995× was presented beside a measured 12.749× as like-for-like when it is modelled only — *fixed with F1*. F5 (76) six exported rsample functions take `times`, not only `bootstraps()` — *fixed at user direction*. F4 (74) `vfold_cv()`'s formals also include `strata`/`breaks`/`pool`, so "its arguments are `v` and `repeats`" is incomplete — *fixed at user direction*. F8 (68) an explicit 18,000-integer vector costs 72,048 B, so the row-names hypothesis over-predicts by 1,680 B and the drift's causal claim is firmer than the residual supports. F17 (66) the header's "two independent oracle types back each figure" covers the three size measurements but not the drift figures. F9 (62) 13.020 is the one published figure the reprex does not compute, against a header promising it does. F26 (60) the published term table omits the `v·(v-1)/v` derivation the script carries, and calls itself exhaustive two paragraphs before admitting it omits overhead. F23 (58) `per_fold` is computed and never printed, though it is exactly the quantity the closing note compares against. F25 (58) the drift block hardcodes the 10×10 scheme and builds a third 34 MB object to inspect a frame `measure()` already had. F20 (55) the heading "Scope of the fix" presumed the outcome — *fixed with F1*. F13 (52) `lean_size()` duplicates `analytic_size()` with nothing guarding the pair. F24 (48) "the divisor it used is the outer fold count printed above" does not say which of the three printed. F14 (42) `COMMITTED_10x5` restates a value DESIGN.md says to cite, and crosses seeds (1 vs 35222) — the scorer verified the ratio is seed-invariant. F22 (40) the draft engages none of the issue's three existing comments. F15 (35) nothing runs the reprex automatically — deliberate per Scope Out. F19 (32) the comment leads with the reporter's error rather than the cause. F21 (32) "not ours to answer" under a single-author post — *fixed with F1*. F7 (30) the "fell into `...`" mechanism is inference stated as history. F16 (30) the closed-form model is derived by reading rsample, so "independent of rsample's implementation" overstates it — pre-existing phrasing from M01's O2 oracle record. F27 (28) the row-names drift is new knowledge `cairn/references/tidymodels-nested-cv-gaps.md` does not yet carry. F6 (22) and F10 (12) refuted on their premises. F12 (3) observed the Review section empty before it was written.
