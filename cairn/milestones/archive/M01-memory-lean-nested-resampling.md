# M01: Memory-lean nested resampling structure

**Status:** done (2026-07-25, PR #1 https://github.com/jmgirard/nestedtune/pull/1)

**Goal:** Ship a nested-resampling constructor whose object size does not grow
with the outer fold count, producing splits row-identical to rsample's.

**Outcome:** `nestedtune` ships as an R package (rsample, cli, rlang in
Imports) exporting `nested_resamples(data, outside, inside)`. It runs the inner
spec on each outer fold's transiently materialized analysis frame, keeps only
the indices, and remaps them by rewriting `data`/`in_id`/`out_id` on rsample's
own splits, so class, attributes and ids survive. At 50 outer folds: 10.0x the
source data vs rsample's 57.5x (LetterRecognition, inner v = 5), slope 0.183 vs
1.152. Outer bootstraps and mismatched prebuilt `outside` rsets are refused.

**Decisions:** D-008 (export name and class), D-009 (cli/rlang in Imports).
Local: transient materialization over a stand-in frame; inner rsets keep their
spec's identity, not `manual_rset()`'s; a row-name divergence proved false.

**Review:** Two lenses clean; [O] diff-bug found 7. Four scored >=80, all fixed
on the branch: F1 IP1 leakage via a prebuilt `outside` rset on other data (88),
F2 missing per-split `id` (85), F3 lost subclass (82), F5 overclaiming docs
(80). F4 (68), F6 (55) logged; F7 (78) became a ROADMAP candidate.
