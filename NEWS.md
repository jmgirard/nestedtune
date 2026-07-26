# nestedtune 0.0.0.9000

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
