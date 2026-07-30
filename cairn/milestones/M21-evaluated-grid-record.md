# M21: A run says which candidates it actually searched, fold by fold

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4, GP1
- **Branch/PR:** `m21-evaluated-grid-record` / https://github.com/jmgirard/nestedtune/pull/22

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

- [x] AC1: `nested_tune_grid()` returns a `nested_results` carrying a `.grid`
      list column with one element per outer fold. For a fold whose inner tuning
      scored at least one candidate, the element is a tibble with one row per
      distinct candidate scored, one column per tuned parameter, plus tune's
      `.config` label.
- [x] AC2: with a data-frame `grid` whose candidates all score, each fold's
      `.grid` element holds exactly that frame's candidates — same row count,
      same values in every parameter column, compared after ordering both sides
      by the shared parameter columns. Not by `.config`: `tune_grid()` renumbers
      `.config` into ascending parameter order, so a request frame given in any
      other order fails a `.config`-ordered comparison on an identical set.
- [x] AC3: with an integer `grid`, a completed fold's `.grid` element equals the
      candidate set `tune::tune_grid()` scores when run by hand on that fold's
      inner resamples under that fold's `.tuning_seed` with the generator kind
      pinned — asserted for a workflow tuning a continuous parameter.
- [x] AC4: an integer `grid` larger than the reachable candidate count is
      recorded as what ran, not as what was asked: a request whose expansion
      truncates leaves `attr(x, "grid")` at the requested number while every
      completed fold's `.grid` element holds the smaller set that scored.
- [x] AC5: `.grid` records what that fold scored, on every failure path. A fold
      completing with one candidate that failed on all its inner resamples holds
      one row fewer than the requested frame, omitting exactly that candidate; a
      fold that failed at the **outer fit** holds the full set its inner tuning
      scored; a fold that scored nothing — every candidate failed, or no tuning
      result was reached — holds a zero-row tibble, never `NULL` and never a
      missing element.
- [x] AC6: `.grid` is one of the columns a `nested_results` is defined by —
      dropping it in a column subset sheds the `nested_results` class, exactly as
      dropping `.metrics` does.
- [x] AC7: a fold record arriving from a mirai worker with no grid element is
      classified as a failed fold rather than accepted as completed —
      `is_fold_record()` (`R/parallel.R:389`) requires it, verified by mutation:
      dropping it from the required set leaves the suite red. The serial path
      builds its own records and is not reached by this guard.
- [x] AC8: printing a result whose completed folds scored different candidate
      sets says so in one line; printing one where they agree does not. Both are
      snapshot-covered, and the method still never raises and never warns.
- [x] AC9: `@return` for `nested_tune_grid()` documents both records and how they
      differ — `attr(x, "grid")` is the request as given, `.grid` is what each
      fold scored, they diverge whenever a size was passed or a candidate failed,
      and a candidate that failed on every inner resample is absent from `.grid`.
- [x] AC10: `Rscript -e 'devtools::test()'` clean; `devtools::document()` no
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
- [x] T7: the print line for disagreeing candidate sets
      (`R/nested-results-print.R`), beside the existing selection-instability
      line; re-record affected snapshots.
- [x] T8: `@return` and the failure section in `R/nested-tune-grid.R`;
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

