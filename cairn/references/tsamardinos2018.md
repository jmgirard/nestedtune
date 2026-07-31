# tsamardinos2018 — BBC-CV: bootstrap the out-of-sample predictions and skip the outer loop entirely

**Citation.** Tsamardinos, I., Greasidou, E., & Borboudakis, G. (2018).
Bootstrapping the out-of-sample predictions for efficient and accurate
cross-validation. *Machine Learning*, 107(12), 1895–1922.
doi:10.1007/s10994-018-5714-4. Computer Science Department, University of Crete
and Gnosis Data Analysis PC, Heraklion. Received 3 August 2017, accepted 21
April 2018, published online 9 May 2018. Open Access (CC-BY 4.0). Editor:
Hendrik Blockeel.

**Provenance.** Ingested 2026-07-31 from `sources/tsamardinos2018.pdf`
(gitignored), publisher PDF, 28 pages.
Pagination: PDF page N = article page 1894 + N (PDF p. 1 = journal p. 1895).
Extraction: `pdftotext -layout`, full text read. Algorithms 1–5 and Table 1
extracted cleanly. **Figures 1–7 are images and were not read**; every bias,
speed-up and coverage curve lives in one of them, so the numbers below are the
ones the prose and captions state — which, unusually for this shelf, is most of
the important ones — observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology note

**Their NCV is exactly ours**, and the paper's Algorithm 3 is the cleanest
statement of it this shelf has: define CVT (cross-validate every configuration,
pick the best, refit on all data) as a *learning method* in its own right, then
plain-CV that method. Two lines. That framing — nesting is not a new protocol,
it is ordinary CV applied to a procedure that happens to contain CV — is the
same one `arlot2010.md` reaches through the calibrated algorithm A′, and it is
what IP3 says in principle terms.

Vocabulary this paper adds:

- **Configuration** — one point in the joint space of algorithms *and* their
  hyper-parameter values, including preprocessing and feature selection steps.
  A tidymodels `workflow` with its parameters finalized is one configuration.
- **Tuning set** versus **estimation set** — their names for the inner
  assessment fold and the outer assessment fold.
- **CVT** — flat CV used for both tuning and reporting. The thing the package
  exists to replace.
- **Π** — the pooled matrix of out-of-sample predictions, N rows × C
  configurations. Everything in the paper is computed from this one object.

On provenance they are careful and worth quoting on: they could not trace who
first coined "nested cross-validation", note their own group's use from 2005
(Statnikov et al.), place `varma2006.md` at the same time, and point to a 2003
bioinformatics application. `stone1974a.md` predates all of it by three decades
under a different name — a gap this paper does not close and this shelf can.

## What it establishes

**Result 1 — the winner's-curse bias has a two-line proof.** With μᵢ the true
loss of configuration i and mᵢ its tuning-set estimate, reporting
min{m₁ … m_C} instead of min{μ₁ … μ_C} carries
Bias = min{E(m₁) … E(m_C)} − E(min{m₁ … m_C}) ≥ 0 by Jensen's inequality
(p. 1897). It grows with the number of configurations, shrinks with sample
size, and depends on how correlated the configurations' performances are. Same
phenomenon as `varma2006.md` eq. (8), stated as an inequality rather than a
probability.

**Result 2 — nesting costs exactly K²·C + K + 1 models.** Counted explicitly
(p. 1903): K × ((K−1) × C + 1) for the estimate plus K × C + 1 for the final
model. Quadratic in the fold count. This is the number that motivates the whole
paper, and it is the same O(k²) `wilimitis2023.md` measured on the clock.

**Result 3 — BBC-CV removes the bias without training a single extra model.**
Algorithm 5 (p. 1906). Run flat CVT once, keep Π. Then for b = 1…B: resample N
*rows* of Π with replacement; apply the selection rule to the resampled matrix
to pick a configuration; score that configuration on the rows the bootstrap
left out. Average the B out-of-bag losses. The insight is that what gets
bootstrapped is the *selection strategy*, not the learning algorithm — so the
optimism of choosing a winner is simulated at the cost of index arithmetic.

