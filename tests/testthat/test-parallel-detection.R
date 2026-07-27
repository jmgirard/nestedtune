# Detection of the parallel dispatch branch.
#
# The threshold is tune's, not ours (D-018): tune goes parallel only at two or
# more connected daemons, so "parallel" means the same thing in both packages.
# RR03 B1 read that from tune:::choose_framework and flagged the test-design
# consequence these tests exist to serve -- a suite that starts ONE daemon and
# believes it exercised the parallel path is comparing serial to serial.

test_that("the dispatch threshold is two daemons, matching tune's", {
  expect_false(use_parallel(0L))
  expect_false(use_parallel(1L))
  expect_true(use_parallel(2L))
  expect_true(use_parallel(8L))
})

test_that("a NULL or missing worker count is not parallel", {
  expect_false(use_parallel(NULL))
  expect_false(use_parallel(NA_integer_))
  expect_false(use_parallel(integer(0)))
})

test_that("mirai_workers() reports 0 when mirai is not installed", {
  local_mocked_bindings(is_mirai_installed = function() FALSE)
  expect_identical(mirai_workers(), 0L)
})

test_that("mirai_workers() counts connected daemons", {
  skip_if_not_installed("mirai")
  skip_on_cran()

  mirai::daemons(0)
  expect_identical(mirai_workers(), 0L)

  mirai::daemons(2)
  on.exit(mirai::daemons(0), add = TRUE)
  expect_identical(mirai_workers(), 2L)
  expect_true(use_parallel(mirai_workers()))
})

test_that("the branch a run took is recorded out-of-band, not on the result", {
  # BC1 needs a test to prove the parallel branch ran, but the same criterion
  # demands the parallel result be identical() to the serial one -- so the
  # evidence cannot live on the returned object. It lives in an internal
  # environment instead, which is what makes both halves of BC1 satisfiable.
  reset_dispatch_record()
  expect_null(last_dispatch())

  record_dispatch("serial")
  expect_identical(last_dispatch(), "serial")

  record_dispatch("parallel")
  expect_identical(last_dispatch(), "parallel")
})
