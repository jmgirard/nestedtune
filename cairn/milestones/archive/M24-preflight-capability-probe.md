# M24: The pre-flight tells the truth about the pool

**Status:** done (2026-07-31, PR #25 https://github.com/jmgirard/nestedtune/pull/25)

**Goal:** The dispatch-time check on a daemon pool answers the question that
decides whether the run is trustworthy — can these daemons actually run this fold.

**Outcome:** `daemons_load_status()` sends each daemon the host's whole namespace
manifest (`ls(asNamespace())`) and each reports what it lacks; `daemon_report()`
validates it positively, so a `miraiError` — a length-1 character vector — is
never read as a capability report. `preflight_outcome()` gains an `incompatible`
outcome below `cannot_load` (M10-D1's ladder extended, not reordered) and
`check_daemons_can_load()` aborts with `nestedtune_daemons_incompatible`, naming
count, missing symbols and the reinstall-then-restart remedy; a pool failing both
ways names both fixes. `pool_is_cancellable()` reads `status()$mirai`, and
`dispatch_folds()` warns once per call on a `dispatcher = FALSE` pool.

**Decisions:** Two milestone-local: the probe asks for the whole namespace, not
the two symbols the worker resolves, a hand-maintained list being the defect
fixed; and the daemons are sent an expression built by `str2lang()` from text,
which no rewriting tool reaches.

**Review:** Two passes. The first returned it on red CI — five actioned (F15 98,
F1 94, F2 88, F6 85, F9 85), ten below threshold. The second actioned two (G1 88,
G2 85), both fixed in-pass, nine logged. Nothing retired.
