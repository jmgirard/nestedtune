# the printed report is stable

    Code
      print(final_for_print())
    Message
      
      -- Nested cross-validation final fit -------------------------------------------
      Selected: num_comp = 3
      
      i This model has no performance estimate of its own. Report the nested estimate
        from `collect_metrics()` on the `nested_tune_grid()` result, which describes
        the procedure that produced it.
      i Compare the parameters above with `.selected` from that run. Outer folds
        choosing differently is selection instability, and it is information about
        the procedure rather than noise.
      i `extract_tune_results()` returns the tuning run selection came from, and
        `extract_scored_candidates()` the candidates it scored. Any metric reachable
        through the first is a selection-time quantity, optimistically biased as a
        claim about this model.

