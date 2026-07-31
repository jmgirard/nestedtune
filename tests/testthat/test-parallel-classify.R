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
    # The evaluated-candidate record (M21). Part of the shape a fold record is
    # RECOGNISED by, not decoration: a worker returning the pre-M21 shape is a
    # worker whose package disagrees with this one, and classifying it as a
    # completed fold would put an object with no `.grid` element into a column
    # that must have one.
    grid = data.frame(mtry = 2, .config = "pre0_mod1_post0"),
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

test_that("a fold record missing the evaluated-candidate set is not a fold record", {
  # M21, and the reason this is asserted per element rather than on the whole
  # shape at once: the required set is what classification RECOGNISES, so a
  # requirement nothing pins can be dropped from it with every test still green
  # (verified by mutation at M21 T4 -- removing "grid" left the file passing
  # until this test existed).
  #
  # What the missing element means in practice is a worker running a different
  # version of this package. Accepting it would put a fold with no candidate
  # record into the `.grid` column, which new_nested_results() would fill with
  # a NULL -- an object claiming to record what it searched while recording
  # nothing, which is the IP4 failure the column exists to prevent.
  for (element in c("metrics", "selected", "grid", "notes")) {
    rec <- fake_fold_record()
    rec[[element]] <- NULL
    expect_false(is_fold_record(rec))

    out <- classify_fold_result(rec)
    expect_false(out$completed)
    expect_identical(out$notes$location, "worker")
  }

  expect_true(is_fold_record(fake_fold_record()))
})

test_that("a miraiError becomes a recorded worker failure, not an abort", {
  skip_if_not_installed("mirai")
  skip_on_cran()

  on.exit(mirai::daemons(0), add = TRUE)
  mirai::daemons(1)
  # This pool is deliberately raw -- unprimed and unwarmed, because the shape
  # under test needs no package in the daemon at all. That also made it the one
  # unbounded wait left in the suite: a bare `[` collect on a daemon that never
  # comes up waits forever, and it is the first daemon test to run in this file,
  # so it inherits whatever pool state the files before it left (M14 T2).
  err <- collect_bounded(mirai::mirai(stop("boom")))

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
    check_daemons_can_load(preflight_outcome(reports(FALSE))),
    class = "nestedtune_daemons_cannot_load"
  )
})

test_that("a connected daemon that cannot answer in time is bounded", {
  skip_if_not_installed("mirai")
  skip_on_cran()

  # The only test that drives the deadline path for real: poll to the deadline,
  # stop_mirai(), and read the resulting errorValue as a non-answer rather than
  # as a package that is missing. The daemon is connected but busy, so
  # everywhere() queues behind the task occupying it and genuinely cannot
  # answer inside the bound -- which is what a loaded machine looks like.
  #
  # M07's version of this test pointed the pool at a URL nothing would dial
  # into, which reports zero connections. That case is real and covered
  # separately below -- but everywhere() queues a task for the daemon that never
  # arrives rather than returning empty, so it exercises the deadline against an
  # empty pool. This test is the one that exercises it against a daemon that is
  # genuinely there and genuinely cannot answer, which is the case users hit.
  mirai::daemons(0)
  mirai::daemons(1)
  on.exit(mirai::daemons(0), add = TRUE)

  # setTimeLimit, not system.time: the latter measures only after the call
  # returns, so it flags a slow probe and can never fail on a hung one -- which
  # is the only failure this test exists to catch (M09's lesson).
  setTimeLimit(elapsed = 60, transient = TRUE)
  on.exit(setTimeLimit(), add = TRUE, after = FALSE)

  busy <- mirai::mirai(Sys.sleep(20))
  # The backstop, registered before anything can abort (M16 T6). testthat 3e
  # unwinds the block on a failed expectation, so a stop_mirai() written only at
  # the end is skipped exactly when a racy timing assertion fails -- leaving a
  # live 20-second task while the on.exit stack tears the pool down around it,
  # which is how this file leaked the orphan R process a CI cleanup reported.
  # Firing unconditionally is safe: on a task that has already resolved
  # stop_mirai() is inert, verified by execution at M15.
  #
  # after = FALSE puts it ahead of the daemons(0) registered above, so the task
  # is cancelled before the pool it runs on is taken away.
  on.exit(mirai::stop_mirai(busy), add = TRUE, after = FALSE)
  Sys.sleep(0.2)

  started <- Sys.time()
  status <- daemons_load_status(timeout = 1000L)
  elapsed <- as.numeric(Sys.time() - started, units = "secs")

  # Cancelled here, before the first assertion rather than after the last: the
  # measurement is complete, so nothing below needs the task alive, and no
  # assertion added later can get in front of the cleanup.
  mirai::stop_mirai(busy)

  expect_identical(status$outcome, "no_response")
  expect_identical(status$cannot_load, 0L)
  expect_identical(status$no_answer, 1L)
  # The bound held: it returned on its own deadline rather than waiting out the
  # 20-second task.
  expect_lt(elapsed, 15)
})

