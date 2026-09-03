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
# overclaim. Three kinds escape it: a bound read from a named constant, which
# cannot drift and needs no re-read; a bound set through the OPTION at one line
# and spent at another (classify:745 sets it, :751 spends it); and a wait that is
# no function call at all (the deadline poll in interrupt). None carries an
# explicit bound argument in the call itself, which is exactly how the
# cross-check recognises them.
#
# Those exemptions are now DECLARED and asserted, not merely described here.
# `test-suite-hygiene.R` keeps the list as DECLARED_UNCHECKABLE_BOUNDS and fails
# when the set of rows it could not re-read differs from it -- so a fourth
# exemption has to be argued for rather than acquired by writing a call the
# regex cannot parse. Prose alone was not enough: this paragraph said the gap was
# on the record while a row wrapped across two lines sat in it unnoticed (M24
# review F9).

# One site's worst case: what it waits for, times the number of times the
# surrounding code runs it. `times` is 1 unless a loop says otherwise -- the
# start_daemons() call in test-parallel-identity.R:38 sits inside
# `for (n in c(2L, 3L))` and is therefore paid twice.
tb_row <- function(file, line, call, seconds, payer, times = 1L, note = "") {
  data.frame(
    file = file,
    line = line,
    call = call,
    seconds = seconds * times,
    times = times,
    payer = payer,
    note = note,
    stringsAsFactors = FALSE
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
    tb_row(
      "test-parallel-classify.R",
      80L,
      "collect_bounded",
      COLLECT_BOUNDED_DEFAULT_S,
      "a miraiError becomes a recorded worker failure, not an abort"
    ),
    tb_row(
      "test-parallel-classify.R",
      209L,
      "check_daemons_can_load",
      0,
      "dispatch refuses daemons that cannot load the package",
      note = "fabricated status; classifies, never dispatches"
    ),
    tb_row(
      "test-parallel-classify.R",
      237L,
      "setTimeLimit",
      0,
      "a connected daemon that cannot answer in time is bounded",
      note = "not a bound on a blocked mirai wait (M14)"
    ),
    tb_row(
      "test-parallel-classify.R",
      238L,
      "setTimeLimit",
      0,
      "a connected daemon that cannot answer in time is bounded",
      note = "restore"
    ),
    tb_row(
      "test-parallel-classify.R",
      255L,
      "daemons_load_status",
      1,
      "a connected daemon that cannot answer in time is bounded",
      note = "explicit timeout = 1000L"
    ),
    tb_row(
      "test-parallel-classify.R",
      293L,
      "setTimeLimit",
      0,
      "a pool with no daemon at all is a non-response, not a load failure",
      note = "not a bound on a blocked mirai wait (M14)"
    ),
    tb_row(
      "test-parallel-classify.R",
      294L,
      "setTimeLimit",
      0,
      "a pool with no daemon at all is a non-response, not a load failure",
      note = "restore"
    ),
    tb_row(
      "test-parallel-classify.R",
      296L,
      "daemons_load_status",
      2,
      "a pool with no daemon at all is a non-response, not a load failure",
      note = "explicit timeout = 2000L"
    ),
    tb_row(
      "test-parallel-classify.R",
      301L,
      "check_daemons_can_load",
      0,
      "a pool with no daemon at all is a non-response, not a load failure",
      note = "status already in hand"
    ),
    tb_row(
      "test-parallel-classify.R",
      319L,
      "check_daemons_can_load",
      0,
      "a pool where every daemon loaded passes",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      331L,
      "check_daemons_can_load",
      0,
      "one loadable daemon no longer passes the check for the whole pool",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      338L,
      "check_daemons_can_load",
      0,
      "a load failure keeps the install and prime remedies",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      356L,
      "check_daemons_can_load",
      0,
      "a timeout is not reported as a package that cannot be loaded",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      368L,
      "check_daemons_can_load",
      0,
      "the timeout message points at the option that raises the bound",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      379L,
      "check_daemons_can_load",
      0,
      "a raised bound is reported as a number, not in scientific notation",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      398L,
      "check_daemons_can_load",
      0,
      "a pool failing both ways names both facts",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      424L,
      "check_daemons_can_load",
      0,
      "a pool that cannot load AND holds an old build names both fixes",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      438L,
      "check_daemons_can_load",
      0,
      "a pool that cannot load AND holds an old build names both fixes",
      note = "fabricated status; the bullet's absence"
    ),
    tb_row(
      "test-parallel-classify.R",
      453L,
      "check_daemons_can_load",
      0,
      "the both-fault bullet counts and pluralises on the affected daemons",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      468L,
      "check_daemons_can_load",
      0,
      "both causes answer to one shared class",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      605L,
      "check_daemons_can_load",
      0,
      "the incompatible abort names the symbols, the count, and the restart",
      note = "fabricated status; classifies, never dispatches"
    ),
    tb_row(
      "test-parallel-classify.R",
      635L,
      "check_daemons_can_load",
      0,
      "the incompatible abort renders at one, two, five, and a mixed pool",
      note = "fabricated status; snapshot, one symbol"
    ),
    tb_row(
      "test-parallel-classify.R",
      643L,
      "check_daemons_can_load",
      0,
      "the incompatible abort renders at one, two, five, and a mixed pool",
      note = "fabricated status; snapshot, two symbols"
    ),
    tb_row(
      "test-parallel-classify.R",
      652L,
      "check_daemons_can_load",
      0,
      "the incompatible abort renders at one, two, five, and a mixed pool",
      note = "fabricated status; snapshot, truncated case"
    ),
    tb_row(
      "test-parallel-classify.R",
      660L,
      "check_daemons_can_load",
      0,
      "the incompatible abort renders at one, two, five, and a mixed pool",
      note = "fabricated status; snapshot, mixed pool"
    ),
    tb_row(
      "test-parallel-classify.R",
      674L,
      "check_daemons_can_load",
      0,
      "an incompatible pool answers to the shared unusable class",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      688L,
      "check_daemons_can_load",
      0,
      "an incompatible pool still reports daemons that said nothing",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      751L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "the probe reads its bound from the option, not from the constant"
    ),
    tb_row(
      "test-parallel-classify.R",
      756L,
      "setTimeLimit",
      0,
      "the probe reads its bound from the option, not from the constant",
      note = "not a bound on a blocked mirai wait (M14)"
    ),
    tb_row(
      "test-parallel-classify.R",
      757L,
      "setTimeLimit",
      0,
      "the probe reads its bound from the option, not from the constant",
      note = "restore"
    ),
    tb_row(
      "test-parallel-classify.R",
      759L,
      "daemons_load_status",
      45.678,
      "the probe reads its bound from the option, not from the constant",
      note = "the test sets the option to 45678 ms at :745"
    ),
    tb_row(
      "test-parallel-classify.R",
      776L,
      "daemons_load_status",
      0,
      "a bad bound is refused before any daemon is asked",
      note = "the option is invalid, so it aborts before dispatching"
    ),
    tb_row(
      "test-parallel-classify.R",
      790L,
      "check_daemons_can_load",
      0,
      "a probe that reached no daemon at all is not a pass",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      800L,
      "check_daemons_can_load",
      0,
      "the abort names the package actually probed",
      note = "fabricated status"
    ),
    tb_row(
      "test-parallel-classify.R",
      885L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "dispatch accepts daemons primed with the package"
    ),
    tb_row(
      "test-parallel-classify.R",
      892L,
      "daemons_load_status",
      60,
      "dispatch accepts daemons primed with the package",
      note = "explicit timeout = 60000; was the option's 300 s before M16"
    ),
    tb_row(
      "test-parallel-classify.R",
      893L,
      "check_daemons_can_load",
      0,
      "dispatch accepts daemons primed with the package",
      note = "status already in hand"
    ),

    # --- test-parallel-detection.R ------------------------------------------
    tb_row(
      "test-parallel-detection.R",
      70L,
      "setTimeLimit",
      0,
      "a heterogeneous pool names the daemons that cannot load",
      note = "not a bound on a blocked mirai wait (M14)"
    ),
    tb_row(
      "test-parallel-detection.R",
      71L,
      "setTimeLimit",
      0,
      "a heterogeneous pool names the daemons that cannot load",
      note = "restore"
    ),
    tb_row(
      "test-parallel-detection.R",
      74L,
      "start_mixed_daemons",
      60,
      "a heterogeneous pool names the daemons that cannot load",
      note = "its own `timeout` default"
    ),
    tb_row(
      "test-parallel-detection.R",
      82L,
      "collect_bounded",
      30,
      "a heterogeneous pool names the daemons that cannot load"
    ),
    tb_row(
      "test-parallel-detection.R",
      275L,
      "start_daemons_undispatched",
      START_DAEMONS_BOUND_S(),
      "dispatch_folds warns once per call, whatever it is dispatching"
    ),
    tb_row(
      "test-parallel-detection.R",
      219L,
      "start_daemons_undispatched",
      START_DAEMONS_BOUND_S(),
      "a run on an uncancellable pool warns exactly once"
    ),
    tb_row(
      "test-parallel-detection.R",
      248L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "a dispatcher-backed run warns not at all"
    ),
    tb_row(
      "test-parallel-detection.R",
      130L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "a primed pool matches the host's namespace exactly"
    ),
    tb_row(
      "test-parallel-detection.R",
      132L,
      "daemons_load_status",
      30,
      "a primed pool matches the host's namespace exactly",
      note = "explicit timeout = 30000"
    ),
    tb_row(
      "test-parallel-detection.R",
      142L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "a symbol no build defines is reported by every daemon that loaded"
    ),
    tb_row(
      "test-parallel-detection.R",
      145L,
      "daemons_load_status",
      30,
      "a symbol no build defines is reported by every daemon that loaded",
      note = "explicit timeout = 30000"
    ),
    tb_row(
      "test-parallel-detection.R",
      160L,
      "check_daemons_can_load",
      0,
      "a symbol no build defines is reported by every daemon that loaded",
      note = "status already in hand"
    ),
    tb_row(
      "test-parallel-detection.R",
      89L,
      "daemons_load_status",
      30,
      "a heterogeneous pool names the daemons that cannot load",
      note = "explicit timeout = 30000"
    ),
    tb_row(
      "test-parallel-detection.R",
      101L,
      "check_daemons_can_load",
      0,
      "a heterogeneous pool names the daemons that cannot load",
      note = "status already in hand"
    ),
    # The one test that starts its pools with bare `mirai::daemons()` rather
    # than through a budgeted helper, because it compares the two POOL KINDS and
    # priming is orthogonal to the property under test -- routing it through
    # start_daemons() would buy nothing and charge this file two more prime and
    # warm bounds. `daemons` is not among BUDGETED_WAIT_CALLS, so the guard
    # cannot see the two pool starts below, nor the three `daemons(0)` calls
    # beside them (:180 on.exit teardown, :182 and :187 resets between kinds);
    # the starts are rowed here so the file's account is complete rather than
    # complete-looking, which is the same disclosure the test-parallel-metrics.R
    # block below makes for its own `daemons(0)` calls.
    #
    # 0 seconds, and measured rather than assumed (2026-07-31, mirai 2.7.2):
    # `daemons(2)` returned in 0.635 s, `daemons(2, dispatcher = FALSE)` in
    # 0.224 s, `daemons(0)` in 0.205 s, with `status()$connections` already
    # reading 2. None waits on a mirai result, so none has a bound to declare.
    tb_row(
      "test-parallel-detection.R",
      184L,
      "daemons",
      0,
      "the two pool kinds are distinguishable, and the count cannot do it",
      note = "bare mirai::daemons(2); returns without waiting, measured 0.635 s"
    ),
    tb_row(
      "test-parallel-detection.R",
      189L,
      "daemons",
      0,
      "the two pool kinds are distinguishable, and the count cannot do it",
      note = "bare mirai::daemons(2, dispatcher = FALSE), measured 0.224 s"
    ),

    # --- test-parallel-identity.R -------------------------------------------
    # The heaviest file by declared worst case, and deliberately untouched here:
    # its eight-plus pool restarts are what a ROADMAP candidate proposes to
    # share, and doing that safely needs evidence a reused pool stays clean
    # between tests. M16 records the figure and sets no ceiling on it.
    tb_row(
      "test-parallel-identity.R",
      38L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "serial and parallel agree, any worker count",
      times = 2L,
      note = "inside for (n in c(2L, 3L))"
    ),
    tb_row(
      "test-parallel-identity.R",
      72L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "the RNG kind pin survives dispatch"
    ),
    tb_row(
      "test-parallel-identity.R",
      89L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "a third RNG kind still round-trips"
    ),
    tb_row(
      "test-parallel-identity.R",
      116L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "fold order does not change the estimate"
    ),
    tb_row(
      "test-parallel-identity.R",
      153L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "the caller's RNG state is left untouched"
    ),
    tb_row(
      "test-parallel-identity.R",
      167L,
      "setTimeLimit",
      0,
      "the caller's RNG state is left untouched",
      note = "not a bound on a blocked mirai wait (M14)"
    ),
    tb_row(
      "test-parallel-identity.R",
      168L,
      "setTimeLimit",
      0,
      "the caller's RNG state is left untouched",
      note = "restore"
    ),
    tb_row(
      "test-parallel-identity.R",
      226L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "seeds are assigned per fold, not per worker"
    ),
    tb_row(
      "test-parallel-identity.R",
      272L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "a failed fold does not disturb the others"
    ),
    tb_row(
      "test-parallel-identity.R",
      283L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "notes survive the trip back from a worker"
    ),
    tb_row(
      "test-parallel-identity.R",
      346L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "the parallel branch really ran"
    ),
    tb_row(
      "test-parallel-identity.R",
      443L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "the identity holds with param_info supplied"
    ),
    tb_row(
      "test-parallel-identity.R",
      496L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "the identity holds with a two-class fixture at event_level second"
    ),
    tb_row(
      "test-parallel-identity.R",
      543L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "the identity holds with a censored fixture at a named eval_time"
    ),
    tb_row(
      "test-parallel-identity.R",
      597L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "the Bayesian path matches serial at two above-threshold daemon counts",
      times = 2L,
      note = "inside for (n in c(2L, 3L)) (M45)"
    ),
    tb_row(
      "test-parallel-identity.R",
      645L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "the control reaches every fold on the parallel path as on the serial one",
      note = "one pool of 2 (M48)"
    ),
    tb_row(
      "test-parallel-identity.R",
      702L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "both racing paths match serial at two above-threshold daemon counts",
      times = 4L,
      note = "inside for (n in c(2L, 3L)) for each of two racers (M50)"
    ),

    # --- test-parallel-metrics.R --------------------------------------------
    # One pool start, and that is the whole file's declared waiting. The two
    # `mirai::daemons(0)` calls beside it (:50 teardown, :53 reset before the
    # serial reference) are not among BUDGETED_WAIT_CALLS and get no row: M16
    # measured `daemons(0)` returning in ~0.2 s with a live task outstanding --
    # it orphans rather than blocks -- so there is no bound to declare. They are
    # named here because the guard cannot see them, which is the same
    # disclosure the option/deadline-poll gap above makes.
    tb_row(
      "test-parallel-metrics.R",
      58L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "the metric set the caller gave reaches folds running on a worker"
    ),
    tb_row(
      "test-parallel-payload.R",
      302L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "a daemon receives the payload rehydrated, not the leaned one"
    ),

    # --- test-parallel-required-pkgs.R --------------------------------------
    # One pool start and one bounded read, the read charged once even though the
    # test calls `attached()` twice: both calls are the same `collect_bounded()`
    # site, and the ledger rows sites rather than executions -- the same
    # convention every helper-side row above follows. The `mirai::daemons(0)`
    # teardown at :48 gets no row for the reason the metrics block states.
    tb_row(
      "test-parallel-required-pkgs.R",
      49L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "a recipe selector the caller left unqualified resolves on a daemon"
    ),
    tb_row(
      "test-parallel-required-pkgs.R",
      56L,
      "collect_bounded",
      30,
      "a recipe selector the caller left unqualified resolves on a daemon",
      note = "explicit seconds = 30; one site, called twice"
    ),
    tb_row(
      "test-parallel-required-pkgs.R",
      89L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "a racing run attaches finetune and the race's model package in every daemon"
    ),
    tb_row(
      "test-parallel-required-pkgs.R",
      92L,
      "collect_bounded",
      30,
      "a racing run attaches finetune and the race's model package in every daemon",
      note = "explicit seconds = 30; one site, called twice (M50)"
    ),

    # --- test-parallel-interrupt.R ------------------------------------------
    tb_row(
      "test-parallel-interrupt.R",
      52L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "an interrupted run leaves no fold executing"
    ),
    tb_row(
      "test-parallel-interrupt.R",
      98L,
      "deadline poll",
      15,
      "an interrupted run leaves no fold executing",
      note = "while (executing() > 0L && Sys.time() < deadline)"
    ),
    tb_row(
      "test-parallel-interrupt.R",
      133L,
      "start_daemons",
      START_DAEMONS_BOUND_S(),
      "a completed run is not disturbed by the unconditional cancel"
    ),

    # --- helper-parallel.R --------------------------------------------------
    # The two waits inside start_daemons(), carried at 0 here because they are
    # already counted at every start_daemons() CALL SITE above -- charging them
    # again here would double-count. They get rows anyway so the guard sees them
    # classified rather than absent, which is the whole discipline: a wait is
    # either budgeted somewhere or it is a finding.
    tb_row(
      "helper-parallel.R",
      61L,
      "collect_bounded",
      0,
      "prime_daemons()",
      note = "PRIME_DAEMONS_BOUND_S, counted at each start_daemons() site"
    ),
    tb_row(
      "helper-parallel.R",
      84L,
      "collect_bounded",
      0,
      "warm_daemons()",
      note = "WARM_DAEMONS_BOUND_S, counted at each start_daemons() site"
    )
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
