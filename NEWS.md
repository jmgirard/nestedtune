# nestedtune 0.0.0.9000

* `nested_tune_grid()` now runs its outer folds in parallel. Start workers with
  `mirai::daemons(n)` before the call and the loop uses them; there is no
  argument to set, and no daemons means the serial behaviour is unchanged.
  Inner tuning still runs serially, because nesting parallelism inside
  parallelism oversubscribes cores.

* Parallel results are identical to serial ones. The same seed gives the same
  answer at any number of workers, because each fold's seeds are drawn before
  the loop starts and assigned by position — a fold's result depends on where it
  sits in the design, never on which worker ran it. A fold whose worker dies is
  recorded as a failed fold like any other, and the run finishes.

* `?nested_tune_grid` gains a "Parallel execution" section covering what workers
  do and do not inherit from your session, and why the package must be installed
  where they can load it.

* A new guide, `vignette("nested-cv")`, runs the whole path — build a nested
  design, run the loop, read what each fold selected, fit the model to deploy —
  as code you can run, and says plainly what to report for that model and why.
  It puts the nested estimate next to the selection-time score users are most
  tempted to report, and closes with a worked write-up. Every number in its
  prose is produced when the vignette is built, so a claim that stops being true
  fails the check rather than ageing quietly.

* New `nested_final_fit()` builds the model you actually deploy. It runs the
  same tuning procedure the nested estimate describes, this time with the whole
  dataset in hand: it re-evaluates the design's inner resampling specification
  against every row, tunes, selects, and fits. Reach the trained workflow with
  `extract_workflow()`.

* The final model is a separate object rather than a field on the results, and
  it carries no performance number of its own. Report the estimate from
  `collect_metrics()` on the `nested_tune_grid()` result for it — the
  documentation says why, and what that number does and does not claim.
  `collect_metrics()`, `show_best()`, and `select_best()` deliberately refuse a
  final fit rather than returning something that reads as its score.

* Because the inner resampling specification is stored unevaluated and
  re-evaluated at final-fit time, write it with literal arguments —
  `inside = vfold_cv(v = 5)`, not `inside = vfold_cv(v = k)`. A specification
  whose variables have gone out of scope now fails with a message naming it.

* Nested results now print as a report on the run rather than as a table of
  list columns. It names the outer resampling scheme, says how many folds were
  requested and how many completed, names any fold that failed along with the
  stage it failed at, and gives the estimate across the folds that contributed.

* Printing shows what each outer fold's inner tuning selected, marking whether
  the folds agreed on a parameter or disagreed about it and, when they
  disagreed, listing every fold's choice. Disagreement means the tuning
  procedure is unstable on this data, which averaging the metrics would hide.

* Printing also states plainly that the estimate describes the tune-and-fit
  procedure rather than a model you can deploy — the caveat now travels with
  the number instead of living only in the documentation.

* Printing never warns and never errors, including for a run where no outer
  fold completed at all. `collect_metrics()` still does both: asking for a
  summary of a design that did not run deserves a condition, while describing
  an object does not.

* An outer fold that fails no longer ends the run. The remaining folds still
  run, and the failed one is recorded rather than thrown away: `.completed`
  marks it, and `.notes` says which stage failed and why, carrying tune's own
  notes about the underlying cause. This matters because both stages can fail
  quietly — inner tuning only raises once every candidate has failed, and the
  outer fit does not raise at all.

* A fold that completes on only part of its inner design now keeps the notes
  explaining what was lost. `.completed` being `TRUE` alongside a non-empty
  `.notes` means the fold worked, but chose its parameters on less of the inner
  design than was requested.

* `nested_tune_grid()` now checks a data-frame `grid` against the workflow
  before fitting anything: a column that is not marked for tuning, or a tuned
  parameter with no column, is refused immediately and by name. Either mistake
  is wrong for every fold rather than for one, so it is reported as what it is
  — an error in the call — instead of as an entire design failing.

* `collect_metrics()` now summarizes only the outer folds that completed, warns
  naming the ones that did not, and errors rather than returning `NA` when none
  completed. An estimate is never reported as though it came from a design that
  did not run.

* Added `nested_tune_grid()`, which runs the nested cross-validation loop end to
  end. For each outer fold it tunes on that fold's inner resamples with
  `tune::tune_grid()`, selects the best candidate, finalizes the workflow, and
  fits and scores it on the outer split. The result keeps each fold's chosen
  parameters alongside its metrics, so disagreement between folds — selection
  instability — is visible rather than averaged away.

* Added a `collect_metrics()` method for those results, returning either the
  per-fold metrics or their summary across outer folds.

* `nested_tune_grid()` is reproducible from a single `set.seed()` before the
  call. It derives one tuning seed and one outer-fit seed per fold up front, so
  a fold's result depends on its position in the design rather than on the order
  folds happen to run in, and it leaves the caller's random-number state exactly
  as it found it.

* Added `nested_resamples()`, a constructor for nested resampling designs that
  does not keep a copy of the data for every outer fold. For the same seed and
  the same specifications it selects the same rows as `rsample::nested_cv()`:
  `analysis()` and `assessment()` return identical frames, and each inner split
  carries the same class and resample id. On a 20000-row dataset with a
  five-fold inner resampling, a 50-fold outer design holds 10× the source data
  rather than 57×.

* `nested_resamples()` refuses an outer bootstrap rather than warning about it.
  The same observation can otherwise land in both the inner analysis and the
  inner assessment set, which makes the design invalid rather than unusual.
