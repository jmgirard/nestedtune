# RR06: What AC5 should certify when the masked-nnet build is unsatisfiable, and whether nnet belongs in Suggests (M064)

- **Date:** 2026-09-05
- **Brief:** `cairn/reviews/RB06-nnet-closure-ac5.md`
- **Binding criteria:** not requested (none emitted)

## Evidence gathered

Reproduced on the development machine (R 4.6, branch `m064-why-nest-article`
at 6c85bcf), ref-based reads only:

- `tools::package_dependencies("tune", recursive = TRUE)` contains `nnet`;
  `packageDescription("ipred")$Imports` reads `rpart (>= 3.1-8), MASS,
  survival, nnet, class, prodlim`; `packageDescription("recipes")$Imports`
  names `ipred`. `packageDescription("nnet")$Priority` is `recommended` and
  `find.package("nnet")` resolves under
  `/Library/Frameworks/R.framework/Versions/4.6/Resources/library`, the
  second of two `.libPaths()` entries.
- `loadNamespace("tune")` alone leaves `nnet` in `loadedNamespaces()`
  (`TRUE`); `loadNamespace("parsnip")` does not (`FALSE`). So the chain is
  live at load time, not only in the dependency database.
- A fresh-process `rmarkdown::render("vignettes/articles/why-nest.Rmd",
  output_dir = tempdir())` succeeds; afterwards `nnet`, `tune`, `nestedtune`
  and `parsnip` are all absent from `loadedNamespaces()`. The 45 namespaces
  present are rmarkdown/knitr/bslib machinery, ggplot2 and its imports
  (scales, gtable, farver, S7, etc.), dplyr, tibble, vctrs, cli, rlang.
- `tools:::.check_package_depends` (the code behind `R CMD check`'s
  dependency checks) tests for Suggests packages that are used but not
  declared and for declared Suggests that are not installed. It has no
  branch for a declared Suggests that nothing uses.
- Precedent: M63's criteria (at 984e12d^) kept the tarball listing as its own
  AC4, separate from the build criterion (AC1) and the masked builds (AC5).

## Answers

### 1. What replaces the masked-build clause

The property the clause was after is: the article fits nothing and reaches
nothing of the modelling stack; everything it shows comes from the store.
Masking was one instrument for that property, and it is the wrong instrument
here because the package under review cannot load without `nnet`, so no
masked build of any page can succeed for a reason that has nothing to do
with any page.

Of the options:

- (a) certifies the property and is measurable by one `Rscript` line. Naming
  `tune` and `nestedtune` alongside `nnet` is what makes it readable: the
  three names say "no tuning, no nesting, no fitting engine" without the
  reader having to know the ipred chain.
- (b) is logically equivalent to (a) on today's dependency graph, since
  `loadNamespace("tune")` pulls `nnet` (measured above), but it states less
  than it certifies and its adequacy depends on an upstream accident. If
  ipred ever dropped `nnet`, (b) would go on passing while `tune` could be
  loaded by the article unnoticed. Prefer (a).
- (c) certifies nothing about the article's dependence. `build_article()`
  succeeding on a machine with everything installed is what M63's AC1
  already established as the "page builds" clause; it does not distinguish a
  page that reads a store from one that fits.
- (d) I considered a static formulation (the article's code chunks contain
  no `library()` or `::` reference to nestedtune, tune, parsnip or nnet, and
  its only file read is `why-nest.rds`). It is a purer property of the
  deliverable, but measuring it needs `knitr::purl()` plus a grep that must
  exclude prose spans such as `tune::tune_grid()`, and it cannot see a
  transitive load. The render check sees everything the static one would and
  more, in one line. Not preferred.

Recommended wording, one sentence, to replace AC5's first clause (the
tarball clause moves out under question 4):

> AC5: `pkgdown::build_article("articles/why-nest")` succeeds on the
> development machine, and a fresh-process `rmarkdown::render()` of
> `vignettes/articles/why-nest.Rmd` succeeds with `nnet`, `tune` and
> `nestedtune` all absent from `loadedNamespaces()` at its end, since the
> article reads the store and fits nothing.

The measuring command, for T4 and the review log:

```
Rscript -e 'rmarkdown::render("vignettes/articles/why-nest.Rmd", output_dir = tempdir(), quiet = TRUE); print(c("nnet", "tune", "nestedtune") %in% loadedNamespaces())'
```

Expected output: three `FALSE`.

### 2. Property of the deliverable or of an instrument

