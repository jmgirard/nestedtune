# stone1974a — the source paper: the "two-deep" assessment, what "double-cross" actually names, and Dawid's question

**Citation.** Stone, M. (1974). Cross-validatory choice and assessment of
statistical predictions (with Discussion). *Journal of the Royal Statistical
Society, Series B (Methodological)*, 36(2), 111–147. University College London.
Read before the Royal Statistical Society at a meeting organized by the Research
Section on Wednesday 5 December 1973, Professor J. Gani in the Chair. JSTOR
stable URL https://www.jstor.org/stable/2984809.

**Provenance.** Ingested 2026-07-31 from `sources/stone1974a.pdf` (gitignored),
JSTOR scan, 38 pages: a JSTOR cover sheet plus article pages 111–147, so PDF
page N = article page 109 + N. The paper proper runs to p. 133; the recorded
Discussion runs pp. 133–144 and the author's written reply pp. 144–147.
Downloaded 2026-07-31 per the scan's own stamp.
Extraction: `pdftotext -layout`. §§1–2 and §4 read in full, along with the
Discussion contributions of Dawid and Downton and the whole of the author's
reply; §3's six worked examples were read for structure and for Examples 3.1 and
3.4, and skimmed elsewhere. **Table 1 (p. 119) was verified against a 160-dpi
render of that page**, because the extraction interleaves its cells. Figures 1–4
and Tables 2–6 were **not** read — observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## This is the paper the shelf was missing

`stone1974b.md` — the Biometrika companion, ingested first — carries a warning
that the paper everyone cites for *double cross* was absent. This is that paper.
Both `cawley2010.md` (p. 2080) and `arlot2010.md` (p. 58) cite it by this exact
title, and it is the "Stone (1974)" in `bengio2004.md`'s and `bayle2020.md`'s
reference lists. The warning on `stone1974b.md` is now discharged.

## Terminology finding, read this first

**Stone's "double-cross" is not our construct.** The received chain — Cawley and
Talbot's "nested cross-validation or 'double cross' (Stone, 1974)", and Arlot and
Celisse's "This procedure is called 'double cross' by Stone (1974)" — attaches
the nested *assessment* to Stone's term. The paper attaches it to something else.

Section 2 lays out seven numbered items (pp. 114–116). Reading them in order:

| Item | Name | What it is |
|---|---|---|
| I | naive choice | α⁰(S) minimizes the in-sample average loss |
| II | naive assessment | the in-sample loss at α⁰(S); for Example 2.1 this is RSS/n |
| III | cross-validatory assessment of the naive choice | C⁰ = (1/n) Σᵢ L[yᵢ, ŷ(xᵢ; α⁰(S\i), S\i)] |
| IV | **cross-validatory choice** | α†(S) minimizes C(α) = (1/n) Σᵢ L[yᵢ, ŷ(xᵢ; α, S\i)] (eq. 2.3) |
| V | **cross-validatory assessment of a cross-validatory choice** | C† = (1/n) Σᵢ L[yᵢ, ŷ(xᵢ; α†(S\i), S\i)] (eq. 2.4), where α†(S\i) is itself obtained by minimizing over S\ij |
| VI | **"double-cross"** | *two-stage* cross-validatory **choice**: with α = (a, b), choose b† inside for each fixed a, then a†† outside (eq. 2.5) |
| VII | — | the loss used for choice need not be the loss used for assessment |

Item **V** is nestedtune's construct, and Stone's name for it is not "double
cross" — it is that "cross-validatory assessment of a cross-validatory choice
involves a **'two-deep' analysis** (cf. Mosteller and Tukey, 1968, p. 147)"
(p. 115). Item **VI**, the thing actually called double-cross, is a nested
*selection* device for a two-component α: an inner cross-validatory choice of b
and an outer one of a. Its own assessment is C†† (eq. 2.6), which has the same
two-deep shape as C†.

