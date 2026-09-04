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
  status <- daemons_load_status(package = "ranger", timeout = 30000)
  elapsed <- as.numeric(Sys.time() - started, units = "secs")

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
    symbols = c(daemon_symbol_manifest(), absent),
    timeout = 30000
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
      nested_tune_grid(
        wf,
        det_nested(d),
        grid = det_grid(),
        metrics = reg_metrics()
      )
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

  fold_record <- function(
    payload,
    object,
    tuner,
    metrics,
    param_info,
    event_level,
    eval_time,
    control
  ) {
    list(
      completed = TRUE,
      metrics = data.frame(.estimate = as.double(payload$seed)),
      selected = data.frame(seed = payload$seed),
      inner_metrics = data.frame(.config = "pre0_mod1_post0"),
      notes = data.frame(
        location = character(0),
        type = character(0),
        note = character(0)
      )
    )
  }
  local_mocked_bindings(fold_task = fold_record)
  payloads <- lapply(1:3, function(i) list(seed = i))

  warnings <- character()
  out <- withCallingHandlers(
    without_pkgload_warning(
      dispatch_folds(payloads, object = NULL, tuner = NULL, metrics = NULL)
    ),
    nestedtune_pool_not_cancellable = function(cnd) {
      warnings <<- c(warnings, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    }
  )

  expect_length(warnings, 1L)
  expect_identical(last_dispatch(), "parallel")
  expect_identical(
    vapply(out, function(x) x$selected$seed, numeric(1)),
    c(1, 2, 3)
  )
})

# --- The start-first queue names real files (M57) ----------------------------
#
# `Config/testthat/start-first` in DESCRIPTION queues the slowest files first
# under parallel test files (M52). testthat matches each name against the
# files it found and says nothing about a name that matches none, so a file
# renamed or removed leaves a stale entry that quietly stops ordering
# anything. The check reads the field the way testthat does -- names split on
# commas and whitespace -- and resolves each against the test directory.

start_first_names <- function(description) {
  field <- read.dcf(description, fields = "Config/testthat/start-first")[[1L]]
  if (is.na(field)) {
    return(character())
  }
  names <- strsplit(field, "[[:space:],]+")[[1L]]
  names[nzchar(names)]
}

# The `start-first` names that no `test-<name>.R` in `dir` answers to.
unresolved_start_first <- function(description, dir) {
  names <- start_first_names(description)
  names[!file.exists(file.path(dir, paste0("test-", names, ".R")))]
}

test_that("every Config/testthat/start-first name resolves to a test file", {
  # `system.file()` is pkgload's shim under `devtools::test()` and the
  # installed package's copy under `R CMD check`; both carry the Config field.
  description <- system.file("DESCRIPTION", package = "nestedtune")
  expect_true(file.exists(description))

  names <- start_first_names(description)
  # The check is empty if the field is, and an empty field would be its own
  # regression: M52 put eleven names there.
  expect_gt(length(names), 0L)

  expect_identical(
    unresolved_start_first(description, test_path(".")),
    character()
  )
})

test_that("the start-first check reports a planted unknown name", {
  dir <- tempfile("start-first-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  description <- file.path(dir, "DESCRIPTION")
  writeLines(
    c(
      "Package: planted",
      "Config/testthat/start-first: parallel-detection, nonesuch-file,",
      "    hang-trace"
    ),
    description
  )

  # Read and split as the real field is, including the continuation line;
  # named, so a second unknown name could not hide behind a count.
  expect_identical(
    start_first_names(description),
    c("parallel-detection", "nonesuch-file", "hang-trace")
  )
  expect_identical(
    unresolved_start_first(description, test_path(".")),
    "nonesuch-file"
  )
})

# --- The probe carries the package list (M58) --------------------------------
#
# The seam tests in test-parallel-classify.R fabricate per-daemon answers; the
# two tests here send the list to a real pool. The first is the case the new
# report must stay silent in; the second is the heterogeneous pool, where one
# daemon's scratch library holds mirai and nanonext and nothing else.

test_that("the probe sends the package list, and a daemon that has them all reports none", {
  # Against a real pool: every package this session imports is loadable on a
  # primed daemon, so asking for two of them is the silent case the new
  # report must stay silent in.
  skip_if_no_daemons()

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  status <- daemons_load_status(pkgs = c("cli", "rlang"), timeout = 30000)
  expect_identical(status$outcome, "ok")
  expect_identical(status$missing_pkgs, 0L)
  expect_identical(status$missing_packages, character())

  # And a package no library holds is reported by every daemon, by name.
  status <- daemons_load_status(
    pkgs = c("cli", "nestedtune.no.such.package"),
    timeout = 30000
  )
  expect_identical(status$outcome, "missing_pkgs")
  expect_identical(status$missing_pkgs, 2L)
  expect_identical(status$missing_packages, "nestedtune.no.such.package")
})

test_that("a heterogeneous pool names the daemon that lacks a needed package", {
  # AC2: the same two-daemon pool the cannot-load test above builds, asked a
  # question both daemons can answer. `package = "mirai"` is the loadable
  # stand-in -- under devtools::test() neither daemon holds nestedtune, and
  # the cannot-load rung would take the class -- and ranger is what the
  # scratch library lacks.
  skip_if_no_daemons()
  skip_if_not_installed("ranger")
  skip_on_os("windows")

  lean <- lean_library()
  skip_if(is.null(lean), "could not build a scratch library (no symlinks?)")

  on.exit(mirai::daemons(0), add = TRUE)
  setTimeLimit(elapsed = 180, transient = TRUE)
  on.exit(setTimeLimit(), add = TRUE, after = FALSE)

  started <- Sys.time()
  connections <- start_mixed_daemons(lean)
  skip_if(connections < 2, "the heterogeneous pool did not assemble")

  status <- daemons_load_status(
    package = "mirai",
    pkgs = "ranger",
    timeout = 30000
  )
  elapsed <- as.numeric(Sys.time() - started, units = "secs")

  expect_identical(status$total, 2L)
  expect_identical(status$cannot_load, 0L)
  expect_identical(status$incompatible, 0L)
  expect_identical(status$no_answer, 0L)
  expect_identical(status$missing_pkgs, 1L)
  expect_identical(status$missing_packages, "ranger")
  expect_identical(status$outcome, "missing_pkgs")

  err <- expect_error(
    check_daemons_can_load(status),
    class = "nestedtune_daemons_missing_pkgs"
  )
  expect_match(conditionMessage(err), "ranger")
  expect_lt(elapsed, 150)
})