Both, and that is normal for this repo's criteria. The property is "the
article depends on nothing beyond the store"; `loadedNamespaces()` after a
fresh render is the instrument that measures it. AC1 already has this shape
(`identical()` on two stores is the instrument for "the script is a
function of its seed"), and so does the tarball clause (`untar(list = TRUE)`
is the instrument for "the tarball excludes the articles"). The tracking
rule's "prefer script-measurable acceptance criteria" is a request to name
the instrument inside the criterion, not to keep it out.

The line the M64 criteria audit drew, moving "verification acts" from AC1
and AC4 into T1 and T3, is the right one: an act performed once during
implementation (run it twice, look at the PNG) belongs in a task; a
repeatable measurement whose outcome is the criterion belongs in the
criterion. The render check is the second kind. So: the property and its
measurement stay in AC5 as worded above; the exact command and its printed
output go in T4 and in the review's evidence line, as the milestone already
does for the tarball listing. The one thing not to put in AC5 is the
mechanism that made masking impossible (the ipred chain); that is a lesson,
not a criterion.

### 3. Whether `nnet` still earns its Suggests line

Remove it, (b), by a superseding D-entry.

What the line does when kept, measured against every reader of `Suggests`:

- `R CMD check`: exercises Suggests through examples, tests and vignettes.
  Nothing in the tarball names `nnet` (the script and article are
  build-ignored), so no check path touches the entry. The one thing check
  does with an unused Suggests, warn when it is not installed, cannot fire:
  `tune` is in Imports and its hard closure installs `nnet` before this
  package can be checked at all. The noSuggests flavor has it for the same
  reason.
- `install.packages(dependencies = TRUE)`: installs nothing new; `tune`'s
  closure already did.
- A human reading DESCRIPTION: sees a package the tarball never uses and has
  to go to `cairn/DECISIONS.md` to learn why. The script's own header comment
  and its `requireNamespace()` loop already say what the script needs, at
  the place someone running the script will read.

So the entry declares nothing that any tool or reader can act on. This is
the M57 lesson's situation exactly ("a Suggests package inside an Import's
hard closure guards nothing"), reached from the declaration side instead of
the skip side.

