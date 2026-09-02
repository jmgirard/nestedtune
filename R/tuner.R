# The tuner description: which tune function a fold calls, and the static
# arguments only that function takes.
#
# One loop runs both orchestrators (D-040). What differs between them is the
# inner call -- `tune_grid()` takes a `grid`, `tune_bayes()` takes `iter`,
# `initial` and `objective` -- and everything else a fold needs (`object`,
# `param_info`, `metrics`, `eval_time`, `event_level`) is common. So the
# orchestrator builds one of these and threads it through the dispatch chain
# in place of the `grid` formal, and the worker assembles the call from it.
# The description holds no function object, only the function's name: package
# functions serialize by namespace name, so a mirai daemon resolves it inside
# its own copy of tune, and a name costs nothing on the wire (M12/M23).
#
# The record a results object carries (`procedure`) is built from the same
# description, which is what lets a later final fit re-run what ran (M46).

tuner_grid <- function(grid) {
  new_tuner("tune_grid", list(grid = grid))
}

tuner_bayes <- function(iter, initial, objective) {
  new_tuner(
    "tune_bayes",
    list(iter = iter, initial = initial, objective = objective)
  )
}

new_tuner <- function(tuner, args) {
  list(tuner = tuner, args = args)
}

# The inner tuning call, assembled and evaluated.
#
# `seed` is the fold's tuning seed, and it matters to one tuner only:
# `control_bayes()` draws its own `seed` from the stream by default and uses it
# to seed the Gaussian-process proposals, so leaving it to the default would
# make the proposals depend on how much of the stream tune had consumed before
# it got there. Fixing it to the fold's tuning seed keeps the fold reproducible
# from that one number, the contract the seeds exist to give (D-040, IP2). The
# control is built here, inside the fold's seed scope, because that is the
# scope the roxygen's by-hand recipe reproduces.
#
# `control_grid()` has no seed slot and takes none. Both controls force
# `allow_par = FALSE`: parallelism belongs over the outer folds, and a second
# pool inside a daemon would contend with the first.
run_tuner <- function(
  tuner,
  object,
  resamples,
  param_info,
  metrics,
  eval_time,
  event_level,
  seed
) {
  control <- tuner_control(tuner, event_level = event_level, seed = seed)
  # The call is built over symbols and evaluated where they are bound, never
  # over the values themselves: a condition tune raises carries its call, and
  # a call holding the workflow inline holds the recipe's training data with
  # it -- 172,000 characters of deparsed call on a 400-row fixture against 173
  # over symbols (measured 2026-09-01, M45 review). `object` stays positional
  # so the call reads as a by-hand one would.
  args <- c(
    list(
      object = object,
      resamples = resamples,
      param_info = param_info,
      metrics = metrics,
      eval_time = eval_time
    ),
    tuner$args,
    list(control = control)
  )
  syms <- rlang::syms(names(args))
  names(syms) <- c("", names(args)[-1L])
  call <- rlang::call2(tuner$tuner, !!!syms, .ns = "tune")
  rlang::eval_bare(call, rlang::new_environment(args, parent = baseenv()))
}

tuner_control <- function(tuner, event_level, seed) {
  switch(
    tuner$tuner,
    tune_grid = tune::control_grid(
      allow_par = FALSE,
      event_level = event_level
    ),
    tune_bayes = tune::control_bayes(
      allow_par = FALSE,
      event_level = event_level,
      seed = seed
    ),
    cli::cli_abort(
      "Unknown tuner {.val {tuner$tuner}}.",
      .internal = TRUE
    )
  )
}

# What a results object records about the procedure that produced it (IP4):
# the tuner and its static arguments, then the arguments both tuners share. A
# flat named list, so a reader asks `attr(x, "procedure")$iter` rather than
# walking a nested description, and so the record reads the same whichever
# tuner ran.
new_procedure <- function(tuner, param_info, event_level, eval_time) {
  c(
    list(tuner = tuner$tuner),
    tuner$args,
    list(
      param_info = param_info,
      event_level = event_level,
      eval_time = eval_time
    )
  )
}

# The tuner description rebuilt from a results object's record, for the final
# fit (D-041): the record is the description plus the three shared arguments,
# so everything that is neither the tuner's name nor one of those is the
# tuner's own argument. Read by name rather than by position so a record
# whose shared arguments were reordered still rebuilds the same description.
procedure_tuner <- function(procedure) {
  shared <- c("tuner", "param_info", "event_level", "eval_time")
  new_tuner(procedure$tuner, procedure[setdiff(names(procedure), shared)])
}
