# gauran2025 — a valid test from a nested design, bought with a closed form this package cannot have

**Citation.** Gauran, I. I., Ombao, H., & Yu, Z. (2025). Predictive performance
test based on the exhaustive nested cross-validation for high-dimensional data.
arXiv:2408.03138v2 [stat.ME], 24 November 2025. Statistics Program, King
Abdullah University of Science and Technology (Gauran, Ombao); Department of
Statistics, University of California, Irvine (Yu).

**Provenance.** Ingested 2026-07-31 from `sources/gauran2025.pdf` (gitignored),
arXiv PDF, 37 pages.
Pagination: PDF page N = the preprint's own printed page N; the body runs
pp. 1–26 and appendices follow.
Extraction: `pdftotext -layout`. **Read in full: Sections 1, 2, 4 and 7**, plus
the statements of Lemma 1, Corollaries 1–2 and the closed forms in §3.1 and
§4.1. **Section 5's discussion and Section 6 (the RNA-seq application) were
read at the level of their setup and stated conclusions rather than
exhaustively; Appendices A–C are proofs and were not read.** The simulation
results are rendered as heat-map figures whose cell values extract as loose
text; a subset is reproduced below **as extracted, with the caveat that the
column-to-parameter alignment was inferred from the axis labels and not
independently confirmed** — observed 2026-07-31.

**Preprint status.** arXiv preprint as of 2026-07-31; no journal version
confirmed.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology note

**"Nested cross-validation" here is ours in structure, but not in setting.**
Inner loop selects the ridge/LASSO penalty λ, outer loop scores — and the paper
cites `varma2006.md` for exactly the reason DESIGN gives (p. 11). What differs
is everything around it:

- **Exhaustive** rather than sampled. Instead of one random K-fold partition,
  the estimator averages over **all** C(N, N₀) train–test splits. The paper's
  framing is that a single partition makes conclusions non-reproducible:
  different partitions of the same data lead to different test decisions.
- **Leave-N₀-out (LN₀OCV)** with a three-way split of the held-out set:
  T₀ℓ = R_Oℓ ∪ R_Iℓ, where R_O is "reserved" for the outer assessment and R_I
  is used for the inner hyper-parameter search. Their headline cases are
  **NL1OCV** (R_O = R_I = 1) and **NL2OCV** (R_O = 2, R_I = 1).
- **Comparison against a fixed baseline**, not between two arbitrary
  candidates. M₀ is the intercept-only model; M₁ is the full model.

Their **Table 1** (p. 6) is the most useful thing on this page for the shelf: a
map of the prediction-error vocabulary across the literature. Recorded below.

## What it establishes

**Result 1 (Lemma 1, p. 9; Corollary 1, p. 10) — the closed form that makes
exhaustion possible.** For ridge-regularized fits, the leave-N₀-out CV
estimator over all C(N, N₀) partitions can be written in terms of the hat
matrix H(λ) and the residual vector r(λ), with no enumeration. For the nested
leave-one-out case the inner selection becomes

> λ̂ₙ = argmin_λ (1/(N−1)) Σ_{m≠n} [ (H0ₙ(λ)r_m(λ) + [H(λ)]_{mn} r_n(λ)) / H1_{mn}(λ) ]²

with H0_a = 1 − [H]_{aa} and H1_{mn} = H0ₙH0_m − [H]²_{mn} (eq. 15, p. 12).
**This is the engine of the entire paper.** Exhaustive nesting is only tractable
because the estimator collapses algebraically for a linear smoother.

**Result 2 (Corollary 2, p. 11) — asymptotics for the estimator.** The
first-order behaviour of LN₀OCV(M₁) is governed by a quantity C₁ with
E(C₁) = Err⁽¹⁾ and V(C₁) = N, under stated excess-risk scaling assumptions.
This is what licenses the normal-theory test.

**Result 3 (Section 2.2, p. 5) — the hypothesis is about predictive
improvement, not parameters.** They test H₀: Err_X⁽⁰⁾ − Err_X⁽¹⁾ ≤ 0 against
H₁: > 0, on the *expected in-sample* prediction error, and report the percent
change Δ = 100·(Err_X⁽⁰⁾ − Err_X⁽¹⁾)/Err_X⁽⁰⁾. The stated advantage of a fixed
intercept-only baseline is screening: a method that cannot beat it does not
merit further comparison.

**Result 4 (Sections 5, 7) — the denominator choice dominates Type I error.**
Twenty-four test statistics were compared: R_O ∈ {1, 2} × three ways of
quantifying the CV estimate's variability (variance-only **V**, squared-bias
**B**, mean squared error **M**) × {Ridge **R**, LASSO **L**} × {adaptive λ̂
**Ad**, averaged λ̄ **Av**}. The conclusions (p. 26):