test_that("a pool with no daemon at all is a non-response, not a load failure", {
  skip_if_not_installed("mirai")
  skip_on_cran()

  # A pool configured against a URL nothing will ever dial into: connections
  # are 0, and everywhere() queues a task for the daemon that never arrives
  # rather than returning empty. Nothing reported the package missing, so this
  # must not be dressed up as a library problem -- there is no daemon to have a
  # library.
  #
  # Port 0, not a hardcoded 45997 (M16 T5). What the test needs is a port nothing
  # dials into, and asking the OS for a free one gives that without competing for
  # a fixed number with a concurrent job or a socket still in TIME_WAIT on a
  # reused runner. That collision was a suspect for the 2026-07-27 stall until
  # execution ruled it out -- an occupied port makes daemons() raise
  # "10 | Address in use" in 0.03 s, so it fails loudly rather than hanging. Not
  # the hang, then, but a real way for this test to fail for a reason that has
  # nothing to do with what it asserts.
  mirai::daemons(0)
  mirai::daemons(url = "tcp://127.0.0.1:0")
  on.exit(mirai::daemons(0), add = TRUE)

  setTimeLimit(elapsed = 30, transient = TRUE)
  on.exit(setTimeLimit(), add = TRUE, after = FALSE)

  status <- daemons_load_status(timeout = 2000L)
  expect_identical(status$outcome, "no_response")
  expect_identical(status$cannot_load, 0L)
  expect_gt(status$no_answer, 0L)
  expect_error(
    check_daemons_can_load(status),
    class = "nestedtune_daemons_no_response"
  )
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
  status <- preflight_outcome(reports(TRUE, TRUE, TRUE))
  expect_identical(status$outcome, "ok")
  expect_identical(status$total, 3L)
  expect_true(check_daemons_can_load(status))
})

test_that("one loadable daemon no longer passes the check for the whole pool", {
  # The regression proper. Under M07's single-task probe this pool answered
  # TRUE and dispatched; every fold landing on daemon 2 then failed opaquely.
  status <- preflight_outcome(reports(TRUE, FALSE, TRUE))
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
  err <- expect_error(check_daemons_can_load(preflight_outcome(reports(FALSE, FALSE))))
  msg <- conditionMessage(err)
  expect_match(msg, "Install the package")
  expect_match(msg, "pkgload::load_all")
})

test_that("a timeout is not reported as a package that cannot be loaded", {
  # The second M07 defect: one message covered both outcomes, so a daemon that
  # was merely slow was reported with install-and-prime remedies -- telling a
  # user to install what they already have.
  status <- preflight_outcome(reports(TRUE, NA), timeout = 1500)
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
  err <- expect_error(check_daemons_can_load(preflight_outcome(reports(NA, NA), timeout = 250)))
  expect_match(conditionMessage(err), "nestedtune.preflight_timeout")
})

test_that("a raised bound is reported as a number, not in scientific notation", {
  # cli renders an interpolated numeric through as.character(), which turns
  # 300000 into "3e+05" -- in the very bullet telling the user to raise that
  # number. Every bound the earlier tests use is small enough to miss this.
  err <- expect_error(check_daemons_can_load(preflight_outcome(reports(NA), timeout = 300000)))
  msg <- conditionMessage(err)
  expect_match(msg, "300000")
  expect_false(grepl("e+0", msg, fixed = TRUE))
})

