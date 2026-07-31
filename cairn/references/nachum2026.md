# nachum2026 — there is no universally optimal fold count, and CV's MSE has a floor no ERM can beat

**Citation.** Nachum, I., Urbanke, R., & Weinberger, T. (2026). The structure of
cross-validation error: Stability, covariance, and minimax limits.
arXiv:2511.03554v2 [math.ST], 8 January 2026.

**Provenance.** Ingested 2026-07-31 from `sources/nachum2026.pdf` (gitignored),
arXiv PDF, 60 pages.
Pagination: PDF page N = the preprint's own printed page N.
Extraction: `pdftotext -layout`. **Read in full: Sections 1, 2 and 5**, plus
Section 4's theorem, lemma and definition statements with their surrounding
discussion. **Appendices A–F are proofs (roughly 45 of the 60 pages) and were
not read**; every result below is recorded as stated, not verified — observed
2026-07-31.

**Preprint status.** arXiv preprint as of 2026-07-31; no journal version
confirmed. The author affiliations are marked with symbols the extraction did
not resolve and are therefore not recorded here.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology note

**No nesting and no tuning.** This is a theory paper about plain k-fold CV used
for *risk estimation* — the model is chosen independently of the error
computations. Its relevance is to the outer loop's own accuracy, not to
selection.

Its lasting contribution to this shelf is vocabulary. It lays three stability
notions side by side (Definitions 2.1–2.3, pp. 5–6), from strongest to weakest:

- **Hypothesis stability** — how often the fitted *hypothesis* changes its
  prediction when a fold is removed. The paper argues this is stronger than
  needed.
- **Loss stability** — how much the *risk* changes when a fold is removed.
  Kumar et al.'s notion, and the one `bayle2020.md` uses.
- **Squared loss stability (SLS)**, new here — the expected squared gap between
  the symmetrized leave-m loss and the full-sample loss. Weaker still, and
  **provably necessary** for low MSE under low loss variance (Corollary 4.6).

**The shelf now carries five mutually non-interchangeable stability notions**:
these three, plus `luo2025.md`'s prediction-based (ε, δ)-stability and
`bayle2026.md`'s *relative* loss stability (a ratio, not an absolute bound).
Nothing on the shelf reconciles them, and results proved under one do not
transfer to another.

## What it establishes

**Result 1 (Lemma 4.1 / Theorem 4.3, §4.1) — the decomposition.** The MSE of
the k-fold CV estimator splits into (i) a squared-loss-stability term and
(ii) the covariance between per-fold loss estimates, plus two correction terms
that are dominated by the first two under low loss variance. The paper's claim
is that this is the first rigorous version of the informal
variance/covariance/stability tradeoff practitioners reason with when picking
k.

**Result 2 — there is no universally optimal k, demonstrated by two opposite
extremes.**

- A **linear-function learner** over a finite field (Theorem 4.8) has poor
  squared-loss stability, so the stability term dominates and **more folds are
  better** — leave-one-out when n ≥ d. (When n < d the direction reverses and
  larger folds help.)
- The **majority algorithm** (§4.1.2) has excellent squared-loss stability — its
  population loss is exactly 1/2 regardless of sample — so fold covariance is
  the whole story, and **fewer folds are better**.

**Result 3 (Theorems 4.10 and 4.11) — the majority algorithm, solved exactly.**
Under Bernoulli(1/2) labels, the between-fold covariance has a closed
combinatorial form,

> Cov(n, m) = 2⁻ⁿ · Σ_{j=0}^{m−1} C(m−1, j)² · C(n−2m, ⌊(n−m)/2⌋ − j)

and Lemma 4.9 gives MSE = ((k−1)/k)·Cov(L̂₁, L̂₂) + 1/(4n). Asymptotically
Cov(n, m) = Θ(1/√(nm)) = Θ(√k/n) for m = Ω(n^{1/5}), and the covariance is
**strictly decreasing in m up to n/3, with k = 3 the minimizer**.

