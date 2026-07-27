# CI usage — jmgirard/nestedtune

Window `[2026-07-26T00:00:00Z, 2026-07-27T07:00:00Z)`, runs with status `completed`. Default branch `main`.

Path filter read from R-CMD-check.yaml, test-coverage.yaml: `cairn/**`, `CLAUDE.md`, `.claude/**`

| category | runs | machine-min | reclaimable |
|---|---|---|---|
| total | 108 | 2276 | — |
| on skipped commits | 30 | 628 | 628 |
| superseded (all) | 32 | 823 | 442 |
| superseded off `main` | 9 | 248 | 162 |
| **removed by the filter + off-branch cancel** | **39** | — | **790** |

Jobs in window: 324.

`machine-min` is what those runs cost; `reclaimable` is what removing them saves, and only the second is a saving. A skipped commit fires no run at all, so the two are equal for it. Cancelling a superseded run reclaims only the tail still to come when its successor was created — which is why the superseded rows differ. The two waste categories overlap (a tracking commit on the default branch can be both) and are never summed; the last row is their union, counted once.

## Default-branch commits (22 of 32 skipped)

Enumerated from `git log`, not from the runs they fired — a commit the filter skips fires no run, and a run-derived list would lose it.

| commit | verdict | files | runs | first packaged paths |
|---|---|---|---|---|
| `040e4bd86` Printing surfaces the run and its disagr | run | 12 | 2 | `NAMESPACE`, `NEWS.md`, `R/nested-results-print.R` |
| `363592f03` Parallel outer folds (#7) | run | 16 | 2 | `.Rbuildignore`, `DESCRIPTION`, `NEWS.md` |
| `39d2f6898` Outer-loop orchestration: nested_tune_gr | run | 23 | 2 | `DESCRIPTION`, `NAMESPACE`, `NEWS.md` |
| `45a6e898d` Selection instability you can see (#8) | run | 21 | 2 | `.gitignore`, `DESCRIPTION`, `NAMESPACE` |
| `508c9ef5d` A stopped run reports nothing, not a par | run | 9 | 2 | `NEWS.md`, `R/nested-tune-grid.R`, `R/parallel.R` |
| `6ff3f08fb` M03: fold failures are recorded, never f | run | 14 | 2 | `NAMESPACE`, `NEWS.md`, `R/checks.R` |
| `a6ee0f42f` M05: the final model is its own object ( | run | 27 | 2 | `NAMESPACE`, `NEWS.md`, `R/checks.R` |
| `a7ef98f87` cairn-init: scaffold tracking system | run | 11 | 0 | `.Rbuildignore`, `.gitignore` |
| `b34069dc6` A guide that says what to report (#6) | run | 8 | 2 | `DESCRIPTION`, `NEWS.md`, `README.md` |
| `fafb31f5b` M01: memory-lean nested resampling struc | run | 26 | 2 | `.Rbuildignore`, `.github/.gitignore`, `.github/workflows/R-CMD-check.yaml` |
| `01ca49136` design-interview: Phase 2 principles (IP | skipped | 3 | 0 | — |
| `138e2b009` plan M03, M04: failed-fold recording and | skipped | 3 | 2 | — |
| `248a86f10` tracking: refresh hygiene stamp after /m | skipped | 1 | 0 | — |
| `253b4f963` plan M09, M10: the parallel path fails h | skipped | 4 | 2 | — |
| `3bacc9f17` review M05: done | skipped | 4 | 2 | — |
| `4756c71e2` hygiene: /milestone audit pass — all che | skipped | 1 | 2 | — |
| `4d78627b5` plan M05, M06: the final model is its ow | skipped | 4 | 2 | — |
| `50a426a34` design-interview: ledger tidymodels nest | skipped | 3 | 0 | — |
| `61a51493c` review M07: done | skipped | 4 | 2 | — |
| `8066de42e` review M01: done | skipped | 4 | 2 | — |
| `8376447b7` review M02: done | skipped | 4 | 2 | — |
| `83b95fd5b` review M08: done | skipped | 4 | 2 | — |
| `aa93545f5` design-interview: Phase 1 facts, contrac | skipped | 4 | 0 | — |
| `b33514374` review M03: done | skipped | 4 | 2 | — |
| `bbb432896` review M09: done | skipped | 4 | 2 | — |
| `c0b3ed31e` plan M08: selection instability you can  | skipped | 3 | 2 | — |
| `ca0cc66bd` plan M07: parallel outer folds | skipped | 2 | 2 | — |
| `d2f1b6ada` review M06: done | skipped | 4 | 2 | — |
| `dfe141416` plan M01: memory-lean nested resampling  | skipped | 5 | 0 | — |
| `f8d65ad86` design-interview: record elicitation pro | skipped | 1 | 0 | — |
| `faf80f165` plan M02: outer-loop orchestration | skipped | 3 | 0 | — |
| `fc7cf0fac` review M04: done | skipped | 4 | 2 | — |
