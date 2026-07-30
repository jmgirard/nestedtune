<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M19: A malformed design is refused at the driver, not at the tenth fold

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Branch/PR:** `m19-driver-design-guards` / https://github.com/jmgirard/nestedtune/pull/20

## Goal

Both drivers refuse a structurally malformed design or a preprocessor-less
workflow at the call the user wrote, instead of degrading to an all-folds-failed
result or a base-R error.

## Scope

**In:**

- `check_nested()` (`R/checks.R:80`) additionally requires every element of
  `splits` to be an `rsplit` and every element of `inner_resamples` to be an
  `rset`, naming the first offending position. Both drivers already call it
  (`R/nested-tune-grid.R:234`, `R/nested-final-fit.R:158`), so both inherit it.
- `check_workflow()` (`R/checks.R:7`) refuses a workflow carrying a model
  specification but no preprocessor, the sibling of the missing-model branch
  M18 added at `:37`.
- `eval_inside_spec()` (`R/checks.R:236`) takes the user's call, so its two
  aborts stop blaming `final_fit_worker()`.
- `@param resamples` on both drivers, and `NEWS.md`, state the requirement.

**Out:**

- Refusing a design for anything beyond the class of its two columns' elements
  — a zero-row inner `rset`, an `inner_resamples` length mismatched to `nrow()`,
  an `id` column disagreeing with the splits → candidate row. Only the two
  class checks have a measured baseline; the rest are unmeasured shapes.
- `check_inside_spec()`'s `call` (`R/checks.R:209`) — verified 2026-07-30 to
  already name the user's call, so there is nothing to fix.
- Reporting *every* offending position rather than the first → candidate row;
  no measured case has more than one, and the fix is a rewrite of the message
  rather than of the check.
- Upstream: `rsample::nested_cv()` admitting `inside = list()` at all, and its
  own error deparsing the data frame into the message (observed 2026-07-30) →
  the existing rsample#283 reporting track (M13), not this milestone.

## Acceptance criteria

All baselines below were verified by execution 2026-07-30.

