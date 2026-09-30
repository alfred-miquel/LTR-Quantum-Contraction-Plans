# functions and preliminary data for notebook 5


#################################

#  ndcg params

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



params_ndcg = [
    :objective   => "rank:ndcg",
     :eval_metric => "ndcg@3",
    :maximize    => true , # <--- AFEGEIX AIXÒ en tots en què cal maximitzar la mètrica com ndcg
    :eta         => 0.02,     # Aprenentatge lent per a més precisió
    :max_depth   => 6,        # Profunditat moderada per evitar overfitting
    :subsample   => 0.8,      # Estabilitat
    :seed        => 42
]

#################################

#  pairwise params 

params_pairwise=
[
  :lambda           => 0.0,
  :min_child_weight => 3,
  :eval_metric      => "ndcg@3",
  :maximize         => true ,
  :eta              => 0.05 ,
  :gamma            => 0.5 ,
  :objective        => "rank:pairwise" ,
  :colsample_bytree => 0.5 ,
  :subsample        => 0.5 ,
  :seed             => 42 ,
  :max_depth        => 5 ,

    ]

# features for pair model

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

using XLSX
using DataFrames


"""
    getting_dataframe_excel(ruta_arxiu::String;
                                   nom_full::String="", versio=false)

Read a `DataFrame` from an Excel file.

# Arguments
- `ruta_arxiu::String`: path to the Excel file.
- `nom_full::String=""`: name of the sheet to read. If empty, the first sheet
  is used.
- `versio::Bool=false`: if `true`, the Excel file handle is explicitly closed
  after reading.

# Returns
- `df::DataFrame`: the data read from the selected sheet.
"""
function getting_dataframe_excel(ruta_arxiu::String;
                                         nom_full::String="", versio=false, verbose = false)
    try
        # Show information about the available sheets
        xf = XLSX.readxlsx(ruta_arxiu)
        fulls = XLSX.sheetnames(xf)
        if verbose == true
           println("📑 Available sheets: $fulls")
        end
        
        # Decide which sheet to read
        full_a_llegir = isempty(nom_full) ? fulls[1] : nom_full
        if verbose == true
           println("📖 Reading sheet: '$full_a_llegir'")
        end

        # Read the data as a DataTable
        datatable = XLSX.readtable(ruta_arxiu, full_a_llegir)

        # Convert the DataTable into a DataFrame
        df = DataFrame(datatable)

        if versio == true
            # Close the file
            XLSX.close(xf)
        end
      if verbose == true
        println("✅ DataFrame successfully read")
        println("📊 Dimensions: $(nrow(df)) rows × $(ncol(df)) columns")
        println("📋 Columns: $(names(df))")
      end
        
        return df

    catch e
        println("❌ Error while reading the Excel file: $e")
        rethrow(e)
    end
end





using Printf
using XGBoost
using Statistics


"""
    Getting_model(df_train, features, params; num_round=200, verbose=true)

Train an XGBoost Learning-to-Rank (LTR) model on the training split.

The function groups the data by circuit (via `base_id`), builds the
`DMatrix` with the required `group` vector, and converts the continuous
labels into integer relevance grades using NDCG-based encoding.

# Arguments
- `df_train::DataFrame`: training data, must contain `base_id`, `label` and
  the columns listed in `features`.
- `features`: list of feature names used as predictors.
- `params`: iterable of keyword pairs passed to `xgboost` (e.g.
  `:objective => "rank:ndcg"`, `:eta => 0.1`).
- `num_round::Int=200`: number of boosting rounds.
- `verbose::Bool=true`: if `true`, training progress is printed to stdout;
  otherwise XGBoost is run with `verbosity=0`.

# Returns
- `model`: the trained XGBoost model, or `nothing` if training failed.
"""
function Getting_model(df_train, features, params; num_round=200, verbose=true)
    params_dict = Dict(params)

    # 1. Prepare the data for XGBoost (Ranking objective)
    # The protocol requires the data to be grouped by circuit
    sort!(df_train, :base_id)

    # Groups (how many plans each circuit has)
    grups_train = [nrow(g) for g in groupby(df_train, :base_id)]

    # DMatrix inputs
    X_train = Matrix{Float64}(df_train[:, features])
    y_train = Float32.(df_train.label)

    y_train = transforma_a_enters_relevancia(y_train; vector_group=grups_train)
    dtrain  = DMatrix(X_train, label=y_train, group=grups_train)

    model = try
        if verbose == true
            xgboost(dtrain, num_round=num_round; params...)
        else
            xgboost(dtrain, num_round=num_round, watchlist=(;); verbosity=0, params...)
        end

    catch e
        println("❌ ERROR: $e")
        return nothing
    end

    if model !== nothing && verbose == true
        println("✅ Ranking model successfully trained!")
    end

    return model
