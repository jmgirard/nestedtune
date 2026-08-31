# The two oracles for what a fold's dispatch puts on the wire (M23).
#
# Defined once and shared: `benchmarks/dispatch-payload-size.R` sources this
# file rather than keeping its own copy, so the number a benchmark run reports
# and the number the suite asserts cannot drift apart. M16's ledger lesson is
# the same shape -- a value copied from its definition into a second place needs
# something re-reading the definition, or the two diverge in silence.
#
# The two oracles share no arithmetic, which is the point (GP2 asks for two
# independent types for a numeric claim):
#
#   closed form  predicts serialized bytes from n / v / inner_v alone
#   copy count   counts occurrences of the data's own wire bytes in the stream
#
# A bug that drops an inner split shrinks the measured size, and the closed form
# would only catch it if the prediction were computed independently -- hence the
# scalars-only signature below, never lengths read off the object being
# predicted. The copy count cannot be fooled that way at all: it answers "how
# many copies of this frame are in here", which is the claim, not a proxy for it.

# Serialized bytes of anything.
payload_bytes <- function(x) length(serialize(x, NULL))

# The wire bytes of a frame's first `k` values in its `column`th column.
#
# R's XDR format writes doubles big-endian, so writeBin(endian = "big")
# reproduces exactly the bytes serialize() emits for them, and each copy of the
# frame in a stream contributes one occurrence.
#
# Numeric deliberately. R memoises CHARSXPs through the global string cache, so
# a character column deduplicates ACROSS copies inside one serialize() call and
# would report one copy where there are six -- the measurement would silently
# agree with a green result it had not earned.
sentinel_of <- function(frame, column = 1L, k = 40L) {
  values <- frame[[column]]
  stopifnot(is.double(values), length(values) >= k)
  writeBin(values[seq_len(k)], raw(), endian = "big")
}

count_data_copies <- function(x, sentinel) {
  length(grepRaw(sentinel, serialize(x, NULL), all = TRUE, fixed = TRUE))
}

# What a leaned payload must weigh, from the design's scalars and nothing else.
#
# An outer fold's analysis set is n * (v - 1) / v rows. The outer split stores
# that as an index; vfold leaves `out_id` as NA and derives the complement. Each
# inner split stores an analysis AND an assessment index, together partitioning
# the outer analysis set, because a split indexing the whole data cannot derive
# its complement -- the same term test-nested-resamples-memory.R's analytic_size()
# charges, and for the same reason. R stores an integer in 4 bytes.
predicted_lean_bytes <- function(n, v, inner_v) {
  outer_analysis <- n * (v - 1) / v
  4 * (outer_analysis + inner_v * outer_analysis)
}

# The fixture M23's criteria name, built the same way in the suite and in the
# benchmark.
payload_fixture_data <- function(n = 5000, p = 20, seed = 1) {
  set.seed(seed)
  d <- data.frame(y = stats::rnorm(n), matrix(stats::rnorm(n * p), n, p))
  names(d)[-1] <- paste0("x", seq_len(p))
  d
}

# The design M23's criteria name, built once for every consumer.
#
# It lived in test-parallel-payload.R until M26. A test file is sourced by
# testthat and by nothing else, so `benchmarks/probe-mori-dispatch.R` could not
# call it and re-typed the same five lines by hand -- while its header claimed
# the fixture was "defined once, in the test helpers, and sourced here rather
# than copied" and the assessment note attributed the published figures to
# `fixture_design()` by name. The two copies agreed when M26 checked, and
# nothing would have said so had they stopped agreeing; a mislabelled fixture is
# what failed M26's first review pass. Here, both consumers call one definition.
fixture_design <- function(
  constructor = nested_resamples,
  v = 5,
  inner_v = 5,
  n = 5000,
  p = 20
) {
  d <- payload_fixture_data(n = n, p = p)
  set.seed(2)
  list(
    data = d,
    design = constructor(
      d,
      rsample::vfold_cv(v = v),
      rsample::vfold_cv(v = inner_v)
    )
  )
}

# A workflow whose formula carries an EMPTY environment.
#
# A formula captures the environment it was written in, and R serializes an
# ordinary environment by contents while globalenv() and namespaces go by
# reference. Built inside a test function, `y ~ .` therefore drags that
# function's frame -- the design included -- onto the wire: measured
# 26,549,958 B against 1,761 B here, which would swamp the very quantity these
# tests bound.
payload_fixture_workflow <- function() {
  env <- new.env(parent = baseenv())
  workflows::add_model(
    workflows::add_formula(
      workflows::workflow(),
      stats::as.formula("y ~ .", env = env)
    ),
    parsnip::linear_reg()
  )
}
