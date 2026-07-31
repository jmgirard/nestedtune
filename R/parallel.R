# Detecting and recording the outer-loop dispatch branch.
#
# nestedtune parallelizes over outer folds and never inside them: inner tuning
# runs with control_grid(allow_par = FALSE), because nested parallelism
# oversubscribes cores. Detection mirrors tune's own so that "parallel" means
# the same thing in both packages (D-018) -- mirai installed, and at least two
# connected daemons. Below that tune stays sequential, and so do we.

# Split out so the threshold can be tested without daemons, and so the
# installed-or-not branch can be mocked.
is_mirai_installed <- function() {
  rlang::is_installed("mirai")
}

mirai_workers <- function() {
  if (!is_mirai_installed()) {
    return(0L)
  }
  # status() reports the live daemon pool; connections is NULL before daemons()
  # has ever been called in the session.
  workers <- mirai::status()$connections
  if (length(workers) != 1L || is.na(workers)) {
    return(0L)
  }
  as.integer(workers)
}

use_parallel <- function(workers = mirai_workers()) {
  length(workers) == 1L && !is.na(workers) && workers >= 2L
}

# Whether the pool can be told to stop.
#
# Cancellation is a dispatcher feature: `mirai::daemons(n)` starts one by
# default, but `daemons(n, dispatcher = FALSE)` does not, and use_parallel()
# admits both because it asks only how many daemons are connected. On such a
# pool the unconditional stop_mirai() in dispatch_folds() returns FALSE per
# element and every outstanding fold runs to completion regardless (verified at
# M15 against mirai 2.7.2).
#
# `status()$mirai` is what separates them -- NULL without a dispatcher and a
# record with one -- while `status()$connections` reads the same either way, so
# the count use_parallel() consults cannot tell them apart (verified by
# execution, mirai 2.7.2). NULL is also what an absent mirai would give, hence
# the installed check first: never warn about a pool that is not there.
pool_is_cancellable <- function() {
  if (!is_mirai_installed()) {
    return(TRUE)
  }
  !is.null(mirai::status()$mirai)
}

# Which branch the last dispatch took.
#
# This is deliberately NOT stored on the results object. BC1 requires both that
# a parallel result be identical() to its serial counterpart and that a test be
# able to prove the parallel branch actually ran; an attribute on the result
# would satisfy the second by breaking the first. An internal record satisfies
# both, and keeps the public surface unchanged.
the <- new.env(parent = emptyenv())

record_dispatch <- function(branch) {
  the$last_dispatch <- branch
  invisible(branch)
}

last_dispatch <- function() {
  the$last_dispatch
}

reset_dispatch_record <- function() {
  the$last_dispatch <- NULL
  invisible(NULL)
}

