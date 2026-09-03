# Every slot of tune's two control objects is classified on the help page of
# the orchestrator it reaches (M48, AC6): under exactly one of six headings --
# forced, settable as its own argument, refused, passed through, not returned,
# inert.
#
# The classification is read off the rendered help rather than off a list kept
# here, and the slot names come from `formals()` of tune's own functions, so a
# slot tune adds fails here by name until the page classifies it, and a slot
# the page names under two headings fails as the duplicate it is. The section
# writes each heading as bold text opening with the heading word and a colon
# and carrying the slot names in code -- `**Forced: `allow_par`.**` -- and the
# parse is of exactly that shape: a `\strong` node's text up to the colon is
# the heading, its `\code` children are the slots. Prose outside the bold may
# name any slot it likes.

CONTROL_HEADINGS <- c(
  "Forced",
  "Settable as its own argument",
  "Refused",
  "Passed through",
  "Not returned",
  "Inert"
)

# The topic's Rd, from the source tree where there is one and from the
# installed help database under `R CMD check`, where `man/` is not on disk.
help_rd <- function(topic) {
  src <- test_path("..", "..", "man", paste0(topic, ".Rd"))
  if (file.exists(src)) {
    return(tools::parse_Rd(src))
  }
  tools::Rd_db("nestedtune")[[paste0(topic, ".Rd")]]
}

rd_tag <- function(x) attr(x, "Rd_tag")

# The plain text of an Rd node: its character leaves, in order.
rd_text <- function(x) {
  if (is.character(x)) {
    return(paste(x, collapse = ""))
  }
  paste(vapply(x, rd_text, character(1)), collapse = "")
}

# The section is titled for the package the page's tuner lives in: tune on
# the grid and Bayesian pages, finetune on the racing page (M50).
DIFFERENCES_TITLES <- c(
  "Differences from calling tune directly",
  "Differences from calling finetune directly"
)

differences_section <- function(rd) {
  for (node in rd) {
    if (
      identical(rd_tag(node), "\\section") &&
        trimws(rd_text(node[[1L]])) %in% DIFFERENCES_TITLES
    ) {
      return(node[[2L]])
    }
  }
  rlang::abort("no 'Differences from calling ... directly' section")
}

# Every `\strong` node under `x`, in document order.
strong_nodes <- function(x) {
  out <- list()
  walk <- function(node) {
    if (!is.list(node)) {
      return(invisible())
    }
    if (identical(rd_tag(node), "\\strong")) {
      out[[length(out) + 1L]] <<- node
    }
    for (child in node) {
      walk(child)
    }
  }
  walk(x)
  out
}

# heading -> slot names, one entry per bold heading in the order written; a
# heading written twice appears twice, which the assertions below reject.
heading_slots <- function(section) {
  nodes <- strong_nodes(section)
  labels <- vapply(
    nodes,
    function(n) trimws(sub(":.*$", "", rd_text(n))),
    character(1)
  )
  slots <- lapply(nodes, function(n) {
    codes <- Filter(function(e) identical(rd_tag(e), "\\code"), n)
    vapply(codes, rd_text, character(1))
  })
  names(slots) <- labels
  slots
}

expect_classified <- function(topic, control_fn) {
  slots <- names(formals(control_fn))
  # One fact held independently of the derivation: the enumeration is not
  # empty, and the two slots every tune control carries are in it.
  expect_gt(length(slots), 5L)
  expect_true(all(c("allow_par", "event_level") %in% slots))

  buckets <- heading_slots(differences_section(help_rd(topic)))

  # The six headings, each exactly once, and nothing else in bold.
  expect_identical(sort(names(buckets)), sort(CONTROL_HEADINGS))

  # Every slot under exactly one heading, and nothing under a heading that is
  # not a slot.
  placed <- unlist(buckets, use.names = FALSE)
  expect_identical(setdiff(placed, slots), character(0))
  expect_identical(setdiff(slots, placed), character(0))
  for (slot in slots) {
    n <- sum(vapply(buckets, function(b) slot %in% b, logical(1)))
    expect_identical(n, 1L, info = slot)
  }
  invisible(buckets)
}

test_that("every control_grid() slot sits under one heading on nested_tune_grid()'s page", {
  buckets <- expect_classified("nested_tune_grid", tune::control_grid)
  # The forced slot is the one the package overwrites on both tuners.
  expect_identical(buckets[["Forced"]], "allow_par")
  expect_identical(buckets[["Settable as its own argument"]], "event_level")
})