test_that("a pool failing both ways names both facts", {
  # M10-D1: installing is the actionable fix, so the load failure carries the
  # class -- but staying silent on the non-answer would only make the user
  # rediscover it on the next run.
  status <- preflight_outcome(reports(TRUE, FALSE, NA), timeout = 2000)
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
  for (status in list(preflight_outcome(reports(FALSE)), preflight_outcome(reports(NA)))) {
    expect_error(
      check_daemons_can_load(status),
      class = "nestedtune_daemons_unusable"
    )
  }
})

# --- A daemon that loads the package but cannot run the fold (M24) ----------
#
# `requireNamespace()` answers a weaker question than dispatch asks. A daemon
# holding an older install loads the package and reports TRUE, then dies on
# every fold at `ns$rehydrate_payload` -- the symbol M23 added and no pre-flight
# noticed. The probe now carries the host's namespace manifest and each daemon
# reports what it lacks, so the gap is classified rather than discovered a fold
# at a time.

test_that("the probe expression asks the daemon for nothing but base R", {
  # The contract, and the one this suite got wrong: whatever `everywhere()` is
  # handed is serialized to daemons that may hold nothing but base R and the
  # package itself. Anything else named in it is a name the daemon has to
  # resolve, and a daemon that cannot raises -- returning a miraiError that
  # daemon_report() refuses, so a pool that answered is classified as silent.
  #
  # This is what caught M24's first cut only after CI: the probe was written as
  # live source, so `covr` rewrote its braces and sent `covr:::count()` calls to
  # daemons whose library has no covr (review F15). Under the coverage job this
  # test is now the thing that fails, at the exact allowlist below, rather than a
  # heterogeneous-pool test failing four assertions down with no cause named.
  names_called <- function(x) {
    if (is.call(x)) {
      c(deparse(x[[1L]]), unlist(lapply(as.list(x)[-1L], names_called)))
    } else {
      character()
    }
  }
  expect_identical(
    sort(unique(names_called(daemon_probe_expr()))),
    sort(c("{", "asNamespace", "character", "if", "list", "ls",
           "requireNamespace", "setdiff"))
  )
})

test_that("a package this session has no copy of yields no symbol expectation", {
  # The manifest asks what THIS build contains, so with no build here there is
  # nothing to compare a daemon against and the probe falls back to the load
  # question -- which is exactly what the `package` argument exists to ask.
  # Before this it raised an unclassified error from asNamespace() (review F6).
  absent <- "nestedtune.no.such.package"
  expect_false(requireNamespace(absent, quietly = TRUE))
  expect_identical(daemon_symbol_manifest(absent), character())

  # An empty expectation classifies a daemon that loaded as ok, never as
  # running a different build -- the fallback has to be silent, not accusing.
  status <- preflight_outcome(reports(TRUE, TRUE))
  expect_identical(status$outcome, "ok")
  expect_identical(status$incompatible, 0L)
})

test_that("a daemon that loads but lacks a symbol is incompatible, not ok", {
  status <- preflight_outcome(
    reports(TRUE, TRUE, missing = list(NULL, "rehydrate_payload"))
  )
  expect_identical(status$outcome, "incompatible")
  expect_identical(status$incompatible, 1L)
  expect_identical(status$cannot_load, 0L)
  expect_identical(status$no_answer, 0L)
  expect_identical(status$total, 2L)
})

test_that("the missing symbols are the union across the pool", {
  # Two daemons short of different things is one pool short of both, and the
  # message names the set rather than whichever daemon answered first.
  status <- preflight_outcome(
    reports(TRUE, TRUE, missing = list("nested_fold_fit", "rehydrate_payload"))
  )
  expect_identical(status$incompatible, 2L)
  expect_identical(
    status$missing_symbols, c("nested_fold_fit", "rehydrate_payload")
  )
})

