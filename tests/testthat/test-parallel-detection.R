# Detection of the parallel dispatch branch.
#
# The threshold is tune's, not ours (D-018): tune goes parallel only at two or
# more connected daemons, so "parallel" means the same thing in both packages.
# RR03 B1 read that from tune:::choose_framework and flagged the test-design
# consequence these tests exist to serve -- a suite that starts ONE daemon and
# believes it exercised the parallel path is comparing serial to serial.

test_that("the dispatch threshold is two daemons, matching tune's", {
  expect_false(use_parallel(0L))
  expect_false(use_parallel(1L))
  expect_true(use_parallel(2L))
  expect_true(use_parallel(8L))
})

test_that("a NULL or missing worker count is not parallel", {
  expect_false(use_parallel(NULL))
  expect_false(use_parallel(NA_integer_))
  expect_false(use_parallel(integer(0)))
})

test_that("mirai_workers() reports 0 when mirai is not installed", {
  local_mocked_bindings(is_mirai_installed = function() FALSE)
  expect_identical(mirai_workers(), 0L)
})

test_that("mirai_workers() counts connected daemons", {
  skip_if_not_installed("mirai")
  skip_on_cran()

  mirai::daemons(0)
  expect_identical(mirai_workers(), 0L)

  mirai::daemons(2)
  on.exit(mirai::daemons(0), add = TRUE)
  expect_identical(mirai_workers(), 2L)
  expect_true(use_parallel(mirai_workers()))
})

test_that("the branch a run took is recorded out-of-band, not on the result", {
  # BC1 needs a test to prove the parallel branch ran, but the same criterion
  # demands the parallel result be identical() to the serial one -- so the
  # evidence cannot live on the returned object. It lives in an internal
  # environment instead, which is what makes both halves of BC1 satisfiable.
  reset_dispatch_record()
  expect_null(last_dispatch())

  record_dispatch("serial")
  expect_identical(last_dispatch(), "serial")

  record_dispatch("parallel")
  expect_identical(last_dispatch(), "parallel")
})

test_that("the probe reaches every daemon, not just a loadable one", {
  # AC1's second layer: the seam tests in test-parallel-classify.R fabricate the
  # per-daemon answers, so this is the one place a genuinely heterogeneous pool
  # is built and probed for real.
  skip_if_no_daemons()
  skip_if_not_installed("ranger")
  skip_on_os("windows")

  lean <- lean_library()
  skip_if(is.null(lean), "could not build a scratch library (no symlinks?)")

  # Bounded twice over: setTimeLimit turns a hang into an error (system.time
  # could only ever flag a slow run after it returned -- M09's lesson), and the
  # elapsed assertion below states the bound AC4 asks for.
  on.exit(mirai::daemons(0), add = TRUE)
  setTimeLimit(elapsed = 180, transient = TRUE)
  on.exit(setTimeLimit(), add = TRUE, after = FALSE)

  started <- Sys.time()
  connections <- start_mixed_daemons(lean)
  skip_if(connections < 2, "the heterogeneous pool did not assemble")

  # The precondition, asserted rather than assumed: the two daemons really do
  # have different libraries. Without this the test reports a comfortable green
  # whenever the fixture quietly fails and both daemons share one library --
  # which is what setting only R_LIBS_USER did, on a machine whose packages live
  # in the site library.
  libs <- collect_bounded(mirai::everywhere(.libPaths()), seconds = 30)
  expect_false(identical(libs[[1]], libs[[2]]))

  # ranger stands in for nestedtune: installed here, absent from the scratch
  # library, and not something mirai drags in. Probing for nestedtune itself
  # would need it installed, and priming a daemon with everywhere() reaches
  # every daemon -- erasing the very heterogeneity under test.
  probe_started <- Sys.time()
  status <- daemons_load_status(package = "ranger", timeout = 30000)
  probe_secs <- as.numeric(Sys.time() - probe_started, units = "secs")
  elapsed <- as.numeric(Sys.time() - started, units = "secs")

  # TEMPORARY DIAGNOSTIC (M24 T8) -- removed once F15's mechanism is named.
  dbg <- function(...) cat("[m24-dbg]", ..., "\n", file = stderr())
  dbg("probe took", round(probe_secs, 2), "s of a 30 s bound")
  dbg("status:", paste(names(status), unlist(lapply(status, function(v)
    paste(format(v), collapse = "/"))), sep = "=", collapse = " "))
  dbg("host libPaths:", paste(.libPaths(), collapse = " | "))
  dbg("host ranger:", paste(find.package("ranger", quiet = TRUE), collapse = " | "))
  syms <- daemon_symbol_manifest("ranger")
  dbg("manifest n =", length(syms))
  seen <- collect_bounded(mirai::everywhere(
    list(lib = .libPaths(), has = requireNamespace(package, quietly = TRUE)),
    .args = list(package = "ranger")
  ), seconds = 30)
  for (i in seq_along(seen)) {
    dbg("daemon", i, "class:", paste(class(seen[[i]]), collapse = "/"),
        "value:", paste(utils::capture.output(utils::str(seen[[i]])),
                        collapse = " ~ "))
  }
  again <- collect_bounded(mirai::everywhere(
    if (requireNamespace(package, quietly = TRUE)) {
      list(loaded = TRUE, missing = setdiff(symbols, ls(asNamespace(package))))
    } else {
      list(loaded = FALSE, missing = character())
    },
    .args = list(package = "ranger", symbols = syms)
  ), seconds = 30)
  for (i in seq_along(again)) {
    dbg("reprobe", i, "class:", paste(class(again[[i]]), collapse = "/"),
        "value:", paste(utils::capture.output(utils::str(again[[i]])),
                        collapse = " ~ "))
  }

  # The M07 defect, in its natural habitat: one mirai() task lands on one
  # daemon, so this pool answered TRUE and dispatched, and every fold routed to
  # the lean daemon came back as an opaque worker failure.
  expect_identical(status$total, 2L)
  expect_identical(status$cannot_load, 1L)
  expect_identical(status$no_answer, 0L)
  expect_identical(status$outcome, "cannot_load")

  expect_error(
    check_daemons_can_load(status),
    class = "nestedtune_daemons_cannot_load"
  )
  expect_lt(elapsed, 150)
})

