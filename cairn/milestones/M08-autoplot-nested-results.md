<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M08: Selection instability you can see

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, IP4, GP1, GP3, GP4
- **Branch/PR:** `m08-autoplot-nested-results` · https://github.com/jmgirard/nestedtune/pull/8

## Goal

`autoplot()` on a `nested_results` object draws what each outer fold's inner
tuning selected and how the per-fold outer scores spread, so the disagreement
the print method describes in words can also be seen.

## Scope

**In:** `autoplot.nested_results(object, type = c("parameters", "performance"),
...)`, registered on `ggplot2::autoplot()` and defaulting to the parameters
view. The parameters view draws one panel per tuned parameter and one point per
completed outer fold at its selected value, keyed by fold id, so agreement and
disagreement are legible without reading the numbers. The performance view
draws one panel per metric, one point per contributing fold, and marks the
nested estimate — the value `collect_metrics()` reports, read off
`summarize_folds()` (`R/nested-results.R:170`) rather than recomputed, so plot
and summary can never disagree. Both views state how many of the requested
folds contributed and omit the rest rather than imputing them (IP4).
`ggplot2` joins Imports and `vdiffr` joins Suggests (D-019). Documentation:
`_pkgdown.yml` reference row, a `NEWS.md` entry, and the vignette's
disagreement section gains the plot.

**Out:**

- An `autoplot()` for `nested_final_fit` — deliberately not planned: the object
  holds no performance number of its own by D-014, so there is nothing an
  honest plot could draw.
- `show_best()` / `select_best()` methods — stay unregistered, per D-010.
- Plotting each fold's *inner* tuning surface — deliberately not planned: the
  results object does not retain the inner `tune_results`, and keeping every
  fold's would cost the memory GP4 exists to defend.
- An interval or band on the fold spread → the existing variance-estimation
  candidate row, which GP5 keeps parked until the literature backs it.

## Acceptance criteria

- [x] AC1: `autoplot()` on a `nested_results` returns a `ggplot` for both
      `type` values; `type` defaults to `"parameters"`; the method is
      registered so a bare `autoplot(x)` dispatches without namespacing.
- [x] AC2: For a fixture whose outer folds disagree on a parameter, every
      completed fold's selected value appears in the built plot's data keyed by
      its fold id; for a fixture where they agree, every completed fold appears
      at the one value. Asserted on `ggplot2::ggplot_build(p)$data`, never on
      pixels.
- [ ] AC3: A failed outer fold, and a completed fold carrying no value for a
      parameter, contribute no point to that parameter's panel and are never
      imputed; the plot states how many of the requested folds contributed —
      derived from the columns in hand as `print.nested_results` does, never
      from the stamped attribute (IP4).
- [x] AC4: In the performance view the marked central value for each metric
      equals `collect_metrics(x)$mean` exactly, and the plot carries IP3's
      caveat — the number describes the tune-and-fit procedure, not a
      deployable model — where a reader meets the number *(RB tripwire:
      ip-touching — print carries this in a sentence; what a plot can honestly
      carry is unsettled)*.
- [x] AC5: Three error branches fire with the package's own `cli_abort()` in
      the `R/checks.R` idiom: a results object where no outer fold completed, a
      `type = "parameters"` request against a design with no tuned parameters,
      and an unrecognized `type` (which names the allowed values).
- [x] AC6: `vdiffr` snapshots pin both views for a deterministic fixture;
      `_pkgdown.yml` carries the new method, `NEWS.md` says what a user can now
      see and why it matters, and the vignette plots the disagreement it
      currently only describes.
- [x] AC7: `devtools::test()` clean and `devtools::check()` clean — 0 errors, 0
      warnings, NOTEs justified — with `ggplot2` in Imports, and
      `devtools::document()` producing no diff.

## Coverage

- AC1 → T1, T3, T5
- AC2 → T2, T3
- AC3 → T2, T3
- AC4 → T4, T5
- AC5 → T6
- AC6 → T7, T8
- AC7 → T1, T8

## Tasks

- [x] T1: Add `ggplot2` to Imports and `vdiffr` to Suggests in `DESCRIPTION`;
      `devtools::document()`; confirm the existing suite stays clean with the
      new hard dependency in place.
- [x] T2: Failing tests for the parameters view — folds agreeing, folds
      disagreeing, a failed fold, and a completed fold missing a parameter —
      asserting on `ggplot_build()$data` and the stated contributing count.
