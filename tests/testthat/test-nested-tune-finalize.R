# Oracle records for the frame an inner tuning call finalizes an unknown
# parameter range on (DESIGN Conventions: oracles are recorded in the test file
# that asserts them).
#
# O1 -- type "analytic" (closed form). Source: dials::get_n_frac_range(), whose
#   finalized range is `floor(nrow(x) * frac)` of the frame it is handed (dials
#   1.4.x, read 2026-09-03), so a candidate the fold searched is inside
#   `floor(n * c(1/10, 5/10))` computed here from that fold's own
#   `nrow(rsample::analysis(split))` -- and outside it, by up to 20 on the
#   200-row fixture, when tune reads the full frame instead. Pinned by "AC2:
#   every candidate a fold searched lies inside the range its analysis rows
#   finalize".
#
# O2 -- type "live" (reference implementation). Source: rsample::nested_cv()
#   built under the same seed, whose inner splits carry each outer fold's
#   analysis set as their own frame, so tune finalizes on it by construction.
#   Pinned by "AC3: a nested_resamples() design and the nested_cv() design it
#   matches tune identically", which asserts the inner rows identical first.
#
# O1 and O2 are the >=2 independent oracle types GP2 requires. AC1 is the
# row-identity assertion behind both: the frame every finalizer call is handed
# is one outer fold's analysis frame and no other rows.

# The fixture: a 200-row frame, five outer folds of four inner folds, so each
# fold's analysis set holds 160 rows. Inner v = 4 clears the racers' burn-in
# floor (R/checks.R, `check_race_burn_in()`); the `inside` arguments are
# literal (the M05 lesson).
finalize_data <- function() make_reg_data(n = 200, seed = 5454)

finalize_nested <- function(data, seed = 54) {
  set.seed(seed)
  nested_resamples(
    data,
    outside = rsample::vfold_cv(v = 5),
    inside = rsample::vfold_cv(v = 4)
  )
}

finalize_nested_cv <- function(data, seed = 54) {
  set.seed(seed)
  rsample::nested_cv(
    data,
    outside = rsample::vfold_cv(v = 5),
    inside = rsample::vfold_cv(v = 4)
  )
}

FINALIZE_FRAC <- c(1 / 10, 5 / 10)

# A `min_n` whose upper bound is unknown until a frame is seen, finalized by
# dials::get_n_frac_range() over FINALIZE_FRAC. With `record` an environment,
# the finalizer first appends what it was handed -- the row count and the
# sorted first predictor -- so a test can say which rows tune read.
frac_min_n <- function(record = NULL) {
  finalizer <- function(object, x, ...) {
    if (!is.null(record)) {
      record$frames[[length(record$frames) + 1L]] <- list(
        n = nrow(x),
        x1 = sort(x$x1)
      )
    }
    dials::get_n_frac_range(object, x, frac = FINALIZE_FRAC)
  }
  dials::new_quant_param(
    type = "integer",
    range = c(2L, dials::unknown()),
    inclusive = c(TRUE, TRUE),
    label = c(min_n = "Minimal Node Size"),
    finalize = finalizer
  )
}

frac_param_info <- function(wf, record = NULL) {
  update(
    tune::extract_parameter_set_dials(wf),
    min_n = frac_min_n(record)
  )
}

new_frame_record <- function() {
  record <- new.env(parent = emptyenv())
  record$frames <- list()
  record
}

# The sorted first predictor of each outer fold's analysis frame: the key a
# recorded frame is matched against.
analysis_keys <- function(nested) {
  lapply(nested$splits, function(split) sort(rsample::analysis(split)$x1))
}

# One run of the export behind a registry key, on the recording `param_info`.
# Every tuner is asked for five candidates or the smallest search it allows;
# what matters is the frame its finalizer reads, not the search.
run_finalize_tuner <- function(fn, wf, nested, param_info) {
  ms <- reg_metrics()
  switch(
    fn,
    tune_grid = nested_tune_grid(
      wf,
      nested,
      param_info = param_info,
      grid = 5,
      metrics = ms
    ),
    tune_race_anova = nested_tune_race_anova(
      wf,
      nested,
      param_info = param_info,
      grid = 5,
      metrics = ms,
      control = race_control()
    ),
    tune_race_win_loss = nested_tune_race_win_loss(
      wf,
      nested,
      param_info = param_info,
      grid = 5,
      metrics = ms,
      control = race_control()
    ),
    tune_sim_anneal = nested_tune_sim_anneal(
      wf,
      nested,
      param_info = param_info,
      iter = 1,
      initial = 2,
      metrics = ms,
      control = anneal_control()
    ),
    rlang::abort(sprintf("no export for %s", fn))
  )
}

