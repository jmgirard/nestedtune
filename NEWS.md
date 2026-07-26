# nestedtune (development version)

* Added `nested_resamples()`, a memory-lean constructor for nested resampling
  designs. It produces the same splits as `rsample::nested_cv()` for the same
  seed, but stores index vectors into the original data instead of a
  materialized analysis set per outer fold, so object size no longer grows by
  one copy of the data for every outer fold.
