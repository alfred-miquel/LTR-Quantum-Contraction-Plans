################################################################################
## Notebook: model predictions — required functions
################################################################################

using Statistics
using XGBoost
using XLSX
using DataFrames


# Features used in the article

feature_names = [
    "max_cost",              # 1.  max cost
    "log2_sum_flops_val",    # 2.  log2 sum flops
    "topq_mean",             # 3.  topq mean cost
    "avg_cost",              # 4.  avg cost
    "std_cost",              # 5.  std cost
    "n_steps",               # 6.  number of steps
    "frac_tiny",             # 7.  fraction of tiny steps
    "max_out_rank",          # 8.  max output rank
    "avg_out_rank",          # 9.  avg output rank
    "costw_out_rank",        # 10. cost-weighted output rank
    "p_at_max_cost_val",     # 11. p at max cost
    "max_red_rank_val",      # 12. max reduction rank
    "costw_red_rank_val",    # 13. cost-weighted reduction rank
    "k_at_max_cost_val",     # 14. k at max cost
    "max_asym_val",          # 15. max asymmetry
    "avg_asym",              # 16. avg asymmetry
    "costw_asym_val",        # 17. cost-weighted asymmetry
    "d_at_max_cost_val"      # 18. d at max cost
]


# Reduced feature subset (13 features) used by the model
features_13 = [
    "std_cost",
    "n_steps",
    "frac_tiny",
    "max_out_rank",
    "avg_out_rank",
    "costw_out_rank",
    "p_at_max_cost_val",
    "max_red_rank_val",
    "k_at_max_cost_val",
    "max_asym_val",
    "avg_asym",
    "costw_asym_val",
    "d_at_max_cost_val"
]


"""
    llegir_dataframe_excel_corregit(ruta_arxiu::String;
                                   nom_full::String="", versio=false)

Read a `DataFrame` from an Excel file (corrected version).

# Arguments
- `ruta_arxiu::String`: path to the Excel file.
- `nom_full::String=""`: name of the sheet to read. If empty, the first sheet
  is used.
- `versio::Bool=false`: if `true`, the Excel file handle is explicitly closed
  after reading.

# Returns
- `df::DataFrame`: the data read from the selected sheet.
"""
function llegir_dataframe_excel_corregit(ruta_arxiu::String;
                                         nom_full::String="", versio=false)
    try
        # Show information about the available sheets
        xf = XLSX.readxlsx(ruta_arxiu)
        fulls = XLSX.sheetnames(xf)
        println("📑 Available sheets: $fulls")

        # Decide which sheet to read
        full_a_llegir = isempty(nom_full) ? fulls[1] : nom_full
        println("📖 Reading sheet: '$full_a_llegir'")

        # Read the data as a DataTable
        datatable = XLSX.readtable(ruta_arxiu, full_a_llegir)

        # Convert the DataTable into a DataFrame
        df = DataFrame(datatable)

        if versio == true
            # Close the file
            XLSX.close(xf)
        end

        println("✅ DataFrame successfully read")
        println("📊 Dimensions: $(nrow(df)) rows × $(ncol(df)) columns")
        println("📋 Columns: $(names(df))")

        return df

    catch e
        println("❌ Error while reading the Excel file: $e")
        rethrow(e)
    end
end


"""
    selecciona_columnes(df, columnes)

Select the given `columnes` from `df`, raising an error if any of them is
missing.

# Arguments
- `df`: the input `DataFrame`.
- `columnes`: iterable of column names to select.

# Returns
- A new `DataFrame` containing only the requested columns.
"""
function selecciona_columnes(df, columnes)
    disponibles = Set(names(df))
    faltants = [c for c in columnes if !(c in disponibles)]
    if !isempty(faltants)
        error("Columns not found in the DataFrame: $faltants")
    end
    return select(df, columnes)
end


"""
    create_circuit_dataframe_direct(id_circuits, features_v, feature_names)

Build a `DataFrame` from a list of circuit identifiers and their corresponding
feature vectors.

# Arguments
- `id_circuits`: vector of circuit identifiers (stored in the `circuit_name`
  column).
- `features_v`: vector of feature vectors, one per circuit.
- `feature_names`: names of the features, in the same order as the entries of
  each feature vector.

# Returns
- `df::DataFrame`: one row per circuit, one column per feature.
"""
function create_circuit_dataframe_direct(id_circuits, features_v, feature_names)

    # Check dimensions
    if length(id_circuits) != length(features_v)
        error("circuit names and features do not match")
    end

    # DataFrame
    df = DataFrame()
    df.circuit_name = id_circuits

    # Fill it with features
    for (i, feature_name) in enumerate(feature_names)
        df[!, Symbol(feature_name)] = [feature_vector[i] for feature_vector in features_v]
    end

    return df
end


