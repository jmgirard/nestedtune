# M21: A run says which candidates it actually searched, fold by fold

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4, GP1
- **Branch/PR:** `m21-evaluated-grid-record`

## Goal

Record on `nested_results` the candidate set each outer fold actually scored, so
IP4's "the grid actually evaluated" clause is checkable on the object instead of
documented as unmet.

## Scope

**In:** a `.grid` list column on `nested_results`, one element per outer fold,
holding the distinct candidates that fold's inner tuning scored, read back from
the tuning run inside the worker. The record survives the failure paths: a fold
that loses some candidates keeps the rest, a fold that fails at the outer fit
keeps everything its tuning scored, a fold that scored nothing carries a zero-row
table. `attr(x, "grid")` keeps its present meaning — the request as given — and
`@return` states how the two differ. One print line when folds searched different
candidate sets.

**Out:**

- Generating the grid ourselves so the *attempted* set is known, rather than
  reading back what scored → ROADMAP candidate row, carrying the two shapes the
  plan gate weighed (per-fold expansion, and one shared grid expanded up front).
  The second hits the `ip-touching` tripwire and needs its own decision before it
  is plannable.
- A hard assertion that outer folds evaluate *different* candidate sets → the
  same candidate row. It is true on tune 2.1.0 and recorded as an observation
  here, but it is a fact about tune's expansion, which IP2 declines to guarantee
  across tune versions.
- The same record on `nested_final_fit` → ROADMAP candidate row. That object
  retains its whole tuning run, so the scored candidates are already reachable,
  just not named.

## Acceptance criteria

- [ ] AC1: `nested_tune_grid()` returns a `nested_results` carrying a `.grid`
      list column with one element per outer fold. For a fold whose inner tuning
      scored at least one candidate, the element is a tibble with one row per
      distinct candidate scored, one column per tuned parameter, plus tune's
      `.config` label.
- [ ] AC2: with a data-frame `grid` whose candidates all score, each fold's
      `.grid` element holds exactly that frame's candidates — same row count,
      same values in every parameter column, compared after ordering both sides
      by the shared parameter columns. Not by `.config`: `tune_grid()` renumbers
      `.config` into ascending parameter order, so a request frame given in any
      other order fails a `.config`-ordered comparison on an identical set.
- [ ] AC3: with an integer `grid`, a completed fold's `.grid` element equals the
      candidate set `tune::tune_grid()` scores when run by hand on that fold's
      inner resamples under that fold's `.tuning_seed` with the generator kind
      pinned — asserted for a workflow tuning a continuous parameter.
- [ ] AC4: an integer `grid` larger than the reachable candidate count is
      recorded as what ran, not as what was asked: a request whose expansion
      truncates leaves `attr(x, "grid")` at the requested number while every
      completed fold's `.grid` element holds the smaller set that scored.
- [ ] AC5: `.grid` records what that fold scored, on every failure path. A fold
      completing with one candidate that failed on all its inner resamples holds
      one row fewer than the requested frame, omitting exactly that candidate; a
      fold that failed at the **outer fit** holds the full set its inner tuning
      scored; a fold that scored nothing — every candidate failed, or no tuning
      result was reached — holds a zero-row tibble, never `NULL` and never a
      missing element.
- [ ] AC6: `.grid` is one of the columns a `nested_results` is defined by —
      dropping it in a column subset sheds the `nested_results` class, exactly as
      dropping `.metrics` does.
- [ ] AC7: a fold record arriving from a mirai worker with no grid element is
      classified as a failed fold rather than accepted as completed —
      `is_fold_record()` (`R/parallel.R:389`) requires it, verified by mutation:
      dropping it from the required set leaves the suite red. The serial path
      builds its own records and is not reached by this guard.
- [ ] AC8: printing a result whose completed folds scored different candidate
      sets says so in one line; printing one where they agree does not. Both are
      snapshot-covered, and the method still never raises and never warns.
- [ ] AC9: `@return` for `nested_tune_grid()` documents both records and how they
      differ — `attr(x, "grid")` is the request as given, `.grid` is what each
      fold scored, they diverge whenever a size was passed or a candidate failed,
      and a candidate that failed on every inner resample is absent from `.grid`.
- [ ] AC10: `Rscript -e 'devtools::test()'` clean; `devtools::document()` no
      diff; `Rscript -e 'devtools::check()'` clean (0 errors, 0 warnings; NOTEs
      justified).

## Coverage

- AC1 → T2, T3
- AC2 → T1, T3
- AC3 → T6
- AC4 → T6
- AC5 → T2, T5
- AC6 → T3
- AC7 → T4
- AC8 → T7
- AC9 → T8
- AC10 → T8

## Tasks

- [x] T1: failing test first — a data-frame grid, asserting each completed fold's
      `.grid` element against the frame passed in, ordered by the shared
      parameter columns. Reuses the existing orchestration fixtures
      (`tests/testthat/helper-orchestration.R`).
