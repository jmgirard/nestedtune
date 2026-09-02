# The record a Bayesian run leaves (M45 T2, AC5): each fold's `.grid` carries
# the search iteration its candidates were scored in, the readers of `.grid`
# treat that column as bookkeeping rather than as a parameter, and every
# result of either orchestrator records the procedure that produced it.

# ---- the .iter join, on the derivation itself --------------------------------

# A tuning result's shape as `scored_candidates()` reads it: per-resample
# metric frames, and for a Bayesian run a top-level `.iter` beside them. Built
# by hand so the join can be asserted on a shape whose answer is known without
# a fit -- a candidate scored in iteration 1 on one resample and iteration 0
# on none, one that scored on two resamples, and a resample that scored
# nothing.
candidate_frame <- function(config, value) {
  out <- data.frame(
    df1 = value,
    .metric = "rmse",
    .estimator = "standard",
    .estimate = 1,
    .config = config,
    stringsAsFactors = FALSE
  )
  out
}

test_that("a Bayesian run's record carries the iteration each candidate came from", {
  tuned <- list(
    .metrics = list(
      rbind(
        candidate_frame("pre1_mod0_post0", 1L),
        candidate_frame("pre2_mod0_post0", 5L)
      ),
      candidate_frame("pre1_mod0_post0", 1L),
      candidate_frame("iter1", 3L),
      candidate_frame("iter1", 3L)[0, ]
    ),
    .iter = c(0L, 0L, 1L, 1L)
  )
  got <- scored_candidates(tuned)

  # One row per candidate, the iteration joined from the row the frame sat in,
  # ordered by iteration and then by label.
  expect_identical(names(got), c("df1", ".config", ".iter"))
  expect_identical(
    got$.config,
    c("pre1_mod0_post0", "pre2_mod0_post0", "iter1")
  )
  expect_identical(got$.iter, c(0L, 0L, 1L))
  expect_identical(got$df1, c(1L, 5L, 3L))
})

test_that("iterations past nine order by number, not by label", {
  # tune labels proposals `iter1`, `iter2`, ... without padding, so a lexical
  # order would put the tenth before the second. The record is ordered by the
  # iteration number, and the label decides only within an iteration.
  frames <- lapply(c(0L, 2L, 10L, 1L), function(i) {
    candidate_frame(if (i == 0L) "pre1_mod0_post0" else paste0("iter", i), i)
  })
  tuned <- list(.metrics = frames, .iter = c(0L, 2L, 10L, 1L))
  got <- scored_candidates(tuned)

  expect_identical(got$.iter, c(0L, 1L, 2L, 10L))
  expect_identical(
    got$.config,
    c("pre1_mod0_post0", "iter1", "iter2", "iter10")
  )
})

test_that("a grid run's record is untouched by the join", {
  # No `.iter` at the top level, so no column is added and the order is the
  # label's alone -- the grid path's record as it was before the join existed.
  tuned <- list(
    .metrics = list(
      rbind(
        candidate_frame("pre2_mod0_post0", 5L),
        candidate_frame("pre1_mod0_post0", 1L)
      ),
      candidate_frame("pre3_mod0_post0", 9L)
    )
  )
  got <- scored_candidates(tuned)

  expect_identical(names(got), c("df1", ".config"))
  expect_identical(got$.config, paste0("pre", 1:3, "_mod0_post0"))
})

test_that("a frame that already carries .iter keeps its own", {
  frame <- candidate_frame("iter1", 3L)
  frame$.iter <- 7L
  got <- scored_candidates(list(.metrics = list(frame), .iter = 1L))
  expect_identical(got$.iter, 7L)
})

test_that("a top-level .iter that does not line up with the frames is ignored", {
  tuned <- list(
    .metrics = list(candidate_frame("pre1_mod0_post0", 1L)),
    .iter = c(0L, 1L)
  )
  got <- scored_candidates(tuned)
  expect_false(".iter" %in% names(got))
})

# ---- the readers of .grid ---------------------------------------------------

test_that("two folds that scored the same candidates in different iterations searched the same set", {
  a <- data.frame(
    df1 = c(1L, 3L),
    .config = c("pre1_mod0_post0", "iter1"),
    .iter = c(0L, 1L)
  )
  b <- data.frame(
    df1 = c(1L, 3L),
    .config = c("pre1_mod0_post0", "iter2"),
    .iter = c(0L, 2L)
  )
  expect_true(same_candidates(list(a, b)))

  # And a genuine difference in the candidates is still a difference: the
  # exclusion is of the bookkeeping column, not of the comparison.
  c1 <- data.frame(
    df1 = c(1L, 4L),
    .config = c("pre1_mod0_post0", "iter1"),
    .iter = c(0L, 1L)
  )
  expect_false(same_candidates(list(a, c1)))
})

