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
  #
  # The abort is induced by mocking the probe, not by breaking the library path:
  # real daemons with no library cannot load mirai either, so they die at
  # startup and the probe hangs (M07-D6).
  local_mocked_bindings(daemons_load_status = function(...) {
    preflight_outcome(reports(FALSE))
  })
  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

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

test_that("a cancelled parallel run returns nothing and restores the RNG state", {
  skip_if_no_daemons()

  # Cancellation needs an actor outside the host, because the host is blocked
  # in collect_mirai() for the whole window in which it can happen. What is
  # substituted here is only that actor: the map is really dispatched to real
  # daemons and really stopped, and everything the milestone is about --
  # collect_mirai() resolving to errorValue 20, classify_fold_result() seeing
  # it, the abort, the on.exit() unwind -- is the production path, unmocked.
  # Hand-rolling the collect instead would pin nothing (M07).
  real_map <- mirai::mirai_map
  local_mocked_bindings(
    mirai_map = function(...) {
      map <- real_map(...)
      mirai::stop_mirai(map)
      map
    },
    .package = "mirai"
  )
  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  data <- make_reg_data()
  nested <- det_nested(data)
  wf <- det_workflow(data)

  set.seed(5L)
  before_seed <- .Random.seed
  before_kind <- RNGkind()

  # A real bound, not a measurement after the fact: a stopped map resolves at
  # once, so if this call ever blocks, the run must end as an error rather than
  # wedge `R CMD check` the way M07-D6 records. It rests on the collect being
  # interruptible, which is the same property a user's Ctrl-C rests on.
  setTimeLimit(elapsed = 60, transient = TRUE)
  on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)

  result <- NULL
  # `error =`, deliberately not `condition =`: the pre-milestone code returns
  # normally here while signalling a failed-folds *warning*, and a condition
  # handler would catch that warning, unwind before the assignment completed,
  # and leave `result` NULL either way -- making the AC4 assertion below pass
  # against the very behaviour this test exists to reject.
  cnd <- tryCatch(
    without_pkgload_warning(
      result <- nested_tune_grid(
        wf,
        nested,
        grid = det_grid(),
        metrics = reg_metrics()
      )
    ),
    error = identity
  )

  expect_s3_class(cnd, "nestedtune_cancelled")
  expect_s3_class(cnd, "nestedtune_interrupted")
  # AC4: nothing partial escapes -- no results object is built from the folds
  # that happened to finish before the stop landed.
  expect_null(result)
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
  # expect_warning() hands back the *condition*, never the expression's value
  # (M03 lesson) -- so the object is taken by assigning inside the expectation
  # rather than by running the fit a second time to fetch it. Muffling a warning
  # does not abort the expression, so `serial` is bound either way.
  set.seed(2026L)
  # tune raises its own "All models failed" warning alongside ours; catching
  # only the outer one leaves it to surface as an uncaught warning in the run.
  suppressWarnings(
    expect_warning(
      serial <- nested_tune_grid(
        wf,
        nested,
        grid = stoch_grid(),
        metrics = reg_metrics()
      ),
      class = "nestedtune_failed_folds"
    )
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
  skip_if_not_installed("ranger")

  # This drives the REAL nested_tune_grid() -> dispatch_folds() path. An earlier
  # version hand-rolled mirai_map/collect_mirai/classify_fold_result instead, on
  # the belief that production code had no injection point; review disproved
  # that by execution. Because dispatch_folds() looks `fold_task` up by name and
  # serializes it, a mocked binding reaches the daemon, so the kill happens
  # inside a genuine dispatch. The old shape left AC5 unpinned: switching the
  # collect to `.stop = TRUE` kept every test green.
  #
  # The mock communicates through environment variables, not captured locals:
  # dispatch strips the task's environment before sending it, and daemons
  # inherit environment variables set before they start.
  ledger <- tempfile()
  dir.create(ledger)

  data <- make_reg_data()
  nested <- det_nested(data)
  wf <- stoch_workflow(data)

  # Fold 2's tuning seed, derived the way the documented contract says the
  # driver derives it, so the mock can recognise that fold wherever it lands.
  set.seed(2026L)
  seeds <- sample.int(.Machine$integer.max, 2L * nrow(nested))
  kill_seed <- seeds[[2L * 2L - 1L]]

  old <- Sys.getenv(
    c("NESTEDTUNE_LEDGER", "NESTEDTUNE_KILL_SEED"),
    names = TRUE
  )
  Sys.setenv(NESTEDTUNE_LEDGER = ledger, NESTEDTUNE_KILL_SEED = kill_seed)
  on.exit(do.call(Sys.setenv, as.list(old)), add = TRUE)
  on.exit(mirai::daemons(0), add = TRUE)

  mirai::daemons(0)
  set.seed(2026L)
  serial <- nested_tune_grid(
    wf,
    nested,
    grid = stoch_grid(),
    metrics = reg_metrics()
  )

  start_daemons(2)
  local_mocked_bindings(
    fold_task = function(
      payload,
      object,
      grid,
      metrics,
      param_info,
      event_level
    ) {
      seed <- payload$seeds[[1L]]
      file.create(file.path(
        Sys.getenv("NESTEDTUNE_LEDGER"),
        paste0(seed, "-", Sys.getpid())
      ))
      if (identical(as.character(seed), Sys.getenv("NESTEDTUNE_KILL_SEED"))) {
        tools::pskill(Sys.getpid())
        Sys.sleep(30)
      }
      asNamespace("nestedtune")$nested_fold_fit(
        split = payload$split,
        inner = payload$inner,
        seeds = payload$seeds,
        object = object,
        grid = grid,
        metrics = metrics,
        param_info = param_info,
        event_level = event_level
      )
    }
  )

  set.seed(2026L)
  parallel <- suppressWarnings(
    without_pkgload_warning(
      nested_tune_grid(wf, nested, grid = stoch_grid(), metrics = reg_metrics())
    )
  )

  # The run returned rather than aborting -- the whole point (M03, IP4).
  expect_identical(last_dispatch(), "parallel")
  expect_identical(nrow(parallel), nrow(serial))

  expect_false(parallel$.completed[[2L]])
  expect_identical(parallel$.notes[[2L]]$location, "worker")

  # Every surviving fold matches its serial counterpart exactly.
  for (i in setdiff(seq_len(nrow(serial)), 2L)) {
    expect_true(parallel$.completed[[i]])
    expect_identical(parallel$.metrics[[i]], serial$.metrics[[i]])
    expect_identical(parallel$.selected[[i]], serial$.selected[[i]])
  }

  # One file per fold, and exactly one: a retried fold would leave two, since
  # the replacement daemon has a different pid.
  ran <- sub("-.*$", "", list.files(ledger))
  expect_identical(
    sort(as.numeric(ran)),
    sort(as.numeric(seeds[c(TRUE, FALSE)]))
  )
  expect_identical(anyDuplicated(ran), 0L)
})