# --- A daemon that loads the package but cannot run the fold (M24) ----------
#
# The failure M23 made reachable: dispatch resolves `rehydrate_payload` through
# the daemon's own namespace, so a daemon holding a build from before that
# symbol existed loads the package, answers the old pre-flight TRUE, and then
# raises "attempt to apply non-function" on every fold. A version comparison
# cannot see it -- DESCRIPTION has read 0.0.0.9000 since M01, so the stale
# daemon reports this session's own string.
#
# Proved here against a real pool rather than a stubbed install: asking for a
# name no build defines produces exactly the shape a stale build produces, and
# needs no second library. The stub-install route was weighed at the plan gate
# and declined -- priming reaches every daemon, erasing the heterogeneity such
# a fixture exists to create (see the ranger test above).

test_that("a primed pool matches the host's namespace exactly", {
  skip_if_no_daemons()

  # The precondition for the whole approach, asserted rather than assumed. The
  # manifest is `ls()` of the host's namespace, and host and daemons must agree
  # under BOTH ways the suite runs -- primed by pkgload here, installed under
  # R CMD check. A mismatch either way would refuse every parallel run.
  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  status <- daemons_load_status(timeout = 30000)
  expect_identical(status$outcome, "ok")
  expect_identical(status$incompatible, 0L)
  expect_identical(status$missing_symbols, character())
})

test_that("a symbol no build defines is reported by every daemon that loaded", {
  skip_if_no_daemons()

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  absent <- "nestedtune_symbol_no_build_defines"
  status <- daemons_load_status(
    symbols = c(daemon_symbol_manifest(), absent), timeout = 30000
  )

  # Every daemon loaded the package -- this is not the cannot_load path -- and
  # every one of them is short the same symbol.
  expect_identical(status$total, 2L)
  expect_identical(status$cannot_load, 0L)
  expect_identical(status$no_answer, 0L)
  expect_identical(status$incompatible, 2L)
  expect_identical(status$missing_symbols, absent)
  expect_identical(status$outcome, "incompatible")

  err <- expect_error(
    check_daemons_can_load(status),
    class = "nestedtune_daemons_incompatible"
  )
  expect_match(conditionMessage(err), absent)
})

