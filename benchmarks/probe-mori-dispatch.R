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
old_kind <- RNGkind()
on.exit(RNGkind(old_kind[[1L]], old_kind[[2L]], old_kind[[3L]]), add = TRUE)
on.exit(mirai::daemons(0), add = TRUE)
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
# `share()` is idempotent, so the frame is shared once and re-used.
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
# metadata too. An earlier draft of this probe quoted "~30 bytes", the name's
# own length, as the per-reference wire cost -- wrong by an order of magnitude
# in a document whose subject is wire cost (M26 review D4).

cat("== what one shared reference costs on the wire ==\n")
ref_frame <- payload_fixture_data(n = 10000, p = 1)
ref_shared <- mori::share(ref_frame)
one_ref <- length(serialize(ref_shared, NULL))
four_refs <- length(serialize(list(ref_shared, ref_shared, ref_shared, ref_shared), NULL))
cat(sprintf("region name: %s (%d characters)\n",
            mori::shared_name(ref_shared), nchar(mori::shared_name(ref_shared))))
cat(sprintf("one shared object serialized: %d B\n", one_ref))
cat(sprintf("marginal cost per additional reference: %.0f B\n",
            (four_refs - one_ref) / 3))
cat(sprintf("(the frame itself by value would be %d B)\n\n",
            length(serialize(ref_frame, NULL))))

# ---- wire cost ---------------------------------------------------------------
#
# Three oracles, not two. helper-payload-size.R defines the pair M23 certified
# under GP2 -- a CLOSED FORM predicting bytes from n/v/inner_v alone, and a
# direct COPY COUNT found by searching the stream for the big-endian doubles of
# one numeric column -- and they share no arithmetic. An earlier draft named
# "serialized bytes" as one of the two, but the byte total and the copy count
# both read the same serialize() stream, so that pair was one mechanism wearing
# two hats (M26 review D14). The closed form is evaluated below.

cat("== wire cost per fold: payload + `.args`, three routes ==\n")
cat("`.args` is charged once per TASK, not once per run -- mirai::mirai_map()\n")
cat("serializes it per task -- so it is per-fold wire cost exactly as the\n")
cat("payload is, and a payload figure alone understates the lean route.\n\n")
cat("Counted: the DATA-BEARING terms, plus the worker closure where the route\n")
cat("actually carries it. The workflow, grid and metrics ride in `.args` on\n")
cat("every route and cancel. The worker closure does NOT cancel -- \n")
cat("dispatch_folds() adds `worker` and `shared` to `.args` only on the leaning\n")
cat("branch (R/parallel.R:250-256), so it is a lean-route cost and neither the\n")
cat("fat nor the mori route pays it.\n\n")
cat("The fat and lean figures are reproducible to the byte. The mori ones are\n")
cat("not: a shared object serializes as its region name, and the name encodes\n")
cat("the creating process, so that route varies by a few bytes per run. The\n")
cat("copy count is exact on every route and is the claim that matters here.\n\n")

wire_report <- function(label, frame, design, v, inner_v) {
  sentinel <- sentinel_of(frame)
  set.seed(SEED)
  seeds <- sample.int(.Machine$integer.max, 2L)
  payload <- list(
    split = design$splits[[1L]],
    inner = design$inner_resamples[[1L]],
    seeds = seeds
  )
  shared_mori <- mori::share(frame)

  worker <- nestedtune:::fold_task
  environment(worker) <- globalenv()

  lean <- nestedtune:::lean_payload(payload, shared = frame)
  mori_payload <- morify_payload(payload, shared = shared_mori, original = frame)

  # A payload that measured well but resolved to the wrong rows would score
  # perfectly on both oracles. Check the mori route still names the same rows
  # the fat payload does before believing its bytes (M26 review D21).
  stopifnot(identical(as.integer(mori_payload$split$in_id),
                      as.integer(payload$split$in_id)))
  stopifnot(identical(
    rsample::analysis(mori_payload$inner$splits[[1L]]),
    rsample::analysis(payload$inner$splits[[1L]])
  ))

  routes <- list(
    fat = list(payload = payload, args = NULL),
    lean = list(payload = lean, args = list(shared = frame, worker = worker)),
    mori = list(payload = mori_payload, args = NULL)
  )

  cat("--", label, "--\n")
  cat(sprintf("closed-form oracle for the lean payload (n=%d, v=%d, inner_v=%d): %d B\n",
              nrow(frame), v, inner_v, predicted_lean_bytes(nrow(frame), v, inner_v)))
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

wire_report("orchestration fixture (90x5, v=3/v=3)", data, nested, v = 3, inner_v = 3)

# M23's fixture, exactly: fixture_design() in tests/testthat/test-parallel-payload.R
# is v = 5, inner_v = 5, n = 5000, p = 20 under set.seed(2). An earlier draft
# used inner_v = 3 under set.seed(1) and still labelled it "M23's fixture",
# which put a 4-copy fat count into three documents against M23's test-locked
# 6L (test-parallel-payload.R:145) -- M26 review D2/D3.
big_data <- payload_fixture_data()
set.seed(2)
big_design <- nested_resamples(
  big_data,
  outside = rsample::vfold_cv(v = 5),
  inside = rsample::vfold_cv(v = 5)
)
wire_report("M23 fixture (5000x21, v=5/v=5, seed 2)", big_data, big_design,
            v = 5, inner_v = 5)

cat("== summary ==\n")
for (n_workers in names(results)) {
  r <- results[[n_workers]]
  cat(sprintf("%s workers: by-value %s, mori %s, daemon mapped the region %s\n",
              n_workers,
              if (r$by_value) "identical to serial" else "DIVERGED",
              if (r$mori) "identical to serial" else "DIVERGED",
              if (r$transport$shared_in_daemon && r$transport$name_matches) "yes" else "NO"))
}

# Shared regions are freed when their objects are garbage-collected and on a
# clean exit; prune_shared() recovers anything a killed process left behind.
# Cheap insurance in a script that creates several regions.
invisible(mori::prune_shared())