test_that("every control_bayes() slot sits under one heading on nested_tune_bayes()'s page", {
  buckets <- expect_classified("nested_tune_bayes", tune::control_bayes)
  expect_setequal(buckets[["Forced"]], c("allow_par", "seed"))
  expect_identical(buckets[["Settable as its own argument"]], "event_level")
  # The three slots issue #35 asked for pass through.
  expect_true(all(
    c("no_improve", "uncertain", "time_limit") %in% buckets[["Passed through"]]
  ))
})

test_that("every control_race() slot sits under one heading on the racing page (M50, AC7)", {
  skip_if_not_installed("finetune")
  buckets <- expect_classified("nested_tune_race", finetune::control_race)
  expect_identical(buckets[["Forced"]], "allow_par")
  expect_identical(buckets[["Settable as its own argument"]], "event_level")
  expect_identical(buckets[["Refused"]], character(0))
  # The racing slots pass through, as the criterion names them.
  expect_true(all(
    c("burn_in", "alpha", "num_ties", "randomize", "verbose_elim") %in%
      buckets[["Passed through"]]
  ))
  expect_setequal(
    buckets[["Not returned"]],
    c("extract", "save_pred", "save_workflow")
  )
  expect_identical(buckets[["Inert"]], "backend_options")
})

test_that("every control_sim_anneal() slot sits under one heading on nested_tune_sim_anneal()'s page (M51, AC6)", {
  skip_if_not_installed("finetune")
  buckets <- expect_classified(
    "nested_tune_sim_anneal",
    finetune::control_sim_anneal
  )
  expect_identical(buckets[["Forced"]], "allow_par")
  expect_identical(buckets[["Settable as its own argument"]], "event_level")
  expect_identical(buckets[["Refused"]], character(0))
  # The annealing slots pass through, `time_limit` and `verbose_iter` among
  # them as the criterion names.
  expect_true(all(
    c(
      "no_improve",
      "restart",
      "radius",
      "flip",
      "cooling_coef",
      "time_limit",
      "verbose_iter"
    ) %in%
      buckets[["Passed through"]]
  ))
  expect_setequal(
    buckets[["Not returned"]],
    c("extract", "save_pred", "save_workflow", "save_history")
  )
  expect_identical(buckets[["Inert"]], "backend_options")

  # The two caveats the criterion asks the page to carry: the wall-clock
  # stop's IP2 caveat, and the log `verbose_iter` prints from every fold.
  txt <- gsub("\\s+", " ", rd_text(help_rd("nested_tune_sim_anneal")))
  expect_match(
    txt,
    "wall-clock stop makes the candidate set depend on the machine",
    fixed = TRUE
  )
  expect_match(txt, "from every fold of a serial run", fixed = TRUE)
})

test_that("the racing page says what the recorded grid is, and what `n` is (AC7)", {
  # Whitespace collapsed: the Rd wraps its lines, and the installed database
  # under `R CMD check` wraps them where the source file did not.
  txt <- gsub("\\s+", " ", rd_text(help_rd("nested_tune_race")))
  # The two records, each named for what it is: the grid as the design
  # offered, `n` as the resamples each candidate was scored on.
  expect_match(
    txt,
    "is the design the race was offered, exactly as given",
    fixed = TRUE
  )
  expect_match(
    txt,
    "n is the number of inner resamples each candidate was scored on",
    fixed = TRUE
  )
})

test_that("the heading parse can see a slot classified twice, and one left out", {
  # Discrimination: the assertions above report nothing, which is also what a
  # parse that read no heading would report. A planted section with one slot
  # under two headings and one slot under none is seen as exactly that.
  rd <- tools::parse_Rd(textConnection(paste0(
    "\\name{x}\\title{x}",
    "\\section{Differences from calling tune directly}{",
    "Prose naming \\code{verbose} outside any heading.",
    "\\strong{Forced: \\code{allow_par}.} Text. ",
    "\\strong{Refused: none.} Text. ",
    "\\strong{Inert: \\code{allow_par}, \\code{pkgs}.} Text.",
    "}"
  )))
  buckets <- heading_slots(differences_section(rd))
  expect_identical(names(buckets), c("Forced", "Refused", "Inert"))
  expect_identical(buckets[["Forced"]], "allow_par")
  expect_identical(buckets[["Refused"]], character(0))
  expect_identical(buckets[["Inert"]], c("allow_par", "pkgs"))
  placed <- unlist(buckets, use.names = FALSE)
  expect_identical(placed[duplicated(placed)], "allow_par")
  expect_false("verbose" %in% placed)
})
