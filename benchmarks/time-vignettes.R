# AC5 (M66): median of three rmarkdown::render() timings per CRAN vignette on one head.
# Run from the package root on a quiet machine: Rscript benchmarks/time-vignettes.R <output dir>
pkgload::load_all(".", quiet = TRUE)
out <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(out)) {
  stop("give an output directory as the one argument")
}
pages <- c("nested-cv.Rmd", "estimate.Rmd", "results.Rmd", "tuners.Rmd")
med <- numeric()
for (p in pages) {
  t <- replicate(
    3,
    system.time(rmarkdown::render(
      file.path("vignettes", p),
      output_dir = out,
      intermediates_dir = tempfile(),
      envir = new.env(parent = globalenv()),
      quiet = TRUE
    ))[["elapsed"]]
  )
  med[p] <- median(t)
  cat(sprintf(
    "%-14s runs %s  median %.1f s\n",
    p,
    paste(sprintf("%.1f", t), collapse = " / "),
    med[p]
  ))
}
cat(sprintf(
  "total of medians %.1f s (cap 150); tuners %.1f (cap 45); results %.1f (cap 60)\n",
  sum(med),
  med[["tuners.Rmd"]],
  med[["results.Rmd"]]
))
cat("head:", system("git rev-parse --short HEAD", intern = TRUE), "\n")
