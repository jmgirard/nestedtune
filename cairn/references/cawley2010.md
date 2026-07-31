# cawley2010 — model selection over-fits too, and the protocol that hides it is biased

**Citation.** Cawley, G. C., & Talbot, N. L. C. (2010). On over-fitting in model
selection and subsequent selection bias in performance evaluation. *Journal of
Machine Learning Research*, 11, 2079–2107. School of Computing Sciences,
University of East Anglia. Editor: Isabelle Guyon. Submitted 10/09, revised
3/10, published 7/10.

**Provenance.** Ingested 2026-07-31 from `sources/cawley2010.pdf` (gitignored),
JMLR PDF, 29 pages. Pagination: PDF page N = journal page 2078 + N.
Extraction: `pdftotext -layout`, full text read. Tables 1–8 extracted cleanly
and are reproduced or summarized below. **Figures 1–14 are images and were not
read**; every figure claim below comes from its caption or the prose — observed
2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology note

**This paper names our construct and cites Stone for it.** p. 2080: "robust
unbiased performance evaluation is likely to require more rigorous and
computationally intensive protocols, such a nested cross-validation or 'double
cross' (Stone, 1974)" — the Stone reference being the JRSS-B paper, now on the
shelf as `stone1974a.md`. Its own vocabulary for the two protocols is *internal*
(model selection re-run inside every fold — correct) and *external* (model
selection done once on all the data, then folds evaluated with fixed
hyper-parameters — biased), borrowed from `ambroise2002.md`.

