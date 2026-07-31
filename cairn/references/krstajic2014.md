# krstajic2014 — a nested CV estimate belongs to a (model, protocol) pair

**Citation.** Krstajic, D., Buturovic, L. J., Leahy, D. E., & Thomas, S. (2014).
Cross-validation pitfalls when selecting and assessing regression and
classification models. *Journal of Cheminformatics*, 6:10.
doi:10.1186/1758-2946-6-10. Received 2014-01-06, accepted 2014-03-25,
published 2014-03-29. Open Access (CC BY 2.0).

**Provenance.** Ingested 2026-07-31 from `sources/krstajic2014.pdf` (gitignored),
publisher PDF, 15 numbered pages + 1 trailing.
Pagination: PDF page N = article page N ("Page N of 15"), so anchors are both.
Extraction: `pdftotext -layout`, full text read. Figures 1–16 are images and were
**not** read; every figure claim below comes from a caption or the prose — the
one numeric range attributed to a figure (bbb2, ~0.13–0.23) is stated in the
Discussion text, not read off the plot — observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology, which this paper is the best source on

It is the only source on this shelf that untangles the naming, and it does so
carefully (p. 3, p. 5):

- **Nested cross-validation** = Varma & Simon's (2006) model-*assessment*
  procedure, which the paper identifies as the same thing Stone (1974) called
  cross-validatory assessment of the cross-validatory choice. **This is
  nestedtune's construct.**
- **Double cross-validation** = Stone's model-*selection* procedure, where an
  internal CV tunes for each candidate variable set (Algorithm 4, p. 5).
- Both differ again from `bates2023.md`'s NCV (a variance-estimation device) and
  from `zhong2020.md`'s (an inner feature-selection loop).

## What it establishes

**Four named pitfalls** (p. 2), the paper's spine:

1. Selecting variables prior to, and not within, cross-validation.
2. Selecting a model on the performance of a *single* cross-validation.
3. Reporting a cross-validation error as an estimate of error.
4. Reporting a *single* nested cross-validation error as an estimate of error.

**The central conceptual contribution — the P-estimate** (p. 3, elaborated
p. 12). A nested CV estimate is not a property of the selected model. It is a
property of the model *and* the cross-validation protocol P that selected it,
where P = the grid, the number of folds, and the number of repeats. Two
protocols that happen to select the same model will in general yield different
P-estimates, because they scanned different regions of hyperparameter space.
The paper argues this is not a defect but a fact that must be recognized to
interpret the result at all.

**Algorithms.** Algorithm 1 (p. 3), repeated grid-search V-fold CV for tuning,
carries a tie-break worth noting: among α values with minimal average loss,
take the one with **lowest model complexity**. Algorithm 2 (p. 3–4) is repeated
stratified nested CV for assessment, and its step 3 is the reporting rule — the
min–max interval over the outer repeats is the P-estimated interval; the mean is
the P-estimate. Algorithm 3 (p. 4) handles variable selection and tuning
together on a joint (n, α) grid in one CV loop.

**Argument against double CV when tuning affects complexity** (p. 5): in
double CV's outer loop a different α may be chosen for each training subset, so
for a fixed variable count you end up averaging over models of differing
complexity. A joint grid cannot do this, because each grid point fixes both.
They used grid search throughout.

**Stratification stance** (p. 2): with many repeats, stratification becomes
redundant for *selection*; keep it for *assessment*. Stated as their compromise,
and they note there is no consensus.

## Extracted values

Settings: V1 = V2 = 10, Nexp1 = Nexp2 = 50 (p. 4). Seven QSAR datasets from the
`QSARdata` R package, nine dataset/method combinations (p. 7). Loss: sum of
squared residuals (regression), proportion misclassified (classification).

