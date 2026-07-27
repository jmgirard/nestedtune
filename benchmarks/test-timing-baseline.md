# Test-suite timing baseline

What `benchmarks/profile-tests.R` reported on the tree **before** the fixture
cache landed. Re-run the same script on the finished branch, on this machine and
this R version, to get the comparable figure.

Every condition below is part of the measurement, not decoration: the suite
total moves with all of them, and a re-run under different ones is not a
comparison.

| Condition | Value |
|---|---|
| Commit measured | `d095bae` (the branch point; no test file had changed yet) |
| R | 4.6.1 (2026-06-24) |
| OS | macOS Tahoe 26.5.2 |
| testthat | 3.3.2 |
| `NOT_CRAN` | `true` (set by the script, as `devtools::test()` does) |
| Package loading | loaded **once** for all files via `pkgload::load_all()`; helpers sourced once; each file runs in a child of that environment |
| `lobstr` | installed (1.2.1) |
| `mlbench` | installed (2.1.10) |
| `ranger` | installed (0.18.0) |
| `vdiffr` | installed (1.0.9) |
| Runs | 3; every figure below is the median of the three |

Result of the run: **pass 1175 | fail 0 | skip 0**. No test was skipped, so the
figures cover the whole suite rather than the part that happened to run.

## Median seconds per file

| File | Seconds | Share |
|---|---:|---:|
| `test-nested-results-plot.R` | 95.7 | 29.2% |
| `test-parallel-identity.R` | 63.1 | 19.3% |
| `test-nested-results-print.R` | 60.9 | 18.6% |
| `test-nested-tune-grid-failures.R` | 35.9 | 11.0% |
| `test-nested-tune-grid-rng.R` | 15.2 | 4.6% |
| `test-nested-tune-grid-results.R` | 13.1 | 4.0% |
| `test-parallel-classify.R` | 12.0 | 3.7% |
| `test-nested-resamples-memory.R` | 9.3 | 2.8% |
| `test-nested-tune-grid-oracles.R` | 6.6 | 2.0% |
| `test-nested-final-fit-rng.R` | 5.3 | 1.6% |
| `test-nested-final-fit-print.R` | 3.0 | 0.9% |
| `test-nested-final-fit-results.R` | 2.4 | 0.7% |
| `test-parallel-detection.R` | 2.3 | 0.7% |
| `test-nested-final-fit-oracles.R` | 2.0 | 0.6% |
| `test-nested-tune-grid-leakage.R` | 1.8 | 0.6% |
| `test-nested-resamples-specs.R` | 1.2 | 0.4% |
| `test-nested-resamples-identity.R` | 1.2 | 0.4% |
| `test-nested-tune-grid-checks.R` | 0.7 | 0.2% |
| `test-nested-final-fit-checks.R` | 0.7 | 0.2% |
| `test-nested-resamples-regressions.R` | 0.4 | 0.1% |
| `test-nested-resamples-rng.R` | 0.3 | 0.1% |
| **SUITE TOTAL** | **327.3** | |
| Wall clock for one pass | 328.4 | |

## What the shape says

The six files this milestone converts hold **211.0 s, 64.5% of the suite**:
plot 95.7, print 60.9, failures 35.9, tune-grid-results 13.1, final-fit-print
3.0, final-fit-results 2.4. Nearly all of it is spent rebuilding tuning runs
that are identical to one another — `test-nested-results-plot.R` alone requests
the same `nested_tune_grid()` result seventeen times.

Two of the heaviest files are deliberately left alone.
`test-parallel-identity.R` (63.1 s) spends most of its time restarting mirai
worker pools, and sharing one pool across its tests would risk exactly the
reproducibility guarantee those tests exist to prove. The oracle files
(`test-nested-tune-grid-oracles.R`, `test-nested-final-fit-oracles.R`,
8.6 s together) duplicate their reference runs on purpose — that duplication is
the oracle, and removing it would remove the check.