- [x] T2: `nested_fold_fit()` (`R/nested-tune-grid.R:295`) reads the scored
      candidates off `tuned` and returns them; `failed_fold()`
      (`R/nested-tune-grid.R:365`) gains the same element, taking the set from
      `tuned` where there is one — the outer-fit path has one and currently
      passes `NULL` (`R/nested-tune-grid.R:335`) — and a bare zero-row tibble
      otherwise.
- [x] T3: `new_nested_results()` (`R/nested-results.R:8`) assembles the `.grid`
      column; `has_results_columns()` (`R/nested-results.R:106`) requires it.
- [x] T4: `is_fold_record()` (`R/parallel.R:389`) requires the grid element;
      mutation-verify by dropping it from the required set and confirming red.
- [x] T5: failure-path tests — one candidate failing everywhere, an outer-fit
      failure, and a fold where every candidate failed.
- [x] T6: integer-grid oracle test on a continuous-parameter workflow: the
      by-hand `tune_grid()` comparison under the fold's `.tuning_seed`, plus the
      truncation case. Record the observed cross-fold difference in the file's
      oracle provenance header without asserting it.
- [ ] T7: the print line for disagreeing candidate sets
      (`R/nested-results-print.R`), beside the existing selection-instability
      line; re-record affected snapshots.
- [ ] T8: `@return` and the failure section in `R/nested-tune-grid.R`;
      `devtools::document()`; NEWS entry; full `check()`.

## Work log

- 2026-07-30: created by /milestone-plan.
- 2026-07-30: start — status in-progress, branch `m21-evaluated-grid-record` cut from `4cc1a9e`.
- 2026-07-30: implement gate — one question open (the disagreement print line's content); chose counts then the difference over the bare flag, because counts separate same-size-different-values from one fold truncating further. Everything else had one right answer and was settled inline: candidates come from the tuning run's `.metrics` (unioned across inner resamples, deduped and ordered by `.config`) because `collect_metrics()` raises when all models failed; no `BUDGETED_FILES` row is owed since nothing added waits.
- 2026-07-30: T1-T4 — `.grid` column recorded, required by `has_results_columns()` and `is_fold_record()`. The new requirement caught two fixtures fabricating the pre-M21 shape (`test-parallel-classify.R:9`, `test-parallel-interrupt.R:20`), which is the guard working rather than breakage. Mutation-verified per guard-doctrine: dropping `"grid"` from the required set left the classify file GREEN until a test pinned it per element, so the guard was written against the measured gap, not assumed.
- 2026-07-30: criteria audit ([O], fresh context) returned three defects, all fixed before the gate — AC6 named `valid_fold_result()`, which does not exist (the predicate is `is_fold_record()`, `R/parallel.R:389`); AC2's "ordering by `.config`" was impossible against a request frame that has no such column, and provably wrong besides, since `tune_grid()` renumbers `.config` into ascending parameter order; AC4's failure enumeration omitted the outer-fit path, where a zero-row record would have violated IP4 by reporting a fold that did evaluate a grid as having evaluated none. It also raised GP2 (moot — two oracle types already present) and IP2 fragility in the difference assertion, which became a gate question.
- 2026-07-30: plan gate chose reading back the candidates that scored over generating the grid ourselves, because reading back changes nothing about what runs while still closing the truncation gap; falsified by evidence that a user needs the candidates that were attempted but failed, which `.notes` records only as prose.
- 2026-07-30: plan gate chose a bare zero-row tibble for a fold that scored nothing over a typed one, because a fold that died before tuning returned has no result to read parameter names from and typing it would need machinery built solely to furnish an empty record; falsified by a downstream binding of `.grid` across folds that needs uniform columns.
- 2026-07-30: plan gate chose recording the cross-fold grid difference as an observation over asserting it, because it is a property of tune's expansion and IP2 declines to guarantee anything across tune versions; falsified by the difference proving load-bearing for a user-facing claim rather than only motivating the design.
- 2026-07-30: plan chose a per-fold list column over a single attribute, weighed autonomously, because folds are measured to disagree and an attribute would need an invented rule for that case while also surviving a row subset as the parent's record (M20's finding); falsified by evidence that folds cannot disagree.
- 2026-07-30: T5-T6 — failure-path and oracle tests. Two oracle types now cover the record: O3 re-runs `tune_grid()` by hand on each fold's inner resamples under its own `.tuning_seed`, O4 is the data-frame invariant. Truncation measured: `grid = 20L` on a four-predictor `num_comp` workflow records 4 candidates per fold against a `grid` attribute still reading 20. The cross-fold difference was measured on the shipped fixture rather than cited from the plan-gate probe on other data, and recorded in the oracle header unasserted per the plan gate — folds expanded 0.00059/0.24510/0.50336/0.74564/0.98373, 0.03347/0.25516/0.49639/0.75686/0.99656, and 0.00259/0.23142/0.48026/0.74269/0.99798.

## Decisions

## Review
