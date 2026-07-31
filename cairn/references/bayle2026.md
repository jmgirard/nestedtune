# bayle2026 — two individually stable algorithms can have an unstable *comparison*, and the CV interval then breaks

**Citation.** Bayle, A., Janson, L., & Mackey, L. (2026). The relative
instability of model comparison with cross-validation. arXiv:2508.04409v3
[stat.ML], 4 June 2026. Harvard University (Bayle, Janson); Microsoft Research
New England (Mackey).

**Provenance.** Ingested 2026-07-31 from `sources/bayle2026.pdf` (gitignored),
arXiv PDF, 35 pages.
Pagination: PDF page N = the preprint's own printed page N; the main body runs
pp. 1–8 and appendices follow.
Extraction: `pdftotext -layout`. **Read in full: the main body, Sections 1–6**,
including every definition, theorem statement, lemma statement and the
Conclusions. **Appendices C–N are proofs and experiment details and were not
read**; every result below is recorded as stated, not verified. **Figures 1–6
are images and were not read** — the rate curves and coverage plots live there;
the r(hₙ) values quoted below are the ones printed as text inside the Figure 2
and Figure 3 KDE legends and are recorded as printed — observed 2026-07-31.

**Preprint status.** arXiv preprint as of 2026-07-31, in ICML/PMLR manuscript
format with an Impact Statement section; no journal or proceedings version
confirmed.

**Citekey disambiguation.** This is **A. Bayle** (Alexandre) with Janson and
Mackey. `bayle2020.md` is **P. Bayle** (Pierre) *and* A. Bayle with the same
two senior authors — a different first author, same research line. Read
`bayle2020.md` first; this paper is a negative result about that paper's own
guarantee.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology note

The paper's central object is **relative loss stability** (Definition 2.1,
p. 2). With γ(hₙ) the loss stability of Kumar et al. (2013) — the expected
squared change in the centred loss when one training point is swapped — and
σ²(hₙ) = Var(E[hₙ(Z₀, Z) | Z₀]), define

> r(hₙ) ≜ n · γ(hₙ) / σ²(hₙ)

The **relative loss stability condition** is r(hₙ) = o(1). This is exactly the
sufficient condition behind `bayle2020.md`'s CLT and variance-estimator
consistency, rewritten as a ratio. The reformulation is the whole point:
absolute stability γ(hₙ) → 0 fast is *not enough* if σ²(hₙ) shrinks just as
fast.

Two roles for hₙ, distinguished throughout by superscript:

- **h^sing** — the loss of one prediction rule. Single-algorithm assessment.
- **h^diff** — the *difference* of two prediction rules' losses. Comparison.

The inferential target is the **k-fold test error** Rₙ (eq. 6, p. 4): the
conditional expected loss, averaged over folds — random, conditional on each
training set. Not E[Rₙ]. The paper is explicit (p. 2) that `luo2026.md` targets
E[Rₙ] instead, and that inference on E[Rₙ] is often hard even where inference
on Rₙ is easy. **The two papers are complements, not rivals**, and the shelf
should carry them that way.

## What it establishes

**Result 1 (Theorem 3.1, p. 3) — soft-thresholding comparisons are relatively
unstable.** Under the Gaussian linear model with at least one zero coefficient
(‖β*‖₀ < p), comparing ST(λₙ) against ST(λₙ + δₙ) with λₙ = O(√n), λₙ = ω(1),
δₙ = Θ(1):

> (n²/δₙ²)·σ²(h^diff) → 4τ²‖β*‖₀  and  γ(h^diff) = Ω(√n/n²), so r(h^diff) = Ω(√n)

Not o(1) — it *diverges*. The paper notes this is a lower bound, so the
stringent assumptions (linearity, sparsity, independent Gaussian covariates)
make the result stronger, not weaker: failure occurs in the most favourable
setting imaginable.

**Result 2 (Theorem 3.2, p. 3) — the same algorithm, assessed alone, is
relatively stable.** For λₙ = o(n), σ²(h^sing) → 2τ⁴ and γ(h^sing) ~ C/n², so
r(h^sing) ~ (C/2τ⁴)·(1/n) = o(1). Both ST(λₙ) and ST(λₙ + δₙ) individually
satisfy the condition under Theorem 3.1's hypotheses. **The pair is unstable
while each member is stable.**

**Result 3 (Theorems 3.3 and 3.4, p. 4) — the same holds for the Lasso.**
Carried over from ST by a proximity bound (Lemma 2.3): the Lasso comparison has
r = Ω(√n) while the Lasso alone has r = o(1).

