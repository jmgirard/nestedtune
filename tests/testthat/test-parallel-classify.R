# Classifying what a worker hands back (BC3, BC4; M07-D2).
#
# The trap RR03 found by execution: neither of mirai's two failure shapes
# inherits "condition", which is the idiom nested_fold_fit() uses internally,
# and conditionMessage() *errors* on the errorValue a dead daemon produces. So
# classification is positive validation of the fold-record shape -- anything
# that is not a fold record is a failure -- rather than a test for error-ness.

fake_fold_record <- function(completed = TRUE) {
  list(
    completed = completed,
    metrics = data.frame(.metric = "rmse", .estimate = 1),
    selected = data.frame(mtry = 2),
    notes = data.frame(location = character(0), type = character(0),
                       note = character(0))
  )
}

test_that("a well-formed fold record passes through untouched", {
  rec <- fake_fold_record()
  expect_identical(classify_fold_result(rec), rec)

  failed <- fake_fold_record(completed = FALSE)
  expect_identical(classify_fold_result(failed), failed)
})

test_that("a miraiError becomes a recorded worker failure, not an abort", {
  skip_if_not_installed("mirai")
  skip_on_cran()

  mirai::daemons(1)
  on.exit(mirai::daemons(0), add = TRUE)
  err <- mirai::mirai(stop("boom"))[]

  # The precondition that makes this test worth having: the idiom used
  # elsewhere in the package does NOT catch this shape.
  expect_false(inherits(err, "condition"))
  expect_true(mirai::is_mirai_error(err))

  out <- classify_fold_result(err)
  expect_false(out$completed)
  expect_identical(out$notes$location, "worker")
  expect_match(out$notes$note, "boom")
})

test_that("an errorValue from a dead daemon is recorded without calling conditionMessage()", {
  # A raw errorValue: conditionMessage() raises on it, so a classifier that
  # reaches for the message before checking the shape takes the whole run down
  # with it -- the failure mode this test pins.
  ev <- structure(19L, class = "errorValue")
  expect_false(inherits(ev, "condition"))
  expect_error(conditionMessage(ev))

  out <- classify_fold_result(ev)
  expect_false(out$completed)
  expect_identical(out$notes$location, "worker")
  expect_match(out$notes$note, "19")
})

test_that("anything else that is not a fold record is recorded as a worker failure", {
  for (junk in list(NULL, list(), "a string", 42L, list(completed = "yes"))) {
    out <- classify_fold_result(junk)
    expect_false(out$completed)
    expect_identical(out$notes$location, "worker")
  }
})

test_that("a miraiInterrupt aborts instead of being recorded as a failed fold", {
  # BC4: a cancelled run is not a run that had failures. Recording an interrupt
  # as a failed fold would let a run the user stopped masquerade as a completed
  # design with some folds missing -- an IP4 inversion.
  interrupt <- structure(20L, class = c("miraiInterrupt", "errorValue"))
  expect_error(classify_fold_result(interrupt), class = "nestedtune_interrupted")
})

test_that("dispatch refuses daemons that cannot load the package", {
  # The probe result is injected rather than engineered. Producing it for real
  # means pointing the daemons' library path somewhere empty, which also stops
  # them loading *mirai* -- they die at startup, are still counted as
  # connections, and the pre-flight round-trip then blocks forever. That hung
  # `R CMD check` for 39 minutes before this test was rewritten, and it is the
  # reason the probe is now bounded (M07-D6).
  expect_error(
    check_daemons_can_load(ok = FALSE),
    class = "nestedtune_daemons_cannot_load"
  )
})

test_that("an unresponsive daemon pool fails fast instead of hanging", {
  skip_if_not_installed("mirai")
  skip_on_cran()

  # A pool configured against a URL nothing will ever dial into: connections are
  # reported, no daemon answers. Unbounded, this is the documented hang.
  mirai::daemons(0)
  mirai::daemons(url = "tcp://127.0.0.1:45997")
  on.exit(mirai::daemons(0), add = TRUE)

  elapsed <- system.time(ok <- daemons_can_load(timeout = 2000L))[["elapsed"]]
  expect_false(ok)
  expect_lt(elapsed, 30)
})

test_that("dispatch accepts daemons primed with the package", {
  skip_if_not_installed("mirai")
  skip_if_not_installed("pkgload")
  skip_on_cran()

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)
  expect_true(check_daemons_can_load())
})
