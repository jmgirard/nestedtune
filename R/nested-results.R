# The results object.
#
# Deliberately NOT a `tune_results`. Inheriting it would bring show_best() and
# select_best() along, and both would happily rank outer folds -- output that
# looks authoritative and means nothing, since there is nothing to select at
# the outer level. Refusing the class makes them error instead (D-010).

new_nested_results <- function(resamples, folds, seeds, grid, metrics) {
  n <- length(folds)
  id_cols <- setdiff(names(resamples), c("splits", "inner_resamples"))

  cols <- list(splits = resamples$splits)
  for (nm in id_cols) {
    cols[[nm]] <- resamples[[nm]]
  }
  completed <- vapply(folds, function(x) x$completed, logical(1))

  cols[[".metrics"]] <- lapply(folds, function(x) x$metrics)
  cols[[".selected"]] <- lapply(folds, function(x) x$selected)
  # IP4's "the grid actually evaluated", per fold rather than per run: folds can
  # genuinely search different candidate sets, so this is a column and not an
  # attribute. An attribute would also survive a row subset as the parent's
  # record (M20), which is the stale claim the same principle forbids.
  cols[[".grid"]] <- lapply(folds, function(x) x$grid)
  cols[[".notes"]] <- lapply(folds, function(x) x$notes)
  cols[[".completed"]] <- completed
  cols[[".tuning_seed"]] <- seeds[seq(1L, by = 2L, length.out = n)]
  cols[[".outer_fit_seed"]] <- seeds[seq(2L, by = 2L, length.out = n)]

  out <- new_tbl(cols)
  attr(out, "grid") <- grid
  attr(out, "metrics") <- metrics
  attr(out, "outer_label") <- outer_scheme_label(resamples)
  # Which columns the design named its folds with, recorded rather than
  # recognized later. See id_columns().
  attr(out, "id_columns") <- id_cols
  # IP4: what ran is recorded positively, never inferred from what is absent.
  attr(out, "folds_attempted") <- n
  attr(out, "folds_completed") <- sum(completed)
  class(out) <- c("nested_results", class(out))
  out
}

# How the outer resampling scheme describes itself, for printing.
#
# rsample answers this through pretty(), but a nested design dispatches to a
# method describing both levels at once. Stripping the nested classes leaves the
# outer rset, which describes only itself. A design built somewhere else may
# carry no pretty() method at all, and then the run simply has no scheme to
# name -- printing drops the line rather than inventing one.
outer_scheme_label <- function(resamples) {
  outer <- resamples
  class(outer) <- setdiff(class(outer), c("nested_resamples", "nested_cv"))
  label <- tryCatch(pretty(outer), error = function(cnd) NULL)
  if (!is.character(label) || length(label) != 1L) {
    return(NULL)
  }
  label
}

# The invariants, and the one rule every operation on the class goes through.
#
# These are tune's, declared on `tune_results` (tune#221) and asked for here in
# #32: rows may be reordered but never added or removed, and columns may be
# added or reordered. An operation inside that set gets the class back; anything
# else gets a bare tibble, because an object holding rows other than the ones
# the run produced cannot answer for the run and must stop claiming it can
# (IP4). The alternative -- what this class did until M36 -- is what makes
# `slice(x, 1)` return a one-row object still headed "3-fold cross-validation".
#
# Only `dplyr_reconstruct()` is registered. dplyr's default `dplyr_row_slice()`
# and `dplyr_col_modify()` both finish by calling it, and so does `bind_rows()`,
# so one method covers the verbs; `[` is the one door that does not lead here on
# its own, and is routed here explicitly below.

# Which of an object's columns are the design's own fold labels.
#
# Read off the record the constructor wrote, never derived from the names in
# hand. It is the only place the answer is given -- record_columns(),
# has_results_columns(), can_reconstruct_results() and fold_ids() all ask here,
# so the class cannot hold two ideas of what a label column is.
#
# Until M38 this matched a name pattern, and every review round bought one more
# spelling. A bare `^id` prefix caught `ideal` and `id_extra`, names a caller
# joins in to label folds with; anchoring it to `^id[0-9]*$` left `id2`, which
# rsample gives a repeated design and a caller may add to a plain one. No
# pattern separates those two, because they are spelled identically and only the
# design knows which it is -- so the design is asked once, at construction, and
# the answer is carried with the run's description.
#
# An object carrying no such record gets the empty answer, and the rule then
# refuses rather than guessing: the conservative direction M36 review O6 already
# chose for a label column it could not recognize.
id_columns <- function(x) {
  nms <- attr(x, "id_columns")
  if (is.null(nms)) character(0) else nms
}

