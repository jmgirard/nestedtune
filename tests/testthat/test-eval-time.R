# Oracle records (DESIGN Conventions: oracles are recorded in the test file
# that asserts them). The records for the behavioral oracles are added with the
# tests that pin them; this file opens with the fixture's own properties, which
# are asserted rather than assumed because every comparison below is vacuous
# without them.

# The evaluation times a censored-regression metric is measured at (M41).
#
# Everything here runs on the srv_* fixture (helper-orchestration.R), built so
# `eval_time` has something to move: a mixture of early failures no log-normal
# can reproduce and a long tail no exponential can match, so the grid's three
# distributions rank differently at the fixture's early time than at its late
# one. The first tests assert the fixture still has those properties -- without
# them a run at either time would agree with a run at the other for reasons
# having nothing to do with whether the argument was forwarded.

test_that("both evaluation times have observations at risk and events on either side", {
  skip_if_no_censored()

  data <- srv_data()
  times <- srv_eval_times()

  for (t in times) {
    profile <- srv_risk_profile(data, t)
    expect_gt(profile[["at_risk"]], 0L)
    expect_gt(profile[["events_before"]], 0L)
    expect_gt(profile[["events_after"]], 0L)
  }

  # The metric is computed on each outer fold's assessment set, not on the
  # whole frame, so the property has to hold there too -- a fold whose
  # assessment set has nobody left at risk reports a Brier score that says
  # nothing about the evaluation time.
  nested <- srv_nested(data)
  for (i in seq_len(nrow(nested))) {
    assessment <- rsample::assessment(nested$splits[[i]])
    for (t in times) {
      profile <- srv_risk_profile(assessment, t)
      expect_gt(profile[["at_risk"]], 0L)
      expect_gt(profile[["events_before"]], 0L)
      expect_gt(profile[["events_after"]], 0L)
    }
  }
})

test_that("the fixture's grid is ranked differently at the two evaluation times", {
  skip_if_no_censored()

  data <- srv_data()
  times <- srv_eval_times()
  workflow <- srv_workflow(data)

  set.seed(7)
  resamples <- rsample::vfold_cv(data, v = 3)

  ranked <- lapply(times, function(t) {
    set.seed(99)
    tuned <- tune::tune_grid(
      workflow,
      resamples = resamples,
      grid = srv_grid(),
      metrics = srv_metrics(),
      eval_time = t,
      control = tune::control_grid(allow_par = FALSE)
    )
    scored <- tune::collect_metrics(tuned)
    scored <- scored[scored$.metric == "brier_survival", ]
    scored[order(scored$mean), ]
  })

  early <- ranked[[1L]]
  late <- ranked[[2L]]

  # Which candidate is best, not merely by how much: the log-normal is the best
  # of the three at the early time and the worst at the late one, so a run that
  # ignored `eval_time` could not produce both orders.
  expect_identical(early$dist[[1L]], "lognormal")
  expect_identical(late$dist[[nrow(late)]], "lognormal")
  expect_false(identical(early$dist, late$dist))

  # And the winner is not a tie broken by rounding. Measured 2026-09-01 on
  # tune 2.1.0 / censored 0.3.4: 1.0% at the early time, 3.5% at the late one.
  for (scored in ranked) {
    expect_gt((scored$mean[[2L]] - scored$mean[[1L]]) / scored$mean[[1L]], 0.005)
  }
})
