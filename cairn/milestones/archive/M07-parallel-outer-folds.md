# M07: Parallel outer folds

**Status:** done (2026-07-26, PR #7 https://github.com/jmgirard/nestedtune/pull/7)

**Goal:** `nested_tune_grid()` runs its outer folds concurrently on mirai daemons
when the user has started them, producing results identical to a serial run.

**Outcome:** `R/parallel.R` adds `mirai_workers()`/`use_parallel()` (threshold >= 2,
mirroring tune), `dispatch_folds()` mapping per-fold payloads over `mirai::mirai_map()`
+ a plain `collect_mirai()`, `fold_task()` resolving the namespace by name rather than
carrying it, `classify_fold_result()` recognising fold records by shape, and a bounded
`check_daemons_can_load()` pre-flight. `failed_fold()` gained an optional `message`.
Enabled solely by `mirai::daemons(n)`; no exported signature changed.
`benchmarks/parallel-speedup.R`: 52.6 s to 18.6 s on 6 warm daemons, all `identical()`.

**Decisions:** D-018 (mirai backend, Suggests, >= 2 threshold, daemons must load the
package). Local: threshold mirrors tune's; failures classified by fold-record shape,
never condition inheritance; `notes$trace` outside IP2's identity claim; probe bounded.

**Review:** Two of three lenses clean; diff-bug found six, scored 82/92/68/60/78/55.
Both >= 80 fixed: F2, the BC3 test hand-rolled the dispatch path so a `.stop = TRUE`
collect left the suite green, its deviation resting on a claim review disproved by
execution; F1, aborts named internal frames. F3/F4/F5 became candidate rows; BC3's
deviation row withdrawn, BC6's stands.
