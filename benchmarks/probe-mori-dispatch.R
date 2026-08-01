# Does routing a fold's data through mori change what the fold computes?
#
#   Rscript benchmarks/probe-mori-dispatch.R
#
# M26 (AC2/AC3). The question is not whether mori is faster -- tune#1188 already
# measured that on `fit_resamples()` -- but whether it disturbs IP2: the same
# seed producing the same result regardless of worker count and regardless of
# whether execution is parallel or serial. mori has no RNG surface to disturb it
# through (no `unif_rand`/`GetRNGstate`/`rand` anywhere in its 2,245 lines of C,
# and none of its five R functions is stochastic), so the expected answer is
# "no change". An expectation is not a measurement, and the finding counts
# whichever way it comes out.
#
# Three arms, over one design, one workflow, one grid, one seed:
#
#   serial    nestedtune:::dispatch_folds() with no daemons -- its serial branch
#   by-value  nestedtune:::dispatch_folds() with daemons up -- the real lean path
#   mori      a REPLICA of that parallel branch, sharing the frame via mori
#
# Only the third arm is hand-rolled; the first two are the package's own
# dispatcher, called directly. All three return the same thing -- a list of fold
# records from nested_fold_fit() -- so `identical()` across them is a comparison
# of like with like rather than of two differently-assembled result objects.
#
# How the mori arm DIFFERS from dispatch_folds() (M26 AC2 requires this stated):
#
#   1. No leaning. dispatch_folds() blanks `$data` on the outer split and every
#      inner split and sends one frame beside the task in `.args`, rehydrating
#      worker-side. The mori arm leaves `$data` in place on every split, all of
#      them pointing at one shared object; the ALTREP serialization hook is what
#      makes those references cost ~30 bytes each, so there is nothing to lean
#      and nothing to rehydrate. This is the substantive difference and the
#      reason the arm exists.
#   2. No pre-flight and no cancellation guard. check_daemons_can_load() and
#      warn_if_not_cancellable() are diagnostics around the dispatch, not part
#      of it, and the identity question does not reach them.
#   3. No `record_dispatch()`. The by-value arm asserts `last_dispatch()`
#      out-of-band; the replica has no such seam to assert.
#
# Everything else is copied deliberately: the same seed scheme
# (`sample.int(.Machine$integer.max, 2 * n)`, fold i taking 2i-1 and 2i), the
# same per-fold payload shape, the same namespace-by-name lookup in the worker,
# and the same `environment(task) <- globalenv()` strip.
#
# The engine is ranger, never lm. With a deterministic engine every identity
# assertion here would pass vacuously, including against a dispatcher that
# seeds wrongly -- the trap M02 recorded and RR03 re-confirmed by execution.

suppressMessages({
  library(rsample)
  library(parsnip)
  library(workflows)
})
if (requireNamespace("pkgload", quietly = TRUE) &&
    !requireNamespace("nestedtune", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  suppressMessages(library(nestedtune))
}

for (pkg in c("mori", "mirai", "ranger", "yardstick")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("this probe needs ", pkg, "; install it and re-run")
  }
}

cat(R.version.string, "|", R.version$platform, "\n")
cat("mori", as.character(packageVersion("mori")),
    "| mirai", as.character(packageVersion("mirai")),
    "| tune", as.character(packageVersion("tune")),
    "| rsample", as.character(packageVersion("rsample")), "\n\n")

# The fixture and the byte oracles are defined once, in the test helpers, and
# sourced here rather than copied -- the same discipline
# dispatch-payload-size.R follows, and for the same reason: a number this
# script prints and a number the suite asserts must not be free to drift.
for (helper in c("helper-orchestration.R", "helper-payload-size.R")) {
  path <- file.path("tests", "testthat", helper)
  if (!file.exists(path)) {
    stop("run this from the repository root: ", path, " not found")
  }
  source(path)
}

SEED <- 2026L
WORKER_COUNTS <- c(2L, 3L)

data <- make_reg_data()
nested <- det_nested(data)
wf <- stoch_workflow(data)
grid <- stoch_grid()
metrics <- reg_metrics()
n_folds <- nrow(nested)

# The driver's own payload construction (R/nested-tune-grid.R:318-330),
# reproduced here so all three arms are handed identical input.
build_payloads <- function() {
  set.seed(SEED)
  seeds <- sample.int(.Machine$integer.max, 2L * n_folds)
  lapply(seq_len(n_folds), function(i) {
    list(
      split = nested$splits[[i]],
      inner = nested$inner_resamples[[i]],
      seeds = seeds[c(2L * i - 1L, 2L * i)]
    )
  })
}

# ---- arm 3: the mori replica -------------------------------------------------

# Point every split at one shared frame instead of blanking and rehydrating.
# `share()` is idempotent, so the frame is shared once and re-used.
morify_payload <- function(payload, shared) {
  payload$split$data <- shared
  payload$inner$splits <- lapply(payload$inner$splits, function(split) {
    split$data <- shared
    split
  })
  payload
}

