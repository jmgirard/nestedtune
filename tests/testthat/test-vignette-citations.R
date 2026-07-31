# The documentation's citations and the reference shelf cannot drift apart.
#
# M25 put author-year citations into `vignettes/nested-cv.Rmd` and into the
# roxygen on `collect_metrics.nested_results()` and `nested_final_fit()`, for
# claims whose evidence lives in `cairn/references/`. Those surfaces are edited
# by different hands at different times: prose when the guide is rewritten, the
# shelf when a source is ingested. Nothing but this file connects them, so a
# citation can lose its page, or a page can be renamed or emptied, with every
# other check green.
#
# What is pinned, stated at the level the code actually reaches:
#
#   1. every author-year citation in the vignette prose -- narrative
#      (`Varma and Simon (2006)`) or parenthetical (`(Bayle et al., 2026)`) --
#      has an entry in the vignette's `## References` section
#   2. every `## References` entry parses into a surname and a year
#   3. every `## References` entry has a shelf page that is non-empty and whose
#      own `**Citation.**` line names that surname and year
#   4. every `## References` entry is cited somewhere in the prose
#   5. every author-year citation in `R/` roxygen resolves to a shelf page the
#      same way
#
# Three deliberate limits, disclosed rather than papered over:
#
# * Direction 5 reads roxygen *citations*, not the `@references` entries
#   themselves -- a reference-list line (`Bengio, Y., & Grandvalet, Y. (2004).
#   ...`) does not match the citation matcher, by design, since initials are not
#   surnames. So an orphaned `@references` entry whose source is never cited in
#   the prose above it is not detected. The direction that matters is covered:
#   a citation whose page is renamed or deleted turns this red.
#
# * The matcher reads any capitalized token followed by a year, so prose like
#   "the Appendix (2019)" would turn it red. That direction is chosen on
#   purpose: a false red is a sentence to reword or an exemption to add, while
#   the opposite error is a citation that quietly loses its evidence. Widening
#   the matcher to exclude non-names would mean enumerating what a name is not,
#   which is the failure mode guard doctrine section 3 describes.
# * Direction 4 is not applied to roxygen. An `@references` block conventionally
#   lists background a topic rests on, whether or not each entry is named in the
#   prose above it, so requiring a mention there would fight the format.
#
# Where this actually runs: `devtools::test()` in the source tree, and nowhere
# else. Under `R CMD check` the suite executes from `<pkg>.Rcheck/tests/testthat`,
# so every `test_path("..", "..", ...)` here resolves outside the source tree and
# all of these tests skip -- `vignettes/`, `R/` and `cairn/` alike, whatever
# `.Rbuildignore` says about any of them. Verified by probing both layouts, not
# assumed. That means CI does not exercise this guard; the source tree is where
# the vignette and the shelf are edited, which is where it needs to fire. The
# separate `dir.exists(shelf_dir())` guards are kept only so a failure reads as
# "no shelf" rather than as an empty result.

vignette_file <- function() {
  test_path("..", "..", "vignettes", "nested-cv.Rmd")
}

shelf_dir <- function() {
  test_path("..", "..", "cairn", "references")
}

r_dir <- function() {
  test_path("..", "..", "R")
}

# A surname token: optional lowercase particles, then the capitalized part.
# `van der Laan` parses whole rather than silently becoming `Laan`.
SURNAME <- paste0(
  "(?:(?:van|von|de|der|den|di|da|del|dos|du|la|le|el)\\s+)*",
  "[A-Z][A-Za-z’'-]+"
)

# A citekey is the surname stripped to letters, lowercased, plus the year:
# `van der Laan` + 2011 -> `vanderlaan2011`. Applied identically to prose and to
# entries, so the two sides cannot disagree about what a key is.
citekey <- function(surname, year) {
  paste0(tolower(gsub("[^A-Za-z]", "", surname)), year)
}

# Prose with the R removed. Fenced chunks go first, then inline `r ...` spans:
# both are code, and a year inside either is not a citation. The header used to
# claim only the first, which was the gap this line closes.
strip_code <- function(lines) {
  fence <- grepl("^```", lines)
  inside <- cumsum(fence) %% 2L == 1L
  lines[inside | fence] <- ""
  gsub("`r[^`]*`", "", lines, perl = TRUE)
}