The counter-intuitive part, which the paper flags: the majority algorithm
becomes *more hypothesis unstable* as k decreases, yet CV becomes *more
accurate*. Any bound driven by hypothesis stability predicts the wrong
direction here — which is why they nominate Majority as a benchmark that any
future CV bound should have to match.

**Result 4 (Corollary 4.12) — a minimax floor for every ERM.** Taking a
degenerate distribution on a single point with uniform labels reduces any ERM
to the majority algorithm, giving max_D MSE_CV = Ω(√k/n) for every k, hence

> ℜ_CV(𝒜) = Ω(√k*/n)

where k* is the fold count attaining the minimax optimum. **No ERM can use all
n samples as efficiently as an independent validation set of size n**, whose
MSE is O(1/n). The penalty is a factor √k*, and it comes from dependence
between folds.

**Result 5 (Definition 4.13, Theorem 4.14, Corollary 4.15) — and some
algorithms do no better than a single hold-out.** The r-square-wave algorithm —
which outputs a constant hypothesis determined by ⌊(Σyᵢ)/√r⌋ mod 2 — has fold
covariance c₀/m + error, with c₀ = (1/2)·Σ_{j≥0} e^{−π²(2j+1)²/4} ≈ **0.0424**
and error constant c_R ≤ 4 × 10⁻⁴. Because that covariance is **independent of
n** no matter how large the shared training set, max_D MSE_CV = Ω(k/m) = Ω(k/n)
— the rate of a hold-out on a single fold of size n/k. For these algorithms
cross-validating buys at most a constant factor.

**Result 6 — two published results are identified as erroneous.** Appendix E
concerns Theorem 5.3 of Kearns & Ron (1997) and Appendix F concerns Theorem 2
of Kale, Kumar & Vassilvitskii (2011). Both appendices were not read; recorded
because the corrections change what earlier literature can be relied on. The
paper uses the first to argue that loss stability is *not* in general necessary
for low MSE — there exist algorithms with poor loss stability whose risk CV
estimates well (Lemma 4.4).

## Extracted values

The paper reports no simulations. Its computable quantities:

| Quantity | Value |
|---|---|
| Fold-count minimizing majority's fold covariance | **k = 3** |
| Majority fold covariance, m = Ω(n^{1/5}) | Θ(1/√(nm)) = Θ(√k/n) |
| Majority MSE (Lemma 4.9) | ((k−1)/k)·Cov(n, m) + 1/(4n) |
| Square-wave main constant c₀ | ≈ **0.0424** |
| Square-wave error constant c_R | ≤ 4 × 10⁻⁴ |
| Constant-hypothesis baseline (footnote 3, p. 4) | MSE_CV = p(1−p)/n, so ℜ_CV = **1/(4n)** |
| ERM minimax floor | Ω(√k*/n) |
| Square-wave rate | Ω(k/n) |

Linear-learner MSE over a finite field of size q with feature dimension d
(Theorem 4.8): O(q^{−(d−n)}) when n < d; Ω(1) when n ≥ d and n − m < d;
O(q^{−(n−m−d+1)}) when n − m ≥ d.

## Bearing on nestedtune

- **It is the rigorous answer to "what should v be?", and the answer is that
  there is no answer.** nestedtune has no opinion on the outer or inner fold
  count today, and this paper says that is the *correct* posture: which of the
  two MSE terms dominates is a property of the algorithm–distribution pair, so
  a package cannot pick well on the user's behalf. That is the same shape as
  `austern2020.md`'s finding that the V-fold variance reduction is jointly
  determined by algorithm and distribution, now proved for MSE rather than
  asymptotic variance. **Two independent sources now say the fold count is not
  a knob a library can set correctly.** Worth stating in documentation instead
  of leaving the default unexplained.
