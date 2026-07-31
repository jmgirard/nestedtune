# What the daemon tests are allowed to wait for, declared (M16 T2, AC2).
#
# The problem this exists to make visible. `test-parallel-classify.R` typically
# runs in 12.0 s (benchmarks/test-timing-baseline.md), but before M16 its
# declared waits permitted 1008.7 s. On 2026-07-27 a CI job sat in that file for
# ~17 minutes and was killed by the 20-minute cap, and the surviving log said
# only that it had started the file (PR #13, run 30303761053). A wedge and a
# file running its own worst case are indistinguishable from the outside -- so
# the worst case is written down here, and kept smaller than the cap.
#
# THE SUMMING CONVENTION, which is a decision and not an accident (M16 plan
# gate): each wait contributes ITS OWN declared seconds. An enclosing
# `setTimeLimit()` never caps that contribution, because M14 established by
# execution that `setTimeLimit()` does not interrupt a blocked mirai wait -- it
# is not a bound on the path that actually stalls, and crediting it would
# flatter every total here exactly where the flattery is unsafe. Those calls get
# rows carrying 0 seconds so the guard can see they were classified, never
# because they are free.
#
# A call that does no waiting also gets a 0-second row rather than no row:
# `check_daemons_can_load(status)` on a fabricated `preflight_outcome()`
# classifies an answer already in hand and dispatches nothing. Recording it is
# what makes `test-suite-hygiene.R`'s guard able to insist that EVERY wait-shaped
# call is accounted for -- a new one cannot land silently by looking like the
# many harmless ones.
#
# HOW A ROW'S SECONDS ARE KEPT HONEST, which is two different mechanisms and was
# once described here as one (M16 review F3, scored 85).
#
# Rows whose bound lives in helper-parallel.R read the constant itself --
# COLLECT_BOUNDED_DEFAULT_S, START_DAEMONS_BOUND_S(), MIXED_DAEMONS_BOUND_S --
# so cutting a bound there moves the ledger with it and those cannot drift.
#
# The rest carry a literal copied from an explicit argument at the call site
# (`daemons_load_status(timeout = 1000L)` and friends), and a copy can drift:
# raising the real argument while leaving the row alone would leave every guard
# green and the printed total unchanged. So `test-suite-hygiene.R` re-reads each
# such argument from the source and fails when the row disagrees.
#
# What that cross-check cannot reach is declared here rather than left implicit,
# because an unstated exemption is how the first version of this comment came to
# overclaim. Two kinds escape it: a bound set through the OPTION at one line and
# spent at another (classify:409 sets it, :415 spends it), and a wait that is no
# function call at all (the deadline poll in interrupt). Neither carries an
# explicit argument on its own line, which is exactly how the cross-check
# recognises them, and both are named here so the gap is on the record.

# One site's worst case: what it waits for, times the number of times the
# surrounding code runs it. `times` is 1 unless a loop says otherwise -- the
# start_daemons() call in test-parallel-identity.R:38 sits inside
# `for (n in c(2L, 3L))` and is therefore paid twice.
tb_row <- function(file, line, call, seconds, payer, times = 1L, note = "") {
  data.frame(
    file = file, line = line, call = call, seconds = seconds * times,
    times = times, payer = payer, note = note, stringsAsFactors = FALSE
  )
}

# start_daemons() waits twice over: once priming the daemons and once warming
# them. Neither is visible at the call site, which is what made 600 s of
# test-parallel-classify.R's old worst case invisible to a reader of that file.
START_DAEMONS_BOUND_S <- function() PRIME_DAEMONS_BOUND_S + WARM_DAEMONS_BOUND_S

# The suite-wide option (PREFLIGHT_TEST_TIMEOUT_MS) is charged to no file below,
# because after M16 every probe in these files passes an explicit `timeout` or
# sets the option itself. It remains as the backstop a future call would inherit
# -- which is precisely how the largest wait in test-parallel-classify.R came to
# be invisible, so a new call relying on it should be charged here.