# Take the data out of one fold's payload, and put it back on the worker.
#
# Every rsplit carries the whole frame it indexes. In memory those are one
# shared copy -- that is what nested_resamples() exists to achieve -- but R's
# serializer does not preserve sharing for ordinary objects, so each split wrote
# its own copy onto the wire: six of them for v = 5, inner_v = 5, measured
# 5,141,166 B against 840,540 B of data. `lobstr::obj_size()` reports 946.94 kB
# for that same payload and so cannot see the defect at all, which is why the
# guards in test-parallel-payload.R measure the serialized stream.
#
# `$data` is blanked with `x["data"] <- list(NULL)` rather than `x$data <- NULL`
# on purpose: assigning NULL to a list element DELETES it, and the rehydrated
# object would then carry `data` in last position instead of its own. The round
# trip has to be `identical()` to what the serial branch passes, not merely
# equivalent, or IP2's serial-vs-parallel comparison is testing two shapes.
#
# What each frame is compared against is `shared`, the one copy `.args` carries.
# A nested_resamples() design indexes a single frame throughout, so nothing is
# carried per fold. An rsample::nested_cv() design materializes each outer
# fold's analysis set, so that fold's inner frame is neither the original nor
# any other fold's and travels with the fold -- still once, rather than once per
# inner split. `identical()` decides which case a fold is in: it takes a pointer
# fast path when the frames are the same object (0.04 ms against 1.05 ms on a
# 32 MB frame), and an equal-but-distinct frame answering TRUE is sound here,
# since substituting one for the other is exactly what rehydration does.
# Whether this is a fold payload that can be leaned without changing a result.
#
# Read with `[[` and `names()`, never `$`: `$` partial-matches on a plain list,
# so `x$split` would answer a payload carrying `splits` and `x$inner` one
# carrying `inner_resamples`. is_fold_record() uses `%in% names(x)` for the same
# reason, and this is the discipline it claims parity with.
#
# The last clause is load-bearing rather than defensive. lean_payload() takes ONE
# frame for the fold's inner splits and rehydrate_payload() writes it back onto
# all of them, which is only sound if they shared it to begin with.
# `nested_resamples()` guarantees that and validates it at construction
# (R/nested-resamples.R:84), but check_nested() admits any object whose
# `inner_resamples` elements are `rset`s -- including a `manual_rset()` of splits
# over different frames. Such a design would otherwise be tuned on the wrong rows
# in parallel and the right ones serially: a silent IP2 breach, and an IP1
# exposure wherever the substituted frame holds outer assessment rows. Failing
# the predicate sends the run down the fat path, which is slower and correct.
is_fold_payload <- function(x) {
  if (!is.list(x) || !all(c("split", "inner") %in% names(x))) {
    return(FALSE)
  }
  split <- x[["split"]]
  inner <- x[["inner"]]
  if (!inherits(split, "rsplit") || !is.data.frame(split$data) ||
        !is.data.frame(inner) || !is.list(inner$splits) ||
        length(inner$splits) == 0L) {
    return(FALSE)
  }
  inner_data <- inner$splits[[1L]]$data
  if (!is.data.frame(inner_data)) {
    return(FALSE)
  }
  all(vapply(
    inner$splits,
    function(s) identical(s$data, inner_data),
    logical(1)
  ))
}

lean_payload <- function(payload, shared) {
  outer_data <- payload$split$data
  inner_data <- payload$inner$splits[[1L]]$data

  payload$split["data"] <- list(NULL)
  payload$inner$splits <- lapply(payload$inner$splits, function(split) {
    split["data"] <- list(NULL)
    split
  })

  if (!identical(outer_data, shared)) {
    payload$outer_data <- outer_data
  }
  if (!identical(inner_data, shared)) {
    payload$inner_data <- inner_data
  }
  payload
}

rehydrate_payload <- function(payload, shared) {
  outer_data <- payload$outer_data
  inner_data <- payload$inner_data
  if (is.null(outer_data)) {
    outer_data <- shared
  }
  if (is.null(inner_data)) {
    inner_data <- shared
  }

  payload$split$data <- outer_data
  payload$inner$splits <- lapply(payload$inner$splits, function(split) {
    split$data <- inner_data
    split
  })
  # Removes the fields rather than blanking them, so what comes back has the
  # shape the serial branch passes and nothing more.
  payload$outer_data <- NULL
  payload$inner_data <- NULL
  payload
}

