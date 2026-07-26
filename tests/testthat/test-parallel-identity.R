# IP2 across workers: the identity that makes parallel dispatch legitimate.
#
# Oracle note (DESIGN "Oracle records"): these tests are *mode-independence*
# assertions, not absolute-correctness ones. A defect present identically in the
# serial and parallel paths preserves every identity here while breaking the
# documented contract, which is why RR03 (BC7) requires the contract-derived
# reference-loop oracle in test-nested-tune-grid-oracles.R to stay green
# alongside them. Neither replaces the other: that one anchors what the numbers
# are, these anchor that the numbers do not depend on how the loop was run.
#
# Every test uses the ranger workflow. With a deterministic engine these pass
# vacuously -- RR03 re-confirmed M02's lesson by executing a wrong dispatcher
# against the PCA/lm workflow and watching it pass.

serial_reference <- function(wf, nested, grid, metrics, seed = 2026L) {
  mirai::daemons(0)
  set.seed(seed)
  out <- nested_tune_grid(wf, nested, grid = grid, metrics = metrics)
  testthat::expect_identical(last_dispatch(), "serial")
  out
}

test_that("BC1: parallel matches serial at two above-threshold daemon counts", {
  skip_if_no_daemons()
  skip_if_not_installed("ranger")

  data <- make_reg_data()
  nested <- det_nested(data)
  wf <- stoch_workflow(data)
  on.exit(mirai::daemons(0), add = TRUE)

  serial <- serial_reference(wf, nested, stoch_grid(), reg_metrics())

  # Both counts are >= 2, the threshold D-018 inherited from tune. A one-daemon
  # run would take the serial branch and the "identity" would be serial vs
  # serial -- the vacuity RR03 flagged as B1.
  for (n in c(2L, 3L)) {
    start_daemons(n)
    set.seed(2026L)
    parallel <- without_pkgload_warning(
      nested_tune_grid(wf, nested, grid = stoch_grid(), metrics = reg_metrics())
    )

    # BC1's second half: prove the parallel branch actually ran. The evidence is
    # out-of-band precisely so that asserting it cannot disturb the identity.
    expect_identical(last_dispatch(), "parallel")
    expect_identical(parallel, serial)
  }
})

test_that("BC2: identity holds under a caller kind that is neither MT nor L'Ecuyer", {
  skip_if_no_daemons()
  skip_if_not_installed("ranger")

  # Why Wichmann-Hill and not the obvious L'Ecuyer-CMRG: mirai starts its
  # daemons on L'Ecuyer-CMRG. A caller who has selected that same kind therefore
  # matches the daemons' ambient generator exactly, and an implementation with
  # NO kind pin at all reproduces serial results perfectly -- RR03 verified this
  # by execution. L'Ecuyer-CMRG is the one non-default kind with zero detection
  # power here, so the test that exists to catch a missing pin must avoid it.
  old_kind <- RNGkind()
  on.exit(RNGkind(old_kind[[1L]], old_kind[[2L]], old_kind[[3L]]), add = TRUE)
  on.exit(mirai::daemons(0), add = TRUE)
  RNGkind("Wichmann-Hill")

  data <- make_reg_data()
  nested <- det_nested(data)
  wf <- stoch_workflow(data)

  serial <- serial_reference(wf, nested, stoch_grid(), reg_metrics())

  start_daemons(2)
  set.seed(2026L)
  parallel <- without_pkgload_warning(
    nested_tune_grid(wf, nested, grid = stoch_grid(), metrics = reg_metrics())
  )
  expect_identical(last_dispatch(), "parallel")
  expect_identical(parallel, serial)
})

test_that("BC1: the caller's RNG state and kind survive a parallel run", {
  skip_if_no_daemons()
  skip_if_not_installed("ranger")

  data <- make_reg_data()
  nested <- det_nested(data)
  wf <- stoch_workflow(data)
  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  set.seed(99L)
  before_seed <- .Random.seed
  before_kind <- RNGkind()
  without_pkgload_warning(
    nested_tune_grid(wf, nested, grid = stoch_grid(), metrics = reg_metrics())
  )

  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)
})

