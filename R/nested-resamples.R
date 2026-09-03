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
#' @param ... Not used; must be empty. All three arguments above are required,
#'   so the barrier is what turns a mistyped fourth into an error.
#'
#' @return An object of class `nested_resamples`, which also carries the classes
#'   [rsample::nested_cv()] returns, so methods written against those keep
#'   working. It is the outer `rset` with an `inner_resamples` list column
#'   added, one inner `rset` per outer split.
#'
#' @section Differences from rsample:
#'
#' The splits select the same rows. [rsample::analysis()] and
#' [rsample::assessment()] return identical frames, attributes included, and
#' each inner split carries the class and the resample id rsample gives it, so
#' `labels()` and [rsample::add_resample_id()] behave the same. What differs is
#' what the splits point at: nestedtune's index the original data, rsample's
#' index a materialized copy of each outer fold's analysis set. One behavior
#' differs on purpose.
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
nested_resamples <- function(data, outside, inside, ...) {
  rlang::check_dots_empty()
  cl <- match.call()
  env <- rlang::caller_env()

  if (!is.data.frame(data)) {
    cli::cli_abort(
      "{.arg data} must be a data frame, not {.obj_type_friendly {data}}."
    )
  }

  outer_cl <- cl[["outside"]]
  if (rlang::is_call(outer_cl)) {
    outside <- eval_spec(outer_cl, data, env, "outside", call = environment())
  }
  if (!inherits(outside, "rset")) {
    cli::cli_abort(c(
      "{.arg outside} must be a resampling specification or an {.cls rset}.",
      x = "Got {.obj_type_friendly {outside}}."
    ))
  }
  # An rset carries the data its indices refer to. If that is not the data we
  # were handed, remapping those indices onto `data` would silently produce
  # inner splits drawn from rows the outer fold assigned to assessment -- a
  # leak across the outer boundary (IP1) that no inspection of the result would
  # reveal. rsample sidesteps this by ignoring `data` entirely for an rset;
  # refusing says so instead of quietly picking one.
  if (!identical(split_data(outside), data)) {
    cli::cli_abort(c(
      "{.arg outside} was built on different data than {.arg data}.",
      x = "Its row indices refer to that other data frame, so composing them \\
           with {.arg data} would draw inner splits from rows the outer fold \\
           holds out.",
      i = "Pass the same data frame {.arg outside} was built from, or give \\
           {.arg outside} as an unevaluated call such as \\
           {.code vfold_cv(v = 5)}."
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
    data = data,
    call = environment()
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
inner_resamples_from_split <- function(split, cl, env, data, call) {
  outer_idx <- as.integer(split$in_id)
  analysis_frame <- as.data.frame(split)

  # This function runs once per outer fold, so the rset guard below it covers
  # every fold. A pre-pass over the first fold would be cheaper to write and
  # wrong: building an rset draws from the RNG, so the extra evaluation would
  # shift the stream and change every design this function returns.
  inner_rset <- eval_spec(cl, analysis_frame, env, "inside", call = call)
  if (!inherits(inner_rset, "rset")) {
    cli::cli_abort(
      c(
        "{.arg inside} did not produce an {.cls rset}.",
        x = "{.code {paste(deparse(cl), collapse = ' ')}} gave \\
             {.obj_type_friendly {inner_rset}}.",
        i = "It is evaluated once per outer fold, so it must return an \\
             {.cls rset} for every one of them."
      ),
      call = call
    )
  }

  # Rebuilding the splits from scratch would drop everything rsample attaches
  # beyond the indices -- the split subclass and the per-split `id` tibble that
  # labels()/add_resample_id() read. So the splits rsample just produced are
  # kept and only their three index-bearing fields are rewritten.
  #
  # `out_id` is made explicit rather than left as NA. rsample can leave it NA
  # because its inner splits index a frame that *is* the analysis set, so the
  # complement is derivable; ours index the whole data, where the complement
  # would sweep in the outer fold's assessment rows.
  splits <- lapply(inner_rset$splits, function(inner_split) {
    assessment_idx <- outer_idx[as.integer(rsample::complement(inner_split))]
    inner_split$in_id <- outer_idx[as.integer(inner_split$in_id)]
    inner_split$out_id <- assessment_idx
    inner_split$data <- data
    inner_split
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

# Re-point one outer fold's inner splits at that fold's analysis frame, so the
# frame tune reads holds only the rows the fold may see (M54).
#
# tune finalizes an unknown parameter range on `resamples$splits[[1]]$data`,
# the whole frame the first inner split carries, molded through the workflow's
# preprocessor (`tune_grid_workflow()`, tune 2.1.0; the racers through the
# `tune_grid()` they call, `tune_sim_anneal()` through its own
# `check_parameters()`). The inner splits `inner_resamples_from_split()` builds
# index the caller's one frame, assessment rows included, so read that way the
# range is finalized on rows IP1 keeps out of the inner loop -- a `min_n` bound
# of 100 on a 200-row frame where the fold's 160 analysis rows give 80 --
# while a `nested_cv()` design, whose inner splits carry the analysis set as
# their own frame, gets it right by construction. This is the inverse of that
# remap: the indices come back onto the analysis frame, so the inner call no
# longer receives the object the design holds (the GP1 divergence DESIGN
# records), while the design itself and the wire payload do not change -- the
# analysis frame is materialized once per fold, in the worker, for the tune
# call's duration (GP4). Nothing here draws from the RNG.
#
# Two shapes are left as they are, since the inverse does not apply: an inner
# rset whose frame is not the outer split's (a `nested_cv()` design, whose
# splits `is_fold_payload()`'s shared-frame check also passes, which is why the
# test here is against the outer frame), and an outer split whose `in_id`
# repeats a row (an evaluated `manual_rset()`), where `match()` would collapse
# the repeats onto one position. An index the outer split does not hold is
# left alone the same way rather than mapped to `NA`.
analysis_framed_inner <- function(inner, split) {
  outer_idx <- as.integer(split$in_id)
  if (anyDuplicated(outer_idx) > 0L) {
    return(inner)
  }
  shared <- vapply(
    inner$splits,
    function(inner_split) identical(inner_split$data, split$data),
    logical(1)
  )
  if (!all(shared)) {
    return(inner)
  }

  # An all-`NA` `out_id` is rsample's "the complement", derivable from the
  # frame, and stays as it is; any other index is a position in `split$data`
  # that must have a position in the analysis frame.
  remap <- function(idx) {
    if (all(is.na(idx))) {
      return(idx)
    }
    out <- match(as.integer(idx), outer_idx)
    if (anyNA(out)) NULL else out
  }
  splits <- vector("list", length(inner$splits))
  for (i in seq_along(splits)) {
    inner_split <- inner$splits[[i]]
    in_id <- remap(inner_split$in_id)
    out_id <- remap(inner_split$out_id)
    if (is.null(in_id) || is.null(out_id)) {
      return(inner)
    }
    inner_split$in_id <- in_id
    inner_split$out_id <- out_id
    splits[[i]] <- inner_split
  }
  # Materialized only once every index is known to map: an outer split whose
  # own `in_id` reaches past the data is left for `last_fit()` to refuse, as
  # the fold's outer-fit failure, rather than raised here as its inner one.
  analysis_frame <- rsample::analysis(split)
  splits <- lapply(splits, function(inner_split) {
    inner_split$data <- analysis_frame
    inner_split
  })
  # As in `inner_resamples_from_split()`: the rset's class, id columns and
  # attributes are kept, the splits swapped, and the fingerprint recomputed
  # because it describes the indices.
  out <- inner
  out[["splits"]] <- splits
  attr(out, "fingerprint") <-
    attr(rsample::manual_rset(splits, inner$id), "fingerprint")
  out
}

# Evaluate a resampling specification against a data frame.
#
# The frame is bound to a name in a child environment rather than inlined into
# the call. The two are equivalent whenever the call succeeds -- verified
# identical down to the fingerprint -- but any condition raised downstream
# deparses the call it came from, and a call carrying the frame produces a
# message that is the data: 1,194 characters on a 30x2 frame, and growing with
# it. `eval_inside_spec()` (R/checks.R) already takes this shape on the
# final-fit path for the same reason; construction did not.
eval_spec <- function(cl, data, env, arg, call) {
  eval_env <- rlang::new_environment(
    list(.nestedtune_data = data),
    parent = env
  )
  out <- tryCatch(
    eval(rlang::call_modify(cl, data = quote(.nestedtune_data)), eval_env),
    error = function(cnd) cnd
  )
  if (inherits(out, "condition")) {
    cli::cli_abort(
      c(
        "{.arg {arg}} could not be evaluated.",
        x = "Tried to run {.code {paste(deparse(cl), collapse = ' ')}}."
      ),
      parent = out,
      call = call
    )
  }
  out
}

# The data an rset's indices refer to. Every split in an rset shares one data
# frame, so the first split answers for all of them.
split_data <- function(x) {
  x$splits[[1]]$data
}
