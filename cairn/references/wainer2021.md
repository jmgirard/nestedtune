# wainer2021 — nested CV is overzealous for *choosing an algorithm*

**Citation.** Wainer, J., & Cawley, G. (2021). Nested cross-validation when
selecting classifiers is overzealous for most practical applications.
*Expert Systems With Applications*, 182, 115222.
doi:10.1016/j.eswa.2021.115222. Received 2019-12-21, accepted 2021-05-14.

**Provenance.** Ingested 2026-07-31 from `sources/wainer2021.pdf` (gitignored),
publisher PDF, 10 numbered pages + 1 trailing blank.
Pagination: PDF page N = article page N throughout, so anchors below are both.
Extraction: `pdftotext -layout`, full text read. Figures 1–6 are images and were
**not** read — every figure claim here is taken from the surrounding prose or
from a table, never from a plot. Reproduction materials at
doi:10.6084/m9.figshare.3457238, not retrieved — observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## What it establishes

The paper's target is **algorithm selection**, not error reporting. It compares
two procedures for picking a classifier: *nested CV* (inner tunes, outer scores)
and what it names *flat CV* (one CV both tunes and scores, then the tuned score
selects the algorithm). Its finding is that the algorithm flat CV picks is, for
practical purposes, as good as the one nested CV picks — so the nested compute is
usually not repaid **for that decision**.

It does **not** dispute the estimand argument. p. 2 states the standard position
it is arguing around: the nested estimate is unbiased for
E<sub>g∼D</sub>[ac(g|a, G, θ̂<sub>a</sub>)] (Eq. 3) while the flat estimate carries
a positive bias (citing Cawley & Talbot 2010). Its case is that for *ranking*
algorithms the bias mostly cancels — explicitly conditional on the bias being
"approximately the same for all classifiers" (p. 2).

Design (p. 3, p. 5): 115 binary UCI datasets (the Fernández-Delgado et al. 2014
suite as processed by Wainer 2016), 12 algorithm families, 6 repetitions of a
stratified 50/50 split. Per repetition: 5-fold-within-5-fold nested CV vs 5-fold
flat CV. The 9 datasets over 10,000 rows were subsampled to 5,000.

Method note (p. 4): rather than a fixed effect-size threshold, each dataset gets
its own **irrelevance threshold** δ(i) — the smaller of the two gaps between the
nested estimate and measured future accuracy for the two selected algorithms,
averaged over the 6 repetitions (Eqs. 11–13). The claim tested is |accgain(i)| <
δ(i) by one-sided Wilcoxon signed-rank; 95% CIs from 5000 bootstrap rounds.

## Extracted values

| Where | Quantity | Value |
|---|---|---|
| Table 2, p. 6 | top-3 scenario: flat and nested pick the same algorithm | **71%** (chance 33%); p = 0.001; median \|accgain\|−δ = −0.001, CI [−0.002, 0.0] |
| Table 2, p. 6 | full 12-algorithm scenario | **62%** (chance 8%); p = 3.6e−06; median −0.001, CI [−0.002, −0.001] |
| Table 3, p. 6 | top-3 under AUC / F1 | 76% / 78% agreement; both p = 0.0001 |
| Table 4, p. 7 | 32 datasets with ≥2000 rows | top-3 80% (p = 0.00158), full 71% (p = 0.0108) |
| Table 6, p. 8 | distribution of δ(i) | min 0.00%, Q1 0.11%, **median 0.41%**, mean 0.89%, Q3 1.17%, max 8.06% |
| Table 1, p. 6 | mean rank under the **nested** estimate | rf 3.4, svmRadial 3.6, gbm 4.0, nnet 4.8, rknn 5.3, svmPoly 5.3, knn 5.4, svmLinear 6.1, sda 6.6, lvq 6.7, nb 7.9, bst 8.7 |
| Table 5, p. 8 | mean rank under the **flat** estimate | gbm 3.0, svmRadial 3.2, rf 4.0, nnet 4.1, rknn 4.2, svmPoly 5.2, knn 5.3, lvq 6.4, svmLinear 6.4, sda 7.0, nb 8.4, bst 8.6 |
| App. C, p. 9 | skip selection entirely, always use rf | agreement 28%, p = 1.0, mean gain 0.002, CI [0, 0.004] — **above** the threshold |

Two of those rows matter more than the headline. **Table 1 vs Table 5**: the two
procedures produce sharply different *full rankings* — gbm is 1st under flat and
3rd under nested; rf is 1st under nested and 3rd under flat. The authors
attribute this to gbm carrying one more hyperparameter than rf or svmRadial
(p. 9). And **Appendix C**: dropping algorithm selection altogether is *not*
harmless, so the paper argues against nested CV for one decision, not against
model selection in general.

## Stated limits (p. 7, p. 9)

The authors bound their own claim, and the bounds are the load-bearing part for
this package:

- Only binary, only medium-sized (≤100,000 rows), none from text classification
  (high dimensionality, high sparsity).
- Every algorithm tested had **1 to 3 hyperparameters**. The paper says
  explicitly it is less confident where counts differ sharply (ARD kernels,
  multi-layer nets, deep networks, XGBoost), citing Cawley & Talbot 2010's
  ARD LS-SVM result: nested selection favoured the plain RBF LS-SVM in 7 of 13
  datasets against 1 for ARD, while flat CV preferred ARD.
- The claim covers the **best-ranked algorithm only**, not the ranking.
- Results apply to a practitioner choosing a model, and — stated in the paper —
  not to a scientist arguing one algorithm beats another.

## Bearing on nestedtune

- **It does not undercut the package's premise, and saying so needs care.** The
  contract boundary in `DESIGN.md` is estimating the performance of a
  tune-and-fit procedure, which is IP3's subject. Wainer & Cawley leave that
  estimand alone (p. 2) and argue only that the *argmax over algorithms* is
  usually the same either way. A user who wants a number to report is not the
  user this paper addresses.
- **Direct support for the selection-instability convention.** Table 1 vs
  Table 5 is published evidence that flat and nested procedures disagree about
  the ranking. `DESIGN.md`'s "inner-loop selection stability is first-class"
  convention is the same instinct one level down (folds disagreeing rather than
  procedures disagreeing).
- **A documentation obligation, not a scope change.** The honest caveat this
  source creates is: if all you want is to pick among a few low-hyperparameter
  algorithms, this package may be more machinery than the decision needs. IP3
  already carries an obligation to say what a user should report instead; this
  is the same sentence from the other side. Not filed as a candidate — it is
  prose in a vignette, not work.
- The 1–3 hyperparameter bound is what keeps the finding narrow: a tidymodels
  user tuning a boosted tree over 4+ parameters is outside the tested regime.

## Oracle status

**No oracle.** Nothing here is a per-fold or per-split worked value that a test
could pin. The agreement rates (71%/62%/76%/78%) are properties of a 115-dataset
study, not of an implementation, and reproducing them is a research project, not
a unit test. Recorded so a later reader does not mistake the table above for
oracle material — see `GP2` and the oracle convention in `DESIGN.md`.

## Open questions

- Whether the flat/nested ranking divergence (Tables 1 and 5) reproduces at the
  *fold* level inside one dataset, which is the scale this package operates at —
  the paper measures across datasets only — unexamined as of 2026-07-31.
- The figshare reproduction bundle (doi:10.6084/m9.figshare.3457238) holds the
  R analysis scripts and per-run results; not retrieved, so whether any
  per-dataset value there could seed a fixture is unknown — observed 2026-07-31.
