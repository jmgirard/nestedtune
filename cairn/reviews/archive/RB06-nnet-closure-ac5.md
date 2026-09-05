# RB06: What AC5 should certify when the masked-nnet build is unsatisfiable, and whether nnet belongs in Suggests (M064)

- **Date:** 2026-09-05
- **Output required:** write findings to `cairn/reviews/RR06-nnet-closure-ac5.md`
- **Binding criteria:** not requested

You are performing an independent expert review. This brief is fully
self-contained — do not assume any conversation context. Read only what this
brief directs you to read, answer the numbered questions, and write your
findings to the output path above using the same numbering.

## Background

nestedtune is an R package for nested cross-validation in the tidymodels
ecosystem: it runs an outer resampling loop and delegates inner tuning to the
`tune` package, which it imports. Milestone M064 ships a site-only pkgdown
article, `vignettes/articles/why-nest.Rmd`, that reads a stored simulation
result (`vignettes/articles/why-nest.rds`) produced by a hand-run script,
`vignettes/articles/why-nest-sim.R`. The script fits `parsnip::mlp()` on the
`nnet` engine; the article fits nothing and reads the store. The directory
`vignettes/articles/` is in `.Rbuildignore`, so neither the built tarball nor
`R CMD check` sees the script, the store or the article.

At planning, D-050 put `nnet` in `Suggests` on the reasoning that the package
producing a shipped page's figures should declare the package the producing
script needs, and rejected both no declaration and `Config/Needs/website`.
Acceptance criterion AC5 then asked that `pkgdown::build_article("articles/why-nest")`
succeed with `nnet` masked from `.libPaths()`, to show the article does not
depend on it.

Implementation found the masked build unsatisfiable, for a reason that has
nothing to do with the article:

- `nnet` is a recommended package and lives in R's system library
  (`/Library/Frameworks/R.framework/Versions/4.6/Resources/library/nnet` on
  the development machine), which `.libPaths()` always includes, so it cannot
  be masked by library paths at all. The same fact is recorded for `survival`
  in `cairn/LESSONS.md` (the M06 line).
- Masking it instead with a stub `nnet` package (a `DESCRIPTION` and no
  namespace) in a temporary library placed first on the path makes
  `requireNamespace("nnet")` return `FALSE`, and then
  `library(nestedtune)` itself fails with "package 'nnet' does not have a
  namespace": `tune` imports `recipes`, `recipes` imports `ipred`, and `ipred`
  imports `nnet` (its `Imports:` field reads `rpart (>= 3.1-8), MASS,
  survival, nnet, class, prodlim`). So `nnet` is in the package's hard
  transitive dependency closure and is present wherever nestedtune loads.
- Under that stub mask, `pkgdown::build_article()` renders the article (the
  render process loads nothing of nestedtune) and then fails in pkgdown's
  autolinker, `downlit`, which loads the `tune` namespace to resolve the prose
  span `tune::tune_grid()` and hits the chain above.
- A plain `rmarkdown::render()` of the article in a fresh R process succeeds
  and ends with `nnet`, `tune` and `nestedtune` all absent from
  `loadedNamespaces()`.

M061 met the same shape once before: a planned `dials` guard was dropped by a
mini-gate amendment because `tune` imports `dials`, so a dials-masked build
fails at `library()` before any guard runs (its archive summary,
`cairn/milestones/archive/M61-tuner-vignette.md`, Decisions paragraph).

The maintainer escalated rather than amending at the implement gate. Two
things are open: what AC5 should certify about the article, and whether
D-050's `Suggests` entry is right now that `nnet` is known to be always
present through the import closure.

## Materials

- `cairn/milestones/M064-why-nest-article.md` — Goal, Scope, AC5 as written
  (line 28), Coverage, the work log.
- `cairn/DECISIONS.md` — search the headings for `D-050` (nnet in Suggests),
  `D-044` and `D-045` (the Suggests precedent for finetune, lme4 and
  BradleyTerry2, and the floor rule), `D-029` (dials via tune).
