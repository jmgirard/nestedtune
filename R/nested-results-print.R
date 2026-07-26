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
  invisible(NULL)
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
