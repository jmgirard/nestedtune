# The mori assessment's published wire figures are locked to M26's manifest
# (benchmarks/mori-wire-manifest.json): each document declares the manifest
# figures it cites, and this check fails when a cited figure drifts from the
# manifest at the precision the document prints it (M29 AC2).
#
# `cairn/` and `benchmarks/` are `.Rbuildignore`d, so this file has nothing to
# read when the suite runs from a built tarball and skips there. It runs under
# `devtools::test()` in the source tree, which is where the documents are
# edited in the first place. The working parts live in
# helper-drift-manifest.R so the red-run evidence can drive them directly.

drift_repo_path <- function(...) test_path("..", "..", ...)

test_that("every wire figure the documents cite matches the manifest", {
  manifest_path <- drift_repo_path("benchmarks", "mori-wire-manifest.json")
  docs <- c(
    note = drift_repo_path("cairn", "references", "mori-backend-assessment.md"),
    roadmap = drift_repo_path("cairn", "ROADMAP.md")
  )
  skip_if_not(
    file.exists(manifest_path) && all(file.exists(docs)),
    "repo-only files are absent from a built package"
  )

  figures <- drift_manifest_figures(manifest_path)
  checked <- 0L
  for (doc in names(docs)) {
    result <- drift_failures(docs[[doc]], figures)
    expect_identical(result$failures, character(0),
                     label = sprintf("drift failures in %s", doc))
    checked <- checked + result$checked
  }
  # A bare Rscript harness that skips everything finishes clean having
  # asserted nothing (LESSONS, M14) -- so assert the assertion count: the
  # note declares 9 figures and the ROADMAP row 5.
  expect_gte(checked, 14L)
})

test_that("the check goes red when a cited figure drifts", {
  manifest_path <- drift_repo_path("benchmarks", "mori-wire-manifest.json")
  note_path <- drift_repo_path("cairn", "references", "mori-backend-assessment.md")
  skip_if_not(
    file.exists(manifest_path) && file.exists(note_path),
    "repo-only files are absent from a built package"
  )

  figures <- drift_manifest_figures(manifest_path)
  # Perturb a scratch copy of the note -- never the committed manifest -- in
  # every occurrence, declaration and prose alike, so the drift is the
  # value-vs-manifest kind rather than a missing rendering.
  scratch <- tempfile(fileext = ".md")
  writeLines(
    gsub("941,683", "941,999", readLines(note_path, warn = FALSE), fixed = TRUE),
    scratch
  )
  result <- drift_failures(scratch, figures)
  expect_length(result$failures, 1L)
  expect_match(result$failures, "lean_bundle_bytes.*misses the manifest value")

  # And a rendering that disappears from prose while staying declared is the
  # other failure shape.
  scratch2 <- tempfile(fileext = ".md")
  lines <- readLines(note_path, warn = FALSE)
  decl_at <- grepl("<!-- drift-check:", lines)
  lines[!decl_at] <- gsub("103,109 B", "roughly 100 kB", lines[!decl_at], fixed = TRUE)
  writeLines(lines, scratch2)
  result2 <- drift_failures(scratch2, figures)
  expect_length(result2$failures, 1L)
  expect_match(result2$failures, "mori_bundle_bytes.*not printed")
})