# The run's record: every column new_nested_results() writes. Read off the
# TEMPLATE only -- see can_reconstruct_results(). Takes the object rather than
# its names, because half the answer is the object's recorded label columns and
# not anything its names can be asked.
record_columns <- function(x) {
  fixed <- c(
    "splits",
    ".metrics",
    ".selected",
    ".grid",
    ".notes",
    ".completed",
    ".tuning_seed",
    ".outer_fit_seed"
  )
  nms <- names(x)
  nms %in% fixed | nms %in% id_columns(x)
}

# Whether `data` may wear `template`'s class: every column of the template's
# record still present, holding the same values, over the same number of rows.
# Row ORDER is exempt -- the folds are a set, and arrange() rearranging them
# changes nothing the object claims -- so both sides are put in id order before
# their values are compared.
#
# The record compared is the TEMPLATE's, and a column `data` carries beyond it
# is simply not looked at. Comparing the two sets for equality instead would
# read a caller-added column as a record that no longer matches, which is what
# "columns may be added" forbids (M36 review F2).
can_reconstruct_results <- function(data, template) {
  # The label columns come from the TEMPLATE's record, so what `data` is asked
  # for is what the run named -- `data` is a bare frame for half the verbs and
  # carries no record of its own to be asked about.
  id_cols <- id_columns(template)
  if (!is.data.frame(data) || !has_results_columns(data, id_cols)) {
    return(FALSE)
  }
  cols <- sort(names(template)[record_columns(template)])
  if (!all(cols %in% names(data))) {
    return(FALSE)
  }
  if (!identical(nrow(data), nrow(template))) {
    return(FALSE)
  }
  # Without an id column there is no ordering to compare under: the
  # permutation is empty, every compared column comes out zero-length, and any
  # two objects are identical(). Refusing is the honest answer -- the record
  # cannot be checked, so it cannot be vouched for (M36 review O5). A template
  # that records a label column it no longer carries is the same case.
  if (length(id_cols) == 0L || !all(id_cols %in% names(template))) {
    return(FALSE)
  }
  # `order()` takes atomic vectors and dies on anything else, with a message
  # naming a C routine rather than anything the caller did:
  # `mutate(x, id = list(c(1, 2), 3, 4))` aborted with "unimplemented type
  # 'list' in 'orderVector1'" (measured 2026-08-31). A label column replaced by
  # something unorderable is a record that no longer matches, which the rule has
  # an answer for -- it just has to reach it rather than die on the way (M38).
  orderable <- function(x) {
    all(vapply(id_cols, function(nm) is.atomic(x[[nm]]), logical(1)))
  }
  if (!orderable(data) || !orderable(template)) {
    return(FALSE)
  }
  in_id_order <- function(x) {
    ord <- do.call(order, lapply(id_cols, function(nm) x[[nm]]))
    lapply(cols, function(nm) x[[nm]][ord])
  }
  identical(in_id_order(data), in_id_order(template))
}

# The rule. `template` supplies what describes the call; the rows in hand supply
# what describes themselves.
reconstruct_results <- function(data, template) {
  if (!can_reconstruct_results(data, template)) {
    return(bare_results(data))
  }
  # Promoted before the class goes on, for the reason as_results_tbl() gives:
  # the class is documented as a tibble subclass, and dplyr hands this function
  # a bare data frame often enough that only the bare branch promoting would
  # make it one for some verbs and not others (M36 review F1).
  out <- as_results_tbl(data)
  if (!inherits(out, "nested_results")) {
    class(out) <- c("nested_results", class(out))
  }
  stamp_results(out, template)
}

