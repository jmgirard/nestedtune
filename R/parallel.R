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