**Result 4 — the same bootstrap population gives a confidence interval for
free.** The percentile interval [L₍₀.₀₂₅·B₎, L₍₀.₉₇₅·B₎] over the B out-of-bag
losses (p. 1906). Measured coverage is **conservative** at N = 20, closer to
nominal but still conservative by N ≥ 100, and improved further by repeats.
At N = 500 the intervals stopped being conservative, traced to two datasets
(madeline, jasmine) whose downward bias dragged the intervals below the true
performances (p. 1919).

**Result 5 — a sharp, non-contrived failure mode for the TT correction.**
Because TT's bias estimate is bounded by 0 ≤ TTBias ≤ L_CVT, the corrected
estimate always lies in [L_CVT, 2·L_CVT] (p. 1903). Under leave-one-out with
many configurations, some configuration predicts each singleton fold correctly,
so the bias estimate equals the loss and the correction *doubles* it — a 70%
loss becomes 140%. More generally TT needs large folds, which is exactly what
small-sample analyses cannot supply, and it cannot be used with AUC or the
concordance index at all, since those need several predictions per fold. This
is the direct rebuttal to `tibshirani2009.md`, and their simulations bear it
out: TT was optimistic at N ∈ {20, 40}, over-corrected at N ∈ {60, 80, 100},
and was systematically conservative at N ≥ 500 (p. 1911).

**Result 6 — NCV was almost unbiased everywhere; BBC-CV was slightly
conservative.** In simulation, across every sample size, NCV's bias sat at
essentially zero; BBC-CV ran conservative by 0.013 accuracy points on average
and 0.034 at worst (N = 20); BBCD-CV by 0.005 and 0.018 (p. 1911). **The
paper's own numbers put nesting first on bias** and argue for BBC-CV on cost.

**Result 7 — at equal compute, repeated flat CV produced better *models* than
nesting.** BBC-CV with 10 fold-partition repeats trains about as many models as
NCV with K = 10. Under that matched budget, BBC-CV₁₀ returned an equally good
or better model than NCV for N ≥ 40 on 7 of 9 datasets (philippine and jasmine
varied), with similar estimate bias (p. 1918). This is a tuning-quality result,
not an estimation result, and it is the most uncomfortable finding here for any
package built around an outer loop.

**Result 8 — dropping inferior configurations early buys 2–5× (up to 10×), but
not at small n.** BBCD-CV drops a configuration once the bootstrap says it
loses to the current best with probability > α = 0.99. At N = 500 the speed-up
over CVT was typically 2–5 and reached the theoretical maximum of K = 10 on
gisette (p. 1917). At N ≤ 100 it cost real model quality — up to 9.05% AUC on
dexter at N = 40 — because over 95% of configurations were dropped within the
first couple of folds on 2–10 out-of-sample predictions. Their fix is a floor:
do not start dropping until ~50 out-of-sample predictions exist (p. 1916). The
authors label the criterion a heuristic and name two things it ignores — it
tests each configuration against the current best in isolation, and it does not
account for the uncertainty in *which* configuration is currently best
(p. 1909).

## Extracted values

Simulation (pp. 1910–1911): N ∈ {20, 40, 60, 80, 100, 500, 1000};
C ∈ {50, 100, 200, 300, 500, 1000, 2000}; true configuration performances drawn
from Beta(a, 6) with a ∈ {9, 14, 24, 54}, giving means {0.6, 0.7, 0.8, 0.9} and
variances {0.015, 0.01, 0.0052, 0.0015}. 196 settings × 500 repeats = 98,000
prediction matrices. K = 10 for every protocol, NCV inner K = 9, B = 1000,
α = 0.99. Predictions are simulated directly (Πᵢⱼ = 1(rᵢ < Pⱼ)) — no models are
ever trained.

