# nestedtune 0.0.0.9000

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
