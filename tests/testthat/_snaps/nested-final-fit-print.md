# the printed report is stable

    Code
      print(final_for_print())
    Message
      
      -- Nested cross-validation final fit -------------------------------------------
      Procedure: grid search, 3 candidates scored
      Selected: num_comp = 3
      
      i This model has no performance estimate of its own. Report the nested estimate
        from `collect_metrics()` on the results object this fit was built from, which
        describes the procedure that produced it.
      i Compare the parameters above with `.selected` from that run. Outer folds
        choosing differently is selection instability, and it is information about
        the procedure rather than noise.
      i `extract_tune_results()` returns the tuning run selection came from, and
        `extract_scored_candidates()` the candidates it scored. Any metric reachable
        through the first is a selection-time quantity, optimistically biased as a
        claim about this model.

# the summary report is stable

    Code
      print(summary(final_for_print()))
    Message
      
      -- Nested cross-validation final fit -------------------------------------------
      Full-data tuning: 3-fold cross-validation
      Procedure: grid search, 3 candidates scored
      Candidates scored: 3
      
      -- Selected parameters --
      
      num_comp: 3
      
      -- Estimate --
      
      i This model has no performance estimate of its own. Report the nested estimate
        from `collect_metrics()` on the results object this fit was built from, which
        describes the procedure that produced it.
      i The tuning run above has metrics, but selection consumed them.
        `extract_tune_results()` reaches them, and every one is a selection-time
        quantity, optimistically biased as a claim about this model.

# the Bayesian printed reports are stable

    Code
      print(bayes_final_for_print())
    Message
      
      -- Nested cross-validation final fit -------------------------------------------
      Procedure: Bayesian optimization, 3 initial candidates (3 requested), 2
      iterations completed (2 requested)
      Selected: df1 = 1, df2 = 2
      
      i This model has no performance estimate of its own. Report the nested estimate
        from `collect_metrics()` on the results object this fit was built from, which
        describes the procedure that produced it.
      i Compare the parameters above with `.selected` from that run. Outer folds
        choosing differently is selection instability, and it is information about
        the procedure rather than noise.
      i `extract_tune_results()` returns the tuning run selection came from, and
        `extract_scored_candidates()` the candidates it scored. Any metric reachable
        through the first is a selection-time quantity, optimistically biased as a
        claim about this model.

---

    Code
      print(summary(bayes_final_for_print()))
    Message
      
      -- Nested cross-validation final fit -------------------------------------------
      Full-data tuning: 3-fold cross-validation
      Procedure: Bayesian optimization, 3 initial candidates (3 requested), 2
      iterations completed (2 requested)
      Candidates scored: 5
      
      -- Selected parameters --
      
      df1: 1
      df2: 2
      
      -- Estimate --
      
      i This model has no performance estimate of its own. Report the nested estimate
        from `collect_metrics()` on the results object this fit was built from, which
        describes the procedure that produced it.
      i The tuning run above has metrics, but selection consumed them.
        `extract_tune_results()` reaches them, and every one is a selection-time
        quantity, optimistically biased as a claim about this model.