# What describes the call comes from the template; what describes the rows is
# read off the rows. Split out of reconstruct_results() so vec_restore()'s
# prototype branch writes the same record rather than a second version of it.
stamp_results <- function(out, template) {
  # `metrics` is absent rather than NULL when none was supplied, and assigning
  # NULL to an attribute removes it, so this preserves the distinction.
  attr(out, "grid") <- attr(template, "grid")
  attr(out, "metrics") <- attr(template, "metrics")
  attr(out, "outer_label") <- attr(template, "outer_label")
  # Which columns the design named its folds with travels the same way, and for
  # the same reason: it describes the call, not the rows in hand (M38).
  attr(out, "id_columns") <- attr(template, "id_columns")
  # Read off the rows rather than copied from the template. Under the invariants
  # the two agree, so this corrects nothing today; it is the object's own record
  # of what ran, and IP4 asks that it be true of the object holding it however
  # the object was reached.
  attr(out, "folds_attempted") <- nrow(out)
  attr(out, "folds_completed") <- sum(out$.completed)
  # The private carriers are a prototype's, not a caller's: an object with rows
  # records what it holds in the two counts above, and its own names say which
  # columns the record is in.
  for (nm in template_attributes()) {
    attr(out, nm) <- NULL
  }
  out
}

# Shedding the class also sheds the run's record. Leaving `outer_label` on a
# bare tibble would leave the stale claim readable by anyone who looks for it,
# which is the same fault one layer down.
#
# The class is removed by subtraction rather than replaced with tibble's three,
# which leaves whatever else the object was carrying alone.
bare_results <- function(data) {
  for (nm in c(results_attributes(), template_attributes())) {
    attr(data, nm) <- NULL
  }
  class(data) <- setdiff(class(data), "nested_results")
  as_results_tbl(data)
}

# What both branches return is a tibble. `nested_results` is a tibble subclass
# (DESIGN: "a plain tibble carrying class `nested_results`"), and dplyr hands
# `dplyr_reconstruct()` a bare data frame for a good half of the verbs --
# `filter()`, `mutate()`, `arrange()`, `bind_cols()`, `left_join()`, `slice()`
# and `bind_rows()` all do, measured 2026-08-31 -- so leaving the classes off
# would make the result a tibble after `select()` and not after `mutate()`,
# and drop `x[, "id"]` to a bare vector for the second. Neither branch is a
# downgrade the caller asked for.
as_results_tbl <- function(data) {
  if (!inherits(data, "tbl_df")) {
    class(data) <- c("tbl_df", "tbl", class(data))
  }
  data
}

results_attributes <- function() {
  c(run_attributes(), "folds_attempted", "folds_completed")
}

# The part of the record that describes the run rather than the rows in hand.
# These stay true of anything the run produced, a type token included; the two
# counts do not, which is why they are separated here.
run_attributes <- function() {
  c("grid", "metrics", "outer_label", "id_columns")
}

#' @importFrom dplyr dplyr_reconstruct
#' @export
dplyr_reconstruct.nested_results <- function(data, template) {
  reconstruct_results(data, template)
}

# `[` reaches tibble's method, which carries every attribute through every
# subset shape and would hand back a classed object for any of them. Routing its
# result through the same rule is what makes the invariants a property of the
# class rather than of whichever `[` NextMethod() happened to reach.
#' @export
`[.nested_results` <- function(x, i, j, ...) {
  out <- NextMethod()
  if (!is.data.frame(out)) {
    return(out)
  }
  reconstruct_results(out, x)
}

# The vctrs door, and the two doors that are neither.
#
# `vec_slice()`, `vec_rbind()`, `vec_c()`, `vec_cbind()`, `vec_ptype()` and
# `vec_cast()` all finish at `vec_restore()` and never reach
# `dplyr_reconstruct()`, so one method there covers them the way one
# `dplyr_reconstruct()` method covers the verbs (measured 2026-08-31, on a
# tibble subclass carrying each method set in turn). `rbind()` and dplyr's
# `rename()` reach neither generic and are routed explicitly below.