- **It puts a floor under the outer estimate's accuracy, which bears on G6.**
  Even with the best possible k, an ERM's k-fold MSE is Ω(√k*/n). `luo2026.md`
  bounds the *power of any test*; this bounds the *MSE of the estimate itself*.
  Together they say the nested estimate is neither as accurate as a hold-out of
  the same total size nor testable at nesting's sample ratio. Neither result
  makes the point estimate wrong; both constrain what may be claimed about it.
- **It supplies the shelf's first genuine analytic oracle candidate for the
  outer loop.** See Oracle status below. This is the most actionable finding on
  this page.
- **It complicates the stability blocker rather than resolving it.** G6's
  disposition currently names loss stability, following `bayle2020.md`. This
  paper introduces a weaker sufficient notion (SLS), proves loss stability is
  *not* necessary in general (Lemma 4.4), and proves SLS *is* necessary under
  low loss variance (Corollary 4.6). Any future G6 work must say which notion
  it means; "stability" alone is no longer a well-formed condition on this
  shelf.
- **Nothing here touches IP1, IP2, IP4, or the orchestration gaps.**

## Oracle status

**A real GP2 type (3) analytic-oracle candidate — the first the outer loop has
had — with a cost caveat that has sunk similar candidates before.**

Theorem 4.10 plus Lemma 4.9 give a **closed-form exact value** for the mean
squared error of the k-fold CV estimate of the majority algorithm's risk under
Bernoulli(1/2) labels: MSE = ((k−1)/k)·Cov(n, m) + 1/(4n) with Cov(n, m) the
finite sum above. Both are elementary to compute in R for small n.

Why it is reachable from this package specifically:

- The majority algorithm is a real tidymodels model. `parsnip::null_model()`
  exists with `mode = "classification"` and the `"parsnip"` engine — verified
  present in the installed parsnip on 2026-07-31 — and predicts a constant
  class from the training labels.
- It has **no tuning parameters**, so a nested run over a one-row grid should
  reduce exactly to plain k-fold CV of that model. That degeneracy is itself
  the invariant worth testing: `nested_tune_grid()` with a single candidate
  must agree with the flat CV of the same workflow, and the MSE of that
  quantity is analytically known.

Why it is not yet a fixture, recorded honestly:

- The theorem's setting is exactly Bernoulli(1/2) labels with an arbitrary
  feature marginal and 0–1 loss. Any deviation (class imbalance, a tie-breaking
  rule that differs from `Y > n/2`) voids the closed form, and the tie-breaking
  behaviour of `null_model()` at Y = n/2 has **not** been checked — observed
  2026-07-31.
- MSE is a distributional property. Confirming it needs many replicates, which
  is the same GP4 collision that keeps `varma2006.md`'s null-data invariant off
  the fixture list. The advantage here is that the target is an *exact number*
  rather than a separation between two distributions, which may need far fewer
  replicates — unmeasured.
- The paper's own asymptotic claims (Θ(1/√(nm)), k = 3 minimizing) are
  asymptotic; only Theorem 4.10's finite sum is exact at small n.

Recorded as a candidate shape. Not planned, and no acceptance criterion depends
on it.

## Open questions

- Whether `parsnip::null_model()`'s prediction rule matches A_maj exactly,
  including at Y = n/2. Not checked — observed 2026-07-31.
- How many replicates separate the predicted MSE from a plausible wrong
  implementation at fixture-sized n. Unmeasured — observed 2026-07-31.
- Whether a nested run with a single-candidate grid provably reduces to flat CV
  in this package. Structurally it should — `select_best()` on one candidate is
  a no-op — but no test asserts it as of 2026-07-31.
- What the corrections in Appendices E and F actually say, and whether any
  shelf page currently rests on the corrected results. Not read; neither
  Kearns & Ron (1997) nor Kale, Kumar & Vassilvitskii (2011) is on the shelf —
  observed 2026-07-31.
- Which combined algorithm/distribution properties permit better than the
  Ω(√k*/n) minimax rate. Named by the authors as future work (p. 13) —
  observed 2026-07-31.
