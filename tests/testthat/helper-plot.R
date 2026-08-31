# Reading a built plot.
#
# Every assertion goes through ggplot2::ggplot_build() rather than the data the
# plot was handed, because the question these tests ask is what got *drawn*: a
# point dropped by a scale or absent for want of a value is missing from the
# built layer and present in the data. Pixels are pinned separately, by vdiffr.

# The drawn points, keyed by the fold label their x position stands for and the
# panel they sit in. A discrete x is built as an integer index into the scale's
# labels, so the lookup is what turns a position back into a fold.
plot_points <- function(p) {
  b <- ggplot2::ggplot_build(p)
  d <- layer_with(b, "x")
  data.frame(
    fold = axis_labels(b, "x")[as.integer(d$x)],
    y = d$y,
    panel = panel_labels(b)[as.integer(d$PANEL)],
    stringsAsFactors = FALSE
  )
}

# The horizontal rules -- the marked estimate, one per panel.
plot_rules <- function(p) {
  b <- ggplot2::ggplot_build(p)
  d <- layer_with(b, "yintercept")
  data.frame(
    yintercept = d$yintercept,
    panel = panel_labels(b)[as.integer(d$PANEL)],
    stringsAsFactors = FALSE
  )
}

# The first built layer carrying a given column. Named by what it carries rather
# than by position, so adding a layer beneath the points does not silently move
# every assertion onto the wrong one.
layer_with <- function(b, column) {
  hit <- vapply(b$data, function(d) column %in% names(d), logical(1))
  if (!any(hit)) {
    testthat::fail(paste0("no built layer carries a `", column, "` column"))
  }
  b$data[[which(hit)[[1L]]]]
}

# The axis tick labels of one panel. For a discrete scale these are the factor
# levels the scale kept, so a fold whose level was dropped is missing here too --
# which is how a test distinguishes "no point drawn" from "not on the axis at
# all".
#
# `panel` exists because reading only the first one is what hid M08's F3: a
# continuous parameter in one panel silently reverted every *other* panel's
# breaks, and a helper that could not look past panel 1 could not see it.
axis_labels <- function(p, axis = "x", panel = 1L) {
  b <- if (inherits(p, "ggplot_built")) p else ggplot2::ggplot_build(p)
  as.character(b$layout$panel_params[[panel]][[axis]]$get_labels())
}

# Evaluate something that needs a graphics device, without acquiring a real one.
#
# Anything that measures text -- laying a gtable out, for instance -- opens the
# default device when none is current, and R's default is `pdf()`, which writes
# an `Rplots.pdf` beside the tests that `R CMD check` then NOTEs as a
# non-standard top-level file.
on_null_device <- function(expr) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(expr)
}

# The panel strip labels, in panel order -- where a per-panel qualifier lives.
strip_labels <- function(p) {
  b <- if (inherits(p, "ggplot_built")) p else ggplot2::ggplot_build(p)
  panel_labels(b)
}

panel_labels <- function(b) {
  layout <- b$layout$layout
  facet <- setdiff(
    names(layout),
    c("PANEL", "ROW", "COL", "SCALE_X", "SCALE_Y", "COORD")
  )
  as.character(layout[[facet[[1L]]]])
}

# The labels a reader sees. Absent labels come back as NA rather than dropping
# out, so an assertion on one that was never set fails instead of erroring.
plot_label <- function(p, which) {
  value <- p$labels[[which]]
  if (is.null(value)) {
    NA_character_
  } else {
    paste(as.character(value), collapse = "\n")
  }
}

# A results object whose second fold completed but carries no value for the
# parameter -- the false-instability case M04 pins for printing, reused here
# because the plot must not impute a point for it either.
drop_selection <- function(res, fold = 2L) {
  res$.selected[[fold]] <- res$.selected[[fold]][, ".config", drop = FALSE]
  res
}
