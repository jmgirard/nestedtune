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
# Seconds are read from the helper's own constants, never copied, so cutting a
# bound in helper-parallel.R moves the ledger with it and the two cannot drift.

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
    tb_row("test-parallel-classify.R", 38L, "collect_bounded",
           COLLECT_BOUNDED_DEFAULT_S,
           "a miraiError becomes a recorded worker failure, not an abort"),
    tb_row("test-parallel-classify.R", 155L, "check_daemons_can_load", 0,
           "dispatch refuses daemons that cannot load the package",
           note = "fabricated status; classifies, never dispatches"),
    tb_row("test-parallel-classify.R", 183L, "setTimeLimit", 0,
           "a connected daemon that cannot answer in time is bounded",
           note = "not a bound on a blocked mirai wait (M14)"),
    tb_row("test-parallel-classify.R", 184L, "setTimeLimit", 0,
           "a connected daemon that cannot answer in time is bounded",
           note = "restore"),
    tb_row("test-parallel-classify.R", 201L, "daemons_load_status", 1,
           "a connected daemon that cannot answer in time is bounded",
           note = "explicit timeout = 1000L"),
    tb_row("test-parallel-classify.R", 239L, "setTimeLimit", 0,
           "a pool with no daemon at all is a non-response, not a load failure",
           note = "not a bound on a blocked mirai wait (M14)"),
    tb_row("test-parallel-classify.R", 240L, "setTimeLimit", 0,
           "a pool with no daemon at all is a non-response, not a load failure",
           note = "restore"),
    tb_row("test-parallel-classify.R", 242L, "daemons_load_status", 2,
           "a pool with no daemon at all is a non-response, not a load failure",
           note = "explicit timeout = 2000L"),
    tb_row("test-parallel-classify.R", 247L, "check_daemons_can_load", 0,
           "a pool with no daemon at all is a non-response, not a load failure",
           note = "status already in hand"),
    tb_row("test-parallel-classify.R", 265L, "check_daemons_can_load", 0,
           "a pool where every daemon loaded passes", note = "fabricated status"),
    tb_row("test-parallel-classify.R", 277L, "check_daemons_can_load", 0,
           "one loadable daemon no longer passes the check for the whole pool",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 284L, "check_daemons_can_load", 0,
           "a load failure keeps the install and prime remedies",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 299L, "check_daemons_can_load", 0,
           "a timeout is not reported as a package that cannot be loaded",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 311L, "check_daemons_can_load", 0,
           "the timeout message points at the option that raises the bound",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 319L, "check_daemons_can_load", 0,
           "a raised bound is reported as a number, not in scientific notation",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 335L, "check_daemons_can_load", 0,
           "a pool failing both ways names both facts", note = "fabricated status"),
    tb_row("test-parallel-classify.R", 348L, "check_daemons_can_load", 0,
           "both causes answer to one shared class", note = "fabricated status"),
    tb_row("test-parallel-classify.R", 407L, "start_daemons",
           START_DAEMONS_BOUND_S(),
           "the probe reads its bound from the option, not from the constant"),
    tb_row("test-parallel-classify.R", 412L, "setTimeLimit", 0,
           "the probe reads its bound from the option, not from the constant",
           note = "not a bound on a blocked mirai wait (M14)"),
    tb_row("test-parallel-classify.R", 413L, "setTimeLimit", 0,
           "the probe reads its bound from the option, not from the constant",
           note = "restore"),
    tb_row("test-parallel-classify.R", 415L, "daemons_load_status", 45.678,
           "the probe reads its bound from the option, not from the constant",
           note = "the test sets the option to 45678 ms at :409"),
    tb_row("test-parallel-classify.R", 432L, "daemons_load_status", 0,
           "a bad bound is refused before any daemon is asked",
           note = "the option is invalid, so it aborts before dispatching"),
    tb_row("test-parallel-classify.R", 446L, "check_daemons_can_load", 0,
           "a probe that reached no daemon at all is not a pass",
           note = "fabricated status"),
    tb_row("test-parallel-classify.R", 456L, "check_daemons_can_load", 0,
           "the abort names the package actually probed", note = "fabricated status"),
    tb_row("test-parallel-classify.R", 489L, "start_daemons",
           START_DAEMONS_BOUND_S(),
           "dispatch accepts daemons primed with the package"),
    tb_row("test-parallel-classify.R", 496L, "daemons_load_status", 60,
           "dispatch accepts daemons primed with the package",
           note = "explicit timeout = 60000; was the option's 300 s before M16"),
    tb_row("test-parallel-classify.R", 497L, "check_daemons_can_load", 0,
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

    # --- test-parallel-interrupt.R ------------------------------------------
    tb_row("test-parallel-interrupt.R", 40L, "start_daemons",
           START_DAEMONS_BOUND_S(), "an interrupted run leaves no fold executing"),
    tb_row("test-parallel-interrupt.R", 91L, "deadline poll", 15,
           "an interrupted run leaves no fold executing",
           note = "while (executing() > 0L && Sys.time() < deadline)"),
    tb_row("test-parallel-interrupt.R", 108L, "start_daemons",
           START_DAEMONS_BOUND_S(),
           "a completed run is not disturbed by the unconditional cancel"),

    # --- helper-parallel.R --------------------------------------------------
    # The two waits inside start_daemons(), carried at 0 here because they are
    # already counted at every start_daemons() CALL SITE above -- charging them
    # again here would double-count. They get rows anyway so the guard sees them
    # classified rather than absent, which is the whole discipline: a wait is
    # either budgeted somewhere or it is a finding.
    tb_row("helper-parallel.R", 60L, "collect_bounded", 0,
           "prime_daemons()",
           note = "PRIME_DAEMONS_BOUND_S, counted at each start_daemons() site"),
    tb_row("helper-parallel.R", 80L, "collect_bounded", 0,
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
