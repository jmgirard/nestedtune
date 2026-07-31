# The vignette's citations and the reference shelf cannot drift apart.
#
# M25 put author-year citations into `vignettes/nested-cv.Rmd` for claims whose
# evidence lives in `cairn/references/`. Those two surfaces are edited by
# different hands at different times: prose is edited when the guide is
# rewritten, the shelf when a source is ingested. Nothing but this file connects
# them, so a citation can lose its page, or a page can be renamed, with every
# other check green.
#
# Three directions are asserted, because a one-way check is satisfiable by
# deleting whichever side is inconvenient:
#
#   1. every source cited in the prose has an entry in `## References`
#   2. every entry in `## References` resolves to a shelf page
#   3. every entry in `## References` is actually cited in the prose
#
# `cairn/` is `.Rbuildignore`d (`^cairn$`), so this file has nothing to read
# when the suite runs from a built tarball and skips there. It runs under
# `devtools::test()` in the source tree, which is where the vignette and the
# shelf are both edited. That is the same shape as `test-ci-workflows.R`.

vignette_file <- function() {
  test_path("..", "..", "vignettes", "nested-cv.Rmd")
}

shelf_dir <- function() {
  test_path("..", "..", "cairn", "references")
}

# The vignette split at its `## References` heading: prose before, entries
# after. Fenced code chunks are dropped from the prose half -- a chunk is R, not
# a claim, and `(2026)` inside one is not a citation.
vignette_halves <- function(path) {
  lines <- readLines(path, warn = FALSE)

  fence <- grepl("^```", lines)
  inside <- cumsum(fence) %% 2L == 1L
  lines[inside | fence] <- ""

  at <- grep("^##\\s+References\\s*$", lines)
  if (length(at) != 1L) {
    return(list(prose = character(), entries = character(), heading = FALSE))
  }

  entry_lines <- lines[seq(at + 1L, length(lines))]
  # Entries are blank-line separated paragraphs; join each into one string so a
  # wrapped entry is read whole. An anchor that stopped at the line break would
  # miss the year on any entry whose first line ends early.
  group <- cumsum(entry_lines == "")
  paragraphs <- vapply(
    split(entry_lines, group),
    function(p) trimws(paste(p[p != ""], collapse = " ")),
    character(1),
    USE.NAMES = FALSE
  )

  list(
    prose = lines[seq_len(at - 1L)],
    entries = paragraphs[nzchar(paragraphs)],
    heading = TRUE
  )
}

# `Surname (YYYY)`, `Surname and Surname (YYYY)`, `Surname et al. (YYYY)` --
# returning the FIRST surname and the year, which is what a citekey is built
# from. Markdown emphasis and backticks around the surname are tolerated: they
# are decoration on the token, not part of it.
prose_citations <- function(prose) {
  text <- paste(prose, collapse = " ")
  text <- gsub("[*_`]", "", text)

  pattern <- paste0(
    "([A-Z][A-Za-z’'-]+)",
    "(?:\\s+(?:and|&)\\s+[A-Z][A-Za-z’'-]+",
    "|\\s+et\\s+al\\.",
    "|,\\s+[A-Z][A-Za-z’'-]+\\s+(?:and|&)\\s+[A-Z][A-Za-z’'-]+)?",
    "\\s*\\((\\d{4})\\)"
  )

  m <- gregexpr(pattern, text, perl = TRUE)
  hits <- regmatches(text, m)[[1]]
  if (length(hits) == 0L) {
    return(data.frame(surname = character(), year = character()))
  }

  surname <- sub(paste0("^", pattern, "$"), "\\1", hits, perl = TRUE)
  year <- sub(paste0("^", pattern, "$"), "\\2", hits, perl = TRUE)
  unique(data.frame(surname = surname, year = year, stringsAsFactors = FALSE))
}

# An entry's first surname and year. Entries are `Surname, I. I., & Other, A.
# (YYYY). Title...`, so the surname is what precedes the first comma.
entry_key <- function(entry) {
  plain <- gsub("[*_`]", "", entry)
  surname <- sub("^\\s*([A-Z][A-Za-z’'-]+),.*$", "\\1", plain)
  year <- sub("^.*?\\((\\d{4})\\).*$", "\\1", plain)
  if (identical(surname, plain) || identical(year, plain)) {
    return(NULL)
  }
  list(surname = surname, year = year)
}

# The shelf page backing one entry. A citekey is `<surname><year>`, optionally
# with a single-letter disambiguating suffix -- the shelf carries `stone1974a`
# and `stone1974b` for one author-year, and `vabalas2019a` for a citekey with no
# sibling yet. Both forms are accepted deliberately; that is the shelf's own
# naming convention, not a widening to make a failing case pass.
shelf_page <- function(surname, year, dir) {
  stem <- paste0(tolower(surname), year)
  candidates <- list.files(dir, pattern = "\\.md$")
  keys <- sub("\\.md$", "", candidates)
  hit <- keys[keys == stem | grepl(paste0("^", stem, "[a-z]$"), keys)]
  if (length(hit) == 0L) NULL else hit
}

test_that("the vignette has a References section", {
  skip_if_not(file.exists(vignette_file()), "vignette absent (built package)")

  halves <- vignette_halves(vignette_file())

  expect_true(halves$heading)
  expect_gt(length(halves$entries), 0L)
})

test_that("every source cited in the vignette is listed in its References", {
  skip_if_not(file.exists(vignette_file()), "vignette absent (built package)")

  halves <- vignette_halves(vignette_file())
  cited <- prose_citations(halves$prose)
  skip_if(nrow(cited) == 0L, "no author-year citations in the prose")

  listed <- lapply(halves$entries, entry_key)
  listed <- listed[!vapply(listed, is.null, logical(1))]
  listed_keys <- vapply(
    listed,
    function(k) paste0(tolower(k$surname), k$year),
    character(1)
  )

  cited_keys <- paste0(tolower(cited$surname), cited$year)
  missing <- setdiff(cited_keys, listed_keys)

  expect_equal(missing, character(0))
})

test_that("every References entry resolves to a page on the reference shelf", {
  skip_if_not(dir.exists(shelf_dir()), "cairn/ absent (built package)")
  skip_if_not(file.exists(vignette_file()), "vignette absent (built package)")

  halves <- vignette_halves(vignette_file())
  skip_if(length(halves$entries) == 0L, "no References entries")

  unresolved <- character()
  for (entry in halves$entries) {
    key <- entry_key(entry)
    if (is.null(key)) {
      unresolved <- c(unresolved, entry)
      next
    }
    page <- shelf_page(key$surname, key$year, shelf_dir())
    if (is.null(page)) {
      unresolved <- c(unresolved, paste0(tolower(key$surname), key$year))
    }
  }

  expect_equal(unresolved, character(0))
})

test_that("every References entry is cited somewhere in the vignette prose", {
  skip_if_not(file.exists(vignette_file()), "vignette absent (built package)")

  halves <- vignette_halves(vignette_file())
  skip_if(length(halves$entries) == 0L, "no References entries")

  cited <- prose_citations(halves$prose)
  cited_keys <- paste0(tolower(cited$surname), cited$year)

  uncited <- character()
  for (entry in halves$entries) {
    key <- entry_key(entry)
    if (is.null(key)) {
      next
    }
    stem <- paste0(tolower(key$surname), key$year)
    if (!stem %in% cited_keys) {
      uncited <- c(uncited, stem)
    }
  }

  expect_equal(uncited, character(0))
})