test_that("print() and summary() count the candidates a Bayesian fold scored", {
  skip_if_no_bayes_fixture()

  res <- bayes_results()
  expect_true(all(res$.completed))

  # The counts are the rows of each fold's record, initial candidates and
  # proposals alike. Three initial candidates and two proposals is five per
  # fold when every proposal scored; a fold that stopped short of `iter` holds
  # fewer, so the assertion is on the record, not on the arithmetic.
  counts <- vapply(res$.grid, nrow, integer(1))
  for (g in res$.grid) {
    expect_true(".iter" %in% names(g))
    expect_identical(sum(g$.iter == 0L), 3L)
  }

  s <- summary(res)
  expect_identical(vapply(s$grids, nrow, integer(1)), counts)

  # The candidates-searched line fires only when the folds' candidate sets
  # differ, and its numbers are the same counts. Whether they differ is a fact
  # of the search, so both branches are accepted -- and each is asserted on.
  txt <- print_text(res)
  if (same_candidates(res$.grid)) {
    expect_no_match(txt, "Candidates searched")
  } else {
    expect_match(
      txt,
      paste0("Candidates searched: ", paste(counts, collapse = ", "))
    )
  }
  expect_no_error(print(s))
})

# ---- the procedure attribute -------------------------------------------------

test_that("a grid run records its procedure, and its grid and metrics as before", {
  skip_if_no_engines()

  metrics <- reg_metrics()
  grid <- det_grid()
  d <- make_reg_data()
  set.seed(2)
  res <- memoised(nested_tune_grid(
    det_workflow(d),
    det_nested(d),
    grid = grid,
    metrics = metrics
  ))

  expect_identical(attr(res, "grid"), grid)
  expect_identical(attr(res, "metrics"), metrics)

  procedure <- attr(res, "procedure")
  expect_type(procedure, "list")
  expect_identical(
    names(procedure),
    c("tuner", "grid", "param_info", "event_level", "eval_time")
  )
  expect_identical(procedure$tuner, "tune_grid")
  expect_identical(procedure$grid, grid)
  expect_null(procedure$param_info)
  expect_identical(procedure$event_level, "first")
  expect_null(procedure$eval_time)
})

test_that("a Bayesian run records its procedure and carries no grid attribute", {
  skip_if_no_bayes_fixture()

  res <- bayes_results()
  wf <- bayes_workflow(make_reg_data())

  expect_null(attr(res, "grid"))
  expect_false("grid" %in% names(attributes(res)))
  expect_identical(attr(res, "metrics"), reg_metrics())

  procedure <- attr(res, "procedure")
  expect_identical(
    names(procedure),
    c(
      "tuner",
      "iter",
      "initial",
      "objective",
      "param_info",
      "event_level",
      "eval_time"
    )
  )
  expect_identical(procedure$tuner, "tune_bayes")
  expect_identical(procedure$iter, 2)
  expect_identical(procedure$initial, 3)
  expect_s3_class(procedure$objective, "acquisition_function")
  expect_identical(procedure$objective, tune::exp_improve())
  # Compared on the ids and the parameter objects rather than the whole set:
  # the set also carries the recipe step ids, which `recipes::rand_id()` draws
  # from the stream, and a workflow built here is not the fixture's.
  recorded <- procedure$param_info
  expected <- bayes_param_info(wf)
  expect_s3_class(recorded, "parameters")
  expect_identical(recorded$id, expected$id)
  expect_identical(recorded$object, expected$object)
  expect_identical(procedure$event_level, "first")
  expect_null(procedure$eval_time)

  # The design's inner specification rides beside the procedure (M46).
  expect_identical(
    attr(res, "inside"),
    attr(det_nested(make_reg_data()), "inside")
  )
})

test_that("the procedure is part of the run's record", {
  # `run_attributes()` is what the dplyr and vctrs doors carry across and shed,
  # so membership here is what makes the compat suites' `expect_kept()` and
  # `expect_no_record()` assert the attribute at every door.
  expect_true("procedure" %in% run_attributes())
  expect_true("procedure" %in% results_attributes())
})

test_that("the procedure survives a row reorder and goes with the class", {
  skip_if_no_bayes_fixture()

  res <- bayes_results()
  procedure <- attr(res, "procedure")

  reordered <- res[rev(seq_len(nrow(res))), ]
  expect_s3_class(reordered, "nested_results")
  expect_identical(attr(reordered, "procedure"), procedure)

  narrowed <- res[, setdiff(names(res), ".grid")]
  expect_false(inherits(narrowed, "nested_results"))
  expect_null(attr(narrowed, "procedure"))
})