end


"""
    transforma_a_enters_relevancia(y; vector_group=vector_group)

Convert a continuous target vector `y` into integer relevance labels,
computed independently within each group defined by `vector_group`.

Within each group, the values of `y` are ranked and mapped to integers
starting at 0 (worst) up to `n_per_group - 1` (best).

# Arguments
- `y`: continuous target vector.
- `vector_group`: vector giving the size of each group; the entries of `y`
  are consumed sequentially, one group at a time.

# Returns
- `y_enters`: vector of integer relevance labels, aligned with `y`.
"""
function transforma_a_enters_relevancia(y; vector_group=vector_group)
    
    y_enters = []
    i = 0
    ini = 1

    for j in 1:length(vector_group)
        n_per_grup = vector_group[j]
        fi = ini + n_per_grup - 1
        # for i in 1:n_per_grup:length(y)-n_per_grup+1
        # Take the block of 7 plans
        bloc = y[ini:fi]
        # Assign integers from 0 to 6 based on the ordering
        # (0 = worst, 6 = best)
        bloc_ordenat = invperm(sortperm(bloc)) .- 1

        append!(y_enters, bloc_ordenat)
        ini = fi + 1
    end

    return y_enters
end


"""
    evaluate_tops_and_regrets(model, df, features;
                              nom_bloc="Test", normalize_regret=true,
                              k=1, verbose=true)

Evaluate a trained Learning-to-Rank model on a given data split using
Top-k accuracy and normalized regret.

For each group (circuit), the model's predicted scores are used to rank the
plans. Ties in the predicted score share the same rank, and the next rank is
shifted accordingly.

- **Top-1 hit**: the truly best plan (highest `label`) is ranked 1st.
- **Top-3 hit**: the truly best plan is ranked within the top 3.
- **Regret@k**: `1 - best_in_topk / best_real` when `normalize_regret=true`,
  or `best_real - best_in_topk` otherwise.

# Arguments
- `model`: trained XGBoost model.
- `df::DataFrame`: data split to evaluate; must contain `base_id`, `label`
  and the columns listed in `features`.
- `features`: list of feature names used as predictors.
- `nom_bloc::String="Test"`: name of the split, used in the printed report.
- `normalize_regret::Bool=true`: if `true`, regret is normalized by the best
  real speedup; otherwise the raw difference is reported.
- `k::Int=1`: which Top-k report to print (1, 3, or any other value to print
  both Top-1 and Top-3).
- `verbose::Bool=true`: if `true`, a formatted report is printed to stdout.

# Returns
- `Dict`: a dictionary with keys `:top1`, `:top3`, `:regret1`, `:regret3`
  containing the corresponding aggregate metrics (in % for accuracy and
  averaged over groups for regret).
"""
function evaluate_tops_and_regrets(model, df, features;
                                   nom_bloc="Test", normalize_regret=true,
                                   k=1, verbose=true)

    X = Matrix{Float64}(df[:, features])
    df.pred_score = XGBoost.predict(model, X)

    groups = groupby(df, :base_id)
    n_groups = length(groups)

    top1_hits = 0
    top3_hits = 0
    regret1_vals = Float64[]
    regret3_vals = Float64[]

    for g in groups
        sp = g.label    # label vs speedup
        pred = g.pred_score

        # Best real speedup
        best_real = maximum(sp)

        # ---------------------------
        # 1. Sort with tie handling
        # ---------------------------
        # Assign a rank to each element: entries with the same prediction
        # share the same rank, and the next rank is shifted by the number
        # of tied elements.
        order = sortperm(pred, rev=true)
        ranks = similar(order, Int)
        current_rank = 1
        i = 1
        while i <= length(order)
            j = i
            # Find all indices with the same prediction (equal value)
            while j < length(order) && pred[order[j]] == pred[order[j+1]]
                j += 1
            end
            # Assign the same rank to the whole tied block
            for k in i:j
                ranks[order[k]] = current_rank
            end
            i = j + 1
            current_rank += (j - i + 2)
        end

        ranks = fill(0, length(pred))
        sorted_idx = sortperm(pred, rev=true)
        rank = 1
        idx = 1
        while idx <= length(sorted_idx)
            start = idx
            current_pred = pred[sorted_idx[idx]]
            while idx < length(sorted_idx) && pred[sorted_idx[idx+1]] == current_pred
                idx += 1
            end

            for k in start:idx
                ranks[sorted_idx[k]] = rank
            end
            idx += 1
            rank = idx
        end

        # Rank of the truly best element
        best_idx = argmax(sp)
        best_rank = ranks[best_idx]

        # Top-1
        if best_rank == 1
            top1_hits += 1
        end
        # Top-3
        if best_rank <= 3
            top3_hits += 1
        end

        # ---------------------------
        # 2. Normalized regret
        # ---------------------------
        # For regret@1: best speedup among all elements with rank 1
        idx_rank1 = findall(ranks .== 1)
        best_in_rank1 = maximum(sp[idx_rank1])
        # For regret@3: best speedup among all elements with rank <= 3
        idx_rank3 = findall(ranks .<= 3)
        best_in_rank3 = maximum(sp[idx_rank3])

        if normalize_regret
            regret1 = 1 - best_in_rank1 / best_real
            regret3 = 1 - best_in_rank3 / best_real
        else
            regret1 = best_real - best_in_rank1
            regret3 = best_real - best_in_rank3
        end
        push!(regret1_vals, regret1)
        push!(regret3_vals, regret3)
    end

    top1 = top1_hits / n_groups * 100
    top3 = top3_hits / n_groups * 100

    if verbose == true

        if k == 1
            @printf("\n📊 REPORT : %s (Top-%d)\n", nom_bloc, k)
            @printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            @printf("🏆 TOP-1 Accuracy: %.2f%%  |  New_Regret@1: %.4f\n", top1, mean(regret1_vals))

            @printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        elseif k == 3

            @printf("\n📊 REPORT: %s (Top-%d)\n", nom_bloc, k)
            @printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            @printf("🏆 TOP-3 Accuracy: %.2f%%  |  New_Regret@3: %.4f\n", top3, mean(regret3_vals))

            @printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        else

            @printf("\n📊 REPORT: %s (Top-%d)\n", nom_bloc, k)
            @printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            @printf("🏆 TOP-1 Accuracy: %.2f%%  |  New_Regret@1: %.4f\n", top1, mean(regret1_vals))

            @printf("🥉 TOP-3 Accuracy: %.2f%%  |  New_Regret@3: %.4f\n", top3, mean(regret3_vals))

            @printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        end
    end
    return Dict(:top1 => top1, :top3 => top3,
                :regret1 => mean(regret1_vals),
                :regret3 => mean(regret3_vals))
