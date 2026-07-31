# bayle2020 — an asymptotically exact CI for k-fold test error, conditional on stability

**Citation.** Bayle, P., Bayle, A., Janson, L., & Mackey, L. (2020).
Cross-validation confidence intervals for test error. In *Advances in Neural
Information Processing Systems 33* (NeurIPS 2020), Vancouver, Canada. Princeton
University, Harvard University, and Microsoft Research New England. Pierre Bayle
and Alexandre Bayle contributed equally. Replication code at
https://github.com/alexandre-bayle/cvci.

**Provenance.** Ingested 2026-07-31 from `sources/bayle2020.pdf` (gitignored),
NeurIPS proceedings PDF, 12 pages: nine pages of main text, then Broader Impact
and references.
Pagination: PDF page N = paper page N.
Extraction: `pdftotext -layout`, full text read. **Appendices A–L are not in
this PDF** — every proof, all experimental detail, and Figures 3–15 live there
and were not retrieved, so no claim below rests on them. **Figures 1 and 2 are
images and were not read**; the coverage and width claims below come from the
§5.1–5.2 prose and the captions — observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology warning, read this first

**There is no nesting anywhere in this paper, and no tuning step.** The
algorithm is fixed; the paper asks what interval to put around a single k-fold
CV run's error. It is on this shelf because it is the closest thing the
literature has to an answer for G6, not because its construct is ours. What it
would take to reach our loop is set out under *Bearing* below, and the gap is
real.

Note also the estimand, which is narrower than the phrase "test error" suggests
(eq. 2.1, p. 3): R_n is the **k-fold test error** — the average, over the k
folds actually used, of the conditional expected loss of the prediction rule
fitted on that fold's training set. It is a property of the k rules this run
produced, not of a rule fitted to all n points, and it is random through the
training sets. §6 names the alternative, E[R_n], as future work.

## What it establishes

**Result 1 — a CLT for k-fold CV under stability.** Theorem 1, p. 4: with i.i.d.
data and a uniform-integrability condition, √n(R̂_n − R_n)/σ_n → N(0,1) provided
an *asymptotic linearity* condition (2.2) holds — that CV error behaves, to
first order, like the test error plus an average of one-datapoint functions.
Theorem 2, p. 4, gives a sufficient condition in terms of Kumar et al.'s **loss
stability**: linearity holds with h̄_n(z) = E[h_n(z, Z_{1:n(1−1/k)})] whenever
γ_loss(h_n) = o(σ_n²/n). Theorem 3, p. 5, gives a weaker alternative for bounded
k, requiring only convergence of a conditional variance. The number of folds
k = k_n may grow with n, up to and including k = n.

**Result 2 — two consistent variance estimators, both computable from a single
run.** Theorem 4, p. 6, the **within-fold** estimator: for k < n,

> σ̂²_{n,in} = (1/k) Σ_j [1/((n/k)−1)] Σ_{i∈B′_j} ( h_n(Z_i, Z_{B_j}) − (k/n) Σ_{i′∈B′_j} h_n(Z_{i′}, Z_{B_j}) )²

— the average across folds of the within-fold sample variance of the per-point
losses. Theorem 5, p. 7, the **all-pairs** estimator, which is the one that also
covers leave-one-out:

> σ̂²_{n,out} = (1/k) Σ_j (k/n) Σ_{i∈B′_j} ( h_n(Z_i, Z_{B_j}) − R̂_n )²

— the pooled variance of every per-point loss about the overall CV error. Both
are consistent (in L¹, and in L² for σ̂²_{n,in} under a fourth-moment condition)
under the same loss-stability condition that gives the CLT, with σ̂²_{n,out}
additionally needing γ_ms(h_n) = o(kσ_n²/n).

**Result 3 — the interval, and its cost.** Eq. (4.1), p. 6:

> C_α = R̂_n ± q_{1−α/2} · σ̂_n / √n,  with  P(R_n ∈ C_α) → 1 − α.

Note the divisor: **√n, over observations, not √k over folds.** Eq. (4.2) gives
the matching one-sided test for whether one algorithm beats another. Cost
(p. 7): "both σ̂²_{n,in} and σ̂²_{n,out} can be computed in O(n) time using just
the individual datapoint losses h_n(Z_i, Z_{B_j}) outputted by a run of k-fold
cross-validation." For 0–1 loss they collapse to closed forms —
σ̂²_{n,out} = R̂_n(1 − R̂_n) in O(1), and
σ̂²_{n,in} = (1/k) Σ_j [(n/k)/((n/k)−1)] R̂_{n,j}(1 − R̂_{n,j}) in O(k) from the k
fold errors alone.

**Result 4 — the popular alternatives are not valid, and it shows.** §5.1: among
the cross-validated t-test, the repeated train–validation t-test (corrected and
not), the 5×2-fold CV test and a hold-out CLT, "none except the hold-out method
are known to be valid". Empirically the repeated train–validation CI
"significantly undercovers in all cases", the hold-out CI is valid but
"substantially wider and less informative", and the paper's own interval
"delivers the smallest width (and hence greatest precision) for both learning
tasks and every dataset size", with coverage near 95% even at n = 700.

**Result 5 — instability breaks it, and tuning is a destabilizer.** §5.3, p. 9.
Repeating the comparison with a deliberately less stable neural network (reduced
ℓ₂ penalty) and a less stable random forest (deeper trees), "the size of every
test save the hold-out test rises above the nominal level", and for their own
test the diagnosis is direct: the variance of √n(R̂_n − R_n)/σ_n is "much larger
than 1", which Theorem 2 says can only happen when loss stability is large. The
condition that matters is relative: "it suffices for the loss stability to be
negligible relative to the noise level σ_n²/n" — which is why the same
destabilized algorithms still gave good intervals for single-algorithm
assessment, where σ_n² is larger.

