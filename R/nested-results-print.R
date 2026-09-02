# Printing a nested_results, and summarizing one.
#
# The two answer different questions and this file keeps them apart. print()
# describes the OBJECT: it is a tibble of outer folds, so it shows its rows,
# says how much of the design did not run, and points at summary() for the rest.
# summary() says what the run MEANS: the design, the failures and their stages,
# the selections, and the estimate across the folds that completed.
#
# Every fact either one reports is derived from the columns at call time rather
# than read off the counts stamped at construction. The stamped counts describe
# the run the rows came from; a subset's rows are their own run, and both
# methods must describe the object in hand (IP4).
#
# Printing never raises and never warns. summary() and collect_metrics() warn on
# a partial run, because asking what a design that only partly ran means
# deserves an answer with a condition attached; printing is a description of an
# object, and an object that describes a failed run is exactly what M03 built.

#' Print a nested cross-validation result
#'
#' @description
#' Shows the object: its outer folds as the tibble rows they are, the outer
#' resampling scheme it came from, how many folds did not complete, and a
#' pointer to [summary.nested_results()] for what the run means.
#'
#' Printing also says when the folds were not choosing from the same menu. A
#' grid given as a size is expanded per fold, under that fold's own seed, so a
#' continuous parameter leaves every fold with its own candidates — which
#' changes how the selections [summary.nested_results()] reports should be
#' read. The line
#' reports each fold's candidate count and appears only when the sets actually
#' differ.
#'
#' @param x A `nested_results` object from [nested_tune_grid()] or
#'   [nested_tune_bayes()].
#' @param ... Not used; must be empty. An argument passed here is an error
#'   rather than silently ignored, so `n` and `width` must be spelled out in
#'   full.
#' @param n Number of rows to show, passed to the tibble printing of the outer
#'   folds. `NULL`, the default, leaves it to tibble: every row when there are
#'   fewer than the `print_max` option allows, and otherwise the `print_min`
#'   option's count with a footer saying how many more there are. `Inf` shows
#'   every fold.
#' @param width Width of text output to generate for the rows, passed to the
#'   tibble printing. `NULL`, the default, uses the `width` option. Columns that
#'   do not fit are listed in the footer under their names.
#'
#' @return `x`, invisibly.
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
#' res
#'
#' @seealso [summary.nested_results()], [nested_tune_grid()],
#'   [collect_metrics()]
#' @export
print.nested_results <- function(x, ..., n = NULL, width = NULL) {
  # `n` and `width` sit after the fence so they match by full name only: a
  # partial spelling lands in `...` and is refused rather than silently ignored
  # (GP3). tibble's own method takes `width` before its dots, so this is one
  # place the two signatures differ on purpose. The two are the whole
  # pass-through: any other tibble print option is not reachable from here.
  rlang::check_dots_empty()
  cli::cli_h1("Nested cross-validation results")
  label <- attr(x, "outer_label")
  if (!is.null(label)) {
    cli::cli_text("Outer resamples: {label}")
  }
  print_rows(x, n = n, width = width)
  print_failure_count(x)
  print_candidate_sets(x$.grid[x$.completed])
  cli::cli_bullets(c(
    i = "Use {.fn summary} for what the run means: which folds failed, what \\
         each one selected, and the estimate across them."
  ))
  invisible(x)
}

# The object's own rows, rendered by whatever prints the classes underneath.
#
# Stripping this class rather than formatting the columns here: a nested_results
# IS a tibble and tibble already knows how to show one, including the truncation
# rules a wide table needs (D-037). Routed through cli rather than printed
# straight to the console so the whole method writes to one stream -- cli
# redirects to stderr whenever a sink is active on stdout, and a method that
# wrote to both would come apart under capture.
print_rows <- function(x, n = NULL, width = NULL) {
  rows <- x
  class(rows) <- setdiff(class(rows), "nested_results")
  cli::cli_verbatim(utils::capture.output(print(rows, n = n, width = width)))
  invisible(NULL)
}

# How much of the design did not run. The count only -- which folds failed and
# at what stage is a fact about what the run MEANS, and lives behind summary().
# Silent on a whole run, so its presence is itself the signal.
print_failure_count <- function(x) {
  failed <- sum(!x$.completed)
  if (failed == 0L) {
    return(invisible(NULL))
  }
  n <- nrow(x)
  cli::cli_bullets(c(
    x = "{failed} of {n} outer fold{?s} did not complete."
  ))
  invisible(NULL)
}

