# Fixtures and the reference loop for the orchestration oracles.
#
# Data is generated here rather than committed, so this file *is* the generator
# the profile's fixture-provenance rule asks for: source and seed are visible.

make_reg_data <- function(n = 90, seed = 4242) {
  set.seed(seed)
  d <- data.frame(
    x1 = rnorm(n),
    x2 = rnorm(n),
    x3 = rnorm(n),
    x4 = rnorm(n)
  )
  d$y <- 2 * d$x1 - d$x2 + 0.5 * d$x3 + rnorm(n)
  d
}

# The deterministic engine: a tunable recipe step ahead of an lm model. Nothing
# on this path touches the RNG, which is what lets AC3's fit_resamples()
# invariant be an exact equality rather than a seed-contingent one (D-013).
det_workflow <- function(data) {
  rec <- recipes::step_pca(
    recipes::recipe(y ~ x1 + x2 + x3 + x4, data = data),
    recipes::all_predictors(),
    num_comp = tune::tune()
  )
  workflows::workflow(rec, parsnip::linear_reg())
}

det_grid <- function() data.frame(num_comp = 1:3)

# The stochastic engine. ranger draws its seed from R's RNG and runs
# single-threaded here, so a fold's fit is reproducible iff our seeding is
# (RR01 Q8: with a deterministic engine every RNG test passes vacuously).
stoch_workflow <- function(data) {
  spec <- parsnip::set_mode(
    parsnip::set_engine(
      parsnip::rand_forest(min_n = tune::tune(), trees = 25),
      "ranger",
      num.threads = 1
    ),
    "regression"
  )
  workflows::workflow(y ~ x1 + x2 + x3 + x4, spec)
}

stoch_grid <- function() data.frame(min_n = c(2L, 10L, 25L))

reg_metrics <- function() {
  yardstick::metric_set(yardstick::rmse, yardstick::rsq)
}

# The hand-rolled reference loop (AC2/AC16). Deliberately written from the
# documented seed contract -- `set.seed(s)` then one
# `sample.int(.Machine$integer.max, 2 * n_folds)`, fold i taking elements
# 2i-1 and 2i -- and never from the driver's output, so a driver that
# misassigns seeds *and* misreports the assignment consistently still fails.
reference_nested_loop <- function(wf, nested, grid, metrics, seed, metric_name) {
  set.seed(seed)
  n <- nrow(nested)
  seeds <- sample.int(.Machine$integer.max, 2L * n)

  lapply(seq_len(n), function(i) {
    tuning_seed <- seeds[[2L * i - 1L]]
    outer_seed <- seeds[[2L * i]]

    set.seed(tuning_seed, kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    tuned <- tune::tune_grid(
      wf,
      resamples = nested$inner_resamples[[i]],
      grid = grid,
      metrics = metrics,
      control = tune::control_grid(allow_par = FALSE)
    )
    best <- tune::select_best(tuned, metric = metric_name)
    final_wf <- tune::finalize_workflow(wf, best)

    set.seed(outer_seed, kind = "Mersenne-Twister",
             normal.kind = "Inversion", sample.kind = "Rejection")
    fitted <- tune::last_fit(final_wf, split = nested$splits[[i]],
                             metrics = metrics)

    list(
      metrics = tune::collect_metrics(fitted),
      selected = best,
      tuning_seed = tuning_seed,
      outer_fit_seed = outer_seed
    )
  })
}

# The hand-rolled reference final fit (AC2/AC9).
#
# Written from the documented contract, never from the object: its own
# `set.seed(s)` and its own `sample.int(.Machine$integer.max, 2)`, its own inner
# rset built under the first of those seeds, and the inner specification spelled
# out here rather than read off the design. Nothing is taken from what
# nested_final_fit() returned, so a function that misassigns its seeds *and*
# reports the assignment consistently still fails.
#
# The rset is built after the tuning seed is set, which is the ordering D-016
# fixed: building an rset draws from the RNG, so a reference that built it
# earlier would disagree with a correct implementation.
reference_final_fit <- function(wf, data, grid, metrics, seed, metric_name,
                                v = 3) {
  set.seed(seed)
  seeds <- sample.int(.Machine$integer.max, 2L)

  set.seed(seeds[[1L]], kind = "Mersenne-Twister",
           normal.kind = "Inversion", sample.kind = "Rejection")
  inner <- rsample::vfold_cv(data, v = v)
  tuned <- tune::tune_grid(
    wf,
    resamples = inner,
    grid = grid,
    metrics = metrics,
    control = tune::control_grid(allow_par = FALSE, save_workflow = TRUE)
  )
  best <- tune::select_best(tuned, metric = metric_name)
  final_wf <- tune::finalize_workflow(wf, best)

  set.seed(seeds[[2L]], kind = "Mersenne-Twister",
           normal.kind = "Inversion", sample.kind = "Rejection")
  fitted <- parsnip::fit(final_wf, data = data)

  list(seeds = seeds, selected = best, workflow = fitted, tuned = tuned)
}

ref_field <- function(ref, field) {
  vapply(ref, function(x) x[[field]], integer(1))
}

# One outer fold engineered to fail, at a stage of our choosing (M03).
#
# The failure is injected into the *design*, not the workflow: the named fold's
# inner rset -- or its outer split -- is rebuilt on a frame the recipe cannot
# prep, so that fold fails at that stage while its neighbours run untouched.
# Keyed to fold position rather than to a counter, so it stays deterministic
# however the loop is scheduled.
foreign_frame <- function(n = 30, seed = 909) {
  set.seed(seed)
  data.frame(z = rnorm(n), w = rnorm(n))
}

break_fold <- function(nested, fold, stage = c("inner tuning", "outer fit")) {
  stage <- match.arg(stage)
  foreign <- rsample::vfold_cv(foreign_frame(), v = 3)
  if (stage == "inner tuning") {
    nested$inner_resamples[[fold]] <- foreign
  } else {
    nested$splits[[fold]] <- foreign$splits[[1L]]
  }
  nested
}

# One inner split of one outer fold, rebuilt on a foreign frame. That inner
# resample fails while the rest of the fold's inner design survives, so tuning
# still yields a candidate and the fold completes -- on a truncated inner design
# that tune recorded notes about.
break_inner_split <- function(nested, fold, split = 1L) {
  foreign <- rsample::vfold_cv(foreign_frame(), v = 3)
  nested$inner_resamples[[fold]]$splits[[split]] <- foreign$splits[[1L]]
  nested
}

# The two stages fail differently, and the difference is the point: inner
# tuning raises ("All models failed") while the outer fit stays silent and
# hands back NULL metrics. Both are failures; only one of them says so.
det_nested <- function(data, v = 3, seed = 11) {
  set.seed(seed)
  nested_resamples(
    data,
    outside = rsample::vfold_cv(v = v),
    inside = rsample::vfold_cv(v = v)
  )
}

# A design whose inner specification is written with literal arguments, so it
# survives re-evaluation when the final fit re-runs it (M05).
#
# det_nested() above deliberately does not: its `v` is a parameter of the helper
# and is gone by the time nested_final_fit() evaluates the stored call. That is
# the hazard RR02 named as B1 and test-nested-final-fit-checks.R pins, and it is
# why the documentation asks for literals -- a design built inside any function
# that parameterizes its resampling has the same problem.
final_nested <- function(data, seed = 11) {
  set.seed(seed)
  nested_resamples(
    data,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 3)
  )
}

