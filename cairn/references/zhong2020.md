# zhong2020 — "nested CV" as an inner *feature-selection* loop

**Citation.** Zhong, Y., He, J., & Chalise, P. (2020). Nested and Repeated Cross
Validation for Classification Model With High-dimensional Data. *Revista
Colombiana de Estadística*, 43(1), 103–125.
doi:10.15446/rce.v43n1.80000. Department of Biostatistics and Data Science,
University of Kansas Medical Center.

**Provenance.** Ingested 2026-07-31 from `sources/zhong2020.pdf` (gitignored),
23 pages, no PDF metadata (MiKTeX producer only).
Pagination: printed page = PDF page + 102 (PDF p. 1 = article p. 103). Anchors
below use **printed** pages; the PDF page is printed − 102.
Extraction: `pdftotext -layout`, full text read. Figures 1–4 are images and were
**not** read; Figure 1 (the K=V=3 illustration) and Figure 2 (the method
flowchart) carry structure this page therefore takes from the prose instead.
Section 5's real-data results were read from Tables 4 and 5 — observed
2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Terminology warning

**A third meaning of "nested CV" on this shelf.** Here the inner loop performs
**feature selection** and the outer loop tunes and builds the final model
(§3.3–3.5, p. 110–114) — the reverse of the arrangement in `krstajic2014.md`,
where the inner loop tunes and the outer loop assesses, which is nestedtune's
construct. It differs again from `bates2023.md`'s variance-estimation NCV. The
paper does describe the assessment arrangement as an alternative use (p. 105)
but does not adopt it.

## What the proposed method is

Two steps over K outer folds with V inner folds, plus R repeats of the inner
partition (§3.4–3.5, p. 111–114):

- **Step 1, variable selection.** For each outer fold k, repeat R times:
  partition D<sub>−k</sub> into V folds, tune over an M-point grid by V-fold CV,
  average the CV error across the R repeats, pick θ̂, fit, and read off a feature
  subset (coefficient shrinkage for elastic net; variable ranking for SVM and
  random forest). A feature entering more than R/2 of the R subsets is kept,
  giving one "winner" subset per outer fold. Across the K winners, a feature
  kept in ≥ K/2 of them enters the final subset FS<sub>final</sub>.
- **Step 2, model building.** Reduce the training data to FS<sub>final</sub>,
  reuse the *same* folds from step 1, run repeated K-fold CV over the grid,
  and fit the final model at the chosen θ̂.

Classifiers: logistic regression via elastic net, SVM with Gaussian kernel,
random forest. Comparison baseline throughout is "Method 1" = standard single
CV; "Method 2" = the proposed repeated/nested procedure.

## Extracted values

Simulation (§4, p. 113–118): n = 100, p ∈ {2000, 5000}, within-group correlation
ρ ∈ {0.3, 0.5, 0.8}; three informative groups at 1%, 2%, 2% of p with
coefficients 5, 3, 2; remaining 95% of predictors iid N(0,1).

| Table 1, p. 118 (AUC) | Elastic net | SVM | Random forest |
|---|---|---|---|
| Sc. 1 (p=2000, ρ=0.3) M1 → M2 | 0.8856 → 0.8930 | 0.8646 → 0.8968 | 0.8215 → 0.8532 |
| Sc. 2 (p=5000, ρ=0.3) M1 → M2 | 0.9029 → 0.9197 | 0.9151 → 0.9153 | 0.8432 → 0.8612 |
| Sc. 3 (p=2000, ρ=0.5) M1 → M2 | 0.8823 → 0.8823 | 0.8648 → 0.8802 | 0.7983 → 0.8381 |
| Sc. 4 (p=5000, ρ=0.5) M1 → M2 | 0.8900 → 0.8905 | 0.8838 → 0.8916 | 0.7936 → 0.8457 |
| Sc. 5 (p=2000, ρ=0.8) M1 → M2 | 0.8922 → 0.9171 | 0.9017 → 0.9205 | 0.8570 → 0.8840 |
| Sc. 6 (p=5000, ρ=0.8) M1 → M2 | 0.9324 → 0.9422 | 0.9345 → 0.9403 | 0.8877 → 0.8989 |

M2 ≥ M1 in every cell (two ties at 4 decimal places). An oracle row using only
the truly informative variables scores 0.9483–0.9878 throughout, well above both.