test_that("a load failure still outranks an incompatible daemon", {
  # The ladder extends M10-D1 rather than reordering it: installing the package
  # is a stronger instruction than reinstalling it, so a pool failing both ways
  # is still told to install.
  status <- preflight_outcome(
    reports(FALSE, TRUE, missing = list(NULL, "rehydrate_payload"))
  )
  expect_identical(status$outcome, "cannot_load")
  expect_identical(status$cannot_load, 1L)
  expect_identical(status$incompatible, 1L)
})

test_that("an incompatible daemon outranks one that never answered", {
  # The other side of the same ladder. A daemon that said nothing names no fix;
  # one that named a missing symbol does, so it takes the class.
  status <- preflight_outcome(
    reports(NA, TRUE, missing = list(NULL, "rehydrate_payload"))
  )
  expect_identical(status$outcome, "incompatible")
  expect_identical(status$no_answer, 1L)
  expect_identical(status$incompatible, 1L)
})

test_that("every outcome the ladder can produce is reachable and distinct", {
  # All four in one place, so a future branch added above or below any of them
  # cannot quietly absorb its neighbour.
  outcomes <- vapply(
    list(
      reports(TRUE, TRUE),
      reports(TRUE, TRUE, missing = list(NULL, "rehydrate_payload")),
      reports(TRUE, NA),
      reports(TRUE, FALSE)
    ),
    function(answers) preflight_outcome(answers)$outcome,
    character(1)
  )
  expect_identical(
    outcomes, c("ok", "incompatible", "no_response", "cannot_load")
  )
})

test_that("the incompatible abort names the symbols, the count, and the restart", {
  status <- preflight_outcome(
    reports(TRUE, TRUE, missing = list(NULL, "rehydrate_payload")),
    timeout = 2000
  )
  err <- expect_error(
    check_daemons_can_load(status),
    class = "nestedtune_daemons_incompatible"
  )
  msg <- conditionMessage(err)
  expect_match(msg, "1 of 2")
  expect_match(msg, "rehydrate_payload")
  # The half users forget: a daemon keeps the namespace it loaded, so
  # reinstalling under a live pool changes nothing until it is replaced.
  expect_match(msg, "restart the pool")
  # NOT the install remedy -- the package is installed on these daemons, so
  # telling the user to install it reads as already done.
  expect_false(grepl("Install the package", msg, fixed = TRUE))
})

test_that("the incompatible abort renders at one symbol, two, five, and a mixed pool", {
  # Snapshotted rather than matched because the failures this guards are
  # presentational: a daemon holding a genuinely old build is missing most of
  # the namespace, and the untruncated bullet listed all 106 names at the user.
  # Pluralisation is snapshotted with it -- the daemon count and the symbol
  # count are different quantities and an earlier draft pluralised on the wrong
  # one, printing "The daemons" for a single daemon.
  #
  # Four configurations, not two, because a snapshot only guards what it
  # renders. The first draft pinned one symbol and five, which are exactly the
  # two counts that came out right, and shipped both defects the review found
  # (M24 review F1, F2, F11a). The two added here are where the wording
  # actually changes: cli joins a pair with `vec-sep2` rather than `vec-last`,
  # and a pool that is only PARTLY incompatible is the only one whose verb
  # quantity differs from its daemon count.
  expect_snapshot(error = TRUE, {
    check_daemons_can_load(
      preflight_outcome(reports(TRUE, missing = list("rehydrate_payload")),
                        timeout = 30000)
    )
    # The headline case: exactly the two names the worker resolves through the
    # daemon's own namespace, which is what a pre-M23 daemon is short of.
    check_daemons_can_load(
      preflight_outcome(
        reports(TRUE, missing = list(c("nested_fold_fit", "rehydrate_payload"))),
        timeout = 30000
      )
    )
    check_daemons_can_load(
      preflight_outcome(
        reports(TRUE, missing = list(c("a", "b", "c", "d", "e"))),
        timeout = 30000
      )
    )
    # One daemon of two: "1 of 2 ... is running", against the daemon count's own
    # plural in the same sentence.
    check_daemons_can_load(
      preflight_outcome(
        reports(TRUE, TRUE, missing = list(NULL, "rehydrate_payload")),
        timeout = 30000
      )
    )
  })
})

