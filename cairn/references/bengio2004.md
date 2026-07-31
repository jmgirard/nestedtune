# bengio2004 — no universally unbiased estimator of the variance of K-fold CV

**Citation.** Bengio, Y., & Grandvalet, Y. (2004). No unbiased estimator of the
variance of K-fold cross-validation. *Journal of Machine Learning Research*, 5,
1089–1105. Dept. IRO, Université de Montréal, and Heudiasyc UMR CNRS 6599,
Université de Technologie de Compiègne. Editor: Dana Ron. Submitted 05/03,
revised 9/03, published 9/04.

**Provenance.** Ingested 2026-07-31 from `sources/bengio2004.pdf` (gitignored),
JMLR PDF, 17 pages. Pagination: PDF page N = journal page 1088 + N.
Extraction: `pdftotext -layout`, full text read; all lemmas, the theorem and
their proofs are text and were read in full. **Figures 1–6 are images and were
not read** — Figures 4, 5 and 6 are the bar plots carrying the experimental
variance decompositions, so the numeric claims in §7 below come from the prose
only, and the figures hold values this note does not have — observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## What it establishes

**Setup.** n points, K folds, block size m = n/K, per-point cross-validation
errors e_i, and μ̂ = (1/n) Σ e_i standing for the K-fold CV estimate, the paired
difference ΔCV between two algorithms, or the jackknife JK (§2.5, p. 1094). The
estimand is EPE(n − m), the expected prediction error at the *reduced* training
size: "the outer average of (3) estimates unbiasedly EPE(n − m)" (§2.3,
p. 1093).

**Result 1 — the covariance matrix has exactly three distinct entries.**
Lemma 1 and Corollary 2 (pp. 1095–1096), from permutation symmetry of the data
distribution and of the algorithm: every diagonal entry equals σ², every
off-diagonal entry *within* a test block equals ω, and every entry *across*
blocks equals γ. Corollary 3 (p. 1096) then gives the whole variance as

> θ = Var[μ̂] = (1/n)σ² + ((m−1)/n)ω + ((n−m)/n)γ.

The interpretation the paper attaches (p. 1096): σ² is the within-training-set
error variance for training sets of size m(K−1); ω arises because test errors in
one block share a training set; γ arises because the K training sets overlap in
n(K−2)/K points *and* because block T_k appears inside every other block's
training set.

**Result 2 — the main theorem.** Theorem 6, p. 1098: **there exists no
universally unbiased estimator of Var[μ̂]**, where "universal" means valid under
all distributions of the errors. The proof is two steps. Lemma 4 (p. 1097): any
unbiased estimator must be purely quadratic in the e_i, since θ involves only
second moments. Lemma 5 (p. 1097): the expectation of any quadratic form
e′We is a(σ²+μ²) + b(ω+μ²) + c(γ+μ²) with a, b, c the sums of W's diagonal,
within-block and between-block entries. Matching that to θ for all admissible
(μ, σ², ω, γ) forces the system

> a = 1/n, b = (m−1)/n, c = (n−m)/n, **and** a + b + c = 0,

which has no solution: the first three are non-negative and sum to 1, not 0
(eq. 14, p. 1098). The last equation is what kills it — it comes from the µ²
terms, which have no counterpart in θ.

**Result 3 — why, geometrically, and why repetition does not help.** §5,
pp. 1099. The eigen-decomposition of Σ has three eigenvalues: λ₁ = σ² − ω with
multiplicity n − K; λ₂ = σ² + (m−1)ω − mγ with multiplicity K − 1; and
λ₃ = σ² + (m−1)ω + (n−m)γ with the single eigenvector **1**. Since μ̂ *is* the
projection of e on that eigenvector, Var[μ̂] = λ₃/n, and one run of CV yields
exactly one realization along it — a sample of size one, whose sample variance
is zero. Only λ₁ and λ₂ can be estimated unbiasedly. The sentence that matters
most here (p. 1099):

> "Note that this problem cannot be addressed by performing multiple K-fold
> splits of the data set. Such a procedure would not provide independent
> realizations of e."

The paper adds that even a Gaussian parametric assumption does not rescue it —
"the maximum likelihood estimate of θ is not defined".

**Result 4 — the naive estimator's bias is of the order of the variance
itself.** §6 bounds what is left to hope for: for μ̂ = CV and μ̂ = ΔCV,
0 ≤ ω ≤ σ² and −(1/(n−m))(σ²+(m−1)ω) ≤ γ ≤ (1/m)(σ²+(m−1)ω) (Lemma 8, p. 1100).
The admissible region "is very large ... Hence we cannot propose a variance
estimate with universally small bias." §7 then measures the three components:
with outliers present, "the contribution of γ is of same order as the one of σ²,
even when the ratio of examples to free parameters is large (here up to 20).
Thus, in difficult situations, where A(D) varies according to the realization of
D, neglecting the effect of ω and γ can be expected to introduce a bias of the
order of the true variance" (p. 1101). On real data (Experiment 3, the UCI
*Letter* set collapsed to two classes, 20,000 examples as the population,
K = 10): "σ² is only responsible for 50 to 70 % of the total variance, so that a
variance estimate based solely on σ² has a negative bias of the order of
magnitude of the variance itself" (p. 1102).

