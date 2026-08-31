# The drift check's working parts (test-drift-manifest.R), in a helper so the
# red-run evidence can exercise the same code path against a scratch copy.
#
# The manifest is parsed by regex over its committed pretty-printed shape --
# one `"name":` line and one `"value":` line per figure -- rather than with a
# JSON package, for the same reason test-ci-workflows.R reads YAML by
# indentation: `jsonlite` is not a dependency of this package, and the parse
# fails loudly (stopifnot below) if the file is ever reformatted.

drift_manifest_figures <- function(path) {
  lines <- readLines(path, warn = FALSE)
  name_lines <- grep('"name":', lines, value = TRUE)
  value_lines <- grep('"value":', lines, value = TRUE)
  stopifnot(length(name_lines) > 0, length(name_lines) == length(value_lines))
  names <- sub('.*"name": *"([^"]*)".*', "\\1", name_lines)
  values <- as.numeric(sub('.*"value": *([-0-9.eE+]+).*', "\\1", value_lines))
  stopifnot(!anyNA(values))
  stats::setNames(values, names)
}

# A document declares the manifest figures it cites in one comment line:
#   <!-- drift-check: name=rendering@N|rendering; name=rendering -->
# `@N` declares how many times the rendering occurs in the document body
# (default 1); the check requires the exact count, so a drifted duplicate --
# one occurrence of a twice-printed figure edited away from the manifest --
# still goes red instead of hiding behind the surviving occurrence.
# Returns a named list of data frames (rendering, count), or NULL when the
# document carries no declaration.
drift_declared_renderings <- function(lines) {
  decl <- grep("<!-- drift-check:", lines, value = TRUE)
  if (length(decl) == 0) {
    return(NULL)
  }
  stopifnot(length(decl) == 1)
  body <- sub(".*<!-- drift-check: *", "", decl)
  body <- sub(" *-->.*", "", body)
  entries <- strsplit(body, "; *")[[1]]
  parts <- regmatches(entries, regexec("^([A-Za-z0-9_]+)=(.+)$", entries))
  stopifnot(all(lengths(parts) == 3L))
  stats::setNames(
    lapply(parts, function(p) {
      renderings <- strsplit(p[[3]], "|", fixed = TRUE)[[1]]
      count <- rep(1L, length(renderings))
      at <- grepl("@", renderings, fixed = TRUE)
      count[at] <- as.integer(sub(".*@", "", renderings[at]))
      stopifnot(!anyNA(count), count >= 1L)
      data.frame(rendering = sub("@[0-9]+$", "", renderings), count = count)
    }),
    vapply(parts, `[[`, "", 2L)
  )
}

# A rendering is compared at the precision the document prints it: the
# tolerance is half a unit in the last printed decimal place, scaled by the
# unit suffix. "941.7 kB" tolerates 50 B; "524 B" and "941,683 B" are exact
# for integers; "9.13" tolerates 0.005.
drift_rendering_value <- function(rendering) {
  num <- rendering
  unit <- 1
  if (grepl(" kB$", num)) {
    unit <- 1000
    num <- sub(" kB$", "", num)
  } else if (grepl(" B$", num)) {
    num <- sub(" B$", "", num)
  }
  num <- gsub(",", "", num, fixed = TRUE)
  decimals <- if (grepl(".", num, fixed = TRUE)) {
    nchar(sub(".*\\.", "", num))
  } else {
    0L
  }
  printed <- suppressWarnings(as.numeric(num))
  stopifnot(!is.na(printed))
  c(printed = printed * unit, tol = 0.5 * 10^(-decimals) * unit)
}

# The check proper. Enumerates from the declaration (never parses prose for
# what counts as a figure); a declared name the manifest lacks, a declared
# rendering printed a different number of times than declared, and a
# rendering that misses the manifest value at its printed precision are each
# a failure. The declaration line itself is excluded from the occurrence
# count, or every rendering would find itself.
drift_failures <- function(doc_path, figures) {
  lines <- readLines(doc_path, warn = FALSE)
  decl <- drift_declared_renderings(lines)
  if (is.null(decl)) {
    return(list(failures = "no drift-check declaration", checked = 0L))
  }
  body <- paste(
    grep("<!-- drift-check:", lines, value = TRUE, invert = TRUE),
    collapse = "\n"
  )
  failures <- character()
  checked <- 0L
  for (nm in names(decl)) {
    if (!nm %in% names(figures)) {
      failures <- c(failures, sprintf("%s: not a manifest figure", nm))
      next
    }
    entry <- decl[[nm]]
    for (i in seq_len(nrow(entry))) {
      rendering <- entry$rendering[[i]]
      expected <- entry$count[[i]]
      checked <- checked + 1L
      hits <- gregexpr(rendering, body, fixed = TRUE)[[1]]
      found <- if (hits[[1]] == -1L) 0L else length(hits)
      if (found != expected) {
        failures <- c(
          failures,
          sprintf(
            "%s: rendering '%s' printed %d time(s) against %d declared",
            nm,
            rendering,
            found,
            expected
          )
        )
        next
      }
      rv <- drift_rendering_value(rendering)
      if (abs(rv[["printed"]] - figures[[nm]]) > rv[["tol"]]) {
        failures <- c(
          failures,
          sprintf(
            "%s: '%s' misses the manifest value %s at its printed precision",
            nm,
            rendering,
            format(figures[[nm]])
          )
        )
      }
    }
  }
  list(failures = failures, checked = checked)
}