# A design whose outer folds genuinely disagree about the best candidate (M04).
#
# The disagreement is earned rather than staged: y depends on x1 alone and the
# other five predictors are noise, so how many principal components help is a
# question each outer fold answers from its own data. The path is still PCA and
# lm, so it stays deterministic -- the same seeds give the same disagreement.
unstable_data <- function(n = 60, seed = 7, k = 6, noise = 3) {
  set.seed(seed)
  d <- as.data.frame(matrix(rnorm(n * k), nrow = n, ncol = k))
  names(d) <- paste0("x", seq_len(k))
  d$y <- 2 * d$x1 + noise * rnorm(n)
  d
}

unstable_workflow <- function(data) {
  rec <- recipes::step_pca(
    recipes::recipe(y ~ ., data = data),
    recipes::all_predictors(),
    num_comp = tune::tune()
  )
  workflows::workflow(rec, parsnip::linear_reg())
}

unstable_grid <- function() data.frame(num_comp = 1:4)

# Every outer fold broken, for the run that has nothing to report at all.
break_every_fold <- function(nested, stage = "inner tuning") {
  for (i in seq_len(nrow(nested))) {
    nested <- break_fold(nested, i, stage)
  }
  nested
}

# Printed output as one string, at a width wide enough that cli's wrapping does
# not decide whether an assertion matches. The snapshots set their own width
# through testthat, so they are unaffected by this.
#
# cli::cli_fmt() rather than capture.output(): cli deliberately writes to stderr
# whenever a sink is active on stdout, so capture.output() around a cli-based
# print method captures nothing at all and every assertion on it passes or
# fails for the wrong reason.
print_text <- function(x, width = 200) {
  op <- options(width = width, cli.width = width)
  on.exit(options(op), add = TRUE)
  paste(cli::cli_fmt(print(x)), collapse = "\n")
}

skip_if_no_engines <- function(stochastic = FALSE) {
  testthat::skip_if_not_installed("recipes")
  testthat::skip_if_not_installed("yardstick")
  if (stochastic) testthat::skip_if_not_installed("ranger")
}
