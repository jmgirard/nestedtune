# M43: The print and summary follow-ups M39 left behind

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Branch/PR:** m043-print-summary-followups · https://github.com/tidymodels/nestedtune/pull/52

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

- [x] AC1: Printing a `summary.nested_results` whose run has at least one
      failed fold ends the failure block with one advice line that names the
      results object's `.notes` column, and that line does not contain the
      characters `x$`; asserted on the one-failed-fold and every-fold-failed
      fixtures in `test-nested-results-print.R`.
- [x] AC2: `print.nested_results()` accepts `n` and `width` by name after `...`
      and hands them to the tibble rendering of the rows: on a results object
      of more than twenty outer folds, `print(x)` shows ten rows and tibble's
      `# i <k> more rows` footer while `print(x, n = Inf)` shows every row and
      no such footer; on the three-fold fixture, `print(x, n = 2)` shows two
      rows and a `# i 1 more row` footer; and at console width 80,
      `print(x, width = 40)` lists more columns in the `# i <k> more variables`
      footer than `print(x)` does.
- [x] AC3: `print.nested_results()` still fences `...`: `print(x, foo = 1)`,
      `print(x, n = 2, foo = 1)` and `print(x, w = 40)` each signal an error of
      class `rlib_error_dots_nonempty` whose call is the `print()` call, so a
      prefix of a new argument is refused rather than partially matched.
- [x] AC4: `man/summary.nested_results.Rd`, as `devtools::document()`
      regenerates it, carries a `\value` section whose first paragraph opens
      with `summary()` returns and whose second opens with `print()` returns,
      and an `\examples` section guarded by
      `@examplesIf rlang::is_installed(c("recipes", "yardstick"))` that builds
      a `nested_results` and calls `summary()` on it; and
      `man/print.nested_results.Rd` documents `n` and `width` in its usage and
      arguments.
- [x] AC5: `NEWS.md` carries one entry stating that `print()` on a
      `nested_results` accepts `n` and `width` and passes them to the row
      rendering, and one stating that the summary's failure advice now names
      the results object's `.notes` column.
- [x] AC6: `devtools::document()` leaves no diff, `devtools::test()` is clean,
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
- [x] T3: `@return` labels on `summary.nested_results()` and its print method
      in the M40 form; an `@examplesIf` block mirroring
      `R/nested-final-fit-print.R:81-101` with `summary(res)` as its last line;
      `devtools::document()`; read the regenerated Rd for AC4.
- [x] T4: A snapshot transform for the four `print(<results>)` blocks in the
      `printed output holds its shape` test: keep the `# A tibble: <n> x <k>`
      line, replace the column-type row, the cell rows and the
      `# i <k> more variables` footer with one fixed marker; re-record the four
      blocks and look at them (M08 lesson).
- [x] T5: NEWS entries (AC5); `air format .`; `devtools::document()`,
      `devtools::test()`, `devtools::check()` (AC6).

## Work log

- 2026-09-01: created by /milestone-plan.
- 2026-09-01: criteria audit ran in full mode ([O] reader): 13 findings — the summary cannot name the caller's variable; tibble truncates above twenty rows, not ten; the width comparison named no console width; a dots error through S3 dispatch reports the generic's call; the example needed the sibling's engines guard; `?print.nested_results` went unmentioned; the snapshot scrub, the exemption-list clause and the NEWS-to-test relation were instrument properties — all fixed in the criteria as written (the scrub became T4 with no criterion).
- 2026-09-01: plan gate chose named `n`/`width` after `...` with the fence kept over forwarding `...` to tibble's print, because a mistyped argument would then be ignored silently and the registry probe would need an exemption; falsified by a user needing a tibble print option beyond `n` and `width`.
- 2026-09-01: plan gate chose scrubbing tibble's body from the four print snapshots (header and cli lines kept) over leaving them pinned, because the body is a dependency's rendering; falsified by a print regression the header line and the in-words assertions fail to catch.
- 2026-09-01: plan gate chose rewording only the summary's advice line over one shared sentence at all four `.notes` sites, because the other three name the right object; falsified by a second site found wrong.
- 2026-09-01: T1 done — advice line now reads ``See the `.notes` column of the results object for what went wrong.``; the print-side control assertion moved from `\$\.notes` (which the tibble body could never match anyway) to `what went wrong`; AC1's two assertions plus a block-position check on both failed fixtures; two summary snapshots re-recorded, diff read: the one line each.
- 2026-09-01: T2 done — `print.nested_results(x, ..., n = NULL, width = NULL)`, both handed to `print_rows()`; `@param` text derived from tibble's `?print.tbl_df` as read at tibble 3.3.x; AC2 and AC3 tests added, the AC3 probes as real `print(res, …)` calls; registry probe passes with no new exemption. Minor amendment: the >20-fold fixture is `repeated_results(v = 3, repeats = 7)` (21 folds through the constructor over stand-in records), not an `rbind()` stack — measured: `rbind()` of seven copies returns a bare tibble, because `can_reconstruct_results()` refuses a row count differing from the template's (M36), which D-032's class-keeping does not override.
- 2026-09-01: T3 done — `?summary.nested_results` regenerated: `\value` opens ``summary()` returns` then ``print()` returns`, `\examples` under the engines guard ends in `summary(res)`. T4 done — `scrub_tibble_body()` transform on the four print blocks; testthat hands a transform each cli message alone, so the first cut (which looked for the next bullet) errored and was made to accept a body with nothing after it; re-recorded blocks read: header, marker, cli lines.
- 2026-09-01: T5 done — two NEWS entries; `devtools::document()` no diff, `air format --check .` clean, `devtools::test()` clean, `devtools::check()` 0 errors / 0 warnings / 0 notes. Status → review.
- 2026-09-01: review — PR #52 opened as draft; every criterion verified with fresh evidence; three-lens review: two lenses clean, the diff lens reported eight findings, three fixed at the gate (NEWS threshold, signature comment, AC3 whole-call assertion), five rejected with reasons in the Review section.
- 2026-09-01: merge approved at the gate; PR #52 marked ready; CI watch timed out with 7 of 10 checks green and the devel, ubuntu-release and windows legs still running; merge waits on them.