- **Avoid variance-based denominators entirely** — inflated Type I error across
  most scenarios, from unreliable variance estimation.
- **Prefer squared-bias denominators** for the best power/error balance; use MSE
  when more conservatism is wanted.
- **Prefer Ridge over LASSO** — LASSO-based procedures are described as
  unsuitable for formal inference in most practical applications.
- For NL2OCV, use **adaptive** hyper-parameter selection only; averaged
  selection inflates Type I error. For Ridge NL1OCV, averaged selection is
  acceptable when N ≈ P.

**Result 5 (Section 6) — an applied demonstration** on RNA sequencing data in a
traumatic brain injury cohort. Read only at the level of its framing and its
conclusions; no numbers from it are recorded here.

## Extracted values

**Table 1, p. 6 — prediction-error terminology across the literature.**
Reproduced because it is the clearest cross-walk this shelf has for a
vocabulary that varies by source.

| Terminology | Quantity | Attributed to |
|---|---|---|
| Generalization error | μ := E[L(Y_new, f̂_D(X_new))] | Nadeau & Bengio (1999, 2003) |
| Extra-sample error / true error rate | Err := E[L(Y_new, f̂_D(X_new)) \| D, f̂_D] | Efron & Tibshirani (1997) |
| Expected true error | μ := E_D[Err] | Efron & Tibshirani (1997) |
| Prediction error of f̂ | Err(f̂_D), conditional on X_new and f̂_D | Borra & Di Ciaccio (2010) |
| Expected prediction error | Err = E_D[Err(f̂_D)] | Borra & Di Ciaccio (2010) |
| Out-of-sample error | Err_XY := E[L(Y_new, f̂_{X,y}(X_new, β̂)) \| X, y] | Bates et al. (2023); Patil et al. (2021); Rad & Maleki (2020) |
| In-sample error of f̂ | Err_X^(in) := (1/N)Σₙ E[L(Yₙ, f̂_D(xₙ)) \| f̂_D, X] | Efron (2004) |

The Err/Err_XY pair is `bates2023.md`'s; the conditional-versus-marginal split
is `luo2026.md`'s R_P(f̂ₙ) versus R_{P,n}(𝒜). **This paper's own target is the
in-sample error Err_X**, which is a third thing again — the loss at the
*observed* covariates rather than at fresh ones.

Simulation design (p. 15): N ∈ {50, 100, 150, 200};
γ = P/N ∈ {1+1/N, 2, 3, 4, 5, 10, 15, 20, 25, 50, 75, 100}; effect size
ξ = 0.025·A for A ∈ {0, …, 5}, with ξ = 0 the null.

Rejection rates at N = 50, P = 51 and N = 100, P = 101, extracted from the
Section 5 heat maps. The ξ = 0 column is the Type I error rate; naming is
[R/L][R_O][V/B/M][Ad/Av]. **Extracted as printed; column alignment inferred
from the axis labels** — observed 2026-07-31.

| Statistic | N=50, ξ=0 | ξ=0.05 | ξ=0.125 | N=100, ξ=0 | ξ=0.05 | ξ=0.125 |
|---|---|---|---|---|---|---|
| L1MAv | 0.045 | 0.134 | 0.524 | 0.049 | 0.288 | 0.949 |
| L1BAv | 0.046 | 0.157 | 0.574 | 0.049 | 0.370 | 0.960 |
| **L1VAv** | **0.361** | 0.506 | 0.827 | **0.401** | 0.764 | 0.973 |
| L1MAd | 0.137 | 0.218 | 0.568 | 0.056 | 0.276 | 0.977 |
| L1BAd | 0.140 | 0.241 | 0.624 | 0.056 | 0.365 | 0.986 |
| **L1VAd** | **0.364** | 0.459 | 0.844 | **0.314** | 0.691 | 0.997 |
| R1MAv | 0.002 | 0.028 | 0.762 | 0.000 | 0.573 | 1.000 |
| R1BAv | 0.003 | 0.043 | 0.876 | 0.000 | 0.692 | 1.000 |
| **R1VAv** | **0.326** | 0.625 | 0.998 | **0.192** | 0.998 | 1.000 |
| R1MAd | 0.001 | 0.012 | 0.366 | 0.000 | 0.349 | 1.000 |
| R1BAd | 0.002 | 0.017 | 0.511 | 0.000 | 0.460 | 1.000 |
| R1VAd | 0.108 | 0.129 | 0.710 | 0.060 | 0.886 | 1.000 |

