# tibshirani2009 — the cheap alternative to nesting: correct the minimum CV error instead of re-running the loop

**Citation.** Tibshirani, R. J., & Tibshirani, R. (2009). A bias correction for
the minimum error rate in cross-validation. *The Annals of Applied Statistics*,
3(2), 822–829. doi:10.1214/08-AOAS224. Both authors Stanford University.
Received November 2008; revised November 2008.

**Provenance.** Ingested 2026-07-31 from `sources/tibshirani2009.pdf`
(gitignored), publisher PDF, 8 pages.
Pagination: PDF page N = article page 821 + N (PDF p. 1 = journal p. 822).
Extraction: `pdftotext -layout`, full text read. Tables 1 and 2 (pp. 827, 826)
extracted cleanly and are reproduced below. **Figure 1 (p. 823) is an image and
was not read**; the Brown-data numbers below come from its caption and the
surrounding prose — observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology note

**This paper is not about nested CV; it is the argument for not doing it.** It
names `varma2006.md` explicitly and dismisses the remedy: nested CV amounts, it
says, to a cross-validation per data point, and is therefore "impractical"
where CV is expensive (p. 822). *Recorded as characterized, and the
characterization is worth flagging:* Varma & Simon's outer loop happens to be
leave-one-out, so a CV per data point is that paper's design, not the
construct's. A V-fold outer loop — nestedtune's default — costs V inner tuning
runs, not n. The dismissal lands against one published experiment, not against
nesting.

Sign convention here is the opposite of the usual one: **Bias = Err − CV(θ̂)**
(eq. 2, p. 824), so a *positive* bias means the CV number is too low. The
estimate is non-negative by construction. Where other shelf pages say the
tuned-CV estimate is "biased downward by 12.2 points" (`varma2006.md`), this
paper says the bias is "+0.122".

## What it establishes

**Result 1 — the minimum of a CV curve is a biased estimate of the test error
at that same tuning value, and the bias is estimable for free.** The naive
estimate of Err = E[L(y₀, f̂(x₀, θ̂))] is CV(θ̂); its bias "is likely to be
positive, since θ̂ was chosen because it minimizes CV(θ)" (p. 824). The proposed
correction (eq. 3, p. 825) uses only per-fold error curves that the tuning run
has already computed:

> Bias‑hat = (1/K) Σₖ [eₖ(θ̂) − eₖ(θ̂ₖ)]

where eₖ(θ) is the error curve from fold k alone and θ̂ₖ its own minimizer. The
adjusted estimate is CV(θ̂) + Bias‑hat, which for equal fold sizes rearranges to
2·CV(θ̂) − (1/K) Σₖ eₖ(θ̂ₖ) (p. 825). "It requires no new model fitting" (p. 825)
— that is the whole selling point.

**Result 2 — the bias is only material when p ≫ n.** Measured over 100
simulations on standard-Gaussian data in four cells (p < n / p ≫ n × signal /
no signal) with five classifiers. In the p < n cell (n = 400, p = 100) the
worst no-signal minimum CV error is 0.473 against a true 0.5 — under 3 points.
In the p ≫ n cell (n = 40, p = 1000) the same quantity reaches 0.384. Their
own summary (p. 829): "the bias itself is only an issue when p ≫ N and its
magnitude varies considerably depending on the classifier."

**Result 3 — an analytic non-negativity result under no signal.** Theorem 1
(p. 827): for classification with 0–1 loss, G equiprobable classes, and y₀
stochastically independent of x₀, E[CV(θ̂)] ≤ Err = (G−1)/G. The proof is two
lines — Err = (G−1)/G by independence, E[CV(θ)] = (G−1)/G for any *fixed* θ,
and E[min_i CV(θᵢ)] ≤ E[CV(θ₁)]. The regression analogue is stated as a
**conjecture only** (pp. 828–829, eqs. 6–7), resting on two unproven
conditional-independence claims that "certainly seem true when looking at
simulations, but are hard to prove rigorously."

**Result 4 — the correction over-shoots for unstable learners on tiny folds.**
At p ≫ n with no signal, the adjusted estimate lands at 0.577 (KNN) and 0.552
(GBM) against a truth of 0.5. The paper attributes this to fold size — "With
only 40 observations, 10-fold CV has just four observations in each fold"
(p. 826) — and shows 5-fold CV improves both (0.524, 0.511) without fixing
them.

## Extracted values

Table 1, p. 827 — 10-fold CV, mean (SE) over 100 simulations. "No signal" test
error is 0.5 by construction and printed without an SE.