- [x] **AC1.** Both drivers refuse a design holding a non-`rsplit` element in
      `splits` or a non-`rset` element in `inner_resamples`, via
      `cli::cli_abort()` naming `{.arg resamples}`, the first offending column
      and position, and what that element holds instead; `conditionCall()` is
      the user's call. Three baselines, three designs. (a)
      `rsample::nested_cv(d, outside = vfold_cv(v = 3), inside = list())` builds
      silently; `nested_tune_grid()` returns a `nested_results` with all three
      folds `.completed == FALSE` carrying tune's "The `resamples` argument
      should be an <rset> object", and `nested_final_fit()` aborts only because
      re-evaluating `inside` fails, from `eval_inside_spec()`, with
      `conditionCall()` `final_fit_worker(inside, data, env, seeds, object,
      grid, metrics)`. (b) A `nested_resamples()` design with a valid `inside`
      and `inner_resamples[[2]]` set to a string: `nested_final_fit()` returns
      an object with no complaint at all. (c) `splits[[1]]` set to a string:
      `nested_tune_grid()` records fold 1 as an "outer fit" failure carrying
      tune's "Each element of `splits` must be an <rsplit> object";
      `nested_final_fit()` raises base R's `$ operator is invalid for atomic
      vectors`, `conditionCall()` `x$splits[[1]]$data` — no nestedtune
      condition, no argument named.
- [x] **AC2.** Every `check_nested()` check refuses at both drivers with the
      same message, each naming its own call — including on the parts the final
      fit does not read (gate decision, 2026-07-30). Final-fit-only checks
      (`check_inside_spec()`) stay so: a design with no `inside` attribute runs
      to completion under `nested_tune_grid()` today and must still do so.
- [x] **AC3.** Both drivers refuse a workflow with a model specification but no
      preprocessor, naming `{.arg object}` with an `i` bullet stating the
      remedy, as the neighbouring `object` checks do; `conditionCall()` is the
      user's call. Baseline on `add_model(workflow(), <ranger spec>)`:
      `nested_tune_grid()` returns all three folds failed carrying workflows' "A
      formula, recipe, or variables preprocessor is required.";
      `nested_final_fit()` raises that same error, `conditionCall()`
      `check_workflow(workflow, pset = pset, call = call)`.
- [x] **AC4.** Every refusal added here fires before the entry `sample.int()`
      draw: in a session that has never drawn, `exists(".Random.seed", envir =
      globalenv())` is `FALSE` after each refused call. This discriminates where
      `identical(.Random.seed, before)` cannot — `restore_rng()`
      (`R/nested-tune-grid.R:464`) deliberately leaves a state it created in
      place, so identity holds even for a refusal that already drew and
      re-seeded (audit finding, 2026-07-30).
- [x] **AC5.** `eval_inside_spec()`'s two aborts name the user's call — the
      not-an-`rset` branch (`R/checks.R:263`) and the could-not-be-re-evaluated
      branch (`R/checks.R:249`), both giving `final_fit_worker(...)` today.
      `check_inside_spec()` is already correct and is not touched.
- [x] **AC6.** `@param resamples` on both drivers states that `splits` holds
      `rsplit` objects and `inner_resamples` holds `rset` objects, and
      `nested_final_fit()`'s "Only its inner specification and its data are
      used: the outer folds play no part in a final fit."
      (`R/nested-final-fit.R:26`) is rewritten, since AC2 makes it false.
      `NEWS.md` gains an entry naming the refusals. `devtools::document()`
      leaves no uncommitted diff — a regression guard, clean today.
- [x] **AC7.** The profile's `verify` slot is clean and `R CMD check` passes
      with no new NOTE.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2, T6
- AC3 → T3, T4
- AC4 → T6
- AC5 → T5
- AC6 → T7
- AC7 → T8

## Tasks

- [x] **T1.** Regression tests in `test-nested-tune-grid-checks.R` and
      `test-nested-final-fit-checks.R` for a non-`rset` `inner_resamples`
      element and a non-`rsplit` `splits` element, at both drivers, asserting
      message and `conditionCall()`. Red first — AC1's three baselines are what
      they currently produce. Cover AC2's negative half too: a design with no
      `inside` attribute still runs under `nested_tune_grid()`.
- [x] **T2.** Add the two element-class checks to `check_nested()`
      (`R/checks.R:80`), after the existing `id`/bootstrap branches so the
      cheaper whole-object checks still fire first.
- [x] **T3.** Regression test for the preprocessor-less workflow at both
      drivers, asserting the `i` bullet and `conditionCall()`.
- [x] **T4.** Add the branch to `check_workflow()` (`R/checks.R:7`), beside the
      missing-model branch at `:37`.
- [x] **T5.** Thread the driver's call into `eval_inside_spec()`
      (`R/nested-final-fit.R:196` → `R/checks.R:236`), with a test asserting
      both branches' `conditionCall()`.
- [x] **T6.** The `exists(".Random.seed")` placement test of AC4, over every
      refusal added here, in a `callr`-free fresh-state harness (`rm()` the
      binding, assert absence after).
- [x] **T7.** Roxygen on both `@param resamples`, the rewritten
      `nested_final_fit()` sentence, `NEWS.md`, and `devtools::document()`.
- [x] **T8.** Full `devtools::check()`; confirm no new NOTE and no suite-time
      regression.

## Work log

- 2026-07-30: created by /milestone-plan.
- 2026-07-30: criteria audit ([O], fresh context) returned six findings over six drafted criteria (draft numbering, since renumbered) — the `inner_resamples` baseline was wrong about the final-fit half, the workflow criterion carried a false claim about `R/checks.R`, the RNG criterion could not fail, the docs criterion was vague and partly vacuous; the `splits` criterion was clean; the two-driver-symmetry criterion's biconditional was unsatisfiable against `check_inside_spec()`. Four fixed autonomously, the symmetry residue taken to the gate.
- 2026-07-30: eight drafted criteria hit the >7 sizing tripwire; the two element-class criteria merged into AC1 rather than splitting the milestone — one check over the two columns of one object, nothing dropped.
- 2026-07-30: /milestone-implement started on branch `m19-driver-design-guards`, cut from `main` at 9510f6f.
- 2026-07-30: no implementation question gate — the plan fixed the API shape (no new arguments, exports or dependencies), the gate settled the three behavioural calls, and the message idiom is set by the six existing checks in `R/checks.R`.
- 2026-07-30: T1-T7 landed in one checkpoint rather than per-task, because the tests for all three areas were written into two files in a single tests-first pass and no intermediate subset leaves `devtools::test()` clean.
- 2026-07-30: `check_nested()` gained `check_column_class()`, one helper over both columns, reporting the first offending element; the every-position variant stays the ROADMAP row M19 Out records.
- 2026-07-30: discovered fallout — `test-nested-tune-grid-failures.R:305` used a non-`rsplit` `splits` element as the vehicle for 'an error raised by last_fit() is recorded against the outer fit', which AC1 now refuses at the call. Vehicle changed to an `rsplit` whose `in_id` indexes a row past the end: still an `rsplit`, `last_fit()` still raises, same `.completed` pattern. What the test pins is unchanged.
- 2026-07-30: guards verified by mutation, all three red when inverted — moving `check_nested()` after the `sample.int()` draw reddens the AC4 placement test specifically, which is the failure mode the plan-gate audit found the original `.Random.seed` identity formulation could not produce.
- 2026-07-30: `@param resamples` first linked `[rsample::rsplit()]`, an undocumented topic that `document()` flagged; changed to plain code font, matching how the package already names `rset`.
- 2026-07-30: AC4's teardown first used `withr::defer()`, which `R CMD check` flagged as an undeclared dependency; replaced with `on.exit(add = TRUE)` inside the `test_that()` block rather than adding a dependency, following the standing choice recorded at `teardown-fixture-cache.R:4`. Mutation re-verified after the change — the placement test still reddens.
- 2026-07-30: `devtools::check()` clean (0 errors, 0 warnings, 0 notes); `devtools::test()` 1303 passing, 0 failures, 0 skips; tests leg 75s/123s, no suite-time regression. Status → review.
- 2026-07-30: no prose-guard authored or edited — the new assertions pin `cli_abort()` message content, which the profile's test-doctrine requires of every abort branch, not wording in a skill, rulebook or template; so guard-doctrine §8's fresh-reader step does not apply.
- 2026-07-30: plan gate chose refusing at both drivers over checking only what each driver reads, because one definition of a valid design beats two; falsified by a real design whose broken `inner_resamples` a user legitimately wants the final fit to ignore.
- 2026-07-30: plan gate chose refusing outright over warning-and-continuing, because a design that cannot execute should not cost a full fitting run first (GP3, D-003 waives the deprecation cycle); falsified by evidence that partially-malformed designs are common enough that the surviving folds are worth returning.
- 2026-07-30: plan chose checking every element of both columns over checking only the first, decided autonomously since it is class inspection with no RNG and no fitting; falsified by a measured cost on a design large enough for the sweep to matter.
- 2026-07-30: plan gate chose absorbing the `eval_inside_spec()` call fix over leaving it a candidate row, because it is the same defect class in the same file; falsified by the fix proving to need more than threading an argument.
- 2026-07-30: review fan-out — 14 findings from the diff-bug lens, zero from the other two; three scored >= 80 and were fixed, five sub-threshold ones fixed anyway (two false doc sentences, three assertion tightenings) and six left logged. Return count for this milestone: 0 (fixed in place at review, status never left `review`).

## Decisions

## Review

PR #20 (https://github.com/jmgirard/nestedtune/pull/20). `main` had not moved
since the branch was cut (0/0 against `origin/main`), so no merge-forward was
needed. All evidence below executed on the branch 2026-07-30.

### Acceptance criteria evidence

- **AC1.** Six calls executed — both drivers against each of three malformed
  designs (`inner_resamples[[2]]` a string; `splits[[1]]` a string;
  `rsample::nested_cv(inside = list())`). All six abort. Messages name
  `{.arg resamples}`, the offending column (`inner_resamples` / `splits`), the
  element index (2, 1, 1), and the type held (`a string`, `a list`);
  `conditionCall()` is the user's `nested_tune_grid(...)` / `nested_final_fit(...)`
  in all six.
- **AC2.** Symmetry: the message text for a given malformed design is identical
  at both drivers, each naming its own call (AC1's six calls are the evidence).
  Negative half: on a design with `attr(x, "inside")` removed,
  `nested_tune_grid()` returns a `nested_results` with every fold `.completed`,
  while `nested_final_fit()` alone refuses it — so `check_inside_spec()` stayed
  final-fit-only.
- **AC3.** Both drivers refuse `add_model(workflow(), <ranger spec>)` with
  "`object` has no preprocessor.", the `x` bullet "The workflow carries a model
  specification only.", and an `i` bullet naming `add_formula()`,
  `add_recipe()`, and `add_variables()`; `conditionCall()` is the user's call.
- **AC4.** `test-nested-tune-grid-checks.R` 54 passing, 0 failed. Mutation:
  moving `check_nested()` to after the `sample.int()` draw fails the placement
  test at `:417` twice (plus one unrelated collateral error), confirming the
  assertion can fail — the property the plan-gate audit found the
  `.Random.seed`-identity formulation could not test.
- **AC5.** Both `eval_inside_spec()` branches now give `conditionCall()` of the
  user's `nested_final_fit(...)`: the could-not-be-re-evaluated branch (on a
  design whose `inside` names a vanished `v`) and the did-not-produce-an-`rset`
  branch (on `attr(x, "inside") <- quote(data.frame())`). Both named
  `final_fit_worker(...)` before.
- **AC6.** Both `.Rd` files carry the `rsplit`/`rset` requirement; the old
  "the outer folds play no part in a final fit." sentence is gone from the
  `@param` (0 matches in source); `NEWS.md` carries three entries;
  `devtools::document()` leaves no diff in `man/` or `NAMESPACE`.
- **AC7.** `devtools::check()` — 0 errors, 0 warnings, 0 notes, 3m30.9s.

### Consistency gate

`cairn_validate` — 16 checks PASS, 8 advisories OK, exit 0. `cairn_impact`
not applicable: the diff does not touch `DESIGN.md`, so no principle changed.
Profile `consistency-gate` slot: `document()` no diff; generated files not
hand-edited (covered by that); no `README.Rmd` in this repo; `check_pkgdown()`
"No problems found."; `NEWS.md` carries the user-visible entries with no
milestone numbers; no new top-level files, so no `.Rbuildignore` additions
owed; full `check()` clean as above.

### Independent review

Three fresh-context lenses. **[S] blame-history:** zero findings — "No
regressions against history were found"; it traced the retargeted test to its
M03 origin (`6ff3f08`) and confirmed by execution that the replacement vehicle
still exercises the raising branch. **[S] prior-review:** zero findings; the
GitHub probe returned `[]` (no real inline PR comments in this repo), so it
worked from the archived `## Review` sections and RB02/RR02. **[O] diff-bug:**
14 findings, scored by a fresh [S] scorer holding the diff and the plan.

