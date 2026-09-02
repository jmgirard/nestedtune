# M49: Each outer fold keeps its inner search's metrics in place of `.grid`

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4, GP4
- **Resolves:** #57 closes
- **Branch/PR:** m049-inner-metrics-column · https://github.com/tidymodels/nestedtune/pull/59

## Goal

A `nested_results` carries, per outer fold, the inner tuning run's `collect_metrics()` table in a `.inner_metrics` column
in place of `.grid`, so a user can compute the best candidate or plot a Bayesian search's trajectory from the object.

## Scope

**In:** user-facing tier — the exported results class changes columns. The fold worker records
`tune::collect_metrics(tuned)` as `.inner_metrics` (the Bayesian table carrying `.iter`); a fold that tuned and then
failed its outer fit keeps its table; a fold that scored nothing carries a zero-row table with a completed fold's columns,
built without calling `collect_metrics()` on it (it raises when every candidate fails — the M03 lesson). `.grid` is
removed from the constructor, the invariant set, `has_results_columns()`, the readers, the docs and the vignette; the
print and summary candidate-set comparison derives each fold's candidate set from the distinct parameter rows of
`.inner_metrics` (metric columns, `.config` and `.iter` dropped), keeping `candidate_key()`'s value comparison, which is
what tells apart per-fold random grids that share `.config` labels. `.selected` is unchanged. D-043 supersedes D-031's
column list and D-023's `.grid` clause and records that `extract_scored_candidates()` keeps its candidate shape. Size:
measured 2026-09-02 on a 5-fold `mtcars` ranger grid of 10 candidates and 2 metrics, the summarized table is 3,872 B
against 3,368 B for `.grid` and `.selected` together (GP4); the M23 payload tests measure outbound dispatch only.

**Out:** dropping `.selected` (gate: kept — it records what the fold's outer fit used under `select_best()`'s tie rules,
and DESIGN.md calls retained selections first-class); an `autoplot()` view of the inner trajectory → candidate row;
reshaping `extract_scored_candidates()` to the metrics table → recorded in D-043, not done; a `nested_results` method
for that generic → not planned; a user control on the inner run → M48.

## Acceptance criteria

- [x] AC1: Each completed fold's `.inner_metrics` is identical to `tune::collect_metrics()` of the inner tuning run re-run
      by hand under the fold's tuning seed, for both tuners, the Bayesian table carrying `.iter`; a fold that tuned and
      then failed its outer fit keeps its table; a fold that scored nothing carries a zero-row table with the columns of
      a completed fold's; a candidate that scored on some inner resamples and failed on others appears with `n` below
      the inner resample count; each asserted by a test — one fixture per tuner, the failure shapes on the existing
      `break_*` fixtures. (RB tripwire: ip-touching)
- [x] AC2: `.grid` is gone from the constructor, the invariant column set, `has_results_columns()`, the print and summary
      candidate-set comparison, the vignette, README and every help page:
      `grep -rnE '(^|[^A-Za-z])\.grid' R/ tests/ vignettes/ man/ README.Rmd` matches nothing, and NEWS is the only
      remaining mention. (RB tripwire: ip-touching)
- [x] AC3: `.selected` is built as before and its readers are untouched: `git diff <base>..HEAD --
      R/nested-results-agreement.R R/nested-results-plot.R` is empty, the vignette's selection section is unchanged,
      and the snapshot files for print, summary, agreement and plot carry no edit.
- [x] AC4: The print and summary candidate-set comparison renders as before on the existing snapshots — equal sets,
      differing sets (the per-fold random grid whose folds share `.config` labels), a partial run, and the Bayesian
      rendering — with no snapshot edit, each fold's candidate set derived from the distinct parameter rows of
      `.inner_metrics`.
