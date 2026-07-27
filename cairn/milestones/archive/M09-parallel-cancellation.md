# M09: A stopped run reports nothing, not a partial estimate

**Status:** done (2026-07-26, PR #9 https://github.com/jmgirard/nestedtune/pull/9)

**Goal:** a parallel run cancelled from outside aborts, instead of recording the
folds that never ran as folds that were attempted and failed.

**Outcome:** `classify_fold_result()` gains `is_cancelled_value()`, allowlisting
nanonext's ECANCELED (20) by positive shape validation, and aborts on it with
`c("nestedtune_cancelled", "nestedtune_interrupted")` — the subclass keeps M07's
handlers working. `benchmarks/probe-mirai-cancellation.R` + M09-D1 record the
probe. Roxygen, two NEWS entries; no exported signature changed.

**Decisions:** M09-D1 (mirai's teardown values, by execution, mirai 2.7.2). Gate:
allowlist rather than invert the default, so an unrecognised value keeps M03's
failed-fold behaviour; cancellation subclasses the interrupt condition. Amended
mid-flight — the plan assumed cancellation is always code 20, but 19 covers a
`daemons(0)` teardown *and* a dying daemon alike, so 19 keeps its behaviour.

**Review:** Two of three lenses clean. Diff-bug found four, scored 82/87/78/33.
F2 and F3 fixed — the AC4 assertion pinned nothing (`tryCatch(condition=)` caught
the old path's warning) and the "bound" was a post-hoc `system.time()`. F1 fixed
below threshold: roxygen put the interrupt class on the wrong event, disproved
against mirai's docs. F4 rejected on RR03 Q4. Review also caught two T2 tests
passing only because an earlier test loaded mirai as a side effect.
