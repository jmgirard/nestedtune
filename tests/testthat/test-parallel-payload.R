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

# `fixture_design()` moved to helper-payload-size.R at M26, so a benchmark can
# source it. It lived here, in a test file nothing outside testthat can source,
# which is why benchmarks/probe-mori-dispatch.R re-typed the design by hand and
# then attributed its figures to a definition it had never called.

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

    expect_lt(abs(measured - predicted) / predicted, 0.05)
    # The direction that matters independently of the band: whatever else it
    # holds, it is no longer carrying the data.
    expect_lt(measured, payload_bytes(shared))
  }
})

test_that("the dispatch gate recognises the payloads it must lean", {
  # The gate decides whether ANY of this milestone happens: `dispatch_folds()`
  # leans only when every payload passes `is_fold_payload()`. Nothing else here
  # goes through that decision -- the byte oracles call `lean_payload()`
  # directly, and a run that never leans is indistinguishable from one that
  # leans and rehydrates, because rehydrating is what makes them identical. So a
  # predicate that stopped recognising real fold payloads would turn the feature
  # off in production with every other test in this file still green.
  for (ctor in list(nested_resamples, rsample::nested_cv)) {
    fx <- fixture_design(constructor = ctor, v = 3, inner_v = 3, n = 200, p = 3)
    for (i in seq_len(nrow(fx$design))) {
      expect_true(is_fold_payload(fat_payload(fx$design, i)))
    }
  }

  # And the other direction, which is what keeps the fallback reachable: the
  # stand-in payloads test-parallel-interrupt.R dispatches carry no split at
  # all, and leaning them would error rather than degrade.
  expect_false(is_fold_payload(list(value = 1)))
  expect_false(is_fold_payload(list(marker = "f")))
  # `$` partial-matching would answer these from the wrong fields.
  expect_false(is_fold_payload(list(splits = 1, inner_resamples = 2)))

  # The shapes that carry the right NAMES but the wrong contents. Each of these
  # would reach further into the payload than it can safely go, so each has to
  # be refused by its own clause rather than by the name check above.
  real <- fat_payload(
    fixture_design(v = 3, inner_v = 3, n = 200, p = 3)$design,
    1L
  )
  expect_false(is_fold_payload(list(split = "not a split", inner = real$inner)))
  expect_false(is_fold_payload(list(split = real$split, inner = "not an rset")))
  expect_false(is_fold_payload(list(
    split = real$split,
    inner = real$inner[0, ]
  )))
  dataless <- real$inner
  dataless$splits <- lapply(dataless$splits, function(sp) {
    sp["data"] <- list(NULL)
    sp
  })
  expect_false(is_fold_payload(list(split = real$split, inner = dataless)))
})

test_that("an inner rset whose splits hold different frames is refused leaning", {
  # The invariant lean_payload() rests on: one frame per fold's inner splits,
  # taken off the first and written back onto all. check_nested() does not
  # enforce it, so the gate must -- otherwise a split is silently tuned on
  # another split's rows in parallel and its own serially (IP2), and on rows the
  # outer assessment set may hold (IP1).
  d <- payload_fixture_data(n = 200, p = 3)
  outer <- rsample::make_splits(list(analysis = 1:150, assessment = 151:200), d)
  heterogeneous <- rsample::manual_rset(
    list(
      rsample::make_splits(
        list(analysis = 1:60, assessment = 61:100),
        d[1:100, ]
      ),
      rsample::make_splits(
        list(analysis = 1:60, assessment = 61:100),
        d[51:150, ]
      )
    ),
    c("i1", "i2")
  )
  payload <- list(split = outer, inner = heterogeneous, seeds = c(1L, 2L))

  expect_false(is_fold_payload(payload))
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
  )) +
    n_folds * args_bytes

  # `.args` grows by one copy of the data on the leaned path, and it is charged
  # per fold because mirai serializes `.args` once per task -- counting it once
  # per run would flatter this ratio by exactly the term the milestone added.
  lean_args_bytes <- payload_bytes(
    list(
      object = payload_fixture_workflow(),
      grid = 3,
      metrics = NULL,
      data = shared
    )
  )
  lean_total <- sum(vapply(
    seq_len(n_folds),
    function(i) payload_bytes(lean_payload(fat_payload(fx$design, i), shared)),
    numeric(1)
  )) +
    n_folds * lean_args_bytes

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

