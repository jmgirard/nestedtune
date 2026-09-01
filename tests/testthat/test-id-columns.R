# Which columns are the design's own fold labels, and where that answer comes
# from (M38).
#
# It used to be a name pattern matched against whatever names the object carried
# at the time, and every review round of M36 bought exactly one more spelling: a
# bare `^id` prefix caught `ideal` and `id_extra`, and anchoring it to
# `^id[0-9]*$` still caught `id2` -- a name rsample gives a repeated design and a
# caller may perfectly well add to a plain one. Those two cases are spelled
# identically, so no pattern separates them. The constructor asks the design once
# and records the answer; every reader asks the record.

test_that("the constructor records the columns it took from the design", {
  skip_if_no_engines()

  plain <- repeated_results(repeats = 1)
  expect_identical(attr(plain, "id_columns"), "id")
  expect_identical(id_columns(plain), "id")

  repeated <- repeated_results(repeats = 2)
  expect_identical(attr(repeated, "id_columns"), c("id", "id2"))
  expect_identical(id_columns(repeated), c("id", "id2"))
})

# The record is what the design carried, not what a pattern would have picked
# out of it. A design labelling its repeats some other way is recorded under
# that name -- and a caller's `id2` on such a run is just a caller's column.
test_that("a design's label column is recorded under whatever name it has", {
  skip_if_no_engines()

  design <- repeated_design()
  names(design)[names(design) == "id2"] <- "rep_label"
  odd <- results_from(design)

  expect_identical(id_columns(odd), c("id", "rep_label"))
  expect_identical(
    fold_ids(odd),
    paste(odd$id, odd$rep_label, sep = ", ")
  )

  # The passing control: on the design as rsample built it, `id2` is the second
  # label and is pasted in. Here it is a name nothing has claimed.
  expect_identical(id_columns(repeated_results()), c("id", "id2"))
  added <- dplyr::mutate(odd, id2 = "x")
  expect_s3_class(added, "nested_results")
  expect_identical(fold_ids(added), fold_ids(odd))
})

# The record describes the call, so it travels the way the rest of the call's
# description does -- and goes when the class goes, for the reason
# `bare_results()` gives: a bare tibble left holding it would leave the stale
# claim readable.
test_that("the record travels with the class and is shed with it", {
  skip_if_no_engines()
  rep_res <- repeated_results()

  kept <- dplyr::mutate(rep_res, extra = 1)
  expect_s3_class(kept, "nested_results")
  expect_identical(id_columns(kept), c("id", "id2"))

  shed <- dplyr::slice(rep_res, 1)
  expect_false(inherits(shed, "nested_results"))
  expect_null(attr(shed, "id_columns"))
})

# The sweep AC4 asks for: at every method that routes a caller's column through
# the rule, the answer may not depend on what the caller called the column.
#
# `extra` is the reference in every cell -- a name no derivation this class has
# ever used could match -- and the five names under test are the ones that did.
# `ideal` and `id_extra` fell to the bare `^id` grep M36 started with; `id2`,
# `id0` and `id9` fall to the `^id[0-9]*$` that replaced it, and `id2` is the one
# a caller is actually likely to reach for, since rsample gives a repeated design
# a column of that name.

# The column is added at the vector level rather than through `mutate()`, so a
# door's cell reports that door and not one a caller passed through on the way
# in. Everything but the names and the row names is carried over untouched.
with_col <- function(x, nm, value) {
  out <- unclass(x)
  out[[nm]] <- value
  for (a in setdiff(names(attributes(x)), c("names", "row.names", "class"))) {
    attr(out, a) <- attr(x, a)
  }
  attr(out, "row.names") <- .set_row_names(nrow(x))
  class(out) <- class(x)
  out
}

# What "the same answer" means for two objects that necessarily differ in one
# column's name: what the object came back as, the run's description it carries,
# the two fold counts, the record of the design's own label columns, and the
# values of every column but the caller's. A cell that raises instead is its
# condition, so an abort in one cell and a value in the other are never equal.
door_answer <- function(expr, caller_col) {
  tryCatch(
    {
      out <- expr
      list(
        class = class(out),
        grid = attr(out, "grid"),
        metrics = attr(out, "metrics"),
        outer_label = attr(out, "outer_label"),
        attempted = attr(out, "folds_attempted"),
        completed = attr(out, "folds_completed"),
        id_columns = id_columns(out),
        columns = as.list(out)[setdiff(names(out), caller_col)]
      )
    },
    condition = function(cnd) {
      list(condition = class(cnd), message = conditionMessage(cnd))
    }
  )
}

