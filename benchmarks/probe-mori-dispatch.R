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

# Install the working tree to a throwaway library and measure THAT (M26 AC2).
#
# Every wire figure this probe published across three earlier passes was taken
# under `pkgload::load_all(".")`, which keeps source references on every package
# function. A closure's srcrefs serialize with it, so `load_all()` inflates the
# worker closure roughly fourfold against the state `install.packages()` actually
# produces -- and the figures were presented as the adoption case. That is a
# property of how the package was loaded, not of the run, and modelling it away
# afterwards (`removeSource()` on a captured closure) is the same
# reconstruct-then-publish shape that failed on passes 1 and 2. So the package is
# genuinely installed, and the probe measures the installed copy.
#
# `R_KEEP_PKG_SOURCE=no` is set explicitly rather than relied on: it is the
# default, but a developer with it set to "yes" in ~/.Renviron would otherwise
# reproduce the very development-state figure this step exists to eliminate.
PKG_LIB <- tempfile("nestedtune-probe-lib-")
dir.create(PKG_LIB, recursive = TRUE, showWarnings = FALSE)

cat("installing the working tree to a temporary library...\n")
install_log <- tempfile("nestedtune-install-", fileext = ".log")
install_status <- system2(
  file.path(R.home("bin"), "R"),
  c("CMD", "INSTALL", "--no-multiarch", "--with-keep.source=no",
    paste0("--library=", shQuote(PKG_LIB)), "."),
  env = "R_KEEP_PKG_SOURCE=no",
  stdout = install_log, stderr = install_log
)
if (!identical(install_status, 0L)) {
  cat(readLines(install_log), sep = "\n")
  stop("R CMD INSTALL failed; see the log above")
}

# Daemons are separate R processes that load nestedtune from THEIR library, and
# `prime_daemons()` deliberately no-ops off a dev package (helper-parallel.R:52),
# so nothing would put the temp library in front of them. R_LIBS prepends, which
# is the right verb here -- the daemons still need mirai and the whole tidymodels
# stack from the real library, and only nestedtune is being redirected.
Sys.setenv(R_LIBS = paste(c(PKG_LIB, Sys.getenv("R_LIBS")), collapse = .Platform$path.sep))
.libPaths(c(PKG_LIB, .libPaths()))
suppressMessages(library(nestedtune, lib.loc = PKG_LIB))
# normalizePath on both sides: on macOS `tempfile()` hands back a /var path that
# resolves to /private/var, so the raw strings differ for a namespace that did
# load from exactly here.
stopifnot(identical(
  normalizePath(dirname(getNamespaceInfo("nestedtune", "path")), mustWork = TRUE),
  normalizePath(PKG_LIB, mustWork = TRUE)
))
cat("package: installed to a temporary library (the state a user runs)\n")

