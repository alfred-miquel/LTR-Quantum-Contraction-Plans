Dataset used in the training process in both models, pair and ndcg. The file format in all cases is .xlsx. 

Df_final files were used in the training and validation processes while df_test and df_ood were used during testing processes.

In the process of getting the files we used the features :

### 18 features as detailed in the article

feature_names = [

        "max_cost",              # 1. max cost
        
        "log2_sum_flops_val",    # 2. log2 sum flops
        
        "topq_mean",             # 3. topq mean cost
        
        "avg_cost",              # 4. avg cost
        
        "std_cost",              # 5. std cost
        
        "n_steps",               # 6. n steps
        
        "frac_tiny",             # 7. frac tiny steps
        
        "max_out_rank",          # 8. max out rank
        
        "avg_out_rank",          # 9. avg out rank
        
        "costw_out_rank",        # 10. costw out rank
        
        "p_at_max_cost_val",     # 11. p at max cost
        
        "max_red_rank_val",      # 12. max red rank
        
        "costw_red_rank_val",    # 13. costw red rank
        
        "k_at_max_cost_val",     # 14. k at max cost
        
        "max_asym_val",          # 15. max asym 
        
        "avg_asym",              # 16. avg asym
        
        "costw_asym_val",        # 17. costw asym 
        
        "d_at_max_cost_val"      # 18. d at max cost
    ]

### features used in ncdg models

FEATURES_13_ndcg = [

 "std_cost"
 "n_steps"
 "frac_tiny"
 "max_out_rank"
 "avg_out_rank"
 "costw_out_rank"
 "p_at_max_cost_val"
 "max_red_rank_val"
 "k_at_max_cost_val"
 "max_asym_val"
 "avg_asym"
 "costw_asym_val"
 "d_at_max_cost_val"
   
    ]

### features used in pair models


FEATURES_13_pair = [

 "n_steps"
 "frac_tiny"
 "max_out_rank"
 "avg_out_rank"
 "costw_out_rank"
 "p_at_max_cost_val"
 "max_red_rank_val"
 "costw_red_rank_val"
 "k_at_max_cost_val"
 "max_asym_val"
 "avg_asym"
 "costw_asym_val"
 "d_at_max_cost_val"

    ]





