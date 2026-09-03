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

# Composed in the helper rather than here, so `test-hang-trace.R` can assert
# the composite declares the live-update mode the trace needs under parallel
# test files (M52); see the comment on check_reporter_with_hang_trace().
test_check("nestedtune", reporter = check_reporter_with_hang_trace())