- `cairn/LESSONS.md` — the M06 line (guarding and masking Suggests packages;
  system-library packages are unmaskable) and the M57 line
  (`skip_if_not_installed()` on a Suggests package inside an Import's hard
  closure guards nothing).
- `cairn/milestones/archive/M61-tuner-vignette.md` — the dials precedent.
- `vignettes/articles/why-nest.Rmd` — the article; note it calls no
  `library()` on nestedtune and reads `why-nest.rds`.
- `vignettes/articles/why-nest-sim.R` — the script; its `requireNamespace()`
  loop and the `set_engine("nnet", ...)` call.
- `DESCRIPTION` — `Imports` and `Suggests`; `.Rbuildignore` —
  `^vignettes/articles$`.
- `.github/workflows/pkgdown.yaml` — the job that builds the site; what it
  installs (`Config/Needs/website` in `DESCRIPTION`).
- To reproduce the closure: `Rscript -e 'tools::package_dependencies("tune", recursive = TRUE)'`
  contains `nnet`; `Rscript -e 'packageDescription("ipred")$Imports'` names it.
- To reproduce the fresh-process render:
  `Rscript -e 'rmarkdown::render("vignettes/articles/why-nest.Rmd", output_dir = tempdir()); "nnet" %in% loadedNamespaces()'`
  prints `FALSE`.

## Questions

1. AC5's masked-build clause cannot be satisfied. Of these replacements,
   which certifies the property the clause was after, that the article itself
   depends on nothing beyond the store, and is measurable at review:
   (a) `rmarkdown::render()` of the article in a fresh R process ends with
   `nnet`, `tune` and `nestedtune` all absent from `loadedNamespaces()`;
   (b) the same with only `nnet` named; (c) drop the clause and keep
   `pkgdown::build_article()` succeeding plus the tarball listing; (d) another
   formulation you would write instead. State the wording you recommend
   verbatim, as one criterion sentence, since the maintainer will ingest it.
2. Is a criterion about which namespaces a render loads a property of the
   deliverable (the article) or of an instrument that verifies it? If the
   latter, where should it live instead (a task, the review procedure)?
3. D-050 put `nnet` in `Suggests` for a script the build excludes. Given
   `nnet` is in the package's hard import closure (through tune → recipes →
   ipred) and is a recommended package present in every R installation, does
   the `Suggests` entry still earn its line? Weigh: (a) keep, since the
   script's need is the package's need to declare and closure membership is
   an accident of upstream that could change; (b) remove, since a Suggests
   entry that can never be absent declares nothing and `R CMD check` never
   exercises it; (c) keep but the script's `requireNamespace()` check for it
   is redundant. If (b), say whether D-050 is superseded or annotated.
4. Does the tarball-listing half of AC5 (`untar(list = TRUE)` shows no path
   under `vignettes/articles/`) still belong in the same criterion as the
   render clause, or should AC5 be split so each half is one measurable
   assertion?
5. Is there any reading of the current AC5 text under which the review could
   tick it without amendment (for instance, treating the stub mask as
   "masked from `.libPaths()`" and the failure as pkgdown's rather than the
   article's)? If so, say whether that reading should be taken or refused,
   and why.

## Constraints

- D-050 is the standing decision on `nnet`; a recommendation to remove it is
  a superseding D-entry, not a silent edit.
- D-044 and D-045 set the Suggests precedent (a fitting package a shipped
  path needs is declared; a floor only where a load-bearing upstream behavior
  arrived at a known version). Do not relitigate them; apply them.
- The article stays a site-only page reading a stored result; a live build
  and a test that re-runs the script are out of scope (milestone Scope, Out).
- Acceptance-criterion wording must state a property of the deliverable and
  be script-measurable where possible (tracking-rules "Prefer
  script-measurable acceptance criteria"); the milestone is user-facing tier.
- Do not modify any file other than the RR you write.

## Output format

In `RR06-nnet-closure-ac5.md`: answer each question by number with your
reasoning and evidence; list any additional findings separately under "Beyond
the brief"; end with concrete recommendations, each marked apply / consider /
reject-with-reason. Your report is advisory: emit a `## Binding criteria`
section ONLY if this brief's header slot says `requested`.