#' Summarize a nested cross-validation result
#'
#' @description
#' Answers what the run means: how much of the requested outer design ran,
#' which outer folds failed and at which stage, what each fold's inner tuning
#' selected, and the estimate across the folds that completed.
#'
#' The selection lines are the part nothing else in the ecosystem shows. When
#' outer folds choose different parameters, the tuning procedure is unstable on
#' this data — averaging the metrics hides that, so the summary marks it.
#'
#' Summarizing a run that only partly completed warns, and still returns the
#' summary: the folds that ran are described, and the warning says the design
#' asked for more. A run where every fold failed is the same case — it warns
#' and still returns, describing a failed run rather than refusing to answer.
#' That is where this differs from [collect_metrics()], which aborts when no
#' outer fold completed.
#'
#' @param object A `nested_results` object from [nested_tune_grid()] or
#'   [nested_tune_bayes()].
#' @param ... Not used; must be empty. An argument passed here is an error
#'   rather than silently ignored.
#'
#' @return
#' `summary()` returns an object of class `summary.nested_results`: a list
#' holding the outer resampling scheme's label, the outer design's requested
#' and completed fold counts, the failed folds with the stage each failed at,
#' the parameter values the completed folds selected, the candidate grid each
#' completed fold searched, and the metric estimates averaged across them.
#' Printing it is what most callers want; the components are there for a
#' caller that needs a number rather than a line of text.
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
#' summary(res)
#'
#' @seealso [print.nested_results()], [nested_tune_grid()], [collect_metrics()]
#' @export
summary.nested_results <- function(object, ...) {
  rlang::check_dots_empty()
  # The partial-run warning belongs to being asked what the run MEANS, which is
  # this method and collect_metrics(). It never travelled with print(), which
  # only describes the object in hand.
  warn_partial_summary(object)
  new_summary_nested_results(object)
}

#' @rdname summary.nested_results
#' @param x A `summary.nested_results` object from [summary.nested_results()].
#' @return
#' `print()` returns `x`, invisibly.
#' @export
print.summary.nested_results <- function(x, ...) {
  rlang::check_dots_empty()
  cli::cli_h1("Nested cross-validation results")
  print_design(x)
  print_failures(x)
  print_selection(x)
  print_estimate(x)
  print_procedure_note()
  invisible(x)
}

# Everything the two print methods report, computed once from the columns.
#
# Derived at summary time rather than read off the counts stamped at
# construction: the stamped counts describe the run the rows came from, and a
# subset's rows are their own run (IP4). Nothing here raises and nothing here
# warns -- warning is summary()'s job, and it does it before calling this.
new_summary_nested_results <- function(x) {
  completed <- which(x$.completed)
  failed <- which(!x$.completed)
  ids <- fold_ids(x)
  selected <- x$.selected[completed]

  structure(
    list(
      outer_label = attr(x, "outer_label"),
      requested = nrow(x),
      completed = length(completed),
      failures = list(
        id = ids[failed],
        stage = vapply(x$.notes[failed], fold_failure_stage, character(1))
      ),
      selection = summary_selection(selected),
      grids = x$.grid[completed],
      estimate = if (length(completed) > 0L) {
        summarize_folds(per_fold_metrics(x))
      }
    ),
    class = "summary.nested_results"
  )
}

# One entry per parameter any completed fold chose a value for, each holding
# one string per completed fold in fold order. Empty when nothing completed and
# when the workflow had nothing to tune -- two cases the printing tells apart.
summary_selection <- function(selected) {
  params <- selection_params(selected)
  out <- lapply(params, function(p) selection_values(selected, p))
  names(out) <- params
  out
}

# IP3, and the reason these methods exist at all: the number above is a
# property of the procedure, and the sentence saying so travels with it rather
# than living in documentation the reader has to go and find.
print_procedure_note <- function() {
  cli::cli_text("")
  cli::cli_bullets(c(
    i = "A nested estimate describes the tune-and-fit procedure, not a model \\
         you can deploy. Build that with {.fn nested_final_fit}, and report \\
         this estimate as what its procedure achieves."
  ))
  invisible(NULL)
}

print_design <- function(s) {
  if (!is.null(s$outer_label)) {
    cli::cli_text("Outer resamples: {s$outer_label}")
  }
  cli::cli_text(
    "Outer folds: {s$requested} requested, {s$completed} completed"
  )
  invisible(NULL)
}

print_failures <- function(s) {
  if (length(s$failures$id) == 0L) {
    return(invisible(NULL))
  }
  for (i in seq_along(s$failures$id)) {
    id <- s$failures$id[[i]]
    stage <- s$failures$stage[[i]]
    cli::cli_bullets(c(x = "{id} failed during {stage}."))
  }
  # The results object, not `x`: what is bound to `x` here is the summary
  # bundle, which has no `.notes`. The column lives on the object the caller
  # summarized, and the sentence names it by the column alone (M43).
  cli::cli_bullets(c(
    i = "See the {.code .notes} column of the results object for what went \\
         wrong."
  ))
  invisible(NULL)
}

