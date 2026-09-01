# printed output holds its shape

    Code
      print(complete)
    Message
      
      -- Nested cross-validation results ---------------------------------------------
      Outer resamples: 3-fold cross-validation
      # A tibble: 3 x 9
        splits          id    .metrics         .selected .grid    .notes   .completed
        <list>          <chr> <list>           <list>    <list>   <list>   <lgl>     
      1 <split [60/30]> Fold1 <tibble [2 x 4]> <tibble>  <tibble> <tibble> TRUE      
      2 <split [60/30]> Fold2 <tibble [2 x 4]> <tibble>  <tibble> <tibble> TRUE      
      3 <split [60/30]> Fold3 <tibble [2 x 4]> <tibble>  <tibble> <tibble> TRUE      
      # i 2 more variables: .tuning_seed <int>, .outer_fit_seed <int>
      i Use `summary()` for what the run means: which folds failed, what each one
        selected, and the estimate across them.

---

    Code
      print(partial)
    Message
      
      -- Nested cross-validation results ---------------------------------------------
      Outer resamples: 3-fold cross-validation
      # A tibble: 3 x 9
        splits          id    .metrics         .selected .grid    .notes   .completed
        <list>          <chr> <list>           <list>    <list>   <list>   <lgl>     
      1 <split [60/30]> Fold1 <tibble [2 x 4]> <tibble>  <tibble> <tibble> TRUE      
      2 <split [20/10]> Fold2 <tibble [0 x 4]> <NULL>    <tibble> <tibble> FALSE     
      3 <split [60/30]> Fold3 <tibble [2 x 4]> <tibble>  <tibble> <tibble> TRUE      
      # i 2 more variables: .tuning_seed <int>, .outer_fit_seed <int>
      x 1 of 3 outer folds did not complete.
      i Use `summary()` for what the run means: which folds failed, what each one
        selected, and the estimate across them.

---

    Code
      print(nothing)
    Message
      
      -- Nested cross-validation results ---------------------------------------------
      Outer resamples: 3-fold cross-validation
      # A tibble: 3 x 9
        splits          id    .metrics         .selected .grid    .notes   .completed
        <list>          <chr> <list>           <list>    <list>   <list>   <lgl>     
      1 <split [60/30]> Fold1 <tibble [0 x 4]> <NULL>    <tibble> <tibble> FALSE     
      2 <split [60/30]> Fold2 <tibble [0 x 4]> <NULL>    <tibble> <tibble> FALSE     
      3 <split [60/30]> Fold3 <tibble [0 x 4]> <NULL>    <tibble> <tibble> FALSE     
      # i 2 more variables: .tuning_seed <int>, .outer_fit_seed <int>
      x 3 of 3 outer folds did not complete.
      i Use `summary()` for what the run means: which folds failed, what each one
        selected, and the estimate across them.

---

    Code
      print(differing)
    Message
      
      -- Nested cross-validation results ---------------------------------------------
      Outer resamples: 3-fold cross-validation
      # A tibble: 3 x 9
        splits          id    .metrics         .selected .grid    .notes   .completed
        <list>          <chr> <list>           <list>    <list>   <list>   <lgl>     
      1 <split [60/30]> Fold1 <tibble [2 x 4]> <tibble>  <tibble> <tibble> TRUE      
      2 <split [60/30]> Fold2 <tibble [2 x 4]> <tibble>  <tibble> <tibble> TRUE      
      3 <split [60/30]> Fold3 <tibble [2 x 4]> <tibble>  <tibble> <tibble> TRUE      
      # i 2 more variables: .tuning_seed <int>, .outer_fit_seed <int>
      ! Candidates searched: 5, 5, 5 — the folds did not search the same grid
      i Use `summary()` for what the run means: which folds failed, what each one
        selected, and the estimate across them.

---

    Code
      print(summary(complete))
    Message
      
      -- Nested cross-validation results ---------------------------------------------
      Outer resamples: 3-fold cross-validation
      Outer folds: 3 requested, 3 completed
      
      -- Selected parameters --
      
      v num_comp: 3 (all 3 completed folds agree)
      
      -- Estimate (3 of 3 outer folds) --
      
      rmse (standard): 1.4
      rsq (standard): 0.708
      
      i A nested estimate describes the tune-and-fit procedure, not a model you can
        deploy. Build that with `nested_final_fit()`, and report this estimate as
        what its procedure achieves.

---

    Code
      print(summary(unanimous))
    Message
      
      -- Nested cross-validation results ---------------------------------------------
      Outer resamples: 5-fold cross-validation
      Outer folds: 5 requested, 5 completed
      
      -- Selected parameters --
      
      v num_comp: 3 (all 5 completed folds agree)
      
      -- Estimate (5 of 5 outer folds) --
      
      rmse (standard): 1.35
      rsq (standard): 0.716
      
      i A nested estimate describes the tune-and-fit procedure, not a model you can
        deploy. Build that with `nested_final_fit()`, and report this estimate as
        what its procedure achieves.

---

    Code
      print(summary(divergent))
    Message
      
      -- Nested cross-validation results ---------------------------------------------
      Outer resamples: 4-fold cross-validation
      Outer folds: 4 requested, 4 completed
      
      -- Selected parameters --
      
      ! num_comp: 4, 4, 4, 3 (folds disagree)
      
      -- Estimate (4 of 4 outer folds) --
      
      rmse (standard): 3.7
      rsq (standard): 0.123
      
      i A nested estimate describes the tune-and-fit procedure, not a model you can
        deploy. Build that with `nested_final_fit()`, and report this estimate as
        what its procedure achieves.

---

    Code
      print(suppressWarnings(summary(partial)))
    Message
      
      -- Nested cross-validation results ---------------------------------------------
      Outer resamples: 3-fold cross-validation
      Outer folds: 3 requested, 2 completed
      x Fold2 failed during outer fit.
      i See `x$.notes` for what went wrong.
      
      -- Selected parameters --
      
      v num_comp: 3 (all 2 completed folds agree)
      
      -- Estimate (2 of 3 outer folds) --
      
      rmse (standard): 1.52
      rsq (standard): 0.664
      
      i A nested estimate describes the tune-and-fit procedure, not a model you can
        deploy. Build that with `nested_final_fit()`, and report this estimate as
        what its procedure achieves.

---

    Code
      print(suppressWarnings(summary(nothing)))
    Message
      
      -- Nested cross-validation results ---------------------------------------------
      Outer resamples: 3-fold cross-validation
      Outer folds: 3 requested, 0 completed
      x Fold1 failed during inner tuning.
      x Fold2 failed during inner tuning.
      x Fold3 failed during inner tuning.
      i See `x$.notes` for what went wrong.
      
      -- Selected parameters --
      
      i No outer fold completed, so nothing was selected.
      
      -- Estimate --
      
      i No outer fold completed, so there is no estimate.
      
      i A nested estimate describes the tune-and-fit procedure, not a model you can
        deploy. Build that with `nested_final_fit()`, and report this estimate as
        what its procedure achieves.

