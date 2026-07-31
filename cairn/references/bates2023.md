# bates2023 — what CV estimates, and why its naive interval under-covers

**Citation.** Bates, S., Hastie, T., & Tibshirani, R. (2023). Cross-Validation:
What Does It Estimate and How Well Does It Do It? *Journal of the American
Statistical Association*, 2023, 1–12. doi:10.1080/01621459.2023.2197686.
Received August 2021, accepted February 2023. Experiment scripts at
https://github.com/stephenbates19/nestedcv_experiments.

**Provenance.** Ingested 2026-07-31 from `sources/bates2023.pdf` (gitignored),
publisher PDF, 12 pages.
Pagination: PDF page N = article page N, so anchors below are both.
Extraction: `pdftotext -layout`, full text read. Figures 1–10 are images and were
**not** read; every figure claim below comes from its caption or the prose.
The Supplementary Appendices (A–I, where the bootstrap results, the proofs,
Algorithm 1, and the bias-correction derivation live) were **not** retrieved —
observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology warning, read this first

**"Nested cross-validation" in this paper is not what it means in this
package.** Bates et al.'s NCV (§4.3, p. 8, Figure 7) is a *variance-estimation*
device: repeatedly split off a fresh holdout fold, run ordinary CV on the rest,
and compare the inner CV estimate against the holdout error to estimate the MSE
of the CV point estimate. There is no hyperparameter tuning in the inner loop.
nestedtune's nested CV — inner loop tunes, outer loop scores — is the
Stone/Varma–Simon construct that `krstajic2014.md` names, and the two share only
a name. Three of this shelf's four sources use the term for three different
procedures; see also `zhong2020.md`.

## What it establishes

**Result 1 — CV estimates the average error, not your model's error.**
Three estimands (§3, p. 3–4): Err<sub>XY</sub>, the error of the model fit on
the data at hand; Err = E[Err<sub>XY</sub>], the average over training sets; and
Err<sub>X</sub> = E[Err<sub>XY</sub> | X] in between.

- Theorem 1 (p. 4): under the homoscedastic Gaussian linear model with
  squared-error loss, any *linearly invariant* estimator of prediction error is
  conditionally independent of the true error given X. CV with OLS is such an
  estimator (Lemma 1, p. 4). The proof is two lines: OLS residuals are
  independent of the fitted coefficients, and a linearly invariant estimator is
  a function of the residuals alone.
- Theorem 2 (p. 5): in the proportional limit (n > p, n, p → ∞, n/p → λ > 1),
  E<sub>X</sub>[var(Err<sub>XY</sub>|X)] = Θ(1/n) while var(Err<sub>X</sub>) =
  Θ(1/n²) — so variation from Y|X dominates variation from X.
- Corollaries 2–3 (p. 5): cor(Err<sub>XY</sub>, Êrr) → 0, and the MSE penalty
  for targeting Err<sub>XY</sub> instead of Err is Θ(1/n).
- §3.4–3.6 (p. 6–7): the same conclusions carry to data splitting, Mallows
  C<sub>p</sub> (Lemma 2, p. 7), and the bootstrap, because all are linearly
  invariant. Under regularization the picture softens — §7, p. 11 reports CV
  does track Err<sub>XY</sub> weakly when a penalty is present.

**Result 2 — naive CV intervals under-cover, and the cause is structural.**
The motivating example (§1.1, p. 1): n = 90, p = 1000, 4 equal nonzero
coefficients, Bayes misclassification 20%, ℓ1-penalized logistic regression at a
fixed penalty. A nominal 10% miscoverage interval misses **31%** of the time;
the intervals need widening by a factor of about **1.6**.

The cause is that the per-point errors e<sub>i</sub> are not independent — each
point is used for both training and testing, giving the block covariance
structure of Figure 6 (p. 7). So se = sd(e)/√n is too small. Bengio & Grandvalet
(2004), cited p. 2, prove no unbiased estimator of that variance exists from a
single run of CV, which is why fixing it requires changing the procedure.

**Result 3 — their NCV, and its cost.** Lemma 3 (p. 8) decomposes the MSE of any
prediction-error estimate into two terms that are each estimable from a
train/holdout split; the estimator (p. 8) uses (K−1)-fold CV inside and averages
over many random splits. Theorem 3 (p. 8): E[MSê<sup>(NCV)</sup>] =
MSE<sub>K−1,n′</sub> with n′ = n(K−1)/K, so they recommend rescaling by
(K−1)/K, and clamping MSê between se and √K·se.

Cost, stated plainly (p. 11): about **1000× more model fits** than standard CV,
≈10 s for the §1.1 example on a personal computer.

## Extracted values