- [x] T3: Implement `autoplot.nested_results(type = "parameters")` in a new
      `R/nested-results-plot.R`. Stack `.selected` with `do.call(rbind, ...)`
      before reading a parameter out of it (a list column of one-row tibbles
      answers `$mtry` with `NULL`, which rendered "0 distinct values" in M06),
      and take fold labels from `fold_ids()` (`R/nested-results.R:263`).
- [x] T4: Failing tests for the performance view, including that the marked
      central value is the one `summarize_folds()` produces and that the IP3
      caveat is present in the plot's labels.
- [x] T5: Implement `type = "performance"` over `per_fold_metrics()` and
      `summarize_folds()`, and the `type` dispatch itself.
- [x] T6: The three error branches — tests first, then `cli_abort()` calls
      matching the `check_*()` idiom in `R/checks.R`.
- [x] T7: `vdiffr` snapshots for both views on a deterministic fixture from
      `helper-orchestration.R`; roxygen with an `@examplesIf` guard; the
      `_pkgdown.yml` reference row.
- [x] T8: `NEWS.md` entry; the vignette section plotting its disagreement;
      `devtools::check()` clean.

## Work log

- 2026-07-26: created by /milestone-plan, promoting the plotting candidate row split out of M02 (whose parallelism half became M07); gate settled one `autoplot()` with a `type` argument and `ggplot2` to Imports with `vdiffr` in Suggests (D-019), leaving the three other candidate shapes as rows.

- 2026-07-26: T1 — `ggplot2` to Imports, `vdiffr` to Suggests, `autoplot` re-exported beside `collect_metrics` so a bare `autoplot(x)` dispatches; `document()` clean, suite clean at 1028 passing / 0 failures with the new hard dependency in place.

