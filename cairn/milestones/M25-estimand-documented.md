# M25: The number has a name, and the docs say which

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP3, GP5
- **Branch/PR:** `m25-estimand-documented` · https://github.com/jmgirard/nestedtune/pull/26

## Goal

Extend M06's guide so the nested estimate is named as a published quantity,
its bias direction and its `std_err` carry sources, and the guide says when
nesting changes the answer and when it does not.

## Scope

**In:** `vignettes/nested-cv.Rmd` and the roxygen on
`collect_metrics.nested_results()` (`R/nested-results.R:127-146`). Name the
estimand as the k-fold test error of the tune-and-fit procedure at the outer
folds' reduced training size, disclosing in one clause that the marginal
quantity is what you cannot infer. Source the bias-direction claim, which is
uncited today at `vignettes/nested-cv.Rmd:133-136` and
`R/nested-final-fit.R:62`. Say why `std_err` must not be read as an interval,
in the man page as well as the vignette (closes M02 review finding F5).
Warn that two nested estimates cannot be compared inferentially. Add a
when-it-matters section, and correct the `mtcars` justification at
`vignettes/nested-cv.Rmd:81-84` that the new section contradicts. Reader-facing
citations are full author-year with a References section; cairn citekeys stay
internal.

**Out:**
- Any interval or inference on the estimate → the G6 candidate row, narrowed by
  this plan to the interval half.
- Re-cutting the vignette onto a p > n example where nesting demonstrably earns
  its cost → candidate row (it invalidates every inline number and both
  figures).
- The `parsnip::null_model()` analytic oracle and the degenerate-grid invariant
  → candidate rows.
- A synthesis note reconciling the shelf's five stability notions → candidate
  row.
- Changing IP3's text → not proposed; it would need a D-entry.

## Acceptance criteria

- [x] AC1: `vignettes/nested-cv.Rmd` names what `collect_metrics()` reports as
      the k-fold test error of the tune-and-fit procedure, states that the
      training sets are the outer analysis sets and so smaller than the full
      data, and names at least two quantities it is not — one of them the risk
      of the deployed model. Cites Bayle, Janson & Mackey (2026) for the named
      quantity and Luo & Barber (2026) for why the marginal version is not
      inferable here. Reconciled with the existing claim at
      `vignettes/nested-cv.Rmd:33`.
- [x] AC2: The bias-direction statement cites Varma & Simon (2006) (+4.2 points
      against a 50.0% truth, n = 40, `references/varma2006.md` p. 6) and
      Wilimitis & Walsh (2023) (1–2% AUROC and 5–9% AUPR pessimistic,
      n = 41,121, `references/wilimitis2023.md` p. 8), names reduced training
      size as the mechanism, and states in the same paragraph that a single run
      at this vignette's sample size can land either way. No number in that
      paragraph is computed inline from the vignette's own run.
- [x] AC3: `collect_metrics.nested_results()`'s roxygen states that `std_err`
      must not be read as a confidence interval and why, citing Bengio &
      Grandvalet (2004) for the absence of a universally unbiased variance
      estimator and Gauran, Ombao & Yu (2025) for variance-denominator Type I
      error measured near 0.36 against a nominal 0.05 inside a nested design.
      `man/collect_metrics.nested_results.Rd` regenerates with no further diff.
- [x] AC4: The vignette states (a) that two nested estimates cannot be compared
      inferentially from `collect_metrics()` output, and (b) that fold-to-fold
      disagreement is expected wherever candidates perform near-identically —
      a condition consistent with this vignette's own run, in which `mtry`
      splits across folds while `min_n` does not. Both cite Bayle, Janson &
      Mackey (2026).
- [x] AC5: The vignette carries a section stating when nesting changes the
      reported number materially and when it does not, citing Tibshirani &
      Tibshirani (2009) (material only at p ≫ n), Vabalas et al. (2019) (the
      flat-CV bias persists to n = 1000, and nesting feature selection matters
      more than nesting tuning) and Wilimitis & Walsh (2023) (a measured null
      result at n ≫ p with a small grid). `vignettes/nested-cv.Rmd:81-84` no
      longer claims `mtcars` is where the optimism is largest.
- [x] AC6: A `testthat` test asserts every author-year citation in the
      vignette's References section maps to an existing
      `cairn/references/<citekey>.md`, and skips when `cairn/` is absent, as
      it is in the built package (`.Rbuildignore:1`; the pattern is
      `tests/testthat/test-ci-workflows.R:1-15`).