# Every recorded frame is one outer fold's analysis frame -- its row count and
# its rows -- and every outer fold was finalized on at least once.
expect_frames_are_analysis_rows <- function(record, nested, label) {
  keys <- analysis_keys(nested)
  sizes <- vapply(
    nested$splits,
    function(split) nrow(rsample::analysis(split)),
    integer(1)
  )
  expect_gt(length(record$frames), 0L, label = paste(label, "recorded frames"))
  matched <- vapply(
    record$frames,
    function(frame) {
      hits <- which(vapply(
        keys,
        function(key) identical(frame$x1, key),
        logical(1)
      ))
      # Exactly one fold, and that fold's row count.
      if (length(hits) != 1L || frame$n != sizes[[hits]]) NA_integer_ else hits
    },
    integer(1)
  )
  # Which recorded frames, by position, were no fold's analysis frame.
  expect_identical(
    which(is.na(matched)),
    integer(0),
    label = paste(label, "frames that are no fold's analysis frame")
  )
  expect_setequal(matched, seq_along(nested$splits))
}

test_that("AC1: every tuner finalizes on the outer fold's analysis rows", {
  skip_if_no_engines(stochastic = TRUE)
  skip_if_not_installed("dials")

  d <- finalize_data()
  nested <- finalize_nested(d)
  wf <- stoch_workflow(d)

  tuners <- setdiff(names(tuner_registry), "tune_bayes")
  expect_length(tuners, 4L)
  ran <- character()
  for (fn in tuners) {
    requires <- tuner_registry[[fn]]$requires
    if (!all(vapply(requires, rlang::is_installed, logical(1)))) {
      next
    }
    record <- new_frame_record()
    set.seed(1)
    res <- suppressMessages(run_finalize_tuner(
      fn,
      wf,
      nested,
      frac_param_info(wf, record)
    ))
    expect_true(all(res$.completed), label = paste(fn, "completed"))
    expect_frames_are_analysis_rows(record, nested, fn)
    ran <- c(ran, fn)
  }
  expect_true("tune_grid" %in% ran)

  # The same on a design whose outer rset the caller evaluated first.
  set.seed(54)
  outer <- rsample::vfold_cv(d, v = 5)
  evaluated <- nested_resamples(
    d,
    outside = outer,
    inside = rsample::vfold_cv(v = 4)
  )
  record <- new_frame_record()
  set.seed(1)
  res <- suppressMessages(nested_tune_grid(
    wf,
    evaluated,
    param_info = frac_param_info(wf, record),
    grid = 5,
    metrics = reg_metrics()
  ))
  expect_true(all(res$.completed))
  expect_frames_are_analysis_rows(record, evaluated, "evaluated outer")
})

test_that("AC2: every candidate a fold searched lies inside the range its analysis rows finalize", {
  skip_if_no_engines(stochastic = TRUE)
  skip_if_not_installed("dials")

  d <- finalize_data()
  nested <- finalize_nested(d)
  wf <- stoch_workflow(d)

  set.seed(2)
  res <- suppressMessages(nested_tune_grid(
    wf,
    nested,
    param_info = frac_param_info(wf),
    grid = 5,
    metrics = reg_metrics()
  ))
  expect_true(all(res$.completed))

  full_upper <- floor(nrow(d) * FINALIZE_FRAC[[2L]])
  for (i in seq_len(nrow(nested))) {
    n <- nrow(rsample::analysis(nested$splits[[i]]))
    bounds <- floor(n * FINALIZE_FRAC)
    # What makes the assertion discriminating on this fixture: a range read
    # off the full frame reaches 20 past the fold's own upper bound.
    expect_equal(full_upper - bounds[[2L]], 20L)
    candidates <- unique(res$.inner_metrics[[i]]$min_n)
    expect_gt(length(candidates), 1L)
    # Which candidates, if any, fall outside the fold's own range.
    outside <- candidates[candidates < bounds[[1L]] | candidates > bounds[[2L]]]
    expect_identical(
      outside,
      candidates[0],
      label = sprintf(
        "fold %d candidates outside [%d, %d]",
        i,
        bounds[[1L]],
        bounds[[2L]]
      )
    )
  }
})

