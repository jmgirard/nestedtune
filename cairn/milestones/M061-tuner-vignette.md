# M61: A vignette runs the four alternative inner tuners on one design and shows what each records

- **Status:** planned
- **Priority:** normal
- **Depends on:** M60
- **Driving RR:** —
- **Principles touched:** GP1
- **Resolves:** —
- **Surface tier:** user-facing — a vignette shipped in the package and on the site
- **Branch/PR:** —

## Goal

Ship `vignettes/tuners.Rmd` ("Choosing the inner tuner"), which runs `nested_tune_bayes()`, `nested_tune_race_anova()`, `nested_tune_race_win_loss()` and `nested_tune_sim_anneal()` on the getting-started guide's design and workflow, shows what each fold's `.inner_metrics` records for each, shows tune's control reaching the inner call through `...`, and says what differs from calling tune or finetune directly.

## Scope

**In:** the page; its `knit_exit()` guard on `ranger` and `dials` (the guide's form, `dials` for the `param_info` chunk); its section guards — the racing sections built only with `finetune`, `lme4` and `BradleyTerry2` all present (the packages `nested_tune_race_*()` refuse at entry without), the annealing section only with `finetune`, one notice standing in for whichever is skipped, the Bayesian section always built; the `param_info` the Bayesian and annealing tuners need for an `mtry` range with unknowns (the plan probe: without it every fold fails at inner tuning with "`mtry` must be a <param> object without unknowns"); the page's `_pkgdown.yml` entry; its build-time figure.

**Out:** the grid tuner's own walkthrough (the getting-started guide); an inner-search trajectory plot (the ROADMAP candidate row); parallel runs → M63; the results object's readers → M62; any cited source (none planned — a page cited here owes a shelf page in this milestone).

## Acceptance criteria

- [ ] AC1: The page builds under `R CMD check` with `ranger`, `dials`, `finetune`, `lme4` and `BradleyTerry2` installed, and its built HTML holds executed output from each of `nested_tune_bayes()`, `nested_tune_race_anova()`, `nested_tune_race_win_loss()` and `nested_tune_sim_anneal()` on the design and workflow the getting-started guide builds.
- [ ] AC2: For each of the four runs the page prints one fold's `.inner_metrics` in an executed chunk; for the Bayesian and annealing runs the prose reads the `.iter` range from that table inline; for the ANOVA race the chunk prints the fold with the smallest total `n` over candidates and the prose reads, inline, how many of its candidates show `n` below the inner fold count, which on the guide's design and grid is at least one (the plan probe: folds 3, 4 and 5 of 5 eliminated candidates).
- [ ] AC3: An executed chunk passes a `tune::control_bayes()` through `...` and prints the `procedure` attribute of the result; the prose reads `allow_par` from that record inline, and states as text that a control naming an `event_level` that is neither tune's default nor the argument's is refused while one left at tune's default takes the argument's level, and that `seed` is dropped from the record.
- [ ] AC4: With `finetune` masked from `.libPaths()`, the page builds, its Bayesian section still executes, no racing or annealing chunk executes and one notice paragraph stands in their place; with `lme4` alone masked, the annealing section still executes and no racing chunk executes; with `ranger` or `dials` masked, the page prints its notice and exits at `knitr::knit_exit()`; each verified by one masked build.
- [ ] AC5: The citation guard (M60) passes over the page: no uncited digit in its prose, and either no citations or a backed References section.
- [ ] AC6: The page's build time, measured as the median elapsed seconds of three runs of `tools::buildVignettes(dir = <temporary copy>, skip = <every other vignette file>)` on the development machine, is at most 45 seconds.
- [ ] AC7: The profile's `verify` slot is clean and `devtools::check()` reports no error, warning or note beyond those on the default branch.

## Coverage

- AC1 → T1, T2
- AC2 → T2
- AC3 → T3
- AC4 → T4, T5
- AC5 → T5
- AC6 → T5
- AC7 → T5

## Tasks

- [ ] T1: Draft the page: the guide's design and workflow chunk, the `param_info` chunk (`update(tune::extract_parameter_set_dials(wf), mtry = dials::mtry(c(2L, 8L)))`) with a sentence on why the Bayesian and annealing tuners need it, then one section per tuner with its call, its result printed, and the cost arithmetic (fits per outer fold) as inline R.
- [ ] T2: The `.inner_metrics` section: print `res$.inner_metrics[[1]]` for the Bayesian and annealing runs and the smallest-`n` fold for the ANOVA race; compute the `.iter` range and the eliminated-candidate count inline; keep `initial = 4, iter = 3` for the Bayesian run and `initial = 3, iter = 3` for annealing (the plan probe: 5.7 s and 6.2 s) so AC6 holds.
- [ ] T3: The control section: a `control_bayes(verbose = FALSE, no_improve = 3)` pass through `...`, `attr(res, "procedure")` printed, `allow_par` read from it inline, the `event_level` and `seed` sentences as text.
- [ ] T4: Guarding: the guide's `deps`/`deps-notice` chunks extended to `ranger` and `dials`; `has_finetune <- requireNamespace("finetune", quietly = TRUE)` and `has_race <- has_finetune && all(vapply(c("lme4", "BradleyTerry2"), requireNamespace, logical(1), quietly = TRUE))`, every racing chunk `eval = has_race` and every annealing chunk `eval = has_finetune`, every inline R for those sections reading variables assigned only inside guarded chunks (the M06 lesson on inline expressions), notice chunks `eval = !has_race` and `eval = !has_finetune`.
- [ ] T5: `_pkgdown.yml` entry under Guides; measure AC6 with `skip =` and log it with the combined CRAN-vignette figure, date and commit; run the guard, the verify slot and `devtools::check()`; one build each with `finetune`, with `lme4`, with `ranger` and with `dials` masked for AC4.

## Work log

- 2026-09-04: created by /milestone-plan.
- 2026-09-04: plan gate chose shipping this page as a CRAN vignette under a 45-second cap over a site-only article because the user placed it among the cheap pages and the plan probe put the four runs at 21 s together; falsified by a CI leg's vignette step exceeding its budget on this page.
- 2026-09-04: criteria audit (full mode, the M60 reader) returned seven findings: `event_level` cannot be read as overwritten from the record (AC3 narrowed to `allow_par`), the race elimination pinned to the probed design (AC2), the `ranger` guard added (Scope, AC4), the notice wording aligned with T4, logging moved to T5, AC4's coverage extended to T5, and the CRAN-or-article placement decided as the line above records.
- 2026-09-04: second audit pass (full mode, a fresh [O] reader) returned three M61 findings, all applied: the racing sections need `lme4` and `BradleyTerry2` and the `param_info` chunk needs `dials` (guards and AC1, AC4 extended), `tools::buildVignettes()` measures the whole set so AC6 names `skip =`, and AC3's `event_level` sentence now matches `check_control()`'s rule.
