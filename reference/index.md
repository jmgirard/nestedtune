# Package index

## Nested resampling

Build a nested resampling design whose size does not grow by a copy of
the data for every outer fold.

- [`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
  : Build a nested resampling design without copying the data per outer
  fold

## Running the loop

Tune on each outer fold’s inner resamples, select, then fit and score on
the outer split — and keep what each fold chose.

- [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  : Run the nested cross-validation loop
- [`collect_metrics(`*`<nested_results>`*`)`](https://nestedtune.tidymodels.org/reference/collect_metrics.nested_results.md)
  : Collect the metrics from a nested resampling run
- [`print(`*`<nested_results>`*`)`](https://nestedtune.tidymodels.org/reference/print.nested_results.md)
  : Print a nested cross-validation result
- [`summary(`*`<nested_results>`*`)`](https://nestedtune.tidymodels.org/reference/summary.nested_results.md)
  [`print(`*`<summary.nested_results>`*`)`](https://nestedtune.tidymodels.org/reference/summary.nested_results.md)
  : Summarize a nested cross-validation result
- [`autoplot(`*`<nested_results>`*`)`](https://nestedtune.tidymodels.org/reference/autoplot.nested_results.md)
  : Plot a nested cross-validation result

## The final model

Run the same tuning procedure once more with the whole dataset in hand,
and get back the model to deploy — as its own object, never a field on
the results.

- [`nested_final_fit()`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
  : Fit the final model after nested cross-validation
- [`print(`*`<nested_final_fit>`*`)`](https://nestedtune.tidymodels.org/reference/print.nested_final_fit.md)
  : Print a final fit
- [`extract_tune_results()`](https://nestedtune.tidymodels.org/reference/extract_tune_results.md)
  : Extract the tuning run a final fit was selected from
- [`extract_scored_candidates()`](https://nestedtune.tidymodels.org/reference/extract_scored_candidates.md)
  : Extract the candidates a final fit actually scored

## Re-exports

- [`reexports`](https://nestedtune.tidymodels.org/reference/reexports.md)
  [`collect_metrics`](https://nestedtune.tidymodels.org/reference/reexports.md)
  [`extract_workflow`](https://nestedtune.tidymodels.org/reference/reexports.md)
  [`autoplot`](https://nestedtune.tidymodels.org/reference/reexports.md)
  : Objects exported from other packages