So the citation chain is loose rather than wrong — both items are nested, both
are in this paper's §2, and the assessment of a double-cross choice is the
two-deep measure. But a doc page or test that says "nested CV, called double
cross by Stone (1974)" is naming item VI while meaning item V. The precise
citation for what nestedtune computes is **Stone (1974a), §2 item V, eq. (2.4),
p. 115**; a package that also tuned two nested tiers of hyper-parameter would be
doing item VI.

## What it establishes

**Result 1 — the two-deep assessment, and its price.** Item V, p. 115. To assess
a cross-validatory choice, the choice must be recomputed on each S\i, which
requires the inner criterion to be evaluated on samples S\ij with two items
removed. That is exactly the structure of an outer loop wrapping an inner one.
The paper is candid about what it costs: Example 2.6, p. 115 — "For Example 2.1
and L quadratic, the expression for C† is hopelessly complex and the assessment
must be computer-based." The author's reply goes further (p. 145): the
assessment measure was simply not computed for Example 3.6 "because a computer
program for the calculation of this measure has not yet been written."

**Result 2 — the estimand is the procedure at n − 1, and the paper names the
trade.** Item III, p. 114: "C⁰ is strictly relevant to the prediction problem
for samples of size n−1 rather than n but this conservatism may be a small price
to pay for the increase in realism over L(α⁰(S)) that might be expected as a
result of the shrinkage phenomenon." The word is *conservatism*: the offset is
acknowledged and accepted, not overlooked.

**Result 3 — item VII: the selection loss and the assessment loss need not
match, and matching them is not optimal.** p. 116:

> "There is no very good reason why the loss function used in the definition of
> α†(S) or α††(S) should be the same as that used in its assessment. (The latter
> loss function should reasonably be considered fixed.) Indeed we have some
> evidence (see Example 3.1, Table 1) that this flexibility might be exploited."

The evidence is real and is reproduced below: in the Monte-Carlo study, choosing
under L = |y − ŷ|^½ beats choosing under quadratic loss *even when efficiency is
measured at p = 2*. Stone's summary (p. 119): "it is not at all the rule that the
best choice of power for L is the same as that used for the efficiency measure."

**Result 4 — a remark that says when nesting is inert.** p. 116: "If ŷ(x; α, S)
is independent of S then α†(S) = α⁰(S)." When the predictor family does not
depend on the sample, cross-validatory choice degenerates to naive choice —
which is why item VI exists: "In such a case, simple cross-validatory choice
would yield the naive estimator; double-cross is designed to avoid this
outcome" (p. 116).

**Result 5 — the paper declines to be a theory of inference.** Author's reply,
p. 145: "the cross-validatory method should not set itself up as a theory of
inference but should be content to act as substitute for some of the predictive
applications of inference."

**Result 6 — Dawid asks G6's question, at the reading, and it is left open.**
Discussion, A. P. Dawid, pp. 136–138. He opens: "Professor Stone has emphasized
cross-validatory choice at the expense of cross-validatory assessment, although
his analysis clearly brings out the latter as fundamental. ... So the vital
question is: **How reliable is cross-validatory assessment?**" He then does the
thing the paper avoids — puts a distribution behind it — and separates two
targets:

- R(p_S), the predictive risk of the predictor built on *this* sample S;
- r_n(p) = E{R(p_S)}, the average predictive risk over samples of size n.

His verdict on which is reachable: "What we should really like is for A(p, S) to
be always close to R(p_S) — for example, that E[{A(p, S) − R(p_S)}²] should be
small; but this seems rather too much to expect. We might have to be satisfied
with a good estimator of, not the relevant predictive risk R(p_S), but the
average predictive risk r_n(p)." He then shows E{C(p, S̃)} = r_{n−1}(p), so
cross-validatory assessment "would appear to be a distribution-free method of
estimating r_n(p)", unbiased for the risk one sample size down.

Stone's reply (p. 145) does not answer it: "Cross-validation will undoubtedly
benefit from some theoretical underpinning. Few can be better equipped to attempt
this than Mr Dawid. His first results are interesting."