# The six methods `NAMESPACE` registers whose bodies call `reconstruct_results()`,
# each in one stated shape -- the shape decides both whether the cell runs and
# whether it can tell anything apart, so it is pinned rather than left to taste.
#
# `rbind` is asked in its row-preserving one-argument form: `rbind(x, x)` adds
# rows and sheds the class whatever the column is called, so those cells could
# not separate the fixed code from the broken. `vec_cast` is asked as
# `vec_cast(y, y)`: casting to a type that lacks the caller's column is a loss
# of precision and vctrs refuses it, so there is no answer there to compare.
# `names<-` is asked as an identity assignment over an object that already
# carries the caller's column, which is what puts that column in front of the
# rule -- renaming a column TO the tested name would leave the tested name out
# of the template, and every such cell would be true by construction.
id_doors <- function() {
  list(
    dplyr_reconstruct = function(x, nm, value) {
      y <- with_col(x, nm, value)
      dplyr::dplyr_reconstruct(bare_results(y), y)
    },
    `[` = function(x, nm, value) {
      with_col(x, nm, value)[rep(TRUE, nrow(x)), ]
    },
    vec_restore = function(x, nm, value) {
      y <- with_col(x, nm, value)
      vctrs::vec_restore(bare_results(y), y)
    },
    `names<-` = function(x, nm, value) {
      y <- with_col(x, nm, value)
      names(y) <- names(y)
      y
    },
    rbind = function(x, nm, value) rbind(with_col(x, nm, value)),
    vec_cast = function(x, nm, value) {
      y <- with_col(x, nm, value)
      vctrs::vec_cast(y, y)
    }
  )
}

test_that("no method's answer depends on what the caller named the column", {
  skip_if_no_engines()

  designs <- list(
    # `id2` is a caller's column on a plain design and one of the design's own
    # on a repeated one, which is the pair no name pattern can separate -- and
    # why the repeated design is asked four names rather than five.
    res = list(
      x = repeated_results(repeats = 1),
      names = c("id2", "id0", "id9", "ideal", "id_extra")
    ),
    rep_res = list(
      x = repeated_results(repeats = 2),
      names = c("id0", "id9", "ideal", "id_extra")
    )
  )
  forms <- list(
    atomic = function(n) seq_len(n),
    list = function(n) as.list(seq_len(n))
  )
  doors <- id_doors()

  for (design in names(designs)) {
    x <- designs[[design]]$x
    for (form in names(forms)) {
      value <- forms[[form]](nrow(x))
      for (door in names(doors)) {
        f <- doors[[door]]
        reference <- door_answer(f(x, "extra", value), "extra")
        # The passing control: the reference cell keeps the class, so the
        # comparisons below are between two answers and never between two
        # identical refusals.
        expect_identical(
          reference$class[1L],
          "nested_results",
          info = paste(design, form, door, "reference")
        )
        for (nm in designs[[design]]$names) {
          expect_identical(
            door_answer(f(x, nm, value), nm),
            reference,
            info = paste(design, form, door, nm)
          )
        }
      }
    }
  }
})

# The prose half. The behavior above is what a reader of `NEWS.md` and the help
# page is being promised, and M36 shipped a sentence narrowing that promise to
# the pattern this milestone removed -- "unless you name it `id` or `id`
# followed by digits". A claim left standing after the code stopped making it is
# the fault this block exists to catch (M36 review O1 asked the same of the
# subsetting paragraph).
#
# `test_path("..", "..", ...)` resolves outside the source tree under
# `R CMD check`, so this skips there and fires where the documentation is
# actually edited. Each file is asserted long enough to have been read and shown
# to carry the sentence that replaced the claim, so a mistyped path cannot pass
# the negative for the wrong reason.
test_that("the changelog and the help page promise what the code now does", {
  paths <- list(
    news = test_path("..", "..", "NEWS.md"),
    roxygen = test_path("..", "..", "R", "nested-tune-grid.R"),
    rd = test_path("..", "..", "man", "nested_tune_grid.Rd")
  )
  skip_if_not(all(vapply(paths, file.exists, logical(1))), "sources absent")
  # The roxygen source carries a `#'` on every line, and the sentence wraps, so
  # the markers are dropped before the whitespace is collapsed -- otherwise a
  # claim that spans two lines is unfindable in the one file it is edited in.
  flat <- function(path) {
    lines <- sub("^\\s*#'\\s?", "", readLines(path, warn = FALSE))
    gsub("\\s+", " ", paste(lines, collapse = " "))
  }

  promise <- "read as a fold label only when the design itself carr"
  for (nm in names(paths)) {
    text <- flat(paths[[nm]])
    expect_gt(nchar(text), 1000L)
    expect_match(text, promise, fixed = TRUE)
  }

  # The narrowed claim M36 left in the changelog, gone.
  expect_no_match(
    flat(paths$news),
    "unless you name it `id` or `id` followed by digits",
    fixed = TRUE
  )
})
