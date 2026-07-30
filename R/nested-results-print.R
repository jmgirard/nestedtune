# Printing a nested_results.
#
# Every fact printed here is derived from the columns at print time rather than
# read off the counts stamped at construction. The stamped counts describe the
# run the rows came from; a subset's rows are their own run, and printing must
# describe the object in hand (IP4).
#
# Printing never raises and never warns. collect_metrics() does both, because
# asking for a summary of a design that did not run deserves an answer with a
# condition attached; printing is a description of an object, and an object that
# describes a failed run is exactly what M03 built.

#' Print a nested cross-validation result
#'
#' @description
#' Reports how much of the requested outer design actually ran, which outer
#' folds failed and at which stage, what each fold's inner tuning selected, and
#' the estimate across the folds that completed.
#'
#' The selection lines are the part nothing else in the ecosystem shows. When
#' outer folds choose different parameters, the tuning procedure is unstable on
#' this data — averaging the metrics hides that, so printing marks it.
#'
#' Printing also says when the folds were not choosing from the same menu. A
#' grid given as a size is expanded per fold, under that fold's own seed, so a
#' continuous parameter leaves every fold with its own candidates — which
#' changes how the selection lines above should be read. The line reports each
#' fold's candidate count and appears only when the sets actually differ.
#'
#' @param x A `nested_results` object from [nested_tune_grid()].
#' @param ... Not used.
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
#' @seealso [nested_tune_grid()], [collect_metrics()]
#' @export
print.nested_results <- function(x, ...) {
  cli::cli_h1("Nested cross-validation results")
  print_design(x)
  print_failures(x)
  print_selection(x)
  print_estimate(x)

  # IP3, and the reason this method exists at all: the number above is a
  # property of the procedure, and the sentence saying so travels with it
  # rather than living in documentation the reader has to go and find.
  cli::cli_text("")
  cli::cli_bullets(c(
    i = "A nested estimate describes the tune-and-fit procedure, not a model \\
         you can deploy. Build that with {.fn nested_final_fit}, and report \\
         this estimate as what its procedure achieves."
  ))
  invisible(x)
}

print_design <- function(x) {
  label <- attr(x, "outer_label")
  if (!is.null(label)) {
    cli::cli_text("Outer resamples: {label}")
  }
  requested <- nrow(x)
  completed <- sum(x$.completed)
  cli::cli_text("Outer folds: {requested} requested, {completed} completed")
  invisible(NULL)
}

print_failures <- function(x) {
  failed <- which(!x$.completed)
  if (length(failed) == 0L) {
    return(invisible(NULL))
  }
  ids <- fold_ids(x)
  for (i in failed) {
    id <- ids[[i]]
    stage <- fold_failure_stage(x$.notes[[i]])
    cli::cli_bullets(c(x = "{id} failed during {stage}."))
  }
  cli::cli_bullets(c(i = "See {.code x$.notes} for what went wrong."))
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

print_selection <- function(x) {
  cli::cli_h2("Selected parameters")

  completed <- which(x$.completed)
  if (length(completed) == 0L) {
    cli::cli_bullets(c(i = "No outer fold completed, so nothing was selected."))
    return(invisible(NULL))
  }

  selected <- x$.selected[completed]
  params <- selection_params(selected)
  if (length(params) == 0L) {
    cli::cli_bullets(c(i = "No tuned parameters."))
    return(invisible(NULL))
  }
  for (param in params) {
    print_one_parameter(
      param,
      selection_values(selected, param),
      length(completed)
    )
  }
  print_candidate_sets(x$.grid[completed])
  invisible(NULL)
}

# Whether the folds were even choosing from the same menu (M21).
#
# Printed here rather than in the design block because it qualifies the lines
# above it: a reader comparing what each fold selected is entitled to know that
# the folds did not all have the same candidates to select from. With the
# default `grid = 10` and any continuous parameter this is the ordinary case,
# not an edge case -- expansion is stochastic and each fold tunes under its own
# seed.
#
# Silent on agreement, so the line appears only when it changes how the
# selections above should be read.
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
    "!" = "Candidates searched: {shown} — the folds did not search the \\
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
  params <- sort(setdiff(names(g), ".config"))
  if (length(params) == 0L || nrow(g) == 0L) {
    return(list())
  }
  values <- lapply(params, function(p) g[[p]])
  # Row order is not part of the candidate set, so it is normalised away before
  # comparison; the names travel too, so a fold carrying a different parameter
  # entirely is a difference rather than a coincidence of values.
  ord <- do.call(order, values)
  sorted <- lapply(values, function(v) v[ord])
  names(sorted) <- params
  sorted
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
  vapply(selected, function(s) {
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
  }, character(1))
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
      cli::cli_bullets(c(v = "{param}: {value} (all {n} completed folds agree)"))
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

print_estimate <- function(x) {
  requested <- nrow(x)
  completed <- sum(x$.completed)

  if (completed == 0L) {
    cli::cli_h2("Estimate")
    cli::cli_bullets(c(i = "No outer fold completed, so there is no estimate."))
    return(invisible(NULL))
  }

  # The fold count sits in the heading rather than beside each number, so a
  # partial run cannot be read as a whole one however far down the reader gets.
  cli::cli_h2("Estimate ({completed} of {requested} outer fold{?s})")
  summarized <- summarize_folds(per_fold_metrics(x))
  for (i in seq_len(nrow(summarized))) {
    metric <- summarized$.metric[[i]]
    estimator <- summarized$.estimator[[i]]
    value <- format(summarized$mean[[i]], digits = 3)
    # A fold can complete and still score NA on one metric while scoring the
    # others -- so a metric averaged over fewer folds than completed says so,
    # on its own line, where the heading would be wrong for it alone.
    contributing <- summarized$n[[i]]
    if (contributing == completed) {
      cli::cli_text("{metric} ({estimator}): {value}")
    } else {
      cli::cli_text(
        "{metric} ({estimator}): {value} (from {contributing} fold{?s})"
      )
    }
  }
  invisible(NULL)
}