# What `vec_restore()` is handed as `template` is not always the object the
# operation started from. `vec_slice()` passes the original, so the rule can
# compare the record column by column. Combining and column-binding pass a
# PROTOTYPE instead -- zero rows, and for `vec_cbind()` zero columns -- and the
# rule cannot compare a record against a template that holds none.
#
# The two cases are separated rather than run through one weakened check. Where
# the template carries the record, the full rule decides, and a combination is
# refused because six rows cannot match a three-row template. Where it does
# not, all that survives is what the prototype's attributes say the source was,
# which is the weakest place in the class.
#' @importFrom vctrs vec_restore
#' @export
vec_restore.nested_results <- function(x, to, ...) {
  if (has_results_columns(to)) {
    return(reconstruct_results(x, to))
  }
  # The empty container `vec_cbind()` assembles into, on its way past
  # `vec_cbind_frame_ptype()`. Nothing about a run can be checked here, because
  # what carries the class through has no columns to check: `x[0]` drops every
  # column and keeps the rows. The result assembled into it comes back through
  # this same function with its columns, below, and is checked there.
  #
  # The container is not private. `vctrs::vec_cbind_frame_ptype(x)` is exported,
  # and calling it directly hands back a columnless object wearing the class and
  # the run's description, which `print()` reports as a run it does not hold
  # before erroring on the missing columns (measured 2026-08-31). vctrs
  # documents that generic as experimental and keyword-internal, which is the
  # ground the RB04 review judged the exposure negligible on; no verb reaches
  # it. Recorded in the milestone's review as R2.
  if (length(x) == 0L && nrow(x) == 0L && length(to) == 0L) {
    return(copy_results_attributes(as_results_tbl(x), to))
  }
  # The rows in hand must carry a whole record of their own, under the names the
  # source kept it in, and must number what the source had. `vec_cbind()` cannot
  # alter an existing column, only add, recycle and REPAIR NAMES, so what it can
  # do wrong is exactly what these two catch: recycling a one-fold object up to
  # three rows, and renaming a record column out from under the record.
  attempted <- template_rows(to)
  required <- template_record(to)
  if (
    !has_results_columns(x, id_columns(to)) ||
      !is.numeric(attempted) ||
      !is.character(required) ||
      !all(required %in% names(x)) ||
      !identical(nrow(x), as.integer(attempted))
  ) {
    return(bare_results(x))
  }
  stamp_results(as_results_tbl(x), to)
}

# The common type of a `nested_results` with a table carries BOTH sides'
# columns. The union is what makes a combination with a table whose columns
# differ answer at all: vctrs casts every input to the common type and then
# assigns the columns positionally, so a common type omitting the other side's
# columns leaves the cast returning fewer columns than the container has and
# vctrs raising its own internal error (`dplyr::bind_rows(x,
# tibble::tibble(other = 1))`, measured 2026-08-31).
#
# It wears the `nested_results` class only where the results object is the
# FIRST argument. The class is what makes `vec_cbind()` reach `vec_restore()`
# at all -- a bare prototype takes the class off before the rule is ever asked
# -- so this is what decides whether a column add keeps the class, and
# `dplyr::bind_cols()` keeps it on the first argument's type and no other
# (measured 2026-08-31, both orders). A caller cannot see which door a verb
# uses, so the doors answer alike; the cost is that these ten methods are not
# mirror images of each other, which vctrs asks a `vec_ptype2()` lattice to be.
# Nothing here reaches the asymmetry: `vec_rbind()` and `vec_c()` finalize a
# `nested_results` to a bare tibble before any of them is dispatched on
# (measured 2026-08-31), leaving `vec_cbind()`, which combines in argument
# order. The class is kept or shed in one place, which is `vec_restore()`
# above.
#
# That is the lattice vctrs uses inside an operation, not the answer a caller
# gets. Exported `vctrs::vec_ptype()` and `vctrs::vec_ptype2()` on a
# `nested_results` both hand back a bare tibble (measured 2026-08-31), because
# vctrs finalizes what this returns before returning it. The apparent mismatch
# is not a defect to fix here.
results_ptype <- function(base, from) {
  class(base) <- c("nested_results", class(base))
  copy_results_attributes(base, from)
}

