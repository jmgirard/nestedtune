# The suite-level fixture cache (M12).
#
# The cache exists to stop the suite rebuilding the same tuning run dozens of
# times, and it is only safe if a served result is indistinguishable from a
# fresh build. Two things have to hold for that, and both are asserted here: a
# hit returns the same value, conditions and RNG state a build would, and the
# key separates every fixture this suite actually asks for.
#
# The second is the one with teeth. A key that fails to separate two distinct
# fixtures does not raise anything -- it quietly hands one test another test's
# run, and the test still passes. So the separation is checked against the real
# fixture objects, pairwise, rather than trusted.

# A stand-in for the orchestrator: cheap, and net-zero on the RNG exactly as
# `nested_tune_grid()` and `nested_final_fit()` are (D-011). Nothing here fits a
# model -- what is under test is the cache, not the loop.
fake_builds <- new.env(parent = emptyenv())
fake_builds$n <- 0L

fake_fit <- function(object, resamples, grid = 10, metrics = NULL) {
  fake_builds$n <- fake_builds$n + 1L
  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old <- if (had) get(".Random.seed", envir = globalenv())
  on.exit(if (had) assign(".Random.seed", old, envir = globalenv()), add = TRUE)
  draw <- sample.int(.Machine$integer.max, 1L)
  rlang::warn("fake fold failed", class = "fake_failure")
  rlang::inform("fake progress note")
  list(object = object, resamples = resamples, grid = grid,
       metrics = metrics, draw = draw)
}

quiet <- function(expr) suppressMessages(suppressWarnings(expr))

test_that("a cache hit is identical to the build it replaces", {
  before <- fake_builds$n

  set.seed(101)
  first <- quiet(memoised(fake_fit("wf", "design", grid = 1:3)))
  set.seed(101)
  second <- quiet(memoised(fake_fit("wf", "design", grid = 1:3)))

  expect_identical(second, first)
  # One build for two requests: the second call never reached fake_fit().
  expect_identical(fake_builds$n - before, 1L)
})

test_that("a cache hit re-signals the conditions the build emitted", {
  set.seed(102)
  expect_warning(
    suppressMessages(memoised(fake_fit("wf", "conditions"))),
    class = "fake_failure"
  )

  # The second request builds nothing, so every condition it raises came from
  # the replay. Without it, the test above would pass on the build and fail
  # here -- which is the failure mode nested expectations elsewhere in the
  # suite would hit first.
  set.seed(102)
  expect_warning(
    suppressMessages(memoised(fake_fit("wf", "conditions"))),
    class = "fake_failure"
  )
  set.seed(102)
  expect_message(
    suppressWarnings(memoised(fake_fit("wf", "conditions"))),
    "fake progress note"
  )
})

test_that("a cache hit leaves the RNG where a build would", {
  set.seed(103)
  quiet(memoised(fake_fit("wf", "rng-state")))
  after_build <- get(".Random.seed", envir = globalenv())

  set.seed(103)
  quiet(memoised(fake_fit("wf", "rng-state")))
  after_hit <- get(".Random.seed", envir = globalenv())

  # Both are net-zero, so they agree. A builder that advanced the caller's RNG
  # could not be memoised at all: the hit would leave a different state and
  # every seeded test after it would diverge.
  expect_identical(after_hit, after_build)
})

test_that("the wrapped call sees the test as its caller, not this helper", {
  caller_probe <- function(object, resamples, grid = 10, metrics = NULL) {
    parent.frame()
  }
  here <- environment()

  # Load-bearing for `nested_final_fit()`, which re-evaluates its design's
  # stored `inside` call in `rlang::caller_env()`. If memoised() let itself
  # become the caller, that call would be evaluated in a frame holding this
  # helper's locals instead of the test's, and a design parameterised in the
  # test would resolve against the wrong thing or not at all.
  set.seed(111)
  expect_identical(memoised(caller_probe("wf", "caller")), here)
})

test_that("the key separates the seed, and argument order does not", {
  set.seed(104)
  a <- fixture_key("f", list(object = "wf", resamples = "d"))
  set.seed(104)
  b <- fixture_key("f", list(resamples = "d", object = "wf"))
  set.seed(105)
  c <- fixture_key("f", list(object = "wf", resamples = "d"))

  expect_identical(b, a)
  expect_false(identical(c, a))
})

test_that("a different seed rebuilds rather than serving the first result", {
  before <- fake_builds$n

  set.seed(106)
  first <- quiet(memoised(fake_fit("wf", "seeded")))
  set.seed(107)
  second <- quiet(memoised(fake_fit("wf", "seeded")))

  expect_identical(fake_builds$n - before, 2L)
  expect_false(identical(second$draw, first$draw))
})