## Decisions

## Review

Reviewed 2026-09-01 on branch `m043-print-summary-followups` at 03e340a plus the gate fixes below; PR #52. `main` had not moved since the branch was cut.

**Acceptance criteria — fresh evidence:**
- AC1: the two summary snapshots (`_snaps/nested-results-print.md` lines 135 and 162) carry ``i See the `.notes` column of the results object for what went wrong.`` as the failure block's last line; the `never x$` test asserts on both failed fixtures that exactly one advice line exists, it contains ``` `.notes` column of the results object ```, does not contain `x$`, follows a `failed during` line and precedes a non-failure line. Passes.
- AC2: the `n` test builds a 21-fold `nested_results` through `repeated_results(v = 3, repeats = 7)`; default print counts 10 row lines with `# i 11 more rows`; `n = Inf` counts 21 with no `more row` text; on the three-fold fixture `n = 2` counts 2 with `# i 1 more row`. The `width` test renders both at console width 80 and asserts the `width = 40` footer lists more variables than the default's. Both pass.
- AC3: three probes as real `print(res, …)` calls (`foo = 1`; `n = 2, foo = 1`; `w = 40`) each signal `rlib_error_dots_nonempty`; after the gate fix the test asserts the condition's call is identical to the probe call itself (probed: `print(res, w = 40)`), not merely named `print`. `test-dots-barrier.R` passes with no new exemption. Passes.
- AC4: `man/summary.nested_results.Rd` as regenerated: `\value` opens ``\code{summary()} returns`` (line 21) then ``\code{print()} returns`` (line 29); `\examples` is wrapped in the `rlang::is_installed(c("recipes", "yardstick"))` examplesIf guard (line 48), builds a results object with `nested_tune_grid()` and ends in `summary(res)` (line 68). `man/print.nested_results.Rd` usage reads `(x, ..., n = NULL, width = NULL)` with `\item{n}` and `\item{width}` in arguments. Verified by reading the files.
- AC5: `NEWS.md` diff carries the two entries — `print()` accepts `n` and `width` and passes them to the row rendering; the summary's failure advice names the results object's `.notes` column. The first entry's threshold was corrected at the gate (finding 1).
- AC6: `devtools::document()` leaves no diff (before and after the gate fixes); `devtools::test()` 0 failures, 0 warnings, 0 skips, 2746 passes; `air format --check .` exit 0; `devtools::check()` 0 errors, 0 warnings, 0 notes in 3m 17s.

**Consistency gate:** `cairn_validate.py` all checks passed (18 references-staleness advisories, pre-existing; no release window). No DESIGN principle changed, `cairn_impact` skipped. Toolchain slot: document() no diff; no generated file hand-edited; README.Rmd untouched and older than README.md; `pkgdown::check_pkgdown()` no problems; NEWS carries the milestone's user-visible changes with no milestone numbers; no new top-level files; check clean. Driving RR: none.

**Independent review (three lenses, fresh context).** [S] blame-history: no findings — each touched line traces to M43's own plan, the retargeted print-side assertion still fences print from summary's advice, the scrub still fails on D-037's falsifier (a vanished `# A tibble` header). [S] prior-review: no regressions — each of M39's O1, R1, R4, R9, R10 addressed as recorded, R3 left Out as scoped; one real inline PR comment exists in the repo, on an unrelated workflow file. [O] diff-bug, eight findings ranked, dispositions:
1. NEWS said `n = Inf` matters for a run "wider than ten"; tibble truncates above twenty → **fixed now**: "a run of more than twenty".
2. Code comment claimed tibble places `width` after its dots; tibble's is `(x, width = NULL, ..., n = NULL)` → **fixed now**: the comment states the deliberate difference.
3. `print(res, n = 5)` would fail as a partial match for `na.print` if rows ever rendered through `print.data.frame` → **rejected**: that configuration is D-037's recorded falsifier, under which the default print is already wrong; no new row.
4. AC3's test checked only the condition call's name, which the inner `print(rows, …)` also carries → **fixed now**: asserts the whole call identical to the probe.
5. The scrub no longer pins how many rows the three-fold snapshots render → **rejected**: the plan gate's recorded falsifier for the scrub; the 21-fold test pins rendered-row counts.
6. The scrub's discrimination test runs on synthetic lines only → **rejected**: a change in testthat's chunking surfaces as a visible snapshot mismatch, the loud failure mode.
7. The AC3 test is engine-gated though the fence fires before `x` is read → **rejected**: the file's fixtures are all engine-gated and CI carries the engines; no coverage loss where the tests run.
8. The three other `.notes` advice sites word the advice differently → **rejected**: Scope Out, the gate line records why.