# What a type token carries. `stamp_results()` reads the counts off the rows,
# which is right for an object a caller holds and wrong for a token: a
# prototype has no rows of its own to describe. So the two counts do not travel
# onto one at all -- nothing wearing the class is left claiming a run it does
# not hold (IP4) -- and what `vec_restore()` checks a combination against
# travels privately instead, describing the operation's SOURCE rather than the
# token's own rows: how many rows that source had, and which of its columns the
# record was in.
copy_results_attributes <- function(out, from) {
  for (nm in run_attributes()) {
    attr(out, nm) <- attr(from, nm)
  }
  attr(out, template_rows_attribute()) <- template_rows(from)
  attr(out, template_record_attribute()) <- template_record(from)
  out
}

# The source's row count, from whichever carrier holds it: an object a caller
# holds records it as `folds_attempted`, a prototype privately.
template_rows <- function(x) {
  n <- attr(x, "folds_attempted")
  if (is.null(n)) {
    return(attr(x, template_rows_attribute()))
  }
  n
}

# The names of the source's record columns, from whichever carrier holds them:
# an object with columns says so in its own names, a prototype privately. A
# prototype has none of the source's columns left to read -- `vec_cbind()`'s is
# a frame with no columns at all -- so without this the assembled result could
# be missing a record column and nothing downstream would know (`vec_cbind(x,
# tibble::tibble(splits = 1:3))`, whose name repair renames `splits` away).
template_record <- function(x) {
  nms <- names(x)[record_columns(x)]
  if (length(nms) == 0L) {
    return(attr(x, template_record_attribute()))
  }
  nms
}

template_rows_attribute <- function() {
  "nestedtune_template_rows"
}

template_record_attribute <- function() {
  "nestedtune_template_record"
}

template_attributes <- function() {
  c(template_rows_attribute(), template_record_attribute())
}

# `vec_cbind()` does not reach the prototype above on its own. It builds the
# output's container by calling `x[0]` through `vec_cbind_frame_ptype()`, and a
# zero-column subset of a `nested_results` is a bare tibble by the rule -- so
# without a method here the class is gone before `vec_ptype2()` or
# `vec_restore()` is ever asked, and the same column-add answers differently
# through vctrs than through `dplyr::bind_cols()` (measured 2026-08-31).
#
# The generic is documented `[Experimental]` and vctrs says to expect changes,
# so this is the one method in the file resting on an interface that may move
# (D-033). It can move in two directions, and neither is silent for long. If
# vctrs stops consulting the generic, `vec_cbind()` falls back to the default
# and drops the class, which test-vctrs-compat.R's AC3 block says out loud. If vctrs stops exporting it, the `importFrom` below fails the package
# at load, everywhere, immediately (RR04 recommendation 2).
#' @importFrom vctrs vec_cbind_frame_ptype
#' @export
vec_cbind_frame_ptype.nested_results <- function(x, ...) {
  results_ptype(bare_results(x)[0], x)
}

#' @importFrom vctrs vec_ptype2
#' @export
vec_ptype2.nested_results.nested_results <- function(x, y, ...) {
  results_ptype(vctrs::tib_ptype2(bare_results(x), bare_results(y), ...), x)
}

#' @export
vec_ptype2.nested_results.tbl_df <- function(x, y, ...) {
  results_ptype(vctrs::tib_ptype2(bare_results(x), y, ...), x)
}

#' @export
vec_ptype2.tbl_df.nested_results <- function(x, y, ...) {
  vctrs::tib_ptype2(x, bare_results(y), ...)
}

#' @export
vec_ptype2.nested_results.data.frame <- function(x, y, ...) {
  results_ptype(vctrs::tib_ptype2(bare_results(x), y, ...), x)
}

#' @export
vec_ptype2.data.frame.nested_results <- function(x, y, ...) {
  vctrs::df_ptype2(x, bare_results(y), ...)
}

# Casting down is a question the class can answer: the record is dropped along
# with the claim, and what is left is the data.
#
# Casting UP is not. A table carries no record of a run, and building a
# `nested_results` out of one would be inventing the thing this class exists to
# report honestly (IP4), so the refusal is vctrs' own incompatible-cast
# condition rather than a lossy one -- nothing was lost, the conversion was
# never available. rsample refuses the same way for the same reason.
#
# Every one of them casts the COLUMNS across as well. vctrs hands a cast the
# type it wants back, and assigns what the cast returns into a container built
# from that same type: a cast handing back the object it was given, over a type
# holding a column the object does not, is a column short and vctrs raises its
# own internal error rather than a message a caller can act on (measured
# 2026-08-31 on `dplyr::bind_rows(x, tibble::tibble(other = 1))`, which returns
# a plain table on a build with none of these methods registered).
#' @importFrom vctrs vec_cast
#' @export
vec_cast.nested_results.nested_results <- function(x, to, ...) {
  reconstruct_results(
    vctrs::tib_cast(bare_results(x), bare_results(to), ...),
    x
  )
}

