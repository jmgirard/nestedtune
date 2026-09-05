# Why nest: a simulation

A tuning run reports a score for its winner. That score is the best of
many resampling estimates, each noisy, and picking the best of a noisy
set biases it upward. Nested cross-validation exists to remove that
bias: each outer fold tunes on its own analysis rows and scores the
winner on rows the tuning never saw.
[`vignette("estimate")`](https://nestedtune.tidymodels.org/articles/estimate.md)
explains the argument. This page shows the size of the effect on data
where the true answer is known.

The design follows Varma and Simon (2006). Draw data with no signal at
all, so that every classifier has the same true accuracy, then tune a
learner on it and compare what the tuning run’s best score says against
what the nested estimate says. Repeat over fresh draws, and read the two
distributions.

## What this page reads

Every replicate fits hundreds of small neural networks, so the page does
not run the simulation. It reads a stored result that the script
`vignettes/articles/why-nest-sim.R` in the package repository produces,
and every number below is read from that object. The script’s header
says how to regenerate it.

``` r

sim <- readRDS("why-nest.rds")
names(sim)
#>  [1] "n"             "p"             "grid"          "epochs"       
#>  [5] "max_nwts"      "v_outer"       "v_inner"       "replicates"   
#>  [9] "seed"          "rng_kind"      "null_accuracy" "tolerance"    
#> [13] "results"       "script"        "commit"        "date"
```

## The design

Each replicate draws 60 rows of 200 independent standard normal features
and a label that is a fair coin toss, independent of every feature.
Nothing in the features predicts the label, so any classifier’s true
accuracy is 0.5, whatever its parameters. Features outnumber rows by 3.3
to one, a smaller version of the wide null data Varma and Simon (2006)
simulate.

The learner is a single-layer neural network,
[`parsnip::mlp()`](https://parsnip.tidymodels.org/reference/mlp.html) on
the nnet engine, with `hidden_units` and `penalty` marked for tuning and
`epochs` fixed at 50. The grid holds 20 candidates:

``` r

sim$grid
#>    hidden_units penalty
#> 1             1   0e+00
#> 2             2   0e+00
#> 3             4   0e+00
#> 4             8   0e+00
#> 5             1   1e-04
#> 6             2   1e-04
#> 7             4   1e-04
#> 8             8   1e-04
#> 9             1   1e-03
#> 10            2   1e-03
#> 11            4   1e-03
#> 12            8   1e-03
#> 13            1   1e-02
#> 14            2   1e-02
#> 15            4   1e-02
#> 16            8   1e-02
#> 17            1   1e-01
#> 18            2   1e-01
#> 19            4   1e-01
#> 20            8   1e-01
```

The same workflow is tuned twice on each replicate’s data.

- The **flat run** is
  [`tune::tune_grid()`](https://tune.tidymodels.org/reference/tune_grid.html)
  over 5-fold cross-validation of all the rows. Its winner’s mean
  accuracy across the folds is the number a tuning run shows first, the
  figure a reader who stops there would report.
- The **nested run** is
  [`nested_tune_grid()`](https://nestedtune.tidymodels.org/reference/nested_tune_grid.md)
  over 5 outer folds, each tuning on 5 inner folds of its own analysis
  rows. Its estimate is the mean accuracy of each outer fold’s winner on
  that fold’s assessment rows.

Both see the same grid and the same rows, each run drawing its own fold
assignment. What differs is whether the rows that score the winner took
part in choosing it.

| setting              |    value |
|:---------------------|---------:|
| rows                 |       60 |
| features             |      200 |
| candidates           |       20 |
| epochs               |       50 |
| weight cap (MaxNWts) |     5000 |
| outer folds          |        5 |
| inner folds          |        5 |
| replicates           |       30 |
| seed                 | 20260905 |

## The result

The store holds one row per replicate, with the flat run’s best score
and the nested estimate side by side.

``` r

head(sim$results)
#>   replicate       seed flat_best nested_estimate
#> 1         1 1129449015 0.5166667       0.5333333
#> 2         2 2057056562 0.5500000       0.4000000
#> 3         3  414777423 0.7333333       0.6500000
#> 4         4 1405518975 0.5000000       0.3500000
#> 5         5  508739655 0.5333333       0.4833333
#> 6         6 1633271623 0.6333333       0.4333333
```

``` r

flat_median <- median(sim$results$flat_best)
nested_median <- median(sim$results$nested_estimate)
c(flat = flat_median, nested = nested_median)
#>      flat    nested 
#> 0.5666667 0.4583333
```

Over 30 replicates the median of the flat run’s best score is 0.567,
against a true accuracy of 0.5. The median nested estimate is 0.458. The
flat number sits 0.067 above the truth on data that carries no signal.
The nested number sits 0.042 below it, inside the tolerance of 0.05 the
store carries.

``` r

library(ggplot2)

long <- rbind(
  data.frame(
    quantity = "Flat run: best candidate's CV accuracy",
    accuracy = sim$results$flat_best
  ),
  data.frame(
    quantity = "Nested estimate",
    accuracy = sim$results$nested_estimate
  )
)
long$quantity <- factor(long$quantity, levels = unique(long$quantity))

ggplot(long, aes(x = quantity, y = accuracy)) +
  geom_hline(yintercept = sim$null_accuracy, linetype = "dashed") +
  geom_point(
    position = position_jitter(width = 0.15, height = 0, seed = sim$seed),
    alpha = 0.6
  ) +
  stat_summary(
    fun = median, fun.min = median, fun.max = median,
    geom = "crossbar", width = 0.4, linewidth = 0.6
  ) +
  labs(
    x = NULL,
    y = "Accuracy",
    title = "Accuracy on data with no signal",
    subtitle = sprintf(
      "%d replicates; bars at the median; dashed line at the true accuracy of %s",
      sim$replicates, format(sim$null_accuracy)
    )
  ) +
  theme_minimal()
```

![One panel with two columns of points, one per replicate: the flat
run's best accuracy on the left and the nested estimate on the right,
each column with a horizontal bar at its median, and a dashed line
across the panel at the true accuracy of one half. The left column sits
above the line and the right column straddles
it.](why-nest_files/figure-html/figure-1.png)

Each point is one replicate. Both quantities vary from draw to draw,
with a standard deviation of 0.066 for the flat run’s best score and
0.088 for the nested estimate. Of the 30 replicates, the flat run’s best
score is above the truth on 25, at it on 3 and below it on 2; the nested
estimate is above the truth on 11, at it on 1 and below it on 18.

The nested median sits a little below the truth rather than on it. The
design gives no reason to expect that: every label is an independent
coin toss, so whatever a fold’s network predicts, the rows it is scored
on agree with it half the time in expectation, and the nested estimate’s
expectation is the null accuracy. The mean nested estimate over the
replicates is 0.485, 0.015 below the truth against a standard error of
0.016. The median is the summary the page holds to its tolerance, and on
this many replicates it lands where the draws put it.

## Why the flat number is high

Varma and Simon (2006) give the mechanism. The flat run scores every
candidate on the same folds and reports the maximum. Each of those
scores is an unbiased estimate of an accuracy that, on this data, is the
same for every candidate. The maximum of a set of noisy estimates of one
value is not an unbiased estimate of that value; it is biased upward,
and more so the larger the set. For candidates whose estimates are
independent, their expression for the probability that the minimum error
over the grid falls below the truth is one minus one half to the power
of the grid size, so the chance that it does not is one half to that
power, for this page’s 20 candidates one in 1,048,576. Here the
candidates are scored on the same folds, so their estimates are not
independent and that figure overstates the case, but the direction is
the same. The best candidate’s score describes how lucky the search was,
not how good the winner is.

The nested run’s outer folds are not part of that search. Each fold’s
winner is chosen on the inner folds and then scored once on rows the
search never touched, so the score has no maximum taken over it. Its
expectation is the true accuracy of the whole tune-and-fit procedure,
which here is the null accuracy. That is the argument
[`vignette("estimate")`](https://nestedtune.tidymodels.org/articles/estimate.md)
makes, and the figure above is what it looks like on data where the
truth is known.

## What this page does not show

This is one learner on one design. The size of the gap depends on how
many candidates the search compares, how noisy each candidate’s
resampling score is, and how much the candidates’ true accuracies
actually differ. A grid whose candidates fit the data very differently,
or a learner whose tuning parameters barely change its fit, would show a
different gap, and on data with real signal the flat number is high for
the same reason but the truth is no longer known. Varma and Simon (2006)
report the same design with two other learners and much wider data, and
Ambroise and McLachlan (2002) reach a matching conclusion for feature
selection rather than tuning, from labels permuted rather than drawn at
random.

The nested estimate is not free of every bias. Each outer fold’s winner
is fit on fewer rows than the model you would deploy, so on data with
signal the nested number runs slightly pessimistic.
[`vignette("estimate")`](https://nestedtune.tidymodels.org/articles/estimate.md)
sizes that. On this page every label is an independent coin toss, so a
training set of any size has the same true accuracy and the nested mean
sits within a standard error of the truth. Varma and Simon (2006), whose
null data fixes twenty rows per class, report a nested estimate 4.2
points pessimistic on it.

## Provenance

The stored result was produced by `vignettes/articles/why-nest-sim.R` at
commit 686e14687935eea8bfb304686c8c9258f47ffb18 on 2026-09-05, from seed
20260905 under the Mersenne-Twister generator. The commit is one on the
branch that added this page, reachable through that pull request’s
history. On one machine and one set of package versions, the script
writes the same object from the same seed apart from those two
provenance fields; other versions of R or of the fitting packages may
not reproduce the fits. The tolerance the store carries, 0.05, is the
distance from the null accuracy inside which the nested median is held
when the result is regenerated.

## References

Ambroise, C., & McLachlan, G. J. (2002). Selection bias in gene
extraction on the basis of microarray gene-expression data. *Proceedings
of the National Academy of Sciences*, 99(10), 6562–6566.

Varma, S., & Simon, R. (2006). Bias in error estimation when using
cross-validation for model selection. *BMC Bioinformatics*, 7, 91.