test_that("AC3: a nested_resamples() design and the nested_cv() design it matches tune identically", {
  skip_if_no_engines(stochastic = TRUE)
  skip_if_not_installed("dials")

  d <- finalize_data()
  lean <- finalize_nested(d)
  ref <- finalize_nested_cv(d)
  # The precondition: the two designs hold the same inner rows.
  expect_inner_identical(lean, ref)
  wf <- stoch_workflow(d)
  ms <- reg_metrics()

  # Two direct calls per grid shape, never memoised() (the M46 lesson).
  set.seed(3)
  lean_unknown <- suppressMessages(nested_tune_grid(
    wf,
    lean,
    param_info = frac_param_info(wf),
    grid = 5,
    metrics = ms
  ))
  set.seed(3)
  ref_unknown <- suppressMessages(nested_tune_grid(
    wf,
    ref,
    param_info = frac_param_info(wf),
    grid = 5,
    metrics = ms
  ))
  expect_true(all(lean_unknown$.completed))
  expect_identical(lean_unknown$.inner_metrics, ref_unknown$.inner_metrics)
  expect_identical(lean_unknown$.metrics, ref_unknown$.metrics)

  set.seed(3)
  lean_grid <- nested_tune_grid(wf, lean, grid = stoch_grid(), metrics = ms)
  set.seed(3)
  ref_grid <- nested_tune_grid(wf, ref, grid = stoch_grid(), metrics = ms)
  expect_true(all(lean_grid$.completed))
  expect_identical(lean_grid$.inner_metrics, ref_grid$.inner_metrics)
  expect_identical(lean_grid$.metrics, ref_grid$.metrics)
})

# The `resamples` argument every fold's run_tuner() received, in fold order,
# the mock delegating to the real function so the run completes.
record_run_tuner_resamples <- function(expr) {
  seen <- list()
  original <- run_tuner
  local_mocked_bindings(
    run_tuner = function(tuner, object, resamples, ...) {
      seen[[length(seen) + 1L]] <<- resamples
      original(tuner, object = object, resamples = resamples, ...)
    }
  )
  res <- force(expr)
  expect_true(all(res$.completed))
  seen
}

test_that("AC4: an inner rset the rebuild does not apply to reaches run_tuner() untouched", {
  skip_if_no_engines()

  d <- make_reg_data()
  wf <- det_workflow(d)
  ms <- reg_metrics()

  # A nested_cv() design: its inner splits carry the analysis set already.
  set.seed(4)
  ref <- rsample::nested_cv(
    d,
    outside = rsample::vfold_cv(v = 2),
    inside = rsample::vfold_cv(v = 2)
  )
  seen <- record_run_tuner_resamples(
    nested_tune_grid(wf, ref, grid = det_grid(), metrics = ms)
  )
  expect_length(seen, nrow(ref))
  for (i in seq_along(seen)) {
    expect_identical(seen[[i]], ref$inner_resamples[[i]])
  }

  # An evaluated manual outer split whose `in_id` repeats a row: the inverse
  # of the remap is ambiguous there, so the frame is left as the design holds
  # it.
  repeated <- rsample::make_splits(
    list(analysis = c(1:60, 1:5), assessment = 61:90),
    d
  )
  expect_gt(anyDuplicated(repeated$in_id), 0L)
  outer <- rsample::manual_rset(list(repeated, repeated), c("a", "b"))
  set.seed(4)
  manual <- nested_resamples(
    d,
    outside = outer,
    inside = rsample::vfold_cv(v = 2)
  )
  seen <- record_run_tuner_resamples(
    nested_tune_grid(wf, manual, grid = det_grid(), metrics = ms)
  )
  expect_length(seen, nrow(manual))
  for (i in seq_along(seen)) {
    expect_identical(seen[[i]], manual$inner_resamples[[i]])
  }
})
