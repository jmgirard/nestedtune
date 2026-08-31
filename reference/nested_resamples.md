# Build a nested resampling design without copying the data per outer fold

`nested_resamples()` builds the same nested resampling structure as
[`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html),
but stores index vectors into the original data instead of a
materialized analysis set for every outer fold. For the same seed and
the same specifications it produces the same splits; what changes is the
size of the object that holds them.

## Usage

``` r
nested_resamples(data, outside, inside, ...)
```

## Arguments

- data:

  A data frame.

- outside:

  The outer resampling specification, given either as an unevaluated
  call such as `vfold_cv(v = 5)` or as an already-evaluated `rset`
  object.

- inside:

  The inner resampling specification, given as an unevaluated call such
  as `vfold_cv(v = 5)`. Unlike `outside`, this cannot be an existing
  object, because it is evaluated once per outer fold.

- ...:

  Not used; must be empty. All three arguments above are required, so
  the barrier is what turns a mistyped fourth into an error.

## Value

An object of class `nested_resamples`, which also carries the classes
[`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
returns, so methods written against those keep working. It is the outer
`rset` with an `inner_resamples` list column added, one inner `rset` per
outer split.

## Details

[`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)
evaluates the inner specification against `as.data.frame(split)`, so
each outer fold's inner resamples reference their own copy of that
fold's analysis set. Object size therefore grows by roughly one copy of
the data for every outer fold. `nested_resamples()` evaluates the inner
specification the same way, against the same transient frame, but keeps
only the row indices it produces and remaps them onto the original data
— so the inner splits reference the single shared copy the caller
already has.

## Differences from rsample

The splits select the same rows.
[`rsample::analysis()`](https://rsample.tidymodels.org/reference/as.data.frame.rsplit.html)
and
[`rsample::assessment()`](https://rsample.tidymodels.org/reference/as.data.frame.rsplit.html)
return identical frames, attributes included, and each inner split
carries the class and the resample id rsample gives it, so
[`labels()`](https://rdrr.io/r/base/labels.html) and
[`rsample::add_resample_id()`](https://rsample.tidymodels.org/reference/add_resample_id.html)
behave the same. What differs is what the splits point at: nestedtune's
index the original data, rsample's index a materialized copy of each
outer fold's analysis set. One behavior differs on purpose.

An **outer bootstrap is refused**, not warned about. The same
observation can otherwise land in both the inner analysis and the inner
assessment set, which makes the design invalid rather than merely
unusual.

## See also

[`rsample::nested_cv()`](https://rsample.tidymodels.org/reference/nested_cv.html)

## Examples

``` r
data(mtcars)

set.seed(1)
folds <- nested_resamples(
  mtcars,
  outside = rsample::vfold_cv(v = 3),
  inside = rsample::vfold_cv(v = 3)
)
folds
#> # Nested resampling:
#> #  outer: 3-fold cross-validation
#> #  inner: 3-fold cross-validation
#> # A tibble: 3 × 3
#>   splits          id    inner_resamples
#>   <list>          <chr> <list>         
#> 1 <split [21/11]> Fold1 <vfold [3 × 2]>
#> 2 <split [21/11]> Fold2 <vfold [3 × 2]>
#> 3 <split [22/10]> Fold3 <vfold [3 × 2]>

# Each element of inner_resamples is an ordinary rset.
folds$inner_resamples[[1]]
#> #  3-fold cross-validation 
#> # A tibble: 3 × 2
#>   splits         id   
#>   <list>         <chr>
#> 1 <split [14/7]> Fold1
#> 2 <split [14/7]> Fold2
#> 3 <split [14/7]> Fold3
```
