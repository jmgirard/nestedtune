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

# A continuous tunable, for the cases where an integer grid has to be expanded
# (M21). `num_comp` reaches only as many values as there are predictors, so its
# expansion is a small fixed set and any two runs agree trivially; `threshold`
# is continuous, which is where tune's space-filling expansion has choices to
# make -- and where two runs under different seeds were measured to disagree.
cont_workflow <- function(data) {
  rec <- recipes::step_pca(
    recipes::recipe(y ~ x1 + x2 + x3 + x4, data = data),
    recipes::all_predictors(),
    threshold = tune::tune()
  )
  workflows::workflow(rec, parsnip::linear_reg())
}

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
reference_nested_loop <- function(
  wf,
  nested,
  grid,
  metrics,
  seed,
  metric_name
) {
  set.seed(seed)
  n <- nrow(nested)
  seeds <- sample.int(.Machine$integer.max, 2L * n)

  lapply(seq_len(n), function(i) {
    tuning_seed <- seeds[[2L * i - 1L]]
    outer_seed <- seeds[[2L * i]]

    set.seed(
      tuning_seed,
      kind = "Mersenne-Twister",
      normal.kind = "Inversion",
      sample.kind = "Rejection"
    )
    tuned <- tune::tune_grid(
      wf,
      resamples = nested$inner_resamples[[i]],
      grid = grid,
      metrics = metrics,
      control = tune::control_grid(allow_par = FALSE)
    )
    best <- tune::select_best(tuned, metric = metric_name)
    final_wf <- tune::finalize_workflow(wf, best)

    set.seed(
      outer_seed,
      kind = "Mersenne-Twister",
      normal.kind = "Inversion",
      sample.kind = "Rejection"
    )
    fitted <- tune::last_fit(
      final_wf,
      split = nested$splits[[i]],
      metrics = metrics
    )

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
reference_final_fit <- function(
  wf,
  data,
  grid,
  metrics,
  seed,
  metric_name,
  v = 3
) {
  set.seed(seed)
  seeds <- sample.int(.Machine$integer.max, 2L)

  set.seed(
    seeds[[1L]],
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
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

  set.seed(
    seeds[[2L]],
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
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

# A fixture on which the caller's metric set and tune's default disagree (M18).
#
# reg_metrics() is `metric_set(rmse, rsq)`, which IS tune's regression default,
# so every test passing it asserts nothing about `metrics` reaching tune: drop
# the argument anywhere and the run is identical. This fixture exists to make
# that argument observable, and it needs two properties at once.
#
# The metric names must differ from the default's, so the outer `.metrics` from
# last_fit() changes -- hence `mae`, which is not in `metric_set(rmse, rsq)`.
# And the *selection* must differ, so `.selected` changes when the inner
# tune_grid() loses the argument and select_best() falls back to resolving
# `rmse` off the tuned object. That second property is not free: on
# make_reg_data() every candidate metric picks the same number of components,
# which is exactly why the shared fixture cannot do this job.
#
# Heavy-tailed noise is what earns it. mae is robust to outliers and rmse is
# not, so the two rank candidates differently once the residuals stop being
# Gaussian. The (data seed, design seed) pair below was found by searching that
# space at the OUTER-FOLD level -- a whole-data proxy reports separation the
# nested design does not have -- and separates in all three outer folds.
#
# The model path is RNG-free (PCA and lm), but the fixture itself is not: the
# all-three-folds separation is a property of one seed pair under one generator
# triple, and a bare set.seed() pins only the uniform generator. Measured at
# M18 review: under `normal.kind = "Box-Muller"` separation falls to 1 of 3
# folds, and under `RNGkind("L'Ecuyer-CMRG")` or `sample.kind = "Rounding"` to
# 0 of 3 -- so an ambient kind left set by another file would make the metric
# tests fail for a reason that has nothing to do with `metrics`. Both helpers
# therefore pin the full triple the way reference_nested_loop() does, and
# restore the caller's kinds so the pin does not leak into the next test.
sep_data <- function(n = 80, seed = 10, k = 6, df = 1.2) {
  old <- RNGkind()
  on.exit(RNGkind(old[[1L]], old[[2L]], old[[3L]]), add = TRUE)
  set.seed(
    seed,
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  d <- as.data.frame(matrix(rnorm(n * k), nrow = n, ncol = k))
  names(d) <- paste0("x", seq_len(k))
  d$y <- 2 * d$x1 - d$x2 + rt(n, df = df) * 3
  d
}

# A wrapper, not an alias: `sep_workflow <- unstable_workflow` would make the
# two fixtures the same object, so neither could change without silently
# changing the other's callers.
sep_workflow <- function(data) unstable_workflow(data)

sep_grid <- function() data.frame(num_comp = 1:5)

sep_metrics <- function() {
  yardstick::metric_set(yardstick::mae, yardstick::rmse)
}

# Literal arguments, so nested_final_fit() can re-evaluate the stored call.
sep_nested <- function(data, seed = 21) {
  old <- RNGkind()
  on.exit(RNGkind(old[[1L]], old[[2L]], old[[3L]]), add = TRUE)
  set.seed(
    seed,
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  nested_resamples(
    data,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )
}

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

# A results object narrowed to some of its folds, still carrying the class.
#
# `[` used to build this and no longer does: since M36 a row subset returns a
# bare tibble, which is the whole point of that milestone. The tests that need
# such an object are about something else -- how print() words one fold versus
# several, what collect_metrics() does when no fold in hand completed -- and
# still need a way to reach the shape. This stamps the record the constructor
# would have written for a run of exactly those folds, and deliberately leaves
# `outer_label` off, since the folds kept are not the design that names.
as_fold_subset <- function(x, i) {
  out <- x[i, ]
  attr(out, "grid") <- attr(x, "grid")
  attr(out, "metrics") <- attr(x, "metrics")
  attr(out, "folds_attempted") <- nrow(out)
  attr(out, "folds_completed") <- sum(out$.completed)
  class(out) <- c("nested_results", class(out))
  out
}

# The two-class fixture (M35).
#
# `event_level` names a factor level, so nothing in the regression fixtures
# above can exercise it. Three things this one has to get right.
#
# The outcome is deliberately imbalanced, 32 events against 88, with the event
# the FIRST level -- so `event_level = "first"` is the interesting case rather
# than a formality, and so sensitivity and specificity separate. At a 50/50
# outcome a symmetric classifier scores them close together and the difference
# clauses AC2 and AC4 rest on would be measuring noise.
#
# Both the outer and the inner splits are stratified on the outcome. With 32
# events across three folds each assessment set holds ten or eleven of them, so
# no assessment set is single-class -- which is what sensitivity being NA would
# otherwise mean, and what would take `select_best()` down with it. 32/88 at
# v = 3 is also above rsample's pooling threshold, so stratifying here raises
# no warning.
#
# The metric set leads with `roc_auc`. `select_best()` resolves its metric from
# the tuned object's first metric name, and `roc_auc` returns byte-identical
# values at the two event levels -- so selection is level-invariant and the two
# runs score the same candidate, which is what makes AC3's swap an identity
# rather than a comparison of two different models.
cls_data <- function(n = 120, seed = 3535) {
  old <- RNGkind()
  on.exit(RNGkind(old[[1L]], old[[2L]], old[[3L]]), add = TRUE)
  set.seed(
    seed,
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  d <- data.frame(
    x1 = rnorm(n),
    x2 = rnorm(n),
    x3 = rnorm(n),
    x4 = rnorm(n)
  )
  # The -0.9 intercept is what makes the event the minority class.
  p <- stats::plogis(1.1 * d$x1 - 0.8 * d$x2 + 0.4 * d$x3 - 0.9)
  d$y <- factor(
    ifelse(runif(n) < p, "event", "other"),
    levels = c("event", "other")
  )
  d
}

# ranger, not a deterministic engine: the outer fit has to be reproducible from
# its recorded seed for AC2 to refit it, and with a deterministic engine that
# would pass whatever the seeding did (RR01 Q8).
cls_workflow <- function(data) {
  spec <- parsnip::set_mode(
    parsnip::set_engine(
      parsnip::rand_forest(min_n = tune::tune(), trees = 25),
      "ranger",
      num.threads = 1
    ),
    "classification"
  )
  workflows::workflow(y ~ x1 + x2 + x3 + x4, spec)
}

cls_grid <- function() data.frame(min_n = c(2L, 10L, 25L))

cls_metrics <- function() {
  yardstick::metric_set(yardstick::roc_auc, yardstick::sens, yardstick::spec)
}

# Literal arguments, so nested_final_fit() can re-evaluate the stored call.
cls_nested <- function(data, seed = 35) {
  old <- RNGkind()
  on.exit(RNGkind(old[[1L]], old[[2L]], old[[3L]]), add = TRUE)
  set.seed(
    seed,
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  nested_resamples(
    data,
    outside = rsample::vfold_cv(v = 3, strata = y),
    inside = rsample::vfold_cv(v = 3, strata = y)
  )
}

# The class-presence guard. Returns the levels missing from each assessment
# set, so a failure names which split rather than reporting a count.
missing_assessment_levels <- function(rset, levels = c("event", "other")) {
  vapply(
    rset$splits,
    function(sp) {
      paste(
        setdiff(levels, as.character(unique(rsample::assessment(sp)$y))),
        collapse = ","
      )
    },
    character(1)
  )
}

# Every rset a run of this fixture will score against: the outer assessment
# sets, and the inner rset of each outer fold. The rset `nested_final_fit()`
# builds from the full data is not reachable from the design -- it is drawn
# under the tuning seed the run records -- so the final-fit test checks that
# one where it reconstructs it.
cls_design_rsets <- function(nested) {
  c(list(nested), as.list(nested$inner_resamples))
}

skip_if_no_engines <- function(stochastic = FALSE) {
  testthat::skip_if_not_installed("recipes")
  testthat::skip_if_not_installed("yardstick")
  if (stochastic) testthat::skip_if_not_installed("ranger")
}

# The suite-level fixture cache (M12).
#
# Most of this suite's runtime went on building the same tuning run over and
# over -- one file alone asked for a byte-identical `nested_tune_grid()` result
# seventeen times. `memoised()` wraps such a call so the run is built once per
# suite run and every later request for the same run is served from the cache.
# Nothing about what a test asserts changes; only how many times the fit happens.
#
# "The same run" means the whole of it. The key is a hash of the canonical form
# (below) of every argument the call passes, plus the RNG state in force once
# those arguments have been forced -- which is exactly the state the orchestrator
# itself will snapshot, because `nested_tune_grid()` and `nested_final_fit()`
# both force every argument in their `check_*()` calls before they touch the
# RNG. Change the workflow, the design, the grid, the metrics or the seed and
# the key changes with it.
#
# Do NOT wrap a call made under `local_mocked_bindings()`: the mock is not in
# the key, so a value built under a mock would then be served to an unmocked
# request. test-nested-tune-grid-leakage.R calls the orchestrator directly for
# exactly that reason.

# The canonical form of a value: what it *is*, with environments read for their
# contents rather than their identity.
#
# `rlang::hash()` on its own cannot key this cache. Two identically-constructed
# workflows serialize to different bytes, and so do two `metric_set()` calls: a
# recipe's `terms` quosures capture the frame that built the recipe, and that
# frame holds the recipe itself, while `metric_set()`'s closure environment
# refers to itself the same way. Serialization resolves those cycles by
# reference, and the reference numbering does not survive re-construction.
#
# So environments are expanded by their contents, sorted so that binding order
# cannot enter; a named environment -- a namespace, the global environment --
# stands for its name, since its contents are not what distinguishes one fixture
# from another; and a cycle is cut the second time it is reached. Everything
# else keeps its value and its attributes, which is what keeps the form
# discriminating rather than merely stable. test-fixture-cache.R pins that: it
# asserts every distinct fixture signature in this suite keys differently.
canonical_form <- function(x, depth = 0L, seen = list()) {
  if (depth > 40L) {
    return("<depth>")
  }
  if (is.environment(x)) {
    for (e in seen) {
      if (identical(e, x)) return("<cycle>")
    }
    nm <- environmentName(x)
    if (nzchar(nm)) {
      return(list("<env>", nm))
    }
    seen <- c(seen, list(x))
    vars <- sort(ls(x, all.names = TRUE))
    vals <- lapply(vars, function(v) {
      canonical_form(get(v, envir = x, inherits = FALSE), depth + 1L, seen)
    })
    return(list("<env>", vars, vals))
  }
  if (is.null(x)) {
    return("<null>")
  }
  # The empty symbol standing for a missing argument default: `lapply()` over
  # `formals()` would otherwise try to evaluate it and fail.
  if (is.name(x) && !nzchar(as.character(x))) {
    return("<missing>")
  }
  attrs <- attributes(x)
  canonical_attrs <- if (is.null(attrs)) {
    NULL
  } else {
    lapply(attrs, canonical_form, depth = depth + 1L, seen = seen)
  }
  core <- if (is.function(x)) {
    if (is.primitive(x)) {
      list("<primitive>", format(x))
    } else {
      list(
        "<closure>",
        canonical_form(as.list(formals(x)), depth + 1L, seen),
        body(x),
        canonical_form(environment(x), depth + 1L, seen)
      )
    }
  } else {
    attributes(x) <- NULL
    if (is.list(x) || is.pairlist(x)) {
      lapply(x, canonical_form, depth = depth + 1L, seen = seen)
    } else {
      x
    }
  }
  if (is.null(canonical_attrs)) core else list(core, canonical_attrs)
}

fixture_cache <- new.env(parent = emptyenv())

fixture_cache_reset <- function() {
  rm(list = ls(fixture_cache, all.names = TRUE), envir = fixture_cache)
  invisible(NULL)
}

# Drop every entry whose call matches `pattern`, returning how many went.
#
# The cache outlives the file that filled it, which is the whole point, and it
# is also why test-fixture-cache.R has to tidy up: its stand-in builders are not
# fixtures anyone else wants, and one of them is a fixture built twice on
# purpose. Left in place they would surface in the run-wide report as findings.
fixture_cache_forget <- function(pattern) {
  keys <- ls(fixture_cache, all.names = TRUE)
  drop <- keys[vapply(
    keys,
    function(k) {
      grepl(pattern, fixture_cache[[k]]$label)
    },
    logical(1)
  )]
  rm(list = drop, envir = fixture_cache)
  length(drop)
}

# The RNG state a call is about to run under, as a value. A session that has
# never drawn has no `.Random.seed` at all, and that absence is itself part of
# the state -- a run started there draws from a freshly initialized generator.
fixture_rng_state <- function() {
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    list(RNGkind(), get(".Random.seed", envir = globalenv()))
  } else {
    list(RNGkind(), "<unseeded>")
  }
}

# Re-signal a captured condition so a cache hit reaches the caller's handlers
# exactly as the build did. `warning()` and `message()` on a condition object
# establish the muffle restarts that `suppressWarnings()` and testthat's
# expectations rely on, which `signalCondition()` alone would not; anything else
# -- an `rlang::signal()` diagnostic, say -- is signalled as itself, and reaches
# a calling handler exactly as it did on the build.
#
# An error is never replayed because an error is never cached: a build that
# raises one propagates out of `memoised()` before it stores anything.
replay_condition <- function(cnd) {
  if (inherits(cnd, "warning")) {
    warning(cnd)
  } else if (inherits(cnd, "message")) {
    message(cnd)
  } else {
    signalCondition(cnd)
  }
  invisible(NULL)
}

# Every free variable the design's stored inner specification would resolve
# against the caller's frame, paired with what it resolves to there.
#
# `nested_final_fit()` re-evaluates that specification in `rlang::caller_env()`
# (R/checks.R's `eval_inside_spec()`), so two byte-identical requests made from
# frames that bind those names differently are two different runs. The frame
# itself cannot go in the key -- every `test_that()` block is a distinct frame
# holding distinct locals, so hashing it would give every request its own key
# and the cache would never hit. What the result actually depends on is this
# much smaller thing: the values behind the names that specification names.
#
# A name bound nowhere is recorded as unbound rather than skipped, so a request
# from a frame that supplies it never shares a key with one that does not.
inside_spec_bindings <- function(args, env) {
  design <- args$resamples
  inside <- if (is.null(design)) NULL else attr(design, "inside")
  if (!is.call(inside)) {
    return("<no inside spec>")
  }
  names <- setdiff(all.vars(inside), c("data", ".nestedtune_data"))
  stats::setNames(
    lapply(names, function(nm) {
      if (exists(nm, envir = env)) {
        canonical_form(get(nm, envir = env))
      } else {
        "<unbound>"
      }
    }),
    names
  )
}

# The key for one request: which function, under which arguments, resolving
# which caller-scoped names, at which RNG state.
#
# The function goes in as a value, not as the text that named it: the cache is
# shared across every file in one `test_dir()` run, so keying on the source text
# alone would let two files that memoise same-named local builders collide, and
# the second would silently receive the first one's result.
#
# Arguments are sorted by name so that writing them in a different order is not
# a different fixture. Exposed on its own so test-fixture-cache.R can check what
# it separates without building anything.
fixture_key <- function(fn, args, env = parent.frame()) {
  ordered <- if (is.null(names(args))) args else args[order(names(args))]
  rlang::hash(list(
    canonical_form(fn),
    canonical_form(ordered),
    canonical_form(inside_spec_bindings(args, env)),
    canonical_form(fixture_rng_state())
  ))
}

memoised <- function(expr) {
  call <- substitute(expr)
  if (!is.call(call)) {
    rlang::abort("memoised() takes a call that builds a fixture.")
  }
  env <- parent.frame()
  fn <- eval(call[[1L]], envir = env)

  # Forced here, in written order, so the RNG state captured below is the one
  # the orchestrator would itself snapshot -- it forces its own arguments in its
  # `check_*()` calls before drawing.
  args <- lapply(as.list(call)[-1L], eval, envir = env)
  args <- as.list(match.call(fn, as.call(c(list(call[[1L]]), args))))[-1L]

  seed_hash <- rlang::hash(canonical_form(fixture_rng_state()))
  key <- fixture_key(fn, args, env)

  hit <- fixture_cache[[key]]
  if (is.null(hit)) {
    conditions <- list()
    value <- withCallingHandlers(
      # `envir` keeps `parent.frame()` inside the orchestrator pointing at the
      # test, not at this helper: `nested_final_fit()` re-evaluates its design's
      # stored `inside` call in its caller's environment.
      do.call(fn, args, quote = TRUE, envir = env),
      # Every condition, not only warnings and messages: a hit has to reach the
      # caller's handlers exactly as the build did, and an `rlang::signal()`
      # diagnostic observed by one test would otherwise be seen or missed
      # depending on which file happened to pay for the build.
      condition = function(cnd) {
        conditions[[length(conditions) + 1L]] <<- cnd
      }
    )
    hit <- list(
      value = value,
      conditions = conditions,
      # Deparsing a multi-line call keeps its indentation; the report reads it
      # as one line, so the runs of whitespace go.
      label = gsub("\\s+", " ", paste(deparse(call), collapse = " ")),
      seed = seed_hash,
      builds = 1L,
      requests = 0L
    )
  } else {
    for (cnd in hit$conditions) {
      replay_condition(cnd)
    }
  }
  hit$requests <- hit$requests + 1L
  assign(key, hit, envir = fixture_cache)
  hit$value
}

# What the cache did over a run: one row per distinct fixture, most requested
# first.
#
# Rows are grouped by what was *built*, not by the call that asked for it, and
# every cheaper grouping was tried first and found to lie. Grouping by key makes
# `builds` a tautology -- a miss is what creates an entry, so no key can build
# twice. Grouping by the call's source text is worse than useless here:
# test-nested-tune-grid-failures.R writes seven different designs as
# `nested_tune_grid(det_workflow(d), nested, ...)`, rebinding `nested` per test,
# so that grouping reports seven correct builds as a fault. Adding the seed to
# the source text fixes the seed-sensitivity tests and none of that.
#
# What survives is the question actually worth asking: did the suite pay for the
# same fit twice? Two entries whose values share a canonical form are two fits
# that produced the same thing, whatever they were called or how they were
# spelled, and that is a `builds` above 1 -- the number AC4 reads.
fixture_cache_report <- function() {
  keys <- ls(fixture_cache, all.names = TRUE)
  if (length(keys) == 0L) {
    return(data.frame(
      signature = character(0),
      builds = integer(0),
      requests = integer(0),
      stringsAsFactors = FALSE
    ))
  }
  entries <- lapply(keys, function(k) fixture_cache[[k]])
  labels <- vapply(entries, function(e) e$label, character(1))
  requests <- vapply(entries, function(e) e$requests, integer(1))
  built <- vapply(
    entries,
    function(e) {
      rlang::hash(canonical_form(e$value))
    },
    character(1)
  )

  first <- !duplicated(built)
  out <- data.frame(
    signature = labels[first],
    builds = vapply(built[first], function(b) sum(built == b), integer(1)),
    requests = vapply(
      built[first],
      function(b) sum(requests[built == b]),
      integer(1)
    ),
    stringsAsFactors = FALSE
  )
  out <- out[order(-out$requests, out$signature), ]
  row.names(out) <- NULL
  out
}
