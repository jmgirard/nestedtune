# M08: Selection instability you can see

**Status:** done (2026-07-26, PR #8 https://github.com/jmgirard/nestedtune/pull/8)

**Goal:** `autoplot()` draws what each outer fold's inner tuning selected, and how the per-fold outer scores spread.

**Outcome:** `autoplot.nested_results(object, type = c("parameters", "performance"))`
in `R/nested-results-plot.R`, on ggplot2's re-exported generic, defaulting to
selections. Folds on x in design order, a panel per parameter or metric; `drop =
FALSE` on the fold scale and the metric facet keeps an attempted fold's slot and a
requested metric's panel (IP4). The rule is `summarize_folds()`'s own value, so figure
and `collect_metrics()` cannot drift. Contribution counts per panel (`rmse (from 2
folds)`), the subtitle only requested/completed; `panel_owner()` makes breaks
per-panel. Three `cli_abort()` branches; +ggplot2 Imports, +vdiffr Suggests.

**Decisions:** D-019 (one `autoplot()` with a `type` argument; the dependency pair).
Local: fold-on-x; every attempted fold keeps its slot; IP3's caveat rides the
performance subtitle, which ggplot2 renders into the image itself.

**Review:** Two rounds. The first returned it — AC3 failed, both subtitles asserting
a per-figure contribution count false whenever it differed per panel (F1 95, F2 95),
plus F3 92 (breaks defeated by a mixed grid) and F4 90 (a metric able to vanish or
crash the draw); F5/F6 logged at 78. The re-review raised F7 88 (a panel identified by
value membership, not ownership), fixed at review, plus two reviewer-side defects: a
committed `Rplots.pdf`, and the helper blindness that let F3 hide.
