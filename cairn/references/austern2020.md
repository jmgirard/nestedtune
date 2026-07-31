# austern2020 — two estimands, two asymptotic variances, and a speed-up that depends on the data

**Citation.** Austern, M., & Zhou, W. (2020). Asymptotics of cross-validation.
arXiv:2001.11111v2 [math.ST], 27 June 2020. Microsoft Research and Columbia
University.

**Provenance.** Ingested 2026-07-31 from `sources/austern2020.pdf` (gitignored),
arXiv preprint, 62 pages — the full version, proofs included (§5 runs pp. 20–62).
Pagination: PDF page N = document page N.
Extraction: `pdftotext -layout`. §§1–4 read in full; §5's proofs were **not**
read beyond locating the simulation details in §5.7.2. Tables 1 and 3 extracted
cleanly and are reproduced below. No figures in the paper. This is a preprint;
whether a later peer-reviewed version differs is unchecked — observed
2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology warning, read this first

**No nesting, no tuning.** As with `bayle2020.md`, the algorithm is fixed and the
question is the asymptotic behaviour of one CV run's risk estimate. It is on the
shelf for G6.

What this paper adds over `bayle2020.md` is that it treats **both** estimands
explicitly and shows they have different asymptotic variances — which is the
IP3 distinction, made quantitative.

## What it establishes

**Result 1 — the two things a CV number can be estimating are not the same, and
the survey of which one you mean changes the answer.** §1.1 and §2.2, pp. 4, 6–7:

- R̂^average_{n,K_n} = (1/K_n) Σ_j R_n(f̂_j(X^n)), the average risk of the K
  hypotheses this run actually produced. Random, because it depends on the K
  fitted models. "of interest to characterise the performance of R̂_cv as an
  estimator of the risk of the ensemble hypothesis (which is itself random)".
- R_{n,K_n} = its expectation — "the regime to consider to understand the
  performance of R̂_cv in estimating the average performance of the estimator of
  interest", i.e. the risk of the *procedure* over replications of the dataset.
  The paper calls convergence to this one "of much broader interest" and says it
  "requires somewhat stronger conditions".

Theorem 1 (p. 7) gives a CLT for the first with asymptotic variance σ₁²;
Theorem 3 (pp. 8–9) gives a Berry–Esseen bound for the second with asymptotic
variance **σ²_cv = σ₁² + σ₂² + 2ρ**, where σ₂² is the variance of the risk of the
fitted rule and ρ a covariance term. Different targets, different widths, from
the same CV run.

**Result 2 — how much CV beats a single split depends on the data, not just the
algorithm.** Remark 3, p. 9: relative to the train–test split estimator, the
cross-validated risk converges faster by a factor of

> √( K_n · (1 + 2ρ/(σ₁² + σ₂²))⁻¹ ).

"For ρ < 0, we observe a reduction in variance by a factor larger K_n. For
ρ = 0, we observe an exactly K_n times reduction. For ρ > 0, we observe a
reduction ... less than K_n." So the folk √K speed-up is the ρ = 0 case, not the
general case. §4.4's LDA example is the sharpest statement of why this is not an
academic distinction (p. 16):

> "the observed speed-up is not a property solely of the estimator, but rather
> jointly of the estimator and the distribution of the data."

Two data distributions, the same estimator, the same 2-fold scheme: a speed-up of
1.638 in one and 2.367 in the other (Table 3, below).

**Result 3 — when full speed-up does hold, and when it does not.** Proposition 3
(p. 12) computes ρ for M-estimators:

> ρ = −Cov( ∂_θ R(θ*)ᵀ [∂²_θ E(Ψ(X₁,θ*))]⁻¹ ∂_θ Ψ(X₁,θ*), L(X₁,θ*) ).

Remark 6, p. 12: "if the model is evaluated on the same loss it has been trained
on then Ψ = L. Therefore we have ∂_θ R(θ*) = 0 which implies that ρ = 0." Full
speed-up is the *matched-loss* case. The abstract states the consequence
directly: "In other common cases, such as when the training is performed using a
surrogate loss or a regularizer, we show that the behavior of the cross-validated
risk is complex with a variance reduction which may be smaller or larger than the
'full' speed-up, depending on the model and the underlying distribution."

