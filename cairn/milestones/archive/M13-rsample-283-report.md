# M13: The rsample diagnosis reaches its maintainers

**Status:** done (2026-07-27, PR #18 https://github.com/jmgirard/nestedtune/pull/18)

**Goal:** rsample's maintainers get the cause of issue #283 and the correction
to its headline figure, in a form they can act on without re-deriving it.

**Outcome:** `benchmarks/rsample-283-reprex.R` measures `rsample::nested_cv()`
against a closed-form model, `data_bytes*v + 4n(v-1)*inner_v`, differing from
the committed lean model by (v-1) copies of the data — the diagnosis, caused by
`inside_resample()`'s `as.data.frame()`. rsample 1.3.2, seed 35222: 10x10 =
12.749x over 10 outer folds, 5x2 = 5.245x over 5, so #283's 13.02x is a 10x10
figure, not the 5x2 its prose claims; the 718,800 B gap to 2022 is row names.

**HANDOFF, still open:** post `benchmarks/rsample-283-comment.md` below its
`---` rule to https://github.com/tidymodels/rsample/issues/283, re-running the
reprex first if rsample has moved past 1.3.2. Unposted as of 2026-07-27.

**Decisions:** local — end at a committed draft plus handoff rather than post
within the milestone; rebuild both schemes explicitly, since #283's own call
now errors; keep the rsample-side model out of the test suite.

**Review:** three lenses, 27 findings, two refuted against the live issue.
Actioned: F1 (92)/F2 (88), the draft recommended the `make_splits()` path M01
abandoned; F18 (82) unsound falsification; F11 (88) wrong oracle line. 23 logged.