#' @export
vec_cast.tbl_df.nested_results <- function(x, to, ...) {
  vctrs::tib_cast(bare_results(x), to, ...)
}

#' @export
vec_cast.data.frame.nested_results <- function(x, to, ...) {
  vctrs::df_cast(as.data.frame(bare_results(x)), to, ...)
}

#' @export
vec_cast.nested_results.tbl_df <- function(
  x,
  to,
  ...,
  x_arg = "",
  to_arg = ""
) {
  stop_no_cast_to_results(x, to, x_arg, to_arg)
}

#' @export
vec_cast.nested_results.data.frame <- function(
  x,
  to,
  ...,
  x_arg = "",
  to_arg = ""
) {
  stop_no_cast_to_results(x, to, x_arg, to_arg)
}

stop_no_cast_to_results <- function(x, to, x_arg, to_arg) {
  vctrs::stop_incompatible_cast(
    x,
    to,
    x_arg = x_arg,
    to_arg = to_arg,
    details = paste(
      "A `nested_results` records a run that happened;",
      "a table carries no such record to build one from."
    )
  )
}

# `rbind()` consults neither dplyr nor vctrs -- it is base R's own dispatch, and
# neither rsample nor tune registers a method for it, which is why `rbind(x, x)`
# on either of their objects hands back six rows still reporting three (measured
# 2026-08-31). This package cannot leave that standing: an object whose record
# is untrue of its own rows is what IP4 forbids.
#
# The arguments go in stripped, so the `rbind()` inside is base R's data-frame
# method rather than this one again, and the result is put through the same
# rule against the first argument as the template.
#' @export
rbind.nested_results <- function(..., deparse.level = 1) {
  args <- list(...)
  parts <- lapply(args, function(a) {
    if (is.data.frame(a)) bare_results(a) else a
  })
  out <- do.call(base::rbind, c(parts, list(deparse.level = deparse.level)))
  if (!is.data.frame(out)) {
    return(out)
  }
  reconstruct_results(out, args[[1L]])
}

# `dplyr::rename()` is `set_names()`, so it reaches the class through `names<-`
# and no generic either package dispatches on. Renaming a column the record is
# kept in leaves an object missing that column and still claiming the run, and
# this is the only place that can be caught. rsample closes it with the same
# method, written the same way.
#' @export
`names<-.nested_results` <- function(x, value) {
  out <- NextMethod()
  if (!is.data.frame(out)) {
    return(out)
  }
  reconstruct_results(out, x)
}

# The columns every `nested_results` method reads: the per-fold record, plus at
# least one id column to label the folds with. A subset of `record_columns()`,
# and the weaker test -- it asks only that the methods will work, while
# `can_reconstruct_results()` asks that the record be whole.
# `id_cols` is a parameter because the caller sometimes knows them and `x` does
# not: `can_reconstruct_results()` is handed a bare frame that carries no record
# of its own, and the template's record is the one that decides.
has_results_columns <- function(x, id_cols = id_columns(x)) {
  required <- c(".metrics", ".selected", ".grid", ".notes", ".completed")
  all(required %in% names(x)) &&
    length(id_cols) > 0L &&
    all(id_cols %in% names(x))
}

# A tibble is a data frame with three classes and compact row names. Building
# one directly costs a line and saves a dependency on tibble for the sake of
# a constructor.
new_tbl <- function(cols) {
  structure(
    cols,
    class = c("tbl_df", "tbl", "data.frame"),
    row.names = .set_row_names(length(cols[[1L]]))
  )
}

