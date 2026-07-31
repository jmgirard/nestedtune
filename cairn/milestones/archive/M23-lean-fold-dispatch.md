# M23: A worker is sent the fold, not six copies of the data

**Status:** done (2026-07-30, PR #24 https://github.com/jmgirard/nestedtune/pull/24)

**Goal:** Dispatching an outer fold to a mirai daemon sends one copy of the data instead
of one per inner split, so `nested_resamples()`'s leanness survives serialization.

**Outcome:** `R/parallel.R` gains `lean_payload()`/`rehydrate_payload()`, blanking `$data`
in place (`x["data"] <- list(NULL)`, so the round trip is `identical()`) on the outer split
and every inner split and restoring it worker-side; `is_fold_payload()` gates leaning and
verifies the one-frame-per-fold invariant. Data travels once in `mirai_map()`'s `.args`,
the worker by value beside it so `local_mocked_bindings()` still reaches daemons; a fold
whose frame is not the shared one carries its own, covering `rsample::nested_cv()`.
25,714,635 B -> 5,783,645 B on a 5-fold 5,000x21 fixture, guarded by a closed form over
n/v/inner_v and a `grepRaw()` count of the data's wire bytes.

**Decisions:** local — lean on the parallel branch only, leaving serial as IP2's fixed
reference; data in `.args` rather than the payload; `utils::removeSource()` on the worker
measured (203,790 B vs 524 B) and dropped rather than add `utils` to Imports unilaterally.

**Review:** Two of three lenses clean; diff-bug found 16, four >= 80 all fixed. F1 (93):
the inner-frame invariant went unenforced, so a `manual_rset` over differing frames tuned
on the wrong rows in parallel — an IP2 breach shown by execution, predating M23. F2 (90):
forcing the gate FALSE left all 55 assertions green. F3 (85) band, F4 (82) unsourced
benchmark oracles. 12 logged below threshold; codecov drove 2 tests to 100% of diff hit.
