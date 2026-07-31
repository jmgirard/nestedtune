# stone1974 — cross-validatory choice and assessment, stated as a two-line scheme

**Citation.** Stone, M. (1974). Cross-validation and multinomial prediction.
*Biometrika*, 61(3), 509–515. Department of Statistics, University of Michigan,
Ann Arbor (on leave from University College London). Received February 1974,
revised May 1974. JSTOR stable URL https://www.jstor.org/stable/2334733.

**Provenance.** Ingested 2026-07-31 from `sources/stone1974.pdf` (gitignored),
JSTOR scan, 8 pages: a JSTOR cover sheet plus article pages 509–515, so PDF
page N = article page 507 + N. Downloaded 2026-07-31 per the scan's own stamp.
Extraction: `pdftotext -layout`, full text read. The mathematics is badly
mangled by extraction — equation numbers, subscripts and the α-superscripts
that distinguish the five predictors do not survive reliably, so no expression
below is quoted as a formula unless its prose statement is unambiguous.
**Table 1 (p. 514) and Figure 1 (p. 513) were not read**: Figure 1 is an image,
and Table 1's cells interleave in extraction beyond any safe attribution of a
number to a row — observed 2026-07-31.

**Scope.** This page records what one source establishes. Standing disclaimer:
a reference, not an authority — status lives in `ROADMAP.md`, decisions in
`DECISIONS.md`, architecture in `DESIGN.md`.

## Provenance warning, read this first

**This is not the paper the nested-CV literature cites as "Stone (1974)".**
That one is Stone, M. (1974), "Cross-validatory choice and assessment of
statistical predictions", *Journal of the Royal Statistical Society, Series B*,
36(2), 111–147 — the paper `cawley2010.md` cites (p. 2080) and the one
`arlot2010.md` credits with the term "double cross" (p. 58).

**Resolved 2026-07-31**: it is now on the shelf as **`stone1974a.md`**, and this
note was renamed from `stone1974.md` to `stone1974b.md` to disambiguate. Read
`stone1974a.md` first — it is the authority, it carries the worked applications,
and it holds a terminology finding this note could not: Stone's "double-cross"
names his §2 item VI, a two-stage cross-validatory *choice*, not the nested
assessment (item V) that both later sources take it for. _(This note previously
gave the issue as 36(1); the JSTOR record reads No. 2.)_

The paper recorded here is the Biometrika companion, which applies the method to
multinomial prediction. It cites the JRSS-B paper twice (§1, p. 510: the
integrated method "was integrated with the method of cross-validatory assessment
by Stone (1974), where the reader may find many illustrative applications"; and
in its reference list, p. 515), and it restates the general scheme in its own
Appendix (p. 515) in self-contained form — which is why the construct appeared on
this shelf before its source paper did.

## What it establishes

**The nested construct, written out in five lines (Appendix, p. 515).** The
paper's Appendix gives the general scheme, reproduced here because it is the
earliest statement on this shelf of what nestedtune computes:

- Data S = {(x_i, y_i); i = 1, …, N}; S\i is S with the ith item omitted.
- Prescription: a class of predictors ŷ(x; α, S) indexed by α ∈ 𝒜, plus a loss
  L(y, ŷ).
- **Choice criterion:** C(α) = (1/N) Σ_i L{y_i, ŷ(x_i; α, S\i)}.
- **Cross-validatory choice:** α̂ = α̂(S), the minimizer of C(α).
- **Cross-validatory assessment of any choice method α̂(·):**
  C = (1/N) Σ_i L[y_i, ŷ{x_i; α̂(S\i), S\i}].

The assessment line is the whole of nested cross-validation at leave-one-out.
Note what it does: it re-runs *the choice* on S\i, so the α used to predict item
i was selected without item i. The object assessed is the choice method α̂(·) —
a procedure — not a fitted predictor. Section 5 (p. 514) applies it, and Section
3 (p. 511) applies the choice half.

**The assessed quantity belongs to a procedure at reduced sample size.**
§5, p. 514, of the multinomial application: "Within the context of the
multinomial model, C is an unbiased estimator of the quadratic performance of
the predictor p_{α̂(n)}(n) constructed on samples of size N − 1." Both halves
matter — the estimand is the *performance of the predictor the method builds*,
and it is the performance at N − 1, not at N.

**The choice is not robust to the loss function.** §3 (pp. 511–512) runs the
same prescription — a mix αA + (1 − α)n/N of a prior vector A and the
multinomial MLE — under two losses, with A = (1/t, …, 1/t) in both:

- Quadratic loss (2.1) gives a smooth weight that is a function of N and the
  standardized Pearson statistic Z, equal to 1 for Z < 1 and shrinking
  continuously for Z > 1 (eq. 3.7).