**Result 7 — Downton's two objections, recorded because both are live.**
Discussion, F. Downton, pp. 138–139. (i) "'Prescriptions', which are logically
equivalent from a common-sense point of view, may lead to different estimators
when an identical cross-validation procedure is adopted." (ii) "why do we stop at
one iteration? ... The possibilities are endless" — nothing in the framework says
two deep rather than three. Stone's reply on (i) (pp. 145–146) is that the method
resisting a silly prescription is a feature — "Far from being black art, this is
more guardian angel" — and that a prescription whose individual predictors depend
on sample size "would rule them out on any statistical principles". He does not
answer (ii).

## Extracted values

**Table 1, p. 119** — efficiencies for the Monte-Carlo study of Example 3.1,
n = 7, prescription (3.2), 3,000 samples for Uniform and Cauchy and 2,000 for
Normal; efficiency measured as average |estimate|^p against the best of
MIDRANGE / MEAN / "MEDIAN", which is the entry shown as 1. The three rightmost
columns are cross-validatory choices under three different *selection* losses.
Read from a render of the page:

| Distribution | p | MIDRANGE | MEAN | "MEDIAN" | choose on \|y−ŷ\|^½ | CROSS (choose on \|y−ŷ\|) | choose on (y−ŷ)² |
|---|---|---|---|---|---|---|---|
| Uniform | ½ | 1 | 0.82 | 0.66 | 0.80 | 0.79 | 0.81 |
| Uniform | 1 | 1 | 0.71 | 0.47 | 0.66 | 0.64 | 0.67 |
| Uniform | 2 | 1 | 0.58 | 0.26 | 0.46 | 0.43 | 0.50 |
| Normal | ½ | 0.90 | 1 | 0.94 | **0.97** | 0.95 | 0.90 |
| Normal | 1 | 0.80 | 1 | 0.88 | **0.97** | 0.94 | 0.88 |
| Normal | 2 | 0.62 | 1 | 0.77 | **0.98** | 0.95 | 0.90 |
| Cauchy | ½ | 0.03 | 0.05 | 1 | 0.92 | **0.95** | 0.88 |
| Cauchy | 1 | — | — | 1 | 0.80 | **0.86** | 0.69 |
| Cauchy | 2 | — | — | 1 | 0.4 | **0.5** | — |

The Normal rows are the point of item VII: at every p — including p = 2, where
the *evaluation* is quadratic — the choice made under the ½-power loss beats the
choice made under quadratic loss (0.97/0.97/0.98 against 0.90/0.88/0.90).
Comparison estimators: MIDRANGE = ½(y₍₁₎+y₍₇₎), optimal for uniform; MEAN,
optimal for normal; "MEDIAN" = 0.0592(y₍₃₎+y₍₅₎) + 0.8816 y₍₄₎, optimal for
Cauchy (Barnett, 1966).

Other closed forms recorded as prose: eq. (3.4), the k-group shrinkage
α†(S) = (n−1)/(k(r−1)F + k−1) with F the usual ratio of mean squares; eq. (3.13),
the double-cross criterion for variable selection, C†(a) = (1/n) Σ (yᵢ − ŷᵢ(a))² /
(1 − Aᵢᵢ(a))², i.e. the PRESS statistic, with A the hat matrix (eq. 3.14). The
program written for the hierarchical variable-selection case is named
`DOUBLECROSS` (p. 122); it was applied to satellite geopotential data from
King-Hele and Cook (1973). Tables 2–6 were not read.

## Bearing on nestedtune

- **The citation for what the package computes, with a correction to how it is
  usually cited.** Item V / eq. (2.4) / p. 115 is nestedtune's outer loop. The
  terminology finding above should reach any doc page that was going to write
  "double cross"; the honest phrasing is Stone's own, a "two-deep" analysis, or
  the modern "nested cross-validation".
- **IP3 in the discussion, thirty years before `bates2023.md`.** Dawid's split
  between R(p_S) — the risk of the predictor built on *this* sample — and
  r_n(p) — its average over samples — is precisely Bates et al.'s Err_XY versus
  Err, and `austern2020.md`'s R̂^average versus R_{n,K}. Dawid's verdict is the
  same as theirs: the conditional target "seems rather too much to expect", so
  the average is what CV estimates. Three independent statements of IP3 across
  46 years, one of them in the discussion of the founding paper.