- [x] AC5: `.inner_metrics` is in the dplyr/vctrs invariant set and in `has_results_columns()`: called directly with
      the original as template, `dplyr_reconstruct()` and `vec_restore()` return a bare tibble for a frame lacking the
      column, and for one whose table on a completed fold other than the first is replaced by a zero-row table or by
      the same table with one row dropped; `[` returns a bare tibble for the column subset
      `setdiff(names(x), ".inner_metrics")`, and a single-argument `rbind()` for a still-classed object from which the
      column was removed beforehand; and a frame lacking the column fails `has_results_columns()`; asserted by tests.
- [ ] AC6: `extract_scored_candidates()` on a `nested_final_fit` returns what it returns at the base commit (its existing
      tests unchanged), and its help page describes its shape without reference to `.grid`.
- [x] AC7: The profile's verify slot is clean; NEWS carries the breaking-change entry; DESIGN.md's results-object
      description names `.inner_metrics`; D-043 is appended.

## Coverage

- AC1 → T1, T2
- AC2 → T3, T4
- AC3 → T4
- AC4 → T3
- AC5 → T5
- AC6 → T4
- AC7 → T6

## Tasks

- [x] T1: Tests first: extend the hand-run oracles (`test-nested-tune-grid-oracles.R` O3, `test-nested-tune-bayes-oracles.R`)
      to `.inner_metrics`; the tuned-then-failed, nothing-scored and partial-inner-split shapes in
      `test-nested-tune-grid-failures.R`; the zero-row prototype.
- [x] T2: Fold worker: `nested_fold_fit()` (`R/nested-tune-grid.R:643-652`) and `failed_fold()` (`:802-820`) record the
      table; `new_nested_results()` (`R/nested-results.R:26-31`) writes `.inner_metrics`; `scored_candidates()`
      (`R/nested-tune-grid.R:669-736`) becomes the derivation of a candidate set from the table, `join_iteration()`
      retired where `collect_metrics()` already carries `.iter`.
- [x] T3: Readers: `print_candidate_sets()` and `candidate_key()` (`R/nested-results-print.R:329-393`) and summary's
      candidate counts (`:230`) read the derived sets; the snapshot files stay byte-identical.
- [x] T4: The `.grid` sweep: roxygen on both orchestrators and the extract accessor page, the vignette
      (`vignettes/nested-cv.Rmd:232-247` reads `.selected` only), the fold stand-ins in the payload and classify tests,
      the 21 test files the sweep listed; run the AC2 grep.
- [x] T5: Invariants: `record_columns()` (`R/nested-results.R:121-134`) and `has_results_columns()` (`:608-613`); the
      removal and mutation probes in `test-dplyr-compat.R` and `test-vctrs-compat.R` across the four doors.
- [x] T6: NEWS, DESIGN.md, D-043 (drafted at plan), verify slot.

## Work log

