# References index

_One line per committed page in `cairn/references/`. Source notes
(`<citekey>.md`) each own one primary source; synthesis notes own a
cross-source analysis no single source owns. The source shelf
(`sources/`) is gitignored and never indexed here._

_Entries are bullet lines — `- page.md — what it covers` — not table rows;
`cairn_validate`'s references check only recognizes the bullet form._

- tidymodels-nested-cv-gaps.md — synthesis; what rsample/tune do and don't provide for nested CV, 8-row gap ledger (G1–G8), CRAN name collision.
- bates2023.md — source; CV estimates average error not the model's own, and naive CV intervals under-cover; its "nested CV" is a variance-estimation device, not ours.
- krstajic2014.md — source; four CV pitfalls, repeated nested CV for assessment, and the P-estimate — a nested estimate belongs to a (model, protocol) pair. Nearest external statement of IP4.
- wainer2021.md — source; flat CV picks the same classifier as nested CV 62–71% of the time, so nesting is overzealous *for algorithm selection*; leaves the estimand argument intact.
- zhong2020.md — source; nested CV as an inner feature-selection loop (a third meaning of the term). Numbers do not reconcile; no oracle.
- stone1974.md — source; cross-validatory choice and assessment as a five-line scheme, the earliest statement here of the nested construct. **Biometrika 61(3), not the JRSS-B "double cross" paper everyone cites** — that one is not on the shelf.
- varma2006.md — source; the canonical nested CV, ours in name and construct. Tuned-CV error reads 37.8% where the truth is 50%; nesting returns 54.2%. The clearest oracle *design* on the shelf.
- ambroise2002.md — source; external vs internal CV for feature selection. Permuted labels give ≈0% internally and 0.40–0.45 externally; a held-out test set is no defence if selection saw it.
- cawley2010.md — source; model selection over-fits too. External-selection bias positive on all 13 benchmarks, up to 1.19 points — larger than the gap between competitive algorithms.
- arlot2010.md — source; the survey. Defines double cross as CV of the full calibrated algorithm A′; the minimal-variance V is framework-dependent; precise variance quantification named as *the* open problem.
- bengio2004.md — source; no **universally** unbiased estimator of Var(K-fold CV) exists, and repeating the splits does not help. The theorem under the G6 caveat.
- bayle2020.md — source; an asymptotically exact CI for k-fold test error, O(n) from per-point losses. Valid only under loss stability, targets a different estimand, and needs data we discard.
- austern2020.md — source; two estimands with two asymptotic variances, and a V-fold speed-up that is a joint property of algorithm *and* data distribution (1.638 vs 2.367 at V = 2).
