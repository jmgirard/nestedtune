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