# Run every fold, serially or across daemons.
#
# `payloads` is one self-contained list per fold -- split, inner rset, and the
# fold's two seeds. Mapping over per-fold payloads rather than passing the whole
# design as a shared argument means a worker receives only the fold it runs.
#
# The seeds are already drawn and assigned by position before this is called
# (D-011), so nothing here draws, and a fold's result cannot depend on where or
# when it runs. That is the whole reason the loop is safe to parallelize.
dispatch_folds <- function(payloads, object, grid, metrics,
                           call = rlang::caller_env()) {
  if (!use_parallel()) {
    record_dispatch("serial")
    return(lapply(payloads, fold_task, object = object, grid = grid, metrics = metrics))
  }

  check_daemons_can_load(call = call)
  warn_if_not_cancellable(call = call)

  record_dispatch("parallel")
  # The task is sent with its environment stripped to the global one. Left
  # attached, the nestedtune namespace travels with the closure and mirai warns
  # that the package "may not be available when loading" on every dispatch --
  # and where it truly is unavailable the environment silently degrades to the
  # global one anyway (RR03 Q5). Since the body resolves the namespace by name
  # regardless, carrying it buys nothing and costs a warning per fold.
  # One copy of the data for the whole run, and index vectors per fold. The
  # outer split's frame is the original under both constructors, so it is what
  # every fold is measured against; anything a fold does not share with it
  # travels in that fold's own payload (see lean_payload()).
  #
  # `.args` is charged per fold, not per run -- mirai::mirai_map() serializes it
  # once per task -- so this is one copy per fold rather than one per run, which
  # is still the difference between 25,714,635 B and 4,701,505 B on the fixture
  # in test-parallel-payload.R.
  #
  # Leaning is skipped entirely unless every payload IS a fold payload.
  # dispatch_folds() is also driven directly with stand-in payloads carrying
  # neither split nor inner rset -- deliberately, since what those exercise is
  # the dispatch mechanics and a real fold would cost a model fit apiece. The
  # shape is recognised positively, the same discipline is_fold_record() uses.
  # `length()` first because `all(logical(0))` is TRUE, which would send an
  # empty dispatch into `payloads[[1L]]` below and out through a subscript error
  # -- after the pre-flight had already paid its round trip.
  leaning <- length(payloads) > 0L &&
    all(vapply(payloads, is_fold_payload, logical(1)))

  if (leaning) {
    shared <- payloads[[1L]]$split$data
    payloads <- lapply(payloads, lean_payload, shared = shared)
    # Rehydration wraps `fold_task` rather than living inside it, so that
    # `fold_task` keeps the signature the interrupt and identity tests mock, and
    # so a mock receives the objects the real worker would rather than splits
    # with the data still missing -- a mock made to rehydrate itself would be
    # hand-rolling the path it exists to cover (M07).
    #
    # The worker is passed BY VALUE through `.args`, never looked up by name in
    # the wrapper. `local_mocked_bindings()` rebinds `fold_task` in this
    # process only, so a daemon-side `asNamespace()` lookup would resolve the
    # real function and silently bypass the mock -- which is what makes the
    # mocked-binding injection point work at all. Its environment is stripped
    # for the reason the task's is.
    # Moved from `.f` to `.args`, which is the same wire cost -- mirai
    # serializes both once per task -- and is what leaves `.f` free to be the
    # wrapper. A function's srcrefs travel with it, so under
    # `pkgload::load_all()` this closure measures 202,363 B against 524 B from
    # an installed library, where srcrefs are absent; that was equally true of
    # `.f` before this, and stripping them needs `utils::removeSource()`, a
    # dependency this milestone declined to add on its own authority.
    worker <- fold_task
    environment(worker) <- globalenv()
    task <- function(payload, object, grid, metrics, shared, worker) {
      ns <- asNamespace("nestedtune")
      worker(ns$rehydrate_payload(payload, shared), object, grid, metrics)
    }
    args <- list(object = object, grid = grid, metrics = metrics,
                 shared = shared, worker = worker)
  } else {
    task <- fold_task
    args <- list(object = object, grid = grid, metrics = metrics)
  }
  environment(task) <- globalenv()

  mapped <- mirai::mirai_map(.x = payloads, .f = task, .args = args)
  # Leaving this function without returning must not leave folds running.
  #
  # The collect below blocks, and interrupting it unwinds the host while saying
  # nothing to the daemons: the folds keep computing results nobody will read,
  # on the very pool the user reuses next (verified by execution against mirai
  # 2.7.2 -- the pool reported `executing = 2` after the interrupt).
  #
  # Unconditional rather than gated on a "did we finish" flag, so it covers
  # every way out between here and the return rather than the ones anticipated:
  # the interrupt above, an error raised by the collect itself, and an abort
  # from classification. The last two leave nothing outstanding -- collect_mirai()
  # returns only once every element has resolved -- and stop_mirai() on a map
  # that has fully resolved is a no-op that returns FALSE per element and
  # touches neither the collected values nor the pool (same probe). So there is
  # nothing for a flag to save and one less thing to reason about.
  #
  # What this cannot do is reach a pool started with `dispatcher = FALSE`:
  # cancellation is a dispatcher feature, and use_parallel() admits such a pool
  # because it asks only how many daemons are connected. Verified against mirai
  # 2.7.2 -- there stop_mirai() returns FALSE per element and the tasks run to
  # completion regardless, so this guard is inert and the roxygen says so rather
  # than promising a cancellation that cannot happen (M15 review F1).
  # `mirai::daemons(n)` starts a dispatcher by default, so the common pool is
  # covered.
  on.exit(mirai::stop_mirai(mapped), add = TRUE)
  # A plain blocking collect: results in place, failures as values. mirai's
  # `.stop` would abort the whole run on the first failing fold and discard the
  # completed ones -- exactly what M03 exists to prevent.
  collected <- mirai::collect_mirai(mapped)
  lapply(collected, classify_fold_result, call = call)
}