**Result 5 — two special cases.** §8.1: with K *independent* train/test splits
γ = 0, which deletes the third equation from (14) and *does* admit an unbiased
estimator — this is why hold-out is different in kind, not merely in degree.
§8.3: leave-one-out is not an escape either; with m = 1, b = 0 and the system
reduces to a = 1/n, c = (n−1)/n, a + c = 0, "which still admits no solution".
§8.2 notes 2-fold CV has non-null γ despite disjoint training blocks, because
each block's training set is the other's test set.

## Extracted values

The paper's experiments are variance decompositions plotted as bar charts
(Figs 4–6, unread). Two numeric statements survive in prose and are recorded
above: the outlier-case claim that γ's contribution is of the same order as σ²
at up to 20 examples per free parameter (p. 1101), and the *Letter* result that
σ² accounts for 50–70% of total variance (p. 1102). Experimental setup
(Experiments 1–2, pp. 1091, 1101): d = 30 inputs, y = √(3/d) Σ_k x_k + ε giving
R² ≈ 3/4, OLS as the learning algorithm, K = 10; the outlier variant mixes
N(0, I) with N(0, 100I) at p = 0.95. Experiment 3: *Letter*, 20,000 examples, 16
features, classes A–M versus N–Z, trees, K = 10.

## Bearing on nestedtune

- **This is the theorem under the G6 caveat, and it is stronger than the shape
  the caveat has been assuming.** `R/nested-results.R:213-217` computes
  `std_err` as `sd(vals)/sqrt(length(vals))` over the per-outer-fold estimates.
  Two things follow. First, the independent-errors assumption behind that
  formula is exactly what Corollary 3 refutes: the true variance carries ω and
  γ terms that a sum of squared deviations cannot recover. Second — and this is
  the part `bates2023.md` does not say — §5 forecloses the obvious remedy.
  Repeating the outer CV under different splits and taking a spread across
  repetitions does not produce independent realizations, so it does not fix the
  estimate. Any G6 caveat that says "repeat the outer loop if you want a
  spread" would be contradicted here.
- **A precision on `bates2023.md`.** That note glosses this paper as proving "no
  unbiased estimator of that variance exists from a single run of CV". The
  theorem is stronger and differently qualified: no **universally** unbiased
  estimator exists (unbiasedness under *all* distributions is what fails, and a
  distribution-specific estimator is not excluded), and the obstruction is not
  the single run per se — §5 says extra runs do not help either.
- **A caution about what our `std_err` even is.** The paper's μ̂ averages n
  per-point errors; nestedtune's `std_err` is a standard error over V *fold
  means* of a metric that may not be an average of per-point losses at all
  (`roc_auc` is not). So this theorem does not apply to our column verbatim —
  it applies to the quantity our column is mistaken for. That distinction is
  already the second open question on `bates2023.md`, and it is unresolved.
- **Support for GP5.** §6's admissible region for (ω, γ) is wide enough that no
  correction with universally small bias exists. The package cannot ship one.
- **The reason hold-out is genuinely different.** §8.1 explains why a package
  that estimates on an independent test set may quote a standard error while one
  that cross-validates may not. That is worth a sentence wherever nestedtune's
  output is compared with `last_fit()`'s.

## Oracle status

**No oracle.** The result is a non-existence theorem; there is no value to pin.
It has the opposite use — it is the citation that forbids a certain class of
test from ever being written, because any variance estimator nestedtune shipped
could be shown biased under some distribution by construction.

## Open questions

- Whether the three-value covariance structure survives when the algorithm A
  includes an inner tuning loop. Lemma 1 needs only permutation-invariance of P
  and symmetry of A, and a tune-then-fit procedure is symmetric in its training
  points, so the structure plausibly carries — but the paper never considers it
  and this note asserts nothing. Unverified as of 2026-07-31.
- What the actual decomposition looks like for a metric that is not a mean of
  per-point losses. Every step from Lemma 1 onward is written for μ̂ as an
  average of e_i; `roc_auc` and any other rank-based metric is not of that form.
  Unaddressed by the paper — observed 2026-07-31.
- The magnitudes in Figures 4–6, unread. They are the only quantification of how
  the three components trade off against K, and §7's claim that "there is no
  general trend either in variance or decomposition of the variance" rests on
  them — observed 2026-07-31.