"""
    getting_candidate_plan(model, nom_v, features_v, feature_names, features_13;
                           empat=false)

Use the trained `model` to score a set of candidate contraction plans and print
the best one (or the set of best ones, in case of ties).

# Arguments
- `model`: trained XGBoost model used to predict speedups.
- `nom_v`: vector of candidate plan identifiers.
- `features_v`: vector of feature vectors, one per candidate plan.
- `feature_names`: full list of feature names.
- `features_13`: subset of feature names actually consumed by the model.
- `empat::Bool=false`: if `true`, print every candidate achieving the maximum
  predicted speedup; otherwise print only the first one.
"""
function getting_candidate_plan(model, nom_v, features_v, feature_names, features_13;
                                empat=false)

    df = create_circuit_dataframe_direct(nom_v, features_v, feature_names)
    columnes = append!(["circuit_name"], features_13)
    df_filtrat = selecciona_columnes(df, columnes)

    circuit_ids, predictions = Prediccions_X(model, df_filtrat)
    valors, posicions = maxims_i_posicions(predictions)

    if empat == false
        nom_complet = nom_v[posicions[1]]
        nom_circuit = split(nom_complet, "_pla_")[2]

        println("Our plan candidate : $(nom_circuit)")

    else
        println("Our plan candidates: ")
        for i in 1:length(posicions)
            nom_complet = nom_v[posicions[i]]
            nom_circuit = split(nom_complet, "_pla_")[2]
            println(nom_circuit)
        end
    end
    return
end


"""
    maxims_i_posicions(v)

Return the maximum value of `v` together with the indices at which it occurs.

# Arguments
- `v`: numeric vector.

# Returns
- `(valors, posicions)`: a vector filled with the maximum value (one entry per
  occurrence) and the vector of positions where the maximum is attained.
"""
function maxims_i_posicions(v)
    max_val = maximum(v)
    posicions = findall(==(max_val), v)
    valors = fill(max_val, length(posicions))
    return valors, posicions
end


"""
    Prediu_Speedup(model, dades_features)

Predict the speedup for a single observation.

# Arguments
- `model`: trained XGBoost model.
- `dades_features`: feature vector for a single observation.

# Returns
- `prediction::Float64`: the predicted speedup.
"""
function Prediu_Speedup(model, dades_features)

    # Reshape into a matrix (1 observation, n features)
    X_new = reshape(dades_features, 1, :)

    # Make the prediction
    prediction = XGBoost.predict(model, X_new)

    return prediction[1]
end


"""
    Prediccions_X(model, df_circuits)

Compute predictions for every row of `df_circuits`.

# Arguments
- `model`: trained XGBoost model.
- `df_circuits::DataFrame`: table of candidate plans; the first column holds
  the circuit identifiers and columns 2:14 hold the features.

# Returns
- `(circuit_ids, predictions)`: the vector of circuit identifiers and the
  vector of predicted speedups.
"""
function Prediccions_X(model, df_circuits)

    circuit_ids = df_circuits.circuit_name

    predictions = Float64[]

    for id in 1:length(circuit_ids)

        dades_features = Vector{Float64}(df_circuits[id, Cols(2:14)])
        predicted_speedup = Prediu_Speedup(model, dades_features)

        push!(predictions, predicted_speedup)

    end

    return (circuit_ids=circuit_ids, predictions=predictions)
end

"""
    getting_ordered_plans(model, nom_v, features_v, feature_names, features_13;
                          n=7, verbose=true)

Rank a set of candidate contraction plans using a trained LTR model and
return the top `n` plan identifiers, ordered from best to worst predicted
speedup.

The candidate plans are first collected into a `DataFrame`, restricted to
the model's feature set (`features_13`), and scored via `Prediccions_X`. The
predictions are then sorted in descending order, and the plans whose
predicted score matches each distinct value are grouped together, so that
tied candidates are kept together. The top `n` plan identifiers (with the
`_pla_` prefix stripped) are returned as a vector.

# Arguments
- `model`: trained XGBoost model.
- `nom_v`: vector of candidate plan identifiers (one per feature vector).
- `features_v`: vector of feature vectors, one per candidate plan.
- `feature_names`: full list of feature names.
- `features_13`: subset of feature names actually consumed by the model.
- `n::Int=7`: number of top candidates to return.
- `verbose::Bool=true`: if `true`, the ordered candidates are printed to
  stdout.

# Returns
- `plans_ordenats::Vector{String}`: the top `n` plan identifiers, ordered
  from best to worst predicted speedup.
"""
function getting_ordered_plans(model, nom_v, features_v, feature_names, features_13;
                               n=7, verbose=true)

    resultats = []
    plans_ordenats = []

    # Build the candidate data frame, keeping only the model's features
    df = create_circuit_dataframe_direct(nom_v, features_v, feature_names)
    columnes = append!(["circuit_name"], features_13)
    df_filtrat = selecciona_columnes(df, columnes)

    # Score every candidate
    circuit_ids, v = Prediccions_X(model, df_filtrat)

    # Distinct predicted values, sorted in descending order
    prediccions_uniques = sort(unique(v), rev=true)

    # Group candidates by distinct predicted score
    j = 0
    for prev in prediccions_uniques
        j = j + 1
        indices_top_pred = findall(x -> x ≈ prediccions_uniques[j], v)
        quantitat = length(indices_top_pred)
        circuits = [circuit_ids[i] for i in indices_top_pred]
        push!(resultats, circuits)
    end

    # Flatten the per-score groups into a single ordered list
    tots = resultats[1]
    for i in 2:length(resultats)
        tots = union(tots, resultats[i])
    end

    if verbose == true
        println("Our $n ordered plan candidates: ")
    end

    # Extract the top `n` plan identifiers, stripping the `_pla_` prefix
    for i in 1:n
        nom_complet = tots[i]
        nom_pla = split(nom_complet, "_pla_")[2]
        if verbose == true
            println(nom_pla)
        end
        push!(plans_ordenats, nom_pla)
    end

    return plans_ordenats
end