**Cost** (Table 2, p. 119): the proposed method runs roughly **10–15×** the
standard method — 10–12× for elastic net and random forest, 13–15× for SVM.
At p = 5000, random forest goes from ~89 s to ~943 s.

**Real data.** Golub leukemia (§5.1, p. 119): 72 patients (47 ALL, 25 AML),
7129 probes, 38 train / 34 test. Table 4 misclassification, M1 → M2: elastic net
23.5% → 14.7%, SVM 11.8% → 5.9%, RF 23.5% → 11.8%. TCGA cervical cancer (§5.2,
p. 121): 175 subjects after excluding 3 adenosquamous, 19,037 genes after QC,
140 train / 35 test. Table 5, M1 → M2: AUC 91.05 → 94.11 (enet), 85.47 → 88.23
(SVM), 87.25 → 91.44 (RF); misclassification 20.00 → 14.29, 17.14 → 11.43,
22.86 → 16.22.

## Extraction caveats — the numbers do not fully reconcile

Recorded because they bear directly on whether anything here could serve as an
oracle. All three were found by arithmetic on the printed tables, 2026-07-31:

1. **Scenario indices disagree between Tables 1 and 2.** Table 1 (p. 118) labels
   scenarios 1/3/5 as p = 2000 and 2/4/6 as p = 5000. Table 2 (p. 119) labels
   scenarios 1–3 as **p = 1000** at ρ = 0.3/0.5/0.8 and 4–6 as p = 5000. The two
   tables therefore do not index the same six settings, and p = 1000 appears
   nowhere in the design described in §4.1.
2. **Table 4's confusion-matrix margins contradict the stated test set.** The
   text (p. 120) gives 34 test samples, 20 ALL (positive) and 14 AML. Only the
   SVM Method-2 row has TP + FN = 20; the other five rows give 24, 25, or 28
   positives. The misclassification percentages are nevertheless consistent with
   (FN + FP)/34 in every row, so the error column is right and the four count
   columns are mislabelled or transposed.
3. **One Table 5 row does not sum to its test set.** Every row totals 35 except
   RF Method 2 (22 + 6 + 0 + 9 = 37), whose printed 16.22% equals 6/37 rather
   than 6/35 = 17.14%. One cell in that row is wrong.

A fourth, softer point: §4 never states whether the simulation AUCs in Table 1
are computed on held-out data or on the CV folds themselves. The real-data
results explicitly use held-out test sets (34 and 35 samples); the simulation
results carry no such statement.

## Bearing on nestedtune

- **Mostly a terminology data point, and that is worth something.** Three of the
  four sources on this shelf attach "nested cross-validation" to three different
  procedures. `DESIGN.md`'s contract boundary is precise about which one this
  package implements; user-facing documentation should be too, because a reader
  arriving from this literature may expect an inner feature-selection loop.
- **It is not evidence for the package's premise.** The comparison it wins is
  proposed-method vs single CV, with feature selection, repetition, and nesting
  all varying at once, so nothing here isolates the contribution of nesting. The
  reconciliation failures above make it weak even as a directional citation.
- **A leakage question worth carrying, not a finding.** FS<sub>final</sub> is a
  majority vote across all K outer folds, so it is a function of every training
  row; step 2 then estimates CV error over the same folds using that subset
  (§3.5, p. 114, which reuses step 1's folds explicitly). That is the shape
  Ambroise & McLachlan and `krstajic2014.md`'s pitfall 1 warn about, applied to
  the *reported* step-2 CV error rather than to the held-out test results, which
  are clean. Stated as a reading of the printed algorithm — the paper does not
  discuss it, and IP1 is not implicated in this package by anything here.
- Their stated limitation (p. 122) is the familiar one: K × V folds means
  substantially more compute, mitigated by parallelism — the same argument
  `DESIGN.md` makes for parallelizing the outer loop.

## Oracle status

**No oracle, and deliberately so.** Given the three reconciliation failures
above, no value on this page should be pinned by a test. GP2 requires oracles
that are independently checkable; this source fails that bar on its own
arithmetic. The Golub leukemia dataset (72 × 7129, public) remains a fixture
lead independent of the paper's numbers.

## Open questions

- Whether the p = 1000 scenarios in Table 2 are a typo for p = 2000 or a
  separate unreported run — unresolvable from the article text; no supplementary
  material or code repository is cited — observed 2026-07-31.
- Whether Table 1's simulation AUCs are held-out or in-fold, which decides
  whether the M2 > M1 comparison means anything — unstated in §4 — observed
  2026-07-31.