test_that("BC4: an aborted parallel run still restores the caller's RNG state", {
  skip_if_no_daemons()

  # An interrupt unwinds through the same on.exit() the pre-flight abort does,
  # so this pins the exit contract BC4 depends on. The interrupt value itself is
  # classified in test-parallel-classify.R, where it can be constructed exactly.
  old <- Sys.getenv(c("R_LIBS", "R_LIBS_USER"), names = TRUE)
  Sys.setenv(R_LIBS = tempfile(), R_LIBS_USER = tempfile())
  on.exit(do.call(Sys.setenv, as.list(old)), add = TRUE)
  on.exit(mirai::daemons(0), add = TRUE)

  mirai::daemons(0)
  mirai::daemons(2)

  data <- make_reg_data()
  nested <- det_nested(data)
  wf <- det_workflow(data)

  set.seed(5L)
  before_seed <- .Random.seed
  before_kind <- RNGkind()
  expect_error(
    nested_tune_grid(wf, nested, grid = det_grid(), metrics = reg_metrics()),
    class = "nestedtune_daemons_cannot_load"
  )
  expect_identical(.Random.seed, before_seed)
  expect_identical(RNGkind(), before_kind)
})

test_that("BC6: a failed fold matches serially in every field but its traces", {
  skip_if_no_daemons()
  skip_if_not_installed("ranger")

  data <- make_reg_data()
  nested <- break_fold(det_nested(data), fold = 2L, stage = "inner tuning")
  wf <- stoch_workflow(data)
  on.exit(mirai::daemons(0), add = TRUE)

  mirai::daemons(0)
  # expect_warning() returns the *condition*, never the expression's value
  # (M03 lesson), so the run that produces the object is a separate call.
  set.seed(2026L)
  # tune raises its own "All models failed" warning alongside ours; catching
  # only the outer one leaves it to surface as an uncaught warning in the run.
  suppressWarnings(
    expect_warning(
      nested_tune_grid(wf, nested, grid = stoch_grid(), metrics = reg_metrics()),
      class = "nestedtune_failed_folds"
    )
  )
  set.seed(2026L)
  serial <- suppressWarnings(
    nested_tune_grid(wf, nested, grid = stoch_grid(), metrics = reg_metrics())
  )

  start_daemons(2)
  set.seed(2026L)
  parallel <- suppressWarnings(
    without_pkgload_warning(
      nested_tune_grid(wf, nested, grid = stoch_grid(), metrics = reg_metrics())
    )
  )
  expect_identical(last_dispatch(), "parallel")

  # Traces are rlang backtraces: a daemon's call stack is rooted in
  # mirai::daemon() and can never equal the host's, so they are outside the IP2
  # identity claim (M07-D3). Everything a user reads -- text, location, type --
  # is inside it.
  expect_identical(parallel$.completed, serial$.completed)
  expect_identical(parallel$.metrics, serial$.metrics)
  expect_identical(parallel$.selected, serial$.selected)
  expect_identical(parallel$.tuning_seed, serial$.tuning_seed)
  expect_identical(parallel$.outer_fit_seed, serial$.outer_fit_seed)

  # Note TEXT is compared with whitespace normalized, which departs from BC6's
  # literal "identical()" -- see the "Deviations from RR03" row in the milestone
  # file. cli hard-wraps a message to the console width of the process that
  # formats it, and a daemon's width is its own, so the same note arrives
  # wrapped at 80 columns in parallel and at the host's width serially. The
  # words are identical; only the line breaks differ. RR03 verified the text
  # matched, but its probe formatted both sides at the same width.
  unwrap <- function(x) gsub("[[:space:]]+", " ", x)
  for (i in seq_len(nrow(serial))) {
    s_notes <- serial$.notes[[i]]
    p_notes <- parallel$.notes[[i]]
    expect_identical(p_notes$location, s_notes$location)
    expect_identical(p_notes$type, s_notes$type)
    expect_identical(unwrap(p_notes$note), unwrap(s_notes$note))
  }
  expect_false(serial$.completed[[2L]])
})

