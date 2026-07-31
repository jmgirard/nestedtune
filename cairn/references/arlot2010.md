# arlot2010 — the survey: what is settled about CV, what is framework-dependent, and where double cross sits

**Citation.** Arlot, S., & Celisse, A. (2010). A survey of cross-validation
procedures for model selection. *Statistics Surveys*, 4, 40–79.
doi:10.1214/09-SS054. CNRS/Willow Project-Team, Laboratoire d'Informatique de
l'ENS, and Laboratoire Paul Painlevé, Université Lille 1. Received July 2009;
accepted by Yuhong Yang.

**Provenance.** Ingested 2026-07-31 from `sources/arlot2010.pdf` (gitignored),
publisher PDF, 40 pages. Pagination: PDF page N = journal page 39 + N.
Extraction: `pdftotext -layout`, read in full for §§1–2, 4.4, 5, 7.2, 10 and
skimmed for §§3, 6, 8, 9 — this is a survey of ~180 references and this note
covers the parts bearing on nested CV and on variance, not the whole. The one
displayed formula quoted below (Burman's variance expansion, p. 60) was verified
against a 150-dpi render of that page rather than trusted to text extraction,
because the surrounding extraction garbled superscripts. Everything else quoted
is prose — observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology note

**The survey's name for our construct is "double cross", and it defines it in
one sentence.** §5.1.1, p. 58, under *CV-calibrated algorithms*: when λ̂ is
chosen by minimizing the CV estimate over a family (A_λ), the resulting CV value
"is biased for estimating the risk of A_λ̂(D_n)", and the fix is to treat the
whole calibrated procedure as a single algorithm —

> "Estimating the risk of A_λ̂(D_n) with CV can be done by considering the full
> algorithm A′ : D_n ↦ A_λ̂(D_n)(D_n), and then computing L̂_CV(A′; D_n). This
> procedure is called 'double cross' by Stone (1974)."

That is nestedtune's contract in the survey's own notation: the object handed to
the outer CV is the tune-and-fit procedure, not a model. The Stone reference is
the JRSS-B paper, now on the shelf as `stone1974a.md`.

_(Qualified 2026-07-31 on ingesting the cited paper. The A′ construction is an
exact description of what nestedtune computes and nothing below depends on the
attribution — but "called 'double cross' by Stone (1974)" names Stone's §2 item
VI, a two-stage cross-validatory *choice*, where the survey means his item V, the
cross-validatory assessment of a cross-validatory choice. Same correction as on
`cawley2010.md`; see `stone1974a.md`.)_

## What it establishes

**Result 1 — the bias of any CV estimator depends only on the training-set
size.** §5.1.1, eq. (13), p. 57: with equal-sized training sets of n_t points,
E[L̂_CV(A; D_n)] = E[L_P(A(D_{n_t}))]. So the bias of CV as an estimate of the
risk at n is the difference between the risk of A at n_t and at n. The survey
adds the condition usually left implicit: this is non-negative and decreasing in
n_t "when the risk of A(D_n) is a decreasing function of n, that is, when A is a
smart rule", and notes that "a classical algorithm such as 1-nearest-neighbour
in classification is not smart".

**Result 2 — the CV-calibrated bias is of a different kind.** §5.1.1, p. 58: the
bias incurred by reporting the minimized CV value "is of different nature
compared to the previous frameworks. Indeed, L̂_CV(A_λ̂, D_n) is biased for the
same reason as the empirical contrast suffers some optimism as an estimator of
the loss". That is the same optimism `varma2006.md` measures and
`cawley2010.md` tabulates, placed by the survey in its own taxonomy.

**Result 3 — no universal unbiased variance estimator, restated with its
neighbours.** §5.2.3, p. 61: "There is no universal—valid under all
distributions—unbiased estimator of the variance of RLT (Nadeau and Bengio,
2003) and VFCV (Bengio and Grandvalet, 2004). In particular, Bengio and
Grandvalet (2004) recommend the use of variance estimators taking into account
the correlation structure between test errors." See `bengio2004.md` for the
theorem itself.

**Result 4 — how V affects variance has no framework-independent answer.**
§5.2.2, p. 60. In simple linear regression with homoscedastic data, Burman
(1989) proved

> var(L̂^VF(A)) = 2σ²/n + (4σ⁴/n²)[4 + 4/(V−1) + 2/(V−1)² + 1/(V−1)³] + o(n⁻²)

*(quoted verbatim from the rendered page)*, from which "the variance decreases
with V, implying that LOO asymptotically has the minimal variance among VFCV
estimators". On the same page, for classification: "Hastie et al. (2009)
empirically showed that VFCV has a minimal variance for some 2 < V < n, whereas
LOO usually has a large variance." Both directions are recorded, and the survey
declines to reconcile them: §10.1, p. 68 — "the CV method with minimal variance
seems strongly framework-dependent". The variance also "strongly depends on ...
the stability of A" (§5.2.1, p. 59).

**Result 5 — where the V = 5–10 folklore comes from, and its limits.** §10.3,
p. 70: "When the goal of model selection is estimation, it is often reported
that the optimal V is between 5 and 10, because the statistical performance does
not increase a lot for larger values of V, and averaging over less than 10
splits remains computationally feasible (Hastie et al., 2009, Section 7.10).
Even if this claim is true for many problems, this survey concludes that better
statistical performance can sometimes be obtained with other values of V, for
instance depending on the SNR value." The survey's own summary of the question:
"the question of choosing V remains widely open".

**Result 6 — comparing two algorithms needs a different split ratio than
estimating one.** §7.2, pp. 64–65. For selecting the better of two algorithms
converging at the parametric rate, consistency requires n_v ≫ n_t → ∞ — the
"cross-validation paradox", the validation set must dominate — whereas
non-parametric algorithms can be compared with the usual n_t > n/2. This is the
theory behind the V = 2 recommendation of Dietterich (1998) and Alpaydin (1999),
which the survey notes VFCV cannot satisfy anyway since n_t ≥ n/2 for every V.

**Result 7 — estimation and identification are different goals with different
optima.** §2.4 and §10.1: for estimation with high signal-to-noise, the smallest
bias is best (n_t ∼ n); with low SNR, a small upward bias often helps; for
identification a *large* bias is often needed (n_t ≪ n). No single scheme is
right for all three, and §2.4 cites Yang (2005) that no procedure can be
simultaneously model-consistent and minimax-adaptive in regression.

**Result 8 — the discipline's own open problem, as of 2010.** §10.5, p. 71:
"Perhaps the most important direction for future research would be to provide,
in each specific framework, precise quantitative measures of the variance of CV
estimators with respect to n_t, the number B of splits, and the way splits are
chosen."

## Extracted values

The survey reports formulas and qualitative comparisons rather than experiments;
the only closed form recorded above is Burman's expansion (p. 60). Historical
anchors worth keeping (§4.4, p. 56): simple validation goes back to Larson
(1931); LOO was introduced independently by Stone (1974), Allen (1974) and
Geisser (1975); "The idea of using CV for model selection arose in the
discussion of a paper by Efron and Morris (1973) and in a paper by Geisser
(1974). LOO, as a model selection procedure, was first studied by Stone (1974)
who proposed to use LOO again for estimating the risk of the selected model."
Computational cost is given as proportional to the number of splits — "1 for
hold-out, V for VFCV, B for RLT or MCCV, n for LOO, and n choose p for LPO"
(§10.1, p. 69).

## Bearing on nestedtune

- **The cleanest external statement of the package's contract boundary.** §5.1.1's
  A′ construction says precisely what an outer loop should be handed: the full
  calibrated algorithm. nestedtune's driver builds that A′ per fold — tune, then
  finalize, then fit — and scores it. A doc page describing what the package
  computes can cite this sentence and nothing else.
- **A warning about the smart-rule assumption behind the pessimistic caveat.**
  Every source on this shelf that discusses the N − 1 offset (`stone1974b.md`,
  `varma2006.md`) assumes more training data helps. This survey names the
  exception. So the documented caveat should say the estimate describes training
  sets of size n(V−1)/V and is *usually* pessimistic, not that it is always so.
- **Direct support for GP5, and for refusing to default V.** Results 4, 5 and 7
  together say that the right resampling scheme depends on the framework, the
  SNR, and whether the user's goal is estimation or identification — and that
  even the sign of the effect of V on variance flips between regression and
  classification. A package that picked V, or that printed a variance formula,
  would be picking a side the literature has not. nestedtune takes the scheme
  from the user's `rsample` design and computes no interval; this is the survey
  that says why both are right.
- **Bears on G6 as the boundary of the settled ground.** §5.2.3 gives the
  negative result, §10.5 names precise variance quantification as *the* open
  problem of 2010, and §5.2.1 ties the variance to the stability of A. Everything
  later on this shelf — `bayle2020.md`, `austern2020.md` — is an answer to §10.5,
  and both answers are conditional on the stability §5.2.1 flags. That is the
  arc a G6 plan would have to reproduce.
- **Bears on `wainer2021.md`.** §7.2's cross-validation paradox is the theory
  under the algorithm-selection question `wainer2021.md` studies empirically:
  choosing between two algorithms is a different statistical problem from
  estimating one algorithm's error, with different optimal splits. The two notes
  should be read together on that point.

## Oracle status

**No oracle.** The survey states no values a nestedtune test could pin. Burman's
expansion is the closest thing to a checkable formula, and it is asymptotic, for
squared loss in simple linear regression, for the *variance of the estimator* —
a quantity nestedtune never computes and, per GP5, will not.

## Open questions

- Whether anything after 2010 settles §10.5 for the *tuned* case. This shelf now
  holds two post-2010 CLTs for CV (`bayle2020.md`, `austern2020.md`), and neither
  admits a tuning step inside the algorithm; so the survey's open problem may be
  closed for plain CV and still open for double cross — observed 2026-07-31.
- What §§3, 6, 8 and 9 contain beyond what is summarized here — in particular §9
  on closed-form formulas, which may name algorithms whose CV estimate is exact
  and cheap, and §8.1 on dependent observations, which would bear on whether
  nestedtune should say anything about time-series designs. Skimmed only —
  observed 2026-07-31.
- Whether the survey's estimation/identification split has any consequence for
  the package's surface. nestedtune reports an estimate and records what was
  selected; it never claims to identify a best algorithm. Whether that needs
  saying in documentation is unasked as of 2026-07-31.
