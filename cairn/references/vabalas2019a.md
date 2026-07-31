# vabalas2019a — the bias survives to n = 1000, and leaky feature selection hurts more than leaky tuning

**Citation.** Vabalas, A., Gowen, E., Poliakoff, E., & Casson, A. J. (2019).
Machine learning algorithm validation with a limited sample size. *PLoS ONE*,
14(11), e0224365. doi:10.1371/journal.pone.0224365. University of Manchester
(Electrical & Electronic Engineering; Biological Sciences). Received 9 May
2019, accepted 12 October 2019, published 7 November 2019. Open Access
(CC-BY).

**Provenance.** Ingested 2026-07-31 from `sources/vabalas2019a.pdf`
(gitignored), publisher PDF, 20 pages.
Pagination: PDF page N = article page N (the PDF's own "N / 20" footers).
Extraction: `pdftotext -layout`, full text read. **Figures 1–8 are images and
were not read**; this matters more here than on most shelf pages, because
*every* accuracy curve in this paper lives in a figure and the prose prints
almost no accuracy values. What is quoted below as a number is either a
correlation, a p-value range, or one of the four approximate values the prose
states in words — observed 2026-07-31. The `a` suffix in the citekey
disambiguates this paper from the authors' other 2019 output; no `vabalas2019b`
is on the shelf as of 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology note

**"Nested CV" here is ours, extended.** Ten-fold outer, and inside each outer
fold *both* feature selection and hyper-parameter tuning are redone from
scratch (p. 10): "each time developing a new model for training until all the
data is used." That is `varma2006.md`'s construct with `zhong2020.md`'s feature
selection folded into the same inner loop — which is the right way to read the
two of them together.

The paper's own coinage is **partially nested CV**, and it is the useful
contribution to this shelf's vocabulary: nesting *one* development step while
leaving another outside the loop. It comes in two flavours here, and the figure
legends name them by what *is* nested — "Parameter tuning nested" means feature
selection leaked, "Feature selection nested" means tuning leaked. Read the
legends carefully; the naming is the opposite of what a quick glance suggests.

## What it establishes

**Result 1 — K-fold CV's optimism does not wash out at realistic sample sizes.**
On pure Gaussian-noise data where chance is 50% by construction, K-fold
accuracies sat "considerably higher than the theoretical chance level of 50%"
across the whole range, and "the difference was still evident even at the
sample size of N = 1000" (p. 10). This is the paper's headline and its
extension of `varma2006.md`, which fixed n at 40 and so could not say whether
the effect was a small-sample artefact. It is not.

**Result 2 — nested CV and a train/test split are both unbiased, at every
sample size.** Neither differed significantly from 50% at **96.5% of sample-size
points**, for both algorithm pipelines, p ranging from 4.3 × 10⁻⁴ to 0.997
(p. 10) — with the paper noting that a few significant points are expected by
chance at 95% confidence. Nesting buys correctness; it does not buy it back
only for small n.

**Result 3 — leaky feature selection costs far more than leaky tuning.** The
two partially-nested cells separate cleanly (pp. 10–11):

- Feature selection outside the loop, tuning nested → biased at **every** sample
  point, both pipelines (p from 1.1 × 10⁻⁴² to 6.3 × 10⁻²⁰ for SVM; 1.7 × 10⁻³³
  to 1.7 × 10⁻²² for logistic regression).
- Tuning outside the loop, feature selection nested → "curves approached 50%",
  significantly above chance at **56%** of sample points for the SVM pipeline
  (p 2.8 × 10⁻⁵ to 0.879) and at **2%** — one point — for logistic regression
  (p 0.039 to 1.0).

Their own summary (p. 11): nesting feature selection "is paramount for
controlling overfitting, while nesting parameter tuning has a smaller effect."
**The paper immediately qualifies its own headline**, and the qualification is
the part worth carrying: where feature selection is absent or relied on less,
they say, tuning could contribute more — and their own pipelines leaned on
selection heavily, cutting 50 features to 10 (p. 11).

**Result 4 — grid size and inner fold count are themselves bias knobs, for some
learners.** At fixed n = 100 (Figs 4–5, curves unread; direction from prose,
pp. 11–12): larger tuning grids raised K-fold accuracy for SVM-RBF but had "no
such effect" for logistic regression; more inner CV folds raised it for SVM-RBF
"up to approximately 20 folds when the effect levelled off", again with no
effect for logistic regression. Feature count raised it for both.

**Result 5 — feature-to-sample ratio predicts overfitting better than n
alone.** Ratios of 1/3, 1/2, 1, 2, 3, 10, 20 held while n moved from 42 to 446;
higher ratios gave higher K-fold accuracies throughout (Fig 6, unread;
pp. 12–13). *(The prose gives the sweep as 42–446 on p. 12 and the Fig 6
caption gives 14–446; recorded as printed, and neither is used above.)*

**Result 6 — on discriminable data the three methods separate differently.**
Nested CV and train/test split agreed at 96% of sample points (p 0.039–0.995)
and both traced an ordinary learning curve, levelling off "when sample size
reached approximately N = 700 at ≈ 77% accuracy" (p. 13). K-fold sat
significantly above nested throughout (p 1.3 × 10⁻⁶ to 5.4 × 10⁻³⁵) and its
curve "was not of the typical learning curve shape." The gap between K-fold and
nested was **larger on noise than on discriminable data** (p. 16) — the less
signal there is, the more the validation scheme matters.

**Result 7 — K-fold's interval width is non-monotone in n.** Confidence
intervals shrank with n for nested and train/test, but for K-fold they *widened*
up to n ≈ 60 before shrinking, "caused by a high frequency of perfect
classification (100%) occurrences at sample sizes below 60" (p. 13).

## Extracted values

Literature survey (pp. 3–4), 55 studies applying ML to autism classification,
search through 18 April 2019:

| Quantity | Value |
|---|---|
| Studies retained | 55 (Web of Science 27, Science Direct 9, Google Scholar 10, other 9) |
| Median sample size | 80 |
| Sample size normality, untransformed | D(55) = 0.28, p < 0.001 |
| Sample size normality, log₁₀ | D(55) = 0.12, p = 0.06 |
| log₁₀(N) vs reported accuracy | r(53) = −0.70, p < 0.001; R² = 0.49 |
| Spearman, untransformed | r(53) = −0.67, p < 0.001 |
| Brain imaging subset | r(39) = −0.64, p < 0.001 |
| Motion tracking subset | r(3) = −0.61, p < 0.271 *(printed as "p < 0.271")* |
| Other modalities | r(7) = −0.90, p = 0.001 |

Simulation design (pp. 7–10): standard-normal features, two balanced classes,
50 features reduced to 10 by selection, n from 20 to 1000, **50 runs** per
sample point, accuracy as the metric, 10-fold everywhere (inner tuning grid
search also 10-fold). Two pipelines: SVM-RFE + SVM-RBF (C = 2ʲ, j = 1…7;
γ = 2ⁱ, i = −1…−7) and two-sample t-test + logistic regression (L1/L2 penalty,
C = eⁱ, i = 0…9). Discriminable data: 40 of 50 features noise, 10 features
shifted by 0.5 SD in one class.

Illustrative micro-example (pp. 14–15), n = 10, two features, 1000 repeats:
the model trained on pooled train+validation data reached **81%** mean accuracy
on the two validation points; the model that never saw them reached **50%**.

Code: Python simulation source is published as **S1 File** (`.py`) with the
article. It is not on this shelf — only the PDF is — observed 2026-07-31.

**One framing overstatement, recorded.** The abstract and conclusion say nested
CV produces "unbiased" estimates without qualification, but the design cannot
distinguish unbiased from *slightly* biased: the test is a per-sample-point
one-sample t-test against 50% with 50 runs, and the paper reports only how many
points reached significance. `varma2006.md` measured a genuine +4.2-point
upward residual from the N − 1 training-size effect under a comparable design;
nothing here would have detected it. Read "unbiased" as "no detectable
deviation at this power".

## Bearing on nestedtune

- **The strongest available answer to "isn't this just a small-n problem?"**
  Result 1 is the citation for why nested CV is not a niche precaution for
  n = 40 datasets. It belongs in the package's introductory documentation
  alongside `varma2006.md`, which alone leaves the sample-size question open.
- **Result 3 is the best empirical argument for the workflows path (G3), and it
  cuts both ways.** The failure mode the paper measures — selection done once,
  upfront, on all the data, with only tuning nested — is *structurally
  impossible* when preprocessing lives in a `recipe` inside the `workflow` that
  `nested_tune_grid()` hands to `tune`, because the recipe is re-estimated on
  each analysis set. That is IP1's "not preprocessing" clause, and this is the
  paper that measures what violating it costs. But the same result says the
  tuning half of the loop — the half nestedtune exists to orchestrate — is the
  *smaller* contributor in their setup. The package's own docs should say so
  rather than let the reader assume the loop is doing all the work.
- **Direct support for GP3.** A user who does feature selection before calling
  `nested_tune_grid()` gets exactly the "Parameter tuning nested" cell:
  biased at every sample size, with a perfectly healthy-looking results object.
  Nothing in the package can currently detect that — the leak happened before
  the data arrived. Whether that deserves a documented warning is a design
  question this page does not answer.
- **Grid size as a bias knob has an M21 consequence.** Result 4's finding that
  a bigger tuning grid raises the optimism of a non-nested estimate is the
  empirical form of `varma2006.md`'s eq. (8). M21 already records the grid each
  fold actually evaluated (the evaluated-grid record); this page is the reason
  that record is worth more than provenance — grid size is a quantity that
  changes the meaning of a naive estimate, so IP4's "no estimate is reported as
  though it came from a design that did not run" has a measured motivation, not
  only a hygienic one.
- **A caution about inner fold count that the package has not tested.** More
  inner folds raised the non-nested optimism for SVM-RBF up to ~20 folds
  (Result 4). nestedtune has no opinion on inner `v` today. Nothing here says
  the *nested* estimate moves with inner `v` — the effect is measured on K-fold
  alone — so this is a question to keep, not a default to change.
- **Bears on G6 sideways, and unhelpfully.** Result 7 says the K-fold interval
  width is not even monotone in n below n ≈ 60, and the paper's only advice on
  intervals is to resample the fold assignment repeatedly (p. 16) — which is
  precisely the workaround `bengio2004.md` forecloses for variance estimation.
  Nothing here moves the three G6 blockers.

## Oracle status

**No usable oracle value, one oracle *design* already on the shelf, and one
reference implementation that is not in hand.**

The invariant is the same 50%-chance line as `varma2006.md`,
`ambroise2002.md`, and `tibshirani2009.md` Theorem 1 — GP2 type (4). This paper
adds nothing new to its *form*; what it adds is the range over which it holds
(n up to 1000) and the finding that at large n the separation to be detected
shrinks. As a fixture design that is a strike against it, not for it: the
cheapest place to see the effect is small n and high feature-to-sample ratio,
which agrees with `tibshirani2009.md`'s p ≫ n finding.

**No accuracy value on this page is quotable as an oracle**, because every
number that would serve is in an unread figure. The four approximate values the
prose does state (≈77% plateau, n ≈ 700, n ≈ 60, 81% vs 50%) are either
qualitative or from the toy example.

The Python S1 File would be GP2 type (2), a reference implementation in another
language — the only candidate of that type this shelf has found so far. It is
not on the shelf and has not been retrieved or run — observed 2026-07-31.

## Open questions

- What the actual K-fold-versus-nested accuracy gap is at each sample size.
  The whole quantitative core of the paper is in Figs 3, 6 and 7, which were
  not read; the prose gives significance, not magnitudes — observed
  2026-07-31.
- Whether the S1 File reproduces, and whether its nested implementation agrees
  with `nested_tune_grid()` on the same fixture. Not retrieved — observed
  2026-07-31.
- Whether the "nesting tuning matters less" finding survives when feature
  selection is absent entirely. The paper flags this as the limit of its own
  claim (p. 11) but never runs that cell, and it is exactly nestedtune's case
  when a workflow has no filter step — observed 2026-07-31.
- Whether the inner fold-count effect (Result 4) exists for the *nested*
  estimate or only for the flat one. Measured only under K-fold — observed
  2026-07-31.