Bias in simulation (p. 1911, from Fig. 1's caption and prose):

| Protocol | Behaviour |
|---|---|
| CVT | Optimistic everywhere, up to **0.17** accuracy points; → 0 as N grows |
| TT | Optimistic at N ∈ {20, 40}; over-corrects at N ∈ {60, 80, 100}; conservative at N ≥ 500 |
| NCV | Almost unbiased at every N |
| BBC-CV | Conservative; **0.013** points from NCV on average, **0.034** worst case (N = 20) |
| BBCD-CV | Conservative; **0.005** from NCV on average, **0.018** worst case |

Real data (Table 1, p. 1913): nine binary-classification datasets from the NIPS
2003, WCCI 2006 and ChaLearn AutoML challenges — christine (5418×1636),
jasmine (2984×144), philippine (5832×308), madeline (3140×259), sylvine
(5124×20), gisette (7000×5000), madelon (2600×500), dexter (600×20000), gina
(3468×970). Each split 30% pool / 70% holdout; 20 sub-datasets sampled per
N ∈ {20, 40, 60, 80, 100, 500} (dexter to 100 only), giving **1060
sub-datasets**. Grid Θ = **610 configurations** over imputation, binarization,
standardization, SES feature selection (α ∈ {0.05, 0.01}, k ∈ {2, 3}, plus
none), random forests, SVMs (linear/polynomial/RBF) and LASSO/elastic net.
Total: **more than 135 million trained models** (p. 1914).

Real-data AUC bias (p. 1914): CVT optimistic at N ≤ 100; TT worst of all
protocols except CVT; NCV and BBC-CV both low-bias, with NCV slightly
*optimistic* on dexter and madeline at N = 40 (**0.033** and **0.031** AUC) and
BBC-CV conservative except on madeline (N = 40) and madelon (N ∈ {60, 80, 100}).

Code: Matlab implementation of the simulation study at
`https://github.com/mensxmachina/BBC-CV` (p. 1911). Not retrieved — observed
2026-07-31.

**One caveat the paper raises against itself, recorded.** Pooling predictions
across folds to compute AUC assumes the scores from different folds are on a
comparable scale (footnote 2, p. 1906). Their example: a configuration whose
feature selection returns 4 features in one fold and 5 in another produces SVM
margins measured in different spaces, so pooled ranking is not meaningful. In
their experiments TT and NCV therefore average per-fold AUC while the other
methods pool.

## Bearing on nestedtune

- **This is the most serious published argument against the outer loop, and it
  is more serious than `tibshirani2009.md`'s.** It is validated on nine real
  datasets with a 610-configuration grid and 135 million fits, it explicitly
  recommends forgoing NCV (p. 1920), and it beats the earlier cheap correction
  on the earlier correction's own terms. Any framing of nestedtune that treats
  nesting as the only correct answer is refutable from this shelf.
- **Read the same paper's numbers the other way and nesting still wins on
  bias.** NCV was almost unbiased at every sample size in simulation; BBC-CV
  was conservative and BBCD-CV more so at small n. The paper's case against
  nesting is a *cost* case, not an accuracy case — and cost is GP4, which
  DESIGN already subordinates to correctness. That is a defensible position to
  state plainly in documentation rather than to avoid.
- **Result 7 is the finding to take seriously.** At a matched model budget,
  ten repeats of flat CV with BBC correction produced better final models than
  nesting on most datasets. nestedtune has no repeated-outer-fold story today.
  Whether that is a candidate (repeats as an outer-loop option) or simply an
  honest caveat is a planning question, not one this page settles.
- **G6: this is the second independent method needing the quantity the package
  throws away.** BBC-CV needs Π — per-observation, per-configuration
  out-of-sample predictions from the inner runs. `bayle2020.md` needs
  per-point losses. nestedtune discards per-observation losses at
  `R/nested-tune-grid.R:385-396`. Two unrelated interval methods now converge
  on the same missing input, which turns "retain per-observation predictions"
  from a speculative feature into the single structural prerequisite for any
  future G6 work. That is a stronger statement than the gap ledger currently
  carries.
- **But BBC-CV is not an interval for *our* estimate.** It intervals the flat
  CVT procedure's corrected performance, computed from inner-loop predictions
  only. It replaces the outer loop rather than describing it. Shipping it
  inside nestedtune would mean shipping a second, differently-defined number
  beside the nested one — which is exactly the confusion IP3 and D-014 are
  built to prevent. GP5 applies with force.
- **A GP2 type (2) oracle exists here, and it is the first real candidate.**
  The Matlab reference implementation is public, the simulation is
  fully specified (predictions generated directly from Beta-drawn true
  accuracies, no model training), and the reported biases are printed to three
  decimals. An R port of Algorithm 5 checked against it would be a genuine
  reference-implementation oracle. This is worth recording as a candidate even
  though BBC-CV itself is not planned.
- **Result 2 is a check on the package's own model count.** NCV as they define
  it uses K−1 inner folds derived from the outer K, giving K²·C + K + 1.
  nestedtune's inner scheme is independent of the outer one, so its count is
  v_outer × v_inner × C + v_outer, plus the final fit. The package is not
  bound to the quadratic; that is a consequence of tying the two fold counts
  together, and `nested_resamples()` does not.
- **The AUC pooling caveat (footnote 2) validates a choice already made.**
  nestedtune's `collect_metrics()` averages per-fold metrics rather than
  pooling predictions, which is the side of that footnote that stays safe when
  a workflow's preprocessing differs across folds. Worth recording as a reason,
  since nothing in the package currently states one.
- **Algorithm 3 is the best available external statement of IP3.** Nesting is
  CV of a *learning method that contains tuning*; the estimate belongs to that
  method. Two lines of pseudo-code say what IP3 says in a paragraph.

## Oracle status

**The strongest oracle candidate on the shelf so far, for a method the package
does not implement.**

GP2 type (2), reference implementation: Matlab source is published at a stable
GitHub URL and the simulation it drives needs no learning algorithm at all —
Π is generated directly from Beta-distributed true accuracies. That makes it
unusually cheap to port and compare, with no dependency on matching an
upstream learner's behaviour.

GP2 type (2)/(1) for **NCV itself**: the paper reports NCV's bias as
essentially zero across N ∈ {20 … 1000} under a fully specified generative
setup, and prints two specific NCV values on real data (+0.033 AUC on dexter,
+0.031 on madeline, both at N = 40). The simulation figures are unread, so the
per-cell NCV biases are not in hand; what is quotable is the qualitative claim
plus those two real-data numbers, and the real-data ones depend on datasets and
a 610-configuration grid that would have to be reproduced exactly.

Neither is a fixture. Both are recorded as candidate shapes; nothing here is
planned.

## Open questions

- What NCV's bias actually is, cell by cell, in the simulation. Figure 1 was
  not read and the prose gives only the summary word "almost unbiased" —
  observed 2026-07-31.
- Whether the Matlab implementation runs and reproduces the printed biases.
  Not retrieved — observed 2026-07-31.
- Whether Result 7 (repeats beating nesting at matched budget) holds when the
  outer loop is repeated too. The comparison is BBC-CV₁₀ against single-run
  NCV; repeated NCV is never run — observed 2026-07-31.
- Whether BBC-CV's conservatism at small n and NCV's near-zero bias are
  reconcilable with `varma2006.md`'s finding that nesting overshoots by ~4
  points at N = 40. The two use different estimands for "true performance" —
  a 70% holdout here, an independent 20,000-sample test set there — and the
  discrepancy is not examined by either paper — observed 2026-07-31.
- Whether the package could retain per-observation predictions at acceptable
  memory cost. Two methods now need them; nothing has measured what keeping
  them would cost against GP4 — observed 2026-07-31.
