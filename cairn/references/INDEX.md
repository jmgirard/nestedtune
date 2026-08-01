# References index

_One line per committed page in `cairn/references/`. Source notes
(`<citekey>.md`) each own one primary source; synthesis notes own a
cross-source analysis no single source owns. The source shelf
(`sources/`) is gitignored and never indexed here._

_Entries are bullet lines — `- page.md — what it covers` — not table rows;
`cairn_validate`'s references check only recognizes the bullet form._

- tidymodels-nested-cv-gaps.md — synthesis; what rsample/tune do and don't provide for nested CV, 8-row gap ledger (G1–G8), CRAN name collision.
- mori-backend-assessment.md — synthesis; mori leaves the seed contract and the mirai choice untouched and reaches 0 copies on the wire, but it is same-machine, so it makes M23's lean path conditional rather than obsolete. 10-row premise ledger (P1–P10).
- outer-loop-object-requirements.md — synthesis; what a nested-resampling object must carry for a driver: 19 reads (R1–R19), 7 reconstructions (C1–C7), 11 class-boundary workarounds (W1–W11), and the two size axes measured — the in-process ratio grows with v, and a `nested_cv()` fold's own materialized frame is wire cost no dispatch-side leaning can remove.
- bates2023.md — source; CV estimates average error not the model's own, and naive CV intervals under-cover; its "nested CV" is a variance-estimation device, not ours.
- krstajic2014.md — source; four CV pitfalls, repeated nested CV for assessment, and the P-estimate — a nested estimate belongs to a (model, protocol) pair. Nearest external statement of IP4.
- wainer2021.md — source; flat CV picks the same classifier as nested CV 62–71% of the time, so nesting is overzealous *for algorithm selection*; leaves the estimand argument intact.
- zhong2020.md — source; nested CV as an inner feature-selection loop (a third meaning of the term). Numbers do not reconcile; no oracle.
- stone1974a.md — source; **the founding paper** (JRSS-B 36(2), with Discussion). The nested assessment is its §2 item V, a "two-deep" analysis; "double-cross" is item VI, a two-stage *choice*, which the later literature conflates. Item VII says the selection loss need not be the assessment loss. Dawid's discussion asks G6's question in 1973.
- stone1974b.md — source; the Biometrika 61(3) companion, which restates the scheme in its Appendix and shows the choice flipping under a change of loss. Read `stone1974a.md` first.
- varma2006.md — source; the canonical nested CV, ours in name and construct. Tuned-CV error reads 37.8% where the truth is 50%; nesting returns 54.2%. The clearest oracle *design* on the shelf.
- ambroise2002.md — source; external vs internal CV for feature selection. Permuted labels give ≈0% internally and 0.40–0.45 externally; a held-out test set is no defence if selection saw it.
- cawley2010.md — source; model selection over-fits too. External-selection bias positive on all 13 benchmarks, up to 1.19 points — larger than the gap between competitive algorithms.
- arlot2010.md — source; the survey. Defines double cross as CV of the full calibrated algorithm A′; the minimal-variance V is framework-dependent; precise variance quantification named as *the* open problem.
- bengio2004.md — source; no **universally** unbiased estimator of Var(K-fold CV) exists, and repeating the splits does not help. The theorem under the G6 caveat.
- bayle2020.md — source; an asymptotically exact CI for k-fold test error, O(n) from per-point losses. Valid only under loss stability, targets a different estimand, and needs data we discard.
- austern2020.md — source; two estimands with two asymptotic variances, and a V-fold speed-up that is a joint property of algorithm *and* data distribution (1.638 vs 2.367 at V = 2).
- tibshirani2009.md — source; the cheap alternative to nesting — correct the minimum CV error from the per-fold curves, no refitting. Bias material only at p ≫ n; Theorem 1 proves the null-data bound analytically.
- vabalas2019a.md — source; the K-fold bias survives to n = 1000, and leaky feature selection costs far more than leaky tuning. The answer to "isn't this just a small-n problem?".
- wilimitis2023.md — source; the honest null result. On 41k MIMIC-III rows with a small grid, nesting scored *worse* by 0.002 AUPR and cost O(k²) — and the authors say why.
- tsamardinos2018.md — source; BBC-CV bootstraps the pooled out-of-sample predictions to remove selection bias without refitting, and recommends forgoing NCV. Its own numbers still put NCV first on bias.
- luo2026.md — source; inference on a *procedure's* risk is provably hard unless N ≫ n, and stability does not rescue it. The theory under IP3, and a categorical fourth blocker for G6.
- luo2025.md — source; the companion — certifying a black-box algorithm's (ε, δ)-stability is impossible without exhaustive search. Read after `luo2026.md`; the notion is prediction-based, not loss-based.
- bayle2026.md — source; two individually stable algorithms can have an unstable *comparison*, and `bayle2020.md`'s CV interval then under-covers. Not the same A. Bayle as the 2020 paper's first author.
- gauran2025.md — source; a valid test and CI *from* a nested design, bought with a ridge closed form the package's contract boundary excludes. Its Table 1 maps seven names for prediction error.
- nachum2026.md — source; MSE = squared-loss-stability + fold covariance, so no fold count is universally optimal, and every ERM faces an Ω(√k*/n) floor. Carries the shelf's first analytic outer-loop oracle candidate.
