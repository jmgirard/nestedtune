# M03: Fold failures are recorded, never fatal

- **Status:** review
- **Priority:** high
- **Depends on:** M02
- **Driving RR:** —
- **Principles touched:** IP4, IP2, GP1
- **Branch/PR:** `m03-failed-fold-recording` / https://github.com/jmgirard/nestedtune/pull/3

## Goal

A fold that fails is recorded and the run continues, so the results object says what
actually ran and no summary presents a partial design as the one that was requested.

## Scope

**In:** Per-fold failure capture in `nested_tune_grid()`'s loop, covering both a thrown
error and the quieter path where `tune::tune_grid()` swallows the error itself and
returns no usable candidates for `select_best()`. A per-fold outcome record on
`nested_results` naming the failing stage and its condition message, plus the
attempted/completed counts that make a partial run identifiable without inspecting
every row. `collect_metrics()` averaging over the folds that completed, warning and
naming the ones that did not, and aborting when none did. Plus a pre-flight
check of a data-frame `grid` against the workflow's tunable parameters, added
by amendment (see Work log): recording fold failures instead of raising them
would otherwise turn a malformed grid — wrong for every fold — into a whole
design failing rather than the call error it is.

**Out:**
- Displaying any of this when the object prints → M04.
- Parallel execution over outer folds → ROADMAP candidate (needs its own dependency gate).
- The missing caveat on `collect_metrics()`'s `std_err` → the variance-estimation candidate owns it.
- Changing how a fold that *scores* `NA` is handled (`R/nested-results.R:94`) — that path already matches tune and stays as it is.

## Acceptance criteria

- [x] AC1: A workflow that errors on one outer fold returns a `nested_results` with a
      row for every fold; the call does not abort and later folds still run.
- [x] AC2: The object records, per fold, whether it completed and — when it did not —
      the failing stage (inner tuning or outer fit) and the condition message. Both a
      thrown error and a tuning run that yields no usable candidate are recorded this way.
- [x] AC3: The object records folds attempted and folds completed, so a partial run is
      distinguishable from a complete one without reading per-fold contents.
- [x] AC4: `collect_metrics()` reports only what ran — on a partially failed run it
      means over the completed folds with `n` equal to that count and warns naming the
      failed ids; on a run where none completed it aborts rather than returning `NA`.
- [x] AC5: Failure capture disturbs nothing M02 established: a fully successful run's
      `collect_metrics()` output is unchanged — same columns, same values, no warning —
      and a fold's two seeds are identical whether or not an earlier fold failed (IP2).
- [x] AC6: A data-frame `grid` is refused before any fitting when a column is not marked
      for tuning, or when a tuned parameter has no column; both name the offender, and
      neither draws from the RNG. A `grid` given as a size is exempt.
- [x] AC7: `devtools::test()` and `devtools::check()` clean (0 errors, 0 warnings).

## Coverage

- AC1 → T2, T3
- AC2 → T1, T2, T3, T4
- AC3 → T5
- AC4 → T6
- AC5 → T7
- AC6 → T9
- AC7 → T8, T9

## Tasks

- [x] T1: Fixtures in `tests/testthat/helper-orchestration.R`: a workflow that errors
      deterministically on a chosen outer fold, and one whose inner tuning leaves
      `select_best()` with no candidate.
- [x] T2: Failing tests for the non-aborting loop and the per-fold outcome record.
- [x] T3: `nested_fold_fit()` (`R/nested-tune-grid.R:144`) returns an outcome record
      rather than throwing — each stage wrapped, stage and condition captured.
- [x] T4: Guard the no-usable-candidate path ahead of `select_best()`
      (`R/nested-tune-grid.R:156`) so it lands in the same record.
- [x] T5: `new_nested_results()` (`R/nested-results.R:8`) carries the outcome column and
      the attempted/completed counts.
- [x] T6: `collect_metrics()` (`R/nested-results.R:79`) warns and counts on a partial
      run; aborts on an all-failed one. Message quantities take `{cli::qty()}`.
- [x] T7: Regression tests — untouched happy path, and fold seeds stable across a
      failure.
- [x] T8: Roxygen for the failure record on `nested_tune_grid()`'s `@return` and on
      `collect_metrics()`; NEWS entry; `devtools::document()`; verify + `devtools::check()`.
- [x] T9: `check_grid_params()` in `R/checks.R` comparing a data-frame `grid`'s columns
      against `tune::extract_parameter_set_dials()`, called from `nested_tune_grid()`
      before the seeds are drawn; tests in `test-nested-tune-grid-checks.R`; roxygen,
      NEWS, and re-run verify + `devtools::check()`. Added by amendment.

## Work log