test_that("BC6: the identity holds with param_info supplied (M34, AC4)", {
  skip_if_no_daemons()
  skip_if_not_installed("ranger")
  skip_if_not_installed("dials")

  data <- make_reg_data()
  nested <- det_nested(data)
  wf <- stoch_workflow(data)
  on.exit(mirai::daemons(0), add = TRUE)

  # An integer grid, so `param_info` is what the candidates are generated from.
  # With `stoch_grid()` the candidates travel in the grid itself and
  # `param_info` would ride along inert -- an identity that held whether or not
  # the argument reached a daemon at all.
  narrow <- update(
    tune::extract_parameter_set_dials(wf),
    min_n = dials::min_n(c(2L, 8L))
  )

  mirai::daemons(0)
  set.seed(2026L)
  serial <- nested_tune_grid(
    wf,
    nested,
    param_info = narrow,
    grid = 3,
    metrics = reg_metrics()
  )
  expect_identical(last_dispatch(), "serial")

  start_daemons(2)
  set.seed(2026L)
  parallel <- without_pkgload_warning(
    nested_tune_grid(
      wf,
      nested,
      param_info = narrow,
      grid = 3,
      metrics = reg_metrics()
    )
  )

  expect_identical(last_dispatch(), "parallel")
  expect_identical(parallel, serial)

  # The restriction really is the one being carried across the boundary: a
  # `param_info` the daemons never saw would leave them generating candidates
  # from the default range, which reaches 40.
  expect_true(all(
    vapply(parallel$.selected, function(x) x$min_n, integer(1)) <= 8L
  ))
})

# AC5 (M35). The event level is the first setting the identity has to carry
# that changes a *reported metric value* rather than the candidate chosen:
# `.metrics` is fed by the `control_last_fit()` the outer scoring fit now
# receives, so a level dropped on the daemon path alone -- threaded into
# `fold_task()` but never reaching the worker -- shows up here. What this does
# not establish is which level is which: a level dropped on both paths
# preserves the identity exactly, and test-event-level.R is the anchor for
# that.

test_that("BC1: the identity holds with a two-class fixture at event_level = \"second\"", {
  skip_if_no_daemons()
  skip_if_not_installed("ranger")
  skip_if_no_engines(stochastic = TRUE)

  data <- cls_data()
  nested <- cls_nested(data)
  wf <- cls_workflow(data)
  on.exit(mirai::daemons(0), add = TRUE)

  mirai::daemons(0)
  set.seed(2026L)
  serial <- nested_tune_grid(
    wf,
    nested,
    grid = cls_grid(),
    metrics = cls_metrics(),
    event_level = "second"
  )
  expect_identical(last_dispatch(), "serial")

  start_daemons(2)
  set.seed(2026L)
  parallel <- without_pkgload_warning(
    nested_tune_grid(
      wf,
      nested,
      grid = cls_grid(),
      metrics = cls_metrics(),
      event_level = "second"
    )
  )

  expect_identical(last_dispatch(), "parallel")
  # Every fold completed, so the identity below is between two runs that
  # produced metrics rather than two matching sets of failures.
  expect_true(all(serial$.completed))
  expect_true(all(parallel$.completed))
  expect_identical(parallel, serial)
})
