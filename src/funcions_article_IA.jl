################################################################################
## New functions for the article
################################################################################

"""
    contract_tn_rank_mock!(tn::TensorNetwork, plan::Array{NTuple{3, Symbol}, 1};
                           mock::Bool=false, verbose::Bool=true)

Contract all pairs of tensors specified in `plan` following the given order,
and then contract any remaining disjoint tensors.

# Arguments
- `tn::TensorNetwork`: the tensor network to contract.
- `plan::Array{NTuple{3, Symbol}, 1}`: contraction plan, each entry is a tuple
  `(A_id, B_id, C_id)` indicating that tensors `A_id` and `B_id` must be
  contracted into `C_id`.
- `mock::Bool=false`: if `true`, only mock tensors (correct dimensions but no
  data) are produced.
- `verbose::Bool=true`: if `true`, per-contraction timing is printed to stdout.

# Returns
- `temps_total::Float64`: total contraction time (in seconds), including the
  final disjoint-tensor contraction.

# Side effects
Writes per-contraction timings to `fitxer_sortida.txt`.
"""
function contract_tn_rank_mock!(tn::TensorNetwork, plan::Array{NTuple{3, Symbol}, 1};
                                mock::Bool=false, verbose::Bool=true)
    acum = 0
    llargaria = length(tn)

    # Open output file to log contraction timings
    f = open("fitxer_sortida.txt", "w")

    for (A_id, B_id, C_id) in plan
        @assert haskey(tn.tensor_map, A_id)
        @assert haskey(tn.tensor_map, B_id)

        # Time each pairwise contraction
        stats = @timed contract_pair_rank!(f, tn, A_id, B_id, C_id;
                                           mock=mock, verbose=verbose)

        println
        if verbose
            println("$(stats.time)")
        end
        println(f, "$(stats.time)")

        acum = acum + stats.time   # accumulate pairwise contraction times
    end

    close(f)   # Important: close the file!

    println()
    println("Now we contract the rest of the network, i.e. the disjoint vectors")

    # Contract any disjoint tensors that may remain before returning the result.
    stats_b = @timed simple_contraction_rank!(tn)
    temps_total = acum + stats_b.time

    println("The contraction time of the disjoint network is $(stats_b.time)")
    println()
    println("The TOTAL CONTRACTION of the network of length $llargaria, " *
            "final tensor $(keys(tn.tensor_map)) with value $(values(tn.tensor_map)) " *
            "and a plan of length $(length(plan)) takes: $temps_total")

    println("------------------------------------------------------------------------------------------------")

    return temps_total
end


"""
    simple_contraction_rank!(f::IO, tn::TensorNetwork)

Perform a simple contraction, contracting all tensors in order.
Only useful for very small networks, for testing purposes.

# Arguments
- `f::IO`: output stream used to log contraction information.
- `tn::TensorNetwork`: the tensor network to contract.
"""
function simple_contraction_rank!(f::IO, tn::TensorNetwork)
    tensor_syms = collect(keys(tn))
    A = tensor_syms[1]

    for B in tensor_syms[2:end]
        println("We have contracted disjoint tensors $A with rank $(tn.:tensor_map[A].rank) " *
                "and $B with rank $(tn.:tensor_map[B].rank)")

        t1 = time()
        A = contract_pair_rank!(f, tn, A, B)
        elapsed_time = time() - t1

        println("The result of the disjoint contraction is $A with rank " *
                "$(tn.:tensor_map[A].rank) and it took $elapsed_time")
        println()
    end
    store(tn[A])
end


"""
    simple_contraction_rank!(tn::TensorNetwork)

Perform a simple contraction, contracting all tensors in order.
Only useful for very small networks, for testing purposes.

# Arguments
- `tn::TensorNetwork`: the tensor network to contract.
"""
function simple_contraction_rank!(tn::TensorNetwork)
    tensor_syms = collect(keys(tn))
    A = tensor_syms[1]

    for B in tensor_syms[2:end]
        println("We have contracted disjoint tensors $A with rank $(tn.:tensor_map[A].rank) " *
                "and $B with rank $(tn.:tensor_map[B].rank)")

        t1 = time()
        A = contract_pair!(tn, A, B)
        elapsed_time = time() - t1

        println("The result of the disjoint contraction is $A with rank " *
                "$(tn.:tensor_map[A].rank) and it took $elapsed_time")
        println()
    end
    store(tn[A])
end


"""
    contract_pair_rank!(f::IO, tn::TensorNetwork, a_sym::Symbol, b_sym::Symbol,
                        c_sym::Symbol=:_; mock::Bool=false, verbose::Bool=true)

Contract the tensors in `tn` with ids `a_sym` and `b_sym`, storing the result
under `c_sym`. If `c_sym` is not provided (`:_`), a new symbol is generated.

# Arguments
- `f::IO`: output stream used to log contraction details.
- `tn::TensorNetwork`: the tensor network.
- `a_sym::Symbol`: id of the first tensor to contract.
- `b_sym::Symbol`: id of the second tensor to contract.
- `c_sym::Symbol=:_`: id under which to store the result.
- `mock::Bool=false`: if `true`, the resulting tensor is a mock tensor with
  the correct dimensions but no actual data.
- `verbose::Bool=true`: if `true`, contraction details are printed to stdout.

# Returns
- `c_sym::Symbol`: the id under which the contracted tensor was stored.
"""
function contract_pair_rank!(f::IO, tn::TensorNetwork, a_sym::Symbol, b_sym::Symbol,
                             c_sym::Symbol=:_;
                             mock::Bool=false, verbose::Bool=true)
    Dades = []
    c = contract_pair(tn, a_sym, b_sym; mock=mock)

    # Get and contract tensors a and b to create tensor c
    a = tn.tensor_map[a_sym]
    b = tn.tensor_map[b_sym]
    c_sym == :_ && (c_sym = next_tensor_id!(tn))

    # Remove the contracted indices from the bond map in tn. Also, replace all
    # references in tn to tensors a and b with a reference to tensor c.
    common_indices = intersect(inds(a), inds(b))

    for ind in common_indices
        delete!(tn.bond_map, ind)
    end
    for ind in symdiff(inds(a), inds(b))
        tn.bond_map[ind] = replace(tn.bond_map[ind], a_sym => c_sym, b_sym => c_sym)
    end

    # Add tensor c to tn and remove both a and b
    tn.tensor_map[c_sym] = c
    delete!(tn.tensor_map, a_sym)
    delete!(tn.tensor_map, b_sym)

    if verbose
        print("$(a_sym) $(b_sym) $(c_sym) $(a.rank) $(b.rank) $(c.rank)  $common_indices ")
    end
    print(f, "$(a_sym) $(b_sym) $(c_sym) $(a.rank) $(b.rank) $(c.rank)  $common_indices ")

    c_sym
end