**Result 4 (Lemma 4.1, p. 5) — the mechanism, in one line.** If two linear
predictors converge to the same limit, σ²(h^diff) → 0. Comparing two *consistent*
algorithms drives the denominator of r to zero, so absolute stability of the
numerator no longer suffices. In Theorem 3.1's setting γ(h^diff) = O(1/n²) —
the comparison *is* loss stable in the absolute sense — and it fails anyway
because σ²(h^diff) shrinks at the same 1/n² rate.

**Result 5 — the consequence for intervals.** When r(h^diff) ↛ 0, the CV
central limit theorem (eq. 7) and the consistency of the within-fold variance
estimator need not hold, and intervals built on them can be asymptotically
invalid (p. 5). Figure 1 (unread) is captioned as showing accurate coverage for
a single Lasso fit and severe *under*-coverage for the comparison of two Lasso
fits differing only slightly in tuning parameter.

**Result 6 — it is not universal, and the paper says so.** Two counter-cases
are reported (pp. 6–7): with a fully dense β* (‖β*‖₀ = p) the ST comparison's
γ(h^diff) scales as 1/n⁴ and relative stability *does* hold; and ridge
comparisons are relatively stable for the same reason. The paper declines to
claim the CLT is always a poor choice for comparison — only that users should
not assume relative stability holds by default.

**Result 7 (Proposition 6.1, p. 8) — a valid, conservative fallback.** If
[L⁽¹⁾, U⁽¹⁾] and [L⁽²⁾, U⁽²⁾] are asymptotic (1 − α/2) intervals for each
algorithm's test error separately, then [L⁽¹⁾ − U⁽²⁾, U⁽¹⁾ − L⁽²⁾] covers
Rₙ⁽¹⁾ − Rₙ⁽²⁾ with probability ≥ 1 − α. A two-line union-bound proof. It needs
no comparison-stability assumption, but ignores the strong positive correlation
between the two CV errors and can therefore be much wider — the paper says
orders of magnitude wider in their setting.

**Result 8 — two limitations the authors state about themselves** (p. 8): the
analysis is specific to their data distribution and to ST/Lasso, and they leave
open whether relative instability *always* implies CV invalidity.

## Extracted values

Simulation design (Section 5, p. 5): β* = (3, 1, −5, 3, 0, 0, 0, 0, 0, 0),
p = 10, noise τ = 10, k = 10, λₙ = √n, δₙ = 1. n from 90 to 90,000 (total
sample size nk/(k−1) from 10² to 10⁵). σ²(hₙ) and γ(hₙ) estimated by Monte
Carlo.

Printed r(hₙ) values from the Figure 2 and Figure 3 legends (recorded as
printed; the curves themselves were not read):

| n | ST, single | ST, comparison | Lasso (CV-tuned λ), single | Lasso, comparison |
|---|---|---|---|---|
| 9 × 10¹ | 6.0e−01 | 2.1e+01 | 9.0e−01 | 2.6e+01 |
| 9 × 10² | 4.4e−02 | 3.5e+01 | 9.2e−02 | 4.0e+01 |
| 9 × 10³ | 4.2e−03 | 1.1e+02 | 1.8e−02 | 1.3e+02 |
| 9 × 10⁴ | 4.2e−04 | 3.4e+02 | 4.3e−03 | 4.4e+02 |

Observed rates (p. 6): for the single algorithm, σ² constant, γ ~ 1/n²,
r ~ 1/n — as Theorem 3.2 predicts. For the comparison, σ² ~ 1/n²,
γ ~ 1/(n²√n), r ~ √n — *faster* than the Ω lower bounds the theorems prove.

Alternative settings: dense β* = (3, 1, −5, 3, 4, −3, 10, 8, 5, 2) gives
γ(h^diff) ~ 1/n⁴ and relative stability; ridge comparisons give γ ~ 1/n⁴
against σ² ~ 1/n², also stable (pp. 6–7).

**Note on the Lasso experiment (Figure 3).** Its λₙ is *selected by an inner
cross-validation* at each of the k outer iterations (p. 6). That is a tuned
procedure with an inner CV — structurally the thing nestedtune runs — and its
**single-algorithm** relative stability held empirically (column 3 above, → 0),
while the comparison of two such procedures diverged.

Code: Python replication at `https://github.com/alexandre-bayle/ricv` (p. 5).
Not retrieved — observed 2026-07-31.

## Bearing on nestedtune