# The vignette split at its `## References` heading. A heading that is renamed,
# absent, or duplicated makes this return `heading = FALSE`, which the first
# test asserts on directly -- otherwise every later test would skip itself into
# silence and the rename would ship green.
vignette_halves <- function(path) {
  lines <- readLines(path, warn = FALSE)
  at <- grep("^##\\s+References\\s*$", lines)
  if (length(at) != 1L) {
    return(list(prose = character(), entries = character(), heading = FALSE))
  }
  list(
    prose = strip_code(lines[seq_len(at - 1L)]),
    entries = paragraphs(lines[seq(at + 1L, length(lines))]),
    heading = TRUE
  )
}

# Blank-line-separated paragraphs, each joined into one string, so a wrapped
# entry is read whole and an anchor cannot stop at the line break before the
# year.
paragraphs <- function(lines) {
  group <- cumsum(lines == "")
  out <- vapply(
    split(lines, group),
    function(p) trimws(paste(p[p != ""], collapse = " ")),
    character(1),
    USE.NAMES = FALSE
  )
  out[nzchar(out)]
}

# The author list of a citation, capturing the FIRST surname, which is what the
# citekey is built from. Covers `Varma and Simon`, `Bayle et al.`, and the
# three-author `Gauran, Ombao and Yu` -- that last form is why the comma-list
# alternative is here: without it the scan starts at the second surname and
# builds a key nobody will ever name a page.
AUTHORS <- paste0(
  "(", SURNAME, ")",
  "(?:\\s+et\\s+al\\.",
  "|(?:\\s*,\\s*", SURNAME, ")*(?:\\s*(?:,\\s*)?(?:&|and)\\s+", SURNAME, ")?",
  ")"
)

NARRATIVE <- paste0(AUTHORS, "\\s*\\((\\d{4})\\)")

PARENTHETICAL <- paste0(AUTHORS, "\\s*,\\s*(\\d{4})")

# Every citekey cited in some text, in either rendering. Parentheticals are
# found by scanning each parenthesized span, so a leading `see ` or `e.g., `
# inside the parentheses does not hide the citation.
citekeys_in <- function(text) {
  text <- gsub("[*_`]", "", paste(text, collapse = " "))

  keys <- character()
  collect <- function(hay, pattern) {
    hits <- regmatches(hay, gregexpr(pattern, hay, perl = TRUE))[[1]]
    if (length(hits) == 0L) {
      return(character())
    }
    citekey(
      sub(paste0("^", pattern, "$"), "\\1", hits, perl = TRUE),
      sub(paste0("^", pattern, "$"), "\\2", hits, perl = TRUE)
    )
  }

  keys <- c(keys, collect(text, NARRATIVE))
  spans <- regmatches(text, gregexpr("\\([^()]*\\)", text, perl = TRUE))[[1]]
  for (span in spans) {
    keys <- c(keys, collect(span, PARENTHETICAL))
  }
  unique(keys)
}

# One reference entry's citekey, or NULL when it does not parse.
entry_citekey <- function(entry) {
  plain <- gsub("[*_`]", "", entry)
  surname <- sub(paste0("^\\s*(", SURNAME, "),.*$"), "\\1", plain, perl = TRUE)
  year <- sub("^.*?\\((\\d{4})\\).*$", "\\1", plain)
  if (identical(surname, plain) || identical(year, plain)) {
    return(NULL)
  }
  citekey(surname, year)
}

# The shelf page backing a citekey, or NULL. A single-letter disambiguating
# suffix resolves -- the shelf's own convention (`stone1974a`/`stone1974b`,
# `vabalas2019a`). Where a suffixed pair exists, either member satisfies the
# key, which the caller checks by content rather than by name.
shelf_pages <- function(key, dir) {
  keys <- sub("\\.md$", "", list.files(dir, pattern = "\\.md$"))
  keys[keys == key | grepl(paste0("^", key, "[a-z]$"), keys)]
}

# Does some shelf page for this key actually name this source? Filename
# existence is not evidence: an emptied or repurposed page keeps its name. The
# page's own `**Citation.**` block must carry the surname and the year.
shelf_backs <- function(key, surname, year, dir) {
  for (page in shelf_pages(key, dir)) {
    text <- readLines(file.path(dir, paste0(page, ".md")), warn = FALSE)
    if (length(text) == 0L) {
      next
    }
    at <- grep("\\*\\*Citation\\.\\*\\*", text)
    if (length(at) == 0L) {
      next
    }
    # The citation PARAGRAPH, not a fixed line window. A window overruns into
    # `**Provenance.**`, whose `sources/<citekey>.pdf` path contains the surname
    # -- so every page matched its own key no matter what its citation said, and
    # a repurposed page passed. Stop at the blank line.
    tail_lines <- text[seq(at[1], length(text))]
    stop_at <- which(!nzchar(trimws(tail_lines)))
    block <- paste(
      tail_lines[seq_len(if (length(stop_at)) stop_at[1] - 1L else length(tail_lines))],
      collapse = " "
    )
    bare <- gsub("[^A-Za-z]", "", surname)
    if (grepl(bare, gsub("[^A-Za-z]", "", block), ignore.case = TRUE) &&
        grepl(year, block, fixed = TRUE)) {
      return(TRUE)
    }
  }
  FALSE
}