mori_task <- function(payload, object, grid, metrics) {
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

# A daemon must have mori loaded before it can deserialize an ALTREP object
# mori created; the unserialize hook lives in mori's DLL. Built with str2lang()
# from a string rather than passed as an expression: everywhere() captures its
# argument unevaluated and serializes it, so under covr the HOST's rewritten
# body would travel and a daemon without covr would raise on it (M10).
load_mori_everywhere <- function() {
  mirai::everywhere(.expr = str2lang("loadNamespace('mori')"))
  invisible(NULL)
}

dispatch_via_mori <- function(payloads, shared) {
  payloads <- lapply(payloads, morify_payload, shared = shared)
  task <- mori_task
  environment(task) <- globalenv()
  mapped <- mirai::mirai_map(
    .x = payloads,
    .f = task,
    .args = list(object = wf, grid = grid, metrics = metrics)
  )
  on.exit(mirai::stop_mirai(mapped), add = TRUE)
  mapped[]
}

# ---- identity ----------------------------------------------------------------

cat("== identity: does the dispatch route change the fold records? ==\n")
cat("engine ranger (stochastic through R's RNG); seed", SEED,
    "; kind pinned per fold by set_fold_seed()\n\n")

mirai::daemons(0)
reference <- nestedtune:::dispatch_folds(
  build_payloads(), object = wf, grid = grid, metrics = metrics
)
stopifnot(identical(nestedtune:::last_dispatch(), "serial"))
cat(sprintf("serial reference: %d fold records, %d completed\n\n",
            length(reference),
            sum(vapply(reference, function(r) isTRUE(r$completed), logical(1)))))

results <- list()
for (n_workers in WORKER_COUNTS) {
  start_daemons(n_workers)
  load_mori_everywhere()

  by_value <- without_pkgload_warning(
    nestedtune:::dispatch_folds(
      build_payloads(), object = wf, grid = grid, metrics = metrics
    )
  )
  stopifnot(identical(nestedtune:::last_dispatch(), "parallel"))

  shared <- mori::share(data)
  stopifnot(mori::is_shared(shared))
  via_mori <- without_pkgload_warning(
    dispatch_via_mori(build_payloads(), shared)
  )

  results[[as.character(n_workers)]] <- list(
    by_value = identical(by_value, reference),
    mori = identical(via_mori, reference)
  )
  cat(sprintf("%d workers | by-value == serial: %-5s | mori == serial: %-5s\n",
              n_workers,
              results[[as.character(n_workers)]]$by_value,
              results[[as.character(n_workers)]]$mori))
  mirai::daemons(0)
}

cat("\n")

# ---- wire cost ---------------------------------------------------------------
#
# Two independent oracles per GP2, the pair helper-payload-size.R defines:
# serialized bytes, and a direct count of the data's own wire bytes found by
# searching the stream for the big-endian doubles of one numeric column. The
# count cannot be fooled by the size arithmetic -- it answers "how many copies
# of this frame are in here", which is the claim itself.

cat("== wire cost per fold: payload + `.args`, three routes ==\n")
cat("`.args` is charged once per TASK, not once per run -- mirai::mirai_map()\n")
cat("serializes it per task -- so it is per-fold wire cost exactly as the\n")
cat("payload is, and a payload figure alone understates the lean route.\n\n")
cat("Only the DATA-BEARING terms are counted. The workflow, grid, metrics and\n")
cat("worker closure also ride in `.args`, identically on all three routes, so\n")
cat("they cancel from a route comparison -- which is why the totals below are\n")
cat("smaller than M23's committed 5,783,645 B over 5 folds, which counts them.\n\n")
cat("The fat and lean figures are reproducible to the byte. The mori ones are\n")
cat("not: a shared object serializes as its region NAME, and the name encodes\n")
cat("the creating process, so that route varies by a few bytes per run. The\n")
cat("copy count is exact on every route and is the claim that matters here.\n\n")

# Two fixtures: the small orchestration one the identity arms above ran on, and
# the 5000x21 one M23 stated its numbers against, so the mori route is
# comparable to a committed measurement rather than only to itself.
wire_report <- function(label, frame, design) {
  sentinel <- sentinel_of(frame)
  set.seed(SEED)
  seeds <- sample.int(.Machine$integer.max, 2L)
  payload <- list(
    split = design$splits[[1L]],
    inner = design$inner_resamples[[1L]],
    seeds = seeds
  )
  shared_mori <- mori::share(frame)

  routes <- list(
    fat = list(payload = payload, args = NULL),
    lean = list(payload = nestedtune:::lean_payload(payload, shared = frame),
                args = frame),
    mori = list(payload = morify_payload(payload, shared = shared_mori),
                args = NULL)
  )

  cat("--", label, "--\n")
  cat(sprintf("%-6s %14s %14s %14s %8s\n",
              "route", "payload", ".args", "total/fold", "copies"))
  for (nm in names(routes)) {
    r <- routes[[nm]]
    p_bytes <- payload_bytes(r$payload)
    a_bytes <- if (is.null(r$args)) 0L else payload_bytes(r$args)
    copies <- count_data_copies(r$payload, sentinel) +
      if (is.null(r$args)) 0L else count_data_copies(r$args, sentinel)
    cat(sprintf("%-6s %14d %14d %14d %8d\n",
                nm, p_bytes, a_bytes, p_bytes + a_bytes, copies))
  }
  cat("\n")
}

wire_report("orchestration fixture (90x5, v=3/v=3)", data, nested)

big_data <- payload_fixture_data()
set.seed(1L)
big_design <- nested_resamples(
  big_data,
  outside = rsample::vfold_cv(v = 5),
  inside = rsample::vfold_cv(v = 3)
)
wire_report("M23 fixture (5000x21, v=5/v=3)", big_data, big_design)

cat("\n== summary ==\n")
for (n_workers in names(results)) {
  r <- results[[n_workers]]
  cat(sprintf("%s workers: by-value %s, mori %s\n", n_workers,
              if (r$by_value) "identical to serial" else "DIVERGED",
              if (r$mori) "identical to serial" else "DIVERGED"))
}
