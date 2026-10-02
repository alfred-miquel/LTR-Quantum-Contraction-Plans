

# =============================================================================
# Funcions_de_Features.jl 
# =============================================================================
# Functions related to the computation of features from tensor contraction
# data.
# =============================================================================

using DataFrames, Statistics   

"""
    calcul_Ci_Pi_Di(contractions; epsilon=1.0e-6)

Compute the three basic per-contraction metrics:

- `Ci`: computational cost, `rankA + rankB - num_common_indices`.
- `Pi`: potential parallelism, `rankA + rankB - 2*num_common_indices`.
- `Di`: imbalance / asymmetry, `|rankA - rankB| / (Pi + epsilon)`.

# Arguments
- `contractions`: vector of structures with fields `.rankA`, `.rankB` and
  `.num_common_indices`.
- `epsilon::Float64=1.0e-6`: small constant to avoid division by zero.

# Returns
- `(Ci, Pi, Di)`: a tuple of `Vector{Float64}`.
"""
function calcul_Ci_Pi_Di(contractions; epsilon=1.0e-6)
    n = length(contractions)
    Ci = Vector{Float64}(undef, n)
    Pi = Vector{Float64}(undef, n)
    Di = Vector{Float64}(undef, n)

    for i in 1:n
        ci = contractions[i].rankA + contractions[i].rankB - contractions[i].num_common_indices
        Ci[i] = ci

        pi = (contractions[i].rankA + contractions[i].rankB) - (2 * contractions[i].num_common_indices)
        Pi[i] = pi

        di = abs(contractions[i].rankA - contractions[i].rankB) / (pi + epsilon)
        Di[i] = di
    end

    return Ci, Pi, Di
end


"""
    calcul_Ci_Pi_Di_Ki(contractions; epsilon=1.0e-6)

Extended version that also returns `Ki` (number of common indices /
reduction rank).
"""
function calcul_Ci_Pi_Di_Ki(contractions; epsilon=1.0e-6)
    n = length(contractions)
    Ci = Vector{Float64}(undef, n)
    Pi = Vector{Float64}(undef, n)
    Di = Vector{Float64}(undef, n)
    Ki = Vector{Float64}(undef, n)

    for i in 1:n
        Ci[i] = contractions[i].rankA + contractions[i].rankB - contractions[i].num_common_indices
        Pi[i] = (contractions[i].rankA + contractions[i].rankB) - (2 * contractions[i].num_common_indices)
        Di[i] = abs(contractions[i].rankA - contractions[i].rankB) / (Pi[i] + epsilon)
        Ki[i] = contractions[i].num_common_indices
    end

    return Ci, Pi, Di, Ki
end


# =============================================================================
# Auxiliary functions
# =============================================================================

"""
    tots_maxims(v)

Return the maximum value of a vector together with every position at which
it occurs.
"""
function tots_maxims(v)
    max_val = maximum(v)
    posicions = findall(x -> x == max_val, v)
    return max_val, posicions
end


"""
    valors_per_dalt_de(v; limit=0.9)

Return the elements of the vector that exceed a threshold.

# Returns
- `(limit, quantitat, posicions)`: the threshold, the number of values above
  it, and the positions where they occur.
"""
function valors_per_dalt_de(v; limit=0.9)
    posicions = findall(x -> x >= limit, v)
    quantitat = length(posicions)
    return limit, quantitat, posicions
end


"""
    mitjana_top_q_percent(v; q=5)

Compute the mean of the top `q%` highest values of the vector.

# Returns
- `(mean, top_elements)`: the mean of the selected top values and the values
  themselves.
"""
function mitjana_top_q_percent(v; q=5)
    v_ordenat = sort(v, rev=true)
    n = length(v)
    k = max(1, round(Int, n * q / 100))
    top_elements = v_ordenat[1:k]
    return mean(top_elements), top_elements
end


"""
    fracc_tiny_steps(Ci; tau=6)

F10: fraction of "tiny" steps, i.e. those with `Ci ≤ max(Ci) - tau`.
Indicates how many steps are far below the bottleneck.
"""
function fracc_tiny_steps(Ci; tau=6)
    max_cost = maximum(Ci)
    return sum(Ci .<= (max_cost - tau)) / length(Ci)
end


# =============================================================================
# Bottleneck features
# =============================================================================

"""
    coll_ampolla(Ci, Di, Pi)

Compute metrics related to the bottleneck:

- `max_cost_Ci`: maximum cost.
- `max_imbalance_Di`: maximum imbalance.
- `P_at_maxC`: mean parallelism at the maximum-cost points.
- `D_at_maxC`: mean imbalance at the maximum-cost points.
"""
function coll_ampolla(Ci, Di, Pi)
    max_cost_Ci = maximum(Ci)
    posicions_max = findall(==(max_cost_Ci), Ci)
    max_imbalance_Di = maximum(Di)

    P_at_maxC = sum(Pi[posicions_max]) / length(posicions_max)
    D_at_maxC = sum(Di[posicions_max]) / length(posicions_max)

    return max_cost_Ci, max_imbalance_Di, P_at_maxC, D_at_maxC