#' Collect the metrics from a nested resampling run
#'
#' @param x A `nested_results` object from [nested_tune_grid()].
#' @param summarize Whether to average the per-fold metrics (`TRUE`, the
#'   default) or return them one row per outer fold (`FALSE`).
#' @param ... Not used; must be empty. An argument passed here is an error
#'   rather than silently ignored.
#'
#' @return A tibble. Summarized, one row per metric with the mean across outer
#'   folds, the number of folds, and the standard error of that mean.
#'   Unsummarized, one row per outer fold and metric.
#'
#' @details
#' The summarized value is the nested cross-validation estimate: what the
#' tune-and-fit procedure achieves on data it never saw. It is not the
#' performance of any model you have in hand.
#'
#' Only the outer folds that completed are summarized, and `n` counts them, so
#' a run with failures never reports its estimate as though the whole design
#' had run. Those folds are dropped with a warning naming them; when no fold
#' completed at all, this errors instead of returning `NA`.
#'
#' @section Reading `std_err`:
#'
#' `std_err` is the standard error of the mean across outer folds: the standard
#' deviation of the per-fold scores divided by the square root of how many there
#' were. It is the precision of that mean, not the fold-to-fold spread, which is
#' larger by the same square-root factor. It is **not** a confidence interval for
#' the estimate, and one should not be built from it.
#'
#' That is a limit of the statistics rather than of this implementation. Outer
#' fold scores are not independent — any two folds share most of their training
#' rows — so a standard error computed as though they were can misstate the
#' uncertainty, typically downward. Bengio and Grandvalet (2004) proved there is
#' no universally unbiased estimator of a k-fold cross-validation estimate's
#' variance to put in its place. Gauran, Ombao and Yu (2025) measured what that
#' costs inside a nested design: several of their test statistics built on a
#' variance-based denominator rejected a true null far more often than the
#' nominal 5% they were run at — 36% and 40% in the worst cells they report —
#' and they recommend against such denominators outright.
#'
#' Both results are about closely related quantities rather than this column
#' exactly: Bengio and Grandvalet study the variance of a k-fold estimate built
#' from per-observation losses, and Gauran and colleagues work inside ridge and
#' LASSO designs. Neither gap rescues the column — no interval here is
#' oracle-backed, which is the practical point.
#'
#' The column is reported because `tune` reports it and users expect the shape;
#' no inferential claim is made with it.
#'
#' @examplesIf rlang::is_installed(c("recipes", "yardstick"))
#' data(mtcars)
#'
#' rec <- recipes::step_pca(
#'   recipes::recipe(mpg ~ ., data = mtcars),
#'   recipes::all_predictors(),
#'   num_comp = tune::tune()
#' )
#' wf <- workflows::workflow(rec, parsnip::linear_reg())
#'
#' set.seed(1)
#' folds <- nested_resamples(
#'   mtcars,
#'   outside = rsample::vfold_cv(v = 3),
#'   inside = rsample::vfold_cv(v = 3)
#' )
#'
#' set.seed(2)
#' res <- nested_tune_grid(wf, folds, grid = data.frame(num_comp = 1:3))
#'
#' collect_metrics(res)
#' collect_metrics(res, summarize = FALSE)
#'
#' @references
#' Bengio, Y., & Grandvalet, Y. (2004). No unbiased estimator of the variance of
#' K-fold cross-validation. *Journal of Machine Learning Research*, 5,
#' 1089–1105.
#'
#' Gauran, I. I., Ombao, H., & Yu, Z. (2025). Predictive performance test based
#' on the exhaustive nested cross-validation for high-dimensional data.
#' *arXiv:2408.03138*.
#'
#' @export
collect_metrics.nested_results <- function(x, ..., summarize = TRUE) {
  rlang::check_dots_empty()
  check_any_completed(x)
  warn_partial_summary(x)

  per_fold <- per_fold_metrics(x)
  if (!summarize) {
    return(per_fold)
  }
  summarize_folds(per_fold)
}