_(Corrected 2026-07-31 on ingesting the cited paper. This note originally said
"credits it correctly"; the attribution is loose. Stone's "double-cross" is his
§2 item VI, a two-stage cross-validatory **choice** for a two-component α — not
the nested assessment, which is his item V and which he calls a "two-deep"
analysis. The two are adjacent and both nested, so nothing measured here is
affected, but a doc page copying this phrase would be naming the wrong item.
See `stone1974a.md`'s terminology finding.)_

## What it establishes

**Result 1 — a model selection criterion can be over-fitted, with the classic
signature.** §4, pp. 2084–2085: 1,000 realizations of a synthetic benchmark at
64 samples each, KRR with an ARD kernel, hyper-parameters tuned to minimize a
four-fold CV estimate of MSE. Averaged over realizations, the CV criterion falls
monotonically while the true test MSE falls, bottoms out "after a relatively
short time (approximately 30–40 iterations)", and then climbs "as the
hyper-parameters are tuned in ways that exploit the meaningless statistical
peculiarities of the sample". This is over-fitting at the second level of
inference, plotted exactly like over-fitting at the first.

**Result 2 — for *selection*, low variance beats unbiasedness.** §4.1,
pp. 2086–2087. Leave-one-out CV is almost unbiased, and that is routinely cited
as its virtue for model selection; the paper's answer is that unbiasedness only
guarantees that the minimum of the *expected* criterion sits at the right place,
whereas in practice one minimizes the criterion computed on one sample. A
biased criterion with lower variance can put its per-sample minima much closer
to the true optimum. Their words (p. 2086): "for the purpose of model selection,
rather than performance evaluation, unbiasedness per se is relatively
unimportant".

**Result 3 — more hyper-parameters means more over-fitting, measurably.** §4.3,
Table 2 (p. 2092): the ARD kernel is a strict generalization of the RBF kernel,
so its attainable performance is at least as good — yet across thirteen
benchmarks the plain RBF kernel gives a statistically superior test error on
most, while the ARD models simultaneously show a *lower* PRESS statistic. Lower
criterion, worse generalization, on the same data: the paper calls this "a
strong indication of over-fitting the model selection criterion". Table 3
(p. 2092) repeats it for Gaussian process classifiers selecting by Bayesian
evidence rather than CV, so the effect is not specific to cross-validation.

**Result 4 — external model selection is optimistically biased on every
benchmark tried.** §5.3, Table 8 (p. 2102), reproduced below. Ten-fold CV of
KRR-RBF, comparing a protocol that selects hyper-parameters once on the whole
design set against one that re-selects inside every fold. The external protocol
is optimistic on all thirteen benchmarks, significantly so (bias exceeding twice
its standard error) on eleven, "and so should not be used in practice".

**Result 5 — a biased protocol is not even internally consistent.** §5.2: the
widely-used "median" protocol (select on the first five realizations, take
median hyper-parameters, evaluate all realizations at those) is optimistically
biased (Table 5), and §5.2.1 shows the bias survives when all training and test
sets are made mutually disjoint, so it is not merely re-used test data — the
median is a variance-reduction step and that alone is enough. Worse, Table 7
shows the bias differs *by classifier*, significantly on five of thirteen
benchmarks, so the protocol reorders the ranking: under it RBF-KRR becomes
"statistically superior" at the 95% level to classifiers it is indistinguishable
from under an unbiased protocol (Figs 10 and 12). §5.2.2 draws the conclusion
that the median protocol "may be unreliable and perhaps should be deprecated".
Figure 14 sharpens it: the median protocol's advantage is largest exactly where
the selection criterion is worst (few splits, high variance), so "the bias
introduced by the median protocol favors most the worst model selection
criterion".

## Extracted values

Benchmark suite (Table 1, p. 2083): thirteen data sets from Rätsch et al.
(2001), each with 100 predefined training/test partitions (20 for `image` and
`splice`), training sizes 140–1300 and test sizes 75–7000. Synthetic benchmark
(§3.1, p. 2083): four spherical bivariate Gaussians, common σ² = 0.04, Bayes
error ≈ **12.38%**; a large-sample ARD-KRR fit tuned on true test MSE reached
12.50%, so model mis-specification is not the story.

Table 8, p. 2102 — 10-fold CV error rate of KRR-RBF, model selection external
versus internal to the outer loop, mean ± standard error over 100 realizations
(20 for `image`/`splice`):

| Data set | External | Internal | Bias |
|---|---|---|---|
| banana | 10.355 ± 0.146 | 10.495 ± 0.158 | 0.140 ± 0.035 |
| breast cancer | 26.280 ± 0.232 | 27.470 ± 0.250 | **1.190 ± 0.135** |
| diabetis | 22.891 ± 0.127 | 23.056 ± 0.134 | 0.165 ± 0.050 |
| flare solar | 34.518 ± 0.172 | 34.707 ± 0.179 | 0.189 ± 0.051 |
| german | 23.999 ± 0.117 | 24.217 ± 0.125 | 0.219 ± 0.045 |
| heart | 16.335 ± 0.214 | 16.571 ± 0.220 | 0.235 ± 0.073 |
| image | 3.081 ± 0.102 | 3.173 ± 0.112 | 0.092 ± 0.035 |
| ringnorm | 1.567 ± 0.058 | 1.607 ± 0.057 | 0.040 ± 0.014 |
| splice | 10.930 ± 0.219 | 11.170 ± 0.280 | 0.240 ± 0.152 |
| thyroid | 3.743 ± 0.137 | 4.279 ± 0.152 | **0.536 ± 0.073** |
| titanic | 22.167 ± 0.434 | 22.487 ± 0.442 | 0.320 ± 0.077 |
| twonorm | 2.480 ± 0.067 | 2.502 ± 0.070 | 0.022 ± 0.021 |
| waveform | 9.613 ± 0.168 | 9.815 ± 0.183 | 0.203 ± 0.064 |

Bias is defined as internal minus external, positive meaning the external
protocol is optimistic. Not significant (bias ≤ 2 SE) on `splice` and `twonorm`
only. The paper's calibration for these magnitudes: across the thirteen
benchmarks under the unbiased protocol (Table 4, p. 2096) the three classifiers
EP-GPC, RBF-KLR and RBF-KRR are separated by no statistically significant
difference at all (mean ranks 1.9231 / 2 / 2.0769, Fig. 10) — so a bias of 0.5–1.2
points is larger than the difference between competitive algorithms.

Table 5, p. 2097 — median-protocol bias for RBF-KRR, same suite: largest on
`heart` (1.010 ± 0.186) and `breast cancer` (0.351 ± 0.195); negative on
`twonorm` (−0.022 ± 0.014) and `waveform` (−0.029 ± 0.020).

Table 7, p. 2100 — Wilcoxon signed-rank comparison of the median-protocol bias
between RBF-KRR and RBF-EP-GPC: p < 0.05 on `banana`, `diabetis`, `heart`,
`ringnorm`, `twonorm`; five of thirteen.

## Bearing on nestedtune

- **This is the quantitative case for G1–G3 and G5, on realistic data.** Where
  `varma2006.md` demonstrates the bias on synthetic null data at 40 samples,
  this measures it on thirteen real benchmarks with only *two* hyper-parameters
  tuned, and finds it consistently significant and often larger than the gap
  between state-of-the-art algorithms. That is the argument for making the
  correct protocol the easy one, which is what the package exists to do.
- **Direct support for IP1.** §6: "model selection should be viewed as an
  integral part of the model fitting procedure, and should be conducted
  independently in each trial in order to prevent selection bias and because it
  reflects best practice in operational use."
- **Support for GP4, from the same conclusion.** §6 argues rigorous evaluation
  "requires a substantial investment of processor time", is "straightforward to
  fully automate", and is "well-suited to parallel implementation", so with
  multi-core hardware "there is little justification for the continued use of
  potentially biased protocols". That is nestedtune's parallel design being
  described as the thing that removes the excuse — GP4's "usable on real data is
  part of correctness", argued from the outside.
- **A warning against ever averaging hyper-parameters across folds.** §5.2 is a
  measured account of what happens when a package makes the convenient move of
  summarizing per-fold selections into one "chosen" configuration and evaluating
  against it: an optimistic bias that survives disjoint data, that favours the
  worst selection criteria, and that reorders classifier rankings. nestedtune
  records per-fold selections without collapsing them (M21, M22), and this is
  the citation for why that is not merely tidier.
- **A caveat on M20's metric set and inner-loop defaults.** §4.1's result — for
  *selection*, criterion variance matters more than criterion bias — means the
  inner loop's resampling scheme is a statistical decision, not a cost dial. It
  also means the package must not present the inner CV estimate as an error
  estimate anywhere, which is IP3 restricted to the inner loop.
- **Bears on G6 by way of the literature it cites, not new results.** p. 2094
  cites `bengio2004.md` for the absence of an unbiased variance estimator and
  quotes Kulkarni et al. (1998) that "the available theory is especially poor
  when it comes to analysing parameter selection based on minimizing the deleted
  estimate" — which is still, on the evidence of this shelf, the state of the
  question for the tuned case.

## Oracle status

**No oracle.** Every number here is a Monte-Carlo mean over benchmark
realizations for a MATLAB kernel-machine implementation the package does not
have and would not reproduce; the thirteen data sets are not in any R package
this repo depends on. What the tables give is calibration for how large the
selection bias is in practice — useful in prose, not as a value a test can pin.

## Open questions

- Whether the internal-versus-external gap of Table 8 has the same magnitude for
  tidymodels' usual engines and grid sizes. The paper tunes exactly two
  continuous hyper-parameters by Nelder–Mead on a closed-form LOO criterion; a
  `tune_grid()` user searches a discrete grid of a handful of candidates, and
  `varma2006.md` eq. (8) says the candidate count is what drives the bias.
  Unmeasured as of 2026-07-31.
- What the over-fitting curves of Figs 2, 5–9 and 14 actually look like, unread
  for the reason in Provenance. Figure 14 in particular carries the claim that
  the median protocol most favours the worst criterion, which is quoted above
  from prose alone — observed 2026-07-31.
- Whether the remedies §4.4 lists for over-fitting *in* model selection —
  regularizing the selection criterion, early stopping, hyper-parameter
  averaging — have any expression in a nestedtune design. All of them change
  what the inner loop does, which is `tune`'s territory under GP1, so the answer
  is probably "not ours"; unasked as of 2026-07-31.