test_that("BC9: a fold is immune to whatever a daemon ran before it", {
  skip_if_no_daemons()
  skip_if_not_installed("ranger")

  data <- make_reg_data()
  nested <- det_nested(data)
  wf <- stoch_workflow(data)
  on.exit(mirai::daemons(0), add = TRUE)

  start_daemons(2)
  set.seed(2026L)
  fresh <- without_pkgload_warning(
    nested_tune_grid(wf, nested, grid = stoch_grid(), metrics = reg_metrics())
  )

  # Pollute every daemon: a different generator triple including the legacy
  # Rounding sample kind, consumed draws, and global scribbles shadowing the
  # names the worker uses. The pin covers all three kind components, and
  # mirai_map() passes arguments rather than globals, so none of it can reach a
  # fold's numbers.
  start_daemons(2)
  mirai::everywhere({
    RNGkind("Knuth-TAOCP-2002", "Box-Muller", "Rounding")
    set.seed(1234)
    invisible(runif(10000))
    object <- "scribble"
    payload <- "scribble"
    seeds <- "scribble"
  })

  set.seed(2026L)
  polluted <- without_pkgload_warning(
    nested_tune_grid(wf, nested, grid = stoch_grid(), metrics = reg_metrics())
  )
  expect_identical(last_dispatch(), "parallel")
  expect_identical(polluted, fresh)
})

test_that("BC3: a daemon killed mid-run yields a recorded failure, not an abort", {
  skip_if_no_daemons()

  # The kill is injected at the dispatch layer rather than inside a real fold:
  # production code offers no injection point, and mocking does not reach a
  # separate process. What this exercises is exactly the path a dead daemon
  # takes through the package -- mirai_map -> collect_mirai ->
  # classify_fold_result -- with a genuinely killed worker rather than a
  # synthesized value. See the "Deviations from RR03" row in the milestone file.
  on.exit(mirai::daemons(0), add = TRUE)
  mirai::daemons(0)
  mirai::daemons(2)

  # Each task claims its own file before doing anything else, so the directory
  # counts executions. One shared append-only file looked simpler and was racy:
  # separate processes appending concurrently interleave their writes, which
  # produced a phantom "task ran twice" that was an artifact of the ledger, not
  # of mirai. BC3's "no fold executed more than once" needs a counter that
  # cannot lie.
  ledger <- tempfile()
  dir.create(ledger)

  mapped <- mirai::mirai_map(
    .x = list(1L, 2L, 3L, 4L),
    .f = function(i, ledger) {
      cat(Sys.getpid(), file = file.path(ledger, paste0(i, "-", Sys.getpid())))
      if (i == 2L) {
        # This daemon dies mid-task.
        tools::pskill(Sys.getpid())
        Sys.sleep(30)
      }
      list(
        completed = TRUE,
        metrics = data.frame(.metric = "rmse", .estimate = as.numeric(i)),
        selected = data.frame(min_n = i),
        notes = data.frame(location = character(0), type = character(0),
                           note = character(0))
      )
    },
    .args = list(ledger = ledger)
  )
  collected <- mirai::collect_mirai(mapped)
  records <- lapply(collected, classify_fold_result)

  # The run returned rather than aborting -- the whole point (M03, IP4).
  expect_length(records, 4L)

  completed <- vapply(records, function(r) isTRUE(r$completed), logical(1))
  expect_false(completed[[2L]])
  expect_identical(records[[2L]]$notes$location, "worker")

  # Every surviving fold carries exactly what it computed.
  for (i in c(1L, 3L, 4L)) {
    expect_true(completed[[i]])
    expect_identical(records[[i]]$metrics$.estimate, as.numeric(i))
  }

  # One file per task, and exactly one: a retried task would leave two, since
  # the replacement daemon has a different pid.
  ran <- sort(as.integer(sub("-.*$", "", list.files(ledger))))
  expect_identical(ran, 1:4)
})