test_that("an incompatible pool answers to the shared unusable class", {
  # A handler that only cares the startup check failed catches this too,
  # alongside cannot_load and no_response.
  status <- preflight_outcome(reports(TRUE, missing = list("nested_fold_fit")))
  expect_error(
    check_daemons_can_load(status),
    class = "nestedtune_daemons_unusable"
  )
})

test_that("an incompatible pool still reports daemons that said nothing", {
  # Same reasoning as M10-D1's both-ways message: staying silent on the
  # non-answer only makes the user rediscover it on the next run.
  status <- preflight_outcome(
    reports(NA, TRUE, missing = list(NULL, "rehydrate_payload")),
    timeout = 2000
  )
  msg <- conditionMessage(
    expect_error(check_daemons_can_load(status),
                 class = "nestedtune_daemons_incompatible")
  )
  expect_match(msg, "did not answer")
})

# --- The bound is an option, not an argument (D-020, M10-D2) ----------------

test_that("an unset option yields the documented 30 seconds", {
  old <- options(nestedtune.preflight_timeout = NULL)
  on.exit(options(old), add = TRUE)
  expect_identical(preflight_timeout(), 30000)
})

test_that("the option raises and lowers the bound", {
  old <- options(nestedtune.preflight_timeout = 90000L)
  on.exit(options(old), add = TRUE)
  expect_identical(preflight_timeout(), 90000)

  options(nestedtune.preflight_timeout = 500)
  expect_identical(preflight_timeout(), 500)
})

test_that("a bound that is not a single positive finite number is refused", {
  # NULL is deliberately absent: unsetting the option is the *valid* default
  # case, covered above.
  #
  # The restore is built by hand rather than with options()["name"], which
  # names its element NA when the option is unset -- restoring that leaves the
  # last bad value in place and every later test in this file inherits it.
  old <- list(
    nestedtune.preflight_timeout = getOption("nestedtune.preflight_timeout")
  )
  on.exit(options(old), add = TRUE)
  for (bad in list("soon", -1, 0, NA_real_, c(1000, 2000), TRUE)) {
    options(nestedtune.preflight_timeout = bad)
    expect_error(preflight_timeout(), class = "nestedtune_bad_preflight_timeout")
  }
})

test_that("an infinite bound is refused, because it is not a bound", {
  # M10-D2: Inf is numeric and positive, so it slips past every check above --
  # and honouring it would hand back the unbreakable hang the bound exists to
  # convert into an error (M07's 39-minute `R CMD check`). A user who needs
  # longer sets a large finite value.
  old <- options(nestedtune.preflight_timeout = Inf)
  on.exit(options(old), add = TRUE)
  expect_error(preflight_timeout(), class = "nestedtune_bad_preflight_timeout")
})

test_that("the probe reads its bound from the option, not from the constant", {
  # Without this the option is tested only at the accessor: every other probe
  # test passes an explicit `timeout`, so wiring daemons_load_status() to
  # `default_preflight_timeout_ms` instead of `preflight_timeout()` would leave
  # the whole suite green while the option did nothing.
  skip_if_not_installed("mirai")
  skip_on_cran()

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(1)

  old <- options(nestedtune.preflight_timeout = 45678)
  on.exit(options(old), add = TRUE)

  setTimeLimit(elapsed = 120, transient = TRUE)
  on.exit(setTimeLimit(), add = TRUE, after = FALSE)

  status <- daemons_load_status()
  expect_identical(status$outcome, "ok")
  expect_identical(status$timeout, 45678)
})

test_that("a bad bound is refused before any daemon is asked", {
  # Ordering, not just validation. Left as a lazy default the bound is not read
  # until after everywhere() has already dispatched, so a typo'd option costs a
  # full cold load on every daemon before the user is told the option is bad.
  skip_if_not_installed("mirai")
  skip_on_cran()

  mirai::daemons(0)
  old <- options(nestedtune.preflight_timeout = "soon")
  on.exit(options(old), add = TRUE)

  expect_error(
    daemons_load_status(),
    class = "nestedtune_bad_preflight_timeout"
  )
})