test_that("the key separates every fixture signature this suite asks for", {
  skip_if_no_engines(stochastic = TRUE)

  d <- make_reg_data()
  u <- unstable_data()

  # Every distinct combination the converted files request. Each is keyed at
  # the same RNG state, so what separates them is the arguments alone -- if two
  # of these collided, the cache would serve one test the other's run.
  signatures <- list(
    det = function() {
      list(object = det_workflow(d), resamples = det_nested(d),
           grid = det_grid(), metrics = reg_metrics())
    },
    det_no_metrics = function() {
      list(object = det_workflow(d), resamples = det_nested(d),
           grid = det_grid(), metrics = NULL)
    },
    unstable = function() {
      list(object = unstable_workflow(u), resamples = det_nested(u, v = 4),
           grid = unstable_grid(), metrics = reg_metrics())
    },
    stochastic = function() {
      list(object = stoch_workflow(d), resamples = det_nested(d),
           grid = stoch_grid(), metrics = reg_metrics())
    },
    break_inner_2 = function() {
      list(object = det_workflow(d),
           resamples = break_fold(det_nested(d), 2L, "inner tuning"),
           grid = det_grid(), metrics = reg_metrics())
    },
    break_outer_2 = function() {
      list(object = det_workflow(d),
           resamples = break_fold(det_nested(d), 2L, "outer fit"),
           grid = det_grid(), metrics = reg_metrics())
    },
    break_outer_3 = function() {
      list(object = det_workflow(d),
           resamples = break_fold(det_nested(d), 3L, "outer fit"),
           grid = det_grid(), metrics = reg_metrics())
    },
    break_every = function() {
      list(object = det_workflow(d), resamples = break_every_fold(det_nested(d)),
           grid = det_grid(), metrics = reg_metrics())
    },
    break_inner_split = function() {
      list(object = det_workflow(d),
           resamples = break_inner_split(det_nested(d), 2L),
           grid = det_grid(), metrics = reg_metrics())
    },
    final = function() {
      list(object = det_workflow(d), resamples = final_nested(d),
           grid = det_grid(), metrics = reg_metrics())
    },
    final_no_metrics = function() {
      list(object = det_workflow(d), resamples = final_nested(d),
           grid = det_grid(), metrics = NULL)
    }
  )

  keys <- vapply(signatures, function(build) {
    set.seed(2)
    fixture_key("nested_tune_grid", build())
  }, character(1))

  expect_identical(anyDuplicated(keys), 0L)
})

test_that("the same signature keys the same way twice, so it is built once", {
  skip_if_no_engines()

  d <- make_reg_data()
  twice <- vapply(1:2, function(i) {
    set.seed(2)
    fixture_key("nested_tune_grid", list(
      object = det_workflow(d), resamples = det_nested(d),
      grid = det_grid(), metrics = reg_metrics()
    ))
  }, character(1))

  # `rlang::hash()` on these objects alone would fail here: a recipe's `terms`
  # quosures capture the frame holding the recipe itself, and `metric_set()`'s
  # environment refers to itself, so serialization numbers those references
  # differently each construction. canonical_form() is what makes the two equal.
  expect_identical(twice[[2L]], twice[[1L]])
  expect_false(identical(
    rlang::hash(det_workflow(d)), rlang::hash(det_workflow(d))
  ))
})

test_that("the report counts one build per signature and every request", {
  before <- nrow(fixture_cache_report())

  set.seed(108)
  quiet(memoised(fake_fit("wf", "reported")))
  set.seed(108)
  quiet(memoised(fake_fit("wf", "reported")))
  set.seed(108)
  quiet(memoised(fake_fit("wf", "reported")))

  report <- fixture_cache_report()
  row <- report[grepl("reported", report$signature, fixed = TRUE), ]

  expect_identical(nrow(report) - before, 1L)
  expect_identical(row$builds, 1L)
  expect_identical(row$requests, 3L)
})

test_that("the same call under two seeds is two fixtures, not one rebuilt", {
  set.seed(109)
  quiet(memoised(fake_fit("wf", "two-seeds")))
  set.seed(110)
  quiet(memoised(fake_fit("wf", "two-seeds")))

  report <- fixture_cache_report()
  rows <- report[grepl("two-seeds", report$signature, fixed = TRUE), ]

  # Deliberate: the seed is part of what a fixture is, so this is two fixtures
  # built once each. Reporting it as one signature built twice would make the
  # `builds` column cry wolf at exactly the tests that check seed sensitivity.
  expect_identical(nrow(rows), 2L)
  expect_identical(rows$builds, c(1L, 1L))
})