# --- A pool that cannot be stopped says so (M24) ----------------------------
#
# M15 verified that `stop_mirai()` cancels nothing on a pool started with
# `dispatcher = FALSE`: it returns FALSE per element and the tasks run to
# completion. dispatch_folds()'s unconditional cancelling on.exit() is therefore
# inert there, and an interrupted run leaves every outstanding fold computing.
# M15 scoped the roxygen to say so; M24 says it where the user is, because a
# caveat in the docs is met only by someone already looking for it.
#
# A warning and not a refusal: the pool computes correct results, so GP3's
# refuse-provably-invalid line does not reach a configuration that is merely
# degraded.

test_that("the two pool kinds are distinguishable, and the count cannot do it", {
  skip_if_no_daemons()
  on.exit(mirai::daemons(0), add = TRUE)

  mirai::daemons(0)
  mirai::daemons(2)
  expect_true(pool_is_cancellable())
  with_dispatcher <- mirai::status()$connections

  mirai::daemons(0)
  mirai::daemons(2, dispatcher = FALSE)
  expect_false(pool_is_cancellable())

  # The reason use_parallel() cannot make this call itself: it asks how many
  # daemons are connected, and both pools answer the same.
  expect_identical(mirai::status()$connections, with_dispatcher)
  expect_true(use_parallel())
})

test_that("only the uncancellable pool warns, and it names the remedy", {
  # Driven through the argument seam so both branches are reachable without
  # standing up two pools, the same seam check_daemons_can_load() opens.
  expect_no_warning(warn_if_not_cancellable(cancellable = TRUE))

  w <- expect_warning(
    warn_if_not_cancellable(cancellable = FALSE),
    class = "nestedtune_pool_not_cancellable"
  )
  msg <- conditionMessage(w)
  expect_match(msg, "cannot be cancelled")
  # The consequence, not just the fact: folds keep computing after an interrupt.
  expect_match(msg, "keep computing")
  expect_match(msg, "mirai::daemons\\(n\\)")
})

test_that("a run on an uncancellable pool warns exactly once", {
  skip_if_no_daemons()
  skip_if_not_installed("recipes")

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons_undispatched(2)

  d <- make_reg_data()
  wf <- det_workflow(d)
  nested <- det_nested(d)

  warnings <- character()
  res <- withCallingHandlers(
    without_pkgload_warning(
      nested_tune_grid(wf, nested, grid = det_grid(), metrics = reg_metrics())
    ),
    nestedtune_pool_not_cancellable = function(cnd) {
      warnings <<- c(warnings, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    }
  )

  # Once per run, not once per fold: dispatch_folds() is called once and the
  # design has three outer folds, so a per-fold site would show three.
  expect_length(warnings, 1L)
  expect_identical(last_dispatch(), "parallel")
  expect_identical(nrow(res), 3L)
})

test_that("a dispatcher-backed run warns not at all", {
  skip_if_no_daemons()
  skip_if_not_installed("recipes")

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  d <- make_reg_data()
  wf <- det_workflow(d)

  expect_no_condition(
    without_pkgload_warning(
      nested_tune_grid(wf, det_nested(d), grid = det_grid(),
                       metrics = reg_metrics())
    ),
    class = "nestedtune_pool_not_cancellable"
  )
  expect_identical(last_dispatch(), "parallel")
})

test_that("dispatch_folds warns once per call, whatever it is dispatching", {
  # The seam the previous two tests reach through nested_tune_grid(), driven
  # directly with stand-in payloads: the warning is a property of dispatching to
  # this pool, not of the folds being real, and it is the number of CALLS that
  # sets the count -- three payloads through one call is still one warning.
  skip_if_no_daemons()

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons_undispatched(2)

  fold_record <- function(payload, object, grid, metrics) {
    list(
      completed = TRUE,
      metrics = data.frame(.estimate = as.double(payload$seed)),
      selected = data.frame(seed = payload$seed),
      grid = data.frame(.config = "pre0_mod1_post0"),
      notes = data.frame(
        location = character(0), type = character(0), note = character(0)
      )
    )
  }
  local_mocked_bindings(fold_task = fold_record)
  payloads <- lapply(1:3, function(i) list(seed = i))

  warnings <- character()
  out <- withCallingHandlers(
    without_pkgload_warning(
      dispatch_folds(payloads, object = NULL, grid = NULL, metrics = NULL)
    ),
    nestedtune_pool_not_cancellable = function(cnd) {
      warnings <<- c(warnings, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    }
  )

  expect_length(warnings, 1L)
  expect_identical(last_dispatch(), "parallel")
  expect_identical(
    vapply(out, function(x) x$selected$seed, numeric(1)), c(1, 2, 3)
  )
})