# The averaging, with no conditions of its own.
#
# Split out from collect_metrics() so that print.nested_results() can show the
# same numbers without the warning and the abort: a summary is a request for an
# estimate and owes the caller a condition when the design fell short, while a
# print is a description of the object and says the same thing in its header
# instead. Both read the estimate off this one function, so they can never
# disagree about it.
summarize_folds <- function(per_fold) {
  keys <- paste(per_fold$.metric, per_fold$.estimator, sep = "\r")
  first <- !duplicated(keys)

  # A fold can score NA -- an outer assessment set with one class gives
  # roc_auc = NA, which small folds on imbalanced data reach routinely. Those
  # folds are dropped from the summary rather than allowed to poison it, and
  # `n` counts the folds that actually contributed, so a summary row never
  # reports no estimate while claiming every fold was in it. This is what
  # tune::estimate_tune_results() does, and GP1 says to match it.
  estimates_for <- function(k) {
    vals <- per_fold$.estimate[keys == k]
    vals[!is.na(vals)]
  }

  mean_of <- vapply(
    keys[first],
    function(k) {
      vals <- estimates_for(k)
      if (length(vals) == 0L) NA_real_ else mean(vals)
    },
    numeric(1),
    USE.NAMES = FALSE
  )
  n_of <- vapply(
    keys[first],
    function(k) {
      length(estimates_for(k))
    },
    integer(1),
    USE.NAMES = FALSE
  )
  se_of <- vapply(
    keys[first],
    function(k) {
      vals <- estimates_for(k)
      if (length(vals) < 2L) NA_real_ else stats::sd(vals) / sqrt(length(vals))
    },
    numeric(1),
    USE.NAMES = FALSE
  )

  new_tbl(list(
    .metric = per_fold$.metric[first],
    .estimator = per_fold$.estimator[first],
    mean = mean_of,
    n = n_of,
    std_err = se_of
  ))
}

# IP4: nothing is reported for a design that did not run at all. With no fold
# completed there is no estimate to give, and returning NA would let a caller
# treat the absence of a result as a result. `action` names what the caller was
# asking for -- summarizing or plotting -- so both refusals say the same thing
# about the same object and cannot drift apart.
check_any_completed <- function(
  x,
  action = "summarize",
  call = rlang::caller_env()
) {
  # Read from the column, never from the stamped count: the column travels with
  # the rows, so the two can never disagree about the object actually in hand.
  if (any(x$.completed)) {
    return(invisible(x))
  }
  n <- nrow(x)
  cli::cli_abort(
    c(
      "There is nothing to {action}: no outer fold completed.",
      x = "All {n} outer fold{?s} failed.",
      i = "See {.code x$.notes} for what went wrong."
    ),
    call = call
  )
}

# A partial run is still summarized -- expensive compute is not thrown away --
# but never quietly. The count in `n` says how many folds contributed; this
# says which ones did not, and that the design asked for more.
warn_partial_summary <- function(x, call = rlang::caller_env()) {
  failed <- fold_ids(x)[!x$.completed]
  if (length(failed) == 0L) {
    return(invisible(x))
  }
  n <- nrow(x)
  cli::cli_warn(
    c(
      "!" = "This summary covers {sum(x$.completed)} of {n} outer fold{?s}.",
      x = "Failed: {.val {failed}}.",
      i = "It describes the folds that ran, not the design that was requested."
    ),
    class = "nestedtune_partial_summary",
    call = call
  )
  invisible(x)
}

# One row per outer fold and metric. The per-fold tibbles come straight from
# tune::last_fit(), so their columns are tune's, not ours.
per_fold_metrics <- function(x) {
  ids <- fold_ids(x)
  n_rows <- vapply(x$.metrics, nrow, integer(1))

  new_tbl(list(
    id = rep(ids, times = n_rows),
    .metric = unlist(
      lapply(x$.metrics, function(m) m$.metric),
      use.names = FALSE
    ),
    .estimator = unlist(
      lapply(x$.metrics, function(m) m$.estimator),
      use.names = FALSE
    ),
    .estimate = unlist(
      lapply(x$.metrics, function(m) m$.estimate),
      use.names = FALSE
    )
  ))
}

# The outer fold labels. A repeated design carries id and id2; pasting them
# keeps each row's label unique without assuming which columns are present.
# Asking id_columns() -- the constructor's record -- rather than a name pattern
# is what stops a column the caller added from being pasted in with them
# (M36 T9, narrowed to the record in M38).
fold_ids <- function(x) {
  id_cols <- id_columns(x)
  if (length(id_cols) == 1L) {
    return(x[[id_cols]])
  }
  do.call(paste, c(lapply(id_cols, function(nm) x[[nm]]), list(sep = ", ")))
}
