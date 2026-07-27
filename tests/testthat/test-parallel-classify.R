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
  # mirai resolves a real interrupt to an EMPTY CHARACTER STRING carrying these
  # classes -- not an integer. An earlier fixture used 20L; classification is
  # inherits()-based so it passed either way, but a fixture that does not match
  # what production sees is not evidence.
  interrupt <- structure("", class = c("miraiInterrupt", "errorValue", "try-error"))
  expect_error(classify_fold_result(interrupt), class = "nestedtune_interrupted")
})

test_that("a cancelled task aborts instead of being recorded as a failed fold", {
  # M09-D1: stop_mirai() resolves every task in the map to errorValue 20 --
  # the one in flight and the ones still queued alike -- and carries no
  # miraiInterrupt class, so the branch above never sees it. Recording these as
  # failed folds reports an estimate over folds that were never given a chance
  # to run, which is the same IP4 inversion BC4 exists to prevent, on a path
  # BC4 does not reach.
  cancelled <- structure(20L, class = c("errorValue", "try-error"))
  expect_false(inherits(cancelled, "miraiInterrupt"))
  expect_error(classify_fold_result(cancelled), class = "nestedtune_cancelled")
})

test_that("a cancelled run is caught by a handler for any stopped run", {
  # nestedtune_cancelled inherits nestedtune_interrupted, so code that already
  # handled a stopped run keeps working and code that cares can still tell a
  # torn-down pool from someone pressing Ctrl-C.
  cancelled <- structure(20L, class = c("errorValue", "try-error"))
  expect_error(classify_fold_result(cancelled), class = "nestedtune_interrupted")
})

test_that("a real interrupt is an interrupt, not a cancellation", {
  # The interrupt fixture is an empty STRING (see the BC4 test above), so
  # as.integer() on it is NA. A cancellation check that reached for the integer
  # before validating the shape would misfire right here.
  interrupt <- structure("", class = c("miraiInterrupt", "errorValue", "try-error"))
  cnd <- tryCatch(classify_fold_result(interrupt), condition = identity)
  expect_s3_class(cnd, "nestedtune_interrupted")
  expect_false(inherits(cnd, "nestedtune_cancelled"))
})

test_that("the ambiguous teardown value stays a recorded fold failure", {
  # M09-D1 found errorValue 19 under BOTH a daemons(0) teardown and a daemon
  # dying mid-fold, with identical classes -- nothing in the value separates
  # them. Aborting on it would throw away every completed fold whenever one
  # worker died, which is what M03 exists to prevent. So 19 keeps this
  # behaviour and the roxygen states the limit rather than guessing at it.
  ev <- structure(19L, class = c("errorValue", "try-error"))
  out <- classify_fold_result(ev)
  expect_false(out$completed)
  expect_identical(out$notes$location, "worker")
})

test_that("a worker whose message is the cancel code is not a cancellation", {
  # Why the cancel check validates the type and does not just compare values:
  # R coerces across types in `==`, so a miraiError carrying the message "20"
  # equals the cancel code exactly (verified: `"20" == 20L` is TRUE). Without
  # is.integer(), one unlucky error message would abort the run and discard
  # every fold that had already completed.
  #
  # Asserted on the predicate rather than through classify_fold_result(),
  # deliberately: the fold-failure branch reaches conditionMessage(), whose
  # miraiError method is registered by MIRAI's namespace, so a fabricated
  # miraiError raises "no applicable method" wherever mirai is not loaded --
  # CRAN's noSuggests flavor among them. The end-to-end miraiError path is
  # already covered above, against a real one, behind the mirai skip.
  err <- structure("20", class = c("miraiError", "errorValue", "try-error"))
  expect_true(err == cancel_error_value)      # the coercion this guards against
  expect_false(is_cancelled_value(err))
})

