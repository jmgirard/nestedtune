# wilimitis2023 — the honest null result: on n ≫ p clinical data with a small grid, nesting bought nothing and cost O(k²)

**Citation.** Wilimitis, D., & Walsh, C. G. (2023). Practical considerations
and applied examples of cross-validation for model development and evaluation
in health care: Tutorial. *JMIR AI*, 2, e49023. doi:10.2196/49023. Vanderbilt
University Medical Center. Open Access.

**Provenance.** Ingested 2026-07-31 from `sources/wilimitis2023.pdf`
(gitignored), publisher PDF, 16 pages.
Pagination: PDF page N = article page N (the journal's own "p. N" footers; the
article body runs pp. 1–14, references follow).
Extraction: `pdftotext -layout`, full text read. Table 1 (pp. 7–8) extracted
cleanly. **Figures 1–12 are images and were not read** — Figures 3–12 hold
every optimism and timing curve, so the numbers below come from the prose,
which fortunately states most of them. Multimedia Appendix 1 (a separate DOCX
listing CV types) is not on the shelf — observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology note

**"Nested CV" here is ours.** Five-fold outer; all hyper-parameter tuning,
feature selection and algorithm choice happen inside the inner loop (p. 4).
The tutorial also introduces two axes this shelf has not carried before:

- **Subject-wise versus record-wise CV** (p. 3) — whether one person's several
  records may straddle the split. Subject-wise is `rsample::group_vfold_cv()`.
- **Pooling versus averaging** (p. 3) — for AUROC/AUPR, either average the
  curve across test folds point-by-point (*pooling*) or average the per-fold
  scalar metric (*averaging*). nestedtune's `collect_metrics()` averages.

## What it establishes

**Result 1 — a real-data case where nesting changed almost nothing.** On
MIMIC-III in-hospital mortality (41,121 visits, 10.51% prevalence, 5 folds),
nested CV scored *marginally worse* than every non-nested method: AUPR 0.369
against 0.371–0.372, AUROC 0.814 against 0.818–0.821 (p. 8). On length of stay
the same: mean absolute error 2.39 nested against 2.38 non-nested, median
absolute error 1.23 for every method (p. 11).

**Result 2 — against a real holdout, all the CV estimates were *pessimistic*,
and the nested one most of all.** Splitting 80/20 (32,897 / 8,224) and
comparing each CV estimate against the refit model's score on the held-out 20%,
the ratio of holdout to CV performance exceeded 1 throughout (p. 8). Nested CV
and repeated k-fold were the most pessimistic — about 1–2% for AUROC and 5–9%
for AUPR — and plain k-fold the least. Repeating over 10 randomly drawn
validation sets, the extremes ran from 8% optimistic (AUPR, nested) to 10%
pessimistic (AUPR, all non-nested) (p. 8).

This is the same direction as `varma2006.md`'s +4.2-point residual and the same
N − 1 mechanism `arlot2010.md` §5.1.1 names, now visible on 41k real rows
rather than 40 simulated ones.

**Result 3 — the authors diagnose their own null result, correctly.** Two
reasons are given (p. 13): the study is squarely n ≫ p, and the tuning grid was
deliberately smaller than a real developer's. Both are exactly the conditions
under which `tibshirani2009.md` (bias material only at p ≫ n) and
`varma2006.md` eq. (8) (selection bias grows with the number of candidates)
predict that nesting has little to remove. **The null result is therefore
consistent with the rest of the shelf rather than contrary to it** — a fact the
paper states about itself rather than leaving to the reader.

**Result 4 — cost scales quadratically in the fold count.** Measured wall-clock
by method and number of folds (Figs 8 and 12, unread; claim from prose,
pp. 10 and 12): nested CV grows as O(k²), repeated CV as O(k), and simple CV
"nearly constant" as O(c). Both prediction problems show the same shape.

**Result 5 — their recommendation is conditional, not against nesting.**
They advise nested CV where the feature space is high-dimensional relative to
n, where many algorithms and parameters are being searched, and where the time
cost is bearable (p. 13). For their own case study they conclude the opposite —
that the bias reduction did not justify the cost (p. 13).

**Result 6 — subject-wise versus record-wise made no measurable difference
here.** Attributed to few repeat visits per subject and weak within-subject
correlation across visits (p. 12); presented as a property of this cohort, not
a general finding.

## Extracted values

Cohort (pp. 6–8): 41,121 hospital visits, MIMIC-III, ICU at Beth Israel
Deaconess, 2001–2012. 71.63% White (29,457), 55.92% male (22,996); mortality
4,320 (10.51%). Mean age 68.7 (SD 15.0) with mortality versus 61.6 (SD 16.7)
without.

Models (p. 4): mortality = logistic regression, grid over L1 / L2 / no penalty
and a range of regularization strengths, top-10 features selected. Length of
stay = random forest regression, grid over tree count and maximum depth, with
the feature count (30 or 50) treated as a hyper-parameter. Preprocessing:
median imputation, age capped at 110, standardization.

Mortality, 5 folds (p. 8):

| Method | AUPR | AUROC |
|---|---|---|
| Nested CV | 0.369 | 0.814 |
| All non-nested (K-fold, stratified, repeated, repeated stratified) | 0.371–0.372 | 0.818–0.821 |
| 0.632 bootstrap, 100 iterations | 0.368 (95% CI 0.351–0.382) | 0.819 (95% CI 0.813–0.825) |
| Out-of-bag bootstrap | 0.367 (95% CI 0.346–0.390) | 0.818 (95% CI 0.796–0.828) |

Length of stay, 5 folds (p. 11):

