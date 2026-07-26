# nestedtune 0.0.0.9000

* Added `nested_resamples()`, a constructor for nested resampling designs that
  does not keep a copy of the data for every outer fold. For the same seed and
  the same specifications it produces the same splits as `rsample::nested_cv()`
  — identical down to the attributes of the retrieved frames — so it is a
  drop-in substitution. On a 20000-row dataset with a five-fold inner
  resampling, a 50-fold outer design holds 10× the source data rather than 57×.

* `nested_resamples()` refuses an outer bootstrap rather than warning about it.
  The same observation can otherwise land in both the inner analysis and the
  inner assessment set, which makes the design invalid rather than unusual.