The pattern is unmistakable regardless of alignment details: every
variance-denominator row rejects a true null 19–40% of the time, while the
Ridge bias/MSE rows are markedly *conservative* (0.000–0.003) and still reach
power 1.000 at the larger effect sizes.

No code repository is named in the sections read — observed 2026-07-31.

## Bearing on nestedtune

- **This is the only source on the shelf that produces a valid test and
  confidence interval *from a nested design*, and it is not portable.** Its
  validity and its tractability both rest on Lemma 1's closed form for a linear
  smoother's hat matrix. nestedtune delegates the entire statistical pipeline
  to `tune` for an arbitrary `workflow` — a random forest, a boosted tree, a
  recipe with a filter step — none of which has a hat matrix. **The finding for
  G6 is therefore decisive in a useful way: valid inference from nesting is
  achievable, but the route runs through model-specific algebra that the
  package's contract boundary excludes by design.** That is worth adding to
  the G6 disposition; it is a sharper statement than "the statistics are
  contested".
- **Its outer schemes are ones the ecosystem refuses.** R_O = 1 is leave-one-out
  and R_O = 2 leave-two-out; `tune` aborts on `loo_cv` (the same check at
  `R/checks.R:19-21` that rejects `nested_cv`, per
  `tidymodels-nested-cv-gaps.md`). Even the resampling design here is outside
  what the package can express.
- **It reframes "reproducibility" in a way DESIGN should distinguish
  explicitly.** The paper's motivating complaint is that a K-fold estimate
  depends on which partition was drawn, so two analysts reach different
  conclusions; their fix is to average over *all* partitions. IP2's
  reproducibility is a different property — the same seed gives the same
  partition and the same answer, across workers and execution modes. IP2 makes
  a run repeatable; it does not make the estimate partition-independent.
  Nothing in the package currently says so, and a reader could conflate them.
- **Result 4 is a caution for any future interval, and it is empirical rather
  than theoretical.** The variance-based denominator — the obvious choice, and
  the one a naive `std_err` over outer folds would amount to — produced Type I
  error near 0.36 where 0.05 was nominal. That is the same warning
  `bates2023.md` gives about naive CV intervals under-covering, now measured
  inside a nested design. It is the strongest single argument against ever
  letting `collect_metrics()`'s `std_err` be read as an inferential quantity.
- **Read against `bayle2026.md`, the comparison structure matters.** That paper
  shows comparisons of two *similar* algorithms converging to the same
  prediction rule are relatively unstable. This paper compares against an
  intercept-only baseline — two procedures that emphatically do not converge to
  the same rule — so its σ²(h^diff) does not collapse and the failure mode may
  simply not arise. Recorded as a plausible reconciliation, not as an
  established one: neither paper cites the other, and nothing here verifies it.
- **Table 1 belongs in the package's own vocabulary work.** IP3's documentation
  obligation — say plainly what a user should report instead — requires naming
  the estimand. This table shows there are at least seven named candidates in
  the literature and that this paper's own target (in-sample error at the
  observed covariates) is different again from `bates2023.md`'s and
  `luo2026.md`'s. Whatever the docs say, they must name which one.

## Oracle status

**No oracle.** The estimator is ridge/LASSO-specific and its closed form has no
analogue in the package. The simulation results are rejection rates for tests
nestedtune does not implement, and the applied section's numbers describe a
specific TBI cohort.

The one candidate is negative: Lemma 1's closed form would be a
type (3) analytic oracle *for a ridge fit*, and could in principle validate an
exhaustive-CV estimate against a brute-force enumeration on a tiny fixture.
That would test the algebra, not this package. Not planned.

## Open questions

- Whether the heat-map extraction above is correctly aligned to its axes. The
  figures were not read as images and the numbers were recovered from loose
  text; the qualitative pattern is robust but individual cells are not
  independently confirmed — observed 2026-07-31.
- Whether any part of the exhaustive-partition idea survives without a closed
  form. The paper never addresses the general case, and the naive cost is
  C(N, N₀) fits — observed 2026-07-31.
- Whether the paper's in-sample error target Err_X is the estimand a
  nestedtune user would want. It conditions on the observed covariates, which
  is not what "how will this do on new data" usually means — unexamined here
  and not reconciled with the other six entries in its own Table 1 — observed
  2026-07-31.
- Whether the Type I error inflation from variance denominators depends on
  ridge/LASSO or is general. Measured only inside this framework — observed
  2026-07-31.
