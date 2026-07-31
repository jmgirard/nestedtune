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