time_budget_ledger <- function() {
  rbind(
    # --- test-parallel-classify.R -------------------------------------------
    tb_row("test-parallel-classify.R", 69L, "collect_bounded",
           COLLECT_BOUNDED_DEFAULT_S,
           "a miraiError becomes a recorded worker failure, not an abort"),
    tb_row("test-parallel-classify.R", 186L, "check_daemons_can_load", 0,
           "dispatch refuses daemons that cannot load the package",
           note = "fabricated status; classifies, never dispatches"),
    tb_row("test-parallel-classify.R", 214L, "setTimeLimit", 0,
           "a connected daemon that cannot answer in time is bounded",
           note = "not a bound on a blocked mirai wait (M14)"),
    tb_row("test-parallel-classify.R", 215L, "setTimeLimit", 0,
           "a connected daemon that cannot answer in time is bounded",
           note = "restore"),
    tb_row("test-parallel-classify.R", 232L, "daemons_load_status", 1,
           "a connected daemon that cannot answer in time is bounded",
           note = "explicit timeout = 1000L"),
    tb_row("test-parallel-classify.R", 270L, "setTimeLimit", 0,
           "a pool with no daemon at all is a non-response, not a load failure",
           note = "not a bound on a blocked mirai wait (M14)"),
    tb_row("test-parallel-classify.R", 271L, "setTimeLimit", 0,
           "a pool with no daemon at all is a non-response, not a load failure",
           note = "restore"),
    tb_row("test-parallel-classify.R", 273L, "daemons_load_status", 2,
           "a pool with no daemon at all is a non-response, not a load failure",
           note = "explicit timeout = 2000L"),
    tb_row("test-parallel-classify.R", 278L, "check_daemons_can_load", 0,
           "a pool with no daemon at all is a non-response, not a load failure",
           note = "status already in hand"),
    tb_row("test-parallel-classify.R", 296L, "check_daemons_can_load", 0,
           "a pool where every daemon loaded passes", note = "fabricated status"),
    tb_row("test-parallel-classify.R", 308L, "check_daemons_can_load", 0,
           "one loadable daemon no longer passes the check for the whole pool",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 315L, "check_daemons_can_load", 0,
           "a load failure keeps the install and prime remedies",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 330L, "check_daemons_can_load", 0,
           "a timeout is not reported as a package that cannot be loaded",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 342L, "check_daemons_can_load", 0,
           "the timeout message points at the option that raises the bound",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 350L, "check_daemons_can_load", 0,
           "a raised bound is reported as a number, not in scientific notation",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 366L, "check_daemons_can_load", 0,
           "a pool failing both ways names both facts", note = "fabricated status"),
    tb_row("test-parallel-classify.R", 379L, "check_daemons_can_load", 0,
           "both causes answer to one shared class", note = "fabricated status"),
    tb_row("test-parallel-classify.R", 464L, "check_daemons_can_load", 0,
           "the incompatible abort names the symbols, the count, and the restart",
           note = "fabricated status; classifies, never dispatches"),
    tb_row("test-parallel-classify.R", 486L, "check_daemons_can_load", 0,
           "the incompatible abort reads the same for one symbol or a hundred",
           note = "fabricated status; snapshot"),
    tb_row("test-parallel-classify.R", 490L, "check_daemons_can_load", 0,
           "the incompatible abort reads the same for one symbol or a hundred",
           note = "fabricated status; snapshot, truncated case"),
    tb_row("test-parallel-classify.R", 504L, "check_daemons_can_load", 0,
           "an incompatible pool answers to the shared unusable class",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 517L, "check_daemons_can_load", 0,
           "an incompatible pool still reports daemons that said nothing",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 576L, "start_daemons",
           START_DAEMONS_BOUND_S(),
           "the probe reads its bound from the option, not from the constant"),
    tb_row("test-parallel-classify.R", 581L, "setTimeLimit", 0,
           "the probe reads its bound from the option, not from the constant",
           note = "not a bound on a blocked mirai wait (M14)"),
    tb_row("test-parallel-classify.R", 582L, "setTimeLimit", 0,
           "the probe reads its bound from the option, not from the constant",
           note = "restore"),
    tb_row("test-parallel-classify.R", 584L, "daemons_load_status", 45.678,
           "the probe reads its bound from the option, not from the constant",
           note = "the test sets the option to 45678 ms at :409"),
    tb_row("test-parallel-classify.R", 601L, "daemons_load_status", 0,
           "a bad bound is refused before any daemon is asked",
           note = "the option is invalid, so it aborts before dispatching"),
    tb_row("test-parallel-classify.R", 615L, "check_daemons_can_load", 0,
           "a probe that reached no daemon at all is not a pass",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 625L, "check_daemons_can_load", 0,
           "the abort names the package actually probed", note = "fabricated status"),
    tb_row("test-parallel-classify.R", 695L, "start_daemons",
           START_DAEMONS_BOUND_S(),
           "dispatch accepts daemons primed with the package"),
    tb_row("test-parallel-classify.R", 702L, "daemons_load_status", 60,
           "dispatch accepts daemons primed with the package",
           note = "explicit timeout = 60000; was the option's 300 s before M16"),
    tb_row("test-parallel-classify.R", 703L, "check_daemons_can_load", 0,
           "dispatch accepts daemons primed with the package",
           note = "status already in hand"),

    # --- test-parallel-detection.R ------------------------------------------
    tb_row("test-parallel-detection.R", 70L, "setTimeLimit", 0,
           "a heterogeneous pool names the daemons that cannot load",
           note = "not a bound on a blocked mirai wait (M14)"),
    tb_row("test-parallel-detection.R", 71L, "setTimeLimit", 0,
           "a heterogeneous pool names the daemons that cannot load",
           note = "restore"),
    tb_row("test-parallel-detection.R", 74L, "start_mixed_daemons", 60,
           "a heterogeneous pool names the daemons that cannot load",
           note = "its own `timeout` default"),
    tb_row("test-parallel-detection.R", 82L, "collect_bounded", 30,
           "a heterogeneous pool names the daemons that cannot load"),
    tb_row("test-parallel-detection.R", 89L, "daemons_load_status", 30,
           "a heterogeneous pool names the daemons that cannot load",
           note = "explicit timeout = 30000"),
    tb_row("test-parallel-detection.R", 101L, "check_daemons_can_load", 0,
           "a heterogeneous pool names the daemons that cannot load",
           note = "status already in hand"),

    # --- test-parallel-identity.R -------------------------------------------
    # The heaviest file by declared worst case, and deliberately untouched here:
    # its eight-plus pool restarts are what a ROADMAP candidate proposes to
    # share, and doing that safely needs evidence a reused pool stays clean
    # between tests. M16 records the figure and sets no ceiling on it.
    tb_row("test-parallel-identity.R", 38L, "start_daemons",
           START_DAEMONS_BOUND_S(), "serial and parallel agree, any worker count",
           times = 2L, note = "inside for (n in c(2L, 3L))"),
    tb_row("test-parallel-identity.R", 72L, "start_daemons",
           START_DAEMONS_BOUND_S(), "the RNG kind pin survives dispatch"),
    tb_row("test-parallel-identity.R", 89L, "start_daemons",
           START_DAEMONS_BOUND_S(), "a third RNG kind still round-trips"),
    tb_row("test-parallel-identity.R", 114L, "start_daemons",
           START_DAEMONS_BOUND_S(), "fold order does not change the estimate"),
    tb_row("test-parallel-identity.R", 151L, "start_daemons",
           START_DAEMONS_BOUND_S(), "the caller's RNG state is left untouched"),
    tb_row("test-parallel-identity.R", 165L, "setTimeLimit", 0,
           "the caller's RNG state is left untouched",
           note = "not a bound on a blocked mirai wait (M14)"),
    tb_row("test-parallel-identity.R", 166L, "setTimeLimit", 0,
           "the caller's RNG state is left untouched", note = "restore"),
    tb_row("test-parallel-identity.R", 216L, "start_daemons",
           START_DAEMONS_BOUND_S(), "seeds are assigned per fold, not per worker"),
    tb_row("test-parallel-identity.R", 262L, "start_daemons",
           START_DAEMONS_BOUND_S(), "a failed fold does not disturb the others"),
    tb_row("test-parallel-identity.R", 273L, "start_daemons",
           START_DAEMONS_BOUND_S(), "notes survive the trip back from a worker"),
    tb_row("test-parallel-identity.R", 329L, "start_daemons",
           START_DAEMONS_BOUND_S(), "the parallel branch really ran"),

    # --- test-parallel-metrics.R --------------------------------------------
    # One pool start, and that is the whole file's declared waiting. The two
    # `mirai::daemons(0)` calls beside it (:50 teardown, :53 reset before the
    # serial reference) are not among BUDGETED_WAIT_CALLS and get no row: M16
    # measured `daemons(0)` returning in ~0.2 s with a live task outstanding --
    # it orphans rather than blocks -- so there is no bound to declare. They are
    # named here because the guard cannot see them, which is the same
    # disclosure the option/deadline-poll gap above makes.
    tb_row("test-parallel-metrics.R", 58L, "start_daemons",
           START_DAEMONS_BOUND_S(),
           "the metric set the caller gave reaches folds running on a worker"),
    tb_row("test-parallel-payload.R", 273L, "start_daemons",
           START_DAEMONS_BOUND_S(),
           "a daemon receives the payload rehydrated, not the leaned one"),

    # --- test-parallel-interrupt.R ------------------------------------------
    tb_row("test-parallel-interrupt.R", 41L, "start_daemons",
           START_DAEMONS_BOUND_S(), "an interrupted run leaves no fold executing"),
    tb_row("test-parallel-interrupt.R", 92L, "deadline poll", 15,
           "an interrupted run leaves no fold executing",
           note = "while (executing() > 0L && Sys.time() < deadline)"),
    tb_row("test-parallel-interrupt.R", 109L, "start_daemons",
           START_DAEMONS_BOUND_S(),
           "a completed run is not disturbed by the unconditional cancel"),

    # --- helper-parallel.R --------------------------------------------------
    # The two waits inside start_daemons(), carried at 0 here because they are
    # already counted at every start_daemons() CALL SITE above -- charging them
    # again here would double-count. They get rows anyway so the guard sees them
    # classified rather than absent, which is the whole discipline: a wait is
    # either budgeted somewhere or it is a finding.
    tb_row("helper-parallel.R", 61L, "collect_bounded", 0,
           "prime_daemons()",
           note = "PRIME_DAEMONS_BOUND_S, counted at each start_daemons() site"),
    tb_row("helper-parallel.R", 81L, "collect_bounded", 0,
           "warm_daemons()",
           note = "WARM_DAEMONS_BOUND_S, counted at each start_daemons() site")
  )
}

time_budget_totals <- function(ledger = time_budget_ledger()) {
  totals <- stats::aggregate(seconds ~ file, data = ledger, FUN = sum)
  totals[order(-totals$seconds), , drop = FALSE]
}

# The ceiling AC4 sets, on the one file the 2026-07-27 stall was localized to.
# The other three are recorded without one: detection is small, interrupt is
# two pool starts, and identity is the subject of its own candidate row.
CLASSIFY_BUDGET_CEILING_S <- 480

# What the same ledger totalled before M16 cut anything, so the reduction is a
# measured figure rather than a remembered one.
CLASSIFY_BUDGET_PRE_M16_S <- 1008.678

# The ceiling on the file M20 added, set at the file's one pool start plus a
# margin. M16 capped only the file its stall was localized to and recorded the
# other three without a ceiling; a new file is cheaper to hold to a bound from
# the start than to cut back later, and 30 s of headroom is one more bounded
# wait before the guard asks whether it belongs.
METRICS_BUDGET_CEILING_S <- 150