# One round-trip before any fold is dispatched, to fail on the setup error users
# will actually make.
#
# Daemons are separate R processes: they can load nestedtune only from an
# installed library, and `devtools::load_all()` does not reach them. Without this
# check that mistake surfaces as every fold failing with the same opaque note --
# a run that looks like a statistical catastrophe and is really a library path
# (RR03 rec 8). One round-trip buys an error that names the fix.
# Bounded, because a daemon that never connects would otherwise block here
# forever. mirai reports connections from the pool's configuration, so a daemon
# that died during startup -- one whose own library is broken, say -- is counted
# but will never answer. This is deliberately NOT the per-fold timeout RR03
# rejected: a model fit has no defensible time limit, but a round-trip that only
# calls requireNamespace() does, and bounding it converts an unbreakable hang
# into an error naming the cause (M07-D6).
#
# The bound is an option rather than an argument (D-020): it tunes
# infrastructure and never anything statistical, so no result depends on it and
# nested_tune_grid()'s signature stays what it was. Non-finite is refused along
# with non-positive and non-numeric (M10-D2) -- an `Inf` bound is not a bound,
# and would hand back the unbreakable hang this exists to convert into an error.
default_preflight_timeout_ms <- 30000L

preflight_timeout <- function(call = rlang::caller_env()) {
  value <- getOption("nestedtune.preflight_timeout", default_preflight_timeout_ms)
  usable <- is.numeric(value) && length(value) == 1L &&
    !is.na(value) && is.finite(value) && value > 0
  if (!usable) {
    cli::cli_abort(
      c(
        "{.code options(nestedtune.preflight_timeout)} must be a single
         positive, finite number of milliseconds.",
        x = if (is.numeric(value) && length(value) == 1L) {
          "It is {.val {value}}."
        } else {
          "It is {.obj_type_friendly {value}}."
        }
      ),
      class = "nestedtune_bad_preflight_timeout",
      call = call
    )
  }
  as.numeric(value)
}

# Ask every connected daemon, not whichever one is free.
#
# The M07 defect: a single mirai() task is taken by ONE daemon, so a pool that
# is heterogeneous -- a respawned daemon, differing library paths -- had one
# loadable daemon answer for all of them, and every fold that landed elsewhere
# came back as an opaque worker failure. everywhere() is the mechanism that
# reaches all of them: verified to return one element per connected daemon
# (distinct pids), and to queue behind a daemon that is busy rather than skip it.
#
# It carries no `.timeout` of its own, so the bound is a poll on unresolved()
# to a deadline followed by stop_mirai(), which resolves every outstanding
# element to errorValue 20 and leaves the pool usable (both verified by
# execution, M10 T1).
#
# Answers are then read one element at a time from `$data`, which yields
# `unresolvedValue` for anything still outstanding, rather than through the
# map's own `[` -- that collects, and collecting BLOCKS until every element
# resolves. Reading per element cannot block at all, so the bound holds even if
# stop_mirai() leaves something behind.
#
# That covers the read. The send is the other half, and it is a claim about
# mirai rather than about this code: everywhere() must return without waiting
# for a daemon to be free, or the bound below would never start counting.
# Verified by execution against mirai 2.7.2 / nanonext 1.10.1 -- on a pool whose
# every daemon was already occupied it returned in 0.001 s with the probe
# unresolved and queued (M15 T5). It is deliberately NOT claimed of mirai in
# general: a version whose send blocked on a saturated pool would hang here, and
# no R-side bound could break it, setTimeLimit() not reaching a blocked mirai
# call (M14).
# What the host expects a daemon's copy of the package to contain.
#
# `ls()` rather than `names()`: it drops the dotted internals a namespace
# carries for its own bookkeeping, which differ between an installed package and
# one under pkgload and would report every daemon as incompatible.
#
# The whole namespace rather than the two symbols dispatch_folds() actually
# resolves by name (`rehydrate_payload` at :232, `nested_fold_fit` at :585).
# A hand-maintained list of those two is the defect this check exists to
# catch -- M23 added the second and nothing made the pre-flight notice -- so the
# manifest is derived, never written down. It costs 2,627 B serialized for 106
# names against a per-fold payload already in the megabytes.
daemon_symbol_manifest <- function(package = "nestedtune") {
  ls(asNamespace(package))
}

