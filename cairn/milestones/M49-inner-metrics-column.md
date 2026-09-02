# M49: Each outer fold keeps its inner search's metrics in place of `.grid`

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP4, GP4
- **Resolves:** #57 closes
- **Branch/PR:** m049-inner-metrics-column

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

- [ ] AC1: Each completed fold's `.inner_metrics` is identical to `tune::collect_metrics()` of the inner tuning run re-run
      by hand under the fold's tuning seed, for both tuners, the Bayesian table carrying `.iter`; a fold that tuned and
      then failed its outer fit keeps its table; a fold that scored nothing carries a zero-row table with the columns of
      a completed fold's; a candidate that scored on some inner resamples and failed on others appears with `n` below
      the inner resample count; each asserted by a test — one fixture per tuner, the failure shapes on the existing
      `break_*` fixtures. (RB tripwire: ip-touching)
- [ ] AC2: `.grid` is gone from the constructor, the invariant column set, `has_results_columns()`, the print and summary
      candidate-set comparison, the vignette, README and every help page:
      `grep -rnE '(^|[^A-Za-z])\.grid' R/ tests/ vignettes/ man/ README.Rmd` matches nothing, and NEWS is the only
      remaining mention. (RB tripwire: ip-touching)
- [ ] AC3: `.selected` is built as before and its readers are untouched: `git diff <base>..HEAD --
      R/nested-results-agreement.R R/nested-results-plot.R` is empty, the vignette's selection section is unchanged,
      and the snapshot files for print, summary, agreement and plot carry no edit.
- [ ] AC4: The print and summary candidate-set comparison renders as before on the existing snapshots — equal sets,
      differing sets (the per-fold random grid whose folds share `.config` labels), a partial run, and the Bayesian
      rendering — with no snapshot edit, each fold's candidate set derived from the distinct parameter rows of
      `.inner_metrics`.
- [ ] AC5: `.inner_metrics` is in the dplyr/vctrs invariant set and in `has_results_columns()`: removing it, or changing
      one fold's table, drops the class through `dplyr_reconstruct()`, `[`, `rbind()` and `vec_restore()`, and an object
      lacking the column fails `has_results_columns()`; asserted by tests.
- [ ] AC6: `extract_scored_candidates()` on a `nested_final_fit` returns what it returns at the base commit (its existing
      tests unchanged), and its help page describes its shape without reference to `.grid`.
- [ ] AC7: The profile's verify slot is clean; NEWS carries the breaking-change entry; DESIGN.md's results-object
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

- [ ] T1: Tests first: extend the hand-run oracles (`test-nested-tune-grid-oracles.R` O3, `test-nested-tune-bayes-oracles.R`)
      to `.inner_metrics`; the tuned-then-failed, nothing-scored and partial-inner-split shapes in
      `test-nested-tune-grid-failures.R`; the zero-row prototype.
- [ ] T2: Fold worker: `nested_fold_fit()` (`R/nested-tune-grid.R:643-652`) and `failed_fold()` (`:802-820`) record the
      table; `new_nested_results()` (`R/nested-results.R:26-31`) writes `.inner_metrics`; `scored_candidates()`
      (`R/nested-tune-grid.R:669-736`) becomes the derivation of a candidate set from the table, `join_iteration()`
      retired where `collect_metrics()` already carries `.iter`.
- [ ] T3: Readers: `print_candidate_sets()` and `candidate_key()` (`R/nested-results-print.R:329-393`) and summary's
      candidate counts (`:230`) read the derived sets; the snapshot files stay byte-identical.
- [ ] T4: The `.grid` sweep: roxygen on both orchestrators and the extract accessor page, the vignette
      (`vignettes/nested-cv.Rmd:232-247` reads `.selected` only), the fold stand-ins in the payload and classify tests,
      the 21 test files the sweep listed; run the AC2 grep.
- [ ] T5: Invariants: `record_columns()` (`R/nested-results.R:121-134`) and `has_results_columns()` (`:608-613`); the
      removal and mutation probes in `test-dplyr-compat.R` and `test-vctrs-compat.R` across the four doors.
- [ ] T6: NEWS, DESIGN.md, D-043 (drafted at plan), verify slot.

## Work log

- 2026-09-02: created by /milestone-plan from issue #57 (topepo, 2026-09-02).
- 2026-09-02: criteria audit ran in full mode by a fresh [O] reader; for M49 it returned: the column was never named (now `.inner_metrics`, gate); AC2's grep matched `expand.grid` in the vignette and README (pattern fixed); deriving candidate sets from distinct `.config` rows would collapse the differing-grid snapshot whose folds share labels (derived from parameter rows instead); AC3 rested on green tests rather than unchanged output (now an empty diff and unchanged snapshots); `has_results_columns()` omitted from AC5 (added); the partial-inner-split case unprobed (added to AC1); the final-fit accessor's shape left implicit (settled: kept, recorded in D-043).
- 2026-09-02: plan gate chose keeping `.selected` over dropping it for an on-the-fly `slice_min()` because it records what the outer fit used under `select_best()`'s tie rules and DESIGN.md's selection-stability stance names it; falsified by evidence that recomputing from `.inner_metrics` always reproduces it.
- 2026-09-02: plan chose leaving `extract_scored_candidates()` unchanged over reshaping it to the metrics table because nothing on the final fit is broken and the divergence is one sentence in D-043; falsified by a user comparing the two surfaces row for row.

## Decisions

## Review