**Result 4 — variance estimators, and the awkward one.** §3, pp. 10–11.
Proposition 1: Σ²_cross = (1/K_n) Σ_j Σ̂²_j — the average of the within-block
empirical variances of the per-point losses — is consistent for σ₁², with an
L²-error bound of order S(S + ε_n(∆))/√n. *(This is the same statistic
`bayle2020.md` calls σ̂²_{n,in}; that paper's Thm. 4 proves it consistent under
weaker conditions, and says so — see §3.3 there.)* Proposition 2 gives an
estimator Ŝ²_cv for σ²_cv, built from replace-one perturbations of a
half-sample CV run; the paper is candid about it — "computationally intractable
for large sample sizes and general estimators, due to the requirement of
computing leave-one-out type estimates". The resulting interval is eq. (29),
R̂_CV ± Ŝ_cv Φ(α/2)/√n. The only worked case is ridge regression, where Ŝ²_cv
has a closed form (§5.7.1).

**Result 5 — the conditions are not decoration.** §4.5 gives two counter-examples
where the CLT fails and the limit is not normal:
- **Nearest neighbours** (§4.5.1, pp. 17–18): with a rescaled 0–1 loss, the
  second-order stability condition fails, √n R̂_cv converges to a mixture of
  Poisson terms rather than a Gaussian, and Remark 7 notes the speed-up relative
  to the split estimator is itself *random*.
- **Noiseless / realizable models** (§4.5.2, p. 19): σ²_{m,n} → 0 violates H₃; a
  rescaled loss makes the limit a quadratic form in Gaussians, "the limiting
  distribution is not normal".

Theorem 1 also assumes **H₀, symmetric estimators** — f_{l,n} invariant to the
ordering of its training points.

## Extracted values

Table 1, p. 10 — simulated coverage of the eq. (29) interval, ridge regression,
5,000 replicates per row. Data: x_i ~ N(0, S_X) with S_X Toeplitz on
(1, 0.5, 0.25), p = 3, β* = p^(−1/2)(1,…,1)ᵀ, y = xᵀβ* + ε, ε ~ N(0,1) (§5.7.2,
p. 52):

| n | 80% | 90% | 95% |
|---|---|---|---|
| 20 | 0.8300 | 0.8920 | 0.9288 |
| 40 | 0.8316 | 0.9078 | 0.9464 |
| 100 | 0.8300 | 0.9166 | 0.9520 |
| 200 | 0.8238 | 0.9108 | 0.9516 |
| 400 | 0.8068 | 0.9058 | 0.9494 |
| 800 | 0.8176 | 0.9120 | 0.9550 |

Recorded as printed. Note the 95% column reaches nominal by n = 100 while the
80% column sits at or below nominal at every n and does not improve
monotonically (0.8300 at n = 20, 0.8068 at n = 400); the paper offers no comment
on this and calls the results "some simple simulation results", leaving "further
investigation to future work". The number of folds used is not stated in §5.7.2.

Table 3, p. 16 — variance of split and 2-fold cross-validated accuracy for LDA,
two data-generating regimes; standard errors in parentheses; the n = ∞ row is
computed analytically from Proposition 7:

| n | slow: n·Var(R̂_split) | n·Var(R̂_CV) | speed-up | fast: n·Var(R̂_split) | n·Var(R̂_CV) | speed-up |
|---|---|---|---|---|---|---|
| 40 | 1.44 (0.01) | 0.83 (0.01) | 1.72 (0.02) | 0.43 (0.01) | 0.19 (0.00) | 2.31 (0.04) |
| 160 | 1.93 (0.04) | 1.13 (0.02) | 1.71 (0.04) | 0.42 (0.00) | 0.18 (0.00) | 2.33 (0.03) |
| 1280 | 0.53 (0.01) | 0.33 (0.00) | 1.60 (0.03) | 0.44 (0.00) | 0.18 (0.00) | 2.41 (0.03) |
| 5120 | 0.53 (0.01) | 0.33 (0.00) | 1.62 (0.02) | 0.43 (0.00) | 0.18 (0.00) | 2.36 (0.03) |
| ∞ | 0.534 | 0.326 | **1.638** | 0.438 | 0.185 | **2.367** |