Actioned (scored >= 80), all three fixed and mutation-verified:

- **F1 (92)** — `check_workflow()`'s new guard asked `length(object$pre$actions)
  == 0L`, which is not "has no preprocessor": `workflows::add_case_weights()`
  files an action under `pre` too, so a workflow with a model and case weights
  but no formula/recipe/variables slipped the guard and degraded to "2 of 2
  outer folds failed" — the exact failure AC3 exists to remove. The same
  imprecision made M18's neighbouring bullet call such a workflow "a
  preprocessor only". Fixed with a `has_preprocessor()` helper asking for the
  three preprocessor slots by name, used by both branches. Verified end-to-end
  against a genuine `add_case_weights()` workflow at review.
- **F2 (84)** — the new check's `i` bullet claimed designs from
  `rsample::nested_cv()` "carry one `<rset>` per outer fold", which is false for
  the very design it fires on and contradicts this milestone's own `NEWS.md`.
  The hint is now a parameter of `check_column_class()`; the `inner_resamples`
  hint says rsample builds the design whatever `inside` returned.
- **F6 (80)** — the two final-fit element-class tests asserted only a column/class
  substring and `conditionCall()`, so forcing `i <- 1L` reddened the loop's tests
  and left theirs green. They now assert the position and the type held.

Logged, below the action threshold (11): F3 (22) `check_column_class()` had no
`call` default — fixed incidentally while adding the `hint` parameter; F4 (15)
the `class` parameter shadows `base::class`, no failure today; F5 (62) AC4's
placement test covered 3 of 6 refusal paths — **extended to all 6 rather than
reinterpreting AC4's "every refusal added here"**; F7 (55) no test pinned the
`{.arg resamples}` prefix AC1 requires — **fixed**, mutation-verified; F8 (52)
AC1(a)'s final-fit half untested — **fixed**; F9 (78) the new `@param resamples`
closed with "Whether a design is valid has one answer, not one per function", a
biconditional AC2 deliberately does not honour — **fixed**, since it is a false
sentence this diff added to shipped documentation; F10 (66) the other `@param`
attributed a malformed `splits` column to `rsample::nested_cv()`, which always
produces proper `rsplit`s — **fixed**, same reason; F11 (35) an unanchored `"2"`
match — tightened to `"Element 2"`; F12 (18) `all(res$.completed)` vacuous on
zero rows — tightened to an identity; F13 (18) the retargeted test cannot
distinguish the raising from the non-raising branch, a weakness the old vehicle
shared — not actioned, no regression; F14 (28) the NEWS bullet describes one of
`eval_inside_spec()`'s two branches — not actioned.

Deviation logged: findings below 80 are normally logged and not actioned. F7,
F9, F10, F11 and F12 were fixed anyway — F9 and F10 because they are factually
false sentences this diff added to user-facing documentation, and the rest
because they were one-line assertion tightenings in the code the F6 fix was
already editing. F5 and F8 were fixed because AC4 and AC1 as written demand the
coverage, and a criterion is never reinterpreted at review.

Post-fix: `devtools::test()` 1327 passing, 0 failures, 0 skips;
`devtools::check()` 0 errors / 0 warnings / 0 notes; all AC evidence above
re-executed and unchanged apart from the corrected `inner_resamples` hint text.
