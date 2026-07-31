# varma2006 — the package's premise, measured: tuned-CV error is biased, nested CV is not

**Citation.** Varma, S., & Simon, R. (2006). Bias in error estimation when using
cross-validation for model selection. *BMC Bioinformatics*, 7:91.
doi:10.1186/1471-2105-7-91. Biometric Research Branch, National Cancer
Institute, Bethesda MD. Received 28 April 2005, accepted and published 23
February 2006. Open Access (CC-BY 2.0).

**Provenance.** Ingested 2026-07-31 from `sources/varma2006.pdf` (gitignored),
publisher PDF, 8 pages.
Pagination: PDF page N = article page N (the PDF's own "Page N of 8" footers).
Extraction: `pdftotext -layout`, full text read. Table 1 (p. 6) extracted
cleanly and is reproduced below. **Figures 1–4 are images and were not read**;
every figure claim below comes from its caption or the surrounding prose —
observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology note

**This is the one source on the shelf whose "nested CV" is exactly ours.**
Inner loop tunes, outer loop scores, the tuning repeated inside every outer
fold: "there are two CV loops; the inner loop is part of the wrapper algorithm
and the outer loop computes an estimate of the true error" (p. 3). Compare
`bates2023.md` (variance estimation, no tuning) and `zhong2020.md` (feature
selection) for the two other things the phrase is used for on this shelf.

## What it establishes

**Result 1 — tuning by CV and then reporting that CV number is biased, and the
bias is large.** The argument (p. 2): CV is unbiased for the error of a
*classifier training algorithm* only if every step of that algorithm runs inside
the loop. Choosing the hyper-parameter that minimizes a CV estimate is a step of
the algorithm. Doing it outside the loop voids the guarantee. Measured on
deliberately null data — 6000 features, no differential expression, so the true
error is 50% by construction — the optimized classifier's own CV estimate
averages 37.8% (shrunken centroids) and 41.7% (SVM). See the table below.

**Result 2 — nesting removes almost all of it.** Re-running the whole wrapper
inside a leave-one-out outer loop gives a mean nested estimate of 54.2% against
a 50.0% truth for shrunken centroids on null data (p. 6), and 35.3% against
32.0% for the SVM on non-null data (p. 6). Both residuals are *upward*, and the
paper attributes both to training-set size: "the classifier used in each nested
CV iteration is based on 39 samples, while the classifier used on the test set
is trained on 40 samples" (p. 6). Same fact as `stone1974.md`'s N − 1 and
`arlot2010.md` §5.1.1.

**Result 3 — the mechanism, and why it generalizes.** The bias decomposes
(p. 7) into an **inherent bias** — from training on a subset, either sign — and
a **parameter selection bias**, which "is always negative". They add: the
parameter selection bias is smaller for lower-variance resampling methods
(.632 bootstrap, bootstrap CV), but those can carry a large inherent bias, so
the total is what matters. The intuition (p. 7): if the true error E does not
depend on α at all, and the resampling estimate is median-unbiased, then taking
the minimum over K candidate values gives

> Pr(min{e₂, …, e_k} < E) = 1 − (1/2)^K

so "for large K, there is a high probability that choosing the minimum resampled
error will give a biased estimate of the true error". *(Recorded as printed,
eq. 8, p. 7, including its index mismatch: the set is written {e₂, …, e_k} while
the exponent is K.)* Because the cause is the variance of the selection
criterion rather than any property of a particular scheme, they call it "a
general phenomenon" across CV schemes (p. 7).

## Extracted values

Design (pp. 4–5): at least 1000 simulated sets of 40 samples (20 per class),
6000 synthetic gene expressions; independent test set of 20,000 samples. "Null"
= no gene differentially expressed, so true error 50%. "Non-null" = 10 of 6000
genes with population mean difference 1, unit variance. Shrunken centroids: ∆
searched over [0.01, 1], 10-fold CV, ties broken toward the larger ∆. SVM: fixed
Gaussian kernel, top 3 features by |t|, C over 2⁻⁵…2¹⁵ and γ over 2⁻¹⁵…2³,
LOOCV. Nested runs use LOOCV outside and the same wrapper (10-fold or LOOCV)
inside, on 39 samples.

Table 1, p. 6 — no nesting, "null" data (true error 50.0%):