daemons_load_status <- function(package = "nestedtune",
                                timeout = preflight_timeout(call = call),
                                symbols = daemon_symbol_manifest(package),
                                call = rlang::caller_env()) {
  # Forced before anything is dispatched. Left lazy, the bound is not read until
  # after everywhere() has already sent the probe, so a typo in the option costs
  # a full cold load on every daemon before the user is told the option is bad.
  force(timeout)

  # One round trip answers both questions. The symbol check is nested inside the
  # load branch because asNamespace() on a package that will not load raises,
  # and a raised probe comes back as a miraiError -- a length-1 CHARACTER vector,
  # which daemon_report() rejects, turning a clean "cannot load" into a silent
  # daemon and losing the actionable message.
  probe <- mirai::everywhere(
    if (requireNamespace(package, quietly = TRUE)) {
      list(loaded = TRUE, missing = setdiff(symbols, ls(asNamespace(package))))
    } else {
      list(loaded = FALSE, missing = character())
    },
    .args = list(package = package, symbols = symbols)
  )
  deadline <- Sys.time() + timeout / 1000
  while (mirai::unresolved(probe) && Sys.time() < deadline) {
    Sys.sleep(0.05)
  }
  if (mirai::unresolved(probe)) {
    mirai::stop_mirai(probe)
  }
  answers <- lapply(seq_along(probe), function(i) probe[[i]]$data)
  preflight_outcome(answers, timeout = timeout, package = package)
}

# One daemon's answer, validated positively.
#
# Same discipline as classify_fold_result(): recognise the expected shape and
# treat everything else as a non-answer, rather than trying to enumerate the
# ways mirai can hand back something that is not a report. A stopped probe
# yields errorValue 20; a daemon that died mid-probe yields something else
# again. Neither is a report that the package is missing, so neither may be
# reported as one.
#
# `is.list()` is what keeps mirai's failure shapes out, and it is load-bearing
# rather than incidental: a miraiError is a length-1 character vector carrying
# the task's message, so any validator admitting a bare string would read a
# daemon's error text as a capability report. `[[` and `%in% names(x)` rather
# than `$` for the reason given at the top of this file -- `$` partial-matches
# on a plain list, so `x$loaded` would answer a list carrying `loaded_at`.
#
# Returns NULL for a non-answer rather than NA, so the caller distinguishes
# "this daemon said nothing" from any value a daemon could legitimately report.
daemon_report <- function(x) {
  if (!is.list(x) || !all(c("loaded", "missing") %in% names(x))) {
    return(NULL)
  }
  loaded <- x[["loaded"]]
  missing <- x[["missing"]]
  if (!is.logical(loaded) || length(loaded) != 1L || is.na(loaded) ||
        !is.character(missing) || anyNA(missing)) {
    return(NULL)
  }
  list(loaded = loaded, missing = missing)
}

# The three-way outcome, kept separate from both the probing and the message so
# every branch is reachable in a test without a daemon pool.
#
# A pool can fail both ways at once, so the record carries counts rather than a
# bare verdict: the load failure takes the class, because installing is the
# actionable fix, and the message still names the non-answers (M10-D1).
preflight_outcome <- function(answers, timeout = NA_real_,
                              package = "nestedtune") {
  reports <- lapply(as.list(answers), daemon_report)
  answered <- !vapply(reports, is.null, logical(1))
  loaded <- vapply(
    reports, function(r) !is.null(r) && r[["loaded"]], logical(1)
  )
  absent <- lapply(reports[loaded], function(r) r[["missing"]])

  total <- length(reports)
  cannot_load <- sum(answered & !loaded)
  incompatible <- sum(lengths(absent) > 0L)
  no_answer <- sum(!answered)
  missing_symbols <- sort(unique(unlist(absent, use.names = FALSE)))

  # `incompatible` sits below `cannot_load` and above `no_response`, extending
  # rather than reordering M10-D1's ladder: the class goes to whichever failure
  # names the most actionable fix. Installing beats reinstalling, and both beat
  # "some daemon said nothing", which names no fix at all.
  outcome <- if (cannot_load > 0L) {
    "cannot_load"
  } else if (incompatible > 0L) {
    "incompatible"
  } else if (no_answer > 0L || total == 0L) {
    "no_response"
  } else {
    "ok"
  }
  list(
    outcome = outcome,
    total = total,
    cannot_load = cannot_load,
    incompatible = incompatible,
    missing_symbols = if (is.null(missing_symbols)) character() else missing_symbols,
    no_answer = no_answer,
    timeout = timeout,
    package = package
  )
}

