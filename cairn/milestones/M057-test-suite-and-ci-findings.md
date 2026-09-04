# M57: The hang trace, the parallel-files setup and two test files close the M52, M37 and M34 review findings

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — test helpers, test files and a CI workflow, none of which an external consumer relies on
- **Branch/PR:** `m057-test-suite-and-ci-findings` · https://github.com/tidymodels/nestedtune/pull/67

## Goal

Close the review findings on the hang trace, the parallel-files setup, `test-vctrs-compat.R` and `test-dots-barrier.R` that the M52, M37 and M34 reviews deferred.

## Scope

**In:** a test forbidding duplicate `test_that()` descriptions within a file; `HangTraceReporter` pruning `open` at `end_file`; the two hang-trace tempdir leaks; the fixture-cache teardown report on `stderr()` and per-worker comments; a test resolving every `Config/testthat/start-first` name; `timeout-minutes` and `TESTTHAT_CPUS` on `R-CMD-check-hard.yaml` and the PROFILE sentence that names the capped workflows; `tibble` skips in `test-vctrs-compat.R`; the dots-barrier registry probe's named floor and the removal of its source scan.

**Out:** a reporter occurrence counter for duplicate descriptions and a disk-backed fixture cache shared across workers → the trimmed M52 candidate row (the gate took the cheap answers). Hardening the `collect_metrics(` source scan → dropped at the gate in favor of removing it; the runtime refusal test stays. `expect_no_record()` checking template attributes → M56 T2. The package-code findings → M56.

## Acceptance criteria

- [x] AC1: No two `test_that()` blocks in one file under `tests/testthat/test-*.R` share a description, as checked by a test that scans that glob; the test is shown red on a planted duplicate before it is trusted green.
- [x] AC2: `HangTraceReporter$end_file()` removes the ending file's targets from `open` as well as `seen`, so after a file whose block never ends no target of that file remains in `open`; and `trace_lines_parallel()` and `fixture_two_blocks()` remove their temporary directories on exit; a test asserts each.
- [x] AC3: `teardown-fixture-cache.R` writes its report with `cat(file = stderr())`, and its preamble and `helper-orchestration.R`'s cache comment state that the cache is per worker process under parallel test files; a test captures the report with `capture.output(type = "message")`.
- [x] AC4: Every name in DESCRIPTION's `Config/testthat/start-first` resolves to an existing `tests/testthat/test-<name>.R`, as checked by a test reading the field; the test is shown red on a planted unknown name before it is trusted green.
- [x] AC5: `.github/workflows/R-CMD-check-hard.yaml`'s job declares `timeout-minutes` and sets `TESTTHAT_CPUS` in its `env:`, and `cairn/PROFILE.md`'s hang-cap sentence names the capped workflows without a hit count.
- [x] AC6: Every `test_that()` call in `tests/testthat/test-vctrs-compat.R` whose body contains `tibble::` opens with `skip_if_not_installed("tibble")`, as checked by parsing the file's `test_that()` calls.
- [x] AC7: In `tests/testthat/test-dots-barrier.R`, the registry probe asserts that a named list of registered methods (`print`, `collect_metrics`, `autoplot`, `summary` for `nested_results`; `print`, `extract_tune_results`, `extract_scored_candidates` for `nested_final_fit`) is among the methods it probes, shown red when one is removed; and the `collect_metrics(` source scan, its two filters and its discrimination test are gone while the runtime test that a positional argument past `...` errors remains.
- [x] AC8: `devtools::test()` and `devtools::check()` pass.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T4
- AC5 → T5
- AC6 → T6
- AC7 → T7
- AC8 → T8

## Tasks

