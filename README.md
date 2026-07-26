# nestedtune

<!-- badges: start -->
[![R-CMD-check](https://github.com/jmgirard/nestedtune/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/jmgirard/nestedtune/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/jmgirard/nestedtune/graph/badge.svg)](https://app.codecov.io/gh/jmgirard/nestedtune)
<!-- badges: end -->

Nested cross-validation for the tidymodels ecosystem.

## Installation

``` r
# install.packages("pak")
pak::pak("jmgirard/nestedtune")
```

## Building a nested resampling design

`nested_resamples()` builds the same structure as `rsample::nested_cv()` — an
outer resampling with an inner resampling attached to each outer fold — without
keeping a copy of the data for every outer fold.

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

For the same seed and the same specifications the splits are identical to
rsample's, down to the attributes of the retrieved frames — so it is a drop-in
substitution, not an approximation.

## Why

`rsample::nested_cv()` evaluates the inner specification against
`as.data.frame(split)`, so every outer fold's inner resamples reference their
own materialized copy of that fold's analysis set. Object size therefore grows
by roughly one copy of the data per outer fold ([rsample#283][issue]).

`nested_resamples()` evaluates the inner specification against the same frame,
keeps only the row indices it produces, and remaps them onto the original data.
Measured on `mlbench::LetterRecognition` (20000 × 17) with a five-fold inner
resampling, as multiples of the source data size:

| outer folds | `rsample::nested_cv()` | `nested_resamples()` |
|---:|---:|---:|
| 2 | 2.2× | 1.2× |
| 5 | 5.6× | 1.7× |
| 10 | 11.4× | 2.6× |
| 50 | 57.5× | 10.0× |

What remains is the index vectors, which rsample stores too; the copies of the
data are gone.

## Scope

This release ships the resampling structure only. Running the nested loop —
tuning on each outer fold's inner resamples, selecting, and scoring on the outer
assessment set — is the package's purpose and is in development.

[issue]: https://github.com/tidymodels/rsample/issues/283
