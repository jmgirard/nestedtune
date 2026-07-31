# What crosses to a worker (M23).
#
# The defect these pin: an rsplit carries the whole data frame, and R's
# serializer does not preserve the sharing that makes the in-memory design lean.
# Every split in a fold's payload therefore wrote its own copy -- six of them for
# v = 5, inner_v = 5 -- so `lobstr::obj_size()` reported 946.94 kB for something
# that put 5,141,166 B on the wire. An in-memory size assertion cannot see this
# at all, which is why the oracles below measure the serialized stream.
#
# Oracle records (validation doctrine; DESIGN.md Conventions declares that they
# live beside the asserting test):
#
#   O1  type      closed-form -- a storage model recomputed with explicit
#                 arithmetic, independent of the implementation under test
#       source    `predicted_lean_bytes()` in helper-payload-size.R, derived
#                 from n / v / inner_v alone and never from lengths read off the
#                 payload, so a lost inner split cannot shrink measurement and
#                 prediction together
#       asserts   the leaned payload's serialized size, in `a leaned payload
#                 weighs what the index vectors alone predict` below
#
#   O2  type      invariant -- a direct count of the property claimed, sharing
#                 no arithmetic with O1
#       source    `count_data_copies()` in helper-payload-size.R, searching the
#                 serialized stream for the big-endian wire bytes of a data
#                 column
#       asserts   that a fold's dispatch carries the data exactly once, in `a
#                 fold's dispatch carries the data exactly once` and in the
#                 rsample-design test below
#
# O1 and O2 are the two independent types GP2 requires for the size claim, and
# together they are what the roxygen claim on `nested_tune_grid()` rests on.
#
# The baseline every ratio here is measured against is RECOMPUTED, never frozen:
# each test builds the pre-milestone fat payload beside the lean one and
# compares. A frozen byte count would drift the first time rsample changed its
# split representation, and would then fail for a reason that has nothing to do
# with this package.

fixture_design <- function(constructor = nested_resamples, v = 5, inner_v = 5) {
  d <- payload_fixture_data()
  set.seed(2)
  list(
    data = d,
    design = constructor(d, rsample::vfold_cv(v = v), rsample::vfold_cv(v = inner_v))
  )
}

# The payload shape M23 replaced: split and inner rset passed whole.
fat_payload <- function(design, i) {
  list(
    split = design$splits[[i]],
    inner = design$inner_resamples[[i]],
    seeds = c(1L, 2L)
  )
}

test_that("a leaned payload weighs what the index vectors alone predict", {
  fx <- fixture_design()
  shared <- fx$data

  for (i in seq_len(nrow(fx$design))) {
    lean <- lean_payload(fat_payload(fx$design, i), shared)
    measured <- payload_bytes(lean)
    predicted <- predicted_lean_bytes(n = 5000, v = 5, inner_v = 5)

    expect_lt(abs(measured - predicted) / predicted, 0.15)
    # The direction that matters independently of the band: whatever else it
    # holds, it is no longer carrying the data.
    expect_lt(measured, payload_bytes(shared))
  }
})

test_that("a fold's dispatch carries the data exactly once", {
  fx <- fixture_design()
  shared <- fx$data
  sentinel <- sentinel_of(shared)
  args <- list(object = payload_fixture_workflow(), grid = 3, metrics = NULL)

  for (i in seq_len(nrow(fx$design))) {
    fat <- fat_payload(fx$design, i)
    lean <- lean_payload(fat, shared)

    # Six copies before, none in the payload after, and exactly one across
    # everything the task is sent -- the shared frame in `.args`.
    expect_identical(count_data_copies(fat, sentinel), 6L)
    expect_identical(count_data_copies(lean, sentinel), 0L)
    expect_identical(
      count_data_copies(list(lean, args, shared), sentinel),
      1L
    )
  }
})

test_that("rehydrating a leaned payload returns the serial path's own objects", {
  fx <- fixture_design()
  shared <- fx$data

  for (i in seq_len(nrow(fx$design))) {
    fat <- fat_payload(fx$design, i)
    restored <- rehydrate_payload(lean_payload(fat, shared), shared)

    # `identical()` on the whole payload, not on a chosen field: a rehydration
    # that rebuilt the inner rset from ids and classes could match on everything
    # anyone thought to assert and still differ in an attribute nobody did.
    expect_identical(restored, fat)
  }
})

test_that("a leaned run puts under a quarter of the pre-milestone bytes on the wire", {
  fx <- fixture_design()
  shared <- fx$data
  args_bytes <- payload_bytes(
    list(object = payload_fixture_workflow(), grid = 3, metrics = NULL)
  )
  n_folds <- nrow(fx$design)

  fat_total <- sum(vapply(
    seq_len(n_folds),
    function(i) payload_bytes(fat_payload(fx$design, i)),
    numeric(1)
  )) + n_folds * args_bytes

  # `.args` grows by one copy of the data on the leaned path, and it is charged
  # per fold because mirai serializes `.args` once per task -- counting it once
  # per run would flatter this ratio by exactly the term the milestone added.
  lean_args_bytes <- payload_bytes(
    list(object = payload_fixture_workflow(), grid = 3, metrics = NULL,
         data = shared)
  )
  lean_total <- sum(vapply(
    seq_len(n_folds),
    function(i) payload_bytes(lean_payload(fat_payload(fx$design, i), shared)),
    numeric(1)
  )) + n_folds * lean_args_bytes

  expect_lt(lean_total / fat_total, 0.25)
})

test_that("a design whose folds share no frame is leaned too", {
  fx <- fixture_design(constructor = rsample::nested_cv)
  shared <- fx$data

  for (i in seq_len(nrow(fx$design))) {
    fat <- fat_payload(fx$design, i)
    # rsample materializes each outer fold's analysis set, so THIS fold's inner
    # splits share a frame that is neither the original data nor any other
    # fold's -- the case a single shared copy in `.args` cannot serve.
    inner_frame <- fx$design$inner_resamples[[i]]$splits[[1]]$data
    expect_false(identical(inner_frame, shared))

    sentinel <- sentinel_of(inner_frame)
    lean <- lean_payload(fat, shared)

    expect_identical(count_data_copies(fat, sentinel), 5L)
    expect_identical(count_data_copies(list(lean, shared), sentinel), 1L)
    expect_identical(rehydrate_payload(lean, shared), fat)
  }
})