- Modulus loss (2.2) gives a **hard switch**: α̂ = 0 for Z ≥ 1 and α̂ = 1 for
  Z < 1 (eq. 3.11).

Stone's comment (p. 512): "In appearance at least, α̂ can hardly be said to be
robust to change of loss function." He also notes (p. 512) that (3.11) amounts
to a preliminary chi-squared test, and that "cross-validation selects the
critical value for us and does so at a value rather less than traditional
critical values" — the switch is at Z = 1, the null expectation, not at a
conventional significance level.

**A third prescription changes the answer without changing the model.** §3's
Alternative prescription II (eq. 3.12), the "flattening constant" form {n + cA},
is (3.1) reparameterized — "a trivial reparametrization" for any other method
(p. 512) — and yields a *different* cross-validatory choice (eq. 3.15), because
cross-validatory choice is influenced by explicit dependence on n inside the
individual predictors of the prescription.

**Assessment differences are small and second-digit.** §5, p. 514: "We must
almost always look to the second significant figure of C or beyond to see any
differences in the assessment of the various predictors", because "C contains a
large component reflecting the natural variability of the predicted items and
only a small component reflecting the differences in predictors."

## Extracted values

None quoted. The paper's numeric content is Table 1 (six examples × five
predictors), which this extraction cannot attribute cell by cell — see
Provenance. The three closed forms (3.7), (3.11), (3.15) are recorded above as
prose statements only.

## Bearing on nestedtune

- **External support for IP3, at the origin.** "The estimate describes the
  procedure, never the shipped model" is the Appendix's assessment line: what is
  scored is α̂(·), the method, applied afresh to S\i. The p. 514 sentence names
  the estimand explicitly as the performance of the predictor the method
  constructs at sample size N − 1. IP3 was elicited, not derived from this; this
  is the earliest corroboration on the shelf. _(Superseded as the citation of
  choice 2026-07-31: `stone1974a.md` item V and Dawid's discussion of it say the
  same thing at more length and in the paper the field cites.)_
- **The N − 1 caveat is original, not an artifact.** The pessimistic offset —
  the outer estimate describes training sets one fold smaller than the final fit
  — is stated here in 1974, measured by `varma2006.md` (54.2% against a 50.0%
  truth, 39 samples versus 40), and generalized by `arlot2010.md` (§5.1.1: the
  expectation of a CV estimator depends only on n_t). Three sources, one fact;
  a documented caveat can cite any of them.
- **Support for M20's metric-set observability.** M20 made the metric set a run
  scored under provable on every path. §3 is the reason that matters: the same
  data, the same candidate family and the same prescription select a *different*
  α under modulus loss than under quadratic loss — discontinuously, 0-or-1
  against a smooth shrinkage. A run that cannot say which metric drove selection
  has not said what it did, which is IP4's claim. This is the oldest citation on
  the shelf for it.
- **A caution about prescriptions, relevant to how a grid is specified.** §3's
  Alternative prescription II shows a reparameterization that is inert for any
  non-cross-validatory method changing the cross-validatory choice. The parallel
  here is that how a tuning parameter is parameterized is part of the design,
  not a presentation detail — which is the same territory as the ROADMAP
  candidate on grid expansion differing per fold.
- **Nothing here bears on G6.** The paper offers no variance statement, no
  interval, and no repetition scheme.

## Oracle status

**No oracle.** The paper's numeric results are multinomial shrinkage weights for
a predictor family that has no parsnip engine and that nestedtune would never be
asked to tune; the general scheme is a definition rather than a value. Nothing
here is a candidate fixture.

## Open questions

- ~~Everything in the JRSS-B paper — the term "double cross", the worked
  applications, and whatever proof stands behind the p. 514 unbiasedness
  statement — is unread, because that PDF is not on the shelf~~ — **closed
  2026-07-31**: ingested as `stone1974a.md`. Two of the three are answered there
  (double-cross is defined at its §2 item VI; the applications are its §3); the
  third is not, and is restated below.
- Whether the p. 514 unbiasedness claim is proved anywhere or asserted for the
  multinomial model only. The Biometrika text gives no derivation, and
  `stone1974a.md` carries no proof either — the nearest thing is Dawid's
  discussion contribution (`stone1974a.md`, pp. 136–138), which derives
  E{C(p, S̃)} = r_{n−1}(p) under an explicit distributional assumption Stone's own
  framework declines to make — observed 2026-07-31.
- Table 1's comparison of five predictors across six examples, unread for the
  extraction reason above. It is the paper's only empirical content, and it is
  the only place its assessment measure C is exercised — observed 2026-07-31.
