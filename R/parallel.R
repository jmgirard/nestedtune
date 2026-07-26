# Detecting and recording the outer-loop dispatch branch.
#
# nestedtune parallelizes over outer folds and never inside them: inner tuning
# runs with control_grid(allow_par = FALSE), because nested parallelism
# oversubscribes cores. Detection mirrors tune's own so that "parallel" means
# the same thing in both packages (D-018) -- mirai installed, and at least two
# connected daemons. Below that tune stays sequential, and so do we.

# Split out so the threshold can be tested without daemons, and so the
# installed-or-not branch can be mocked.
is_mirai_installed <- function() {
  rlang::is_installed("mirai")
}

mirai_workers <- function() {
  if (!is_mirai_installed()) {
    return(0L)
  }
  # status() reports the live daemon pool; connections is NULL before daemons()
  # has ever been called in the session.
  workers <- mirai::status()$connections
  if (length(workers) != 1L || is.na(workers)) {
    return(0L)
  }
  as.integer(workers)
}

use_parallel <- function(workers = mirai_workers()) {
  length(workers) == 1L && !is.na(workers) && workers >= 2L
}

# Which branch the last dispatch took.
#
# This is deliberately NOT stored on the results object. BC1 requires both that
# a parallel result be identical() to its serial counterpart and that a test be
# able to prove the parallel branch actually ran; an attribute on the result
# would satisfy the second by breaking the first. An internal record satisfies
# both, and keeps the public surface unchanged.
the <- new.env(parent = emptyenv())

record_dispatch <- function(branch) {
  the$last_dispatch <- branch
  invisible(branch)
}

last_dispatch <- function() {
  the$last_dispatch
}

reset_dispatch_record <- function() {
  the$last_dispatch <- NULL
  invisible(NULL)
}

# Run every fold, serially or across daemons.
#
# `payloads` is one self-contained list per fold -- split, inner rset, and the
# fold's two seeds. Mapping over per-fold payloads rather than passing the whole
# design as a shared argument means a worker receives only the fold it runs.
#
# The seeds are already drawn and assigned by position before this is called
# (D-011), so nothing here draws, and a fold's result cannot depend on where or
# when it runs. That is the whole reason the loop is safe to parallelize.
dispatch_folds <- function(payloads, object, grid, metrics) {
  if (!use_parallel()) {
    record_dispatch("serial")
    return(lapply(payloads, fold_task, object = object, grid = grid, metrics = metrics))
  }

  check_daemons_can_load()

  record_dispatch("parallel")
  # The task is sent with its environment stripped to the global one. Left
  # attached, the nestedtune namespace travels with the closure and mirai warns
  # that the package "may not be available when loading" on every dispatch --
  # and where it truly is unavailable the environment silently degrades to the
  # global one anyway (RR03 Q5). Since the body resolves the namespace by name
  # regardless, carrying it buys nothing and costs a warning per fold.
  task <- fold_task
  environment(task) <- globalenv()

  mapped <- mirai::mirai_map(
    .x = payloads,
    .f = task,
    .args = list(object = object, grid = grid, metrics = metrics)
  )
  # A plain blocking collect: results in place, failures as values. mirai's
  # `.stop` would abort the whole run on the first failing fold and discard the
  # completed ones -- exactly what M03 exists to prevent.
  collected <- mirai::collect_mirai(mapped)
  lapply(collected, classify_fold_result)
}

# One round-trip before any fold is dispatched, to fail on the setup error users
# will actually make.
#
# Daemons are separate R processes: they can load nestedtune only from an
# installed library, and `devtools::load_all()` does not reach them. Without this
# check that mistake surfaces as every fold failing with the same opaque note --
# a run that looks like a statistical catastrophe and is really a library path
# (RR03 rec 8). One round-trip buys an error that names the fix.
# Bounded, because a daemon that never connects would otherwise block here
# forever. mirai reports connections from the pool's configuration, so a daemon
# that died during startup -- one whose own library is broken, say -- is counted
# but will never answer. This is deliberately NOT the per-fold timeout RR03
# rejected: a model fit has no defensible time limit, but a round-trip that only
# calls requireNamespace() does, and bounding it converts an unbreakable hang
# into an error naming the cause (M07-D6).
preflight_timeout_ms <- 30000L