| Where | Finding | Value |
|---|---|---|
| Table 2, p. 8 | optimal parameter chosen by 50 *single* CVs, PLS on AquaticTox | components 10–15; frequencies 1, 9, 9, **23**, 6, 2 |
| Table 2, p. 8 | same, ridge logistic on PLD | λ mass at both ends: 10 runs at ≤0.34, **19** at ≥1.17 |
| Table 3, p. 11 | chosen models | AquaticTox PLS 13 comps (loss 0.5948) / ridge λ=0.05325 (0.5767); MeltingPoint PLS 47 comps (45.5848) / ridge λ=0.0549 (45.4370); bbb2 ridge λ=0.10494 (0.1689); Mutagen ridge λ=0.003142 (0.1889); PLD ridge λ=1.02431 (0.1768) |
| Discussion, p. 12 | spread of nested CV error, bbb2 | proportion misclassified ≈ **0.13 to 0.23** across repeats |
| p. 13 | grid density changes the chosen model | coarser grid (5..60 step 5) picks 15 components on AquaticTox vs 13, and 50 on MeltingPoint vs 47 — i.e. a **more complex** model |
| p. 9 | Algorithm 3 worked example, Mutagen | 21 × 6 = 126 grid points; best mean misclassification **0.196** at n = 450 descriptors, C = 8 |
| p. 13 | compute | 50 × 10-fold nested CV = 500 full model-selection runs, each itself 50 × 10-fold CV |

**The 1 SE rule breaks under repetition** (p. 11): repeating cross-validations
shrinks the standard error, so Breiman's/Hastie's one-standard-error rule stops
having any effect. The authors say it needs redefining in a repeated-CV context
and do not propose the redefinition.

Also (p. 5): unsupervised screening — near-zero-variance filtering, dropping
linear combinations — is, in their opinion, legitimately done *before* the CV
loop, unlike supervised variable selection. They flag Zhu et al. as contesting
even this.

## Bearing on nestedtune

- **The P-estimate is IP4, stated in the literature.** "The estimate describes
  the design actually executed" and "a nested CV estimate is a property of the
  (model, protocol) pair" are the same claim. This is the strongest external
  corroboration on the shelf for an inviolable principle, and it also justifies
  the M21 work: recording the grid a run actually searched is what makes the
  protocol half of the pair legible. The paper's own grid-density finding
  (p. 13) is the sharp version — change the grid, get a different model.
- **Pitfall 4 argues for repeated outer resampling.** Their conclusion is that
  no single nested CV run is usable for assessment because of its variance, and
  the reporting unit should be an interval over repeats. nestedtune inherits
  whatever `outside` the user passes, so `vfold_cv(repeats = )` presumably
  reaches this — **unverified**; and the package has no repeat-aware summary,
  since `collect_metrics()` aggregates fold means with a naive `std_err`. Left
  as an open question below rather than a candidate row, because the fix shape
  is unknown until the aggregation question is settled.
- **The 1 SE observation touches selection.** `nested_fold_fit()` uses
  `tune::select_best()` (`R/nested-tune-grid.R:369`). tidymodels also offers
  `select_by_one_std_err()`, and this paper says that rule loses its meaning
  under repetition. Not an argument to change the default — just the reason a
  future selection knob would need a caveat.
- **Their stratification split (none for selection, yes for assessment)** is a
  configuration question this package deliberately does not own: the user builds
  both schemes. Worth knowing when documenting what `outside`/`inside` should be.

## Oracle status

**No oracle for computed results, one candidate fixture.** The values in Table 3
are dataset-and-protocol specific and depend on `glmnet`/`pls` versions, so they
are not reproducible reference values in GP2's sense. What the paper *does*
supply is a public data source: the `QSARdata` CRAN package, named at p. 6 with
per-dataset preprocessing steps and post-preprocessing descriptor counts
(Table 1, p. 6 — AquaticTox 322/184, bbb2 79/22, Caco-PipelinePilotFP 3796/379,
Caco-QuickProp 3796/47, MeltingPoint 4126/169, Mutagen 4335/1283, PLD 324/308).
That is a fixture lead, not an oracle. Recorded so the distinction is not lost.

## Open questions

- Whether `nested_tune_grid()` accepts a repeated outer scheme
  (`rsample::vfold_cv(repeats = R)`) end to end, and what `collect_metrics()`
  does with it — a repeat-aware object would aggregate within repeat first.
  Unverified by execution as of 2026-07-31.
- What the redefined 1 SE rule should be under repetition — the paper poses the
  question (p. 11) and answers it nowhere; unresolved in the literature as far
  as this source shows.
- Whether reporting a min–max interval over outer repeats (their Algorithm 2
  step 3) is defensible under GP5, or whether it is the kind of unsettled
  inference the package declines. The interval is a descriptive range, not a
  confidence interval, which may put it on the permitted side — unexamined.
