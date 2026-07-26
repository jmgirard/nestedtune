# printed output holds its shape

    Code
      print(complete)
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
        deploy. Fit the final model separately, and report this estimate as what that
        procedure achieves.

---

    Code
      print(partial)
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
        deploy. Fit the final model separately, and report this estimate as what that
        procedure achieves.

---

    Code
      print(unanimous)
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
        deploy. Fit the final model separately, and report this estimate as what that
        procedure achieves.

---

    Code
      print(divergent)
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
        deploy. Fit the final model separately, and report this estimate as what that
        procedure achieves.

---

    Code
      print(nothing)
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
        deploy. Fit the final model separately, and report this estimate as what that
        procedure achieves.

