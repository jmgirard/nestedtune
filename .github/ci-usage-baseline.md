# CI usage — jmgirard/nestedtune

Window `[2026-07-26T00:00:00Z, 2026-07-27T07:00:00Z)`, runs with status `completed`. Default branch `main`.

Path filter read from R-CMD-check.yaml, test-coverage.yaml: `.claude/**`, `CLAUDE.md`, `cairn/**`

| category | runs | machine-min |
|---|---|---|
| total | 108 | 2276 |
| on skipped commits | 30 | 628 |
| superseded (all) | 32 | 823 |
| superseded off `main` | 9 | 248 |
| **removed by the filter + off-branch cancel** | **39** | **877** |

Jobs in window: 324. The two waste categories overlap (a tracking commit on the default branch can be both) and are never summed; the last row is their union, counted once.

## Default-branch commits (15 of 24 skipped)

| commit | verdict | files | first packaged paths |
|---|---|---|---|
| `040e4bd86` Printing surfaces the run and its disagreeme | run | 12 | `NAMESPACE`, `NEWS.md`, `R/nested-results-print.R` |
| `363592f03` Parallel outer folds (#7) | run | 16 | `.Rbuildignore`, `DESCRIPTION`, `NEWS.md` |
| `39d2f6898` Outer-loop orchestration: nested_tune_grid() | run | 23 | `DESCRIPTION`, `NAMESPACE`, `NEWS.md` |
| `45a6e898d` Selection instability you can see (#8) | run | 21 | `.gitignore`, `DESCRIPTION`, `NAMESPACE` |
| `508c9ef5d` A stopped run reports nothing, not a partial | run | 9 | `NEWS.md`, `R/nested-tune-grid.R`, `R/parallel.R` |
| `6ff3f08fb` M03: fold failures are recorded, never fatal | run | 14 | `NAMESPACE`, `NEWS.md`, `R/checks.R` |
| `a6ee0f42f` M05: the final model is its own object (#5) | run | 27 | `NAMESPACE`, `NEWS.md`, `R/checks.R` |
| `b34069dc6` A guide that says what to report (#6) | run | 8 | `DESCRIPTION`, `NEWS.md`, `README.md` |
| `fafb31f5b` M01: memory-lean nested resampling structure | run | 26 | `.Rbuildignore`, `.github/.gitignore`, `.github/workflows/R-CMD-check.yaml` |
| `138e2b009` plan M03, M04: failed-fold recording and res | skipped | 3 | — |
| `253b4f963` plan M09, M10: the parallel path fails hones | skipped | 4 | — |
| `3bacc9f17` review M05: done | skipped | 4 | — |
| `4756c71e2` hygiene: /milestone audit pass — all checks  | skipped | 1 | — |
| `4d78627b5` plan M05, M06: the final model is its own ob | skipped | 4 | — |
| `61a51493c` review M07: done | skipped | 4 | — |
| `8066de42e` review M01: done | skipped | 4 | — |
| `8376447b7` review M02: done | skipped | 4 | — |
| `83b95fd5b` review M08: done | skipped | 4 | — |
| `b33514374` review M03: done | skipped | 4 | — |
| `bbb432896` review M09: done | skipped | 4 | — |
| `c0b3ed31e` plan M08: selection instability you can see | skipped | 3 | — |
| `ca0cc66bd` plan M07: parallel outer folds | skipped | 2 | — |
| `d2f1b6ada` review M06: done | skipped | 4 | — |
| `fc7cf0fac` review M04: done | skipped | 4 | — |
