# M43: The print and summary follow-ups M39 left behind

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Branch/PR:** m043-print-summary-followups

## Goal

A user meeting a `nested_results` through `print()` and `summary()` gets failure
advice that resolves, rows they can page through, and a help page that says
which return belongs to which call.

## Scope

User-facing tier: every deliverable is an exported method's behavior or its
documentation. One pass over `R/nested-results-print.R`, its tests and its
snapshots reaches all of it — the five items M39's review deferred to one
candidate row (O1, R1, R4, R9, R10), whose wait condition (ship after M40)
has passed.

**In:**
- `print_failures()`'s advice line names the results object's `.notes` column
  instead of `x$.notes`, which on the summary bundle bound to `x` there names
  nothing.
- `print.nested_results()` takes `n` and `width` by name after `...`, mirroring
  tibble's own `print.tbl_df(x, width = NULL, ..., n = NULL)`, and hands them
  to the row rendering; the `...` fence stays (M34), so a stray or
  partially-spelled argument is still refused (GP3: one obvious path, no
  silently ignored knob).
- `?summary.nested_results` labels its two `\value` paragraphs the way M40's
  sibling page does and gains the same engines-guarded example block;
  `?print.nested_results` documents the two new arguments.
- The four `print(<results>)` snapshot blocks stop recording tibble's table
  body — a dependency's rendering the test doctrine says not to pin — through
  a snapshot transform that keeps the `# A tibble` header and every cli line.

**Out:**
- The other three `.notes` advice sites — `warn_failed_folds()`
  (`R/nested-tune-grid.R`), `check_any_completed()` (`R/nested-results.R`) and
  the daemon-package warning (`R/parallel.R`) — where `x` stands for the
  results object; unchanged by the gate's choice. A shared advice helper is
  not wanted until a second site is wrong.
- Hardening `new_summary_nested_results()` against a non-character
  `.notes$location` → stays on the refuse-a-design candidate row (M39 review
  R3).
- Forwarding `...` to tibble wholesale → rejected at the gate; the work-log
  line records why.
- The `nested_final_fit` side: M40 already labelled its return paragraphs and
  ships an example; `print.nested_final_fit()` shows no rows to page.

## Acceptance criteria

- [ ] AC1: Printing a `summary.nested_results` whose run has at least one
      failed fold ends the failure block with one advice line that names the
      results object's `.notes` column, and that line does not contain the
      characters `x$`; asserted on the one-failed-fold and every-fold-failed
      fixtures in `test-nested-results-print.R`.
- [ ] AC2: `print.nested_results()` accepts `n` and `width` by name after `...`
      and hands them to the tibble rendering of the rows: on a results object
      of more than twenty outer folds, `print(x)` shows ten rows and tibble's
      `# i <k> more rows` footer while `print(x, n = Inf)` shows every row and
      no such footer; on the three-fold fixture, `print(x, n = 2)` shows two
      rows and a `# i 1 more row` footer; and at console width 80,
      `print(x, width = 40)` lists more columns in the `# i <k> more variables`
      footer than `print(x)` does.
- [ ] AC3: `print.nested_results()` still fences `...`: `print(x, foo = 1)`,
      `print(x, n = 2, foo = 1)` and `print(x, w = 40)` each signal an error of
      class `rlib_error_dots_nonempty` whose call is the `print()` call, so a
      prefix of a new argument is refused rather than partially matched.
- [ ] AC4: `man/summary.nested_results.Rd`, as `devtools::document()`
      regenerates it, carries a `\value` section whose first paragraph opens
      with `summary()` returns and whose second opens with `print()` returns,
      and an `\examples` section guarded by
      `@examplesIf rlang::is_installed(c("recipes", "yardstick"))` that builds
      a `nested_results` and calls `summary()` on it; and
      `man/print.nested_results.Rd` documents `n` and `width` in its usage and
      arguments.
- [ ] AC5: `NEWS.md` carries one entry stating that `print()` on a
      `nested_results` accepts `n` and `width` and passes them to the row
      rendering, and one stating that the summary's failure advice now names
      the results object's `.notes` column.