end


"""
    coll_ampolla_ampliada(Ci, Di, Pi)

Extended version that also returns `topq_mean_C`.
"""
function coll_ampolla_ampliada(Ci, Di, Pi)
    max_cost_Ci = maximum(Ci)
    posicions_max = findall(==(max_cost_Ci), Ci)
    max_imbalance_Di = maximum(Di)

    P_at_maxC = sum(Pi[posicions_max]) / length(posicions_max)
    D_at_maxC = sum(Di[posicions_max]) / length(posicions_max)
    topq_mean_C, _ = mitjana_top_q_percent(Ci)

    return max_cost_Ci, max_imbalance_Di, P_at_maxC, D_at_maxC, topq_mean_C
end


"""
    k_at_max_cost(Ci, Ki)

*** NEW FUNCTION (PREVIOUSLY MISSING) ***

`K` at max cost: mean of `Ki` (reduction rank) over the steps where `Ci`
attains its maximum.

Interpretation: proxy for the arithmetic intensity at the bottleneck.
"""
function k_at_max_cost(Ci, Ki)
    max_cost = maximum(Ci)
    posicions_max = findall(==(max_cost), Ci)
    return mean(Ki[posicions_max])
end


# =============================================================================
# Cost-weighted features
# =============================================================================

"""
    cost_w_P(Ci, Pi)

Cost-weighted out-rank: `Σ (Pi * 2^Ci) / Σ 2^Ci`.
"""
function cost_w_P(Ci, Pi)
    pesos = 2.0 .^ Ci
    return sum(Pi .* pesos) / sum(pesos)
end


"""
    cost_w_D(Ci, Di)

Cost-weighted asymmetry: `Σ (Di * 2^Ci) / Σ 2^Ci`.
"""
function cost_w_D(Ci, Di)
    pesos = 2.0 .^ Ci
    return sum(Di .* pesos) / sum(pesos)
end


"""
    cost_w_K(Ci, Ki)

Cost-weighted reduction rank: `Σ (Ki * 2^Ci) / Σ 2^Ci`.
"""
function cost_w_K(Ci, Ki)
    pesos = 2.0 .^ Ci
    return sum(Ki .* pesos) / sum(pesos)
end


# =============================================================================
# Asymmetry features
# =============================================================================

"""
    max_asym(Di)

*** NEW FUNCTION (PREVIOUSLY MISSING) ***

Maximum asymmetry `max(Di)` of the plan.

Interpretation: worst contraction imbalance (skinny vs. square).
"""
function max_asym(Di)
    return maximum(Di)
end


"""
    cost_w_asym(Ci, Di)

*** NEW FUNCTION (PREVIOUSLY MISSING) ***

Cost-weighted asymmetry: `Σ (Di * 2^Ci) / Σ 2^Ci`.

Interpretation: shape imbalance in the expensive region of the plan.
"""
function cost_w_asym(Ci, Di)
    pesos = 2.0 .^ Ci
    return sum(Di .* pesos) / sum(pesos)
end


# =============================================================================
# Other features
# =============================================================================

"""
    log_2_sum_flops(Ci)

F2: `log2(Σ 2^Ci)` — proxy for the total logarithmic FLOPS.
"""
function log_2_sum_flops(Ci)
    return log2(sum(2.0 .^ Ci))
end


"""
    max_red_rank(Ki)

F5: maximum reduction rank, `max(Ki)`.
"""
function max_red_rank(Ki)
    return maximum(Ki)
end


# =============================================================================
# Main feature extraction functions
# =============================================================================

using Statistics

"""
    get_features_v2(contractions)

Extract every feature according to version 2 of the document.

# Arguments
- `contractions`: vector of contraction structures.

# Returns
- `Vector`: the 13 features of version 2, in the order used by the model.
"""
function get_features_v2(contractions)
    Ci, Pi, Di = calcul_Ci_Pi_Di(contractions)
    max_cost_Ci, max_imbalance_Di, P_at_maxC, D_at_maxC, topq_mean_C = coll_ampolla_ampliada(Ci, Di, Pi)
    cost_weighted_P = cost_w_P(Ci, Pi)
    cost_weighted_D = cost_w_D(Ci, Di)

    N_steps = length(contractions)
    avg_cost_Ci = sum(Ci) / N_steps
    avg_parallelism_Pi = sum(Pi) / N_steps
    avg_imbalance_Di = sum(Di) / N_steps

    std_C = std(Ci)
    max_parallelism_Pi = maximum(Pi)

    return [max_cost_Ci, max_imbalance_Di, P_at_maxC, D_at_maxC, topq_mean_C,
            cost_weighted_P, cost_weighted_D, avg_cost_Ci, avg_parallelism_Pi,
            avg_imbalance_Di, std_C, N_steps, max_parallelism_Pi]
