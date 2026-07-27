library(testthat)
library(nestedtune)

# HangTraceReporter is defined in tests/testthat/helper-hang-trace.R so that a
# test file can see it -- testthat sources helpers, never this runner, so a
# class defined here is untestable (M16 T1). It is needed BEFORE test_check()
# runs, hence the explicit source; testthat sourcing it again into the test
# environment is harmless.
#
# Path is relative to tests/, which is the working directory R CMD check runs
# this file from.
source("testthat/helper-hang-trace.R")

test_check(
  "nestedtune",
  # CheckReporter$new(), never check_reporter(): the latter returns the string
  # "Check" for test_check() to resolve, and MultiReporter needs the object.
  reporter = MultiReporter$new(
    reporters = list(CheckReporter$new(), HangTraceReporter$new())
  )
)
