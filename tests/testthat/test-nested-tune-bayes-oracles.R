# Oracle records for nested_tune_bayes() (DESIGN Conventions: oracles are
# recorded in the test file that asserts them). The numbering is this file's
# own; test-nested-tune-grid-oracles.R keeps its O1-O4 for the grid path.
#
# O1 -- type "live" (reference implementation). Source: the tidymodels
#   pipeline itself, recomputed at test time by reference_nested_bayes_loop()
#   in helper-orchestration.R, written from the documented seed contract --
#   `set.seed(s)`, one `sample.int(.Machine$integer.max, 2 * n)`, fold i
#   tuning under element 2i-1 with the kind pinned and `control_bayes(seed =
#   <that element>, allow_par = FALSE)`, fitting under element 2i -- and never
#   from the driver's output. Pinned by "per-fold metrics and selections match
#   a hand-rolled Bayesian reference loop" (deterministic) and "the Bayesian
#   reference loop also matches with a stochastic engine". Satisfies AC2.
#
# O2 -- type "invariant". Source: no external one; the agreement between two
#   independent internal routes is the oracle. At `iter = 0` a Bayesian run
#   scores its initial candidates and proposes nothing, so it must equal
#   nested_tune_grid() on the grid those candidates form. The fixture has two
#   integer-valued parameters, and for two or more parameters
#   dials::grid_space_filling() returns sfd's precomputed design -- the same
#   rows in the same order under every seed, with no draw (measured
#   2026-09-01, dials 1.4.4; a single parameter is drawn from the stream and
#   differs across seeds) -- so one grid built outside the loop is what every
#   fold's Bayesian run scored. Pinned by "at iter = 0 the Bayesian path is the
#   grid path on the space-filling grid". Satisfies AC3.
#
# O3 -- type "invariant" (mode independence), pinned in
#   test-parallel-identity.R as BC10: the same seed gives an identical result
#   serially and at two daemon counts. Recorded here for the audit; the
#   assertion lives with the other dispatch identities.
#
# O1 and O2 are the >=2 independent oracle types GP2 asks of the package's own
# contribution -- the call, the seed, the record, the loop -- at the initial
# stage. The iteration stage has O1 and O3 only: the proposals are tune's own
# Gaussian-process search inside D-002's boundary, and no independent oracle
# for them exists here or in a review brief (plan gate, 2026-09-01).

test_that("per-fold metrics and selections match a hand-rolled Bayesian reference loop", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- det_nested(d)
  p <- bayes_param_info(wf)
  ms <- reg_metrics()

  # The suite's shared run, built with these objects under seed 20 -- which is
  # the seed the reference below starts from.
  res <- bayes_results()
  expect_true(all(res$.completed))

  ref <- reference_nested_bayes_loop(
    wf,
    folds,
    iter = 2,
    initial = 3,
    objective = tune::exp_improve(),
    param_info = p,
    metrics = ms,
    seed = 20,
    metric_name = "rmse"
  )

  # The seeds the driver reports must be the ones the documented contract
  # derives -- checked before the metrics, because a driver that both
  # misassigns and misreports could otherwise agree with a loop fed its own
  # numbers.
  expect_identical(res$.tuning_seed, ref_field(ref, "tuning_seed"))
  expect_identical(res$.outer_fit_seed, ref_field(ref, "outer_fit_seed"))

  for (i in seq_len(nrow(res))) {
    expect_identical(res$.metrics[[i]], ref[[i]]$metrics)
    expect_identical(res$.selected[[i]], ref[[i]]$selected)
  }

  # The search ran: at least one proposal was scored in some fold. Without
  # this the reference could agree with a driver that never iterated, since
  # both would then be the initial stage alone.
  proposed <- vapply(res$.grid, function(g) any(g$.iter > 0L), logical(1))
  expect_true(any(proposed))
})

test_that("the Bayesian reference loop also matches with a stochastic engine", {
  skip_if_no_bayes_fixture(stochastic = TRUE)

  d <- make_reg_data()
  wf <- stoch_workflow(d)
  p <- bayes_stoch_param_info(wf)
  ms <- reg_metrics()

  set.seed(12)
  folds <- nested_resamples(
    d,
    outside = rsample::vfold_cv(v = 3),
    inside = rsample::vfold_cv(v = 3)
  )

  set.seed(21)
  res <- nested_tune_bayes(
    wf,
    folds,
    iter = 2,
    initial = 3,
    param_info = p,
    metrics = ms
  )
  expect_true(all(res$.completed))

  ref <- reference_nested_bayes_loop(
    wf,
    folds,
    iter = 2,
    initial = 3,
    objective = tune::exp_improve(),
    param_info = p,
    metrics = ms,
    seed = 21,
    metric_name = "rmse"
  )

  expect_identical(res$.tuning_seed, ref_field(ref, "tuning_seed"))
  expect_identical(res$.outer_fit_seed, ref_field(ref, "outer_fit_seed"))

  for (i in seq_len(nrow(res))) {
    expect_identical(res$.metrics[[i]], ref[[i]]$metrics)
    expect_identical(res$.selected[[i]], ref[[i]]$selected)
  }
})

