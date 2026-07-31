# the incompatible abort renders at one symbol, two, five, and a mixed pool

    Code
      check_daemons_can_load(preflight_outcome(reports(TRUE, missing = list(
        "rehydrate_payload")), timeout = 30000))
    Condition
      Error:
      ! 1 of 1 mirai daemon is running a different build of nestedtune.
      i The daemon could not find `rehydrate_payload`, which this session's copy defines and the outer loop calls by name on the worker.
      i Reinstall nestedtune into the daemons' library, then restart the pool with `mirai::daemons(0)` followed by `mirai::daemons(n)` -- a running daemon keeps the namespace it already loaded.
      i Alternatively call `mirai::daemons(0)` to run serially -- results are identical either way.
    Code
      check_daemons_can_load(preflight_outcome(reports(TRUE, missing = list(c(
        "nested_fold_fit", "rehydrate_payload"))), timeout = 30000))
    Condition
      Error:
      ! 1 of 1 mirai daemon is running a different build of nestedtune.
      i The daemon could not find `nested_fold_fit`, `rehydrate_payload`, which this session's copy defines and the outer loop calls by name on the worker.
      i Reinstall nestedtune into the daemons' library, then restart the pool with `mirai::daemons(0)` followed by `mirai::daemons(n)` -- a running daemon keeps the namespace it already loaded.
      i Alternatively call `mirai::daemons(0)` to run serially -- results are identical either way.
    Code
      check_daemons_can_load(preflight_outcome(reports(TRUE, missing = list(c("a",
        "b", "c", "d", "e"))), timeout = 30000))
    Condition
      Error:
      ! 1 of 1 mirai daemon is running a different build of nestedtune.
      i The daemon could not find `a`, `b`, `c` and 2 more, which this session's copy defines and the outer loop calls by name on the worker.
      i Reinstall nestedtune into the daemons' library, then restart the pool with `mirai::daemons(0)` followed by `mirai::daemons(n)` -- a running daemon keeps the namespace it already loaded.
      i Alternatively call `mirai::daemons(0)` to run serially -- results are identical either way.
    Code
      check_daemons_can_load(preflight_outcome(reports(TRUE, TRUE, missing = list(
        NULL, "rehydrate_payload")), timeout = 30000))
    Condition
      Error:
      ! 1 of 2 mirai daemons is running a different build of nestedtune.
      i The daemon could not find `rehydrate_payload`, which this session's copy defines and the outer loop calls by name on the worker.
      i Reinstall nestedtune into the daemons' library, then restart the pool with `mirai::daemons(0)` followed by `mirai::daemons(n)` -- a running daemon keeps the namespace it already loaded.
      i Alternatively call `mirai::daemons(0)` to run serially -- results are identical either way.

