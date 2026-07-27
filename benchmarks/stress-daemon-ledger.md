# Stress ledger: the daemon tests, 50 iterations, no hang

Produced by `benchmarks/stress-daemon-tests.R` (M14 T7 / AC5). Recorded so the
next attempt at this hang does not repeat an attempt that has already been made.

## Run

- 2026-07-27, started 19:37:37Z, finished 20:34:08Z — 57 minutes wall.
- `Rscript benchmarks/stress-daemon-tests.R 50 600` from the repo root.
- macOS, `aarch64-apple-darwin25.4.0`, R 4.6.1, mirai 2.7.2, nanonext 1.10.1.
- 50 iterations × 3 files = **150 runs**, each in a fresh R process behind a
  600 s kill deadline.

## Result

**0 hangs of 150 runs.** No iteration reached its deadline; nothing was killed.

| file | n | min | median | mean | max |
|---|---|---|---|---|---|
| `test-parallel-identity.R` | 50 | 35.5 s | 41.5 s | 48.0 s | 142.9 s |
| `test-parallel-classify.R` | 50 | 12.1 s | 13.0 s | 14.5 s | 40.7 s |
| `test-parallel-detection.R` | 50 | 3.4 s | 4.0 s | 4.6 s | 18.4 s |

The three slowest runs are iterations 1–3 of `parallel-identity` (142.9 s,
131.6 s, 119.8 s), which overlapped other work on the same machine; from
iteration 4 the file settles near its 41.5 s median. That spread is CPU
contention, not the signature being hunted — a wedge does not finish at all,
which is why the harness kills rather than times.

## What this does and does not establish

It does not clear the code. The hang has occurred three times in roughly 400 CI
jobs and **never once on a maintainer's machine**, so a clean local result is
consistent with every hypothesis about it, including the ones that matter. What
it rules out is a defect frequent enough to surface in 150 local runs, and it
prices the local route: 57 minutes buys that much and no more.

The informative run is therefore the CI one, on the platform where the hang
actually happens — `.github/workflows/stress-daemon-tests.yaml`, dispatched by
hand. GitHub refuses to dispatch a `workflow_dispatch` workflow that is not yet
on the default branch, so the first macOS invocation is owed once M14 merges
(AC5, amended at a gate 2026-07-27).