- [x] T1: Add a test (home: `tests/testthat/test-hang-trace.R`) that parses each `tests/testthat/test-*.R`, collects `test_that()` descriptions per file and asserts none is duplicated; plant a duplicate in a tempdir copy to see it red.
- [x] T2: In `end_file()` (`tests/testthat/helper-hang-trace.R:99-108`), prune `open` with the same `own` mask as `seen` and amend the comment at `:75-77`; add `on.exit(unlink(dir, recursive = TRUE), add = TRUE)` at `test-hang-trace.R:120` and cover `fixture_two_blocks()` (`:10-12`) from its caller; test with a no-op `end_test` subclass on the `WedgedReporter` pattern (`:69-77`) and a directory-gone assertion.
- [x] T3: Add `file = stderr()` to the four `cat()` calls in `tests/testthat/teardown-fixture-cache.R:15-38`; rewrite the preamble and `helper-orchestration.R:1035-1040` to say per worker; test by calling the report function under `capture.output(type = "message")`.
- [x] T4: Add a test to `tests/testthat/test-parallel-detection.R` reading `Config/testthat/start-first` via `read.dcf()` and asserting each `test-<name>.R` exists; plant a bad name against a tempdir copy of DESCRIPTION to see it red.
- [x] T5: Add `timeout-minutes: 30` beside `runs-on` and `TESTTHAT_CPUS: 4` to the `env:` block in `.github/workflows/R-CMD-check-hard.yaml:19-33`; sum the suite's declared bounds under the cap per the M16/M48 lesson; rewrite `cairn/PROFILE.md:48-50` to name the capped workflows.
- [x] T6: Add `skip_if_not_installed("tibble")` as the first line of every block in `tests/testthat/test-vctrs-compat.R` whose body calls `tibble::` (eleven at 161, 233, 243, 257, 283, 318, 348, 371, 401, 430, 478 on the branch base; the plan's nine line numbers predated M56); verify with a parse over the file's `test_that()` calls.
- [x] T7: At `tests/testthat/test-dots-barrier.R:144-153` assert the named method list is in `probed`; delete `collect_metrics_call_args()` (`:199-241`), the corpus walk (`:250-272`), both positional filters (`:279-282`, `:307-310`) and the scan's discrimination test (`:289-312`), keeping the runtime positional-argument test.
- [x] T8: `devtools::test()`, `devtools::check()`.

## Work log

- 2026-09-03: created by /milestone-plan from the M52 candidate row and the test-file halves of the M37 and M34 rows; the criteria audit ran in reduced mode on a fresh [O] reader and returned findings on AC2 (no target of the ended file, not an empty set), AC3 (`stderr()` plus message capture), AC5 (name the workflows, no hit count), AC6 (parse blocks, not grep), AC7 (name the probed methods; one scan disposition), and none on AC1, AC4 and AC8.
- 2026-09-03: plan gate chose removing the `collect_metrics(` source scan over hardening its positional filter and comment handling because the runtime refusal already errors on a positional argument past `...` and the scan is a second checker over the repo's own files; falsified by a positional `collect_metrics()` call reaching the default branch that no test executes.
- 2026-09-03: plan gate chose a duplicate-description scan test and per-worker cache comments over a reporter occurrence counter and a disk-backed shared cache because both structural answers add failure modes for a trace that misattributes nothing today; falsified by a hang the trace misattributes to the wrong block, or by a fixture build count that dominates a leg's wall clock.

- 2026-09-03: T1 done; `helper-test-source.R` parses a file's `test_that()` calls (shared with T6), the scan in `test-hang-trace.R` found no duplicate in the 57 files and reported one planted into a tempdir copy of the suite before it was trusted green.
- 2026-09-03: T2 done; `end_file()` prunes `open` through the same `forget()` as `seen`, the pruning test failed on the unpruned `open` with the line commented out; `trace_lines_parallel()` unlinks on exit and `fixture_two_blocks()` registers the unlink on its caller's frame, each asserted gone.
- 2026-09-03: T3 done; the four `cat()` calls moved into `print_fixture_cache_report(report, file = stderr())` in `helper-orchestration.R`, which the teardown calls with `file = stderr()` spelled out, a test captures it with `capture.output(type = "message")` and shows stdout empty; the preamble and the cache comment say per worker. Learned by execution (testthat 3.3.2): under parallel files nothing a worker's teardown writes to stdout OR stderr reaches the parent's streams, so the report is a serial-run report whichever stream it takes — the comments say so; the criterion holds as written.
- 2026-09-03: T4 done; `start_first_names()` reads the field with `read.dcf()` off `system.file("DESCRIPTION")` (pkgload's shim or the installed copy), all eleven names resolve, and a copy of the real DESCRIPTION with `nonesuch-planted` prepended reported exactly that name before the check was trusted green.
- 2026-09-03: T5 done; `R-CMD-check-hard.yaml` caps its job at 30 minutes (last green main run 12m09s, check step 9m10s, job 100897115868) and sets `TESTTHAT_CPUS: 4`; the PROFILE sentence names the four cap-bearing workflows and the unaudited stress one, no hit count, PROFILE at 120 lines. The declared wait bounds (`time_budget_totals()`) sum to 4623.7 s over seven daemon files, 2640 of it `test-parallel-identity.R`, above any 30-minute cap on a leg that runs them; the hard leg installs no mirai so every one skips there, and the two legs that run them keep the caps M48 set.
- 2026-09-03: T6 done; minor amendment: the plan's nine block lines were stale after M56, a parse found eleven `tibble::`-calling blocks and the skips were inserted from their parse positions; the check walks each block's code for a `tibble::` call (a text search caught its own description) and went red naming the block when one skip was removed.
- 2026-09-03: T7 done; `DOTS_PROBED_METHODS` names the seven methods and the probe went red naming `summary.nested_results` with its `S3method()` line removed from NAMESPACE; `collect_metrics_call_args()`, the corpus walk, both positional filters and the scan's discrimination test are gone. Minor amendment: no test in the suite exercised a positional argument past `collect_metrics()`'s `...` (the plan assumed one), so one was added beside the AC6 formals test — `collect_metrics(res, FALSE)` refused with `rlib_error_dots_nonempty`, `summarize = FALSE` reaching the unsummarised shape.
- 2026-09-03: T8 done; `devtools::test()` 5756 passing, 0 failures, 0 skips; `devtools::check()` status OK, 0 errors, 0 warnings, 0 notes; status set to review.

## Decisions

## Review

- 2026-09-03 review: PR #67 opened as a draft; `origin/main` had not moved since the branch was cut (no merge needed).
- AC1: the parse-based scan over `tests/testthat/test-*.R` found 57 files, 0 duplicated descriptions; a copy of the suite with a second `no two test_that() blocks in one file share a description` block appended to `test-hang-trace.R` reported exactly `test-hang-trace.R :: <that description>`; the in-suite discrimination test plants a duplicate in a tempdir and names it. Verified.
- AC2: a subclass restoring the pre-M57 `end_file()` (pruning `seen` only) under a no-op `end_test` left `test-fx.R :: a` and `test-fx.R :: b` in `open` after the file ended; the branch's `end_file()` left `open` empty of that file's targets; `trace_lines_parallel()` unlinks its directory on exit and `fixture_two_blocks()` registers the unlink on its caller's frame, each asserted gone by a test in `test-hang-trace.R`. Verified.
- AC3: `teardown-fixture-cache.R:28` calls `print_fixture_cache_report(fixture_cache_report(), file = stderr())`, whose `cat()` calls all pass `file`; the teardown preamble (lines 11–14) and `helper-orchestration.R:1040–1043` say the cache is per worker process under parallel test files; `test-fixture-cache.R`'s new block captures the report with `capture.output(type = "message")` and asserts stdout empty. Verified.
- AC4: `read.dcf()` on DESCRIPTION yields 11 `start-first` names, all resolving to `tests/testthat/test-<name>.R`; the in-suite discrimination test plants `nonesuch-file` in a tempdir DESCRIPTION (with a continuation line) and reports exactly that name. Verified.
- AC5: `R-CMD-check-hard.yaml:28` `timeout-minutes: 30` on the job, `:44` `TESTTHAT_CPUS: 4` in `env:`; `cairn/PROFILE.md:48–50` names `R-CMD-check`, `test-coverage` and `R-CMD-check-hard` with their caps and contains no hit count (`grep -c hits` = 0); PROFILE at 119 lines. Verified.
- AC6: the parse walk over `test-vctrs-compat.R` finds 11 `tibble::`-calling blocks, all opening with `skip_if_not_installed("tibble")`; a copy with the third skip removed was flagged by description (`a tibble does not cast to a nested_results`). Verified.
- AC7: `DOTS_PROBED_METHODS` names the seven methods and `setdiff()` against the live registry's probed set is empty; with `summary.nested_results` removed from the probed set the check names it; `collect_metrics_call_args`, the corpus walk, both positional filters and the scan's discrimination test are absent from `test-dots-barrier.R` (grep empty), and the runtime test asserts `rlib_error_dots_nonempty` on `collect_metrics(res, FALSE)` with a named control. Verified.
- Consistency gate: `cairn_validate` exit 0 (19 advisories: the M057 8-criteria sizing tripwire, 18 references staleness); `devtools::document()` no diff; README.Rmd and README.md last changed in the same commit; `pkgdown::check_pkgdown()` no problems; no principle changed (no `cairn_impact` run); no user-visible change, so no NEWS entry; no new top-level file.
- Independent review, three lenses: [O] diff-bug 11 findings, [S] blame-history 2, [S] prior-review 0 (the PR-comments probe found one real inline comment, on PR #30, unrelated to these files; archived reviews M52 and M34 read, no regression).
- O-F1/S-1 (fix now): `test-dots-barrier.R:223`'s new comment cited `test-collect-metrics.R`, a file that does not exist; it now points at the runtime block below it.
- O-F2 (fix now, comment only): `test-vctrs-compat.R`'s tibble-skip comment claimed the no-Suggests leg lacks tibble, but tibble is an Import of dplyr and tune, so `R-CMD-check-hard` always has it and the skip never fires there; the comment now says the skip is Suggests hygiene and names that fact. AC6 as written asks for the skips and the parse check, both of which hold.
- O-F3 (fix now): the new runtime block in `test-dots-barrier.R` requested its fixture unseeded, keying apart from `compat_results()`'s entry and paying a second fit; it now seeds `set.seed(2)` as that helper does, and a serial run of the three files reports 1 signature, 1 build, 22 requests.
- O-F4 (fix now): the same block skipped on `recipes` alone where `reg_metrics()` also needs yardstick; it now uses `skip_if_no_engines()`.
- O-F5 (fix now): `cairn/PROFILE.md:58` said `TESTTHAT_CPUS` is set in "both gating workflows"; three workflows set it now and the sentence says so; PROFILE stays at 119 lines.
- O-F6 (fix now): the yaml comment called the measured run "the last green run on main"; `gh run view 33832117316` reports a pull_request run of the M56 branch; the durations were confirmed and the attribution is corrected.
- O-F7 (fix now): the `open`-pruning test counted its precondition on a fresh reporter rather than the wedged one; it now reads the wedged run's own lines and asserts two starts and no end.
- O-F8 (reject): `test_that_calls()` reads top-level literal-description calls only, which is every call in the suite today (597 blocks); the empty-domain guards already assert the scan read something, and a nested or computed-description block is not a shape this suite uses.
- O-F9 (reject): the AC6 check requires the tibble skip as the body's first statement, which is what the criterion says ("opens with"); a block ordering it after another skip is reported, which is the intended reading.
- O-F10 (reject): AC3's `cat(file = stderr())` calls live in `print_fixture_cache_report()`, which the teardown calls with `file = stderr()` spelled out; the criterion names the stream and the capture, both tested.
- O-F11/S-2 (reject): the removed corpus scan was the only reader of vignette and roxygen call sites for a positional `collect_metrics()`; the plan gate chose the removal and the candidate row records the promotion condition (a positional call reaching the default branch that no test executes).
- After the fix-now edits, `test-dots-barrier.R`, `test-hang-trace.R` and `test-vctrs-compat.R` ran serially: 39 tests, 0 failures, 0 skips; the workflow yaml parses.
- PR-conversation read on PR #67: no reviews, no comments, no unresolved threads.
- AC8: `devtools::test()` 5756 passing, 0 failures, 0 skips (parallel, the branch head before the fix-now edits); `devtools::check()` status OK, 0 errors, 0 warnings, 0 notes, 5m32s, on the same tree; the fix-now edits touched three test files, one workflow comment and PROFILE, and the three files re-ran green serially (39 tests). Verified.
- 2026-09-03: step-6 checkpoint; seven findings fixed on the branch, four rejected with reasons above, awaiting the step-7 gate.
