# Leaving dispatch_folds() without returning stops the folds it dispatched (M15).
#
# The defect: dispatch_folds() sends a mirai_map and then blocks in
# collect_mirai(). Interrupting there unwinds the host, but says nothing to the
# daemons -- so the pool the user reuses next is still computing folds whose
# results nobody will ever read. Established by execution against mirai 2.7.2
# before the fix: a real SIGINT during the collect left
# `mirai::status()$mirai` reporting `executing = 2`.
#
# The folds here are stand-ins that mark themselves started and then sleep. A
# real fit would make the window the interrupt has to land in depend on how
# fast the machine fits, and what is under test is the fate of dispatched work,
# not fitting (M12). The stand-in is installed by mocking the package's own
# `fold_task`, which dispatch_folds() looks up by name -- so everything from
# `mirai_map()` to the return is the production path.

# A fold record's shape, built inline rather than by calling a helper: the task
# is serialized to a daemon with its environment stripped to the global one, so
# its body can reach nothing this file defines.
completed_fold_task <- function(payload, object, grid, metrics) {
  list(
    completed = TRUE,
    metrics = data.frame(.metric = "rmse", .estimate = payload$value),
    selected = data.frame(mtry = 1L),
    notes = data.frame(
      location = character(0), type = character(0), note = character(0)
    )
  )
}

test_that("an interrupted run leaves no fold executing", {
  skip_if_no_daemons()
  # A genuine console interrupt is the contract under test, and a POSIX signal
  # is the only way to raise one without a console. setTimeLimit() is not a
  # substitute -- it does not fire inside a blocked collect_mirai() (M14).
  skip_on_os("windows")
  skip_if(!nzchar(Sys.which("sh")), "no POSIX shell to signal from")

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  markers <- file.path(tempdir(), paste0("m15-fold-", 1:2))
  unlink(markers)
  on.exit(unlink(markers), add = TRUE)

  local_mocked_bindings(
    fold_task = function(payload, object, grid, metrics) {
      file.create(payload$marker)
      Sys.sleep(60)
      NULL
    }
  )

  # The signal is sent only once BOTH folds have marked themselves started, so
  # the host is necessarily inside the collect when it lands -- a fixed delay
  # would race the pre-flight probe on a loaded machine and interrupt something
  # else. The wait is bounded at 20 s and the folds sleep for 60, so the signal
  # can never arrive after the collect has returned, where it would land
  # outside the handler below and take the suite down with it.
  #
  # A wait that times out sends nothing. If the folds never start -- the
  # pre-flight check aborting is the realistic way -- this test has already
  # failed on its own error, and a signal fired anyway would land in whichever
  # test was running twenty seconds later, aborting the run under `R CMD check`
  # with nothing to connect it to its cause (M15 review F3).
  script <- sprintf(
    'i=0; while [ $i -lt 200 ]; do [ -f "%s" ] && [ -f "%s" ] && break; sleep 0.1; i=$((i+1)); done; if [ -f "%s" ] && [ -f "%s" ]; then sleep 0.5; kill -INT %d; fi',
    markers[[1]], markers[[2]], markers[[1]], markers[[2]], Sys.getpid()
  )
  system2("sh", c("-c", shQuote(script)), wait = FALSE)

  payloads <- list(list(marker = markers[[1]]), list(marker = markers[[2]]))
  interrupted <- FALSE
  tryCatch(
    without_pkgload_warning(
      dispatch_folds(payloads, object = NULL, grid = NULL, metrics = NULL)
    ),
    interrupt = function(cnd) interrupted <<- TRUE
  )

  expect_true(interrupted)
  # Not a vacuous pass: both folds really were executing when the signal landed.
  # Without this an interrupt delivered before dispatch would report an idle
  # pool and read as a fix.
  expect_true(all(file.exists(markers)))

  # Bounded, because the daemons report the cancellation back asynchronously --
  # the pool is idle within a moment of the unwind, not within the same
  # instruction.
  executing <- function() mirai::status()$mirai[["executing"]]
  deadline <- Sys.time() + 15
  while (executing() > 0L && Sys.time() < deadline) {
    Sys.sleep(0.1)
  }
  expect_identical(executing(), 0L)
})

test_that("a run that finished normally is unharmed by the cancel on the way out", {
  skip_if_no_daemons()

  # The other half of AC2. The cancel is unconditional -- no flag decides
  # whether the run was abandoned -- so the normal exit path calls
  # stop_mirai() too, on a map whose every element has already resolved.
  # Verified harmless by execution (it returns FALSE per element and touches
  # nothing), and pinned here so a change that made it destructive would be
  # caught by results going missing rather than by reasoning.
  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  local_mocked_bindings(fold_task = completed_fold_task)

  out <- without_pkgload_warning(
    dispatch_folds(
      list(list(value = 1), list(value = 2)),
      object = NULL, grid = NULL, metrics = NULL
    )
  )

  expect_length(out, 2L)
  expect_true(all(vapply(out, function(x) isTRUE(x$completed), logical(1))))
  expect_identical(
    vapply(out, function(x) x$metrics$.estimate, numeric(1)),
    c(1, 2)
  )
  expect_identical(mirai::status()$mirai[["executing"]], 0L)
})