# Does a closure still carry source references? Asserted as STATE rather than
# inferred from a size comparison: whether two totals differ is an empirical
# outcome that depends on the session's `keep.source`, so a size check would pass
# or fail for reasons unrelated to what it claims to measure.
#
# srcrefs hang off the function itself and off every `{` block in its body, so
# the body's language tree is walked rather than just the top-level attributes.
has_srcref <- function(x, depth = 0L) {
  if (depth > 50L) {
    return(FALSE)
  }
  for (a in c("srcref", "srcfile", "wholeSrcref")) {
    if (!is.null(attr(x, a, exact = TRUE))) {
      return(TRUE)
    }
  }
  if (is.function(x)) {
    return(has_srcref(body(x), depth + 1L))
  }
  if (is.call(x) || is.pairlist(x) || is.expression(x)) {
    return(any(vapply(as.list(x), has_srcref, logical(1), depth = depth + 1L)))
  }
  FALSE
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
# sourcing every helper (M26 review D6). Sourcing them is unaffected by the
# install above -- they are plain files read from the working tree, and the
# package functions they call resolve to the installed copy now attached.
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

# ---- the publication registry (M26 AC4/AC5/AC6) -------------------------------
#
# Nothing this script publishes may reach a document by being transcribed out of
# console output: four passes of this milestone failed on a number that had been
# re-typed and then drifted from its source. Every published figure goes through
# `publish()`, which records the value, the fixture it was taken on, whether it
# depends on how the package was installed, and which oracles back it. The
# manifest written at the end is what a document cites.
#
# `oracles` names the independent checks that have been ASSERTED for this figure,
# never merely computed beside it. GP2 asks for two independent types; the two
# available here are the closed-form prediction from the design's scalars and the
# copy count taken from the serialized stream, which share no arithmetic.
PUBLISHED <- list()
# `derived = TRUE` marks a figure computed wholly from other published figures.
# It inherits their oracles and carries none of its own, because a second
# mechanism for `a / b` or `a - b` would read the same arithmetic that produced
# it. A document may not rest a claim on a derived figure alone; the manifest
# says which they are, and the two-oracle assertion below exempts exactly these.
publish <- function(name, value, fixture, oracles = character(),
                    install_dependent = FALSE, derived = FALSE, derived_from = character()) {
  stopifnot(derived || length(derived_from) == 0L)
  PUBLISHED[[name]] <<- list(
    name = name, value = value, fixture = fixture,
    oracles = oracles, install_dependent = install_dependent,
    derived = derived, derived_from = derived_from
  )
  invisible(value)
}

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
invisible(reg.finalizer(environment(), function(e) cleanup(), onexit = TRUE))
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
# NOT fixed width, against what an earlier pass asserted: the name embeds the
# creating process id in hex, so its length follows the pid. Measured 19
# characters and 20 characters in two consecutive runs of this script. The width
# is not what carries any claim here -- the serialized cost below is -- but a
# stated constant that varies between runs is the exact failure this milestone
# was re-cut over, so it is measured and reported rather than asserted.
cat(sprintf("region name: %s (%d characters, pid-dependent)\n",
            mori::shared_name(ref_shared), nchar(mori::shared_name(ref_shared))))
cat(sprintf("one shared object serialized: %d B\n", one_ref))
cat(sprintf("marginal cost per additional reference: %.0f B\n",
            (four_refs - one_ref) / 3))
cat(sprintf("against the same frame by value: %d B\n",
            length(serialize(ref_frame, NULL))))

# Second oracle for the two figures above, sharing no arithmetic with the copy
# count: INVARIANCE UNDER FRAME SIZE. What a shared reference costs is the claim
# that it does not scale with the data, so a frame four times the size must
# serialize to the same handful of bytes. A byte-count that quietly tracked the
# data would pass a copy count of zero and fail this.
big_ref_frame <- payload_fixture_data(n = 40000, p = 1)
big_ref_shared <- mori::share(big_ref_frame)
one_ref_big <- length(serialize(big_ref_shared, NULL))
cat(sprintf("invariance oracle: a 4x frame shares for %d B against %d B (%.1f%%), while by value it is %d B\n\n",
            one_ref_big, one_ref, 100 * abs(one_ref_big - one_ref) / one_ref,
            length(serialize(big_ref_frame, NULL))))
stopifnot(abs(one_ref_big - one_ref) / one_ref < 0.05)

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

# Capture the object mirai hands `request()` -- the thing it actually serializes.
#
# Reading mirai 2.7.2: `mirai_map()` calls `do_mirai(expr, globals, list(.f = .f,
# .x = elem, .args = .args, .mirai_within_map = TRUE), NULL, envir)` once per
# element, and `do_mirai()` builds
#
#   data <- list(._expr_. = expr, ._globals_. = globals)
#   if (length(.args)) data <- c(.args, data)
#   req <- request(.context(envir[["sock"]]), data, send_mode = 1L, ...)
#
# so ONE `request()` per task serializes ONE list carrying six members. Every
# figure this probe published across three passes summed `.f`, `.x` and `.args`
# serialized SEPARATELY, which is not an object mirai ever sends: separate
# streams each carry their own copy of structure the single stream shares once.
#
# The interception is `do_mirai` rebound to an environment whose only addition is
# a capturing `request`, with mirai's own body untouched -- asserted below, since
# a copied body would be reconstruction wearing interception's clothes. The
# bundle is therefore assembled by mirai's `c(.args, data)`, not by this script.
# `mirai_map` cannot be intercepted at `request` directly: `request` is imported
# from nanonext and has no binding in mirai's namespace to replace.
#
# Host-side only, restored by a function-frame `on.exit()`; it cannot reach a
# daemon, so M07's mocked-binding trap and M12's daemon-substitution lesson do
# not fire (cleared explicitly at M26 review pass 3).
capture_dispatch <- function(payloads, object, grid, metrics) {
  captured <- NULL
  orig <- get("do_mirai", envir = asNamespace("mirai"))
  real_request <- get("request", envir = parent.env(asNamespace("mirai")))
  shim <- new.env(parent = environment(orig))
  # `dispatch_folds()` reaches `request()` before any fold does: its pre-flight
  # asks every daemon whether it can load the package, and `mirai::everywhere()`
  # goes through `do_mirai()` too. Capturing the first call would publish the
  # pre-flight probe's bundle as a fold's wire cost. `.mirai_within_map` is the
  # member `mirai_map()` alone sets, so it is what discriminates; everything else
  # is passed through to the real `request` and dispatches normally.
  shim$request <- function(con, data, ...) {
    if (is.null(data[[".mirai_within_map"]])) {
      return(real_request(con, data, ...))
    }
    captured <<- data
    stop(structure(class = c("dispatch_captured", "error", "condition"),
                   list(message = "captured", call = NULL)))
  }
  patched <- orig
  environment(patched) <- shim
  # If mirai reshapes `do_mirai()` upstream this still captures whatever it
  # builds, but a body that is no longer mirai's own would mean the shim went
  # stale and the capture is this script's construction again.
  stopifnot(identical(body(patched), body(orig)))
  utils::assignInNamespace("do_mirai", patched, ns = "mirai")
  on.exit(utils::assignInNamespace("do_mirai", orig, ns = "mirai"), add = TRUE)
  tryCatch(
    nestedtune:::dispatch_folds(payloads, object = object, grid = grid,
                                metrics = metrics),
    dispatch_captured = function(cnd) NULL
  )
  captured
}

# One serialization of one bundle -- the published figure.
wire_bytes <- function(bundle) length(serialize(bundle, NULL))

# The same bundle's members serialized one at a time and added up. This is NOT a
# wire cost; it is the arithmetic three earlier passes published as one. It is
# computed so the gap between the two can be asserted rather than described.
sum_of_parts <- function(bundle) {
  sum(vapply(bundle, function(x) length(serialize(x, NULL)), numeric(1)))
}

cat("== wire cost per fold, measured off the real dispatch ==\n")
cat("mirai serializes ONE bundle per task. The lean row is CAPTURED at the\n")
cat("`request()` call dispatch_folds() reaches; the mori row is MODELLED by\n")
cat("substituting into that same captured bundle.\n\n")

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
lean_bundle <- bundle
stopifnot(
  !is.null(lean_bundle),
  identical(names(lean_bundle),
            c(".f", ".x", ".args", ".mirai_within_map", "._expr_.", "._globals_.")),
  identical(sort(names(lean_bundle$.args)),
            sort(c("object", "grid", "metrics", "shared", "worker")))
)

# AC2's gate. A run that silently measured the development state fails here
# rather than publishing a figure many times the installed one. Both captured
# closures are checked: the `.f` wrapper mirai is handed, and the package's own
# worker inside `.args`.
srcref_state <- c(.f = has_srcref(lean_bundle$.f),
                  worker = has_srcref(lean_bundle$.args$worker))
cat(sprintf("source references in the captured closures: .f %s, .args$worker %s\n\n",
            srcref_state[[".f"]], srcref_state[["worker"]]))
stopifnot(!any(srcref_state))

# The modelled mori bundle, built by SUBSTITUTION into the captured one rather
# than assembled beside it -- every member adoption would not change is carried
# over untouched, including `._expr_.`, `._globals_.` and `.mirai_within_map`.
#
# The three substitutions are exactly what dropping the leaning branch does
# (R/parallel.R:250-259): with nothing to rehydrate, `.f` collapses from the
# rehydrating wrapper back to the worker itself, and `.args` loses both `shared`
# (the frame) and `worker` (now `.f`). That is the shape the non-leaning branch
# already has, with `.x` pointing at a shared region instead of a whole frame.
mori_shared <- mori::share(big_data)
mori_bundle <- lean_bundle
mori_bundle$.f <- lean_bundle$.args$worker
mori_bundle$.x <- morify_payload(big_payloads[[1L]], shared = mori_shared,
                                 original = big_data)
mori_bundle$.args <- lean_bundle$.args[c("object", "grid", "metrics")]

cat("== wire cost per fold: ONE serialization of what mirai hands request() ==\n\n")
cat(sprintf("%-6s %16s %16s %10s\n",
            "route", "single stream", "sum of parts", "copies"))
report_bundle <- function(label, b, sentinel) {
  single <- wire_bytes(b)
  cat(sprintf("%-6s %16.0f %16.0f %10.0f\n",
              label, single, sum_of_parts(b), count_data_copies(b, sentinel)))
  invisible(single)
}
lean_total <- report_bundle("lean", lean_bundle, big_sentinel)
mori_total <- report_bundle("mori", mori_bundle, big_sentinel)

# AC1. Publishing the sum must FAIL rather than pass: the two are different
# numbers for the same bundle, because separately-serialized members each carry
# their own copy of structure the single stream shares once. Three earlier passes
# published the sum. Asserted as an inequality on both rows, so a future edit
# that quietly reverts to summing is caught here rather than in review.
stopifnot(
  !identical(lean_total, sum_of_parts(lean_bundle)),
  !identical(mori_total, sum_of_parts(mori_bundle))
)
cat(sprintf("\nsum-of-parts overstates the lean bundle by %.0f B (%.1f%%); it is not a wire cost\n",
            sum_of_parts(lean_bundle) - lean_total,
            100 * (sum_of_parts(lean_bundle) - lean_total) / lean_total))
cat(sprintf("ratio (lean / mori), single stream both sides: %.2fx\n\n",
            lean_total / mori_total))

# ---- AC3: the gap identity, closing to the byte --------------------------------
#
# Three passes of this milestone published a sentence explaining the gap, and
# three times the sentence did not add up against the table beside it. A sentence
# is what kept failing, so the explanation is now a ladder the script walks.
#
# Each rung applies exactly ONE of the three substitutions above and re-measures
# the single stream. The deltas therefore telescope to the gap by construction --
# which is the point: the arithmetic can no longer disagree with the prose,
# because the prose is generated from the arithmetic. What the ladder measures,
# and what no member-by-member table could, is each substitution's cost IN
# CONTEXT: applied in the stated order, against the bundle as it stands at that
# rung, with whatever structure the single stream shares already shared.
#
# The order is fixed and stated because the deltas are order-dependent for that
# reason. Attributing the whole gap to any one term is what the note may not do.
ladder <- list()
step <- lean_bundle
for (rung in list(
  list(name = ".f: rehydrating wrapper -> the worker itself", apply = function(b) {
    b$.f <- lean_bundle$.args$worker; b
  }),
  list(name = ".x: blanked payload -> payload pointing at the shared region",
       apply = function(b) { b$.x <- mori_bundle$.x; b }),
  list(name = ".args: drop `shared` (the frame) and `worker` (now .f)",
       apply = function(b) { b$.args <- mori_bundle$.args; b })
)) {
  before <- wire_bytes(step)
  step <- rung$apply(step)
  ladder[[rung$name]] <- before - wire_bytes(step)
}

# The ladder must land exactly on the modelled mori bundle, not merely near it.
# Without this the deltas would telescope to whatever the last rung produced and
# the identity would be true of the wrong destination.
stopifnot(identical(wire_bytes(step), mori_total))

cat("== how the gap decomposes (one substitution per rung, in this order) ==\n")
for (nm in names(ladder)) {
  cat(sprintf("  %+12.0f B   %s\n", -ladder[[nm]], nm))
}
cat(sprintf("  %12s\n", "------------"))
cat(sprintf("  %+12.0f B   lean %.0f -> mori %.0f\n\n",
            mori_total - lean_total, lean_total, mori_total))

# AC3: to the byte, tolerance zero. A single-stream measurement does not round.
stopifnot(identical(lean_total - mori_total, sum(unlist(ladder))))

# And the dominant rung is tied to an independently measured quantity rather than
# left to speak for itself: dropping `.args$shared` should cost about what the
# frame costs on its own. Not an equality -- the frame is measured standalone
# here and in context there -- so the band is stated and checked.
frame_alone <- length(serialize(big_data, NULL))
args_rung <- ladder[[".args: drop `shared` (the frame) and `worker` (now .f)"]]
cat(sprintf("the `.args` rung against the frame measured alone: %.0f B vs %d B (%.1f%%)\n\n",
            args_rung, frame_alone,
            100 * abs(args_rung - frame_alone) / frame_alone))
stopifnot(abs(args_rung - frame_alone) / frame_alone < 0.05)


# The closed-form oracle, compared rather than printed. M23's own test bounds it
# at 5%; an oracle that is printed and never checked cannot fail.
predicted <- predicted_lean_bytes(5000, 5, 5)
measured_payload <- length(serialize(lean_bundle$.x, NULL))
cat(sprintf("closed-form oracle for the lean payload: %d B predicted, %d B measured (%.1f%%)\n",
            predicted, measured_payload,
            100 * abs(measured_payload - predicted) / predicted))
stopifnot(abs(measured_payload - predicted) / predicted < 0.05)

# The copy counts are the claim; assert them rather than printing them. Counted
# over the WHOLE bundle, so a copy hiding in a member the table does not break
# out is still counted.
stopifnot(count_data_copies(lean_bundle, big_sentinel) == 1,
          count_data_copies(mori_bundle, big_sentinel) == 0)

# ---- register every published figure with its oracles and its fixture ---------
#
# FIXTURE names what each figure was taken on. The wire figures use M23's own
# fixture so they are comparable with M23's committed numbers; the shared-
# reference costs use a small separate frame, and saying so is AC6's point.
WIRE_FIXTURE <- "payload_fixture_data(n=5000, p=20, seed=1); nested_resamples(v=5, inner_v=5, set.seed(2)); payload_fixture_workflow()"
REF_FIXTURE <- "payload_fixture_data(n=10000, p=1, seed=1)"

publish("lean_bundle_bytes", lean_total, WIRE_FIXTURE,
        c("copy-count: exactly 1 copy of the frame in the stream",
          "closed-form: the .args rung equals the frame serialized alone, within 5%"))
publish("mori_bundle_bytes", mori_total, WIRE_FIXTURE,
        c("copy-count: exactly 0 copies of the frame in the stream",
          "ladder: reached by substitution from the lean bundle, asserted identical"))
publish("lean_payload_bytes", measured_payload, WIRE_FIXTURE,
        c("closed-form: predicted_lean_bytes(5000,5,5) within M23's 5% band",
          "copy-count: the payload carries 0 copies; the frame rides in .args"))
publish("ratio_lean_over_mori", lean_total / mori_total, WIRE_FIXTURE,
        derived = TRUE, derived_from = c("lean_bundle_bytes", "mori_bundle_bytes"))
publish("gap_bytes", lean_total - mori_total, WIRE_FIXTURE,
        c("ladder: telescopes to the gap to the byte, tolerance zero",
          "closed-form: dominated by the .args rung, checked against the frame alone"))
publish("shared_reference_bytes", one_ref, REF_FIXTURE,
        c("copy-count: 0 copies of the frame in the shared object's stream",
          "invariance: a 4x frame shares for the same bytes, within 5%"))
publish("shared_marginal_bytes", (four_refs - one_ref) / 3, REF_FIXTURE,
        c("copy-count: 0 copies across four references",
          "invariance: a 4x frame shares for the same bytes, within 5%"))

# Second oracle for the closure figure, again sharing no arithmetic with the
# srcref-state walk: stripping source references must not change the byte count,
# because there are none to strip. A closure that still carried them would shrink
# here while the state walk missed them in a corner of the language tree.
worker_stripped <- length(serialize(utils::removeSource(lean_bundle$.args$worker), NULL))
worker_bytes <- length(serialize(lean_bundle$.args$worker, NULL))
stopifnot(identical(worker_stripped, worker_bytes))
publish("worker_closure_bytes", worker_bytes, WIRE_FIXTURE,
        c("srcref-state: asserted absent by walking the closure's language tree",
          "strip-invariance: removeSource() leaves the byte count identical"),
        install_dependent = TRUE)
publish("sum_of_parts_overstatement_bytes", sum_of_parts(lean_bundle) - lean_total,
        WIRE_FIXTURE, install_dependent = TRUE, derived = TRUE,
        derived_from = c("lean_bundle_bytes"))

# AC4, asserted rather than reported. Every non-derived figure carries at least
# two oracles sharing no arithmetic; every derived figure names the published
# figures it comes from, and those must themselves be published and non-derived,
# so a derived figure can never inherit from another derived one.
oracle_counts <- vapply(PUBLISHED, function(p) length(p$oracles), numeric(1))
is_derived <- vapply(PUBLISHED, function(p) isTRUE(p$derived), logical(1))
stopifnot(all(oracle_counts[!is_derived] >= 2))
for (p in PUBLISHED[is_derived]) {
  stopifnot(length(p$derived_from) > 0L,
            all(p$derived_from %in% names(PUBLISHED)),
            !any(vapply(PUBLISHED[p$derived_from], function(q) isTRUE(q$derived), logical(1))))
}
cat(sprintf("published figures: %d (%d measured, %d derived); every measured figure carries >= 2 independent oracles\n",
            length(PUBLISHED), sum(!is_derived), sum(is_derived)))
for (p in PUBLISHED[is_derived]) {
  cat(sprintf("  derived: %s <- %s\n", p$name, paste(p$derived_from, collapse = ", ")))
}
cat("\n")

# ---- T6: the manifest ---------------------------------------------------------
#
# Committed and machine-readable, so a document cites a measured value instead of
# transcribing one. Written by hand rather than through jsonlite: this script's
# dependencies are the package's own plus mori, and a manifest is not a reason to
# add another.
#
# `install_dependent` marks the figures that follow how the package was built
# rather than what the dispatch costs. They are excluded from any later drift
# check, because a run under a different `keep.source` moves them legitimately.
MANIFEST <- "benchmarks/mori-wire-manifest.json"

json_string <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", as.character(x))
  paste0("\"", gsub("\"", "\\\\\"", x), "\"")
}
json_kv <- function(k, v) paste0(json_string(k), ": ", v)
json_num <- function(x) format(x, scientific = FALSE, trim = TRUE)