| Cell | Method | Min CV error | Test error | Adjusted CV error |
|---|---|---|---|---|
| p < n, no signal | LDA | 0.503 (0.003) | 0.5 | 0.503 (0.003) |
| p < n, no signal | SVM | 0.485 (0.003) | 0.5 | 0.511 (0.004) |
| p < n, no signal | CART | 0.474 (0.003) | 0.5 | 0.510 (0.004) |
| p < n, no signal | KNN | 0.473 (0.002) | 0.5 | 0.524 (0.003) |
| p < n, no signal | GBM | 0.475 (0.003) | 0.5 | 0.520 (0.003) |
| p < n, signal | LDA | 0.290 (0.003) | 0.284 (0.001) | 0.290 (0.003) |
| p < n, signal | SVM | 0.257 (0.003) | 0.260 (0.001) | 0.279 (0.003) |
| p < n, signal | CART | 0.356 (0.003) | 0.378 (0.002) | 0.384 (0.003) |
| p < n, signal | KNN | 0.291 (0.003) | 0.284 (0.002) | 0.305 (0.004) |
| p < n, signal | GBM | 0.269 (0.002) | 0.272 (0.002) | 0.288 (0.003) |
| p ≫ n, no signal | NSC | 0.384 (0.009) | 0.5 | 0.511 (0.012) |
| p ≫ n, no signal | SVM | 0.475 (0.009) | 0.5 | 0.498 (0.010) |
| p ≫ n, no signal | CART | 0.498 (0.011) | 0.5 | 0.500 (0.011) |
| p ≫ n, no signal | KNN | 0.430 (0.007) | 0.5 | 0.577 (0.009) |
| p ≫ n, no signal | GBM | 0.432 (0.010) | 0.5 | 0.552 (0.012) |
| p ≫ n, signal | NSC | 0.106 (0.006) | 0.136 (0.004) | 0.152 (0.008) |
| p ≫ n, signal | SVM | 0.142 (0.007) | 0.138 (0.003) | 0.157 (0.008) |
| p ≫ n, signal | CART | 0.432 (0.012) | 0.432 (0.004) | 0.437 (0.012) |
| p ≫ n, signal | KNN | 0.200 (0.007) | 0.251 (0.005) | 0.297 (0.010) |
| p ≫ n, signal | GBM | 0.233 (0.008) | 0.276 (0.006) | 0.307 (0.010) |

Table 2, p. 826 — the same p ≫ n cell re-run with **5-fold** CV:

| Classifier | Setting | Min CV error | Test error | Adjusted CV error |
|---|---|---|---|---|
| KNN | No signal | 0.430 (0.007) | 0.5 | 0.524 (0.009) |
| KNN | Signal | 0.213 (0.007) | 0.253 (0.005) | 0.281 (0.009) |
| GBM | No signal | 0.425 (0.008) | 0.5 | 0.511 (0.010) |
| GBM | Signal | 0.265 (0.008) | 0.289 (0.007) | 0.325 (0.010) |

Design (p. 826): standard Gaussian features, two equal classes; p < n is
n = 400, p = 100; p ≫ n is n = 40, p = 1000. "Signal" shifts the mean of the
first 10% of features by 0.5 in class 2. NSC replaces LDA at p ≫ n because the
LDA solution is not full rank.

Worked example, Brown microarray data (p. 823, from the Figure 1 caption and
prose): 4718 genes, 128 samples (88 healthy, 40 CNS tumor), split in half,
nearest shrunken centroids via `pamr`, 10-fold CV. Minimum at 23 genes, CV
error 0.047, test error at 23 genes 0.08, bias estimate 0.027, adjusted 0.074.
Over 100 repeats: mean test error 7.8%, mean adjusted CV error 7.3%.

**Two internal disagreements, recorded.** (i) The prose (p. 826) says "Table 1
shows the mean of the test error, minimum CV error (using 10-fold CV), true
bias, and estimated bias"; the printed Table 1 has neither bias column — it
prints Min CV error, Test error, Adjusted CV error. The bias columns can be
recovered by subtraction but are not printed. (ii) The same sentence says "The
standard errors are given in brackets"; the tables use parentheses. Neither
affects a number used above.

## Bearing on nestedtune

- **This is the strongest published argument *against* the package's premise,
  and it should be read as such.** If a correction computed from quantities
  `tune` already returns removes most of the selection bias, an outer loop buys
  less than G2 assumes. The honest reading of their own tables is narrower: the
  correction works well in 14 of 20 cells, mis-fires by 5–8 points for KNN and
  GBM at p ≫ n, and is barely needed at all when p < n.
