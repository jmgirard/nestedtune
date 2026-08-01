# M29: The assessment says only what the manifest measured

**Status:** done (2026-08-01, PR #28 https://github.com/jmgirard/nestedtune/pull/28)

**Goal:** The mori assessment note and the tracking records carry only figures
M26's manifest measured — history marked as history — checked mechanically.

**Outcome:** `references/mori-backend-assessment.md` rewritten against
`benchmarks/mori-wire-manifest.json`: manifest values throughout, correction
layers collapsed, M23 totals and the 3.87x dev-state capture quarantined in a
marked [historical] subsection, three unmeasured adoption deltas recorded.
Drift check shipped (`tests/testthat/{helper,test}-drift-manifest.R`):
name=rendering@count declarations in the note and ROADMAP mori row, compared
to the manifest at printed precision with exact occurrence counts (a drifted
duplicate cannot hide); four permanent red shapes; skips from a built tarball.
The tune#1188 draft deleted; downscope applied via gated plan amendment.

**Decisions:** none milestone-local; gate choices in the work log (historical
figures kept marked-as-history, draft deleted, check as testthat test).

**Review:** three lenses: diff-bug 15 findings, blame-history 0, prior-review
0. Actioned ≥80, all fixed: presence-masking pair (82/80, executed demos, →
occurrence counts), the ~451 B non-manifest figure backing a current claim
(90) with its broken arithmetic (88), list-splitting ROADMAP comment (90).
Ten sub-threshold logged; three fixed in passing. Nothing graduated/retired.
