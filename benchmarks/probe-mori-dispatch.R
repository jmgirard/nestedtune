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
# dispatcher, called directly. The WIRE section below hand-rolls nothing at all:
# it captures what dispatch_folds() actually hands mirai_map(). All three return the same thing -- a list of fold
# records from nested_fold_fit() -- so `identical()` across them is a comparison
# of like with like rather than of two differently-assembled result objects.
#
# How the mori arm DIFFERS from dispatch_folds() (M26 AC2 requires this stated;
# the same list appears in cairn/references/mori-backend-assessment.md, which is
# where a reader of the assessment meets it):
#
#   1. No leaning, and NO INVARIANT GATE. dispatch_folds() blanks `$data` on the
#      outer split and every inner split and sends one frame beside the task in
#      `.args`, rehydrating worker-side. The mori arm leaves `$data` in place on
#      every split, all pointing at one shared object, so there is nothing to
#      blank and nothing to rehydrate. But `is_fold_payload()` is NOT part of
#      that leaning machinery: it enforces the one-frame-per-fold invariant, and
#      without it a `manual_rset()` over differing frames -- or an
#      `rsample::nested_cv()` design -- is tuned on the wrong rows in parallel
#      and the right ones serially (an IP2 breach and an IP1 exposure, M23
#      review F1, scored 93; see R/parallel.R:100-118). `morify_payload()` below
#      has no such gate, which is safe HERE only because the fixture is a
#      `nested_resamples()` design whose splits provably share one frame -- and
#      the probe asserts that rather than assuming it. Any real adoption needs
#      the predicate kept.
#   2. No pre-flight and no cancellation guard. check_daemons_can_load() and
#      warn_if_not_cancellable() are diagnostics around the dispatch, not part
#      of it, and the identity question does not reach them.
#   3. No `record_dispatch()`. The by-value arm asserts `last_dispatch()`
#      out-of-band; the replica has no such seam to assert.
#
# Everything else is copied deliberately: the same seed scheme
# (`sample.int(.Machine$integer.max, 2 * n)`, fold i taking 2i-1 and 2i), the
# same per-fold payload shape, the same namespace-by-name lookup in the worker,
# the same `environment(task) <- globalenv()` strip, and the same
# `collect_mirai()` + `on.exit(stop_mirai())` collect the real dispatcher uses.
#
# The engine is ranger, never lm. With a deterministic engine every identity
# assertion here would pass vacuously, including against a dispatcher that
# seeds wrongly -- the trap M02 recorded and RR03 re-confirmed by execution.
# For the same reason the probe ASSERTS that folds completed: three arms that
# all failed identically would compare `identical()` just as happily.

suppressMessages({
  library(rsample)
  library(parsnip)
  library(workflows)
})