# `status` is an argument so both failure branches are reachable in a test
# without breaking a library path. Doing that for real also stops the daemon
# loading *mirai*, which kills it at startup and hangs the very probe under test
# -- found the hard way when it hung `R CMD check` for 39 minutes. The
# heterogeneous pool AC1 asks for is built in test-parallel-detection.R, where
# the scratch library keeps mirai and drops only the probed package.
check_daemons_can_load <- function(status = daemons_load_status(call = call),
                                   call = rlang::caller_env()) {
  if (identical(status$outcome, "ok")) {
    return(invisible(TRUE))
  }

  n_total <- status$total
  n_cannot <- status$cannot_load
  n_incompatible <- status$incompatible
  n_silent <- status$no_answer
  package <- status$package
  # Spelled out rather than interpolated raw: cli renders a numeric through
  # as.character(), which gives "3e+05" for a 300000 ms bound -- scientific
  # notation in the very bullet telling the user to raise that number.
  timeout <- format(status$timeout, scientific = FALSE, trim = TRUE)

  if (identical(status$outcome, "cannot_load")) {
    bullets <- c(
      "{n_cannot} of {n_total} mirai daemon{?s} cannot load {.pkg {package}}.",
      i = "Daemons are separate R processes and load the package from an
           installed library; {.fn devtools::load_all} does not reach them.",
      i = "Install the package, or prime the daemons with
           {.code mirai::everywhere(pkgload::load_all('<path>'))}."
    )
    if (n_silent > 0L) {
      bullets <- c(bullets, i = "A further {n_silent} daemon{?s} did not answer
                                 within {timeout} ms.")
    }
    cli::cli_abort(
      c(bullets, i = "Alternatively call {.code mirai::daemons(0)} to run
                      serially -- results are identical either way."),
      class = c("nestedtune_daemons_cannot_load", "nestedtune_daemons_unusable"),
      call = call
    )
  }

  if (identical(status$outcome, "incompatible")) {
    # Deliberately not the install remedy above: the package IS installed on
    # these daemons, so "install it" reads as already done. What is wrong is
    # WHICH build they hold, and restarting the pool is the half users forget --
    # a daemon keeps the namespace it loaded for its whole life, so reinstalling
    # underneath a running pool changes nothing until the daemons are replaced.
    # Truncated by hand rather than with cli's `vec-trunc` style, which does not
    # survive being wrapped in `{.code }` -- verified by rendering. It matters at
    # the size that matters: a daemon holding a genuinely old build is missing
    # not one symbol but most of them, and an untruncated bullet would list all
    # 106 of them at the user.
    all_missing <- status$missing_symbols
    n_missing <- length(all_missing)
    # Joined with plain commas rather than cli's default "and" so the trailing
    # count below does not read as "`a`, `b`, and `c` and 3 more".
    #
    # BOTH separator styles, because cli uses a different one at length 2:
    # `vec-sep` joins all but the last pair, `vec-last` joins the final pair at
    # n > 2, and `vec-sep2` is what joins the ONLY pair at exactly n = 2. Setting
    # `vec-last` alone left the two-symbol message reading "`a` `b`" with no
    # separator at all -- and n = 2 is the headline case, the two names the
    # worker resolves through the daemon's namespace (M24 review F1).
    shown <- cli::cli_vec(
      all_missing[seq_len(min(3L, n_missing))],
      style = list("vec-last" = ", ", "vec-sep2" = ", ")
    )
    # Built here rather than as a conditional inside the template: cli does not
    # re-interpolate a string a template returns, so `{extra}` nested in one
    # reaches the user verbatim (verified by rendering).
    more <- if (n_missing > 3L) paste0(" and ", n_missing - 3L, " more") else ""
    bullets <- c(
      # `daemon{?s}` agrees with {n_total}, the interpolation before it, but the
      # verb belongs to the affected daemons -- and cli takes every plural's
      # quantity from the LAST interpolation, so an unqualified `{?is/are}` read
      # n_total too and every mixed pool said "1 of 2 mirai daemons ARE running"
      # (M24 review F2). qty() sets the quantity without printing it.
      "{n_incompatible} of {n_total} mirai daemon{?s}
       {cli::qty(n_incompatible)}{?is/are} running a
       different build of {.pkg {package}}.",
      i = "{cli::qty(n_incompatible)}The daemon{?s} could not find
           {.code {shown}}{more}, which this session's copy defines and the
           outer loop calls by name on the worker.",
      i = "Reinstall {.pkg {package}} into the daemons' library, then restart
           the pool with {.code mirai::daemons(0)} followed by
           {.code mirai::daemons(n)} -- a running daemon keeps the namespace it
           already loaded."
    )
    if (n_silent > 0L) {
      bullets <- c(bullets, i = "A further {n_silent} daemon{?s} did not answer
                                 within {timeout} ms.")
    }
    cli::cli_abort(
      c(bullets, i = "Alternatively call {.code mirai::daemons(0)} to run
                      serially -- results are identical either way."),
      class = c("nestedtune_daemons_incompatible", "nestedtune_daemons_unusable"),
      call = call
    )
  }

  # No daemon reported the package missing -- they did not reply at all, so the
  # remedies above would tell a user to install what they already have.
  bullets <- "The mirai daemons did not answer the startup check within
              {timeout} ms."
  if (n_total > 0L) {
    bullets <- c(bullets, i = "{n_silent} of {n_total} daemon{?s} did not reply.")
  }
  cli::cli_abort(
    c(
      bullets,
      i = "A daemon that died during startup is still counted as a connection
           and never replies.",
      i = "If the daemons are merely slow -- a loaded machine, a scanned
           library -- raise the bound with
           {.code options(nestedtune.preflight_timeout = <ms>)}.",
      i = "Alternatively call {.code mirai::daemons(0)} to run serially --
           results are identical either way."
    ),
    class = c("nestedtune_daemons_no_response", "nestedtune_daemons_unusable"),
    call = call
  )
}

# Say once that this pool cannot be stopped.
#
# A warning rather than a refusal, and the line is GP3's: a dispatcher-less pool
# computes correct results, so what is unavailable is cancellation and not
# correctness. GP3 asks that provably invalid designs be refused, and this pool
# is degraded rather than invalid -- refusing it would reject a configuration
# that produces the right answer.
#
# Emitted here rather than in nested_tune_grid() because this is where the fact
# becomes true: dispatch_folds() is called once per run (R/nested-tune-grid.R),
# so one warning site is one warning per call, and the serial branch returns
# above without reaching it. Before M24 only the roxygen said any of this, which
# a user meets only if they go looking after the run they wanted to interrupt.
#
# `cancellable` is an argument so the branch is reachable without a real pool,
# the same seam check_daemons_can_load() opens with `status`.
warn_if_not_cancellable <- function(cancellable = pool_is_cancellable(),
                                    call = rlang::caller_env()) {
  if (isTRUE(cancellable)) {
    return(invisible(FALSE))
  }
  cli::cli_warn(
    c(
      "These mirai daemons were started without a dispatcher, so this run
       cannot be cancelled.",
      i = "Interrupting it returns control to you, but the outer folds keep
           computing on the pool and their results are never read.",
      i = "For a pool that stops when you do, restart it with
           {.code mirai::daemons(n)}, which starts a dispatcher by default."
    ),
    class = "nestedtune_pool_not_cancellable",
    call = call
  )
  invisible(TRUE)
}

# What a worker handed back, turned into a fold record.
#
# Classification is positive: a fold record is recognised by its shape, and
# everything else is a worker failure. The two shapes mirai can return instead
# defeat the obvious test -- neither `miraiError` nor the bare `errorValue` from
# a daemon that died inherits "condition", and `conditionMessage()` raises on
# the latter rather than describing it (RR03 Q4, verified). Asking "is this an
# error?" therefore mistakes both for successes; asking "is this a fold record?"
# cannot.
classify_fold_result <- function(x, call = rlang::caller_env()) {
  if (is_fold_record(x)) {
    return(x)
  }
  if (inherits(x, "miraiInterrupt")) {
    # Not a fold failure: the user stopped the run. Recording it as one would
    # report a cancelled run as a design that executed and partly failed (IP4).
    cli::cli_abort(
      c(
        "Run interrupted while waiting on outer folds.",
        i = "No results are returned; the caller's RNG state is restored."
      ),
      class = "nestedtune_interrupted",
      call = call
    )
  }
  if (is_cancelled_value(x)) {
    # Same inversion as the interrupt above, reached by a different route and
    # carrying none of its classes -- which is why M07 shipped with this path
    # open. The subclass keeps a handler for the general case working.
    cli::cli_abort(
      c(
        "Run cancelled while waiting on outer folds.",
        i = "The tasks were stopped before every outer fold had run, so the
             folds that did finish do not describe the requested design.",
        i = "No results are returned; the caller's RNG state is restored."
      ),
      class = c("nestedtune_cancelled", "nestedtune_interrupted"),
      call = call
    )
  }
  failed_fold("worker", NULL, NULL, message = worker_failure_message(x))
}

# nanonext's ECANCELED, which is what `mirai::stop_mirai()` leaves behind.
#
# Allowlisted to this one value on M09-D1's probe: 20 appears only under
# cancellation -- in flight and still queued alike, and for every task in a
# stopped `mirai_map()`, not just the one running. Deliberately NOT extended to
# 19 (ECONNRESET), which the same probe found under a `daemons(0)` teardown AND
# a daemon dying mid-fold, with identical classes and nothing to separate them;
# aborting on it would discard every completed fold whenever one worker died,
# which is what M03 exists to prevent. Anything unrecognised keeps the
# failed_fold() default for the same reason.
cancel_error_value <- 20L

is_cancelled_value <- function(x) {
  # Positive validation of the shape, per the same reasoning is_fold_record()
  # rests on: a real interrupt is an empty *string* carrying `errorValue`, and
  # a miraiError is the task's message, so `is.integer()` is what keeps both
  # out of this branch rather than an ordering accident.
  inherits(x, "errorValue") &&
    is.integer(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    x == cancel_error_value
}

is_fold_record <- function(x) {
  is.list(x) &&
    is.logical(x$completed) &&
    length(x$completed) == 1L &&
    all(c("metrics", "selected", "grid", "notes") %in% names(x))
}

worker_failure_message <- function(x) {
  # Dispatched on class rather than through mirai's predicates, so classification
  # needs nothing loaded. Order matters: a miraiError is also an errorValue.
  if (inherits(x, "miraiError")) {
    # A miraiError does carry the task's own error message.
    return(conditionMessage(x))
  }
  if (inherits(x, "errorValue")) {
    # A bare errorValue is an integer code. nanonext names it ("19 | Connection
    # reset"); it always ships with mirai, but it is not a declared dependency
    # of this package, so it is reached only if present and the code stands
    # alone otherwise.
    named <- tryCatch(
      getExportedValue("nanonext", "nng_error")(as.integer(x)),
      error = function(cnd) NULL
    )
    return(paste0(
      "The worker failed with mirai error value ", as.integer(x),
      if (!is.null(named)) paste0(" (", named, ")") else ""
    ))
  }
  "The worker returned something that is not a fold record."
}

# One fold, as it runs on a worker.
#
# The namespace is resolved by name rather than captured: a closure carrying the
# nestedtune namespace as its environment loses that environment when a daemon
# cannot reconstruct it, silently falling back to the global environment where
# none of the package's internals resolve (RR03 Q5). Looking the namespace up
# here either works or fails loudly, and the pre-flight check makes it the
# latter before any fold is dispatched.
fold_task <- function(payload, object, grid, metrics) {
  ns <- asNamespace("nestedtune")
  ns$nested_fold_fit(
    split = payload$split,
    inner = payload$inner,
    seeds = payload$seeds,
    object = object,
    grid = grid,
    metrics = metrics
  )
}
