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
    if (nzchar(nm)) return(list("<env>", nm))
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
# expectations rely on, which `signalCondition()` alone would not.
replay_condition <- function(cnd) {
  if (inherits(cnd, "error")) {
    stop(cnd)
  } else if (inherits(cnd, "warning")) {
    warning(cnd)
  } else if (inherits(cnd, "message")) {
    message(cnd)
  } else {
    signalCondition(cnd)
  }
  invisible(NULL)
}

# The key for one request: which function, under which arguments, at which RNG
# state. Arguments are sorted by name so that writing them in a different order
# is not a different fixture. Exposed on its own so test-fixture-cache.R can
# check what it separates without building anything.
fixture_key <- function(fn_name, args) {
  rlang::hash(list(
    fn_name,
    canonical_form(args[order(names(args))]),
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
  key <- fixture_key(deparse(call[[1L]]), args)

  hit <- fixture_cache[[key]]
  if (is.null(hit)) {
    conditions <- list()
    value <- withCallingHandlers(
      # `envir` keeps `parent.frame()` inside the orchestrator pointing at the
      # test, not at this helper: `nested_final_fit()` re-evaluates its design's
      # stored `inside` call in its caller's environment.
      do.call(fn, args, quote = TRUE, envir = env),
      warning = function(w) {
        conditions[[length(conditions) + 1L]] <<- w
      },
      message = function(m) {
        conditions[[length(conditions) + 1L]] <<- m
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
    for (cnd in hit$conditions) replay_condition(cnd)
  }
  hit$requests <- hit$requests + 1L
  assign(key, hit, envir = fixture_cache)
  hit$value
}

# What the cache did over a run: one row per fixture, most requested first.
#
# A fixture here is a call *as written* together with the RNG state it was made
# under, and that pairing is what makes the `builds` column mean something. One
# entry per key is a tautology -- a miss is what creates an entry, so no key can
# build twice. Grouping by the source text alone is no better: a test that
# deliberately runs the same call under two seeds wants two builds and would be
# reported as a fault. What is left once both are excluded is the real failure:
# the same call, at the same seed, landing on two keys because the key was
# unstable, and so paying for one fixture twice. That is the `builds` above 1
# AC4 reads, and nothing else produces one.
fixture_cache_report <- function() {
  keys <- ls(fixture_cache, all.names = TRUE)
  if (length(keys) == 0L) {
    return(data.frame(
      signature = character(0), builds = integer(0), requests = integer(0),
      stringsAsFactors = FALSE
    ))
  }
  entries <- lapply(keys, function(k) fixture_cache[[k]])
  labels <- vapply(entries, function(e) e$label, character(1))
  seeds <- vapply(entries, function(e) e$seed, character(1))
  requests <- vapply(entries, function(e) e$requests, integer(1))

  group <- paste(labels, seeds, sep = "\r")
  first <- !duplicated(group)
  out <- data.frame(
    signature = labels[first],
    builds = vapply(group[first], function(g) sum(group == g), integer(1)),
    requests = vapply(group[first], function(g) sum(requests[group == g]),
                      integer(1)),
    stringsAsFactors = FALSE
  )
  out <- out[order(-out$requests, out$signature), ]
  row.names(out) <- NULL
  out
}
