# M15: An interrupted run stops the work it started

**Status:** done (2026-07-27, PR #14 https://github.com/jmgirard/nestedtune/pull/14)

**Goal:** A parallel `nested_tune_grid()` run that is interrupted leaves no fold
still computing on the daemons the user will reuse next.

**Outcome:** `dispatch_folds()` cancels its dispatched `mirai_map` from an
unconditional `on.exit(mirai::stop_mirai(mapped))`, so every exit after dispatch
stops the outstanding folds while a resolved map stays untouched. The roxygen
contract and NEWS state that behaviour and its two limits — cancelling needs
mirai's dispatcher, and stopping is a request compiled fitting code may not
honour. `daemons_load_status()`'s no-hang comment is scoped to the mirai version
verified; new `test-parallel-interrupt.R` interrupts a run with a real SIGINT.

**Decisions:** the cancel is unconditional, not flag-gated — `stop_mirai()` on a
resolved map is inert, so covering every exit costs nothing; the reachable exits
are enumerated, including the one no guard reaches (an error inside `mirai_map()`).

**Review:** three lenses, two clean. F1 (82) the cancel was inert on a
`dispatcher = FALSE` pool while the docs promised it — verified and scoped; F2
(88) overclaimed certainty — reworded; F3 (78) stray-SIGINT risk, fixed anyway.
