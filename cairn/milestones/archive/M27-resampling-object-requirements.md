# M27: What the outer loop needs from the resampling object, in writing

**Status:** done (2026-08-01, PR #29 https://github.com/jmgirard/nestedtune/pull/29)

**Goal:** The maintainer gets a cited account of what a nested-resampling
object must carry for a driver, and what today's shape forces it to rebuild.

**Outcome:** `references/outer-loop-object-requirements.md`: 19 driver reads
(R1-R19), 7 reconstructions with the carrying field removing each (C1-C7),
11 rsample class-boundary workarounds (W1-W11), all `file:line`.
`benchmarks/outer-loop-object-requirements.R` (#283-reprex sibling):
`nested_cv()` vs `nested_resamples()` obj_size 3.228x at 5x5, 5.094x at
20x5 (models within 1.02%); on the wire a `nested_cv()` fold's own
materialized frame is ~89% of its 754,858 B payload, removable only by
reindexing (copy-count oracle 1 vs 0).
`benchmarks/resampling-object-writeup.md`: unposted maintainer draft,
claims tagged (measured)/(inferred), mori caveat naming what M26 changes.

**Decisions:** none promoted; implement gate chose 5x5+20x5 settings and a
sibling script so the committed #283 recipe stays byte-stable.

**Review:** 3 lenses + scorer, 25 candidates, 3 actioned and fixed: a
wrong-denominator "~70%" figure (actually 89.1%), a tautological wire-gap
attribution (frame minus 16,028 B extra indices = 656,512 B gap), a false
LetterRecognition-integer claim. 22 sub-80 logged (git); nothing retired.