All experiments use K = 10 and 200 random splits for NCV; nominal miscoverage
10% (5% per tail); "Hi"/"Lo" are the two tails.

| Where | Setting | CV miscoverage | NCV | Data splitting | NCV width |
|---|---|---|---|---|---|
| Table 1, p. 9 | logistic, n=100, p=20, Bayes 33.2%, target Err<sub>XY</sub> | 10% / 8% | 3% / 5% | 7% / 6% | 1.23× (DS 2.23×) |
| Table 1, p. 9 | same, Bayes 22.5% | 11% / 3% | 4% / 1% | 16% / 4% | 1.47× (DS 2.25×) |
| Table 2, p. 10 | sparse logistic, n=90, p=1000, ρ=0 | 16% / 12% | 6% / 7% | 9% / 7% | 1.53× |
| Table 2, p. 10 | n=200, p=1000, ρ=0 | 14% / 7% | 3% / 5% | 9% / 4% | 1.66× |
| Table 2, p. 10 | n=90, p=1000, ρ=0.5 | 20% / 10% | 5% / 8% | 15% / 4% | 1.80× |
| Table 3, p. 11 | UCI *Communities and crimes*, n=50 | 4% / 20% | 1% / 13% | 1% / 33% | 2.82× |
| Table 3, p. 11 | UCI *Crop mapping*, n=100 | 6% / 6% | 4% / 5% | 4% / 15% | 1.52× |

Standard error on each reported coverage estimate ≈ 0.5% (Table 1 note, p. 9).
§7, p. 11 adds the calibration point: even at n/p = 10 in a plain linear model,
CV's miscoverage ran about 50% above nominal, shrinking as n grows.

One further practical finding, from the abstract and §3.4: with simple data
splitting, **do not refit on the combined data** if you want the interval to
remain valid.

## Bearing on nestedtune

- **This is the source the G6 candidate was waiting for — partly.** The ROADMAP
  candidate "Variance estimation / inference on the nested estimate" is parked
  for want of oracle-grade literature support, and absorbs M02 review finding
  F5: `collect_metrics()` ships a `std_err` with no caveat. That column is
  computed at `R/nested-results.R:213-217` as `sd(vals)/sqrt(length(vals))`
  across outer folds — precisely the independent-errors formula this paper shows
  is too small, for precisely the reason it gives (fold errors are correlated
  because every row trains and tests). The finding is squarely on point even
  though the construct differs: our folds share training data the same way.
  What it licenses is a **documented caveat**, not an interval — GP5 still says
  don't ship inference the literature hasn't settled, and this paper's remedy is
  for a different loop.
- **External support for IP3.** "The estimate describes the procedure, never the
  shipped model" is, in this paper's vocabulary, the claim that CV estimates Err
  rather than Err<sub>XY</sub> — proved for the linear model (Theorem 1,
  Corollary 3) and shown in simulation for logistic regression (Figure 8, p. 10).
  IP3 was elicited, not derived from this; the paper is corroboration a doc page
  can cite.
- **A caution on borrowing their NCV.** Their scheme is not a drop-in: it
  estimates the MSE of a *CV point estimate*, and our outer loop's estimate is
  already an average over folds whose inner loops tuned. Whether Lemma 3's
  identity survives an inner tuning step is not addressed anywhere in the paper.
  At ~1000× the fits it would also collide with GP4.
- Their `nestedcv_experiments` repo is R and is the closest thing on this shelf
  to a reference implementation, if the variance question is ever planned.

## Oracle status

**No oracle today.** The coverage tables are Monte-Carlo properties of
procedures, not values a nestedtune test could pin. The one plausible future
use is as an oracle *type* rather than a value: if the variance candidate is
ever planned, the GitHub scripts are an independent reference implementation,
which is one of the ≥2 types GP2 requires. Recorded, not claimed.

## Open questions

- Whether the holdout MSE identity (Lemma 3, p. 8) still holds when the inner
  procedure includes hyperparameter tuning, which is the case this package
  produces — the paper never considers it; the proof is in Supplementary
  Appendix D, unread — observed 2026-07-31.
- What the naive `std_err` on `collect_metrics()` actually does across outer
  folds in this package — the paper's under-coverage is measured for CV over
  points, ours is an SE over V fold means, and the two are not the same
  statistic. Unmeasured as of 2026-07-31; this is the first thing to measure if
  the G6 candidate is promoted.
- Whether regularization changes the picture enough to matter for tidymodels
  users, most of whom tune a penalty — §7 (p. 11) reports only that CV tracks
  Err<sub>XY</sub> "albeit weakly" under regularization, with the experiment in
  Supplementary Appendix F.10, unread — observed 2026-07-31.