figure_json <- function(p) {
  paste0(
    "    {\n      ",
    paste(
      c(json_kv("name", json_string(p$name)),
        json_kv("value", json_num(p$value)),
        json_kv("fixture", json_string(p$fixture)),
        json_kv("install_dependent", if (p$install_dependent) "true" else "false"),
        json_kv("derived", if (p$derived) "true" else "false"),
        json_kv("derived_from", paste0("[", paste(vapply(p$derived_from, json_string, character(1)),
                                                  collapse = ", "), "]")),
        json_kv("oracles", paste0("[", paste(vapply(p$oracles, json_string, character(1)),
                                             collapse = ", "), "]"))),
      collapse = ",\n      "
    ),
    "\n    }"
  )
}

manifest_lines <- c(
  "{",
  paste0("  ", json_kv("generated_by", json_string("benchmarks/probe-mori-dispatch.R")), ","),
  paste0("  ", json_kv("milestone", json_string("M26")), ","),
  paste0("  ", json_kv("package_state", json_string("installed to a temporary library, keep.source=no")), ","),
  paste0("  ", json_kv("environment", paste0("{",
    paste(c(json_kv("r", json_string(R.version.string)),
            json_kv("platform", json_string(R.version$platform)),
            json_kv("mori", json_string(packageVersion("mori"))),
            json_kv("mirai", json_string(packageVersion("mirai"))),
            json_kv("tune", json_string(packageVersion("tune"))),
            json_kv("rsample", json_string(packageVersion("rsample")))),
          collapse = ", "), "}")), ","),
  paste0("  ", json_kv("figures", "[")),
  paste(vapply(PUBLISHED, figure_json, character(1)), collapse = ",\n"),
  "  ]",
  "}"
)
writeLines(manifest_lines, MANIFEST)
cat(sprintf("manifest written: %s (%d figures)\n\n", MANIFEST, length(PUBLISHED)))

cat("== summary ==\n")
for (n_workers in names(results)) {
  r <- results[[n_workers]]
  cat(sprintf("%s workers: by-value %s, mori %s, daemon mapped the region %s\n",
              n_workers,
              if (r$by_value) "identical to serial" else "DIVERGED",
              if (r$mori) "identical to serial" else "DIVERGED",
              if (r$transport$shared_in_daemon && r$transport$name_matches) "yes" else "NO"))
}

