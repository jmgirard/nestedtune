#' Build a nested resampling design without copying the data per outer fold
#'
#' `nested_resamples()` builds the same nested resampling structure as
#' [rsample::nested_cv()], but stores index vectors into the original data
#' instead of a materialized analysis set for every outer fold. For the same
#' seed and the same specifications it produces the same splits; what changes is
#' the size of the object that holds them.
#'
#' [rsample::nested_cv()] evaluates the inner specification against
#' `as.data.frame(split)`, so each outer fold's inner resamples reference their
#' own copy of that fold's analysis set. Object size therefore grows by roughly
#' one copy of the data for every outer fold. `nested_resamples()` evaluates the
#' inner specification the same way, against the same transient frame, but keeps
#' only the row indices it produces and remaps them onto the original data — so
#' the inner splits reference the single shared copy the caller already has.
#'
#' @param data A data frame.
#' @param outside The outer resampling specification, given either as an
#'   unevaluated call such as `vfold_cv(v = 5)` or as an already-evaluated
#'   `rset` object.
#' @param inside The inner resampling specification, given as an unevaluated
#'   call such as `vfold_cv(v = 5)`. Unlike `outside`, this cannot be an
#'   existing object, because it is evaluated once per outer fold.
#'
#' @return An object of class `nested_resamples`, which also carries the classes
#'   [rsample::nested_cv()] returns, so methods written against those keep
#'   working. It is the outer `rset` with an `inner_resamples` list column
#'   added, one inner `rset` per outer split.
#'
#' @section Differences from rsample:
#'
#' The splits themselves are identical: [rsample::analysis()] and
#' [rsample::assessment()] return the same frames, attributes included, for the
#' same seed and specifications. One behavior differs on purpose.
#'
#' An **outer bootstrap is refused**, not warned about. The same observation can
#' otherwise land in both the inner analysis and the inner assessment set, which
#' makes the design invalid rather than merely unusual.
#'
#' @examples
#' data(mtcars)
#'
#' set.seed(1)
#' folds <- nested_resamples(
#'   mtcars,
#'   outside = rsample::vfold_cv(v = 3),
#'   inside = rsample::vfold_cv(v = 3)
#' )
#' folds
#'
#' # Each element of inner_resamples is an ordinary rset.
#' folds$inner_resamples[[1]]
#'
#' @seealso [rsample::nested_cv()]
#' @export
nested_resamples <- function(data, outside, inside) {
  cl <- match.call()
  env <- rlang::caller_env()

  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame, not {.obj_type_friendly {data}}.")
  }

  outer_cl <- cl[["outside"]]
  if (rlang::is_call(outer_cl)) {
    outer_cl <- rlang::call_modify(outer_cl, data = data)
    outside <- eval(outer_cl, env)
  }
  if (!inherits(outside, "rset")) {
    cli::cli_abort(c(
      "{.arg outside} must be a resampling specification or an {.cls rset}.",
      x = "Got {.obj_type_friendly {outside}}."
    ))
  }
  if (inherits(outside, "bootstraps")) {
    cli::cli_abort(c(
      "{.arg outside} cannot be a bootstrap.",
      x = "The same row can land in both the inner analysis and inner \\
           assessment set, so the nested estimate would be invalid.",
      i = "{.fn rsample::nested_cv} only warns here; {.fn nested_resamples} \\
           refuses."
    ))
  }

  inner_cl <- cl[["inside"]]
  if (!rlang::is_call(inner_cl)) {
    cli::cli_abort(c(
      "{.arg inside} must be an expression such as {.code vfold_cv(v = 5)}, \\
       not an existing object.",
      i = "It is evaluated once per outer fold, so it cannot be evaluated \\
           ahead of time."
    ))
  }

  inner <- lapply(
    outside$splits,
    inner_resamples_from_split,
    cl = inner_cl,
    env = env,
    data = data
  )

  out <- outside
  out[["inner_resamples"]] <- inner
  class(out) <- c("nested_resamples", "nested_cv", class(outside))
  attr(out, "outside") <- cl$outside
  attr(out, "inside") <- cl$inside
  out
}

# Evaluate the inner specification against one outer fold, keeping only indices.
#
# The analysis frame is built here and referenced by nothing that outlives this
# call, so the inner specification sees exactly what rsample would hand it --
# same rows, same order, same columns, so the same seed draws the same splits --
# while the returned splits reference `data` instead.
inner_resamples_from_split <- function(split, cl, env, data) {
  outer_idx <- as.integer(split$in_id)
  analysis_frame <- as.data.frame(split)

  inner_rset <- eval(rlang::call_modify(cl, data = analysis_frame), env)

  splits <- lapply(inner_rset$splits, function(inner_split) {
    rsample::make_splits(
      list(
        analysis = outer_idx[as.integer(inner_split$in_id)],
        assessment = outer_idx[as.integer(rsample::complement(inner_split))]
      ),
      data = data
    )
  })

  # Keep the inner rset the specification produced -- its class, its id columns
  # (id2 included, which manual_rset() would drop), and its spec attributes --
  # and swap in the remapped splits. The fingerprint is the one exception: it
  # describes rsample's indices, so it is recomputed rather than carried over.
  out <- inner_rset
  out[["splits"]] <- splits
  attr(out, "fingerprint") <-
    attr(rsample::manual_rset(splits, inner_rset$id), "fingerprint")
  out
}