# The stage is the first row of the fold's notes: M03 files its own note naming
# the stage ahead of tune's notes about the cause. A fold recorded some other
# way still prints, without inventing a stage it does not know.
fold_failure_stage <- function(notes) {
  if (is.null(notes) || nrow(notes) == 0L) {
    return("an unrecorded stage")
  }
  notes$location[[1L]]
}

print_selection <- function(s) {
  cli::cli_h2("Selected parameters")

  if (s$completed == 0L) {
    cli::cli_bullets(c(i = "No outer fold completed, so nothing was selected."))
    return(invisible(NULL))
  }
  if (length(s$selection) == 0L) {
    cli::cli_bullets(c(i = "No tuned parameters."))
    return(invisible(NULL))
  }
  for (param in names(s$selection)) {
    print_one_parameter(param, s$selection[[param]], s$completed)
  }
  invisible(NULL)
}

# Whether the folds were even choosing from the same menu (M21).
#
# Printed by print() rather than behind summary() because it qualifies the rows
# above it: a reader looking at a table of outer folds is entitled to know that
# the folds did not all have the same candidates to choose from, before
# summary() says what each one chose. With the default `grid = 10` and any
# continuous parameter this is the ordinary case, not an edge case --
# expansion is stochastic and each fold tunes under its own seed.
#
# Silent on agreement, so the line appears only when it changes how the
# selections summary() reports should be read.
print_candidate_sets <- function(grids) {
  if (length(grids) < 2L || same_candidates(grids)) {
    return(invisible(NULL))
  }
  counts <- vapply(
    grids,
    function(g) if (is.data.frame(g)) nrow(g) else NA_integer_,
    integer(1)
  )
  # The counts, not just the fact of disagreement: they separate two different
  # stories. Equal counts mean the folds searched the same number of different
  # values; unequal ones mean one fold's grid truncated further than another's.
  shown <- cli::cli_vec(
    counts,
    list("vec-sep" = ", ", "vec-last" = ", ", "vec-trunc" = 12)
  )
  cli::cli_bullets(c(
    "!" = "Candidates searched: {shown} \u2014 the folds did not search the \\
           same grid"
  ))
  invisible(NULL)
}

# Compared on the parameter values themselves, never on `.config`: that label is
# positional, so two folds that searched the same candidates in a different
# order carry different labels for them. Compared by identical() on the sorted
# columns rather than through formatted strings, so two values that differ
# beyond the print precision still count as different.
same_candidates <- function(grids) {
  keys <- lapply(grids, candidate_key)
  all(vapply(keys[-1L], identical, logical(1), keys[[1L]]))
}

candidate_key <- function(g) {
  if (!is.data.frame(g)) {
    return(NULL)
  }
  # `.iter` is bookkeeping too (M45): the iteration a candidate was proposed
  # in says when a fold reached it, not what it is, and two folds that scored
  # the same candidates in different iterations searched the same set.
  params <- sort(setdiff(names(g), c(".config", ".iter")))
  if (length(params) == 0L || nrow(g) == 0L) {
    return(list())
  }
  values <- lapply(params, function(p) g[[p]])
  # Row order is not part of the candidate set, so it is normalised away before
  # comparison; the names travel too, so a fold carrying a different parameter
  # entirely is a difference rather than a coincidence of values.
  #
  # The permutation comes from a rendered key rather than from `order()` over
  # the columns themselves. `order()` RAISES on a list column -- "unimplemented
  # type 'list' in 'orderVector1'" -- and this method promises never to raise
  # (M21 review F1; the earlier claim that it does not raise was measured
  # against `scored_candidates_impl()`, which orders `.config` and never a
  # parameter column, so it tested a different path).
  #
  # Rendering decides ROW ORDER ONLY. What is returned and compared is the
  # original values, so two candidates differing below print precision are
  # still different -- rendering them alike merely puts them in the same
  # position for a comparison that then fails on the values.
  ord <- order(rendered_rows(values, nrow(g)))
  sorted <- lapply(values, function(v) v[ord])
  names(sorted) <- params
  sorted
}

# One string per candidate row, total over any column type a parameter can be.
rendered_rows <- function(values, n) {
  vapply(
    seq_len(n),
    function(i) {
      cells <- vapply(
        values,
        function(v) paste0(format(v[[i]]), collapse = "\r"),
        character(1)
      )
      paste0(cells, collapse = "\v")
    },
    character(1)
  )
}