- [x] AC7: `Rscript -e 'devtools::check()'` clean per `cairn/PROFILE.md`'s
      consistency-gate — 0 errors, 0 warnings, NOTEs justified — run on a
      machine with `ranger` installed, so the vignette's
      `requireNamespace()`/`knit_exit()` guard
      (`vignettes/nested-cv.Rmd:42-54`) does not let the new material past
      unexecuted. `pkgdown::check_pkgdown()` passes and the article renders.

## Coverage

- AC1 → T2
- AC2 → T3
- AC3 → T6
- AC4 → T4
- AC5 → T5
- AC6 → T7
- AC7 → T8

## Tasks

- [x] T1: Draft the References section and its entry list, and decide the
      author-year form each of the six sources takes in prose. Reader-facing
      text carries no cairn citekey.
- [x] T2: Name the estimand in the "What to report, and why" section
      (`vignettes/nested-cv.Rmd:124-163`), reconciling it with line 33.
- [x] T3: Replace the uncited bias-direction clause at
      `vignettes/nested-cv.Rmd:133-136` with the sourced paragraph, no inline
      `r` values in it (M06 review F2: an optimism claim refuted by the
      vignette's own output). Carry the same correction to
      `R/nested-final-fit.R:62`, which repeats the uncited claim.
- [x] T4: Add the comparison warning, and give the selection-disagreement
      section (`vignettes/nested-cv.Rmd:165-215`) its mechanism.
- [x] T5: Write the when-it-matters section and correct
      `vignettes/nested-cv.Rmd:81-84`.
- [x] T6: Add the `std_err` caveat to `collect_metrics.nested_results()`'s
      roxygen (`R/nested-results.R:127-146`); `devtools::document()`.
- [x] T7: Write the citation-resolution test.
- [x] T8: Render the vignette and read it end to end as a reader would
      (LESSONS, M08: assertions on a built object cannot see the part a reader
      meets); NEWS.md entry; full `devtools::check()` and
      `pkgdown::check_pkgdown()`.

## Work log

- 2026-07-31: created by /milestone-plan.
- 2026-07-31: implement started on `m25-estimand-documented`, cut from `main` at 4fd429e.
- 2026-07-31: verified the audit's reproduction of the vignette run independently before writing anything resting on it — `mtry` 5/8/5/8/5, `min_n` 2 in all five folds, RMSE 2.46 (SE 0.445). AC4(b)'s condition holds.
- 2026-07-31: T1 done. References section carries the six reader-facing sources; prose form is author-year (`Varma and Simon (2006)`, `Bayle et al. (2026)`). `bengio2004` and `gauran2025` are roxygen-only per AC3 and get `@references` on the man page instead.
- 2026-07-31: T2 done. Estimand named as the k-fold test error of the tune-and-fit procedure (Bayle et al., 2026), with the two quantities it is not — the deployed model's risk, and the training-set-averaged version, the latter carrying Luo and Barber (2026)'s ratio argument. Intro line 33 reconciled: the nested estimate is reported *in place of* a model score, not as one.
- 2026-07-31: T3 done. Bias-direction paragraph sourced to Varma and Simon (2006) (54.2% against a 50.0% truth at n = 40, attributed to training on 39 rows) and Wilimitis and Walsh (2023) (most pessimistic method compared, ~1-2% AUROC / 5-9% AUPR on 41,121 visits), with the mechanism named and a second paragraph saying the gap is a property of the estimator and not a prediction about this run. No inline `r` in either. Same correction carried to `R/nested-final-fit.R`'s `@section What to report`, which repeated the uncited claim, plus an `@references` block; `document()` regenerated `man/nested_final_fit.Rd`.
- 2026-07-31: T4 done. Comparison warning placed after the `std_err` paragraph, framed on the absence of any valid interval first and Bayle et al. (2026)'s difference-instability second, so the citation carries only what it establishes. Disagreement mechanism added to "What each fold chose", stated over the condition that actually holds here — the run splits on `mtry` and is unanimous on `min_n`, and the paragraph names both.
- 2026-07-31: T5 done. New "When this is worth the cost" section before Reproducibility, built on the room-to-overfit framing: Tibshirani and Tibshirani (2009) for the p >> n threshold (0.384 against a 0.5 truth at n = 40, p = 1000, versus under 3 points at n = 400, p = 100), Wilimitis and Walsh (2023) for the tall-data null result at 41,121 visits, Vabalas et al. (2019) against reading that as "small data is fine" (flat CV still above chance at n = 1000). Carries the scope disclosure `references/vabalas2019a.md` asked for -- leaky feature selection outranks leaky tuning, so selection belongs in the recipe. Lines 81-84 corrected and now point forward to the section.
- 2026-07-31: T6 done. `@section Reading std_err` on `collect_metrics.nested_results()` plus an `@references` block; `document()` regenerated the Rd. Caught and removed a false cross-reference in my own draft — it pointed at a "delegation note" in `vignette("nested-cv")` that does not exist.
- 2026-07-31: needing the nominal level for the man page settled an open question on `references/gauran2025.md`: the figure captions state the ξ = 0 column holds Type I error rates and p. 1098 gives α = 0.05, so the column alignment that page recorded as inferred is confirmed. Corrected in place and marked; individual cell values are still text recovered from images.
- 2026-07-31: T7 done. `tests/testthat/test-vignette-citations.R` asserts three directions, not one — prose citation has a References entry, entry resolves to a shelf page, entry is cited — because a one-way check is satisfiable by deleting whichever side is inconvenient. Code chunks are stripped before scanning prose; markdown emphasis is tolerated on the surname; `<key><letter>` suffixes resolve, which is the shelf's own convention (`stone1974a`/`b`, `vabalas2019a`).
- 2026-07-31: T7 verified by inversion per guard-doctrine §1 — a prose citation with no entry, an entry with no shelf page, and an entry never cited each turned the suite red (1, 3 and 1 failures); restored to green with no diff. The built-tarball skip path is exercised for real by `R CMD check` at T8.
- 2026-07-31: guard-doctrine §8 [O] certification of T7's guard returned ten findings, four HIGH. The description layer did not match what was pinned, and one gap was live on shipped text: the matcher read only narrative `Surname (YYYY)`, so the vignette's own `(Bayle et al., 2026)` at line 139 was invisible and green only because the same source is cited narratively elsewhere. Guard reworked rather than re-described.
- 2026-07-31: guard rework — parenthetical and comma-list author forms now match (`Gauran, Ombao and Yu (2025)` was building a key from the second surname); inline `r` spans stripped like fenced chunks, which the header's own rationale already covered; shelf resolution now opens the page and requires its `**Citation.**` paragraph to name the surname and year, so an emptied or repurposed page fails; `R/` roxygen citations added to the sweep; particle surnames (`van der Laan`) parse whole; unparseable entries get their own assertion rather than being misreported under resolution; direction 1's skip replaced by an assertion that citations exist at all.
- 2026-07-31: the reworked guard found two defects in itself before I did — the three-author narrative form, and a fixed 7-line citation window that overran into `**Provenance.**`, whose `sources/<citekey>.pdf` path contains the surname, so every page matched its own key regardless of what its citation said. Bounded to the citation paragraph. Re-verified by inversion across eight cases: parenthetical-with-no-entry, emptied page, repurposed page, roxygen citation with no page, heading rename, narrative-with-no-entry, uncited entry all red; inline `r` correctly does not fire. Tree restored clean after each.
- 2026-07-31: two [O] findings accepted rather than fixed, and disclosed in the guard's header — the matcher over-fires on any capitalized token before a parenthesized year (`Appendix (2019)`), chosen deliberately since a false red is a reword and the opposite error is a citation losing its evidence; and roxygen `@references` entries are not parsed as entries, so an orphaned one is not detected. Scope note: AC6 asks only for the vignette's References section, and the guard now also covers `R/` roxygen — more than the criterion requires, not less.
- 2026-07-31: T8 done. NEWS.md entry; `pkgdown::check_pkgdown()` clean; `devtools::check()` **Status: OK — 0 errors, 0 warnings, 0 notes** on the shipped state, run with `ranger` installed so the vignette's `knit_exit()` guard did not let the new material past unexecuted.
- 2026-07-31: reading the rendered guide end to end caught three things no assertion would have. The pessimism paragraph's evidence was entirely in classification units (accuracy, AUROC, AUPR) while the worked example is regression, so Wilimitis and Walsh's regression datapoint (nested MAE 2.39 against 2.38) was added and the framing changed from "two measurements bracket it" to the two ends of the sample-size range. "The same classifier" was wrong — Tibshirani and Tibshirani swap LDA for shrunken centroids in the p >> n cell — and is now named correctly. And "nested came back marginally worse" read as a verdict on the method rather than as the pessimism already explained, so it now says nesting bought nothing and names the connection.
- 2026-07-31: checked for the contradiction guard-doctrine §9 warns about, a section disagreeing with itself: the final-fit comparison already computes its direction with `ifelse()` and says not to read the direction as the lesson, which agrees with the new pessimism paragraph's caution rather than fighting it. No change needed.
- 2026-07-31: criteria audit ([O], fresh context) returned seven findings. Three fixed before the gate — AC3 re-sourced off `bates2023` (whose own reference page records the statistic as different and the effect unmeasured for it) onto `bengio2004` + `gauran2025`; AC4(b)'s "fine grid" condition dropped as false of this vignette's six-point grid and unanimous `min_n`; AC7 pointed at PROFILE's gate definition and required `ranger` present, since `knit_exit()` made "vignette rebuilt" vacuously satisfiable. Three became gate questions (estimand choice, the `mtcars` claim, citation form); one (AC6 checking a superset of "citations this milestone adds") accepted as satisfied a fortiori — there are zero such citations in the tree today.
- 2026-07-31: plan gate chose naming the estimand as the conditional k-fold test error (bayle2026's R_n) over bates2023's marginal Err because Err is the quantity luo2026 proves is not inferable at N/n ≈ 1.11, so naming it would overclaim; falsified by a source establishing that the outer-fold mean estimates the marginal quantity at this sample ratio.
- 2026-07-31: plan gate chose correcting the `mtcars` justification over re-cutting the vignette onto a wide example because the re-cut invalidates every inline number, both figures and the runtime budget; falsified by the corrected paragraph proving unwritable without the example itself changing.
- 2026-07-31: plan gate chose full author-year citations with a References section over bare cairn citekeys because `cairn/` is stripped from every shipped form while the vignette renders publicly; falsified by the References section proving unmaintainable against the shelf.
- 2026-07-31: plan chose keeping the roxygen caveat (AC3) in this milestone over splitting it out because it is ~6 lines and closes M02 review finding F5, which the G6 row has carried since 2026-07-25; falsified by the roxygen change growing past a task.

## Decisions

## Review

**Evidence, per acceptance criterion.** Gathered fresh on
`m25-estimand-documented`; PR #26.

- **AC1** — `vignettes/nested-cv.Rmd` names the quantity "the **k-fold test
  error of the tune-and-fit procedure** (Bayle et al., 2026)", ties it to "the
  particular analysis sets these folds drew", and gives both exclusions: "Not
  the risk of the model you deploy" and "Not the same quantity averaged over
  training sets", the latter citing Luo and Barber (2026). Line 33 reconciled —
  reported "in its place", not as the model's score.
- **AC2** — carries Varma and Simon (2006) at 54.2% against a 50.0% truth,
  n = 40, 4.2-point overshoot attributed to 39 rows against 40; and Wilimitis
  and Walsh (2023) at 1-2% AUROC / 5-9% AUPR on 41,121 visits plus their
  regression MAE 2.39 against 2.38. Mechanism named as training-set size.
  States the vignette's own numbers could land the other way. Inline-`r` count
  over both paragraphs, measured by `awk` range: **0**.
- **AC3** — `R/nested-results.R`, `@section Reading std_err`: "It is **not** a
  confidence interval", Bengio and Grandvalet (2004) for the absent universally
  unbiased estimator, Gauran, Ombao and Yu (2025) for 36% and 40% in the worst
  cells against a nominal 5%. `devtools::document()`: **0** changed files under
  `man/`, `NAMESPACE`.
- **AC4** — (a) "there is no valid interval here to subtract", with Bayle et al.
  (2026) for difference-instability. (b) disagreement expected "wherever the
  candidates in question perform about equally well", citing Bayle et al.
  (2026), naming this run's split `mtry` against unanimous `min_n`.
- **AC5** — `## When this is worth the cost` present. Wrap-aware scan finds
  Tibshirani and Tibshirani (2009), Vabalas et al. (2019) and Wilimitis and
  Walsh (2023). "the optimism it introduces is largest": **0** occurrences.
- **AC6** — `tests/testthat/test-vignette-citations.R`, 8 assertions,
  `FAIL 0 | WARN 0 | SKIP 0 | PASS 8` under `devtools::test()`; verified red
  across 8 inversions at implement time. _(Corrected at review, finding C1: this
  line first claimed the built-tarball path "is exercised by `R CMD check`". It
  is not — probing both layouts shows every `test_path("..", "..", ...)` here
  resolves outside the source tree under check, so all six tests skip there and
  CI never runs this guard. The header now says so. The criterion is met by the
  source-tree run, which is where the vignette and the shelf are edited.)_
- **AC7** — `devtools::check()` with `ranger` installed: **Status: OK, 0 errors,
  0 warnings, 0 notes**, re-run after the review fixes. `pkgdown::check_pkgdown()`:
  "No problems found."

**Consistency gate.** `cairn_validate` exit 0, all 16 checks PASS; 18 advisory
`references staleness` warnings, shelf-wide and pre-existing. `document()`
no-diff. No `README.Rmd`. NEWS entry present. No new top-level file needing an
`.Rbuildignore` entry. No principle text changed, so `cairn_impact` does not
apply. CI on PR #26 green across ubuntu release/devel/oldrel, macOS, Windows,
coverage and build. Returns to `in-progress`: **0** — the thrash rule does not
fire.

**Independent review.** Three fresh-context lenses (diff-bug [O]; blame-history
[S]; prior-review [S]) reported 28 candidate findings, scored by a fourth agent
that generated none of them. **Seven scored 80 or above.** All seven fixed on
the branch:

- **A1 (97)** — `cairn/references/gauran2025.md` settled a standing open
  question citing "p. 1098" and "p. 1727" for the nominal α = 0.05. Those are
  line numbers in the `pdftotext` output, mistaken for pages; the document has
  37. Confirmed by extracting the PDF page by page: the α = 0.05 statement is on
  **p. 17**, the figure captions on **pp. 16–19**, the summary table on
  **p. 23**. Substance holds, citations did not. Corrected in place and marked.
- **A6 (85)** — "from percentage points at n = 40 to the third decimal at
  n = 41,121" was wrong (MAE 2.39 vs 2.38 is the second decimal) and asserted a
  cross-study trend no source supports. Replaced with two data points and an
  explicit refusal to read a trend into them.
- **A8 (85)** — "sat at chance across the whole range they tested" overstated
  Vabalas et al.; `vabalas2019a.md` records the real figure and flags this exact
  framing. Now "indistinguishable from chance at 96.5% of the sample sizes".
- **B1 (85)** — roxygen and NEWS said the number **is** the k-fold test error;
  it *estimates* it. Fixed on both surfaces, matching the vignette.
- **A9 (84)** — "when the features outnumber the observations" weakened
  Tibshirani's p ≫ n to p > n; the p ≫ n exemplar was also cherry-picked (SVM
  0.475 and a tree 0.498 in the same cell). Both fixed, and the paper's own
  posture — it argues for a cheap correction rather than nesting — is now
  disclosed.
- **B2 (82)** — roxygen said `std_err` "describes how much those folds varied",
  the loose reading the vignette explicitly corrects. Now states it is the
  precision of the mean, not the fold-to-fold spread.
- **C1 (82)** — the guard's header claimed `vignettes/` and `R/` stay reachable
  under `R CMD check`. Probed both layouts: they do not, and every test skips
  there. Header corrected; AC6 evidence corrected with it.

**Six sub-threshold findings actioned anyway**, because each was verifiably true
and sat inside a sentence one of the seven was already rewriting; fixing the
neighbour and leaving these would have shipped a known inaccuracy: A5 (78,
"most pessimistic of every method" → "among the most", plus the optimistic cell
disclosed), A12 (78, the estimand gloss read as marginal in the clause defining
the conditional quantity), A7 (76, "arithmetic rather than statistical" — the
training-size component is either-sign in Varma and Simon's own decomposition),
A4 (74, "understates" → "can misstate, typically downward"), A2 (72, "far more
often" over-generalized across the variance-denominator class; the worst cells
are 36% and 40%, now named), A3 (70, both sources study closely related rather
than identical quantities — now said in the man page).

**Fifteen findings logged, not actioned** (all below 80): C3 (75) direction 5
keeps a `skip_if` where direction 1 does not — a real asymmetry, left because
asserting roxygen citations exist would couple the guard to roxygen always
carrying them. C2 (65) four citation renderings the matcher misses, none present
today. D4 (65) the split-`mtry`/unanimous-`min_n` prose is hard-coded about a
build-time chunk — verified twice, but a version shift could falsify it. A10
(55) the coin-flip framing is the shelf page's extrapolation, labelled as such
there. A11 (55) the shipped ratio is right; the work log's plan-gate note says
"N/n ≈ 1.11" (a v = 10 figure) where this design is v = 5 and the vignette
computes 5/4 — the log is append-only history, so it is corrected here rather
than edited. C4 (50) every test skips on a vignette rename. D3 (50) the write-up
template still emits an SE, on an unmodified line. C5 (45) the year check can
match a DOI. D2 (40) preprint status not marked inline. D1 (25) a disclosed
limitation. H1, H2, H3, H4, P1 — the two history lenses' own verdicts were that
the mtcars reversal and the wording change are documented and deliberate, the
G6 row is byte-identical to main, M06 F1 is not reintroduced, and the GitHub
inline-comment probe returned empty so no PR-thread walk was owed.