## Extracted values

Experiments (§5, pp. 7–9): k = 10 throughout, 90–10 train/validation splits for
the competing tests, 500 training sets per configuration, sample sizes n from
700 to 11,000 subsampled from a large real data set used to form a surrogate
ground truth. Classification on the **Higgs** data set (random forest, neural
network, ℓ₂-penalized logistic regression); regression on the Kaggle
**FlightDelays** data set (random forest, neural network, ridge). Target level
95% for CIs, α = 0.05 for tests. All learners were run in "stable settings" —
strong ℓ₂ regularization, shallow trees — except in §5.3.

No coverage or width table appears in the main text; the numbers are in Figs 1–2
and Apps L.1–L.4, unread. The one hard numeric comparison in prose (§1, p. 2)
is against concentration-based intervals: implementing the ridge-regression CI
of Celisse and Guedj for their §5.1 experiment, "the narrowest
concentration-based interval is 91 times wider than our widest CLT interval",
and 5 × 10¹⁴ times wider without standardized features.

Relation to `austern2020.md`, stated as a proposition (Prop. 2, p. 5):
σ_n² ≤ σ̃_n² ≤ σ_n² + (2/m)γ_loss(h_n), where σ̃_n² is Austern and Zhou's
variance parameter and m = n(1 − 1/k); the first inequality is strict whenever
the loss's deviation from its conditional mean depends on the training set.
§3.3 lists their conditions as strictly weaker than Austern and Zhou's on four
counts, and notes a task where σ_n² converges while σ̃_n² is infinite.

## Bearing on nestedtune

- **This materially changes the G6 candidate, in one direction only.** The
  ROADMAP row records that "the caveat half is now writable and the interval
  half still is not". The second clause needs qualifying: a valid,
  asymptotically exact, cheap interval for k-fold CV **does** exist in the
  literature as of 2020, with a reference implementation in the authors' repo.
  What does not exist is that interval for *our* loop. So the honest statement
  is that G6 is blocked on a specific gap, not on the absence of any method.
- **The gap, precisely.** Three things stand between eq. (4.1) and a nestedtune
  column:
  1. **The algorithm must be loss-stable relative to the noise.** Our per-fold
     algorithm is tune-then-fit, whose output is a *selected* configuration —
     `cawley2010.md` §4 measures exactly how much that selection can swing with
     the sample, and §5.3 above shows what instability does to the guarantee's
     size. Nobody on this shelf has established loss stability for a tuned
     procedure. This is the load-bearing unknown.
  2. **The estimand is not the one users ask for.** R_n is the average test
     error of the k rules actually fitted, conditional on this partition. That
     is very close to IP3's reading of what a nested estimate describes, which
     is a point in its favour — but it is not the error of the final model, and
     §6 lists intervals for E[R_n] as open work.
  3. **We do not keep the inputs.** Both estimators need per-observation losses.
     `R/nested-tune-grid.R:385-396` scores each outer fold with
     `tune::last_fit()` and retains only `collect_metrics(fitted)` — the fold's
     aggregated metric — discarding the fitted result and with it
     `.predictions`. So neither σ̂²_in nor σ̂²_out is computable from a
     `nested_results` object today. Any G6 work starts with a retention
     decision, which collides with M23's lean-payload direction and with GP4.
- **A structural mismatch worth naming in the caveat itself.** The valid
  interval divides by √n; `R/nested-results.R:213-217` divides by √V. These are
  not the same statistic and not the same order of magnitude, which is a
  sharper way to say "this column is not an oracle-backed interval" than the
  caveat currently has available. It is also the second open question on
  `bates2023.md`, now with a concrete alternative to compare against.
- **Corroboration for GP1's refusal to invent metrics.** For 0–1 loss the
  estimators have exact closed forms; for anything that is not an average of
  per-point losses — `roc_auc`, and every rank-based metric tidymodels ships —
  the h_n framework does not apply at all. Any future interval would be
  metric-specific, which is a design constraint, not a detail.

## Oracle status

**No oracle today; the best *future* oracle source on this shelf.** If G6 is
ever planned, `alexandre-bayle/cvci` is an independent reference implementation
of a published formula — GP2 type (3), and with the paper's stated closed forms
(σ̂²_out = R̂_n(1−R̂_n) for 0–1 loss) also type (1), hand-computable from a fixture
in one line. Two independent types from one source, which is what GP2 asks for.
Recorded as available, not claimed: nothing here has been executed, the repo's
language and licence are unchecked, and the formulas apply to a construct
nestedtune does not currently compute.

## Open questions

- Whether a tune-then-fit procedure has loss stability γ_loss = o(σ_n²/n) for
  any realistic tidymodels workflow. This is the question G6 turns on and no
  source on this shelf addresses it — observed 2026-07-31.
- What §5.3's size violations look like quantitatively; Figs 13–15 and App. L.4
  are unretrieved, so "much larger than 1" is all this note can say about how far
  instability pushes the guarantee — observed 2026-07-31.
- Whether the estimators extend to metrics that are not averages of per-point
  losses. The paper's h_n is always a per-observation loss; it never discusses
  AUC, and it cites LeDell et al. (2015) as the separate treatment AUC needed —
  observed 2026-07-31.
- What retaining per-observation losses would cost a `nested_results` object.
  Unmeasured as of 2026-07-31, and the first thing to price if G6 is promoted.