end


"""
    test_model(df_final, df_test, features, params,num;
               nom_bloc=nom_bloc,  verbose=true)

Train two Learning-to-Rank models on `df_final` and evaluate each of them on `df_test` using the corresponding
Top-k report.


# Arguments
- `df_final::DataFrame`: training data.
- `df_test::DataFrame`: test data.
- `features`: list of feature names used as predictors.
- `params`: iterable of keyword pairs passed to XGBoost (e.g.
  `:objective => "rank:ndcg"`).
- `nom_bloc=nom_bloc`: name of the split, used in the printed report.
- `num`: tuple for the models.
- `verbose::Bool=true`: if `true`, the evaluation reports are printed to
  stdout.


"""



function test_model(df_final,df_test,features,params,num;nom_bloc=nom_bloc,verbose=true)

    m_t1= Getting_model(df_final,features, params;num_round=num[1], verbose=false);
    m_t3= Getting_model(df_final ,features, params;num_round = num[2] ,verbose=false);
    resultats= evaluate_tops_and_regrets(m_t1,df_test,features;nom_bloc=nom_bloc,k=1,verbose=verbose);
    resultats= evaluate_tops_and_regrets(m_t3,df_test,features;nom_bloc=nom_bloc,k=3,verbose=verbose);
   return 