test_that("at iter = 0 the Bayesian path is the grid path on the space-filling grid", {
  skip_if_no_bayes_fixture()

  d <- make_reg_data()
  wf <- bayes_workflow(d)
  folds <- det_nested(d)
  p <- bayes_param_info(wf)
  ms <- reg_metrics()

  # The grid every fold's Bayesian run scores: built once, outside any seed
  # scope, which is the O2 premise -- and asserted rather than assumed, so a
  # dials release that started drawing this design would fail here by name.
  g <- dials::grid_space_filling(p, size = 3)
  set.seed(1)
  again <- dials::grid_space_filling(p, size = 3)
  expect_identical(again, g)
  expect_identical(nrow(g), 3L)

  set.seed(20)
  bayes <- nested_tune_bayes(
    wf,
    folds,
    iter = 0,
    initial = 3,
    param_info = p,
    metrics = ms
  )
  set.seed(20)
  grid <- nested_tune_grid(wf, folds, grid = g, param_info = p, metrics = ms)

  expect_true(all(bayes$.completed))
  expect_true(all(grid$.completed))
  expect_identical(bayes$.tuning_seed, grid$.tuning_seed)

  for (i in seq_len(nrow(bayes))) {
    expect_identical(bayes$.metrics[[i]], grid$.metrics[[i]])
    expect_identical(bayes$.selected[[i]], grid$.selected[[i]])

    # The grid record plus an `.iter` column of zeros: the same columns in the
    # same order, holding the same values, and then the iteration.
    b <- bayes$.grid[[i]]
    r <- grid$.grid[[i]]
    expect_identical(names(b), c(names(r), ".iter"))
    for (nm in names(r)) {
      expect_identical(b[[nm]], r[[nm]])
    }
    expect_identical(b$.iter, rep(0L, nrow(r)))

    # And the grid path scored exactly the grid it was handed, so the identity
    # above is with `g` and not merely between two runs of the same code.
    expect_identical(sort(r$df1 * 100L + r$df2), sort(g$df1 * 100L + g$df2))
  }
})

# AC1: every method registered on the class runs on a Bayesian result.
#
# The list of methods is read from NAMESPACE at test time, so a method added
# later fails here by its own line until this table gains a call for it. Each
# call is asserted to run without error and nothing more: what the methods
# answer is pinned elsewhere, on grid results, and their answers do not depend
# on which tuner ran.

test_that("every nested_results method in NAMESPACE runs on a Bayesian result", {
  skip_if_no_bayes_fixture()
  skip_if_not_installed("tibble")

  res <- bayes_results()
  df <- as.data.frame(res)
  tbl <- tibble::as_tibble(df)

  types <- eval(formals(autoplot.nested_results)$type)
  expect_gte(length(types), 2L)

  calls <- list(
    "S3method(\"[\",nested_results)" = function() {
      res[rev(seq_len(nrow(res))), ]
    },
    "S3method(\"names<-\",nested_results)" = function() {
      x <- res
      names(x) <- names(res)
      x
    },
    "S3method(agreement,nested_results)" = function() agreement(res),
    "S3method(autoplot,nested_results)" = function() {
      for (type in types) {
        print(autoplot(res, type = type))
      }
    },
    "S3method(collect_metrics,nested_results)" = function() {
      collect_metrics(res)
    },
    "S3method(dplyr_reconstruct,nested_results)" = function() {
      dplyr::dplyr_reconstruct(df, res)
    },
    "S3method(print,nested_results)" = function() print_text(res),
    "S3method(print,summary.nested_results)" = function() {
      cli::cli_fmt(print(summary(res)))
    },
    "S3method(rbind,nested_results)" = function() rbind(res, res),
    "S3method(summary,nested_results)" = function() summary(res),
    "S3method(vec_cast,data.frame.nested_results)" = function() {
      vctrs::vec_cast(res, df)
    },
    # The two casts INTO the class refuse by contract (a table carries no
    # record to build a run from), so running them is running their refusal.
    "S3method(vec_cast,nested_results.data.frame)" = function() {
      expect_error(
        vctrs::vec_cast(df, res),
        class = "vctrs_error_incompatible_type"
      )
    },
    "S3method(vec_cast,nested_results.nested_results)" = function() {
      vctrs::vec_cast(res, res)
    },
    "S3method(vec_cast,nested_results.tbl_df)" = function() {
      expect_error(
        vctrs::vec_cast(tbl, res),
        class = "vctrs_error_incompatible_type"
      )
    },
    "S3method(vec_cast,tbl_df.nested_results)" = function() {
      vctrs::vec_cast(res, tbl)
    },
    "S3method(vec_cbind_frame_ptype,nested_results)" = function() {
      vctrs::vec_cbind_frame_ptype(res)
    },
    "S3method(vec_ptype2,data.frame.nested_results)" = function() {
      vctrs::vec_ptype2(df, res)
    },
    "S3method(vec_ptype2,nested_results.data.frame)" = function() {
      vctrs::vec_ptype2(res, df)
    },
    "S3method(vec_ptype2,nested_results.nested_results)" = function() {
      vctrs::vec_ptype2(res, res)
    },
    "S3method(vec_ptype2,nested_results.tbl_df)" = function() {
      vctrs::vec_ptype2(res, tbl)
    },
    "S3method(vec_ptype2,tbl_df.nested_results)" = function() {
      vctrs::vec_ptype2(tbl, res)
    },
    "S3method(vec_restore,nested_results)" = function() {
      vctrs::vec_restore(df, res)
    }
  )

  namespace <- readLines(test_path("..", "..", "NAMESPACE"))
  registered <- namespace[grepl("nested_results)", namespace, fixed = TRUE)]
  # The enumeration cannot silently empty: the class has methods.
  expect_gt(length(registered), 10L)

  # Every method the anchor selects has a call. The table also runs the four
  # pair methods the anchor skips -- the casts and common types whose second
  # class is this one -- and every key is a line NAMESPACE holds, so a key for
  # a method that was renamed or dropped fails here rather than testing air.
  expect_identical(setdiff(registered, names(calls)), character(0))
  expect_identical(setdiff(names(calls), namespace), character(0))

  for (method in names(calls)) {
    expect_no_error(calls[[method]](), message = method)
  }
})