daemons_can_load <- function(timeout = preflight_timeout_ms) {
  isTRUE(tryCatch(
    mirai::mirai(
      requireNamespace("nestedtune", quietly = TRUE),
      .timeout = timeout
    )[],
    error = function(cnd) FALSE
  ))
}

# `ok` is an argument so the failure branch is reachable in a test without
# breaking a library path. Doing that for real also stops the daemon loading
# *mirai*, which kills it at startup and hangs the very probe under test --
# found the hard way when it hung `R CMD check` for 39 minutes.
check_daemons_can_load <- function(ok = daemons_can_load(),
                                   call = rlang::caller_env()) {
  if (ok) {
    return(invisible(TRUE))
  }
  cli::cli_abort(
    c(
      "The mirai daemons cannot load {.pkg nestedtune}, or did not respond.",
      i = "Daemons are separate R processes and load the package from an
           installed library; {.fn devtools::load_all} does not reach them.",
      i = "Install the package, or prime the daemons with
           {.code mirai::everywhere(pkgload::load_all('<path>'))}.",
      i = "Alternatively call {.code mirai::daemons(0)} to run serially --
           results are identical either way."
    ),
    class = "nestedtune_daemons_cannot_load",
    call = call
  )
}

# What a worker handed back, turned into a fold record.
#
# Classification is positive: a fold record is recognised by its shape, and
# everything else is a worker failure. The two shapes mirai can return instead
# defeat the obvious test -- neither `miraiError` nor the bare `errorValue` from
# a daemon that died inherits "condition", and `conditionMessage()` raises on
# the latter rather than describing it (RR03 Q4, verified). Asking "is this an
# error?" therefore mistakes both for successes; asking "is this a fold record?"
# cannot.
classify_fold_result <- function(x) {
  if (is_fold_record(x)) {
    return(x)
  }
  if (inherits(x, "miraiInterrupt")) {
    # Not a fold failure: the user stopped the run. Recording it as one would
    # report a cancelled run as a design that executed and partly failed (IP4).
    cli::cli_abort(
      c(
        "Run interrupted while waiting on outer folds.",
        i = "No results are returned; the caller's RNG state is restored."
      ),
      class = "nestedtune_interrupted"
    )
  }
  failed_fold("worker", NULL, NULL, message = worker_failure_message(x))
}

is_fold_record <- function(x) {
  is.list(x) &&
    is.logical(x$completed) &&
    length(x$completed) == 1L &&
    all(c("metrics", "selected", "notes") %in% names(x))
}

worker_failure_message <- function(x) {
  if (isTRUE(try(mirai::is_mirai_error(x), silent = TRUE))) {
    # A miraiError does carry the task's own error message.
    return(conditionMessage(x))
  }
  if (isTRUE(try(mirai::is_error_value(x), silent = TRUE))) {
    # A bare errorValue is an integer code. nanonext names it ("19 | Connection
    # reset"); it always ships with mirai, but it is not a declared dependency
    # of this package, so it is reached only if present and the code stands
    # alone otherwise.
    named <- tryCatch(
      getExportedValue("nanonext", "nng_error")(as.integer(x)),
      error = function(cnd) NULL
    )
    return(paste0(
      "The worker failed with mirai error value ", as.integer(x),
      if (!is.null(named)) paste0(" (", named, ")") else ""
    ))
  }
  "The worker returned something that is not a fold record."
}

# One fold, as it runs on a worker.
#
# The namespace is resolved by name rather than captured: a closure carrying the
# nestedtune namespace as its environment loses that environment when a daemon
# cannot reconstruct it, silently falling back to the global environment where
# none of the package's internals resolve (RR03 Q5). Looking the namespace up
# here either works or fails loudly, and the pre-flight check makes it the
# latter before any fold is dispatched.
fold_task <- function(payload, object, grid, metrics) {
  ns <- asNamespace("nestedtune")
  ns$nested_fold_fit(
    split = payload$split,
    inner = payload$inner,
    seeds = payload$seeds,
    object = object,
    grid = grid,
    metrics = metrics
  )
}