| Method | Mean abs. error | Median abs. error |
|---|---|---|
| Nested CV | 2.39 | 1.23 |
| Non-nested methods | 2.38 | 1.23 |
| 0.632 bootstrap | 2.01 (95% CI 1.98–2.04) | 1.05 (95% CI 1.03–1.07) |
| Out-of-bag bootstrap | 2.84 (95% CI 2.79–2.90) | 1.53 (95% CI 1.49–1.55) |

Bias against the holdout, by metric (pp. 8, 11–12): AUROC 1–2% pessimistic for
nested and repeated k-fold; AUPR 5–9% pessimistic for the same; median absolute
error under 2% pessimistic for all methods, worst at k = 2, least biased for
nested; mean absolute error roughly ±1%, with nested pessimistic at every fold
count and k-fold slightly optimistic.

Textbox 1, p. 4 — the tutorial's seven steps, annotated by whether each belongs
inside the loop: (1) data cleaning and type/encoding work — **outside**;
(2) scaling and imputation — inside; (3) feature selection — inside; (4)
algorithm comparison — inside; (5) hyper-parameter optimization — inside;
(6) evaluation, kept separate from selection; (7) refit a final model on all
data using the settings selection chose.

**One internal disagreement, recorded.** Textbox 1 numbers both step 4 and
step 5 as "Model selection (within the loop)"; from their bodies, step 4 is
algorithm comparison and step 5 is hyper-parameter optimization. The label is
duplicated, not the content.

Code: reproducible Jupyter notebooks and Python are cited as an open-source
repository (reference [15]); the URL is in the reference list, which was read
only far enough to confirm the citation exists. Not retrieved — observed
2026-07-31.

## Bearing on nestedtune

- **This is the shelf's counterweight, and it should be kept as one.**
  `varma2006.md`, `ambroise2002.md` and `vabalas2019a.md` all measure large
  gains from nesting on wide, small, or noise-only data. This paper measures a
  gain of roughly zero on a tall, real, modestly-tuned clinical dataset — and
  correctly explains why. Any documentation claim that nesting always matters
  is refutable by a source already on this shelf.
- **It gives the audience guidance a concrete form.** DESIGN names applied
  analysts who know nested CV is right but not its details. Result 5 is a
  citable, published statement of *when* it is right: wide data, big searches,
  affordable compute. That is a better vignette paragraph than an unconditional
  argument, and it is honest about the case where a user should not bother.
- **Result 4 is a cost model the package can be measured against.** O(k²) in
  the fold count is the naive expectation for a nested loop where the inner
  fold count tracks the outer one. nestedtune's outer and inner counts are
  independent, so the package's own scaling should be O(v_outer × v_inner);
  whether the benchmarks bear that out is a measurement, not a claim this page
  can make.
- **Result 2 hardens a documentation obligation IP3 already carries.** Two
  independent sources — this one on 41k real rows, `varma2006.md` on 40
  simulated ones — now say the nested estimate runs *pessimistic* relative to a
  model refit on everything. A user comparing `nested_tune_grid()`'s number
  against a deployed model's holdout score should expect the nested number to
  be the lower one, and the docs IP3 obliges should say so with both citations.
- **External support for IP3 and D-014.** The tutorial's closing section
  (pp. 13–14) names as a fundamental misconception the belief that CV returns a
  deployable model, and prescribes a separate refit on all data with the
  selected settings — which is `nested_final_fit()` (`R/nested-final-fit.R`)
  and precisely why it is a separate object that answers none of tune's ranking
  generics.
- **Textbox 1 item 1 marks a boundary the package does not police, and cannot.**
  Cleaning and encoding are placed *outside* the loop by the tutorial's own
  advice. That is a defensible line — but it is the same line
  `vabalas2019a.md` shows can be crossed invisibly, and nestedtune sees only
  what arrives in `data`. Worth a documentation sentence, not a check.
- **Subject-wise CV is already reachable.** `nested_resamples()` accepts
  `rsample::group_vfold_cv()` for either level, and `tests/testthat/
  test-nested-resamples-specs.R` (AC5) asserts both that a grouped inner spec
  matches `rsample::nested_cv()` and that no group straddles an inner split.
  Result 6 is therefore a caveat about when grouping matters, not a gap.
- **Nothing for G6.** Every interval in the paper is a bootstrap CI over
  resamples of a *non-nested* procedure; no interval is offered for the nested
  estimate.

## Oracle status

**No oracle. Deliberately not one, and worth saying why.**

The numbers are real-data point estimates with no ground truth: the 20% holdout
is a stand-in the authors describe as simulating ground truth in the absence of
a natural one, so agreement with it is evidence about optimism, not a value any
implementation must reproduce. There is no invariant here — the true AUROC of
logistic regression on MIMIC-III mortality is unknown and unknowable.

The MIMIC-III data are credentialed-access (PhysioNet data use agreement), so
even the reproducible-notebook path is not a fixture this package could ship.
GP2 type (2) would require running their notebooks against a nestedtune port,
which is a research exercise, not a test.

## Open questions

- Whether nestedtune's own scaling matches Result 4's O(k²) shape when outer
  and inner fold counts move together. Not benchmarked in that configuration —
  observed 2026-07-31.
- What the optimism curves in Figs 4–7 and 10–11 actually look like across fold
  counts. The prose gives endpoints and directions only; the figures were not
  read — observed 2026-07-31.
- Whether the pooling-versus-averaging choice (p. 3) changes the nested
  estimate materially for AUROC. nestedtune averages per-fold metrics; the
  paper names the alternative but never compares them — observed 2026-07-31.
- Whether their published notebooks implement the outer loop in a way worth
  comparing against `nested_tune_grid()`. Repository cited but not retrieved —
  observed 2026-07-31.
