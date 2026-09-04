# What the estimate means

This page runs no code. It says what the number
[`collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
reports after a nested run is an estimate of, what it is not, how to
read the standard error beside it, why fold-to-fold disagreement is
expected, and when nesting is worth its cost. The worked example that
produces such a number is in
[`vignette("nested-cv")`](https://nestedtune.tidymodels.org/articles/nested-cv.md).

## Which quantity it is

Nested cross-validation puts the whole tune-and-fit procedure inside an
outer resampling loop. Each outer fold tunes on its own analysis rows,
fits the winner there, and scores it once on assessment rows that no
part of the tuning saw. The mean of those outer scores is the number to
report.

It estimates one specific quantity: the k-fold test error of the
tune-and-fit procedure (Bayle et al., 2026). That is the error of
resampling, tuning, selecting and fitting, the whole thing, on the
particular analysis sets these folds drew, then predicting fresh data
drawn like the training data. It is tied to the training sets this run
actually used.

Two quantities it is not, both easy to mistake it for.

- **Not the risk of the model you deploy.** That model is built
  afterwards on all the rows. Its own error is a different quantity with
  a different value, and nothing in a nested run estimates it. What the
  nested number buys you is the right to describe the procedure that
  produced that model.
- **Not the same quantity averaged over training sets.** The average,
  meaning how this procedure does across all datasets of this size
  rather than on the ones these folds happened to draw, is usually what
  a reader has in mind, and it is much harder to get. Luo and
  Barber (2026) prove that any assumption-free test of it needs a
  dataset many times larger than the training size being evaluated. A
  v-fold outer loop supplies a ratio of v to v - 1, which is not that.
  So this package reports the estimate and offers no test of it.

Two more things the estimate does not say, both easy to over-read.

- It is **marginal over selection, not conditional on any one
  configuration**. It describes what happens when you run the tuning
  procedure, including the fact that the procedure sometimes picks
  differently. It is not a claim about the particular parameter values
  your deployed model happens to carry.
- It describes **new data drawn like your training data**. It says
  nothing about a different population, or about the same procedure run
  at a different sample size.

## Expect it to run slightly pessimistic

The number tends to look a little worse than the procedure deserves. The
mechanism is training-set size. Every outer fold trains on its analysis
rows only, so every model scored is built on less data than the model
you finally deploy, and less data usually means worse predictions. That
is a tendency, not a guarantee. Varma and Simon (2006) separate this
training-size component, whose sign can go either way, from the
selection-driven component, which is always optimistic.

Two published measurements give a sense of the size. Varma and Simon
(2006) found a nested estimate of 54.2% against a true 50.0% on
deliberately null data with 40 samples, a 4.2-point overshoot they
attribute to training on 39 rows rather than 40. Wilimitis and Walsh
(2023), working on 41,121 hospital visits, found nested cross-validation
among the most pessimistic of the methods they compared, by roughly 1 to
2% of AUROC and 5 to 9% of AUPR against a held-out benchmark. On the
regression half of the same study, their nested mean absolute error came
in at 2.39 where the non-nested methods gave 2.38. Read those as two
data points rather than a trend. They differ in data, metric and
baseline, and the same study reports a cell where the nested estimate
came out optimistic instead.

Two cautions on reading that. The gap is a property of the estimator,
not a prediction about any one run. At a small sample size it is small
next to fold-to-fold noise, so one run’s numbers can land either way,
and no single run demonstrates it. And “pessimistic” is a claim about
the procedure’s error, never a licence to adjust the reported figure
upward. There is no correction here to apply.

## The standard error

`std_err` is the standard error of the mean across the outer folds: the
standard deviation of the fold scores divided by the square root of how
many there were. It is not the fold-to-fold spread, which is larger by
that same factor. Quoting `std_err` as though it described the folds
understates their disagreement. On a results object `res`, as
[`vignette("nested-cv")`](https://nestedtune.tidymodels.org/articles/nested-cv.md)
builds one, `collect_metrics(res, summarize = FALSE)` gives the per-fold
scores, and `autoplot(res, type = "performance")` draws them with a
dashed line at the mean.

It is also not a confidence interval. This package deliberately ships no
inference on the nested estimate.

That has a consequence for the obvious next thing to do with two of
these numbers. If you run the loop on two different workflows and one
comes back lower, nothing in the output tells you whether the difference
is real, because there is no valid interval here to subtract. Bayle et
al. (2026) give a second, sharper reason not to reach for one. The
stability condition that makes a single procedure’s cross-validation
interval valid can fail for the difference between two procedures even
when it holds for each of them separately, and it fails hardest when the
two are similar, which is exactly the case where you most want the
comparison. Treat a gap between two nested estimates as a reason to look
closer, never as a result.

## The number not to report

Any tuning run, the ones inside the outer folds and the one behind the
final model, carries resampling scores for every candidate it tried.
Those scores are what selection looked at, and the winner’s is the best
of a set scored on the very resamples that chose it. It therefore
carries an optimistic component of unknown size, and nothing in the
output says how large.

What it is not is reliably worse-looking. At a small sample size the
bias is small next to resampling noise, so a single comparison can land
either way. The structural argument is the reason to distrust the
number, not its sign. That is why the results object and the final fit
both refuse tune’s ranking generics such as `show_best()`: on the
results they would rank outer folds, which is not a ranking of anything
a user wants, and on the final fit they would surface the selection-time
scores dressed as a performance number.

## Why the folds disagree

Each outer fold’s inner tuning makes its own choice, and the results
object keeps every one of them. When the folds split over a parameter,
that parameter is one whose value the data does not pick clearly, so
whichever value your final model ends up carrying was not strongly
preferred by the evidence. That is not a defect in the estimate. The
outer scores already average over exactly this variability, which is
what makes them describe the procedure honestly. It is a defect in any
story you might tell about the selected parameters being the right ones.

Disagreement is the expected behaviour wherever the candidates in
question perform about equally well. Bayle et al. (2026) give the
mechanism. As two candidates’ predictions converge, the difference
between their losses loses variance faster than the noise in estimating
that difference does, so which of them wins any particular fold becomes
close to a coin flip. A run will often show both faces of this at once:
the folds split over one parameter, whose candidates the data cannot
separate, and agree on another, where they can.

## When this is worth the cost

Nesting is expensive, and it is not always worth it. What decides is how
much room the selection step had to overfit in the first place. If there
was little, there is little for the outer loop to remove.

**It removes most when the search is large relative to the data.**
Tibshirani and Tibshirani (2009) measured the optimism of a tuned
cross-validation score across two regimes and found it material only
when the features vastly outnumber the observations. Their phrase is p ≫
n, not merely p \> n. With 400 observations and 100 features, the worst
optimism they saw on pure noise was under 3 points. At 40 observations
and 1000 features a shrunken-centroid classifier’s own score read 0.384
where the truth was 0.5. Even there it depends on the learner: in that
same cell an SVM read 0.475 and a tree 0.498, both within 3 points of
the truth. Wide data, a big grid, and a preprocessing step that the loop
has to redo are where the money is. That paper’s own conclusion is not
to nest but to correct the flat score cheaply instead. It is cited here
for where the bias lives, not for its remedy.

**It removes little when the data is tall and the search is small.**
Wilimitis and Walsh (2023) ran exactly that case, 41,121 hospital visits
and a modest parameter grid, and nesting bought nothing. Its reported
score was fractionally more conservative than the flat methods they
compared it against, which is the pessimism above rather than a
correction, and it cost time that grew quadratically in the fold count.
They are explicit about why: with far more observations than features
and a small search, there was almost no selection bias present to
remove. Their recommendation, and this package’s, is to nest when the
feature space is wide relative to the sample, when many algorithms and
parameters are in play, and when the compute is affordable.

**Do not read that as “small data is fine without it”.** Vabalas et
al. (2019) simulated pure noise, where the honest accuracy is 50%, and
found flat cross-validation still reporting better than chance at a
sample size of 1000, while nested cross-validation was indistinguishable
from chance at 96.5% of the sample sizes they tested. The bias thins
with sample size. It does not conveniently disappear.

## Feature selection must go inside the workflow

One caveat about this package’s own scope, from the same paper. Vabalas
et al. (2019) compared leaving feature selection outside the loop
against leaving parameter tuning outside it, and the first was far more
damaging. Nesting the tuning alone did not rescue the estimate. This
package orchestrates tuning, so if your pipeline selects features, put
that step in the `recipe` inside the `workflow` you hand it. Everything
in the workflow is re-estimated inside every fold. Anything you did to
the data before calling this package is not, and no result here can tell
you that happened.

## References

Bayle, A., Janson, L., & Mackey, L. (2026). The relative instability of
model comparison with cross-validation. *arXiv:2508.04409*.

Luo, Y., & Barber, R. F. (2026). The limits of assumption-free tests for
algorithm performance. *Bernoulli*, 32(3), 2427–2450.

Tibshirani, R. J., & Tibshirani, R. (2009). A bias correction for the
minimum error rate in cross-validation. *The Annals of Applied
Statistics*, 3(2), 822–829.

Vabalas, A., Gowen, E., Poliakoff, E., & Casson, A. J. (2019). Machine
learning algorithm validation with a limited sample size. *PLoS ONE*,
14(11), e0224365.

Varma, S., & Simon, R. (2006). Bias in error estimation when using
cross-validation for model selection. *BMC Bioinformatics*, 7, 91.

Wilimitis, D., & Walsh, C. G. (2023). Practical considerations and
applied examples of cross-validation for model development and
evaluation in health care: Tutorial. *JMIR AI*, 2, e49023.