test_that("a probe that reached no daemon at all is not a pass", {
  # The degenerate shape, at the seam: zero answers means nothing was verified,
  # so it must not classify as "ok" and let dispatch proceed. Unreachable in
  # production today -- everywhere() queues a task even at zero connections --
  # which is exactly why it needs a test of its own rather than trust.
  status <- preflight_outcome(list())
  expect_identical(status$total, 0L)
  expect_identical(status$outcome, "no_response")
  expect_error(
    check_daemons_can_load(status),
    class = "nestedtune_daemons_no_response"
  )
})

test_that("the abort names the package actually probed", {
  # The probe takes a `package` argument, so a message hard-coding nestedtune
  # is false whenever it is used -- as the real mixed-pool test does, probing
  # for ranger.
  status <- preflight_outcome(reports(TRUE, FALSE), package = "ranger")
  err <- expect_error(check_daemons_can_load(status))
  expect_match(conditionMessage(err), "ranger")
})

test_that("the option, not an argument, is what carries the bound", {
  # D-018 settled that parallelism is enabled solely by mirai::daemons(n) and
  # that nested_tune_grid() gains no argument for it; D-020 narrowed that to
  # signature knobs specifically, which is why the timeout became an option.
  # Recorded literally so growing the signature fails here rather than in
  # review.
  expect_identical(
    names(formals(nested_tune_grid)),
    c("object", "resamples", "grid", "metrics")
  )
})

test_that("a daemon answering something other than a report counts as silent", {
  # stop_mirai() resolves an unanswered probe to errorValue 20, and a daemon
  # that died mid-probe yields some other non-record. Neither is an answer, so
  # both classify as non-response rather than as a load failure -- the same
  # positive-shape discipline classify_fold_result() rests on.
  answers <- list(
    list(loaded = TRUE, missing = character()),
    structure(20L, class = c("errorValue", "try-error"))
  )
  status <- preflight_outcome(answers)
  expect_identical(status$outcome, "no_response")
  expect_identical(status$no_answer, 1L)
})

test_that("a miraiError is never read as a capability report", {
  # The shape that makes is.list() load-bearing rather than incidental: a
  # miraiError is a length-1 CHARACTER vector carrying the task's own error
  # message, so a validator admitting a bare string would read a daemon's error
  # text as the list of symbols it is missing -- reporting a mismatch that the
  # daemon never claimed, and hiding the real failure.
  fake <- structure(
    "Error in requireNamespace(): no such package",
    class = c("miraiError", "errorValue", "try-error")
  )
  expect_null(daemon_report(fake))

  status <- preflight_outcome(list(fake))
  expect_identical(status$outcome, "no_response")
  expect_identical(status$no_answer, 1L)
  expect_identical(status$incompatible, 0L)
})

test_that("a report is rejected unless every field has the right shape", {
  # Positive validation means each field is checked, not just the names: a
  # record whose `missing` came back as something other than a character vector
  # is a malformed answer, not a daemon with nothing missing.
  expect_null(daemon_report(list(loaded = TRUE)))
  expect_null(daemon_report(list(loaded = NA, missing = character())))
  expect_null(daemon_report(list(loaded = "yes", missing = character())))
  expect_null(daemon_report(list(loaded = TRUE, missing = 1L)))
  expect_null(daemon_report(list(loaded = TRUE, missing = NA_character_)))
  expect_null(daemon_report(list(loaded = c(TRUE, TRUE), missing = character())))
  expect_identical(
    daemon_report(list(loaded = TRUE, missing = "fold_task")),
    list(loaded = TRUE, missing = "fold_task")
  )
})

test_that("dispatch accepts daemons primed with the package", {
  skip_if_not_installed("mirai")
  skip_if_not_installed("pkgload")
  skip_on_cran()

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  # An explicit bound rather than the suite-wide option. Left implicit this was
  # the single largest wait in the file -- 300 s of legal waiting before M16,
  # invisible at the call site because the number lived in a helper. The daemons
  # here are already primed and warmed, so 60 s is generous for a probe that
  # normally answers in well under one (M16 T4).
  status <- daemons_load_status(timeout = 60000)
  expect_true(check_daemons_can_load(status))
})