test_that("dispatch refuses daemons that cannot load the package", {
  # The probe result is injected rather than engineered. Producing it for real
  # means pointing the daemons' library path somewhere empty, which also stops
  # them loading *mirai* -- they die at startup, are still counted as
  # connections, and the pre-flight round-trip then blocks forever. That hung
  # `R CMD check` for 39 minutes before this test was rewritten, and it is the
  # reason the probe is now bounded (M07-D6). The genuinely heterogeneous pool
  # AC1 asks for is built in test-parallel-detection.R, where the scratch
  # library keeps mirai and drops only the target.
  expect_error(
    check_daemons_can_load(preflight_outcome(FALSE)),
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

  # setTimeLimit, not system.time: the latter measures only after the call
  # returns, so it flags a slow probe and can never fail on a hung one -- which
  # is the only failure this test exists to catch (M09's lesson).
  setTimeLimit(elapsed = 30, transient = TRUE)
  on.exit(setTimeLimit(), add = TRUE, after = FALSE)
  status <- daemons_load_status(timeout = 2000L)

  expect_identical(status$outcome, "no_response")
  expect_identical(status$cannot_load, 0L)
  expect_gt(status$no_answer, 0L)
})

# --- Per-daemon coverage and the two failure causes (M10) --------------------
#
# The M07 defect these pin: the probe submitted a single mirai() task, which one
# daemon takes. In a heterogeneous pool -- a respawned daemon, differing library
# paths -- one loadable daemon therefore passed the check for every other, and
# the rest came back as opaque per-fold worker failures. The outcome is now
# per-daemon, so the classification seam is testable with fabricated answers:
# TRUE loaded, FALSE could not load, NA never answered.

test_that("a pool where every daemon loaded passes", {
  status <- preflight_outcome(c(TRUE, TRUE, TRUE))
  expect_identical(status$outcome, "ok")
  expect_identical(status$total, 3L)
  expect_true(check_daemons_can_load(status))
})

test_that("one loadable daemon no longer passes the check for the whole pool", {
  # The regression proper. Under M07's single-task probe this pool answered
  # TRUE and dispatched; every fold landing on daemon 2 then failed opaquely.
  status <- preflight_outcome(c(TRUE, FALSE, TRUE))
  expect_identical(status$outcome, "cannot_load")
  expect_identical(status$cannot_load, 1L)
  expect_identical(status$total, 3L)

  err <- expect_error(
    check_daemons_can_load(status),
    class = "nestedtune_daemons_cannot_load"
  )
  expect_match(conditionMessage(err), "1 of 3")
})

test_that("a load failure keeps the install and prime remedies", {
  err <- expect_error(check_daemons_can_load(preflight_outcome(c(FALSE, FALSE))))
  msg <- conditionMessage(err)
  expect_match(msg, "Install the package")
  expect_match(msg, "pkgload::load_all")
})

test_that("a timeout is not reported as a package that cannot be loaded", {
  # The second M07 defect: one message covered both outcomes, so a daemon that
  # was merely slow was reported with install-and-prime remedies -- telling a
  # user to install what they already have.
  status <- preflight_outcome(c(TRUE, NA), timeout = 1500)
  expect_identical(status$outcome, "no_response")
  expect_identical(status$no_answer, 1L)

  err <- expect_error(
    check_daemons_can_load(status),
    class = "nestedtune_daemons_no_response"
  )
  expect_false(inherits(err, "nestedtune_daemons_cannot_load"))

  msg <- conditionMessage(err)
  expect_false(grepl("install", msg, ignore.case = TRUE))
  expect_match(msg, "did not answer")
  expect_match(msg, "1500")
})

test_that("the timeout message points at the option that raises the bound", {
  err <- expect_error(check_daemons_can_load(preflight_outcome(c(NA, NA), timeout = 250)))
  expect_match(conditionMessage(err), "nestedtune.preflight_timeout")
})

test_that("a pool failing both ways names both facts", {
  # M10-D1: installing is the actionable fix, so the load failure carries the
  # class -- but staying silent on the non-answer would only make the user
  # rediscover it on the next run.
  status <- preflight_outcome(c(TRUE, FALSE, NA), timeout = 2000)
  expect_identical(status$outcome, "cannot_load")
  expect_identical(status$cannot_load, 1L)
  expect_identical(status$no_answer, 1L)

  err <- expect_error(
    check_daemons_can_load(status),
    class = "nestedtune_daemons_cannot_load"
  )
  msg <- conditionMessage(err)
  expect_match(msg, "cannot load")
  expect_match(msg, "did not answer")
})

test_that("both causes answer to one shared class", {
  # M10-D1: a handler that only cares that the startup check failed catches
  # either, without having to list both names.
  for (status in list(preflight_outcome(FALSE), preflight_outcome(NA))) {
    expect_error(
      check_daemons_can_load(status),
      class = "nestedtune_daemons_unusable"
    )
  }
})

test_that("a daemon answering something other than TRUE or FALSE counts as silent", {
  # stop_mirai() resolves an unanswered probe to errorValue 20, and a daemon
  # that died mid-probe yields some other non-logical. Neither is an answer, so
  # both classify as non-response rather than as a load failure -- the same
  # positive-shape discipline classify_fold_result() rests on.
  answers <- list(TRUE, structure(20L, class = c("errorValue", "try-error")))
  status <- preflight_outcome(answers)
  expect_identical(status$outcome, "no_response")
  expect_identical(status$no_answer, 1L)
})

test_that("dispatch accepts daemons primed with the package", {
  skip_if_not_installed("mirai")
  skip_if_not_installed("pkgload")
  skip_on_cran()

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)
  expect_true(check_daemons_can_load())
})
