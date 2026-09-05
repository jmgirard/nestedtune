# The M66 idiom sweep over every `.Rmd` under `vignettes/`, recursive.
#
# Reader-facing chunk: a fenced `{r ...}` chunk whose header does not set
# `echo = FALSE` or `include = FALSE` (each page's `opts_chunk$set()` sets
# only `collapse` and `comment`, so the header is the effective option).
#
# Three checks, each printing every hit as `file:line: text` and a closing
# `clean` line when it found none:
#   idioms  -- the base idioms the pages dropped, in reader-facing chunks, and
#              `[[` anywhere but a peek `<object>$<column>[[<integer>]]`
#   prefix  -- `pkg::` on nestedtune or a `tidymodels::core` package in
#              reader-facing chunks, and the attach order behind its guard
#   prose   -- outside chunks and inline `r` spans: an em dash, a token
#              `M<digit><digit>`, and every `vignette("<name>")` naming a
#              shipped vignette
# Run from the package root: Rscript benchmarks/sweep-vignette-idioms.R
# Exits 1 on any hit.

pages <- list.files("vignettes", pattern = "\\.Rmd$", recursive = TRUE)
hits <- 0L

report <- function(check, page, lines, idx) {
  for (i in idx) {
    cat(sprintf("%s  vignettes/%s:%d: %s\n", check, page, i, trimws(lines[i])))
  }
  hits <<- hits + length(idx)
}

chunk_map <- function(lines) {
  # For each line: "prose", "hidden", "shown" (reader-facing chunk body), or
  # "header"/"fence" for the fences themselves.
  kind <- rep("prose", length(lines))
  inside <- FALSE
  shown <- FALSE
  for (i in seq_along(lines)) {
    l <- lines[i]
    if (!inside && grepl("^```\\{r", l)) {
      inside <- TRUE
      shown <- !grepl("(echo|include)\\s*=\\s*FALSE", l)
      kind[i] <- "header"
    } else if (inside && grepl("^```\\s*$", l)) {
      inside <- FALSE
      kind[i] <- "fence"
    } else if (inside) {
      kind[i] <- if (shown) "shown" else "hidden"
    }
  }
  kind
}

core <- c("nestedtune", tidymodels:::core) # the unexported list `library(tidymodels)` attaches
prefix_re <- paste0("\\b(", paste(core, collapse = "|"), ")::")
idiom_re <- paste0(
  "vapply\\(|sapply\\(|lapply\\(|do\\.call\\(|Reduce\\(|Map\\(|<<-|",
  "withCallingHandlers\\(|function\\(|data\\.frame\\(|\\[[A-Za-z_.][A-Za-z0-9_.]*\\$"
)
peek_re <- "[A-Za-z_.][A-Za-z0-9_.]*\\$[A-Za-z_.][A-Za-z0-9_.]*\\[\\[[0-9]+\\]\\]"

for (page in pages) {
  lines <- readLines(file.path("vignettes", page), warn = FALSE)
  kind <- chunk_map(lines)
  shown <- which(kind == "shown")

  # idioms
  report("idioms ", page, lines, shown[grepl(idiom_re, lines[shown])])
  stripped <- gsub(peek_re, "", lines[shown])
  report("idioms ", page, lines, shown[grepl("[[", stripped, fixed = TRUE)])

  # prefix
  report("prefix ", page, lines, shown[grepl(prefix_re, lines[shown])])
  if (length(shown)) {
    lib <- which(grepl("^library\\(", lines) & kind == "shown")
    libs <- sub("^library\\((.*)\\)$", "\\1", lines[lib])
    order_ok <- length(libs) >= 2L &&
      identical(libs[1:2], c("tidymodels", "nestedtune"))
    guard <- grep("requireNamespace|\"tidymodels\"", lines)
    guard_ok <- any(grepl("tidymodels", lines[kind == "hidden"])) &&
      any(grepl("knit_exit", lines)) &&
      length(lib) && min(lib) > max(grep("knit_exit", lines))
    if (!order_ok) {
      cat(sprintf("prefix  vignettes/%s: libraries are %s\n", page, toString(libs)))
      hits <- hits + 1L
    }
    if (!guard_ok) {
      cat(sprintf("prefix  vignettes/%s: no tidymodels guard before the attach\n", page))
      hits <- hits + 1L
    }
  }

  # prose
  prose <- which(kind == "prose")
  text <- gsub("`r[^`]*`", "", lines[prose], perl = TRUE)
  report("prose  ", page, lines, prose[grepl("—", text)])
  report("prose  ", page, lines, prose[grepl("\\bM[0-9][0-9]\\b", text, perl = TRUE)])
  named <- regmatches(text, gregexpr("vignette\\(\"[^\"]*\"\\)", text))
  bad <- vapply(named, function(v) {
    any(!sub("vignette\\(\"(.*)\"\\)", "\\1", v) %in%
      c("nested-cv", "estimate", "results", "tuners"))
  }, logical(1))
  report("prose  ", page, lines, prose[bad])
}

cat(if (hits == 0L) "clean\n" else sprintf("%d hit(s)\n", hits))
quit(status = as.integer(hits > 0L))