| Classifier | Training error < 30% | Bias > 20% | Mean CV error of optimized classifier | Mean true error | Mean bias |
|---|---|---|---|---|---|
| Shrunken centroids | 18.5% | 22.2% | 37.8% | 50.0% | −12.2% |
| SVM | 22.2% | 25.3% | 41.7% | 50.0% | −8.3% |

Nested results, from the prose (p. 6; the distributions themselves are Figs 3–4,
unread):

| Setting | Mean nested CV estimate | Mean true error | Residual |
|---|---|---|---|
| Shrunken centroids, "null" | 54.2% | 50.0% | +4.2 |
| SVM, "non-null" | 35.3% | 32.0% | +3.3 |

**One internal disagreement, recorded.** The Abstract (p. 1) states "For SVM
with optimal parameters the estimated error rate was less than 30% on 38% of
'null' data-sets"; Table 1 (p. 6) gives 22.2% for that same quantity. The
shrunken-centroid figure agrees across both (18.5%). Table 1 is internally
consistent — both its bias columns equal (mean CV error − mean true error) to
the digit — so the 38% is the unreconciled number. Neither value is used above
except as printed.

## Bearing on nestedtune

- **This is the source for why the package exists.** Its conclusion (p. 1) is
  the package's premise in one sentence: "Proper use of CV for estimating true
  error of a classifier developed using a well defined algorithm requires that
  all steps of the algorithm, including classifier parameter tuning, be repeated
  in each CV loop." That is IP1 (nothing upstream of an outer assessment set's
  scoring may have seen it) and the reason G2's orchestration is worth
  automating rather than leaving to a how-to article.
- **External support for IP3.** The estimand throughout is the error of a
  *classifier training algorithm* — "an algorithm that takes a dataset and
  returns a single, well defined classifier" (p. 3) — never of one fitted
  classifier. The nested estimate describes the wrapper. Same claim as
  `bates2023.md`'s Err-versus-Err_XY, reached from the applied side.
- **The strongest oracle-shaped experiment on the shelf.** See Oracle status.
- **The residual is upward, and that is worth documenting.** Both nested
  results overshoot by 3–4 percentage points on 40 samples, purely from the
  39-versus-40 training size. A user comparing a nestedtune estimate against a
  final model trained on everything should expect the estimate to be slightly
  pessimistic, and the size of that offset scales with how small the folds are.
  This belongs in the same doc paragraph IP3 already obliges.
- **Bears on G6 only obliquely.** The paper measures bias, never variance, and
  reports no interval. Its eq. (8) does say something G6 will need — the
  selection bias grows with the number of candidates K — which means a
  `collect_metrics()` caveat about the naive `std_err` cannot be written as
  though grid size were irrelevant.

## Oracle status

**No oracle value, but the clearest oracle *design* on this shelf.** The null-
data construction is a published, citable invariant: on data where the features
carry no information about the class, a correctly nested estimate must sit at
chance (here 50%, or slightly above it from the N − 1 effect), while the
optimized-then-reported CV estimate sits well below. `ambroise2002.md` reaches
the same invariant from permuted labels and reports 0.40–0.45 against ≈0.

That is GP2 oracle type (4), an invariant test, and the published numbers above
make it arguably type (2) as well. What it costs is the obstacle: the property
is distributional, so a test would need many replicates of a 40×6000 fixture to
separate 54.2% from 37.8% with confidence, which collides with GP4 on suite
runtime. Recorded as a candidate shape, not claimed as a fixture, and not
planned — the sizing question below is unanswered.

## Open questions

- How few replicates and how small a null fixture still separate a nested
  estimate from a naive tuned-CV estimate with acceptable flake risk. Unmeasured
  as of 2026-07-31; this is the question that decides whether the null-data
  invariant is affordable as a test or only as a documented argument.
- Whether the abstract's 38% or Table 1's 22.2% is the correct SVM figure. The
  paper gives no third statement of it, and Figure 2 — which would show the
  distribution — was not read — observed 2026-07-31.
- Whether the parameter-selection bias behaves the same for a continuous tuning
  parameter as for the discrete grid eq. (8) assumes. The paper's SVM search is
  a grid, its shrunken-centroid search is over a continuum discretized in
  practice, and it never separates the two — observed 2026-07-31.