- 2026-07-26: T2/T3 — parameters view. Tests written first and observed red for the right reason (ggplot2's `autoplot.default()` refusing the class), then green at 18 assertions.
- 2026-07-26: T4/T5 — performance view. Deviation from plan order: `plot_performance()` was authored in T3's file before T4's tests, so tests-first did not hold for this half. Teeth proven by inversion instead — five mutations each turn the suite red: dropping `scale_x_discrete(drop = FALSE)` (FAIL 2), removing the marked-estimate rule (FAIL 6), perturbing that estimate by 1e-7 (FAIL 3, so the equality is exact and not `expect_equal()`'s tolerance), dropping IP3's caveat (FAIL 1), imputing an absent selection as 0 (FAIL 2).

- 2026-07-26: T6 — three error branches, all in the `R/checks.R` idiom; `check_any_completed()` gained an `action` argument so plotting and summarizing refuse the same object in their own words rather than in a shared one. 45 assertions; four more inversions red (borrowing summarize's wording FAIL 1, no completed-fold check FAIL 1, `check_plot_type()` accepting anything FAIL 5, empty plot instead of a refusal FAIL 2).

- 2026-07-26: T7 — four vdiffr snapshots (agreement, disagreement, a failed fold's gap, the performance view). Rendering them found two defects no built-data assertion could see: the parameters subtitle was clipped at 7 inches (now two lines), and a unanimous integer parameter was given fractional breaks, labelling a flat row of identical choices 2.950/2.975/3.000 — a plot about disagreement inventing some. Whole-number breaks when every drawn value is one, default breaks otherwise; pinned by test and by inversion (FAIL 4).

- 2026-07-26: review returned M08 to `in-progress` (first return). AC3 fails as written: both subtitles state a fold count that is false whenever contribution is per-metric or per-parameter rather than per-fold, so the tick was unticked. Four findings actioned — F1 (95) and F2 (95) the false counts, F3 (92) whole-number breaks defeated by a mixed grid, F4 (90) a metric silently dropped and an all-NA object erroring from inside ggplot2. F5 (78) and F6 (78) logged below threshold. All 6 CI jobs green at the reviewed commit.
- 2026-07-26: T8 — NEWS entry (four bullets); the vignette plots both views beside the numbers it already reported, with `fig.alt` on each. Its real figure shows `mtry` splitting 5/8/5/8/5 while `min_n` is unanimous at 2, so per-parameter instability is legible. `devtools::check()` 0 errors / 0 warnings / 0 notes with the vignette rebuilt from the tarball; `document()` no diff; `pkgdown::check_pkgdown()` clean. Status to `review`.

## Decisions

- 2026-07-26 (T1 gate): Both views share a fold-on-x layout — one point per
  outer fold, folds in design order, the selected value or score on y, one
  panel per parameter or metric. Agreement reads as a flat row and
  disagreement as scatter, no two points can overlap, and it matches the order
  `print.nested_results()` lists choices in. Rejected: a count-per-value
  distribution (discards fold identity, so a fold that is an outlier on every
  parameter is invisible); the transpose (a numeric parameter reads
  left-to-right where a value is expected on y).
- 2026-07-26 (T1 gate): Every *attempted* fold keeps its slot on the x axis and
  a failed one draws no point, so the shortfall is visible in the figure and
  not only in the stated count, which is the part a crop removes (IP4).
  Rejected: dropping failed folds from the axis (a cropped figure then looks
  like a complete design).
- 2026-07-26 (T1 gate): IP3's obligation is discharged in the performance view
  by a precise y-axis label naming the quantity plus a subtitle carrying the
  caveat, because ggplot2 renders a subtitle into the image itself and it
  therefore survives being exported into a slide or a paper, detached from the
  console and the help page. Rejected: a caption (the part readers skip and a
  tight crop loses first); the title (strongest placement, but spends the title
  on a disclaimer and reads as scolding on every plot). The RB tripwire on AC4
  is discharged here rather than escalated, at the maintainer's choice at the
  gate.

## Review

_Reviewed 2026-07-26. PR #8. Evidence gathered by command on the branch at
`0066062`; the 17 `test_that` blocks in `test-nested-results-plot.R` are cited
by their descriptions and assertion counts, from a fresh
`testthat::test_local()` run (51 assertions, 0 failures, 0 warnings, 0 skips)._

**AC1 — both views, default, bare dispatch.** `NAMESPACE` carries
`S3method(autoplot,nested_results)`, `export(autoplot)` and
`importFrom(ggplot2,autoplot)`, so `autoplot(x)` dispatches with only
`nestedtune` loaded. "the parameters view is the default and both views are
ggplots" (3) confirms a `ggplot` back from both `type` values and that
`autoplot(res)` builds point data identical to `autoplot(res, "parameters")`.

**AC2 — selections keyed by fold, from the built plot.** "the parameters view
draws one point per completed fold" (4): the agreement fixture draws three
points at one value, labelled Fold1–Fold3 in panel `num_comp`. "folds that
disagree are drawn at their own values, keyed by fold" (2): M04's disagreement
fixture draws 4, 4, 4, 3 *in fold order*, so a plot with the right values in the
wrong order fails. Both read `ggplot_build(p)$data`; nothing asserts on pixels.

**AC3 — nothing imputed, the shortfall stated.** "a failed fold keeps its place
on the axis and draws no point" (2): axis labels stay Fold1/Fold2/Fold3 while
points are Fold1/Fold3 only. "a completed fold with no value for a parameter is
not imputed" (2): same outcome for a fold that ran. "the parameters view states
how many folds contributed" (2) and "a failed fold keeps its slot and
contributes no score" (4): subtitles read "3 of 3 outer folds" whole and "2 of 3
outer folds" partial, in both views. `contributed()` derives the pair from
`nrow(x)` and `sum(x$.completed)` at plot time, never from the stamped
attribute. Inversion: dropping `scale_x_discrete(drop = FALSE)` fails 2,
imputing an absent selection as 0 fails 2.

**AC4 — the marked estimate, exactly; IP3 carried.** Verified independently of
the suite at 17 significant digits: the built rule's `yintercept` values
`1.4022238388365345`, `0.70821188807412516` equal `collect_metrics(res)$mean`
with `identical()` TRUE. "the marked estimate is the number collect_metrics
reports" (2) asserts it with `expect_identical`; inversion by 1 part in 1e7
fails 3, so the equality is exact and not inside edition 3's 1.5e-8 tolerance.
The subtitle reads verbatim: "3 of 3 outer folds contributed a score. The line
marks the nested estimate. / It describes the tune-and-fit procedure, not a
model you can deploy." — pinned with the y label "Score on the held-out outer
fold" by "the performance view says the estimate is not a model's score" (4);
removing the caveat fails 1. The `ip-touching` tripwire was discharged at the
pre-implementation gate rather than escalated, at the maintainer's choice, and
the rendered figure was inspected before merge.

**AC5 — three refusals in the `R/checks.R` idiom.** "a run where no fold
completed is refused, in plotting's own words" (3): both views abort with
"nothing to plot" while `collect_metrics()` still says "nothing to summarize" on
the same object. "a design with no tuned parameters points at the other view"
(3): aborts naming `type = "performance"`, and that view still returns a
`ggplot`. "an unrecognized type is refused by name" (5): a misspelling, a
reordered pair, a number and `NA_character_` all refused with both allowed
values named. Inversions: borrowing summarize's wording fails 1, no check at all
fails 1, accepting any `type` fails 5, an empty plot instead of a refusal fails 2.

**AC6 — pictures and documentation.** Four vdiffr SVGs under
`_snaps/nested-results-plot/` (agreement, disagreement, a failed fold's gap, the
performance view), stable across consecutive runs. `_pkgdown.yml:28` carries
`autoplot.nested_results` and `pkgdown::check_pkgdown()` reports "No problems
found". `NEWS.md` gains four bullets saying what a user can now see and why it
matters. The vignette plots both views at `nested-cv.Rmd:189` and `:223`, each
with `fig.alt`; its real figure shows `mtry` splitting 5/8/5/8/5 while `min_n`
is unanimous at 2. No milestone number appears in any user-facing file.

**AC7 — clean toolchain.** Fresh `devtools::check(document = TRUE)` on the
branch: **0 errors, 0 warnings, 0 notes**, 6m13s, with the vignette re-built
from the tarball and the full suite run inside it. `document()` produced no diff
(the only modified path afterwards is this milestone file). `ggplot2` is in
Imports in `DESCRIPTION`.

### Consistency gate

Universal cairn-file checks — `cairn_validate` **exit 0, all 16 checks PASS**,
7 advisories OK, none WARN. `cairn_impact --changed` **skipped**: the diff
touches no `DESIGN.md` principle text (`git diff main..HEAD -- cairn/DESIGN.md`
is empty), and M08 works under IP3/IP4/GP1/GP3/GP4 without amending any.
Coverage map complete, so no plan gap to send back.

Toolchain checks, from the profile's `consistency-gate` slot — `document()` no
diff ✓ · generated files (`NAMESPACE`, `man/`) regenerate rather than
hand-edited ✓ · README knitting **N/A**, the repo has `README.md` and no
`README.Rmd` ✓ · `pkgdown::check_pkgdown()` "No problems found" ✓ · `NEWS.md`
carries this milestone's user-visible changes with no milestone numbers ✓ · no
new top-level files, so no `.Rbuildignore` entry owed ✓ · full `check()` clean ✓.

### Independent review

Three fresh-context lenses, none of which saw the implementation.

**[S] blame-history — no findings.** Traced every modified line to the milestone
that wrote it. Its load-bearing check: `check_any_completed()` gained
`action = "summarize"` as a *named* argument before `call`, and the sole prior
call site passes no positional second argument, so `collect_metrics()`'s message
is preserved verbatim — no drift in the M03 guarantee or the M04 wording fix. It
also confirmed the plot reuses `selection_params()`/`fold_ids()` rather than
reimplementing column access, so M04's false-instability fix is not reintroduced,
and that D-019 records the ggplot2 Import the diff makes.

**[S] prior-review regression — no findings.** GitHub inline-comment probe
returned `[]`, so per the probe gate the per-PR walk was skipped; primary
evidence was the archived `## Review` sections of M01–M07 plus the ROADMAP
candidates. Checked M06 F1/F2/F5 (vignette claims must be produced, not typed —
both new chunks are executed), M06's `.selected` list-column lesson (the plot
indexes elements rather than `$`-ing the column), and M03/M04's derive-from-
columns rule. It correctly classified the "tests use tune's default metric set"
candidate (M05 F1) as pre-existing rather than introduced here.

**[O] diff-bug — six findings, four actionable.** Scored by an independent
Sonnet scorer that did not generate them. Every code finding was reproduced by
execution in this session before triage.

- **F1 (95) — actioned.** The performance view's subtitle claims folds for a
  rule that averaged fewer. `contributed()` reports `sum(x$.completed)` of
  `nrow(x)` once for the whole figure, but each panel's rule averages only the
  folds that scored *that* metric. Reproduced: with one fold `NA` on `rmse` the
  subtitle reads "3 of 3 outer folds contributed a score" while
  `collect_metrics()` reports `n = 2` for `rmse` and `print` says "(from 2
  folds)" on that metric's own line — the divergence `print_estimate()`
  (`R/nested-results-print.R:232`) exists to prevent.
- **F2 (95) — actioned.** The parameters view's subtitle turns an absent
  selection into apparent unanimity. Reproduced: with fold 2 completed but
  recording no value, the subtitle reads "3 of 3 outer folds contributed a
  selection" while two points are drawn at one height — a reader concludes three
  folds agreed. `print` says "all 2 folds that chose it agree; 1 recorded no
  value". This is the false-*agreement* mirror of the false-instability error
  `print_one_parameter()` calls the most expensive thing it can print.
- **F3 (92) — actioned.** The whole-number-breaks fix is defeated by any
  non-integer parameter in the same design: `value_scale()` is handed the value
  column pooled across parameters, while `facet_wrap(scales = "free_y")` gives
  each its own axis. Reproduced: a `penalty` column beside a unanimous
  `num_comp` puts that panel back on 2.950 / 2.975 / 3.000 / 3.025 — verbatim
  the defect this milestone's T7 log says was fixed. Common in practice
  (glmnet, xgboost, svm_rbf all mix an integer with a continuous parameter).
- **F4 (90) — actioned.** `facet_wrap()` defaults to `drop = TRUE`, which is not
  applied to metrics as `scale_x_discrete(drop = FALSE)` is to folds.
  Reproduced: a metric `NA` in every fold vanishes from the figure with no trace
  while the subtitle still claims full contribution; and with every metric `NA`,
  `autoplot()` returns a `ggplot` that errors when printed, from inside ggplot2
  ("Faceting variables must have at least one value."), where `print` on the
  same object says "NA (from 0 folds)" without complaint.
- **F5 (78) — below threshold, logged.** `cairn/DESIGN.md:255` still lists the
  six-package dependency surface; this diff makes it seven. The reviewer also
  noted no Architecture paragraph for `R/nested-results-plot.R` — that half is
  pre-existing, since `R/parallel.R` has none either and DESIGN.md:223 still
  says the loop is "safe to parallelize later" after M07 did it. The stale
  dependency line is corrected in the return regardless: DESIGN is
  current-knowledge and this diff is what made it false.
- **F6 (78) — below threshold, logged.** `ambiguous_metrics()`/`metric_panel()`
  ship unpinned (the reviewer verified the two-estimator path correct by hand),
  as does a numeric parameter co-plotted with a character one. The third part —
  no test reads either subtitle — is why F1 and F2 survived a 51-assertion
  suite, and is absorbed by their fixes.

Sound on inspection, recorded so the return does not re-litigate them:
`check_any_completed(action=)` leaves `collect_metrics()`'s message
byte-identical; `check_plot_type()` reproduces `match.arg()`'s accept/reject set
including partial matches and a reordered pair; row subsets re-derive counts and
axes; a repeated design's `id`/`id2` labels come through `fold_ids()` in both
views; `NA`, list-valued and non-numeric selections all agree with `print`;
`whole_number_breaks()` is sane across negative, unit, single-value, 1e15 and
1e6-span limits.

### Gate outcome — returned to `in-progress`

**AC3 fails as written.** It requires that "the plot states how many of the
requested folds contributed"; F1 and F2 show it stating a number that is false
whenever contribution is per-metric or per-parameter rather than per-fold. The
tick recorded above was premature — the evidence behind it covered the *points*
for those cases and the *subtitle* only on fixtures where completed and
contributed coincide, so it never met the criterion's second clause. Unticked.

AC1, AC2, AC4, AC5, AC6 and AC7 stand on their recorded evidence: F1 does not
touch AC4's exactness clause (the marked value is still bit-identical to
`collect_metrics()`), and AC5's three enumerated branches all fire — F4's crash
is a fourth situation the criterion does not enumerate, which is why it is a
finding rather than an AC5 failure.

Required before re-review, in addition to whatever the implement gate decides:

1. Both subtitles must state a count that is true of what the figure draws. Note
   the shape mismatch the fix has to resolve: contribution is per panel (per
   metric, per parameter), while the subtitle is per figure — `print` solves it
   by moving the qualifier onto the metric's own line. Panel-level text and a
   reworded figure-level sentence are both open; this is an implement-gate call.
2. `value_scale()` must decide per panel, not over the pooled column.
3. Metrics must keep their panel as folds keep their axis slot, and the
   all-`NA` case must fail (or draw) deliberately rather than from inside
   ggplot2.
4. Tests must read the subtitle text, and `axis_labels()` must be able to read a
   panel other than the first — its `panel_params[[1L]]` is what hid F3.

First return for this milestone; the thrash rule's third-return threshold is not
in play, and no criterion has failed twice.

CI on PR #8: all 6 jobs green (ubuntu release/devel/oldrel-1, macOS, Windows,
test-coverage) at the reviewed commit — the vdiffr snapshots did not prove
platform-fragile, which retires that pre-review concern.