# Every column any completed fold chose a value for, less tune's bookkeeping.
# Taken as a union across folds rather than from the first one, so a parameter
# only some folds carry is still shown rather than silently dropped.
selection_params <- function(selected) {
  nms <- unique(unlist(lapply(selected, names), use.names = FALSE))
  setdiff(nms, ".config")
}

# One string per completed fold, in fold order. A fold with no value for this
# parameter holds its place rather than shifting the rest, so position still
# identifies the fold that chose each value.
#
# `NA_character_` here means "this fold has no value for this parameter" and
# nothing else. A fold that genuinely selected `NA` renders the string "NA" and
# counts as a value: collapsing the two would let a missing column read as a
# selection, and a selection read as a missing column.
selection_values <- function(selected, param) {
  vapply(
    selected,
    function(s) {
      if (is.null(s) || !param %in% names(s)) {
        return(NA_character_)
      }
      value <- s[[param]][[1L]]
      # A list-valued selection is not something select_best() produces, but this
      # method promises never to raise, and vapply() would abort on a length-2
      # result rather than print anything at all.
      if (length(value) != 1L) {
        return(paste(format(value), collapse = ", "))
      }
      if (is.na(value)) {
        return("NA")
      }
      as.character(value)
    },
    character(1)
  )
}

# Unanimity collapses to the single value the folds agreed on; disagreement
# prints every fold's choice. Both say so in words rather than only through the
# bullet symbol, which is a tick or an exclamation mark depending on whether
# the terminal draws unicode.
#
# Agreement is judged over the folds that have a value, never over the whole
# column. A parameter only some folds carry would otherwise read as folds
# disagreeing about it -- and a false instability flag is the most expensive
# thing this method can print, since surfacing real instability is why it
# exists. How many folds had no value is stated rather than swallowed.
print_one_parameter <- function(param, values, n) {
  present <- values[!is.na(values)]
  absent <- sum(is.na(values))

  if (length(present) == 0L) {
    cli::cli_bullets(c(i = "{param}: no completed fold recorded a value."))
    return(invisible(NULL))
  }

  if (length(unique(present)) == 1L) {
    value <- present[[1L]]
    chose <- length(present)
    if (absent > 0L) {
      cli::cli_bullets(c(
        v = "{param}: {value} (all {chose} fold{?s} that chose it agree; \\
             {absent} recorded no value)"
      ))
    } else if (n == 1L) {
      cli::cli_bullets(c(v = "{param}: {value} (the only completed fold)"))
    } else {
      cli::cli_bullets(c(
        v = "{param}: {value} (all {n} completed folds agree)"
      ))
    }
    return(invisible(NULL))
  }

  shown <- cli::cli_vec(
    ifelse(is.na(values), "--", values),
    list("vec-sep" = ", ", "vec-last" = ", ", "vec-trunc" = 12)
  )
  cli::cli_bullets(c("!" = "{param}: {shown} (folds disagree)"))
  invisible(NULL)
}

print_estimate <- function(s) {
  requested <- s$requested
  completed <- s$completed

  if (completed == 0L) {
    cli::cli_h2("Estimate")
    cli::cli_bullets(c(i = "No outer fold completed, so there is no estimate."))
    return(invisible(NULL))
  }

  # The fold count sits in the heading rather than beside each number, so a
  # partial run cannot be read as a whole one however far down the reader gets.
  cli::cli_h2("Estimate ({completed} of {requested} outer fold{?s})")
  summarized <- s$estimate
  timed <- ".eval_time" %in% names(summarized)
  for (i in seq_len(nrow(summarized))) {
    metric <- summarized$.metric[[i]]
    estimator <- summarized$.estimator[[i]]
    value <- format(summarized$mean[[i]], digits = 3)
    # A metric measured at an evaluation time is one row per time (M41), and
    # the line says which, as the condition the number was read under. A row
    # with no time -- a static metric, or a run that named none -- is unchanged.
    label <- "{metric} ({estimator})"
    if (timed && !is.na(summarized$.eval_time[[i]])) {
      at <- summarized$.eval_time[[i]]
      label <- paste(label, "at time {at}")
    }
    # A fold can complete and still score NA on one metric while scoring the
    # others -- so a metric averaged over fewer folds than completed says so,
    # on its own line, where the heading would be wrong for it alone.
    contributing <- summarized$n[[i]]
    if (contributing == completed) {
      cli::cli_text(paste0(label, ": {value}"))
    } else {
      cli::cli_text(
        paste0(label, ": {value} (from {contributing} fold{?s})")
      )
    }
  }
  invisible(NULL)
}