*(rows n = 80, 320, 640, 2560 omitted here; they interpolate.)* Slow regime:
F₁ ~ Γ(10, 0.15), F₂ ~ Γ(1, 1). Fast regime: F₁ ~ Γ(1, 10), F₂ ~ Γ(1, 1). Two
folds, so "full speed-up" would be exactly 2.

## Bearing on nestedtune

- **The literature's own version of IP3, with a number attached.** IP3 says the
  estimate describes the procedure, never the shipped model. §2.2 says the same
  thing as a choice of estimand and then shows it has consequences: the interval
  for "the K rules this run fitted" has variance σ₁², the interval for "what the
  procedure does on data like this" has variance σ₁² + σ₂² + 2ρ. A package that
  reported one width while users read the other meaning would be wrong by a
  quantity the paper names. This is a stronger argument for IP3's documentation
  obligation than corroboration alone.
- **A specific reason the naive `std_err` cannot be repaired by a constant.**
  `R/nested-results.R:213-217` divides a fold-level standard deviation by √V.
  Result 2 says the V-fold variance reduction relative to a single split is
  V·(1 + 2ρ/(σ₁²+σ₂²))⁻¹, and that ρ's sign is a joint property of algorithm and
  data distribution — 1.638 versus 2.367 for the *same* estimator at V = 2. So
  no fixed divisor is right for all users, which is GP5's case in one line.
- **The matched-loss condition is rarely met in tidymodels.** Remark 6's ρ = 0
  needs training loss = evaluation loss. A tidymodels user tuning a `penalty`
  (a regularizer) and reporting `roc_auc` or `rmse` is in exactly the "surrogate
  loss or a regularizer" case the abstract flags as complex. If a G6 caveat ever
  says anything about how the outer average behaves, it must not assume the
  matched-loss case.
- **The stability conditions rule out engines tidymodels ships.** §4.5.1's
  counter-example is nearest neighbours — `nearest_neighbor()` is a parsnip
  model — and §4.5.2's is the realizable case, which a well-separated synthetic
  fixture reaches. Any interval built on these theorems would be silently
  invalid for a `kknn` workflow. That is a concrete instance of GP5's "where the
  statistics are contested, the package declines".
- **Read against `bayle2020.md`, not instead of it.** The two papers analyse
  overlapping ground; `bayle2020.md` §3.3 argues its conditions are weaker on
  four counts and its σ_n² never larger than this paper's σ̃_n² (Prop. 2 there).
  This paper is the one that handles the procedure-level estimand and quantifies
  the speed-up; that one is the one with a practical variance estimator. Neither
  admits a tuning step.

## Oracle status

**No oracle.** Table 1's coverage figures and Table 3's variances are Monte-Carlo
properties of procedures, not values a nestedtune test could pin, and the closed
forms available (Proposition 3's ρ, Proposition 7's asymptotic variances) are for
M-estimators and LDA under specified generative models, not for anything the
package computes. Recorded for the argument, not as a fixture.

## Open questions

- Whether R̂^average versus R_{n,K_n} — the two estimands of §2.2 — maps cleanly
  onto what a nestedtune user believes `collect_metrics()` reports. The mean over
  outer folds is arithmetically R̂_cv; which estimand it is *taken to estimate* is
  a documentation question this package has not settled in those terms.
  Unasked as of 2026-07-31.
- The sign of ρ for any realistic tuned tidymodels workflow. Proposition 3 gives
  a formula for M-estimators only, and a tune-then-fit procedure is not an
  M-estimator. Unaddressed by the paper — observed 2026-07-31.
- Why Table 1's 80% coverage sits below nominal at every n while 95% converges.
  The paper does not remark on it and §5.7.2 does not state the fold count used
  — observed 2026-07-31.
- Everything in §5 (pp. 20–62): all proofs, including whether H₀–H₃ are used in
  ways that would obviously fail for a procedure with an inner selection step.
  Unread — observed 2026-07-31.
