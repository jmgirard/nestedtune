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
#
# The build counter lives in the global environment rather than in this file's,
# and that is not fastidiousness. `memoised()` keys on the canonical form of the
# builder itself, which expands the builder's lexical environment; a counter
# sitting in `fake_fit()`'s own scope would therefore change the key every time
# it ticked, and the cache would never hit. Named environments -- a namespace,
# the global environment -- are taken by their name instead of expanded, so a
# counter kept there is invisible to the key. The real builders are package
# functions whose environment is the nestedtune namespace, which is why they are
# stable for exactly the same reason.
assign(".fixture_fake_builds", 0L, envir = globalenv())
fake_build_count <- function() get(".fixture_fake_builds", envir = globalenv())

fake_fit <- function(object, resamples, grid = 10, metrics = NULL) {
  assign(".fixture_fake_builds", fake_build_count() + 1L, envir = globalenv())
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
  before <- fake_build_count()

  set.seed(101)
  first <- quiet(memoised(fake_fit("wf", "design", grid = 1:3)))
  set.seed(101)
  second <- quiet(memoised(fake_fit("wf", "design", grid = 1:3)))

  expect_identical(second, first)
  # One build for two requests: the second call never reached fake_fit().
  expect_identical(fake_build_count() - before, 1L)
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
  a <- fixture_key(fake_fit, list(object = "wf", resamples = "d"))
  set.seed(104)
  b <- fixture_key(fake_fit, list(resamples = "d", object = "wf"))
  set.seed(105)
  c <- fixture_key(fake_fit, list(object = "wf", resamples = "d"))

  expect_identical(b, a)
  expect_false(identical(c, a))
})

test_that("the key separates the function, not just the name it was called by", {
  one <- function(object, resamples, grid = 10, metrics = NULL) "ONE"
  two <- function(object, resamples, grid = 10, metrics = NULL) "TWO"

  # The cache outlives the file that filled it, so two files that memoise
  # same-named local builders meet in it. Keyed on the callee's source text
  # alone, the second would silently be served the first one's value.
  set.seed(120)
  a <- fixture_key(one, list(object = "wf", resamples = "d"))
  set.seed(120)
  b <- fixture_key(two, list(object = "wf", resamples = "d"))

  expect_false(identical(b, a))

  g <- one
  set.seed(121)
  first <- memoised(g("wf", "collide"))
  g <- two
  set.seed(121)
  second <- memoised(g("wf", "collide"))

  expect_identical(first, "ONE")
  expect_identical(second, "TWO")
})

test_that("the key separates what the design's inner spec resolves in the caller", {
  skip_if_no_engines()

  d <- make_reg_data()
  # `nested_final_fit()` re-evaluates this specification in its caller's frame,
  # so the same request from a frame that binds `v` and one that does not are
  # two different runs -- and the second aborts rather than returning anything.
  parameterised <- local({
    v <- 3
    set.seed(11)
    nested_resamples(d, outside = rsample::vfold_cv(v = 2),
                     inside = rsample::vfold_cv(v = v))
  })

  with_v <- local({
    v <- 3
    set.seed(2)
    fixture_key(nested_final_fit, list(object = det_workflow(d),
                                       resamples = parameterised),
                env = environment())
  })
  without_v <- local({
    set.seed(2)
    fixture_key(nested_final_fit, list(object = det_workflow(d),
                                       resamples = parameterised),
                env = environment())
  })

  expect_false(identical(without_v, with_v))
})

test_that("a call with no named arguments keys rather than erroring", {
  no_args <- function() "nothing"

  set.seed(122)
  expect_identical(memoised(no_args()), "nothing")
  set.seed(122)
  expect_identical(memoised(no_args()), "nothing")
})

test_that("a hit re-signals conditions that are neither warning nor message", {
  signaller <- function(object, resamples, grid = 10, metrics = NULL) {
    rlang::signal("custom diagnostic", class = "fixture_probe")
    "value"
  }
  seen <- function(expr) {
    n <- 0L
    withCallingHandlers(expr, fixture_probe = function(cnd) n <<- n + 1L)
    n
  }

  set.seed(123)
  built <- seen(memoised(signaller("wf", "signal")))
  set.seed(123)
  replayed <- seen(memoised(signaller("wf", "signal")))

  expect_identical(built, 1L)
  expect_identical(replayed, 1L)
})

test_that("a different seed rebuilds rather than serving the first result", {
  before <- fake_build_count()

  set.seed(106)
  first <- quiet(memoised(fake_fit("wf", "seeded")))
  set.seed(107)
  second <- quiet(memoised(fake_fit("wf", "seeded")))

  expect_identical(fake_build_count() - before, 2L)
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
    fixture_key(nested_tune_grid, build())
  }, character(1))

  expect_identical(anyDuplicated(keys), 0L)
})

test_that("the same signature keys the same way twice, so it is built once", {
  skip_if_no_engines()

  d <- make_reg_data()
  twice <- vapply(1:2, function(i) {
    set.seed(2)
    fixture_key(nested_tune_grid, list(
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

test_that("one call written two ways is one fixture, reported as built twice", {
  # The failure the report exists to name. These two requests key differently,
  # so both build -- and both build the same thing. Grouping the table by the
  # call's source text would show two innocent rows; grouping by what was built
  # shows one fixture paid for twice, which is the fact worth acting on.
  set.seed(112)
  quiet(memoised(fake_fit("wf", "same-value", grid = 10)))
  set.seed(112)
  quiet(memoised(fake_fit(object = "wf", resamples = "same-value")))

  report <- fixture_cache_report()
  rows <- report[grepl("same-value", report$signature, fixed = TRUE), ]

  expect_identical(nrow(rows), 1L)
  expect_identical(rows$builds, 2L)
  expect_identical(rows$requests, 2L)
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

test_that("the scaffolding above leaves the shared cache as it found it", {
  # Everything this file built went into the cache the rest of the suite uses,
  # including -- deliberately -- one fixture built twice. Left there, the
  # run-wide report would carry a finding that is really this file's test data.
  # The assertions above have already read these entries; nothing needs them now.
  removed <- fixture_cache_forget("^(fake_fit|caller_probe|g|no_args|signaller)\\(")
  expect_gt(removed, 0L)

  remaining <- fixture_cache_report()$signature
  expect_false(any(grepl("^(fake_fit|caller_probe|g|no_args|signaller)\\(", remaining)))
})