- **G6's question is as old as the construct, and was deferred at birth.**
  Dawid's "How reliable is cross-validatory assessment?" is the ROADMAP's G6 row.
  Stone's answer was that someone should work on it. `bengio2004.md` eventually
  answered a piece of it negatively; `bayle2020.md` and `austern2020.md` answered
  a piece of it positively under stability. None answered it for the tuned case.
  The row's parked status has a long pedigree.
- **Item VII is a live design question for this package.** nestedtune takes one
  `metrics` argument and feeds it to both loops — `R/nested-tune-grid.R:363`
  passes it to `tune_grid()` and `:385` passes it to `last_fit()` — so the metric
  that selects is always the metric that scores. Stone says these need not match,
  and Table 1 gives measured cases where matching is worse. This is not a defect:
  coupling them is the obvious path GP3 prefers, tune's own idiom, and decoupling
  would need a second argument and a story about which metric `collect_metrics()`
  is reporting. But it is an unexamined coupling, and it should be a ROADMAP
  candidate rather than an accident. **See the candidate row added 2026-07-31.**
- **Support for M20, from the same place.** If selection loss and assessment loss
  can differ, then recording which metric a run scored under — M20's work — is
  not bookkeeping; it is the difference between two statements about the run.
- **Support for GP5, from the method's author.** "the cross-validatory method
  should not set itself up as a theory of inference" (p. 145) is GP5's posture in
  Stone's words.
- **The compute argument, 1974 edition.** Baker suggested reserving
  cross-validatory calculation for exhaustive analyses because of cost; Stone
  refused — "I do not think that the essential benefits of the method can be
  realized if it is regarded as an optional extra to the conventional methods" —
  and noted "C.P.U. costs are falling while output costs are increasing"
  (p. 146). That is `cawley2010.md` §6's conclusion, and GP4's, thirty-six years
  early.

## Oracle status

**No oracle for the nested path; one exact formula worth noting.** Eq. (3.13),
p. 121, gives the leave-one-out cross-validatory criterion for a least-squares
prescription in closed form as the PRESS statistic, Σ (yᵢ − ŷᵢ)²/(1 − Aᵢᵢ)², and
eq. (3.15) gives the equivalent under a second deletion. Those are hand-computable
from published formulas — GP2 type (1) — but for the *inner* criterion of an OLS
fit, which is `tune`'s territory under GP1, not nestedtune's. The paper's
Monte-Carlo efficiencies (Table 1) are properties of estimators of location, not
values this package computes. Recorded, not claimed.

## Open questions

- Whether decoupling the selection metric from the assessment metric is worth an
  API. Stone's item VII says the flexibility exists and Table 1 says it pays for
  location estimation with n = 7; nothing establishes that it pays for a
  tidymodels workflow, and the reporting story is unwritten. Registered as a
  ROADMAP candidate 2026-07-31, unmeasured.
- Downton's "why do we stop at one iteration?" (p. 139) is unanswered in the
  reply and, as far as this shelf goes, unanswered since. It is the question of
  whether a three-deep assessment estimates anything a two-deep one does not.
  Not a nestedtune question today; recorded because nobody appears to have shut
  it — observed 2026-07-31.
- §3's Examples 3.2, 3.3, 3.5 and 3.6, and Tables 2–6, skimmed rather than read;
  Example 3.6's assessment was never computed by the author for want of a program
  (p. 145), so the paper's own worked nested assessments are fewer than its
  length suggests — observed 2026-07-31.
- Whether Dawid's normal-case correction factor — multiplying C(p, S) by
  (n+1)(n−2)(n−1)(n−4)/[n²(n−3)²] to target r_n(p) rather than r_{n−1}(p),
  p. 138 — has any descendant in the modern literature. It is a distributional
  bias correction of exactly the kind GP5 forbids shipping, but it is the earliest
  attempt on this shelf to remove the n−1 offset — observed 2026-07-31.
