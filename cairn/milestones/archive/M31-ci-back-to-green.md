# M31: Both red CI jobs go green, so a merge is possible again

**Status:** done (2026-08-30, PR #39 https://github.com/tidymodels/nestedtune/pull/39)

**Goal:** `R-CMD-check.yaml` completes with every matrix leg green, so the never-merge-red rule stops blocking every merge in the repo.

**Outcome:** The `macos-latest` leg alone resolves `gower` through pak's `?source` parameter,
via a `matrix.config.os` ternary on `extra-packages`, so the RSPM arm64 binary referencing
`___kmpc_barrier` is never fetched; the other four legs keep their binary path.
`R-CMD-check`'s job cap goes 20 → 60 minutes and `timeout-minutes: 20` moves onto the
`check-r-package` step, breaking the deadlock where a 20-minute job cap killed the devel leg's
from-source build of 129 packages before `R package cache save` ran — that cold run survived
at 23m34s and wrote the cache, the next read it at 9m37s. Cap comments in the three other
workflows and `PROFILE.md`'s test-doctrine slot now state both caps and their scopes.

**Decisions:** none milestone-local; three plan-gate choices are in the work log (source
install for gower only; the hang bound moved to the step as the job cap rose; the 7-day cache
idle expiry accepted over a warm-up workflow).

**Review:** Three-lens fan-out — blame-history none, prior-review one (shared with diff-bug),
diff-bug twelve, none a correctness problem in the executable parts. Eight fixed on the branch:
a job-scope statistic left pricing a step-scope cap, both hangs mis-attributed to one workflow,
a third stale cap cross-reference in `pkgdown.yaml`, the unbounding of every non-check step left
unstated, a work-log undercount, a stale provenance list, an unmeasured "twice", an unexplained
grep. One routed to the CI-records row, four rejected. Six criteria passed; gate clean.