On (a)'s two arguments. "The script's need is the package's need to
declare": DESCRIPTION describes the package as built (that is what
`R CMD check` and CRAN read it as), and the script is by design outside the
build. D-044's precedent is "a fitting package a shipped path needs is
declared"; the shipped path here is the article, and the article needs
nothing (question 1's measurement). The script is provenance, not a shipped
path; its needs are declared where it lives. "Closure membership is an
accident of upstream that could change": true, and if ipred dropped `nnet`
the script's `requireNamespace()` would still stop with a clear message,
`nnet` would still be a recommended package present in every standard R
installation, and the article would still not need it. Nothing about this
package's behavior changes in that world, so nothing here needs to be
pre-declared against it. D-029 is the contrast case: `dials` is also in
`tune`'s closure, but tests call `dials::` and `R CMD check` refuses an
undeclared `::` in tests, so that line has a reader. This one has none.

On (c): the script's `requireNamespace("nnet")` check is not redundant and
should stay whichever way (b) goes. It is the script's own guard, it costs
nothing, and it is the only declaration that fires at the moment someone
tries to run the script.

D-050 is superseded, not annotated: its decision ("`nnet` joins Suggests")
is reversed, and its context omitted the fact that decides the question
(the entry can never be absent). The superseding entry should record that
the plan gate chose Suggests twice without that fact, that `R CMD check` has
no unused-Suggests check so D-050's first falsifier could never fire, and
that the script's `requireNamespace()` and header are where the need is
declared. Its own falsifier: a tarball path (a test, an example, a CRAN
vignette) coming to name `nnet`, at which point it re-enters Suggests for
the D-029 reason.

If the maintainer instead keeps (a) as a matter of taste, that is a
defensible one-line cost and the RR's other answers do not depend on it. But
the D-050 entry should then be annotated to say the line is documentary and
unexercised, so the next reader does not rediscover this.

### 4. Splitting the tarball clause out of AC5

Split. The two halves measure different artifacts with different
instruments (a render of one file against `loadedNamespaces()`; a tarball
against `untar(list = TRUE)`) and can fail independently, so one box for
both is a box that cannot be ticked when either fails, and the review has to
write prose to say which. M63 already made this split (its AC4 was the
tarball listing alone, AC1 the build, AC5 the masked builds). Suggested:

> AC8: `R CMD build`'s tarball listing (`untar(list = TRUE)`) contains no
> path under `vignettes/articles/`.

Appending as AC8 rather than renumbering keeps AC6 and AC7 and the Coverage
map stable; map AC8 → T4 alongside AC5. The milestone stays under the
"more than about seven criteria" split tripwire in spirit (eight, one of
which is a two-line mechanical check inherited from M63), but the
maintainer may prefer folding it into AC7's check clause instead; either
keeps each assertion single.

### 5. Ticking AC5 as written without amendment

Refuse. Two readings were offered and neither survives the text.

"Masked from `.libPaths()`" is literal: the package is absent from every
library the path names. A stub package on the path is a different
instrument (it is present, with no namespace), and under it the clause's
verb, "succeeds", is false: `build_article()` fails. Reassigning the failure
to pkgdown's autolinker does not restore "succeeds"; it explains why the
sentence cannot be made true. The only way to tick the box is to read
"succeeds" as "the render step succeeds and the failure is elsewhere",
which is a reinterpretation, and the tracking rules say the review reads
criteria and never reinterprets them; wording changes go through the
implement amendment protocol with a work-log line. The maintainer's
escalation instead of a review-side tick was the correct move, and so was
declining the mini gate's silent swap: the replacement changes what the
criterion certifies, which is a gate decision.

There is also a substantive reason not to stretch it. A ticked AC5 in the
archive would tell a future reader that a masked-nnet build of this site
passed. It did not and cannot, and the M61 archive already carries one such
correction for `dials`. The archive should say what was measured.

## Beyond the brief

- D-050's first falsifier, "a CRAN check flagging an unused Suggests
  entry", names a check that does not exist. `tools:::.check_package_depends`
  reports Suggests that are used and undeclared, and Suggests that are
  declared and not installed; it never reports a declared Suggests that
  nothing uses. Whatever question 3's outcome, the falsifier should not be
  carried forward as written.
- The `library(ggplot2)` call in the article's figure chunk is the one
  attachment the render makes, and ggplot2 is in Imports, so the render is
  covered by the package's own closure with nothing extra. Worth one clause
  in the review evidence, not a criterion.
- If (b) is taken, four places on the branch currently say the opposite and
  need the same amendment: the milestone title ("with nnet in Suggests"),
  the Scope In line ("`nnet` in Suggests (D-050)"), AC6's first clause
  ("`nnet` is in `Suggests`, and"), the NEWS bullet's last sentence, and the
  `nnet,` line in `DESCRIPTION`. AC6 then becomes the citation-guard
  criterion alone.
- A LESSONS line earns its place, as the third instance of one shape (M61
  dials, M57 tibble, M64 nnet): before writing a masked-build or
  skip-on-absence criterion for a package, read
  `tools::package_dependencies(<each Import>, recursive = TRUE)` and the
  package's `Priority` field; a closure member or a recommended package
  cannot be masked, and a fresh-process `loadedNamespaces()` after render is
  the check that replaces masking for a page that is meant to load nothing.
  Consider merging into the M06 line rather than adding a fourth.
- The pkgdown CI job (`needs: website`) renders the article from the
  committed `why-nest.rds` (981 bytes on the branch), so the site build's
  correctness rests on the store being committed alongside any script
  change. AC1's `identical()` and the provenance fields cover regeneration;
  nothing covers a script edit committed without a re-run. Out of this
  milestone's scope (the review re-runs the script once), noted only so the
  review's evidence line records which commit the store's `commit` field
  names.

## Recommendations

1. **Apply.** Replace AC5 with the sentence under question 1, through the
   implement amendment protocol with a work-log line; record the measuring
   command and its three `FALSE` in T4 and in the review evidence.
2. **Apply.** Move the tarball listing to its own criterion (AC8 as worded
   under question 4, or folded into AC7), mapped to T4.
3. **Apply.** Remove `nnet` from `Suggests` by a superseding D-entry
   (question 3), keep the script's `requireNamespace("nnet")`, and amend the
   title, Scope, AC6, NEWS and DESCRIPTION together. If the maintainer keeps
   the line, annotate D-050 as documentary and unexercised instead.
4. **Apply.** Do not tick the current AC5 under any reading (question 5).
5. **Consider.** A LESSONS line or an extension of the M06 line on checking
   closure membership and `Priority` before writing a masking criterion.
6. **Consider.** Drop or reword D-050's "CRAN check flagging an unused
   Suggests entry" falsifier in whichever entry carries the decision forward.
7. **Reject with reason.** Option (b) of question 1 (`nnet` alone): passes
   today only because of the ipred chain and says less than it certifies.
8. **Reject with reason.** Option (c) of question 1 (drop the clause): loses
   the one assertion that separates a store-reading page from a fitting one.
9. **Reject with reason.** `Config/Needs/website` as a home for `nnet`:
   D-050 already rejected it, and the closure fact makes it more redundant,
   not less, since the website job installs `tune`.
