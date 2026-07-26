# Printing a nested_final_fit.
#
# The object holds a tuning run, and that run has metrics: the full-data
# resampling estimate at the selected configuration. It is plain CV subject to
# selection optimism over the grid, and it wears tune's authoritative clothes.
# No number from it appears here (RR02 Q7). What appears instead is the sentence
# saying where this model's honest estimate lives, because a print method is
# where a user meets the object.

#' Print a final fit
#'
#' @description
#' Reports which parameters the full-data tuning run selected, and says where
#' this model's performance estimate actually comes from.
#'
#' No performance number is shown. The tuning run stored on the object has
#' metrics, but they were consumed by selection and are optimistically biased as
#' a claim about this model; the nested estimate from [nested_tune_grid()] is
#' the one to report (IP3).
#'
#' @param x A `nested_final_fit` object from [nested_final_fit()].
#' @param ... Not used.
#'
#' @return `x`, invisibly.
#'
#' @seealso [nested_final_fit()], [nested_tune_grid()]
#' @export
print.nested_final_fit <- function(x, ...) {
  cli::cli_h1("Nested cross-validation final fit")
  cli::cli_text("Selected: {selected_label(x$selected)}")
  cli::cli_text("")
  cli::cli_bullets(c(
    i = "This model has no performance estimate of its own. Report the nested \\
         estimate from {.code collect_metrics()} on the {.fn nested_tune_grid} \\
         result, which describes the procedure that produced it.",
    i = "Compare the parameters above with {.code .selected} from that run. \\
         Outer folds choosing differently is selection instability, and it is \\
         information about the procedure rather than noise."
  ))
  invisible(x)
}

# The selected candidate as `name = value` pairs.
#
# tune adds a `.config` column to what select_best() returns; it labels the
# candidate inside the tuning run and means nothing outside it.
selected_label <- function(selected) {
  keep <- setdiff(names(selected), ".config")
  if (length(keep) == 0L) {
    return("nothing to select")
  }
  paste0(keep, " = ", vapply(keep, function(nm) {
    format(selected[[nm]][[1L]])
  }, character(1)), collapse = ", ")
}
