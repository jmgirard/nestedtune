# M21: A run says which candidates it actually searched, fold by fold

**Status:** done (2026-07-30, PR #22 https://github.com/jmgirard/nestedtune/pull/22)

**Goal:** Record on `nested_results` the candidate set each outer fold actually scored, so
IP4's "the grid actually evaluated" clause is checkable on the object.

**Outcome:** A `.grid` list column per outer fold, built by `scored_candidates()` from the
tuning run's `.metrics` — a `tune_results` records its expansion nowhere else (measured,
tune 2.1.0). Required by `has_results_columns()` and `is_fold_record()`, both
mutation-verified; `failed_fold()` gained `tuned`, so a fold failing after tuning keeps what
it scored. `print_candidate_sets()`/`same_candidates()` report per-fold counts when sets
differ — `grid = 10` on a continuous parameter gives every fold its own, expansion drawing
from the generator. Oracles O3 (hand-run `tune_grid()` per `.tuning_seed`) and O4
(data-frame invariant). A candidate failing every inner resample is absent, kept in `.notes`.

**Decisions:** none milestone-local. Plan gate chose recording what scored over generating the
grid (whose shared-grid shape is `ip-touching`), a bare zero-row table, and observing rather
than asserting the cross-fold difference.

**Review:** three lenses, 18 findings (diff-bug 18, blame 0, prior-review 0). Actioned: F1
(90) `print()` raised on a list-valued parameter column via `order()`, row order now
normalising through a rendered key; F9 (82) failure-section doc wrong for tune-then-fail; F2
(78) a shipped comment cited a different code path. Sixteen logged below threshold; merged
with codecov's diff target red at approval; nothing met retirement.
