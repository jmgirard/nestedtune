# Produces `vignettes/articles/why-nest.rds`, the stored result the site-only
# article `vignettes/articles/why-nest.Rmd` ("Why nest: a simulation") reads.
#
# The design follows Varma and Simon (2006), `cairn/references/varma2006.md`:
# data with no signal, so the true accuracy of any classifier is the null
# accuracy by construction, features far outnumbering rows, a learner tuned
# over a grid. Each replicate draws a fresh dataset, tunes the same workflow
# twice on it, and keeps two numbers: the best candidate's mean accuracy from
# a flat `tune::tune_grid()` run, which is the number a tuning run reports as
# its winner's score, and the nested estimate from `nested_tune_grid()`, which
# scores each outer fold's winner on rows its tuning never saw.
#
# The store carries the design, the seed, the null accuracy, the tolerance the
# article holds the nested median to, the commit and the date. The commit and
# the date are provenance and change between runs; everything else is a
# function of the seed, so two runs from the same seed write the same object
# once those two fields are removed.
#
# Run from the package root, with the package and nnet installed:
#
#   Rscript vignettes/articles/why-nest-sim.R
#
# Serially, one replicate takes about 80 seconds on a 2026 laptop, so the
# default of 30 replicates runs for about 40 minutes. The script is under
# `vignettes/articles/`, which `.Rbuildignore` excludes, so neither the
# tarball nor the pkgdown build runs it; the article reads the store.

for (pkg in c("nestedtune", "nnet", "parsnip", "rsample", "workflows",
              "tune", "yardstick")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("package '", pkg, "' is needed to run this script", call. = FALSE)
  }
}

suppressPackageStartupMessages({
  library(nestedtune)
  library(parsnip)
  library(rsample)
  library(workflows)
})

# The design. `n` rows, `p` independent standard normal features, a fair-coin
# label with no dependence on any feature: the null accuracy is 0.5 exactly.
n <- 60L
p <- 200L
null_accuracy <- 0.5
replicates <- 30L
seed <- 20260905L
tolerance <- 0.05
v_outer <- 5L
v_inner <- 5L
epochs <- 50L
grid <- expand.grid(
  hidden_units = c(1L, 2L, 4L, 8L),
  penalty = c(0, 1e-4, 1e-3, 1e-2, 1e-1)
)
# nnet refuses a network with more weights than `MaxNWts`; 8 hidden units on
# 200 inputs need 8 * 201 + 9 = 1617.
max_nwts <- 5000L

# The RNG kind is pinned so the seed means the same thing on every machine,
# and restored on exit.
old_kind <- RNGkind("Mersenne-Twister", "Inversion", "Rejection")
on.exit(do.call(RNGkind, as.list(old_kind)), add = TRUE)

spec <- mlp(hidden_units = tune(), penalty = tune(), epochs = epochs) |>
  set_engine("nnet", MaxNWts = max_nwts) |>
  set_mode("classification")
wf <- workflow(y ~ ., spec)
metrics <- yardstick::metric_set(yardstick::accuracy)

draw_data <- function(n, p) {
  x <- matrix(rnorm(n * p), n, p)
  colnames(x) <- sprintf("x%03d", seq_len(p))
  y <- factor(sample(c("a", "b"), n, replace = TRUE), levels = c("a", "b"))
  data.frame(y = y, x)
}

one_replicate <- function(rep_seed) {
  set.seed(rep_seed)
  dat <- draw_data(n, p)
  flat_folds <- vfold_cv(dat, v = v_outer)
  nested_folds <- nested_resamples(
    dat,
    outside = vfold_cv(v = v_outer),
    inside = vfold_cv(v = v_inner)
  )
  flat <- tune::tune_grid(
    wf,
    flat_folds,
    grid = grid,
    metrics = metrics,
    control = tune::control_grid(verbose = FALSE)
  )
  flat_best <- tune::show_best(flat, metric = "accuracy", n = 1)$mean
  nested <- nested_tune_grid(wf, nested_folds, grid = grid, metrics = metrics)
  nested_estimate <- collect_metrics(nested)$mean
  c(flat_best = flat_best, nested_estimate = nested_estimate)
}

set.seed(seed)
replicate_seeds <- sample.int(.Machine$integer.max, replicates)

started <- Sys.time()
rows <- vector("list", replicates)
for (i in seq_len(replicates)) {
  rows[[i]] <- one_replicate(replicate_seeds[[i]])
  message(sprintf(
    "replicate %2d of %d: flat best %.3f, nested %.3f (%.0f s elapsed)",
    i, replicates, rows[[i]][["flat_best"]], rows[[i]][["nested_estimate"]],
    as.numeric(difftime(Sys.time(), started, units = "secs"))
  ))
}
results <- data.frame(
  replicate = seq_len(replicates),
  seed = replicate_seeds,
  flat_best = vapply(rows, `[[`, numeric(1), "flat_best"),
  nested_estimate = vapply(rows, `[[`, numeric(1), "nested_estimate")
)

commit <- tryCatch(
  system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
  error = function(e) NA_character_,
  warning = function(w) NA_character_
)
if (length(commit) != 1L) commit <- NA_character_

store <- list(
  n = n,
  p = p,
  grid = grid,
  epochs = epochs,
  max_nwts = max_nwts,
  v_outer = v_outer,
  v_inner = v_inner,
  replicates = replicates,
  seed = seed,
  rng_kind = RNGkind(),
  null_accuracy = null_accuracy,
  tolerance = tolerance,
  results = results,
  script = "vignettes/articles/why-nest-sim.R",
  commit = commit,
  date = format(Sys.Date())
)

out <- file.path("vignettes", "articles", "why-nest.rds")
saveRDS(store, out)
message(sprintf(
  "wrote %s: median flat best %.3f, median nested %.3f, %.0f s total",
  out, median(results$flat_best), median(results$nested_estimate),
  as.numeric(difftime(Sys.time(), started, units = "secs"))
))