- 2026-07-26: created by /milestone-plan; absorbs the failed-fold half of the M02 split candidate row.
- 2026-07-26: branch `m03-failed-fold-recording` cut; gate settled the record shape (tune-shaped `.notes` plus a `.completed` flag), a run-end warning mirroring tune, and carrying tune's own notes verbatim.
- 2026-07-26: probes pinned both failure surfaces — inner tuning raises only at `select_best()`/`collect_metrics()` after `tune_grid()` returns with a warning, and `last_fit()` never raises at all, returning `NULL` metrics.
- 2026-07-26: T1–T2 fixtures inject the failure into the design (a fold's inner rset or outer split rebuilt on a foreign frame), so exactly one fold fails at one stage, keyed to position rather than execution order.
- 2026-07-26: T3–T6 implemented; both stages wrapped, notes carried through, `.notes`/`.completed` columns and `folds_attempted`/`folds_completed` attributes added.
- 2026-07-26: T7 updated two M02 tests to the new contract — the leakage stub gained the worker's new fields, and the RNG error-path test split in two (see Decisions).
- 2026-07-26: T8 roxygen, NEWS, `devtools::document()`; `devtools::test()` 748 pass / 0 warn; `R CMD check` 0 errors, 0 warnings, 0 notes.
- 2026-07-26: tasks were completed in one working pass rather than per-task checkpoint commits; a single implementation commit lands them together.
- 2026-07-26: substantive amendment at the user's direction at the completion chip — pre-flight grid validation added to Scope as AC6/T9, restoring the immediate abort the Decisions entry had left to a candidate row; that candidate row is dropped as superseded. AC4 and AC5 merged into one criterion (both are `collect_metrics()` under failure, both mapped to T6) so the criterion count stays under the split tripwire.
- 2026-07-26: probes confirmed tune already raises for both grid directions and that `tune::extract_parameter_set_dials()` is exported, so the check needed no new dependency. The rewritten RNG test lost its vehicle to the new check and now fails both folds via `break_fold()` instead.
- 2026-07-26: review fan-out actioned F1 (96, stale-attribute disagreement in `collect_metrics()`) and F2 (82, a partly-failed fold recorded as clean with its notes discarded); F3 (42) logged as a candidate row. Four regression tests added; suite 766 pass, check 0/0/0.

## Decisions

### 2026-07-26: An all-fold failure is recorded, not raised — including when the cause is a malformed call

M02 aborted as soon as a fold errored, so `nested_tune_grid(wf, folds, grid =
data.frame(not_a_param = 1:2))` — a grid naming a parameter the workflow does not
tune — failed immediately. M03 catches fold errors by design, so that same call
now completes, warns that every fold failed, and carries tune's explanation in
`.notes`; `collect_metrics()` then refuses to summarize it. The change is
entailed by the milestone's goal rather than chosen alongside it: once an error
is caught inside the loop, nothing distinguishes "this fold could not fit" from
"this call was malformed".

An existing RNG test asserted the old abort as its vehicle for checking that the
caller's RNG state survives an error exit. It was split in two — the state is now
checked both when failures are recorded and the run completes, and when the call
genuinely errors (worker stubbed to throw), which is the only remaining exit
after the seeds are drawn.

Not adopted here: a pre-flight check comparing the grid's columns against the
workflow's tunable parameters, which would restore an immediate abort under GP3.
Nothing in this milestone's Scope or criteria covers argument validation, so it
is recorded as a ROADMAP candidate beside the two existing validation-hardening
rows instead. Pre-1.0 the behavior change needs no deprecation cycle (D-003).

### 2026-07-26: The pre-flight grid check is adopted after all — supersedes the paragraph above

At the completion chip the maintainer directed that the check be added to this
milestone rather than deferred. `check_grid_params()` compares a data-frame
`grid`'s columns against `tune::extract_parameter_set_dials(object)$id` in both
directions and aborts before any seed is drawn, so a malformed grid is again
refused as the call error it is. No new dependency: tune already exports the
extractor, and tune's own per-fold errors confirmed both directions are
provable up front.

What stands from the entry above: an all-fold failure arising from a genuine
per-fold cause is still recorded rather than raised, and the RNG test split
stands. What no longer holds: the deferral to a candidate row — that row is
removed from the ROADMAP as superseded by this work, not left to imply the
check is still outstanding. Scope, AC6 and T9 were amended in by the same
direction (see Work log).

## Review

Verified 2026-07-26 against `m03-failed-fold-recording` @ 2926e12, PR #3. Suite run
fresh: 755 passed, 0 failed, 0 warnings, **0 skipped** — the engine-dependent tests
executed rather than skipping, so the RNG and oracle coverage is real, not vacuous.

**Evidence per criterion**

- AC1 — `tune-grid-failures`: "a fold that fails at inner tuning does not abort the
  run" (3 pass) and "a fold that fails at the outer fit does not abort the run"
  (2 pass). Both assert `nrow(res) == 3L` and the exact `.completed` vector, so a
  run that dropped the failed row would fail them.
- AC2 — `tune-grid-failures`: "the failing stage and its cause are recorded, tune's
  own notes included" (7 pass) covers both stages and asserts the note table's
  column names, the stage in `location[[1]]`, and that tune's underlying cause
  ("Not all variables in the recipe") survives; "a completed fold carries an empty
  note table" (2 pass) pins the clean case.
- AC3 — `tune-grid-failures`: "the object records folds attempted and completed"
  (2 pass), asserting `folds_attempted == 3L` and `folds_completed == 2L` by
  `expect_identical()`, so the counts are exact and integer-typed.
- AC4 — `tune-grid-failures`: "collect_metrics() averages the completed folds and
  warns about the rest" (4 pass) checks `n == 2L`, the warning class
  `nestedtune_partial_summary`, the named fold, and that the mean equals the mean of
  the two surviving folds computed independently; "collect_metrics() aborts when no
  fold completed" (3 pass) covers both `summarize` values.
- AC5 — `tune-grid-failures`: "failure capture leaves a clean run exactly as M02
  left it" (5 pass, incl. `expect_no_warning()` and the M02 column set) and "a
  fold's seeds do not move when an earlier fold fails (IP2)" (4 pass), which
  compares a clean run against a broken one by `expect_identical()` on both seed
  vectors and on a surviving fold's metrics and selection.
- AC6 — `tune-grid-checks`: "a grid column not marked for tuning is refused"
  (2 pass), "a tuned parameter with no grid column is refused" (2 pass), "a grid
  given as a size is not held to the column check" (1 pass), "the grid check fires
  before any fitting happens" (2 pass, asserting `.Random.seed` is untouched).
- AC7 — `devtools::test()` 755 pass / 0 fail; `devtools::check()` 0 errors,
  0 warnings, 0 notes.

**Independent checks beyond the criteria.** Two edge cases the suite does not cover
were run by hand at review. A repeated outer design (`id` + `id2`) labels a failed
fold by its composite id — the warning named `"Repeat1, Fold2"` and the summary
reported `n = 3` of 4 — so `fold_ids()` still composes correctly with the new
columns. And an interrupt condition does not inherit `"error"`, verified by
execution, so the per-stage `tryCatch(error = )` propagates a user interrupt rather
than recording it as a fold failure — the failure mode a too-broad catch would have
introduced on exactly the long runs this feature exists for.

**Independent review fan-out.** Three fresh-context lenses. Blame-history: clean —
the two modified M02 tests kept the properties they guarded, and the malformed-grid
guarantee was restored earlier than before rather than lost. Prior-PR-comments:
clean — RR01's binding RNG criteria still hold, M02's below-threshold F5/F6 are
neither worsened nor silently resolved, and the inline-comment probe returned empty
so the thread walk was correctly skipped. Diff-bug: three findings, scored by a
fourth agent that did not generate them.

- **F1 (96) — actioned, fixed.** `collect_metrics()` read two disagreeing sources
  for "did the design run?": `check_any_completed()` took the stamped
  `folds_completed` attribute, `warn_partial_summary()` took the `.completed`
  column. Subsetting preserves class and attributes, so a subset answered from its
  parent's counts — `collect_metrics(res[1, ])` on a failed fold passed the guard
  on a stale 2, warned "covers 2 of 3", and returned a 0-row tibble where AC4
  requires an abort. Fixed by deriving both from `.completed`, plus a
  `[.nested_results` method recomputing the counts for the rows kept and shedding
  the class when `.completed` is dropped. Verified: that call now aborts.
- **F2 (82) — actioned, fixed.** The success path hardcoded `empty_notes()`, so a
  fold whose inner tuning *partly* failed was recorded as a clean completion and
  tune's notes were discarded — contradicting this milestone's own roxygen
  ("anything that went wrong") and GP1. Fixed by carrying both stages' notes on
  the success path. Verified: a fold with one broken inner split completes with
  3 notes; a clean fold still carries 0.
- **F3 (42) — below threshold, logged not actioned.** Two untested error branches
  (nothing makes `last_fit()` or `tune_grid()` itself raise) plus `finalize_workflow()`
  sitting outside both guarded regions. The scorer judged it a missing-test issue
  rather than a demonstrated defect, and its second half had no constructible
  trigger. Recorded as a candidate row.

F1's second scenario resolved differently from how it was reported: after the fix
`collect_metrics(res[res$.completed, ])` still does not warn, because the subset is
now a self-consistent 2-of-2 object. The counts no longer lie; what the package
will not do is remember a design the caller deliberately discarded.

**Post-fix re-verification.** `devtools::test()` 766 passed / 0 failed / 0 skipped
(up 11 — four new regression tests). `devtools::check()` 0 errors, 0 warnings,
0 notes. `devtools::document()` clean; the new `[` method registers as
`S3method("[", nested_results)`.

**Consistency gate.** `cairn_validate` exit 0, every check PASS, no advisories.
`cairn_impact` skipped: `DESIGN.md` is not in the diff, so no principle changed.
Toolchain slot: `devtools::document()` leaves `man/` and `NAMESPACE` clean;
`pkgdown::check_pkgdown()` "No problems found"; `NEWS.md` carries entries for both
user-visible changes; no new top-level files, so no `.Rbuildignore` additions owed.
