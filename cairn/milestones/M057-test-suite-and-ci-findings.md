# M57: The hang trace, the parallel-files setup and two test files close the M52, M37 and M34 review findings

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — test helpers, test files and a CI workflow, none of which an external consumer relies on
- **Branch/PR:** `m057-test-suite-and-ci-findings`

## Goal

Close the review findings on the hang trace, the parallel-files setup, `test-vctrs-compat.R` and `test-dots-barrier.R` that the M52, M37 and M34 reviews deferred.

## Scope

**In:** a test forbidding duplicate `test_that()` descriptions within a file; `HangTraceReporter` pruning `open` at `end_file`; the two hang-trace tempdir leaks; the fixture-cache teardown report on `stderr()` and per-worker comments; a test resolving every `Config/testthat/start-first` name; `timeout-minutes` and `TESTTHAT_CPUS` on `R-CMD-check-hard.yaml` and the PROFILE sentence that names the capped workflows; `tibble` skips in `test-vctrs-compat.R`; the dots-barrier registry probe's named floor and the removal of its source scan.

**Out:** a reporter occurrence counter for duplicate descriptions and a disk-backed fixture cache shared across workers → the trimmed M52 candidate row (the gate took the cheap answers). Hardening the `collect_metrics(` source scan → dropped at the gate in favor of removing it; the runtime refusal test stays. `expect_no_record()` checking template attributes → M56 T2. The package-code findings → M56.

## Acceptance criteria

- [ ] AC1: No two `test_that()` blocks in one file under `tests/testthat/test-*.R` share a description, as checked by a test that scans that glob; the test is shown red on a planted duplicate before it is trusted green.
- [ ] AC2: `HangTraceReporter$end_file()` removes the ending file's targets from `open` as well as `seen`, so after a file whose block never ends no target of that file remains in `open`; and `trace_lines_parallel()` and `fixture_two_blocks()` remove their temporary directories on exit; a test asserts each.
- [ ] AC3: `teardown-fixture-cache.R` writes its report with `cat(file = stderr())`, and its preamble and `helper-orchestration.R`'s cache comment state that the cache is per worker process under parallel test files; a test captures the report with `capture.output(type = "message")`.
- [ ] AC4: Every name in DESCRIPTION's `Config/testthat/start-first` resolves to an existing `tests/testthat/test-<name>.R`, as checked by a test reading the field; the test is shown red on a planted unknown name before it is trusted green.
- [ ] AC5: `.github/workflows/R-CMD-check-hard.yaml`'s job declares `timeout-minutes` and sets `TESTTHAT_CPUS` in its `env:`, and `cairn/PROFILE.md`'s hang-cap sentence names the capped workflows without a hit count.
- [ ] AC6: Every `test_that()` call in `tests/testthat/test-vctrs-compat.R` whose body contains `tibble::` opens with `skip_if_not_installed("tibble")`, as checked by parsing the file's `test_that()` calls.
- [ ] AC7: In `tests/testthat/test-dots-barrier.R`, the registry probe asserts that a named list of registered methods (`print`, `collect_metrics`, `autoplot`, `summary` for `nested_results`; `print`, `extract_tune_results`, `extract_scored_candidates` for `nested_final_fit`) is among the methods it probes, shown red when one is removed; and the `collect_metrics(` source scan, its two filters and its discrimination test are gone while the runtime test that a positional argument past `...` errors remains.
- [ ] AC8: `devtools::test()` and `devtools::check()` pass.

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
- [ ] T3: Add `file = stderr()` to the four `cat()` calls in `tests/testthat/teardown-fixture-cache.R:15-38`; rewrite the preamble and `helper-orchestration.R:1035-1040` to say per worker; test by calling the report function under `capture.output(type = "message")`.
- [ ] T4: Add a test to `tests/testthat/test-parallel-detection.R` reading `Config/testthat/start-first` via `read.dcf()` and asserting each `test-<name>.R` exists; plant a bad name against a tempdir copy of DESCRIPTION to see it red.
- [ ] T5: Add `timeout-minutes: 30` beside `runs-on` and `TESTTHAT_CPUS: 4` to the `env:` block in `.github/workflows/R-CMD-check-hard.yaml:19-33`; sum the suite's declared bounds under the cap per the M16/M48 lesson; rewrite `cairn/PROFILE.md:48-50` to name the capped workflows.
- [ ] T6: Add `skip_if_not_installed("tibble")` as the first line of the nine blocks at `tests/testthat/test-vctrs-compat.R:122, 161, 171, 185, 211, 246, 276, 294, 342`; verify with a parse over the file's `test_that()` calls.
- [ ] T7: At `tests/testthat/test-dots-barrier.R:144-153` assert the named method list is in `probed`; delete `collect_metrics_call_args()` (`:199-241`), the corpus walk (`:250-272`), both positional filters (`:279-282`, `:307-310`) and the scan's discrimination test (`:289-312`), keeping the runtime positional-argument test.
- [ ] T8: `devtools::test()`, `devtools::check()`.

## Work log

- 2026-09-03: created by /milestone-plan from the M52 candidate row and the test-file halves of the M37 and M34 rows; the criteria audit ran in reduced mode on a fresh [O] reader and returned findings on AC2 (no target of the ended file, not an empty set), AC3 (`stderr()` plus message capture), AC5 (name the workflows, no hit count), AC6 (parse blocks, not grep), AC7 (name the probed methods; one scan disposition), and none on AC1, AC4 and AC8.
- 2026-09-03: plan gate chose removing the `collect_metrics(` source scan over hardening its positional filter and comment handling because the runtime refusal already errors on a positional argument past `...` and the scan is a second checker over the repo's own files; falsified by a positional `collect_metrics()` call reaching the default branch that no test executes.
- 2026-09-03: plan gate chose a duplicate-description scan test and per-worker cache comments over a reporter occurrence counter and a disk-backed shared cache because both structural answers add failure modes for a trace that misattributes nothing today; falsified by a hang the trace misattributes to the wrong block, or by a fixture build count that dominates a leg's wall clock.

- 2026-09-03: T1 done; `helper-test-source.R` parses a file's `test_that()` calls (shared with T6), the scan in `test-hang-trace.R` found no duplicate in the 57 files and reported one planted into a tempdir copy of the suite before it was trusted green.
- 2026-09-03: T2 done; `end_file()` prunes `open` through the same `forget()` as `seen`, the pruning test failed on the unpruned `open` with the line commented out; `trace_lines_parallel()` unlinks on exit and `fixture_two_blocks()` registers the unlink on its caller's frame, each asserted gone.

## Decisions

## Review