end


"""
    get_features_v5(contractions)

Extract every feature according to version 5 of the document (full table).
Includes ALL 18 features of the table.

# Arguments
- `contractions`: vector of contraction structures.

# Returns
- `Vector`: the 18 features in the order of the table.
"""
function get_features_v5(contractions)
    # Basic metrics
    Ci, Pi, Di, Ki = calcul_Ci_Pi_Di_Ki(contractions)

    # Complexity / bottleneck features (7 features)
    max_cost = maximum(Ci)                                    # max cost
    log2_sum_flops_val = log_2_sum_flops(Ci)                  # log2 sum flops
    topq_mean, _ = mitjana_top_q_percent(Ci)                  # topq mean cost
    avg_cost = mean(Ci)                                       # avg cost
    std_cost = std(Ci)                                        # std cost
    n_steps = length(Ci)                                      # n steps
    frac_tiny = fracc_tiny_steps(Ci)                          # frac tiny steps

    # Parallelism features (4 features)
    max_out_rank = maximum(Pi)                                # max out rank
    avg_out_rank = mean(Pi)                                   # avg out rank
    costw_out_rank = cost_w_P(Ci, Pi)                         # costw out rank
    p_at_max_cost_val = coll_ampolla(Ci, Di, Pi)[3]           # p at max cost

    # Reduction / intensity features (3 features)
    max_red_rank_val = max_red_rank(Ki)                       # max red rank
    costw_red_rank_val = cost_w_K(Ci, Ki)                     # costw red rank
    k_at_max_cost_val = k_at_max_cost(Ci, Ki)                 # k at max cost (NEW)

    # Geometry / memory features (4 features)
    max_asym_val = max_asym(Di)                               # max asym (NEW)
    avg_asym = mean(Di)                                       # avg asym
    costw_asym_val = cost_w_asym(Ci, Di)                      # costw asym (NEW)
    d_at_max_cost_val = coll_ampolla(Ci, Di, Pi)[4]           # d at max cost

    # Vector with the 18 features in the order of the table
    features = [
        max_cost,              # 1.  max cost
        log2_sum_flops_val,    # 2.  log2 sum flops
        topq_mean,             # 3.  topq mean cost
        avg_cost,              # 4.  avg cost
        std_cost,              # 5.  std cost
        n_steps,               # 6.  n steps
        frac_tiny,             # 7.  frac tiny steps
        max_out_rank,          # 8.  max out rank
        avg_out_rank,          # 9.  avg out rank
        costw_out_rank,        # 10. costw out rank
        p_at_max_cost_val,     # 11. p at max cost
        max_red_rank_val,      # 12. max red rank
        costw_red_rank_val,    # 13. costw red rank
        k_at_max_cost_val,     # 14. k at max cost (NEW)
        max_asym_val,          # 15. max asym (NEW)
        avg_asym,              # 16. avg asym
        costw_asym_val,        # 17. costw asym (NEW)
        d_at_max_cost_val      # 18. d at max cost
    ]

    return features
end


# =============================================================================
# Input / output functions
# =============================================================================

"""
    extraure_nom_circuit(nom_arxiu::String)::String

Extract the circuit name from a file name of the form `"resultats_NOM.txt"`.
"""
function extraure_nom_circuit(nom_arxiu::String)::String
    patro = r"^resultats_(.+)\.txt$"
    coincidencia = match(patro, nom_arxiu)

    if coincidencia !== nothing
        return coincidencia.captures[1]
    elseif startswith(nom_arxiu, "resultats_") && endswith(nom_arxiu, ".txt")
        return nom_arxiu[11:end-4]
    else
        return nom_arxiu
    end
end


"""
    get_contractions(filename)

Read a file and return the contractions it contains.

# Arguments
- `filename::String`: path to the contraction log file.

# Returns
- `contractions::Vector{Contraction}`: the parsed contractions.
"""
function get_contractions(filename)
    contractions, comptador, ranks_A, ranks_B, ranks_C, ranks_AB, ranks_AB_d, Zeros =
        read_contractions_analisi_ranks_indexs(filename, verbose=false)

    return contractions
end



using DataFrames, Statistics   #, Plots


