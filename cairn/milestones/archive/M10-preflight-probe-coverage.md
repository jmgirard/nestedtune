# M10: The startup check inspects every worker and says what went wrong

**Status:** done (2026-07-27, PR #10 https://github.com/jmgirard/nestedtune/pull/10)

**Goal:** The pre-flight check reaches every connected daemon and distinguishes
one that cannot load the package from one that did not answer in time.

**Outcome:** `daemons_load_status()` replaces `daemons_can_load()`, probing every
daemon via `mirai::everywhere()` rather than one `mirai()` task a single daemon
took; `preflight_outcome()` classifies each answer loaded / cannot-load /
no-answer and `check_daemons_can_load()` branches on it. A load failure keeps the
install-and-prime remedies and counts affected daemons, a non-response gets its
own message, a mixed pool names both; `nestedtune_daemons_cannot_load` and
`nestedtune_daemons_no_response` share `nestedtune_daemons_unusable`. The bound
became `options(nestedtune.preflight_timeout=)`, `Inf` refused (D-018, D-020).

**Decisions:** M10-D1 two named causes under one shared class, mixed pool names
both. M10-D2 the bound must be finite. M10-D3 the 30 s default stands and the
first-call cold-load cost it now covers is documented rather than absorbed.

**Review:** blame-history and prior-PR lenses no findings; diff-bug [O] six,
execution-verified. Actioned F1 (85) bound validated only after dispatch, F4 (88)
raised bound rendered "3e+05 ms"; F2/F3/F5/F6 sub-threshold but fixed (two gated
AC3/AC5 as written, two were false statements), F7 (52) rejected. 14/14
inversions reddened; retired the `NEWS.md`-heading and `INDEX.md`-bullets lessons.
