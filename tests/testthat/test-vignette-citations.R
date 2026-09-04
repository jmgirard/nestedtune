# The documentation's citations and the reference shelf cannot drift apart.
#
# M25 put author-year citations into the vignette prose and into the roxygen
# on `collect_metrics.nested_results()` and `nested_final_fit()`, for claims
# whose evidence lives in `cairn/references/`. Those surfaces are edited by
# different hands at different times: prose when a page is rewritten, the shelf
# when a source is ingested. Nothing but this file connects them, so a citation
# can lose its page, or a page can be renamed or emptied, with every other
# check green.
#
# What is pinned, for EVERY `.Rmd` under `vignettes/`, subdirectories included
# (so a site-only article under `vignettes/articles/` is held to the same
# rules as a CRAN vignette), stated at the level the code actually reaches:
#
#   1. a page has at most one `## References` heading
#   2. every author-year citation in the page's prose -- narrative
#      (`Varma and Simon (2006)`) or parenthetical (`(Bayle et al., 2026)`) --
#      has an entry in that page's `## References` section
#   3. every `## References` entry parses into a surname and a year
#   4. every `## References` entry has a shelf page that is non-empty and whose
#      own `**Citation.**` line names that surname and year
#   5. every `## References` entry is cited somewhere in that page's prose
#   6. every author-year citation in `R/` roxygen resolves to a shelf page the
#      same way
#   7. the prose-numeral rule: once fenced chunks, every backtick-quoted span,
#      the YAML header and the `## References` section are removed, every
#      paragraph that still contains a digit also contains an author-year
#      citation -- so a number in the prose is either produced by the page's
#      own code (inline R, quoted code) or backed by a cited source, never
#      typed in from memory
#
# A page with no citation and no References section passes rules 1-5: it makes
# no cited claim and lists nothing. A page with one but not the other fails --
# a citation with no section fails rule 2, a section with no citation rule 5.
#
# Each rule is one expectation function, `expect_<rule>()`, applied to a list
# of pages. The real tree is checked with it, and the same function is shown
# to go RED on a planted fixture in a temporary directory (`expect_failure()`),
# so a rule that stopped seeing its defect class cannot pass green here. The
# fixtures carry their own one-page shelf, so they run under `R CMD check`
# too, where the real-tree tests skip (below).
#
# Three deliberate limits, disclosed rather than papered over:
#
# * Rule 6 reads roxygen *citations*, not the `@references` entries
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
# * Rule 5 is not applied to roxygen. An `@references` block conventionally
#   lists background a topic rests on, whether or not each entry is named in the
#   prose above it, so requiring a mention there would fight the format.
#
# Where the real-tree tests actually run: `devtools::test()` in the source
# tree, and nowhere else. Under `R CMD check` the suite executes from
# `<pkg>.Rcheck/tests/testthat`, so every `test_path("..", "..", ...)` here
# resolves outside the source tree and those tests skip -- `vignettes/`, `R/`
# and `cairn/` alike, whatever `.Rbuildignore` says about any of them.
# Verified by probing both layouts, not assumed. The source tree is where the
# pages and the shelf are edited, which is where the guard needs to fire; the
# fixture tests are what CI exercises.

vignettes_dir <- function() {
  test_path("..", "..", "vignettes")
}

shelf_dir <- function() {
  test_path("..", "..", "cairn", "references")
}

r_dir <- function() {
  test_path("..", "..", "R")
}

