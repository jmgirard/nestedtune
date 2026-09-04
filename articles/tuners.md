# Choosing the inner tuner

The getting-started guide,
[`vignette("nested-cv")`](https://nestedtune.tidymodels.org/articles/nested-cv.md),
tunes each outer fold over a fixed grid with
[`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md).
That is one of five ways the inner search can run. The other four are
tune’s Bayesian optimization and finetune’s two racing methods and its
simulated annealing, and each has a driver here that takes the same
design and workflow and returns the same kind of object. This page runs
all four on the guide’s example, shows what each fold records about its
search, shows how a tune control object reaches the inner call, and says
what differs from calling tune or finetune directly.

``` r

library(nestedtune)
library(parsnip)
library(rsample)
library(workflows)
```

## The design and the workflow

These are the guide’s, unchanged: five outer folds of `mtcars`, five
inner folds under each, and a random forest with two parameters marked
for tuning.

``` r

set.seed(1)

folds <- nested_resamples(
  mtcars,
  outside = vfold_cv(v = 5),
  inside = vfold_cv(v = 5)
)

rf <- rand_forest(mtry = tune(), min_n = tune(), trees = 500) |>
  set_engine("ranger") |>
  set_mode("regression")

wf <- workflow(mpg ~ ., rf)

grid <- expand.grid(mtry = c(2L, 5L, 8L), min_n = c(2L, 10L))
```

The grid tuner and the racers score the candidates they are given. The
Bayesian and annealing searches propose their own candidates instead,
and to do that they need to know each parameter’s range. The default
range of `mtry` is not known until the data is seen, so a search over it
fails at inner tuning in every fold with the message that `mtry` must be
a parameter object without unknowns. The parameter set below fixes that
range by hand, and bounds `min_n` to the grid’s range too, because its
default runs past the size of an inner analysis set here.

``` r

params <- update(
  tune::extract_parameter_set_dials(wf),
  mtry = dials::mtry(c(2L, 8L)),
  min_n = dials::min_n(c(2L, 10L))
)

params
#> Collection of 2 parameters for tuning
#> 
#>  identifier  type    object
#>        mtry  mtry nparam[+]
#>       min_n min_n nparam[+]
#> 
```

## Bayesian optimization

[`nested_tune_bayes()`](https://nestedtune.tidymodels.org/reference/nested_tune_bayes.md)
runs
[`tune::tune_bayes()`](https://tune.tidymodels.org/reference/tune_bayes.html)
inside each outer fold. The search starts from a small space-filling set
of candidates, scores them on the inner resamples, and then proposes one
new candidate per iteration from a Gaussian process fitted to the scores
so far. `initial` and `iter` are the sizes of those two stages, kept
small here so the page builds quickly.

``` r

set.seed(2)

bayes <- nested_tune_bayes(
  wf,
  folds,
  param_info = params,
  initial = 4,
  iter = 3
)

bayes
#> ── Nested cross-validation results ────────────────────────────────────
#> Outer resamples: 5-fold cross-validation
#> # A tibble: 5 × 9
#>   splits         id    .metrics .selected .inner_metrics    .notes  
#>   <list>         <chr> <list>   <list>    <list>            <list>  
#> 1 <split [25/7]> Fold1 <tibble> <tibble>  <tibble [14 × 9]> <tibble>
#> 2 <split [25/7]> Fold2 <tibble> <tibble>  <tibble [14 × 9]> <tibble>
#> 3 <split [26/6]> Fold3 <tibble> <tibble>  <tibble [14 × 9]> <tibble>
#> 4 <split [26/6]> Fold4 <tibble> <tibble>  <tibble [14 × 9]> <tibble>
#> 5 <split [26/6]> Fold5 <tibble> <tibble>  <tibble [14 × 9]> <tibble>
#> # ℹ 3 more variables: .completed <lgl>, .tuning_seed <int>,
#> #   .outer_fit_seed <int>
#> ! Candidates searched: 7, 7, 7, 7, 7 — the folds did not search the
#>   same grid
#> ℹ Use `summary()` for what the run means: which folds failed, what
#>   each one selected, and the estimate across them.
```

Each fold scored 7 candidates on 5 inner resamples, which is 35 fits per
outer fold for tuning, against the 30 the guide’s grid costs. The print
above notes that the folds did not search the same grid. That is the
nature of the search rather than a fault: each fold proposes candidates
from its own scores, so no two folds need score the same set, and the
note is there so that a reader of the summary does not mistake the
selections for a vote over shared candidates.

`.inner_metrics` holds what the search inside one fold saw. Here is the
first fold’s:

``` r

bayes$.inner_metrics[[1]]
#> # A tibble: 14 × 9
#>     mtry min_n .metric .estimator  mean     n std_err .config     .iter
#>    <int> <int> <chr>   <chr>      <dbl> <int>   <dbl> <chr>       <int>
#>  1     2     4 rmse    standard   2.88      5  0.453  pre0_mod1_…     0
#>  2     2     4 rsq     standard   0.811     5  0.0970 pre0_mod1_…     0
#>  3     4    10 rmse    standard   2.94      5  0.535  pre0_mod2_…     0
#>  4     4    10 rsq     standard   0.790     5  0.118  pre0_mod2_…     0
#>  5     6     2 rmse    standard   2.82      5  0.440  pre0_mod3_…     0
#>  6     6     2 rsq     standard   0.839     5  0.0891 pre0_mod3_…     0
#>  7     8     7 rmse    standard   2.83      5  0.445  pre0_mod4_…     0
#>  8     8     7 rsq     standard   0.829     5  0.105  pre0_mod4_…     0
#>  9     5     6 rmse    standard   2.83      5  0.451  iter1           1
#> 10     5     6 rsq     standard   0.818     5  0.106  iter1           1
#> 11     6     5 rmse    standard   2.83      5  0.458  iter2           2
#> 12     6     5 rsq     standard   0.837     5  0.102  iter2           2
#> 13     3    10 rmse    standard   2.99      5  0.515  iter3           3
#> 14     3    10 rsq     standard   0.786     5  0.117  iter3           3
```

The `.iter` column says which stage each candidate came from: `.iter` of
0 marks the initial set, and the proposals run up to 3. A control that
stops the search early, shown further down, is visible here as a fold
whose `.iter` stops short of `iter`.

## Racing

The two racing methods in finetune take the same grid the guide uses and
score every candidate on a few inner resamples first. From then on,
after each further resample, a candidate that is clearly worse than the
current best is dropped, so the fits that a full grid search would spend
on losing candidates are saved.
[`nested_tune_race_anova()`](https://nestedtune.tidymodels.org/reference/nested_tune_race.md)
decides with a repeated measures ANOVA fitted by `lme4`, and
[`nested_tune_race_win_loss()`](https://nestedtune.tidymodels.org/reference/nested_tune_race.md)
with a Bradley-Terry model of pairwise wins fitted by `BradleyTerry2`.

``` r

set.seed(3)

race <- nested_tune_race_anova(wf, folds, grid = grid)

race
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

A fold’s `.inner_metrics` from a race is the whole grid, and the `n`
column says how many inner resamples each candidate was scored on before
it was dropped or the race ended. The fold that spent the fewest fits is
the one where elimination did the most work:

``` r

fits <- vapply(
  race$.inner_metrics,
  function(m) sum(m$n[m$.metric == "rmse"]),
  numeric(1)
)
names(fits) <- race$id
fits
#> Fold1 Fold2 Fold3 Fold4 Fold5 
#>    30    30    23    29    30

cheapest <- which.min(fits)

race$.inner_metrics[[cheapest]]
#> # A tibble: 12 × 8
#>     mtry min_n .metric .estimator  mean     n std_err .config        
#>    <int> <int> <chr>   <chr>      <dbl> <int>   <dbl> <chr>          
#>  1     2     2 rmse    standard   2.37      4  0.393  pre0_mod1_post0
#>  2     2     2 rsq     standard   0.918     4  0.0270 pre0_mod1_post0
#>  3     2    10 rmse    standard   3.48      3  0.660  pre0_mod2_post0
#>  4     2    10 rsq     standard   0.887     3  0.0657 pre0_mod2_post0
#>  5     5     2 rmse    standard   2.23      5  0.327  pre0_mod3_post0
#>  6     5     2 rsq     standard   0.911     5  0.0218 pre0_mod3_post0
#>  7     5    10 rmse    standard   3.12      3  0.764  pre0_mod4_post0
#>  8     5    10 rsq     standard   0.896     3  0.0515 pre0_mod4_post0
#>  9     8     2 rmse    standard   2.27      5  0.313  pre0_mod5_post0
#> 10     8     2 rsq     standard   0.903     5  0.0253 pre0_mod5_post0
#> 11     8    10 rmse    standard   3.08      3  0.791  pre0_mod6_post0
#> 12     8    10 rsq     standard   0.893     3  0.0468 pre0_mod6_post0
```

In `Fold3`, 4 of the 6 candidates show `n` below the 5 inner resamples,
so they were dropped before the race ended, and the fold spent 23 fits
on tuning where the full grid costs 30.

The win/loss race records the same table, and reads the same way:

``` r

set.seed(4)

win_loss <- nested_tune_race_win_loss(wf, folds, grid = grid)

win_loss$.inner_metrics[[1]]
#> # A tibble: 12 × 8
#>     mtry min_n .metric .estimator  mean     n std_err .config        
#>    <int> <int> <chr>   <chr>      <dbl> <int>   <dbl> <chr>          
#>  1     2     2 rmse    standard   2.92      5  0.415  pre0_mod1_post0
#>  2     2     2 rsq     standard   0.806     5  0.0940 pre0_mod1_post0
#>  3     2    10 rmse    standard   3.15      5  0.559  pre0_mod2_post0
#>  4     2    10 rsq     standard   0.757     5  0.123  pre0_mod2_post0
#>  5     5     2 rmse    standard   2.84      5  0.453  pre0_mod3_post0
#>  6     5     2 rsq     standard   0.831     5  0.0907 pre0_mod3_post0
#>  7     5    10 rmse    standard   2.88      5  0.507  pre0_mod4_post0
#>  8     5    10 rsq     standard   0.800     5  0.113  pre0_mod4_post0
#>  9     8     2 rmse    standard   2.78      5  0.448  pre0_mod5_post0
#> 10     8     2 rsq     standard   0.836     5  0.0942 pre0_mod5_post0
#> 11     8    10 rmse    standard   2.86      5  0.493  pre0_mod6_post0
#> 12     8    10 rsq     standard   0.804     5  0.113  pre0_mod6_post0
```

## Simulated annealing

[`nested_tune_sim_anneal()`](https://nestedtune.tidymodels.org/reference/nested_tune_sim_anneal.md)
runs
[`finetune::tune_sim_anneal()`](https://finetune.tidymodels.org/reference/tune_sim_anneal.html)
inside each outer fold. Like the Bayesian search it proposes its own
candidates and needs the parameter set above, but each proposal is a
small random move from the current candidate, accepted when it scores
better and sometimes when it scores worse. finetune prints a log of
every move by default; the control passed below keeps the page quiet,
and is the first use here of the `...` that the next section describes.

``` r

set.seed(5)

anneal <- nested_tune_sim_anneal(
  wf,
  folds,
  param_info = params,
  initial = 3,
  iter = 3,
  control = finetune::control_sim_anneal(verbose_iter = FALSE)
)

anneal$.inner_metrics[[1]]
#> # A tibble: 12 × 9
#>     mtry min_n .metric .estimator  mean     n std_err .config     .iter
#>    <int> <int> <chr>   <chr>      <dbl> <int>   <dbl> <chr>       <int>
#>  1     2    10 rmse    standard   3.05      5  0.550  initial_pr…     0
#>  2     2    10 rsq     standard   0.777     5  0.119  initial_pr…     0
#>  3     5     2 rmse    standard   2.83      5  0.458  initial_pr…     0
#>  4     5     2 rsq     standard   0.842     5  0.0905 initial_pr…     0
#>  5     8     6 rmse    standard   2.82      5  0.465  initial_pr…     0
#>  6     8     6 rsq     standard   0.839     5  0.101  initial_pr…     0
#>  7     7     6 rmse    standard   2.89      5  0.474  Iter1           1
#>  8     7     6 rsq     standard   0.828     5  0.100  Iter1           1
#>  9     6     5 rmse    standard   2.82      5  0.482  Iter2           2
#> 10     6     5 rsq     standard   0.832     5  0.102  Iter2           2
#> 11     5     6 rmse    standard   2.82      5  0.475  Iter3           3
#> 12     5     6 rsq     standard   0.823     5  0.102  Iter3           3
```

`.iter` runs from 0, the initial candidates, to 3. Each fold scored 6
candidates on 5 inner resamples, 30 fits for tuning, the same as the
guide’s grid.

## Passing a control through `...`

None of the four drivers on this page has a `control` argument of its
own. A control object of the matching kind,
[`tune::control_bayes()`](https://tune.tidymodels.org/reference/control_bayes.html)
for the Bayesian driver,
[`finetune::control_race()`](https://finetune.tidymodels.org/reference/control_race.html)
and
[`finetune::control_sim_anneal()`](https://finetune.tidymodels.org/reference/control_sim_anneal.html)
for the others, is passed as `control` through `...`, and reaches the
inner tuning call in every fold. Here the Bayesian run is repeated under
a control that stops a fold’s search after three proposals in a row
bring no improvement.

``` r

set.seed(6)

stopped <- nested_tune_bayes(
  wf,
  folds,
  param_info = params,
  initial = 4,
  iter = 3,
  control = tune::control_bayes(verbose = FALSE, no_improve = 3)
)
#> ! No improvement for 3 iterations; returning current results.

procedure <- attr(stopped, "procedure")
procedure
#> $tuner
#> [1] "tune_bayes"
#> 
#> $iter
#> [1] 3
#> 
#> $initial
#> [1] 4
#> 
#> $objective
#> $trade_off
#> [1] 0
#> 
#> $eps
#> [1] 2.220446e-16
#> 
#> $label
#> [1] "the expected improvement"
#> 
#> attr(,"class")
#> [1] "exp_improve"          "acquisition_function"
#> 
#> $param_info
#> Collection of 2 parameters for tuning
#> 
#>  identifier  type    object
#>        mtry  mtry nparam[+]
#>       min_n min_n nparam[+]
#> 
#> 
#> $event_level
#> [1] "first"
#> 
#> $eval_time
#> NULL
#> 
#> $control
#> Bayes control object
#>   `verbose`: FALSE
#>   `verbose_iter`: FALSE
#>   `allow_par`: FALSE
#>   `no_improve`: 3
#>   `uncertain`: Inf
#>   `extract`: NULL
#>   `save_pred`: FALSE
#>   `time_limit`: NA
#>   `pkgs`: NULL
#>   `save_workflow`: FALSE
#>   `save_gp_scoring`: FALSE
#>   `event_level`: "first"
#>   `parallel_over`: NULL
#>   `backend_options`: NULL
#>   `workflow_size`: 100
```

The `procedure` attribute is the record of what ran, and a final fit
built from this result re-runs exactly that. Its `control` element is
the control as it took effect, not as it was passed. Two of its slots
are this package’s to set. `allow_par` is FALSE whatever the control
said, because parallelism belongs over the outer folds, and a second
pool inside each fold would contend with the first. `event_level` is set
once, by the driver’s own argument: a control left at tune’s default
takes that argument’s level, and a control naming a level that is
neither tune’s default nor the argument’s is refused at entry, naming
both. One slot is missing from the record. `seed` is dropped, because
the Bayesian search’s seed is the fold’s tuning seed, which the fold’s
own `.tuning_seed` column already holds, and the driver puts it back on
the control at the point the inner call is made.

## What differs from calling tune or finetune directly

Every statistical step is tune’s or finetune’s, and the driver adds the
loop around it. The differences a caller meets are these.

A control reaches the inner call through `...`, as above, with
`allow_par` forced off, `event_level` taken from the argument and the
Bayesian `seed` supplied by the fold. Everything else on the control
passes through as given, including the slots that stop a search early,
which is why one fold’s `.inner_metrics` can be shorter than another’s.

The search’s own settings are arguments here rather than control slots.
`iter`, `initial` and `objective` on the Bayesian driver, `iter` and
`initial` on annealing, and `grid` on the racers reach the inner call
unchanged, with one narrowing: `initial` is a count, and an earlier
tuning result, which tune and finetune both accept there, is refused.

What comes back from the inner call is its metrics table and its
selection, never the tuning object itself. `.inner_metrics` is that
table, the whole grid for a race, and `.selected` is the best candidate
by the first metric. So a control’s `extract`, `save_pred` and
`save_workflow` slots cost their work inside every fold and return
nothing on a nested run. The final fit keeps its tuning run whole, and
that is where those slots’ results are reachable. The annealing
control’s `save_history` slot writes finetune’s search history to a file
in the temporary directory of the process that tuned, each fold
overwriting the last, and nothing of it reaches the result or the final
fit.

The racing and annealing drivers refuse at entry when a package their
search needs is not installed, rather than one outer loop’s worth of
work later when finetune would ask for it, and the racers refuse a
`burn_in` that no fold’s inner design can meet before any fold runs.

Seeding is the guide’s contract on all four: seed the session before the
call, and each fold gets its own tuning and fitting seeds, all drawn
from that state at entry, so the same seed gives the same result
serially and in parallel. The help page of each driver gives the exact
hand-replication recipe for one fold.