- 2026-09-02: created by /milestone-plan from issue #57 (topepo, 2026-09-02).
- 2026-09-02: criteria audit ran in full mode by a fresh [O] reader; for M49 it returned: the column was never named (now `.inner_metrics`, gate); AC2's grep matched `expand.grid` in the vignette and README (pattern fixed); deriving candidate sets from distinct `.config` rows would collapse the differing-grid snapshot whose folds share labels (derived from parameter rows instead); AC3 rested on green tests rather than unchanged output (now an empty diff and unchanged snapshots); `has_results_columns()` omitted from AC5 (added); the partial-inner-split case unprobed (added to AC1); the final-fit accessor's shape left implicit (settled: kept, recorded in D-043).
- 2026-09-02: plan gate chose keeping `.selected` over dropping it for an on-the-fly `slice_min()` because it records what the outer fit used under `select_best()`'s tie rules and DESIGN.md's selection-stability stance names it; falsified by evidence that recomputing from `.inner_metrics` always reproduces it.
- 2026-09-02: plan chose leaving `extract_scored_candidates()` unchanged over reshaping it to the metrics table because nothing on the final fit is broken and the divergence is one sentence in D-043; falsified by a user comparing the two surfaces row for row.
- 2026-09-02: gate: proceed without escalation on the ip-touching criteria (the hand-run `collect_metrics()` oracle is available); one candidate derivation over the metrics table, the final fit applying it to `collect_metrics()` of its tuning run. T1: `.inner_metrics` oracles on both hand-run loops, the outer-fit-failed, nothing-scored (both branches), partial-inner-split and Bayesian nothing-scored shapes; red on the missing column until T2.
- 2026-09-02: T2–T5 code landed together (a fold worker writing `.inner_metrics` leaves the readers and invariants red until they read it): `inner_metrics()` records `collect_metrics()` or a workflow-built zero-row prototype, `candidate_set()` derives the candidate set from a table and serves the final fit through `scored_candidates()`, `join_iteration()` and the per-resample pooling retired; readers and invariants swapped; the `.grid` sweep ran and the AC2 grep is empty; T5 probes written; T6 NEWS and DESIGN drafted. Checkpoint while the full suite runs; checkboxes wait on the verify slot. AC5's change-through-`[`-and-`rbind()` clause found unconstructible (those doors self-template); amended wording out to a fresh [O] reader before the mini gate.
- 2026-09-02: amendment (substantive, narrowing) — AC5 rewritten at a mini gate: the change-through-`[`-and-`rbind()` clause was unconstructible, those doors taking the object they act on as their own template. Two fresh [O] readings in full mode: the first returned four findings (probe forms and fold location, `vec_restore()` call form, the two doors' constructions split, a home for the self-template gap), the second two findings and an ambiguity (exact `[` subset, single-argument `rbind()`, a completed fold); all applied, the final text user-approved. Two hand-built-run tests (final-fit print counts, the bookkeeping wrapper) rewritten over a `fake_tuning()` stand-in whose `collect_metrics()` is a table given by hand.
- 2026-09-02: T2–T6 checked off on the verify slot: `devtools::document()` no diff, `air format .` no diff, `devtools::test()` clean in full (an earlier full run failed the three daemon files whose hand-built fold records still carried `grid`, and `test-suite-hygiene.R` on the time-budget ledger's `test-parallel-classify.R` line numbers, which `fake_fold_record()`'s eight new lines had shifted — both fixed). AC2 grep matches nothing; the AC3 diff and snapshot diff are empty. Status → review.
- 2026-09-02: review opened: PR #59 drafted; AC evidence gathering in progress (suite, check and three reviewers running).

## Decisions

- 2026-09-02: a record column altered under the class — `x$.inner_metrics[[1]] <- ...`, which tibble's `$<-` reattaches the class after without consulting the reconstruct rule — passes `[` and `rbind()`, which compare the object against itself; the template-taking doors refuse it. Pre-existing for every record column, recorded at the rule (`R/nested-results.R`) rather than fixed: intercepting `$<-` and `[[<-` is a fifth and sixth door the invariants D-031 fixed do not name, a candidate for a later milestone if a user meets it.

## Review

_Evidence gathered 2026-09-02 on branch `m049-inner-metrics-column` at 8df4c7e (origin/main unmoved since the cut; PR #59 draft). Full `devtools::test()`: 3,621 pass, 0 fail, 0 warn, 0 skip, 381 s._

- AC1 — verified. Grid: `test-nested-tune-grid-oracles.R` "an integer grid records the candidates that fold actually expanded" asserts each fold's `.inner_metrics` identical to `tune::collect_metrics()` of a hand re-run under the fold's seed. Bayesian: `test-nested-tune-bayes-oracles.R` "per-fold metrics and selections match a hand-rolled Bayesian reference loop" asserts the same and `.iter` present. Failure shapes in `test-nested-tune-grid-failures.R`: "a fold that failed at the outer fit keeps the grid its tuning scored" (table kept), "a fold that scored nothing records an empty table, never NULL" (zero-row, a completed fold's columns), "a fold that completed on a truncated inner design keeps tune's notes" (partial inner split: every `n` below 3); Bayesian zero-row with `.iter` in `test-nested-tune-bayes-results.R`. All green in the run above.
- AC2 — verified. `grep -rnE '(^|[^A-Za-z])\.grid' R/ tests/ vignettes/ man/ README.Rmd` exits 1 with no match; a repo-wide sweep outside `cairn/` finds `.grid` only in NEWS.md. `R/nested-results.R` and `has_results_columns()` name `.inner_metrics`; the print and summary comparison reads `candidate_sets()` over `.inner_metrics`.
- AC3 — verified. `git diff origin/main..HEAD -- R/nested-results-agreement.R R/nested-results-plot.R` is 0 bytes; `git diff origin/main..HEAD -- vignettes/ tests/testthat/_snaps/` is empty, so the selection section and the print, summary, agreement and plot snapshots carry no edit.
- AC4 — verified. No `_snaps/` edit (AC3's diff) and `test-nested-results-print.R` (157 tests) plus `test-nested-tune-bayes-results.R` green, covering equal sets, the differing per-fold random grid sharing `.config` labels, a partial run and the Bayesian rendering; `candidate_sets()` derives each completed fold's set from `candidate_set(.inner_metrics)` and `candidate_key()` drops `.config` and `.iter` before comparing parameter values.
- AC5 — verified. `record_columns()` and `has_results_columns()` list `.inner_metrics`; `test-dplyr-compat.R` ".inner_metrics is in the record dplyr_reconstruct() checks" and "has_results_columns() requires .inner_metrics", `test-vctrs-compat.R` ".inner_metrics is in the record vec_restore() and rbind() check" probe the missing column, the zero-row and one-row-dropped replacement on a non-first completed fold, the `[` column subset and the single-argument `rbind()`; all green.
- AC6 — evidence recorded, tick pending the gate. `R/nested-final-fit-extract.R` changes comments only; the function body is untouched and still returns `scored_candidates(x$tuning)`. Every `expect_*` line in `test-nested-final-fit-extract.R` is unchanged and green; the file's diff is three comment rewordings plus one comparand, `res$.grid[[1L]]` → `candidate_set(res$.inner_metrics[[1L]])`, which AC2's grep over `tests/` forces. The help page describes the shape as a `collect_metrics()` table reduced to its parameter columns and `.config`, without `.grid`. Read strictly, "its existing tests unchanged" and AC2 cannot both hold on this file; the disposition is the maintainer's at the gate.
- AC7 — verified. Verify slot: `devtools::document()` produces no diff, `air format .` no diff, `devtools::test()` clean (above). NEWS.md carries the breaking-change entry as its first bullet. DESIGN.md's `new_nested_results()` paragraph names `.inner_metrics`. D-043 is appended to DECISIONS.md.
- Driving RR: none, so no projection-vs-outcome pairs.

### Consistency gate

- `cairn_validate.py`: all checks passed, 18 references-staleness advisories only (the standing set). No IP/GP text changed in DESIGN.md, so `cairn_impact.py --changed` is skipped.
- `devtools::document()`: no diff. `air format .`: no diff. README.Rmd and README.md untouched on the branch. `pkgdown::check_pkgdown()`: no problems found. NEWS has the entry, with no milestone number in user-facing text. No new top-level files. `devtools::check()`: pending.

### Independent review

- [S] blame-history: no findings; checked the M03 collect_metrics guard, M21's per-fold record, M45's `join_iteration()` retirement (tune 2.1.0's `collect_metrics()` carries `.iter` natively), M21 review F1/F2 ordering, M37 probes, D-031/D-036 invariant set, D-043 scope, all respected.
- [S] prior-review record: no findings; archives M21, M36–M39, M45, LESSONS.md and D-023/031/032/036/043 read; the GitHub probe found one real inline comment (PR #30, a workflow file), the walk of PRs #22, #45–#47, #51, #54, #58 returned none.
- [O] diff-bug: pending.
