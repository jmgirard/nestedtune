# The publishing job needs a git working tree it does not create by itself.
#
# `JamesIves/github-pages-deploy-action` runs `git config user.name` inside the
# workspace before it does anything else, so a job that only unpacks an artifact
# into an otherwise empty runner directory dies with `fatal: not in a git
# directory`. That is what the first run of `pkgdown.yaml` on the default branch
# did: every pull-request run before it was green because the job's `if:` guard
# skips `deploy` off that branch, so the step had never once executed.
#
# `.github/` is `.Rbuildignore`d, so this file has nothing to read when the suite
# runs from a built tarball and skips there. It runs under `devtools::test()` in
# the source tree, which is where a workflow is edited in the first place.

workflow_path <- function(name) {
  test_path("..", "..", ".github", "workflows", name)
}

# The `uses:` values of one job's steps, in the order the job runs them.
#
# Read by indentation rather than with a YAML parser, because `yaml` is not a
# dependency of this package and adding one to assert a property of two lines
# would cost more than the check is worth. The boundary is findable this way
# only below `jobs:`, where job names are the sole keys at two-space indent
# carrying no value -- above it, `on:`'s `push:` and `pull_request:` look
# identical, which is why the search starts there and not at line one.
job_uses <- function(path, job) {
  lines <- readLines(path, warn = FALSE)

  jobs_at <- grep("^jobs:\\s*$", lines)
  headers <- grep("^  [A-Za-z0-9_-]+:\\s*$", lines)
  headers <- headers[headers > jobs_at[[1]]]

  start <- headers[lines[headers] == paste0("  ", job, ":")]
  if (length(start) != 1L) {
    return(NULL)
  }

  later <- headers[headers > start]
  end <- if (length(later)) later[[1]] - 1L else length(lines)

  block <- lines[start:end]
  hits <- grep("^\\s*(- )?uses:\\s*\\S+", block, value = TRUE)
  trimws(sub("^\\s*(- )?uses:\\s*", "", hits))
}

test_that("the pkgdown deploy job checks out before it deploys", {
  path <- workflow_path("pkgdown.yaml")
  skip_if_not(
    file.exists(path),
    "workflow sources are not in the built package"
  )

  uses <- job_uses(path, "deploy")
  expect_false(is.null(uses))

  # A block boundary that ran past the job would sweep in `build`'s own
  # checkout and let the assertion below pass over a deploy job that has none.
  # This is what makes the ordering check mean what it says.
  expect_false(any(grepl("upload-artifact", uses)))

  checkout <- grep("^actions/checkout", uses)
  deploy <- grep("github-pages-deploy-action", uses)

  expect_length(deploy, 1L)
  expect_gte(length(checkout), 1L)
  expect_lt(checkout[[1]], deploy[[1]])
})

test_that("job_uses() reads a job's steps in order", {
  path <- workflow_path("pkgdown.yaml")
  skip_if_not(
    file.exists(path),
    "workflow sources are not in the built package"
  )

  uses <- job_uses(path, "build")

  expect_match(uses[[1]], "^actions/checkout")
  expect_true(any(grepl("^actions/upload-artifact", uses)))
  expect_null(job_uses(path, "no-such-job"))
})
