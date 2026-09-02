# M48: `...` reaches the inner tuning call, and every inner control slot is documented as forced, refused, passed through, not returned, or inert

**Status:** done (2026-09-02, PR #58 https://github.com/tidymodels/nestedtune/pull/58; resolves #33 closes, #35 partial)

**Goal:** A user passes `control = tune::control_grid(...)` or `tune::control_bayes(...)` through `...` on either orchestrator; it reaches the inner tuning call in every fold and in the final fit, and each control slot is documented as what this package does with it.

**Outcome:** `capture_dots()` forces `...` under its own `.Random.seed` snapshot; `check_dots_control()` refuses every name but
`control` and any unnamed value (`nestedtune_bad_dots`); `check_control()` holds the class to the tuner's and refuses an `event_level`
neither tune's default nor the argument's (`nestedtune_bad_control`), returning `effective_control()`: the caller's or `default_control()`
(the Bayes default built with `seed = 1L`, so no draw moves the stream) with `allow_par = FALSE`, `event_level` from the argument and
`seed` removed. `control` threads `nested_loop()` → `dispatch_folds()` `.args` → `fold_task()` → `nested_fold_fit()` → `run_tuner()`, where
`tuner_control()` adds the fold's tuning seed inside the seed scope; `new_procedure()` records it, `procedure_tuner()` treats it as shared,
so `final_fit_worker()` passes one. Both "Differences" sections carry six bold headings parsed by `test-control-slots.R` against `formals()`;
`parallel_over` and `workflow_size` corrected from inert to passed through, `backend_options` the one inert slot; `control_resamples()` and
`control_last_fit()` accepted as `control_grid`. The `check-r-package` step cap raised from 20 to 30 minutes. NEWS; D-042.

**Decisions:** D-042. Plan gate: `control` only through `...`; overwrite `allow_par`/`seed`, refuse the `event_level` conflict; record the
effective control. Implement gate: the argument wins over a control left at tune's default level.

**Review:** two rounds, three lenses each. Round 1 returned on AC5 (`call =` in `...` bound to the check's own formal); seven findings fixed
as T8–T13 (the inline `control_bayes()` seed draw, "Not returned" false for the final fit's `$tuning`, no grid pass-through test,
`control_last_fit()` undocumented, a helper omitting `event_level`, the `workflow_size` wording), three rejected. Round 2: four diff-lens findings,
three rejected (`NULL` defaults on internal hops, the recorded Bayes control's missing `seed`, a vacuous bound), the `time_limit` IP2 caveat routed
to DESIGN Known issues. CI: windows red three runs at the 20-minute step cap, suite growth not a hang (main's step 13–18 min, M48 tests 85 s
locally); cap raised at the user's choice. The M16 cap lesson extended; nothing graduated.