# Every page under a vignettes directory, one level or many deep. The call is
# the one the milestone fixed, so a later page under `vignettes/articles/` is
# enumerated by the same line a CRAN vignette is.
vignette_pages <- function(dir) {
  list.files(dir, pattern = "\\.Rmd$", recursive = TRUE)
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

# The YAML header blanked: the lines from a leading `---` to the next `---`.
# A title or an index entry is not prose.
strip_yaml <- function(lines) {
  if (length(lines) == 0L || !identical(lines[1], "---")) {
    return(lines)
  }
  close <- which(lines == "---")
  if (length(close) < 2L) {
    return(lines)
  }
  lines[seq_len(close[2])] <- ""
  lines
}

# Fenced chunks blanked. A chunk header's `fig.alt` text and a chunk's output
# are code, not prose; a year inside either is not a citation.
strip_fences <- function(lines) {
  fence <- grepl("^```", lines)
  inside <- cumsum(fence) %% 2L == 1L
  lines[inside | fence] <- ""
  lines
}

# Prose with the R removed: fenced chunks, then inline `r ...` spans.
strip_code <- function(lines) {
  lines <- strip_fences(strip_yaml(lines))
  gsub("`r[^`]*`", "", lines, perl = TRUE)
}

# A page split at its `## References` heading. No heading: the whole page is
# prose and there are no entries. More than one heading: `heading = NA`, which
# rule 1 asserts on directly -- otherwise every later rule would read only the
# first section and a duplicated heading would ship green.
page_halves <- function(path) {
  lines <- readLines(path, warn = FALSE)
  at <- grep("^##\\s+References\\s*$", lines)
  if (length(at) > 1L) {
    return(list(prose = character(), entries = character(), heading = NA))
  }
  if (length(at) == 0L) {
    return(list(
      prose = strip_code(lines),
      entries = character(),
      heading = FALSE
    ))
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
  "(",
  SURNAME,
  ")",
  "(?:\\s+et\\s+al\\.",
  "|(?:\\s*,\\s*",
  SURNAME,
  ")*(?:\\s*(?:,\\s*)?(?:&|and)\\s+",
  SURNAME,
  ")?",
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
      tail_lines[seq_len(
        if (length(stop_at)) stop_at[1] - 1L else length(tail_lines)
      )],
      collapse = " "
    )
    bare <- gsub("[^A-Za-z]", "", surname)
    if (
      grepl(bare, gsub("[^A-Za-z]", "", block), ignore.case = TRUE) &&
        grepl(year, block, fixed = TRUE)
    ) {
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

# ---- The rules, one expectation each, over a set of pages -------------------
#
# `pages` is a character vector of paths relative to `dir`, as
# `vignette_pages()` returns them, so a failure names the page the way the
# tree does (`articles/parallel.Rmd`, not a temp path).

# Rule 1: at most one `## References` heading per page.
expect_one_references_heading <- function(pages, dir) {
  doubled <- pages[vapply(
    pages,
    function(p) is.na(page_halves(file.path(dir, p))$heading),
    logical(1)
  )]
  expect_equal(doubled, character(0))
}

# Rule 2: every citation in a page's prose is listed in that page's References.
expect_citations_listed <- function(pages, dir) {
  unlisted <- character()
  for (p in pages) {
    halves <- page_halves(file.path(dir, p))
    if (is.na(halves$heading)) {
      next # rule 1's failure, not misattributed here
    }
    cited <- citekeys_in(halves$prose)
    listed <- unlist(lapply(halves$entries, entry_citekey))
    missing <- setdiff(cited, listed)
    if (length(missing)) {
      unlisted <- c(unlisted, paste0(p, ": ", missing))
    }
  }
  expect_equal(unlisted, character(0))
}

# Rule 3: every References entry parses into a surname and a year.
expect_entries_parse <- function(pages, dir) {
  unparsed <- character()
  for (p in pages) {
    halves <- page_halves(file.path(dir, p))
    bad <- halves$entries[vapply(
      halves$entries,
      function(e) is.null(entry_citekey(e)),
      logical(1)
    )]
    if (length(bad)) {
      unparsed <- c(unparsed, paste0(p, ": ", bad))
    }
  }
  expect_equal(unparsed, character(0))
}

# Rule 4: every References entry is backed by a shelf page naming it.
expect_entries_backed <- function(pages, dir, shelf) {
  unbacked <- character()
  for (p in pages) {
    halves <- page_halves(file.path(dir, p))
    for (entry in halves$entries) {
      key <- entry_citekey(entry)
      if (is.null(key)) {
        next # rule 3's failure, not misattributed here
      }
      parts <- entry_surname_year(entry)
      if (!shelf_backs(key, parts$surname, parts$year, shelf)) {
        unbacked <- c(unbacked, paste0(p, ": ", key))
      }
    }
  }
  expect_equal(unbacked, character(0))
}

# Rule 5: every References entry is cited somewhere in that page's prose.
expect_entries_cited <- function(pages, dir) {
  uncited <- character()
  for (p in pages) {
    halves <- page_halves(file.path(dir, p))
    if (is.na(halves$heading)) {
      next
    }
    cited <- citekeys_in(halves$prose)
    listed <- unlist(lapply(halves$entries, entry_citekey))
    orphan <- setdiff(listed, cited)
    if (length(orphan)) {
      uncited <- c(uncited, paste0(p, ": ", orphan))
    }
  }
  expect_equal(uncited, character(0))
}

# The prose the numeral rule reads: the page before its `## References`
# heading (or all of it), less the YAML header, the fenced chunks and every
# backtick span -- inline R and quoted code alike, since a digit inside either
# is code, not a claim.
numeral_prose <- function(path) {
  lines <- readLines(path, warn = FALSE)
  at <- grep("^##\\s+References\\s*$", lines)
  if (length(at)) {
    lines <- lines[seq_len(at[1] - 1L)]
  }
  lines <- strip_fences(strip_yaml(lines))
  gsub("`[^`]*`", "", lines, perl = TRUE)
}

# The units the numeral rule reads: blank-line paragraphs, with each list
# item its own unit and its marker removed -- an item's number belongs to the
# item, and a numbered list's `1.` marker is not a claim.
numeral_units <- function(lines) {
  item <- grepl("^\\s*(?:[-*+]|[0-9]+[.)])\\s+", lines, perl = TRUE)
  lines[item] <- sub(
    "^\\s*(?:[-*+]|[0-9]+[.)])\\s+",
    "",
    lines[item],
    perl = TRUE
  )
  group <- cumsum(lines == "" | item)
  out <- vapply(
    split(lines, group),
    function(p) trimws(paste(p[p != ""], collapse = " ")),
    character(1),
    USE.NAMES = FALSE
  )
  out[nzchar(out)]
}

# Rule 7: every paragraph carrying a digit also carries a citation.
expect_numerals_cited <- function(pages, dir) {
  uncited <- character()
  for (p in pages) {
    paras <- numeral_units(numeral_prose(file.path(dir, p)))
    for (para in paras[grepl("[0-9]", paras)]) {
      if (length(citekeys_in(para)) == 0L) {
        uncited <- c(uncited, paste0(p, ": ", substr(para, 1L, 60L)))
      }
    }
  }
  expect_equal(uncited, character(0))
}

# ---- The real tree ----------------------------------------------------------

test_that("the guard enumerates more than one page under vignettes/", {
  skip_if_not(dir.exists(vignettes_dir()), "vignettes/ absent (built package)")

  pages <- vignette_pages(vignettes_dir())

  expect_gt(length(pages), 1L)
})

test_that("some page under vignettes/ makes a cited claim", {
  skip_if_not(dir.exists(vignettes_dir()), "vignettes/ absent (built package)")

  # Not a skip: the documentation makes cited claims, so an empty result means
  # the matcher stopped seeing them, which is the failure this guard exists for.
  pages <- vignette_pages(vignettes_dir())
  cited <- unlist(lapply(pages, function(p) {
    citekeys_in(page_halves(file.path(vignettes_dir(), p))$prose)
  }))

  expect_gt(length(cited), 0L)
})

test_that("every page has at most one References heading", {
  skip_if_not(dir.exists(vignettes_dir()), "vignettes/ absent (built package)")

  expect_one_references_heading(
    vignette_pages(vignettes_dir()),
    vignettes_dir()
  )
})

test_that("every source cited in a page's prose is listed in its References", {
  skip_if_not(dir.exists(vignettes_dir()), "vignettes/ absent (built package)")

  expect_citations_listed(vignette_pages(vignettes_dir()), vignettes_dir())
})

test_that("every References entry parses into a surname and a year", {
  skip_if_not(dir.exists(vignettes_dir()), "vignettes/ absent (built package)")

  expect_entries_parse(vignette_pages(vignettes_dir()), vignettes_dir())
})

test_that("every References entry is backed by a shelf page naming it", {
  skip_if_not(dir.exists(shelf_dir()), "cairn/ absent (built package)")
  skip_if_not(dir.exists(vignettes_dir()), "vignettes/ absent (built package)")

  expect_entries_backed(
    vignette_pages(vignettes_dir()),
    vignettes_dir(),
    shelf_dir()
  )
})

test_that("every References entry is cited somewhere in its page's prose", {
  skip_if_not(dir.exists(vignettes_dir()), "vignettes/ absent (built package)")

  expect_entries_cited(vignette_pages(vignettes_dir()), vignettes_dir())
})

test_that("every paragraph with a digit in a page's prose carries a citation", {
  skip_if_not(dir.exists(vignettes_dir()), "vignettes/ absent (built package)")

  expect_numerals_cited(vignette_pages(vignettes_dir()), vignettes_dir())
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

# ---- Planted fixtures: each rule shown red on the defect it claims to catch --
#
# A temporary `vignettes/` with a one-page shelf beside it. `Somebody (2020)`
# is on that shelf; `Nobody (2021)` is not. Pages are written with the YAML
# header and a setup chunk a real page carries, so the stripping runs over the
# same shape it meets in the tree.

fixture_tree <- function() {
  # A base tempdir removed at the calling block's exit: withr is deliberately
  # not a dependency of this package (`helper-orchestration.R` says why), and
  # `test_that()` evaluates its block as a function body, so `on.exit()`
  # registered in the caller's frame fires at the end of that block.
  root <- tempfile("citation-fixtures-")
  dir.create(root)
  do.call(
    on.exit,
    list(bquote(unlink(.(root), recursive = TRUE)), add = TRUE),
    envir = parent.frame()
  )
  dir.create(file.path(root, "vignettes", "deeper"), recursive = TRUE)
  dir.create(file.path(root, "shelf"))
  writeLines(
    c(
      "# somebody2020 -- a planted shelf page",
      "",
      "**Citation.** Somebody, A. (2020). A planted source. *Journal*, 1, 1.",
      "",
      "**Provenance.** Planted by the test."
    ),
    file.path(root, "shelf", "somebody2020.md")
  )
  root
}

plant_page <- function(root, name, body, references = NULL) {
  lines <- c(
    "---",
    "title: \"A planted page\"",
    "---",
    "",
    "```{r setup, include = FALSE}",
    "knitr::opts_chunk$set(collapse = TRUE)",
    "```",
    "",
    body
  )
  if (!is.null(references)) {
    lines <- c(lines, "", "## References", "", references)
  }
  writeLines(lines, file.path(root, "vignettes", name))
  invisible(name)
}

SOMEBODY <- "Somebody, A. (2020). A planted source. *Journal*, 1, 1."
NOBODY <- "Nobody, B. (2021). A source with no shelf page. *Journal*, 2, 2."

test_that("a page citing and listing a backed source, and a page with neither, pass every rule", {
  root <- fixture_tree()
  dir <- file.path(root, "vignettes")
  plant_page(root, "cited.Rmd", "As Somebody (2020) showed.", SOMEBODY)
  plant_page(root, "plain.Rmd", "A page with no cited claim.")
  pages <- vignette_pages(dir)

  expect_setequal(pages, c("cited.Rmd", "plain.Rmd"))
  expect_success(expect_one_references_heading(pages, dir))
  expect_success(expect_citations_listed(pages, dir))
  expect_success(expect_entries_parse(pages, dir))
  expect_success(expect_entries_backed(pages, dir, file.path(root, "shelf")))
  expect_success(expect_entries_cited(pages, dir))
})

test_that("a citation with no shelf page turns the shelf rule red", {
  root <- fixture_tree()
  dir <- file.path(root, "vignettes")
  plant_page(root, "unbacked.Rmd", "As Nobody (2021) showed.", NOBODY)
  pages <- vignette_pages(dir)

  expect_failure(
    expect_entries_backed(pages, dir, file.path(root, "shelf")),
    "unbacked.Rmd: nobody2021"
  )
  # The other rules stay silent: the entry is listed, parses, and is cited.
  expect_success(expect_citations_listed(pages, dir))
  expect_success(expect_entries_parse(pages, dir))
  expect_success(expect_entries_cited(pages, dir))
})

test_that("a References entry no prose cites turns the cited rule red", {
  root <- fixture_tree()
  dir <- file.path(root, "vignettes")
  plant_page(
    root,
    "orphan.Rmd",
    "As Somebody (2020) showed.",
    c(SOMEBODY, "", NOBODY)
  )
  pages <- vignette_pages(dir)

  expect_failure(expect_entries_cited(pages, dir), "orphan.Rmd: nobody2021")
  expect_success(expect_citations_listed(pages, dir))
})

test_that("a References section with no citation turns the cited rule red", {
  root <- fixture_tree()
  dir <- file.path(root, "vignettes")
  plant_page(root, "listed-only.Rmd", "A page that cites nothing.", SOMEBODY)
  pages <- vignette_pages(dir)

  expect_failure(
    expect_entries_cited(pages, dir),
    "listed-only.Rmd: somebody2020"
  )
  expect_success(expect_citations_listed(pages, dir))
})

test_that("a citation with no References section turns the listed rule red", {
  root <- fixture_tree()
  dir <- file.path(root, "vignettes")
  plant_page(root, "cited-only.Rmd", "As Somebody (2020) showed.")
  pages <- vignette_pages(dir)

  expect_failure(
    expect_citations_listed(pages, dir),
    "cited-only.Rmd: somebody2020"
  )
  expect_success(expect_entries_cited(pages, dir))
})

test_that("a duplicated References heading turns the heading rule red", {
  root <- fixture_tree()
  dir <- file.path(root, "vignettes")
  plant_page(
    root,
    "doubled.Rmd",
    "As Somebody (2020) showed.",
    c(SOMEBODY, "", "## References", "", SOMEBODY)
  )
  pages <- vignette_pages(dir)

  expect_failure(expect_one_references_heading(pages, dir), "doubled.Rmd")
})

test_that("a defect one directory deep is found by the same rule", {
  root <- fixture_tree()
  dir <- file.path(root, "vignettes")
  plant_page(root, "cited.Rmd", "As Somebody (2020) showed.", SOMEBODY)
  plant_page(
    root,
    file.path("deeper", "cited-only.Rmd"),
    "As Somebody (2020) showed."
  )
  pages <- vignette_pages(dir)

  expect_setequal(pages, c("cited.Rmd", "deeper/cited-only.Rmd"))
  expect_failure(
    expect_citations_listed(pages, dir),
    "deeper/cited-only.Rmd: somebody2020"
  )
})

test_that("an uncited digit in a plain paragraph turns the numeral rule red", {
  root <- fixture_tree()
  dir <- file.path(root, "vignettes")
  plant_page(root, "digit.Rmd", "The bias was 4.2 points on null data.")
  pages <- vignette_pages(dir)

  expect_failure(
    expect_numerals_cited(pages, dir),
    "digit.Rmd: The bias was 4.2"
  )
  # A digit is not a citation, so the citation rules stay silent on it.
  expect_success(expect_citations_listed(pages, dir))
})

test_that("an uncited digit in a list item turns the numeral rule red", {
  root <- fixture_tree()
  dir <- file.path(root, "vignettes")
  plant_page(
    root,
    "list.Rmd",
    c(
      "Two points:",
      "",
      "1. a point with no number, under a numbered marker",
      "- 41,121 hospital visits"
    )
  )
  pages <- vignette_pages(dir)

  expect_failure(expect_numerals_cited(pages, dir), "list.Rmd: 41,121 hospital")
})

test_that("an uncited digit one directory deep turns the numeral rule red", {
  root <- fixture_tree()
  dir <- file.path(root, "vignettes")
  plant_page(root, "plain.Rmd", "A page with no number.")
  plant_page(root, file.path("deeper", "digit.Rmd"), "It took 20 seconds.")
  pages <- vignette_pages(dir)

  expect_failure(
    expect_numerals_cited(pages, dir),
    "deeper/digit.Rmd: It took 20"
  )
})

test_that("a digit inside a backtick span, or beside a citation, passes the numeral rule", {
  root <- fixture_tree()
  dir <- file.path(root, "vignettes")
  plant_page(
    root,
    "quoted.Rmd",
    c(
      "`mtcars` has `r nrow(mtcars)` rows and the grid has `6` points.",
      "",
      "Predict on `mtcars[1:3, ]` to see the shape."
    )
  )
  plant_page(
    root,
    "cited.Rmd",
    "Somebody (2020) found a bias of 4.2 points on 40 samples.",
    SOMEBODY
  )
  pages <- vignette_pages(dir)

  expect_success(expect_numerals_cited(pages, dir))
})