- **It splits G6's most promising lead in two, and the split is good news for
  the package's actual estimand.** `tidymodels-nested-cv-gaps.md` records
  `bayle2020.md` as supplying an asymptotically exact CI, blocked on loss
  stability being unestablished for a tuned procedure. This paper's Figure 3
  is the closest thing to evidence on that exact question: a Lasso whose λ is
  chosen by an inner CV, assessed as a *single* algorithm, showed r → 0 across
  four orders of magnitude of n. That is one setting and not a theorem, but it
  is the first datapoint the shelf has on whether a tuned procedure can be
  relatively stable. **Recorded as evidence, not as settled.**
- **And it adds a blocker the gap ledger does not have, for a use the package
  invites.** Everything the package surfaces beyond a single number is a
  comparison: fold-to-fold selected parameters, and — more dangerously — a user
  comparing two workflows' nested estimates. Result 1 says such a comparison
  can be relatively unstable *precisely when the two candidates are similar*,
  which is the normal case for neighbouring points on a tuning grid. Any future
  inference feature must therefore treat "interval for one procedure" and
  "interval for a difference" as separate problems with separate conditions.
- **It gives the selection-instability convention a mechanism.** DESIGN's
  convention that default print/summary surfaces disagreement between folds'
  selected parameters is currently justified on the grounds that nothing else
  in the ecosystem does it. Result 4 supplies a reason: when two candidates
  converge to the same prediction rule, the variance of their loss *difference*
  collapses while the perturbation noise does not, so which one wins a fold is
  close to arbitrary. Fold-to-fold disagreement is the expected behaviour of a
  well-behaved tuner on a fine grid, not a symptom. That belongs in the print
  method's documentation.
- **GP5 gains a concrete prohibition.** Do not ship anything that tests whether
  one workflow beats another from `collect_metrics()` output. The paper's own
  Impact Statement names reducing over-interpretation of small CV differences
  as its goal, and lists the standard comparison tests (Dietterich 1998,
  Nadeau & Bengio 2003, Demšar 2006) as the practices it undermines.
- **Proposition 6.1 is the shape any future comparison feature should take.**
  Two separate single-algorithm intervals, union-bounded, conservative but
  assumption-light. It inherits G6's blockers for each component interval, so
  it is not reachable today; it is worth recording as the *correct* shape so a
  later attempt does not reach for the tighter, invalid construction.
- **Read with `luo2026.md`, the two bound the problem from both sides.** Luo &
  Barber: inference on the *expected* test error E[Rₙ] — the algorithm risk —
  is hard unless N ≫ n. Bayle et al.: inference on the *conditional* test error
  Rₙ is easy for a single stable algorithm and can fail entirely for
  comparisons. Together they say the tractable target is one procedure's
  conditional test error, and even that only under a stability condition
  `luo2025.md` says cannot be certified from data. That is the honest state of
  G6 as of 2026-07-31.

## Oracle status

**No oracle for nestedtune, but the closest reproducible numeric target the
G6 line has.**

The quantities computed here — σ²(hₙ), γ(hₙ), r(hₙ) — are properties of an
algorithm and a distribution, not outputs a resampling package produces. There
is nothing for `nested_tune_grid()` to reproduce.

What exists is GP2 type (2) material for a hypothetical future feature: a
public Python replication repository, a fully specified generative model
(β* given exactly, τ = 10, k = 10, λₙ = √n, δₙ = 1), and printed r(hₙ) values
at four sample sizes to two significant figures. If the package ever computed a
stability diagnostic, that is the check. Recorded as a candidate shape;
nothing is planned.

## Open questions

- Whether the relative stability observed for the CV-tuned Lasso in Figure 3(a)
  holds for tuned procedures generally, or is an artefact of this generative
  model. The paper proves nothing about tuned procedures — the CV-selected λ
  appears only as an experimental variant — observed 2026-07-31.
- Whether relative instability always implies invalid CV inference. Explicitly
  left open by the authors (p. 8) — observed 2026-07-31.
- What broad, checkable conditions imply relative stability of a comparison.
  Named by the authors as an important direction for future work (p. 8), and it
  is the condition any comparison feature would need — observed 2026-07-31.
- How much wider Proposition 6.1's union-bound interval is in a realistic
  tidymodels setting. The paper reports "orders of magnitude" for its own
  setting in Appendix N, Figure 6, which was not read — observed 2026-07-31.
- Whether the paper has appeared in a peer-reviewed venue since v3 — not
  checked as of 2026-07-31.
