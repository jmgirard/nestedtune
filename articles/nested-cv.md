# Nested cross-validation

You tuned a model with cross-validation and kept the candidate that
scored best. That score is not an estimate of how the model will do on
new data. The candidate was chosen because it scored well on those
resamples, so its score carries the selection along with it, and
reporting it overstates what you have.

Nested cross-validation removes the contamination by putting the whole
tune-and-fit procedure inside a second, outer resampling loop. Each
outer fold tunes from scratch on its own analysis data, fits the winner
there, and scores it once on assessment rows that no part of the tuning
ever saw. Averaging those outer scores estimates how the procedure
(resample, tune, select, fit) performs on new data.

What comes back is a property of the procedure, never of any one fitted
model. The model you eventually deploy is a separate object, produced
further down this page, and it has no honest performance number of its
own. This page walks the path from a design to a write-up. What the
estimate means, and what it does not, is the subject of
[`vignette("estimate")`](https://nestedtune.tidymodels.org/articles/estimate.md).

``` r

library(nestedtune)
library(parsnip)
library(rsample)
library(workflows)
```

## The design

[`nested_resamples()`](https://nestedtune.tidymodels.org/reference/nested_resamples.md)
builds the two-level structure: an outer resampling, with an inner
resampling attached to each outer fold.

``` r

set.seed(1)

folds <- nested_resamples(
  mtcars,
  outside = vfold_cv(v = 5),
  inside = vfold_cv(v = 5)
)

folds
#> # Nested resampling:
#> #  outer: 5-fold cross-validation
#> #  inner: 5-fold cross-validation
#> # A tibble: 5 × 3
#>   splits         id    inner_resamples
#>   <list>         <chr> <list>         
#> 1 <split [25/7]> Fold1 <vfold [5 × 2]>
#> 2 <split [25/7]> Fold2 <vfold [5 × 2]>
#> 3 <split [26/6]> Fold3 <vfold [5 × 2]>
#> 4 <split [26/6]> Fold4 <vfold [5 × 2]>
#> 5 <split [26/6]> Fold5 <vfold [5 × 2]>
```

Each row is one outer fold. `splits` holds that fold’s outer split, and
`inner_resamples` holds an ordinary `rset` built from its analysis rows
alone, which is what the tuning for that fold gets to see.

``` r

folds$inner_resamples[[1]]
#> #  5-fold cross-validation 
#> # A tibble: 5 × 2
#>   splits         id   
#>   <list>         <chr>
#> 1 <split [20/5]> Fold1
#> 2 <split [20/5]> Fold2
#> 3 <split [20/5]> Fold3
#> 4 <split [20/5]> Fold4
#> 5 <split [20/5]> Fold5
```

`mtcars` has 32 rows, which keeps this page fast to build. With that
little data the tuning step is unstable, and the fold-to-fold selections
further down show it directly. It is not the case where nesting removes
the most. That is wide data searched hard, and
[`vignette("estimate")`](https://nestedtune.tidymodels.org/articles/estimate.md)
says why.

## The model and the grid

Anything `tune` can tune, this can tune. Here it is a random forest with
two parameters marked for tuning, and an explicit grid of candidates.

``` r

rf <- rand_forest(mtry = tune(), min_n = tune(), trees = 500) |>
  set_engine("ranger") |>
  set_mode("regression")

wf <- workflow(mpg ~ ., rf)

grid <- expand.grid(mtry = c(2L, 5L, 8L), min_n = c(2L, 10L))
grid
#>   mtry min_n
#> 1    2     2
#> 2    5     2
#> 3    8     2
#> 4    2    10
#> 5    5    10
#> 6    8    10
```

That is 6 candidates, each of which will be resampled inside every outer
fold. The run below fits 150 models for tuning, plus one per outer fold
for scoring. Nested cross-validation is expensive, and that arithmetic
is where the cost lives.

## Running the loop

[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
drives the outer loop. For each outer fold it calls
[`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)
on that fold’s inner resamples, selects the best candidate, finalizes
the workflow, and fits and scores it on the outer split. Every
statistical step is `tune`’s. What this package contributes is the loop,
a reproducibility contract, and a result that keeps what each fold
chose.

``` r

set.seed(2)

res <- nested_tune_grid(wf, folds, grid = grid)

res
#> 
#> ── Nested cross-validation results ────────────────────────────────────
#> Outer resamples: 5-fold cross-validation
#> # A tibble: 5 × 9
#>   splits         id    .metrics .selected .inner_metrics    .notes  
#>   <list>         <chr> <list>   <list>    <list>            <list>  
#> 1 <split [25/7]> Fold1 <tibble> <tibble>  <tibble [12 × 8]> <tibble>
#> 2 <split [25/7]> Fold2 <tibble> <tibble>  <tibble [12 × 8]> <tibble>
#> 3 <split [26/6]> Fold3 <tibble> <tibble>  <tibble [12 × 8]> <tibble>
#> 4 <split [26/6]> Fold4 <tibble> <tibble>  <tibble [12 × 8]> <tibble>
#> 5 <split [26/6]> Fold5 <tibble> <tibble>  <tibble [12 × 8]> <tibble>
#> # ℹ 3 more variables: .completed <lgl>, .tuning_seed <int>,
#> #   .outer_fit_seed <int>
#> ℹ Use `summary()` for what the run means: which folds failed, what
#>   each one selected, and the estimate across them.
```

Printing shows the object: one row per outer fold, and the record each
fold left behind. [`summary()`](https://rdrr.io/r/base/summary.html)
says what the run means.

``` r

summary(res)
#> 
#> ── Nested cross-validation results ────────────────────────────────────
#> Outer resamples: 5-fold cross-validation
#> Outer folds: 5 requested, 5 completed
#> 
#> ── Selected parameters ──
#> 
#> ! mtry: 8, 8, 5, 8, 5 (folds disagree)
#> ✔ min_n: 2 (all 5 completed folds agree)
#> 
#> ── Estimate (5 of 5 outer folds) ──
#> 
#> rmse (standard): 2.49
#> rsq (standard): 0.842
#> 
#> ℹ A nested estimate describes the tune-and-fit procedure, not a model
#>   you can deploy. Build that with `nested_final_fit()`, and report
#>   this estimate as what its procedure achieves.
```

## What to report

``` r

est <- collect_metrics(res)
est
#> # A tibble: 2 × 5
#>   .metric .estimator  mean     n std_err
#>   <chr>   <chr>      <dbl> <int>   <dbl>
#> 1 rmse    standard   2.49      5  0.447 
#> 2 rsq     standard   0.842     5  0.0293

rmse_row <- est[est$.metric == "rmse", ]
```

Report that. The RMSE of 2.49 is the mean of 5 scores, each measured on
rows the procedure never touched. It estimates the error of the whole
procedure, resampling, tuning, selecting and fitting, on data drawn like
`mtcars`. It is not the error of the model you deploy, and `std_err` is
the standard error of that mean, not the spread of the folds and not a
confidence interval.
[`vignette("estimate")`](https://nestedtune.tidymodels.org/articles/estimate.md)
names the quantity exactly, says why to expect it to run a little
pessimistic, and says why two of these numbers cannot be subtracted to
compare workflows.

## What each fold chose

The summary above reported this, and `.selected` holds it exactly: a
list column of one-row tibbles, one per outer fold, each holding the
parameters that fold’s inner tuning chose. Stacked up, with the fold
each came from:

``` r

selected <- do.call(rbind, res$.selected)

data.frame(fold = res$id, mtry = selected$mtry, min_n = selected$min_n)
#>    fold mtry min_n
#> 1 Fold1    8     2
#> 2 Fold2    8     2
#> 3 Fold3    5     2
#> 4 Fold4    8     2
#> 5 Fold5    5     2
```

``` r

n_mtry <- length(unique(selected$mtry))
n_min_n <- length(unique(selected$min_n))
```

Across 5 outer folds, `mtry` took 2 distinct selected values and `min_n`
took 1. Most tools throw this away. nestedtune keeps it, because it is
information about the procedure rather than noise in it.

[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
draws the same thing, one panel per tuned parameter and one point per
outer fold. A flat row means the folds agreed. Scatter means they did
not.

``` r

autoplot(res)
```

![One panel per tuned parameter, with one point per outer fold at the
value that fold's inner tuning
selected.](nested-cv_files/figure-html/autoplot-parameters-1.png)

Read it as a statement about how well-determined each tuning choice is
at this sample size. A parameter the folds agree on is one the data
picks clearly. A parameter they split over is one whose value is largely
arbitrary, so whichever value your final model ends up carrying was not
strongly preferred by the evidence. That is expected wherever the
candidates perform about equally well, and
[`vignette("estimate")`](https://nestedtune.tidymodels.org/articles/estimate.md)
gives the mechanism.

The per-fold scores are worth a look for the same reason:

``` r

per_fold <- collect_metrics(res, summarize = FALSE)
per_fold
#> # A tibble: 10 × 4
#>    id    .metric .estimator .estimate
#>    <chr> <chr>   <chr>          <dbl>
#>  1 Fold1 rmse    standard       1.23 
#>  2 Fold1 rsq     standard       0.911
#>  3 Fold2 rmse    standard       3.22 
#>  4 Fold2 rsq     standard       0.819
#>  5 Fold3 rmse    standard       2.48 
#>  6 Fold3 rsq     standard       0.805
#>  7 Fold4 rmse    standard       1.83 
#>  8 Fold4 rsq     standard       0.766
#>  9 Fold5 rmse    standard       3.69 
#> 10 Fold5 rsq     standard       0.911

fold_rmse <- per_fold$.estimate[per_fold$.metric == "rmse"]
c(sd = sd(fold_rmse), std_err = sd(fold_rmse) / sqrt(length(fold_rmse)))
#>        sd   std_err 
#> 1.0002719 0.4473352
```

Wide spread across outer folds at this sample size is expected. Note the
two numbers above: 1 is how much the folds actually differ from each
other, and 0.45 is the `std_err`
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
reports, the precision of their mean. Quoting the second as though it
described the folds understates their disagreement.

The other view of
[`autoplot()`](https://ggplot2.tidyverse.org/reference/autoplot.html)
shows that spread, with the dashed line at the nested estimate. It is
the same number
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
reports, so the figure and the summary cannot drift apart.

``` r

autoplot(res, type = "performance")
```

![One panel per metric, with one point per outer fold's score and a
dashed line at the mean across
folds.](nested-cv_files/figure-html/autoplot-performance-1.png)

## The model you deploy

Nothing above produced a model you can predict with, and that is
deliberate. The estimate describes the procedure. The model is a
separate object, built by running that same procedure once more with the
whole dataset in hand. The procedure is read from `res` (the design’s
inner resampling specification, the grid, the metrics), so it cannot be
restated: the model and the estimate come from one search.

``` r

set.seed(3)

final <- nested_final_fit(wf, res)

final
#> 
#> ── Nested cross-validation final fit ──────────────────────────────────
#> Procedure: grid search, 6 candidates scored
#> Selected: mtry = 2, min_n = 2
#> 
#> ℹ This model has no performance estimate of its own. Report the nested
#>   estimate from `collect_metrics()` on the results object this fit was
#>   built from, which describes the procedure that produced it.
#> ℹ Compare the parameters above with `.selected` from that run. Outer
#>   folds choosing differently is selection instability, and it is
#>   information about the procedure rather than noise.
#> ℹ `extract_tune_results()` returns the tuning run selection came from,
#>   and `extract_scored_candidates()` the candidates it scored. Any
#>   metric reachable through the first is a selection-time quantity,
#>   optimistically biased as a claim about this model.
```

The outer folds play no part here. Their selections are not pooled or
voted on. They belong to the estimate, which describes the procedure
across the instability they reveal.

The object predicts directly.
[`predict()`](https://rdrr.io/r/stats/predict.html) and
[`augment()`](https://generics.r-lib.org/reference/augment.html) on it
are the trained workflow’s own methods, and
[`extract_workflow()`](https://hardhat.tidymodels.org/reference/hardhat-extract.html)
returns the workflow itself:

``` r

predict(final, new_data = mtcars[1:3, ])
#> # A tibble: 3 × 1
#>   .pred
#>   <dbl>
#> 1  20.9
#> 2  20.9
#> 3  24.0
```

`final$tuning` is the tuning run this model’s parameters were selected
from, and its best score is the number a user is most tempted to report:

``` r

selection_scores <- collect_metrics(final$tuning)
selection_rmse <- selection_scores[selection_scores$.metric == "rmse", ]
best_selection_rmse <- min(selection_rmse$mean)

data.frame(
  quantity = c("nested estimate (report this)", "best selection-time score"),
  rmse = c(rmse_row$mean, best_selection_rmse)
)
#>                        quantity     rmse
#> 1 nested estimate (report this) 2.490053
#> 2     best selection-time score 2.583402
```

The selection-time score is higher than the nested estimate here, 2.58
against 2.49. Do not read the direction as the lesson. With 32 rows a
difference this size is well inside what resampling noise produces, and
the point stands whichever way it falls: the selection-time number was
computed on the very resamples that chose the winner, so it is not an
estimate of performance on anything. It is kept on the object because it
is the record of what selection saw, and
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
will hand it over without warning you.

The model in hand has no honest number of its own. Everything computable
from its training data was consumed by selecting it or by fitting it.
That is why both objects refuse tune’s ranking generics rather than
answering them. On the loop’s results they would rank outer folds, which
is not a ranking of anything a user wants. On the final fit there is
only one model and nothing to rank, and what they would surface is the
selection-time score dressed as a performance number.

``` r

tune::show_best(res, metric = "rmse")
#> Error in `tune::show_best()`:
#> ! No `show_best()` exists for this type of object.
```

``` r

tune::select_best(final, metric = "rmse")
#> Error in `tune::select_best()`:
#> ! No `select_best()` exists for this type of object.
```

## Where this example sits

Nesting is expensive, and it removes most when the search is large
relative to the data: wide data, a big grid, and preprocessing the loop
has to redo. It removes little when the data is tall and the search is
small, and any feature selection has to sit inside the workflow you hand
it or the loop cannot see it.
[`vignette("estimate")`](https://nestedtune.tidymodels.org/articles/estimate.md)
gives the measurements behind each of those. By those lights the example
on this page sits at the modest end: `mtcars` has more rows than
columns, the grid has 6 points, and there is no feature selection at
all. It is here because it builds in seconds, not because it is where
nesting pays best.

## Reproducibility

Seed the session before the call, as elsewhere in tidymodels. Neither
function takes a seed of its own. Each draws and pins its own per-step
seeds from the session state instead, and stores them, so any single
piece is reproducible by hand:

``` r

res$.tuning_seed
#> [1]  794080207 1906307464 2010156236 1118907979 2046114256
final$tuning_seed
#> [1] 721735354
```

Because each fold’s seeds are fixed by its position in the design rather
than by the order the folds happen to run in, the result does not depend
on how the loop is scheduled. And the caller’s own random state is put
back as it was found:

``` r

before <- .Random.seed

invisible(nested_final_fit(wf, res))

identical(before, .Random.seed)
#> [1] TRUE
```

[`?nested_tune_grid`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
and
[`?nested_final_fit`](https://nestedtune.tidymodels.org/reference/nested_final_fit.md)
give the exact hand-replication recipe for each.

## Writing it up

Everything a write-up needs is on the two objects. A minimal, honest
report:

> Hyperparameters (`mtry`, `min_n`) were tuned over a 6-point grid by
> 5-fold cross-validation, nested inside a 5-fold outer cross-validation
> of the entire tune-and-fit procedure (n = 32). The outer folds give an
> estimated RMSE of 2.49 (SE 0.45) for the procedure. Across those 5
> folds, selection took 2 distinct values of `mtry` and 1 of `min_n`.
> The deployed model was produced by applying the same procedure to the
> full dataset, which selected mtry = 2 and min_n = 2.

The three things that make it honest are the ones this package exists to
keep together: the estimate is attributed to the procedure and not to
the model, the instability is reported rather than hidden, and the
deployed model is described as what it is, the same procedure applied to
all the data, carrying no performance claim of its own.
