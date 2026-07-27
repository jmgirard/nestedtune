# Wall-clock scaling of parallel outer folds.
#
# Not a test and deliberately not asserted: wall-clock times on shared CI
# runners are noise, and a speedup threshold would fail for reasons that have
# nothing to do with this package. This script exists so the numbers recorded in
# the milestone are reproducible, and so a later change that destroys scaling
# can be caught by running it again.
#
# Run against an INSTALLED copy -- daemons load nestedtune from a library, and
# under devtools::load_all() they cannot see it at all:
#
#   R CMD INSTALL --no-docs -l /tmp/lib .
#   BENCH_LIB=/tmp/lib Rscript benchmarks/parallel-speedup.R
#
# Cold vs warm is the distinction that matters for reading the result. A fresh
# daemon loads the whole tidymodels stack on its first task, inside the timed
# region; "warm" reuses daemons that have already paid that cost, which is what
# a session doing more than one run actually sees.

lib <- Sys.getenv("BENCH_LIB")
if (nzchar(lib)) {
  .libPaths(c(lib, .libPaths()))
  Sys.setenv(R_LIBS = lib)
}
suppressMessages(library(nestedtune))
suppressMessages(library(mirai))

cat(R.version.string, "|", R.version$platform, "\n")
cat("cores:", parallel::detectCores(),
    "| tune", as.character(packageVersion("tune")),
    "| mirai", as.character(packageVersion("mirai")),
    "| ranger", as.character(packageVersion("ranger")), "\n\n")

set.seed(4242)
n <- 600
d <- data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n), x4 = rnorm(n))
d$y <- 2 * d$x1 - d$x2 + 0.5 * d$x3 + rnorm(n)

set.seed(11)
nested <- nested_resamples(
  d,
  outside = rsample::vfold_cv(v = 6),
  inside = rsample::vfold_cv(v = 5)
)
spec <- parsnip::set_mode(
  parsnip::set_engine(
    parsnip::rand_forest(min_n = tune::tune(), trees = 1000),
    "ranger",
    num.threads = 1
  ),
  "regression"
)
wf <- workflows::workflow(y ~ x1 + x2 + x3 + x4, spec)
grid <- data.frame(min_n = c(2L, 5L, 10L, 25L, 40L))
metrics <- yardstick::metric_set(yardstick::rmse, yardstick::rsq)

cat("design: 6 outer x 5 inner, grid of 5, ranger 1000 trees, n = 600\n\n")

run <- function() {
  set.seed(2026)
  nested_tune_grid(wf, nested, grid = grid, metrics = metrics)
}

daemons(0)
t_serial <- system.time(serial <- run())[["elapsed"]]
cat(sprintf("serial                   : %6.1f s\n\n", t_serial))

for (k in c(2L, 4L, 6L)) {
  daemons(0)
  daemons(k)
  t_cold <- system.time(cold <- run())[["elapsed"]]
  t_warm <- system.time(warm <- run())[["elapsed"]]
  cat(sprintf(
    "%d daemons  cold %6.1f s (%.2fx)  warm %6.1f s (%.2fx)  identical: %s\n",
    k, t_cold, t_serial / t_cold, t_warm, t_serial / t_warm,
    identical(cold, serial) && identical(warm, serial)
  ))
}
daemons(0)