- 2026-07-30: T7-T8 — the disagreement print line, `@return`, the failure section, `print.nested_results()` docs, and the NEWS entry. The M20 NEWS bullet was left standing rather than corrected: its claim is about `attr(x, "grid")`, which is still not a record of what was evaluated, so M21 adds a record beside it rather than falsifying it. Comparison is by `identical()` on the sorted parameter columns, never on `.config` (positional) and never on formatted strings (a difference below print precision is still a difference); all three are asserted.
- 2026-07-30: the `BUDGETED_FILES` judgment logged at the implement gate was half wrong, and the guard caught it. No row was owed — nothing added a wait — but the ledger is anchored by `file:line`, so inserting a fixture line and a test above the existing rows made all 30 stale at once (+31 in `test-parallel-classify.R`, +1 in `test-parallel-interrupt.R`). Renumbered mechanically and re-verified. The coupling is deliberate (M16 built it so a copied bound cannot drift from its call site), but it means any insertion into a budgeted file above a wait call costs a renumbering pass.
- 2026-07-30: T8 — docs, NEWS, `document()` clean, `check()` clean (0 errors, 0 warnings, 0 notes; 3m48s). Two corrections on the way there. A defensive `tryCatch` around the derivation was added because both call sites sit outside every tryCatch in the file, and its first comment claimed `order()` on a list-valued parameter column as the reachable raise — measured false (it sorts and returns both candidates), so the comment now says no raising input is known and a test asserts the list-column case plus, via a mocked binding, that the wrapper is not decorative. And `check()` WARNed on a non-ASCII em dash in the cli string: comments tolerate one, a code string does not, so it is now `\u2014` and the snapshot is byte-identical.
- 2026-07-30: status review — all ten criteria have evidence, suite and check clean on the shipped tree.
- 2026-07-30: review — all ten criteria executed fresh and ticked against recorded evidence; AC6 and AC7 re-mutated at review (1 and 3 failures respectively, both restored). Consistency gate clean: `cairn_validate` exit 0, `pkgdown::check_pkgdown()` no problems, `document()` no diff, `check()` Status OK. Draft PR #22 opened; blame-history and prior-review lenses returned zero findings each.
- 2026-07-30: review returned the milestone to in-progress (return 1). AC8 fails as written: the diff-bug lens found, and I reproduced, that `print.nested_results()` RAISES on a `.grid` carrying a list-valued parameter column — `do.call(order, values)` in `candidate_key()` errors with "unimplemented type 'list' in 'orderVector1'", against the method's documented "never raises" contract. Correcting a work-log claim above: the T8 line says `order()` on a list column was measured not to raise. That measurement was invalid — `scored_candidates_impl()` orders `key[first]`, a character vector, never a parameter column, so the passing test exercised a different path. The shipped comment repeating the claim is false and goes with the fix. Also actioning finding 9 (82): the failure-section doc claims a fold whose inner tuning failed holds a zero-row table, but the inner-tuning guard wraps `select_best()` and `.get_tune_metric_names()` too, so a fold that tuned and then failed selection keeps what it scored.
- 2026-07-30: F1/F2/F9 fixed and AC8 re-verified; status back to review. `candidate_key()` now takes its row-order permutation from a rendered key instead of `order()` over the parameter columns, which is where the raise lived. Rendering decides ROW ORDER ONLY — the values compared are still the originals, so all three comparison properties re-measured green: order-insensitive TRUE, a 1e-12 difference FALSE, a different parameter FALSE. Regression test asserts `same_candidates()` on a list column, in both the agreeing and differing directions, and that row order still normalises away for one. Suite 254 tests / 0 failures; `check()` Status OK; `document()` idempotent.

## Decisions

## Review

**PR:** https://github.com/jmgirard/nestedtune/pull/22

### Acceptance criteria — fresh evidence

Every criterion executed by command on the branch at `504a0b0`, not recalled.
Named-test runs report pass counts; each test was located by name across the
whole suite rather than by file, so a renamed or deleted test reads as MISSING
rather than passing silently.

- AC1 — `test-nested-tune-grid-results.R` "each fold records the candidates its
  inner tuning actually scored", 15 assertions pass: `.grid` present, list type,
  one element per fold, each a data frame carrying the parameter column and
  `.config`.
- AC2 — same test, comparing each fold's element to the request frame by the
  shared parameter column (`sort(g$num_comp)` vs `sort(grid$num_comp)`), not by
  `.config`. 3 folds checked.
- AC3 — `test-nested-tune-grid-oracles.R` "an integer grid records the
  candidates that fold actually expanded", 4 assertions: for each of 3 folds,
  the record equals a by-hand `tune_grid()` on that fold's inner resamples under
  its own `.tuning_seed` with the kind pinned. Continuous-parameter workflow.
- AC4 — same file, "a grid size larger than the reachable candidates records
  what ran", 7 assertions: `attr(x, "grid")` is `20L` while every fold's record
  holds 4 candidates.
- AC5 — `test-nested-tune-grid-failures.R`, three tests, 16 assertions total:
  a candidate failing on every inner resample is absent (2 rows, not 3, and the
  request attribute unchanged); an outer-fit failure keeps all 3 scored
  candidates; a fold that scored nothing holds a 0-row data frame and no element
  is `NULL`.
- AC6 — "dropping any of the per-fold columns sheds the results class", 5
  assertions, including dropping `.grid` alone from an otherwise complete
  object. Mutation-verified: removing `".grid"` from `has_results_columns()`'s
  required set turns the file red (1 failure), restored.
- AC7 — `test-parallel-classify.R` "a fold record missing the
  evaluated-candidate set is not a fold record", 13 assertions, per element.
  Mutation-verified: dropping `"grid"` from `is_fold_record()`'s required set
  turns the file red (3 failures), restored. This mutation was run at
  implementation time too and was GREEN before the test existed, which is why
  the test asserts per element.
- AC8 — `test-nested-results-print.R` "folds that searched different candidate
  sets are said to have" (7 assertions: the line's text, its absence on an
  agreeing run, and `expect_no_error`/`expect_no_warning` on the new branch) and
  "the candidate-set comparison ignores order and tune's config labels" (3
  assertions: order-insensitivity, a 1e-12 difference still counting, a
  different parameter counting). Snapshot recorded in
  `_snaps/nested-results-print.md`.