test_that("a fold whose outer frame is not the shared one carries its own", {
  # `shared` is taken from the FIRST fold's outer split, so a design assembled
  # from folds over different frames has folds that do not match it. Each fold
  # is compared against `shared` rather than assumed to share it, and one that
  # does not carries its own copy -- larger on the wire, and correct, which is
  # the direction that matters.
  d1 <- payload_fixture_data(n = 200, p = 3)
  d2 <- payload_fixture_data(n = 200, p = 3, seed = 99)
  fold_over <- function(d) {
    list(
      split = rsample::make_splits(
        list(analysis = 1:150, assessment = 151:200),
        d
      ),
      inner = rsample::vfold_cv(d[1:150, ], v = 3),
      seeds = c(1L, 2L)
    )
  }
  first <- fold_over(d1)
  other <- fold_over(d2)
  shared <- first$split$data

  lean_first <- lean_payload(first, shared)
  lean_other <- lean_payload(other, shared)

  # The first fold IS the shared frame, so it carries neither copy; the second
  # matches nothing and carries both its outer and its inner frame.
  expect_null(lean_first$outer_data)
  expect_false(is.null(lean_other$outer_data))
  expect_false(is.null(lean_other$inner_data))

  # Both round-trip exactly, which is what keeps a mixed design correct.
  expect_identical(rehydrate_payload(lean_first, shared), first)
  expect_identical(rehydrate_payload(lean_other, shared), other)
})

test_that("a daemon receives the payload the serial branch would have passed", {
  skip_if_no_daemons()

  # The end-to-end half of the round trip. The tests above prove that
  # rehydrating undoes leaning in this process; this one proves the rehydration
  # actually happens in the OTHER one, which is the only place it matters and
  # the only place an `identical()` assertion cannot reach directly.
  #
  # Small on purpose: what is under test is what the worker received, not a
  # model fit, so the fixture is sized for dispatch rather than for the byte
  # accounting the tests above need.
  fx <- fixture_design(v = 3, inner_v = 3, n = 300, p = 4)
  payloads <- lapply(
    seq_len(nrow(fx$design)),
    function(i) fat_payload(fx$design, i)
  )

  on.exit(mirai::daemons(0), add = TRUE)
  start_daemons(2)

  # The mock runs inside a daemon and AFTER rehydration -- the worker is passed
  # to the task by value, so a mocked binding reaches it (M07) and receives what
  # the real one would. A mock that had to rehydrate itself would be reproducing
  # the code path it exists to cover.
  local_mocked_bindings(
    fold_task = function(payload, object, grid, metrics) {
      list(
        completed = TRUE,
        metrics = data.frame(
          .metric = "outer_rows",
          .estimate = nrow(payload$split$data)
        ),
        selected = data.frame(
          inner_rows = nrow(payload$inner$splits[[1L]]$data),
          fields = length(payload)
        ),
        grid = data.frame(inner_rows = 1L, .config = "pre0_mod1_post0"),
        notes = data.frame(
          location = character(0),
          type = character(0),
          note = character(0)
        )
      )
    }
  )

  out <- without_pkgload_warning(
    dispatch_folds(payloads, object = NULL, grid = NULL, metrics = NULL)
  )

  expect_identical(last_dispatch(), "parallel")
  # Every daemon saw the whole frame back on both the outer split and the inner
  # splits -- a rehydration that ran on neither would report NULL and error, and
  # one that ran on only the outer split would report the wrong inner count.
  expect_identical(
    vapply(out, function(x) x$metrics$.estimate, numeric(1)),
    rep(as.double(nrow(fx$data)), length(payloads))
  )
  expect_identical(
    vapply(out, function(x) x$selected$inner_rows, numeric(1)),
    rep(as.double(nrow(fx$data)), length(payloads))
  )
  # And nothing of the leaning survived into what the worker was handed: the
  # payload is back to its three fields, not five.
  expect_identical(
    vapply(out, function(x) x$selected$fields, numeric(1)),
    rep(3, length(payloads))
  )
})