entry_surname_year <- function(entry) {
  plain <- gsub("[*_`]", "", entry)
  surname <- sub(paste0("^\\s*(", SURNAME, "),.*$"), "\\1", plain, perl = TRUE)
  year <- sub("^.*?\\((\\d{4})\\).*$", "\\1", plain)
  list(surname = surname, year = year)
}

# Roxygen comment text across R/, with the `#' ` markers removed.
roxygen_text <- function(dir) {
  files <- list.files(dir, pattern = "\\.R$", full.names = TRUE)
  out <- character()
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    out <- c(out, sub("^#'\\s?", "", lines[grepl("^#'", lines)]))
  }
  out
}

test_that("the vignette has exactly one References section, with entries", {
  skip_if_not(file.exists(vignette_file()), "vignette absent")

  halves <- vignette_halves(vignette_file())

  expect_true(halves$heading)
  expect_gt(length(halves$entries), 0L)
})

test_that("every References entry parses into a surname and a year", {
  skip_if_not(file.exists(vignette_file()), "vignette absent")

  halves <- vignette_halves(vignette_file())
  skip_if(length(halves$entries) == 0L, "no References entries")

  unparsed <- halves$entries[vapply(
    halves$entries,
    function(e) is.null(entry_citekey(e)),
    logical(1)
  )]

  expect_equal(unparsed, character(0))
})

test_that("every source cited in the vignette prose is listed in References", {
  skip_if_not(file.exists(vignette_file()), "vignette absent")

  halves <- vignette_halves(vignette_file())
  cited <- citekeys_in(halves$prose)

  # Not a skip: the vignette makes cited claims, so an empty result means the
  # matcher stopped seeing them, which is the failure this guard exists for.
  expect_gt(length(cited), 0L)

  listed <- unlist(lapply(halves$entries, entry_citekey))
  expect_equal(setdiff(cited, listed), character(0))
})

test_that("every References entry is backed by a shelf page naming it", {
  skip_if_not(dir.exists(shelf_dir()), "cairn/ absent (built package)")
  skip_if_not(file.exists(vignette_file()), "vignette absent")

  halves <- vignette_halves(vignette_file())
  skip_if(length(halves$entries) == 0L, "no References entries")

  unbacked <- character()
  for (entry in halves$entries) {
    key <- entry_citekey(entry)
    if (is.null(key)) {
      next # reported by the parse test above, not misattributed here
    }
    parts <- entry_surname_year(entry)
    if (!shelf_backs(key, parts$surname, parts$year, shelf_dir())) {
      unbacked <- c(unbacked, key)
    }
  }

  expect_equal(unbacked, character(0))
})

test_that("every References entry is cited somewhere in the vignette prose", {
  skip_if_not(file.exists(vignette_file()), "vignette absent")

  halves <- vignette_halves(vignette_file())
  skip_if(length(halves$entries) == 0L, "no References entries")

  cited <- citekeys_in(halves$prose)
  listed <- unlist(lapply(halves$entries, entry_citekey))

  expect_equal(setdiff(listed, cited), character(0))
})

test_that("every source cited in R/ roxygen is backed by a shelf page", {
  skip_if_not(dir.exists(shelf_dir()), "cairn/ absent (built package)")
  skip_if_not(dir.exists(r_dir()), "R/ absent")

  text <- roxygen_text(r_dir())
  keys <- citekeys_in(text)
  skip_if(length(keys) == 0L, "no author-year citations in roxygen")

  unbacked <- character()
  for (key in keys) {
    surname <- sub("[0-9]{4}$", "", key)
    year <- sub("^.*([0-9]{4})$", "\\1", key)
    if (!shelf_backs(key, surname, year, shelf_dir())) {
      unbacked <- c(unbacked, key)
    }
  }

  expect_equal(unbacked, character(0))
})
