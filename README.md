
<!-- README.md is generated from README.Rmd. Please edit that file -->

# nestedtune

<!-- badges: start -->

[![R-CMD-check](https://github.com/tidymodels/nestedtune/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/tidymodels/nestedtune/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/tidymodels/nestedtune/graph/badge.svg)](https://app.codecov.io/gh/tidymodels/nestedtune)
<!-- badges: end -->

Nested cross-validation for the tidymodels ecosystem.

Start with [Nested
cross-validation](https://nestedtune.tidymodels.org/articles/nested-cv.html)
— what the estimate means, what to report instead of your model’s own
score, and how to read disagreement between outer folds.

## Installation

``` r
# install.packages("pak")
pak::pak("tidymodels/nestedtune")
```

## Building a nested resampling design

`nested_resamples()` builds the same structure as `rsample::nested_cv()`
— an outer resampling with an inner resampling attached to each outer
fold — without keeping a copy of the data for every outer fold.

``` r
library(nestedtune)

set.seed(1)
folds <- nested_resamples(
  mtcars,
  outside = rsample::vfold_cv(v = 5),
  inside = rsample::vfold_cv(v = 5)
)

folds$inner_resamples[[1]]
```

For the same seed and the same specifications the splits select the same
rows as rsample’s: `analysis()` and `assessment()` return identical
frames, and each inner split carries the same class and resample id, so
anything dispatching on those keeps working. What differs is what the
splits point at — the original data rather than a materialized copy per
outer fold.

## Why

`rsample::nested_cv()` evaluates the inner specification against
`as.data.frame(split)`, so every outer fold’s inner resamples reference
their own materialized copy of that fold’s analysis set. Object size
therefore grows by roughly one copy of the data per outer fold
([rsample#283](https://github.com/tidymodels/rsample/issues/283)).

`nested_resamples()` evaluates the inner specification against the same
frame, keeps only the row indices it produces, and remaps them onto the
original data. Measured on `mlbench::LetterRecognition` (20000 × 17)
with a five-fold inner resampling, as multiples of the source data size:

| outer folds | `rsample::nested_cv()` | `nested_resamples()` |
|------------:|-----------------------:|---------------------:|
|           2 |                   2.2× |                 1.2× |
|           5 |                   5.6× |                 1.7× |
|          10 |                  11.4× |                 2.6× |
|          50 |                  57.5× |                10.0× |

What remains is the index vectors, which rsample stores too; the copies
of the data are gone.

## Running the nested loop

`nested_tune_grid()` tunes on each outer fold’s inner resamples,
selects, fits on the outer analysis set, and scores on the outer
assessment set — keeping what each fold chose. `nested_final_fit()`
takes that result and runs the procedure it recorded once more with the
whole dataset in hand, and gives back the model to deploy as its own
object.

``` r
library(nestedtune)
library(parsnip)
library(rsample)
library(workflows)

wf <- workflow(
  mpg ~ .,
  rand_forest(mtry = tune(), min_n = tune()) |>
    set_engine("ranger") |>
    set_mode("regression")
)
grid <- expand.grid(mtry = c(2L, 5L, 8L), min_n = c(2L, 10L))

set.seed(1)
folds <- nested_resamples(
  mtcars,
  outside = vfold_cv(v = 5),
  inside = vfold_cv(v = 5)
)

# The estimate: what the whole tune-and-fit procedure achieves. Report this.
set.seed(2)
res <- nested_tune_grid(wf, folds, grid = grid)
collect_metrics(res)
#> # A tibble: 2 × 5
#>   .metric .estimator  mean     n std_err
#>   <chr>   <chr>      <dbl> <int>   <dbl>
#> 1 rmse    standard   2.46      5  0.445 
#> 2 rsq     standard   0.844     5  0.0267

# The model: what you deploy. It has no performance number of its own.
set.seed(3)
final <- nested_final_fit(wf, res)
predict(final, new_data = mtcars[1:3, ])
#> # A tibble: 3 × 1
#>   .pred
#>   <dbl>
#> 1  20.9
#> 2  20.9
#> 3  23.8
```

Why the estimate belongs to the procedure rather than to the model, and
what to write up, is the subject of [the
guide](https://nestedtune.tidymodels.org/articles/nested-cv.html).