# `load_all()` unconditionally when pkgload is available. The earlier form
# preferred an INSTALLED nestedtune whenever one existed, which silently
# measured a different copy of the package than the working tree -- and the
# comparison target below (M23's committed figures) is itself ~19% srcref-laden
# worker closure that only reproduces under load_all().
if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
  cat("package: pkgload::load_all(\".\")\n")
} else {
  suppressMessages(library(nestedtune))
  cat("package: installed library (figures will differ; srcrefs absent)\n")
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
# helper-parallel.R is sourced too, for start_daemons()/without_pkgload_warning();
# omitting it left this script runnable only as a side effect of load_all()
# sourcing every helper (M26 review D6).
for (helper in c("helper-orchestration.R", "helper-payload-size.R",
                 "helper-parallel.R")) {
  path <- file.path("tests", "testthat", helper)
  if (!file.exists(path)) {
    stop("run this from the repository root: ", path, " not found")
  }
  source(path)
}

SEED <- 2026L
WORKER_COUNTS <- c(2L, 3L)

# Pin the full generator triple and restore the caller's on exit. `set.seed(s)`
# pins only the uniform generator, so a session with a non-default RNGkind()
# would build a different fixture and draw different seeds while every number
# below claimed reproducibility (M18). The per-fold pin inside set_fold_seed()
# is the package's own and is inherited, not asserted, by this script.
# NOT `on.exit()`: at top level in an Rscript it registers against a frame that
# never returns, so it silently never fires -- verified by execution, and it is
# how an earlier draft of this script came to claim a restoration it did not
# perform. `reg.finalizer(..., onexit = TRUE)` does run at session exit,
# including after a `stopifnot()` abort.
old_kind <- RNGkind()
cleanup <- function() {
  try(mirai::daemons(0), silent = TRUE)
  try(RNGkind(old_kind[[1L]], old_kind[[2L]], old_kind[[3L]]), silent = TRUE)
  try(mori::prune_shared(), silent = TRUE)
}
reg.finalizer(environment(), function(e) cleanup(), onexit = TRUE)
RNGkind("Mersenne-Twister", "Inversion", "Rejection")

data <- make_reg_data()
nested <- det_nested(data)
wf <- stoch_workflow(data)
grid <- stoch_grid()
metrics <- reg_metrics()
n_folds <- nrow(nested)

# The driver's own payload construction (R/nested-tune-grid.R:320-330),
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

completed_count <- function(records) {
  sum(vapply(records, function(r) isTRUE(r$completed), logical(1)))
}

# ---- arm 3: the mori replica -------------------------------------------------

# Point every split at one shared frame instead of blanking and rehydrating.
# `share()` is idempotent on an ALREADY-SHARED object, not on the original, so
# each call on `data` mints a new region; callers pass one shared object in.
#
# Guarded by the same invariant is_fold_payload() enforces -- see difference 1
# in the header. Without this, a design whose inner splits index a different
# frame would be silently retargeted onto the outer one.
morify_payload <- function(payload, shared, original) {
  stopifnot(identical(payload$split$data, original))
  for (split in payload$inner$splits) {
    stopifnot(identical(split$data, original))
  }
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

# No preload is needed on the daemons, which is worth stating because the
# opposite is the natural assumption: mori's unserialize hook lives in its DLL,
# so one expects a daemon to need `everywhere(loadNamespace('mori'))` first.
# It does not -- R records the owning package on an ALTREP class and loads that
# namespace itself when deserializing. `mori_transport_check()` below verifies
# that by execution rather than leaving it asserted in a comment.
# What a daemon does still need is mori installed in its library, the same
# requirement check_daemons_can_load() already checks for nestedtune itself.

# Did the shared object actually arrive as shared, or did it degrade to a
# by-value copy? Without this the identity arms are vacuous: an ALTREP hook that
# failed to engage would leave all three arms identical() and the probe would
# report success having measured the by-value path three times (M26 review D10).
mori_transport_check <- function(shared) {
  host_name <- mori::shared_name(shared)
  m <- mirai::mirai(
    list(shared = mori::is_shared(d), name = mori::shared_name(d)),
    d = shared
  )
  on.exit(mirai::stop_mirai(m), add = TRUE)
  got <- mirai::collect_mirai(m)
  list(
    shared_in_daemon = isTRUE(got$shared),
    name_matches = identical(got$name, host_name),
    host_name = host_name
  )
}

dispatch_via_mori <- function(payloads, shared, original) {
  payloads <- lapply(payloads, morify_payload, shared = shared,
                     original = original)
  task <- mori_task
  environment(task) <- globalenv()
  mapped <- mirai::mirai_map(
    .x = payloads,
    .f = task,
    .args = list(object = wf, grid = grid, metrics = metrics)
  )
  # The same collect the real dispatcher uses (R/parallel.R:291-293): a plain
  # blocking collect with an unconditional cancelling on.exit, so leaving this
  # function never leaves folds running.
  on.exit(mirai::stop_mirai(mapped), add = TRUE)
  mirai::collect_mirai(mapped)
}

# ---- identity ----------------------------------------------------------------

cat("== identity: does the dispatch route change the fold records? ==\n")
cat("engine ranger (stochastic through R's RNG); seed", SEED,
    "; ambient kind pinned to Mersenne-Twister/Inversion/Rejection\n\n")

mirai::daemons(0)
reference <- nestedtune:::dispatch_folds(
  build_payloads(), object = wf, grid = grid, metrics = metrics
)
stopifnot(identical(nestedtune:::last_dispatch(), "serial"))
# Not decoration: three arms in which every fold FAILED would also compare
# identical(), and the ranger engine would never have been reached.
stopifnot(completed_count(reference) == n_folds)
cat(sprintf("serial reference: %d fold records, %d completed\n\n",
            length(reference), completed_count(reference)))

results <- list()
for (n_workers in WORKER_COUNTS) {
  start_daemons(n_workers)

  by_value <- without_pkgload_warning(
    nestedtune:::dispatch_folds(
      build_payloads(), object = wf, grid = grid, metrics = metrics
    )
  )
  stopifnot(identical(nestedtune:::last_dispatch(), "parallel"))
  stopifnot(completed_count(by_value) == n_folds)

  shared <- mori::share(data)
  stopifnot(mori::is_shared(shared))
  transport <- mori_transport_check(shared)
  via_mori <- without_pkgload_warning(
    dispatch_via_mori(build_payloads(), shared, original = data)
  )
  stopifnot(completed_count(via_mori) == n_folds)

  results[[as.character(n_workers)]] <- list(
    by_value = identical(by_value, reference),
    mori = identical(via_mori, reference),
    transport = transport
  )
  cat(sprintf(
    "%d workers | by-value == serial: %-5s | mori == serial: %-5s | daemon mapped the region: %-5s\n",
    n_workers,
    results[[as.character(n_workers)]]$by_value,
    results[[as.character(n_workers)]]$mori,
    transport$shared_in_daemon && transport$name_matches))
  mirai::daemons(0)
}

# The findings this probe exists to produce. Printing FALSE and exiting 0 would
# let a divergence pass unnoticed by anything reading the exit status.
stopifnot(all(vapply(results, function(r) r$by_value, logical(1))))
stopifnot(all(vapply(results, function(r) r$mori, logical(1))))
stopifnot(all(vapply(results, function(r) r$transport$shared_in_daemon &&
                       r$transport$name_matches, logical(1))))

cat("\n")

# ---- what a shared reference actually costs on the wire -----------------------
#
# Measured rather than assumed. The region NAME is short, but a serialized
# shared object is not the name alone: it carries the ALTREP class and its
# metadata too.

cat("== what one shared reference costs on the wire ==\n")
ref_frame <- payload_fixture_data(n = 10000, p = 1)
ref_shared <- mori::share(ref_frame)
one_ref <- length(serialize(ref_shared, NULL))
four_refs <- length(serialize(list(ref_shared, ref_shared, ref_shared, ref_shared), NULL))
cat(sprintf("region name: %s (%d characters, fixed width)\n",
            mori::shared_name(ref_shared), nchar(mori::shared_name(ref_shared))))
cat(sprintf("one shared object serialized: %d B\n", one_ref))
cat(sprintf("marginal cost per additional reference: %.0f B\n",
            (four_refs - one_ref) / 3))
cat(sprintf("against the same frame by value: %d B\n\n",
            length(serialize(ref_frame, NULL))))

# ---- wire cost, measured off the REAL dispatch --------------------------------
#
# Earlier drafts of this probe reconstructed the payload and `.args` by hand and
# compared those. Twice that produced a published figure that did not survive
# re-derivation: once because the fixture was not M23's, and once because the
# hand-built accounting charged the worker closure to one route only. Both are
# failures of the reconstruction, not of the measurement, so this section no
# longer reconstructs anything.
#
# `capture_dispatch()` runs the package's own `dispatch_folds()` and intercepts
# `mirai::mirai_map()` to record exactly what it was handed: `.f`, one element
# of `.x`, and `.args`. mirai serializes all three per task (its `do_mirai()`
# bundles `list(.f = .f, .x = elem, .args = .args, ...)`), so the per-fold wire
# cost is the sum of the three and nothing is left to an accounting convention.
#
# What this cannot capture is the mori route, which does not exist: no dispatch
# sends it today. That row is therefore MODELLED -- but modelled from the
# captured bundle rather than from a parallel hand-built one, substituting only
# what adoption would change: the shared frame replaces `.args$shared`, and the
# rehydrating wrapper collapses back to `fold_task` because there is nothing to
# rehydrate. The closure is carried on BOTH rows, since a real adoption would
# send the package's own worker exactly as the lean path does.

capture_dispatch <- function(payloads, object, grid, metrics) {
  captured <- NULL
  orig <- mirai::mirai_map
  fake <- function(.x, .f, .args, ...) {
    captured <<- list(f = .f, x = .x, args = .args)
    stop(structure(class = c("dispatch_captured", "error", "condition"),
                   list(message = "captured", call = NULL)))
  }
  utils::assignInNamespace("mirai_map", fake, ns = "mirai")
  on.exit(utils::assignInNamespace("mirai_map", orig, ns = "mirai"), add = TRUE)
  tryCatch(
    nestedtune:::dispatch_folds(payloads, object = object, grid = grid,
                                metrics = metrics),
    dispatch_captured = function(cnd) NULL
  )
  captured
}

cat("== wire cost per fold, measured off the real dispatch ==\n")
cat("mirai serializes `.f`, one element of `.x`, and `.args` per task, so a\n")
cat("fold's wire cost is the sum of the three. The lean row is CAPTURED from\n")
cat("dispatch_folds(); the mori row is MODELLED from that same captured bundle,\n")
cat("carrying the same worker closure, since adoption would still send it.\n\n")

big_data <- payload_fixture_data()
set.seed(2)
big_design <- nested_resamples(
  big_data,
  outside = rsample::vfold_cv(v = 5),
  inside = rsample::vfold_cv(v = 5)
)
big_wf <- payload_fixture_workflow()
big_sentinel <- sentinel_of(big_data)
big_payloads <- lapply(seq_len(nrow(big_design)), function(i) {
  list(split = big_design$splits[[i]],
       inner = big_design$inner_resamples[[i]], seeds = c(1L, 2L))
})

start_daemons(2L)
bundle <- capture_dispatch(big_payloads, big_wf, grid = 3, metrics = NULL)
mirai::daemons(0)
stopifnot(!is.null(bundle),
          identical(sort(names(bundle$args)),
                    sort(c("object", "grid", "metrics", "shared", "worker"))))

lean_parts <- list(.f = bundle$f, .x = bundle$x[[1L]], .args = bundle$args)

# The modelled mori bundle: same closure, no shared frame, no rehydration.
mori_shared <- mori::share(big_data)
mori_payload <- morify_payload(big_payloads[[1L]], shared = mori_shared,
                               original = big_data)
mori_parts <- list(
  .f = bundle$args$worker,
  .x = mori_payload,
  .args = list(object = big_wf, grid = 3, metrics = NULL)
)

report_bundle <- function(label, parts, sentinel) {
  b <- vapply(parts, function(x) length(serialize(x, NULL)), numeric(1))
  copies <- sum(vapply(parts, function(x) count_data_copies(x, sentinel), numeric(1)))
  cat(sprintf("%-6s %12.0f %12.0f %12.0f %14.0f %8.0f\n",
              label, b[[".f"]], b[[".x"]], b[[".args"]], sum(b), copies))
  invisible(sum(b))
}

cat(sprintf("%-6s %12s %12s %12s %14s %8s\n",
            "route", ".f", ".x", ".args", "total/fold", "copies"))
lean_total <- report_bundle("lean", lean_parts, big_sentinel)
mori_total <- report_bundle("mori", mori_parts, big_sentinel)
cat(sprintf("\nratio (lean / mori): %.2fx\n", lean_total / mori_total))
cat(sprintf("the closure is common to both rows: %.0f B\n",
            length(serialize(bundle$args$worker, NULL))))
cat(sprintf("the data term the lean row carries and mori does not: %.0f B\n\n",
            length(serialize(big_data, NULL))))

# The closed-form oracle, compared rather than printed. M23's own test bounds it
# at 5%; an oracle that is printed and never checked cannot fail.
predicted <- predicted_lean_bytes(5000, 5, 5)
measured_payload <- length(serialize(bundle$x[[1L]], NULL))
cat(sprintf("closed-form oracle for the lean payload: %d B predicted, %d B measured (%.1f%%)\n",
            predicted, measured_payload,
            100 * abs(measured_payload - predicted) / predicted))
stopifnot(abs(measured_payload - predicted) / predicted < 0.05)

# The copy counts are the claim; assert them rather than printing them.
stopifnot(sum(vapply(lean_parts, function(x) count_data_copies(x, big_sentinel), numeric(1))) == 1)
stopifnot(sum(vapply(mori_parts, function(x) count_data_copies(x, big_sentinel), numeric(1))) == 0)

cat("== summary ==\n")
for (n_workers in names(results)) {
  r <- results[[n_workers]]
  cat(sprintf("%s workers: by-value %s, mori %s, daemon mapped the region %s\n",
              n_workers,
              if (r$by_value) "identical to serial" else "DIVERGED",
              if (r$mori) "identical to serial" else "DIVERGED",
              if (r$transport$shared_in_daemon && r$transport$name_matches) "yes" else "NO"))
}