- [ ] AC6: `devtools::document()` leaves no diff, `devtools::test()` is clean,
      `air format .` changes nothing, and `devtools::check()` reports 0 errors
      and 0 warnings.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T2
- AC4 → T2, T3
- AC5 → T5
- AC6 → T5

## Tasks

- [x] T1: Reword the advice line in `print_failures()`
      (`R/nested-results-print.R:241`); replace the
      `expect_match(txt, "See .*\\$\\.notes")` assertion in
      `test-nested-results-print.R` with AC1's two assertions on both failed
      fixtures; re-record the two summary snapshots that carry the line.
- [x] T2: Signature `print.nested_results(x, ..., n = NULL, width = NULL)`;
      `print_rows(x, n, width)` passes both to `print()` on the class-stripped
      rows. Roxygen `@param n` / `@param width` worded against `?print.tbl_df`
      as read, not recalled (M28 lesson). Build the more-than-twenty-fold
      fixture by stacking the three-fold fixture with `rbind()` (D-032 keeps
      the class), no new tuning run. Tests for AC2 and AC3; the AC3 probes use
      the real calling shape (M42 lesson). Confirm `test-dots-barrier.R`'s
      registry probe passes with no new exemption.
- [ ] T3: `@return` labels on `summary.nested_results()` and its print method
      in the M40 form; an `@examplesIf` block mirroring
      `R/nested-final-fit-print.R:81-101` with `summary(res)` as its last line;
      `devtools::document()`; read the regenerated Rd for AC4.
- [ ] T4: A snapshot transform for the four `print(<results>)` blocks in the
      `printed output holds its shape` test: keep the `# A tibble: <n> x <k>`
      line, replace the column-type row, the cell rows and the
      `# i <k> more variables` footer with one fixed marker; re-record the four
      blocks and look at them (M08 lesson).
- [ ] T5: NEWS entries (AC5); `air format .`; `devtools::document()`,
      `devtools::test()`, `devtools::check()` (AC6).

## Work log

- 2026-09-01: created by /milestone-plan.
- 2026-09-01: criteria audit ran in full mode ([O] reader): 13 findings — the summary cannot name the caller's variable; tibble truncates above twenty rows, not ten; the width comparison named no console width; a dots error through S3 dispatch reports the generic's call; the example needed the sibling's engines guard; `?print.nested_results` went unmentioned; the snapshot scrub, the exemption-list clause and the NEWS-to-test relation were instrument properties — all fixed in the criteria as written (the scrub became T4 with no criterion).
- 2026-09-01: plan gate chose named `n`/`width` after `...` with the fence kept over forwarding `...` to tibble's print, because a mistyped argument would then be ignored silently and the registry probe would need an exemption; falsified by a user needing a tibble print option beyond `n` and `width`.
- 2026-09-01: plan gate chose scrubbing tibble's body from the four print snapshots (header and cli lines kept) over leaving them pinned, because the body is a dependency's rendering; falsified by a print regression the header line and the in-words assertions fail to catch.
- 2026-09-01: plan gate chose rewording only the summary's advice line over one shared sentence at all four `.notes` sites, because the other three name the right object; falsified by a second site found wrong.
- 2026-09-01: T1 done — advice line now reads ``See the `.notes` column of the results object for what went wrong.``; the print-side control assertion moved from `\$\.notes` (which the tibble body could never match anyway) to `what went wrong`; AC1's two assertions plus a block-position check on both failed fixtures; two summary snapshots re-recorded, diff read: the one line each.
- 2026-09-01: T2 done — `print.nested_results(x, ..., n = NULL, width = NULL)`, both handed to `print_rows()`; `@param` text derived from tibble's `?print.tbl_df` as read at tibble 3.3.x; AC2 and AC3 tests added, the AC3 probes as real `print(res, …)` calls; registry probe passes with no new exemption. Minor amendment: the >20-fold fixture is `repeated_results(v = 3, repeats = 7)` (21 folds through the constructor over stand-in records), not an `rbind()` stack — measured: `rbind()` of seven copies returns a bare tibble, because `can_reconstruct_results()` refuses a row count differing from the template's (M36), which D-032's class-keeping does not override.

## Decisions

## Review
