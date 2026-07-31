# ambroise2002 — external versus internal cross-validation, and the no-information check

**Citation.** Ambroise, C., & McLachlan, G. J. (2002). Selection bias in gene
extraction on the basis of microarray gene-expression data. *Proceedings of the
National Academy of Sciences*, 99(10), 6562–6566.
doi:10.1073/pnas.102102699. Laboratoire Heudiasyc UMR CNRS 6599, Compiègne, and
Department of Mathematics, University of Queensland. Edited by Stephen E.
Fienberg; received 20 February 2002, approved 21 March 2002.

**Provenance.** Ingested 2026-07-31 from `sources/ambroise2002.pdf`
(gitignored), publisher PDF, 5 pages, downloaded 2026-07-31 per the PDF's own
stamp. Pagination: PDF page N = article page 6561 + N.
Extraction: `pdftotext -layout`, full text read; the two-column layout
interleaves in places and every quoted sentence below was checked to read
continuously. **Figures 1–5 are images and were not read** — the paper's
results live in those five figures, so every number below comes from the prose
that describes them, and the figures hold values this note does not have —
observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology note

**The tuned step here is feature selection, not a hyper-parameter.** The paper's
vocabulary is *internal* versus *external* cross-validation, not "nested": an
external CV re-runs the gene-selection procedure inside every fold, an internal
one selects once on all the data and then cross-validates the classifier alone.
Structurally that is the same construct as nestedtune's — the whole training
algorithm, not its last step, is what gets resampled — applied to a different
inner decision. `zhong2020.md` uses "nested CV" for this same feature-selection
shape; `cawley2010.md` adopts *internal/external* from here (p. 2080, "essentially
analogous to the selection bias observed by Ambroise and McLachlan (2002)") and
carries it to hyper-parameters.

## What it establishes

**Result 1 — selecting features on all the data then cross-validating gives a
near-zero error that means nothing.** Two published data sets, both standard at
the time: colon (Alon et al.), n = 62, p = 2,000, 40 tumour and 22 normal;
leukemia (Golub et al.), n = 72, p = 7,129, 47 ALL and 25 AML. With forward
selection for Fisher's linear discriminant, the internal leave-one-out error
CV1IE bottoms out at 6.5% on three genes for colon and at **zero** on three
genes for leukemia, while the external 10-fold error CV10E and the .632+
bootstrap sit at ≈15% and ≈5% respectively (pp. 6565, §*Forward Selection with
Fisher's Rule*). The same pattern holds for SVM with recursive feature
elimination.

**Result 2 — a test set is not a defence if it was used for selection.** The
Discussion (p. 6566) is explicit: "if a test set is used to estimate the
prediction error, then there will be a selection bias if this test set was used
also in the gene-selection process. Thus the test set must play no role in the
feature-selection process for an unbiased estimate to be obtained." Their
worked case is Xiong et al., whose reported 10.7% and 0% test errors for a
three-gene rule came from splits of a sample already used whole for selection
(p. 6564).

**Result 3 — the no-information experiment.** §*Discussion*, p. 6566: 20 data
sets were made by randomly permuting the class labels of the colon tissues, so
the features are independent of the labels by construction. An SVM with RFE then
achieves "not only an average zero AE but also an average CV1IE error close to
zero for a subset of 128 genes and ≈10% for only eight genes", while the
corrected estimates CV10E and B.632+ land "between 0.40 and 0.45, consistent
with the fact that we are forming a prediction rule on the basis of a
no-information training set."

**Result 4 — a recommendation about which resampling scheme.** The abstract
recommends "using 10-fold rather than leave-one-out cross-validation" because
LOO, though nearly unbiased, "can be highly variable" and proved so here
(p. 6563). For the bootstrap they recommend B.632+ (defined at eqs. 1–3,
p. 6563) because it is designed for overfitted rules. Comparing the two
corrections: CV10E "has little bias for both data sets" while B.632+ "is more
biased" on colon, yet B.632+ "was found to have a slightly smaller root mean
squared error than CV10E for the selected subsets of both data sets" (p. 6564).

## Extracted values

All from prose describing Figs 1–5; the figures themselves are unread.

| Where | Setting | Uncorrected (internal) | Corrected (external) |
|---|---|---|---|
| p. 6565, Fig. 3 | colon, Fisher + forward selection | CV1IE 6.5% at 3 genes | CV10E ≈15% beyond 7 genes |
| p. 6565, Fig. 4 | leukemia, Fisher + forward selection | CV1IE 0% at 3 genes | CV10E and B.632+ ≈5% |
| p. 6564, Fig. 1 | colon, SVM + RFE, 50 splits into 31/31 | — | test error >15% for every subset; lowest 17.5% at 26 genes |
| p. 6564, Fig. 2 | leukemia, SVM + RFE, 50 splits into 38/34 | — | selection bias ≈5% |
| p. 6566, Fig. 5 | colon with **permuted labels**, 20 sets, SVM + RFE | AE 0; CV1IE ≈0 at 128 genes, ≈10% at 8 genes | CV10E and B.632+ between **0.40 and 0.45** |

Further, p. 6564: repeating the SVM/RFE comparison on all available samples
(62 and 72, roughly twice the training size) gave a smaller estimated bias,
"between 10 and 15% for the colon data set and between 2 and 3% for the leukemia
data set". Bootstrap settings: K = 30 replications for each of the 50 splits.
For Fisher's rule the gene pool was pre-screened to the top 400 by average
maximum posterior probability, a step the paper concedes "will incur some
(small) bias, which we shall ignore" (p. 6565).

**One caveat the paper raises against its own colon result** (p. 6565): six
colon tissues have labels in doubt; deleting them drove the estimated selection
bias to "almost zero", which the authors read as unsurprising rather than
reassuring — "if all tissue samples that are difficult to classify are deleted,
then the rule should have a prediction error that is close to zero regardless of
the selected subset of genes."

## Bearing on nestedtune

- **IP1, stated as a rule about test sets.** The Discussion's requirement — the
  assessment data must play no role in *any* training step, selection included —
  is IP1's clause about the outer assessment set, from the applied literature.
  The paper's contribution over `varma2006.md` is that it also closes the
  loophole of "but I held out a test set": a held-out set contaminated by a
  selection step run on the full sample is no better than an internal CV.
- **The permuted-label check is the cheaper cousin of varma2006's null data.**
  Where `varma2006.md` simulates null features, this permutes the labels of a
  real data set, which is a construction any test fixture can perform without a
  generative model. The published expectation is that a correct external
  estimate lands near the no-information error while an internal one lands near
  zero. See Oracle status.
- **A caution about reading 0.40–0.45 as "chance".** The colon data is 40/22, so
  the majority-class rule alone errs at 22/62 ≈ 0.355; the paper reports the
  corrected estimates against its own estimated no-information rate γ (eq. 3,
  p. 6563), not against 0.5. Any invariant test built on this shape has to
  compute the chance level from the fixture's class balance rather than assume
  a half.
- **Scheme choice is a user decision, and this is a citation for it.** The
  10-fold-over-LOO recommendation is about the bias/variance trade of the
  *outer* scheme; nestedtune takes the scheme from the user's `nested_cv()`
  design and refuses to pick for them, which GP3 supports. The citation belongs
  in documentation prose, never in a default.
- **Nothing here bears on G6.** No variance statement and no interval; the one
  interval-shaped object in the paper is the 95% confidence limits drawn on the
  test-error curves of Figs 1–2, which are error bars on a Monte-Carlo mean over
  50 splits, not inference on a CV estimate.

## Oracle status

**No oracle value; one invariant shape, weaker than varma2006's.** The permuted-
label construction is a legitimate GP2 type-(4) invariant and is cheap to build
from any classification fixture. But the published numbers (0.40–0.45) are
specific to the colon data, its class imbalance, an SVM with RFE, and 20
permutations — none of which a nestedtune test would reproduce — so they are not
reference values in the type-(2) sense. What transfers is the direction, not the
magnitude. Recorded, not claimed.

## Open questions

- What the corrected and uncorrected curves actually do across the full range of
  subset sizes, which is the content of Figs 1–5 and is unread. The prose
  reports only the extrema and the crossing points — observed 2026-07-31.
- How the 0.40–0.45 corrected estimate relates to the paper's own estimated
  no-information rate γ for the permuted colon data; γ is defined (eq. 3) and
  plotted in Fig. 5 but never given a number in the prose — observed
  2026-07-31.
- Whether the 10-fold-over-LOO recommendation survives when the inner decision
  is hyper-parameter tuning rather than feature selection over thousands of
  genes. The paper's variance argument is about selecting from p = 2,000–7,129
  candidates, which is a far larger selection space than a typical tuning grid,
  and `varma2006.md` eq. (8) says the bias grows with that count — observed
  2026-07-31.