- **It is computable inside the existing object, and that is a real design
  question.** Eq. (3) needs only per-fold, per-candidate metrics — exactly what
  `tune::collect_metrics(summarize = FALSE)` returns from the inner run that
  `nested_final_fit()` already carries (`R/nested-final-fit.R`, the tuning run
  kept as the record of what selection saw, M22). No new fitting, no new
  storage. Whether to expose it is a GP5 question, not a feasibility one.
- **GP5 says not yet.** The regression case is an unproven conjecture, the
  classification theorem covers only the no-signal case, the correction
  over-shoots for unstable learners, and nothing here is validated for a *tuned
  workflow* (preprocessing plus model) as opposed to one scalar θ. Shipping it
  would be shipping inference the literature has not settled.
- **It sharpens `varma2006.md`'s unanswered sizing question.** That page asks
  how small a null fixture can be and still separate a nested estimate from a
  naive tuned-CV one. Result 2 answers half of it: at p < n the gap is at most
  ~2.7 points and no fixture will separate it reliably; the separation needs
  p ≫ n. A candidate fixture is therefore wide and short, not merely small.
- **Independent corroboration of the shelf's sharpest number.** Nearest
  shrunken centroids on null data with 10-fold CV reads **0.384** here
  (n = 40, p = 1000) and **0.378** in `varma2006.md` (n = 40, p = 6000) —
  two separate simulations, different feature counts, agreeing to six tenths of
  a point. That is the closest thing on this shelf to a replicated constant.
- **Bears on `wainer2021.md`'s conclusion in the opposite direction.** Wainer &
  Cawley argue nesting is overzealous *for choosing an algorithm*; this paper's
  discussion (p. 829) says the reverse for *comparing* them: comparing raw CV
  error rates across models can mislead, and the correction matters most there,
  precisely because the size of the bias varies by classifier. Both can
  hold — a biased criterion can rank well while its levels are incomparable —
  and `cawley2010.md` measures that same level incomparability directly.
- **Estimand agrees with IP3.** Err is defined with the expectation taken "over
  all that is random [namely, the model f̂ and the test point (x₀, y₀)]"
  (p. 824), so it is a procedure-level quantity, not the shipped model's score.
  Same side of the line as `bates2023.md`'s Err rather than Err_XY.
- **Touches G6 only at the edge.** The paper offers the SE of the mean over
  folds "as an approximate estimate for its standard deviation" (p. 825) for
  the *bias estimate*, never for the adjusted error, and never validates it. It
  is not an interval for the nested estimate and does not move the G6 blockers
  recorded in `tidymodels-nested-cv-gaps.md`.

## Oracle status

**One analytic oracle, clean, and one worked example that is not reproducible
here.**

Theorem 1 (p. 827) is GP2 oracle type (3), an analytic result: under no signal,
0–1 loss, and G equiprobable classes, E[CV(θ̂)] ≤ (G−1)/G, with Err = (G−1)/G
exactly. For G = 2 that is the 0.5 line that `varma2006.md` and
`ambroise2002.md` each reach by simulation — the same invariant, here with a
two-line proof rather than a Monte Carlo. That makes the null-data invariant a
*proved* one-sided bound for classification, which is what an invariant-type
fixture needs.

The regression analogue is **not** an oracle: eqs. (6)–(7) are labelled
conjectures resting on unproven conditional-independence claims (p. 829). Any
null-data fixture using RMSE rather than accuracy is unbacked by this paper.

The Brown microarray worked example is type (1) in form but unusable in
practice: the data are described only as coming from "the laboratory of Dr. Pat
Brown of Stanford" with no accession or archive named, and the split is a single
random half — observed 2026-07-31.

## Open questions

- Whether the correction holds for a tuned *workflow* rather than a scalar
  tuning parameter. Every experiment here varies one θ over a one-dimensional
  grid; nothing addresses a joint grid over preprocessing and model parameters,
  where θ̂ₖ is a point in several dimensions — unexamined by the paper, observed
  2026-07-31.
- Whether the over-shoot at p ≫ n is fold-size driven as claimed. The paper
  offers 5-fold as evidence (0.577 → 0.524 for KNN) but the residual is still
  +2.4 points and it never separates fold size from learner instability —
  observed 2026-07-31.
- What the correction does when the inner grid is large. Its mechanism is the
  same selection-over-K-candidates effect that `varma2006.md` eq. (8) makes
  grow with K, but the grid sizes used here are never stated — the paper says
  only "a grid of parameter values θ₁, …, θ_t" (p. 824) and never gives t —
  observed 2026-07-31.
- Whether the SE-of-the-mean it suggests for Bias‑hat has any coverage
  property. Proposed in one sentence (p. 825), never simulated — observed
  2026-07-31.
