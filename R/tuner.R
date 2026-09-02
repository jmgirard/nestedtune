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
# `control` is the caller's control object, or NULL for tune's default, and
# what runs is its effective form (D-042): the forced slots applied by
# `tuner_control()` below, inside the fold's seed scope, because that is the
# scope the roxygen's by-hand recipe reproduces.
#
# `seed` is the fold's tuning seed, and it matters to one tuner only:
# `control_bayes()` draws its own `seed` from the stream by default and uses it
# to seed the Gaussian-process proposals, so leaving it to the default would
# make the proposals depend on how much of the stream tune had consumed before
# it got there. Fixing it to the fold's tuning seed keeps the fold reproducible
# from that one number, the contract the seeds exist to give (D-040, IP2).
# `control_grid()` has no seed slot and takes none.
run_tuner <- function(
  tuner,
  object,
  resamples,
  param_info,
  metrics,
  eval_time,
  event_level,
  control,
  seed
) {
  control <- tuner_control(
    tuner,
    control = control,
    event_level = event_level,
    seed = seed
  )
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

# The control the inner call runs under: the effective control, plus the
# fold's tuning seed where the tuner takes one.
tuner_control <- function(tuner, control, event_level, seed) {
  control <- effective_control(tuner$tuner, control, event_level)
  if (identical(tuner$tuner, "tune_bayes")) {
    control$seed <- seed
  }
  control
}

# The control a run records and re-runs (D-042): the caller's control, or
# tune's default when none was passed, with the slots this package forces
# overwritten. `allow_par` is off because parallelism belongs over the outer
# folds, and a second pool inside a daemon would contend with the first.
# `event_level` is the argument's, which `check_control()` has already held
# the control to. The Bayesian `seed` is dropped: it is the fold's tuning
# seed, which the fold record holds, and `tuner_control()` puts it back where
# the call is made. Applied to a control that is already effective it changes
# nothing, so the record and the call cannot disagree.
effective_control <- function(tuner, control, event_level) {
  if (is.null(control)) {
    control <- default_control(tuner)
  }
  control$allow_par <- FALSE
  control$event_level <- event_level
  control$seed <- NULL
  control
}

# tune's default for the tuner. `control_bayes()` draws its `seed` slot when
# built, and that draw would move the caller's stream between the entry
# snapshot and the seed draw; a fixed value costs nothing because
# `effective_control()` discards it and every fold supplies its own -- the
# device tune itself uses in `tune_bayes()`, condensing against
# `control_bayes(seed = 1)`.
default_control <- function(tuner) {
  switch(
    tuner,
    tune_grid = tune::control_grid(),
    tune_bayes = tune::control_bayes(seed = 1L),
    cli::cli_abort(
      "Unknown tuner {.val {tuner}}.",
      .internal = TRUE
    )
  )
}

# The class a tuner's control must carry, and the tune function that returns
# it: the class is the contract, since tune's own `condense_control()` reads
# slots by name and would take a `control_bayes()` for a `control_grid()`
# without complaint.
control_class <- function(tuner) {
  switch(
    tuner,
    tune_grid = "control_grid",
    tune_bayes = "control_bayes",
    cli::cli_abort(
      "Unknown tuner {.val {tuner}}.",
      .internal = TRUE
    )
  )
}

# What a results object records about the procedure that produced it (IP4):
# the tuner and its static arguments, then the arguments both tuners share. A
# flat named list, so a reader asks `attr(x, "procedure")$iter` rather than
# walking a nested description, and so the record reads the same whichever
# tuner ran. `control` is the effective control (D-042), so a later final fit
# re-runs under exactly what ran.
new_procedure <- function(tuner, param_info, event_level, eval_time, control) {
  c(
    list(tuner = tuner$tuner),
    tuner$args,
    list(
      param_info = param_info,
      event_level = event_level,
      eval_time = eval_time,
      control = control
    )
  )
}

# The tuner description rebuilt from a results object's record, for the final
# fit (D-041): the record is the description plus the four shared arguments,
# so everything that is neither the tuner's name nor one of those is the
# tuner's own argument. Read by name rather than by position so a record
# whose shared arguments were reordered still rebuilds the same description.
# `control` is shared, so the final fit passes it once, as its own argument,
# and never a second time inside the description.
procedure_tuner <- function(procedure) {
  shared <- c("tuner", "param_info", "event_level", "eval_time", "control")
  new_tuner(procedure$tuner, procedure[setdiff(names(procedure), shared)])
}