- AC9 — `man/nested_tune_grid.Rd` carries all four claims, checked by pattern:
  "as it was given", the per-fold description, "diverge routinely", and the
  absence of a candidate that "failed on **every** inner resample".
- AC10 — `devtools::test()` clean across the suite; `devtools::document()`
  produces no diff (re-run at review, `git status` on `man/` and `NAMESPACE`
  empty); `devtools::check()` **Status: OK — 0 errors, 0 warnings, 0 notes**
  (3m48s).

### Consistency gate

- `cairn_validate` exit 0 — every check PASS. One advisory: `sizing (split
  tripwires)`, M21's 10 acceptance criteria against the ~7 tripwire. Weighed at
  the plan gate and again at implementation; not actioned, because two of the
  ten are the mandatory toolchain criterion and the documentation criterion, and
  the only separable piece (the print line) is one line of output plus
  snapshots — a task, not a milestone.
- `cairn_impact` skipped: `DESIGN.md` is not in the diff. The header's
  `Principles touched: IP4, GP1` records principles worked *under*, not changed.
- Toolchain slot: `document()` no diff; generated files not hand-edited (implied
  by the no-diff run); no `README.Rmd` in the repo, so the knit check no-ops;
  `pkgdown::check_pkgdown()` — "No problems found."; NEWS.md carries the entry
  and no user-facing file mentions a milestone number (checked by pattern);
  `NEWS.md` is modified rather than new, so no `.Rbuildignore` entry is owed;
  full `check()` clean as above.

### Independent review — three lenses

- **[S] blame-history:** zero findings. Traced every changed and deleted line to
  its introducing commit and cross-referenced M03, M04, M16 and M20. Verified
  independently that all 30 renumbered ledger rows point at the call each row
  describes, and that the fixture changes add coverage rather than weaken it.
- **[S] prior-review record:** zero findings. Read the archived `## Review`
  sections for M03, M04, M07, M09, M15, M16, M18, M19 and M20. The GitHub
  inline-comment probe returned empty, so that surface was correctly skipped.

### Independent review — findings and triage

Three lenses reported; every finding was scored 0–100 by a fresh Sonnet scorer
that generated none of them and held the diff and the milestone file.
**18 findings, 2 at or above the 80 threshold, plus one actioned below it.**

Actioned:

- **F1 (90) — `print.nested_results()` raises on a `.grid` with a list-valued
  parameter column.** `do.call(order, values)` in `candidate_key()` errors with
  "unimplemented type 'list' in 'orderVector1'", against the method's documented
  "never raises" contract and AC8. Reproduced independently before acting.
  **Fixed**: the permutation now comes from a rendered row key; values compared
  are still the originals. Regression-tested.
- **F9 (82) — the failure-section doc is wrong for a fold that scored and then
  failed selection.** The inner-tuning guard wraps `select_best()` and
  `.get_tune_metric_names()` too, so such a fold keeps its scored candidates
  rather than holding a zero-row table as documented. **Fixed** in the roxygen.
- **F2 (78, actioned below threshold) — the defensive wrapper's comment cited a
  measurement that does not support it.** `scored_candidates_impl()` orders
  `key[first]` (character), never a parameter column, so the test cited as
  proof exercised a different path. Actioned because it is a false statement in
  shipped code, independently verified, and F1's fix lands in the same place.
  **Fixed**; the work log carries a correction rather than an edit.

Logged, below threshold, not actioned (16):
F6 (72) `is_fold_record()` accepts an explicit `grid = NULL`, since it tests
name membership — unreachable from this package's own paths, which always build
a table · F8 (68) NEWS and `@return` state tune's expansion behaviour more
firmly than the plan gate agreed to assert · F14 (65) the new print fixture is
built un-memoised where siblings are memoised · F3 (55) the line says "searched"
of a scored-only record · F5 (52) the empty record is zero-column, not just
zero-row, and no doc says so · F4 (50) `.eval_time` would be kept as if a
parameter for survival metrics — no survival support exists · F17 (45) the
counts read oddly in the same-size case · F10 (42) the derivation degrades
silently with no note · F13 (42) the `.config`-absent fallback orders lexically
and is untested · F12 (35) the line is unreachable when no fold has selected
parameters · F16 (30) daemon/driver version skew reports opaquely · F18 (25)
`failed_fold(..., tuned = tuned)` reads as duplication · F7 (20) and F15 (20)
and F11 (12) judged inaccurate or out of scope on inspection.

Codecov reports 93.75% of the diff hit against a 98.44% target (project 98.18%,
−0.27%). Not a required check — `main` is unprotected — and the uncovered lines
are the defensive branches F10 and F13 name.