"""
    Contraction

Container for the data describing a single pairwise tensor contraction.

# Fields
- `tensorA::String`: identifier of the first tensor.
- `tensorB::String`: identifier of the second tensor.
- `tensorC::String`: identifier of the resulting tensor.
- `rankA::Int`: rank of tensor A.
- `rankB::Int`: rank of tensor B.
- `rankC::Int`: rank of tensor C.
- `common_indices::String`: whitespace-joined list of the contracted indices.
- `num_common_indices::Int`: number of contracted (common) indices.
- `time::Float64`: wall-clock time of the contraction, in seconds.
"""
struct Contraction
    tensorA::String
    tensorB::String
    tensorC::String
    rankA::Int
    rankB::Int
    rankC::Int
    common_indices::String
    num_common_indices::Int
    time::Float64
end






# Maximum rank that two tensors can share (upper bound, deliberately large)
const index_max = 100


"""
    read_contractions_analisi_ranks_indexs(filename::String; verbose=true)

Parse a contraction log file and collect per-rank and per-index-count
statistics.

Each line of `filename` is expected to be whitespace-separated and to contain,
in order:

    tensorA tensorB tensorC rankA rankB rankC <common indices...> time

The number of common indices is derived from the ranks via
`((rankA + rankB) - rankC) / 2`, so it does not need to be stored explicitly
in the file.

# Arguments
- `filename::String`: path to the contraction log file.
- `verbose::Bool=true`: if `true`, per-line diagnostics and anomalous
  contractions are printed to stdout.

# Returns
- `contractions::Vector{Contraction}`: the parsed contractions.
- `comptador`: histogram of the number of common indices.
- `ranks_A`, `ranks_B`, `ranks_C`: histograms of the ranks of A, B and C.
- `ranks_AB`: histogram of `rankA + rankB`.
- `ranks_AB_d`: histogram of `|rankA - rankB|`.
- `zeros`: list of `(rankA, rankB)` pairs for which `|rankA - rankB| == 0`.
"""
function read_contractions_analisi_ranks_indexs(filename::String; verbose=true)

    # Initialise the counters
    comptador = [0 for i in 1:index_max]
    ranks_A   = [0 for i in 1:index_max]
    ranks_B   = [0 for i in 1:index_max]
    ranks_C   = [0 for i in 1:index_max]
    # Sum-of-ranks vector
    ranks_AB   = [0 for i in 1:2*index_max]
    ranks_AB_d = [0 for i in 1:index_max]
    zeros = []   # debug element: cases where the rank difference is zero
    contractions = Contraction[]

    open(filename, "r") do file
        for line in eachline(file)
            # Split the line into its components
            parts = split(line)

            # Extract the basic fields
            tensorA = parts[1]
            tensorB = parts[2]
            tensorC = parts[3]
            rankA = parse(Int, parts[4])
            rankB = parse(Int, parts[5])
            rankC = parse(Int, parts[6])

            rankAB = rankA + rankB       # sum of the two ranks
            rankAB_d = abs(rankA - rankB) # absolute rank difference

            if verbose == true
                println("-----------------------------")
                println("rankAB_d: $rankAB_d ")
                println("rankC: $rankC")
                println("rankA: $rankA")
                println("rankB: $rankB")
            end

            # Common indices may contain spaces, so join them back together
            common_indices = join(parts[7:end-1], " ")
            # num_common_indices = parse(Int, parts[end-1])  # compute instead
            divisio = ((rankA + rankB) - rankC) / 2
            num_common_indices = Int(divisio)
            # println(num_common_indices)

            time = parse(Float64, parts[end])

            a = Contraction(tensorA, tensorB, tensorC,
                            rankA, rankB, rankC,
                            common_indices, num_common_indices, time)

            if num_common_indices > 1 && verbose
                println(a)
            end

            # Data collection
            # comptador[num_common_indices] = comptador[num_common_indices] + 1
            ranks_A[rankA] = ranks_A[rankA] + 1
            ranks_B[rankB] = ranks_B[rankB] + 1
            ranks_AB[rankA+rankB] = ranks_AB[rankA+rankB] + 1

            if rankAB_d != 0
                ranks_AB_d[rankAB_d] = ranks_AB_d[rankAB_d] + 1
            else
                if verbose == true
                    println("The absolute rank difference between A and B is zero")
                    println("-----------------------------")
                    println()
                end

                push!(zeros, (rankA, rankB))
            end

            if rankC != 0
                ranks_C[rankC] = ranks_C[rankC] + 1
                comptador[num_common_indices] = comptador[num_common_indices] + 1
            else
                if verbose == true
                    println("The contraction of two tensors of rank A $rankA and rank B $rankB produced a tensor C of rank $rankC ")
                    println("This is normally the final contraction")
                    println()
                end
            end

            # Store the contraction and update the sum-of-ranks vector
            push!(contractions, a)

            # println(contractions)
        end
    end
    return contractions, comptador, ranks_A, ranks_B, ranks_C, ranks_AB, ranks_AB_d, zeros
end





