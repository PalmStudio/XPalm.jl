"""
    mtg_skeleton(parameters; rng=Random.MersenneTwister(parameters["seed"]))

Makes an MTG skeleton with `nb_leaves_emitted` leaves, including all intermediate organs:

- Plant: the whole palm
- Stem: the stem of the plant, *i.e.* the remaining part of the plant after the leaves have been removed
- Phytomer: the part that includes the leaf and the internode
- Internodes: the part of the phytomer that is between two leaves
- Leaf: the leaf of the plant, also called frond

Note: this skeleton does not include reproductive organs (inflorescences, fruits) or the scales that decompose the leaf (petiole, rachis, leaflets).

# Arguments

- `parameters`: The parameters for the MTG skeleton. See `VPalm.default_parameters()` for the default parameters.
- `rng`: (optional) The random number generator to use for stochastic processes. Defaults to `Random.MersenneTwister(parameters["seed"])`, but can be set to `nothing` to disable randomness (for testing).

# Examples

```julia
file = joinpath(dirname(dirname(pathof(VPalm))), "test", "files", "parameter_file.yml")
parameters = read_parameters(file)
mtg_skeleton(parameters)
```
"""
function mtg_skeleton(parameters; rng=Random.MersenneTwister(parameters["seed"]))
    rachis_fresh_biomasses = copy(parameters["rachis_fresh_weight"])
    rank_1_leaf_biomass = copy(rachis_fresh_biomasses[end]) # The fresh biomass of the youngest leaf (rank = 1)

    nb_internodes = parameters["nb_leaves_emitted"] + parameters["nb_internodes_before_planting"] # The number of internodes emitted since the seed
    nb_leaves_alive = length(rachis_fresh_biomasses)
    nb_leaves_alive = min(nb_leaves_alive, nb_internodes)


    # This is optional, it may be computed from the biomass if not provided
    if haskey(parameters, "rachis_final_lengths")
        final_lengths = copy(parameters["rachis_final_lengths"])
    else # If the parameter is missing, we use leaf_length_intercept and leaf_length_slope to compute the final lengths from the fresh biomass
        final_lengths = rachis_length_from_biomass.(rachis_fresh_biomasses, parameters["leaf_length_intercept"], parameters["leaf_length_slope"])
    end

    rank_1_leaf_length = copy(final_lengths[end]) # The length of the youngest leaf (rank = 1)
    @assert length(final_lengths) == nb_leaves_alive "The number of rachis final lengths (`rachis_final_lengths`) should be equal to the number of leaves alive ($nb_leaves_alive)."

    unique_mtg_id = Ref(1)
    # Plant / Scale 1
    plant = Node(NodeMTG("/", "Plant", 1, 1))
    unique_mtg_id[] += 1

    # Stem (& Roots) / Scale 2
    #roots = Node(plant, NodeMTG("+", "RootSystem", 1, 2))
    stem = Node(unique_mtg_id[], plant, NodeMTG("+", "Stem", 1, 2))
    unique_mtg_id[] += 1

    # The reference leaf is usually the leaf at rank 17, but it can be less if there are not enough leaves (9, or 6 or 3, or 1).
    reference_leaf = if length(final_lengths) >= 17
        17
    elseif length(final_lengths) >= 9
        9
    elseif length(final_lengths) >= 6
        6
    elseif length(final_lengths) >= 3
        3
    else
        1
    end

    compute_properties_stem!(stem, parameters, final_lengths[reference_leaf]; rng=rng)

    stem_height = stem[:stem_height]
    stem_diameter = stem[:stem_diameter]

    # Phytomer / Scale 3
    phytomer = Node(unique_mtg_id[], stem, NodeMTG("/", "Phytomer", 1, 3))
    unique_mtg_id[] += 1

    # Loop on internodes
    for i in 1:nb_internodes
        if i > 1
            phytomer = Node(unique_mtg_id[], phytomer, NodeMTG("<", "Phytomer", i, 3))
            unique_mtg_id[] += 1
        end
        internode = Node(unique_mtg_id[], phytomer, NodeMTG("/", "Internode", i, 4))
        unique_mtg_id[] += 1

        rank = compute_leaf_rank(nb_internodes, i, parameters["nb_leaves_in_sheath"])

        compute_properties_internode!(internode, i, nb_internodes, rank, stem_height, stem_diameter, parameters, rng)
        leaf_node = Node(unique_mtg_id[], internode, NodeMTG("+", "Leaf", i, 4))
        unique_mtg_id[] += 1
        leaf_node.rank = rank
        leaf_node.is_alive = leaf_node.rank <= nb_leaves_alive
        final_length = if leaf_node.is_alive
            if leaf_node.rank <= 0
                # If the leaf is a spear, we estimate its future length using the length of the youngest leaf
                rank_1_leaf_length
            else
                popfirst!(final_lengths)
            end
        else
            0.0
        end

        if leaf_node.is_alive
            rachis_fresh_biomass = leaf_node.rank <= 0 ? rank_1_leaf_biomass : pop!(rachis_fresh_biomasses)
            leaf(unique_mtg_id, i, rank, rachis_fresh_biomass, final_length, leaf_node, parameters; rng=rng)
        else
            compute_properties_leaf!(leaf_node, leaf_node.rank, final_length, parameters, rng)
        end
    end

    return plant
end


"""
    init_attributes_seed!(plant, parameters; rng=Random.MersenneTwister(parameters["seed"]))


Initialize the attributes of a palm plant seed (one internode with one leaf), based on the provided parameters.
"""
function init_attributes_seed!(plant, parameters; rng=Random.MersenneTwister(parameters["seed"]))
    nb_leaves_in_sheath = 0# parameters["nb_leaves_in_sheath"]
    biomass_first_leaf =
        uconvert(
            u"kg",
            parameters["dimensions"]["leaf"]["leaf_area_first_leaf"] * parameters["mass_and_dimensions"]["leaf"]["lma_min"] /
            parameters["biomass"]["leaf"]["leaflets_biomass_contribution"] * u"g"
        )

    parameters = parameters["vpalm"]
    final_length = rachis_length_from_biomass(biomass_first_leaf, parameters["leaf_length_intercept"], parameters["leaf_length_slope"])

    stem = plant[2]
    compute_properties_stem!(stem, parameters, final_length; rng=rng)

    stem_height = stem[:stem_height]
    stem_diameter = stem[:stem_diameter]

    nb_internodes = descendants(plant, symbol="Internode") |> length
    i = 0
    unique_mtg_id = Ref(new_id(plant))
    traverse!(plant, symbol="Internode") do internode
        i += 1
        rank = compute_leaf_rank(nb_internodes, i, nb_leaves_in_sheath)

        compute_properties_internode!(internode, i, nb_internodes, rank, stem_height, stem_diameter, parameters, rng)
        leaf_node = internode[1]
        leaf_node.is_alive = true

        leaf(unique_mtg_id, i, rank, biomass_first_leaf, final_length, leaf_node, parameters; rng)
    end

    return plant
end