end



"""
    Choose_model()

Prompt the user to choose one of the two learning-to-rank objectives
(`opt_ndcg` or `opt_pair`) and return the corresponding parameter set.

# Returns
- `params::Vector{Pair{Symbol,Any}}`: the XGBoost parameters matching the
  user's choice.
- `model_name::String`: the name of the selected objective, for reporting.
- others: features and data of the models
"""
function Choose_model()
    # Available objectives
    opcions = Dict(
        "opt_ndcg" => (
            name  = "opt_ndcg",
            params = [
                :objective   => "rank:ndcg",
                :eval_metric => "ndcg@3",
                :maximize    => true , # <--- AFEGEIX AIXÒ en tots en què cal maximitzar la mètrica com ndcg
                :eta         => 0.02,     # Aprenentatge lent per a més precisió
                :max_depth   => 6,        # Profunditat moderada per evitar overfitting
                :subsample   => 0.8,      # Estabilitat
                :seed        => 42
            ],

          num = (1,65),
          features = FEATURES_13_ndcg,
          df_final = df_final_ndcg,
          df_test =df_test_n_ndcg,  
        ),
        "opt_pair" => (
            name  = "opt_pair",
            params =[
                      :lambda           => 0.0,
                      :min_child_weight => 3,
                      :eval_metric      => "ndcg@3",
                      :maximize         => true ,
                      :eta              => 0.05 ,
                      :gamma            => 0.5 ,
                      :objective        => "rank:pairwise" ,
                      :colsample_bytree => 0.5 ,
                      :subsample        => 0.5 ,
                      :seed             => 42 ,
                      :max_depth        => 5 ,

    ],

           num = (16,14),
          features = FEATURES_13_pair,
          df_final = df_final_pair,
          df_test =df_test_n_pair, 


           
        ),
    )

    # Display the menu
    println()
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println("📊 Select the learning-to-rank objective")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println("  1) opt_ndcg   (rank:ndcg)")
    println("  2) opt_pair   (rank:pairwise)")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # Read the user's choice
    print("👉 Enter your choice (1 or 2): ")
    entrada = strip(readline())

    # Map the input to the corresponding objective
    if entrada == "1" || lowercase(entrada) == "opt_ndcg"
        eleccio = opcions["opt_ndcg"]
    elseif entrada == "2" || lowercase(entrada) == "opt_pair"
        eleccio = opcions["opt_pair"]
    else
        println("⚠️  Invalid choice '$entrada'. Defaulting to opt_ndcg.")
        eleccio = opcions["opt_ndcg"]
    end

    println("✅ Selected objective: $(eleccio.name)")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    return eleccio.params, eleccio.name,eleccio.num,eleccio.features,eleccio.df_final,eleccio.df_test
end


"""
    menu_test_model(; nom_bloc="Test",verbose=true)

Interactive entry point: ask the user which LTR objective to use
(`opt_ndcg` or `opt_pair`) and run `test_model` with the corresponding
parameter set.

# Arguments

- `nom_bloc::String="Test"`: name of the split, used in the printed report.

- `verbose::Bool=true`: if `true`, the evaluation reports are printed to
  stdout.

# Returns tops and regrets of the model
- 
"""
function menu_test_model(; nom_bloc="Test",  verbose=true)
    #eleccio.params, eleccio.name,eleccio.num,eleccio.features,eleccio.df_final,eleccio.df_test
    params, model_name,num,features,df_final,df_test = Choose_model()
    
    println("🚀 Running $(nom_bloc) with objective '$model_name' ...")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

   
    return test_model(df_final, df_test, features, params,num;nom_bloc=nom_bloc, verbose=verbose)
end
