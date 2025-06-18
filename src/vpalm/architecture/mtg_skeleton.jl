"""
    mtg_skeleton(nb_internodes)

Makes an MTG skeleton with `nb_leaves_emitted` leaves, including all intermediate organs:

- Plant: the whole palm
- Stem: the stem of the plant, *i.e.* the remaining part of the plant after the leaves have been removed
- Phytomer: the part that includes the leaf and the internode
- Internodes: the part of the phytomer that is between two leaves
- Leaf: the leaf of the plant, also called frond

Note: this skeleton does not include reproductive organs (inflorescences, fruits) or the scales that decompose the leaf (petiole, rachis, leaflets).

# Arguments

- `nb_internodes`: The number of internodes to emit.

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
        rank_1_leaf_length = copy(final_lengths[end]) # The length of the youngest leaf (rank = 1)
        @assert length(final_lengths) == nb_leaves_alive "The number of rachis final lengths (`rachis_final_lengths`) should be equal to the number of leaves alive ($nb_leaves_alive)."
    else # If the parameter is missing, we use leaf_length_intercept and leaf_length_slope to compute the final lengths from the fresh biomass
        final_lengths = rachis_length_from_biomass.(rachis_fresh_biomasses, parameters["leaf_length_intercept"], parameters["leaf_length_slope"])
    end

    unique_mtg_id = Ref(1)
    # Plant / Scale 1
    plant = Node(MutableNodeMTG("/", "Plant", 1, 1))
    unique_mtg_id[] += 1

    # Stem (& Roots) / Scale 2
    #roots = Node(plant, MutableNodeMTG("+", "RootSystem", 1, 2))
    stem = Node(unique_mtg_id[], plant, MutableNodeMTG("+", "Stem", 1, 2))
    unique_mtg_id[] += 1

    compute_properties_stem!(stem, parameters, rng)

    stem_height = stem[:stem_height]
    stem_diameter = stem[:stem_diameter]

    # Phytomer / Scale 3
    phytomer = Node(unique_mtg_id[], stem, MutableNodeMTG("/", "Phytomer", 1, 3))
    unique_mtg_id[] += 1

    # Loop on internodes
    for i in 1:nb_internodes
        if i > 1
            Node(unique_mtg_id[], phytomer, MutableNodeMTG("<", "Phytomer", i, 3))
            unique_mtg_id[] += 1
        end
        internode = Node(unique_mtg_id[], phytomer, MutableNodeMTG("/", "Internode", i, 4))
        unique_mtg_id[] += 1

        rank = compute_leaf_rank(nb_internodes, i, parameters["nb_leaves_in_sheath"])

        compute_properties_internode!(internode, i, nb_internodes, rank, stem_height, stem_diameter, parameters, rng)
        leaf = Node(unique_mtg_id[], internode, MutableNodeMTG("+", "Leaf", i, 4))
        unique_mtg_id[] += 1
        leaf.rank = rank
        leaf.is_alive = leaf.rank <= nb_leaves_alive
        final_length = if leaf.is_alive
            if leaf.rank <= 0
                # If the leaf is a spear, we estimate its future length using the length of the youngest leaf
                rank_1_leaf_length
            else
                popfirst!(final_lengths)
            end
        else
            0.0
        end

        compute_properties_leaf!(leaf, leaf.rank, leaf.is_alive, final_length, parameters, rng)

        # Loop on present leaves
        if leaf.is_alive
            # Build the petiole
            petiole_node = petiole(unique_mtg_id, i, 5, leaf.rachis_length, leaf.zenithal_insertion_angle, leaf.zenithal_cpoint_angle, parameters; rng=rng)
            addchild!(leaf, petiole_node)

            # Build the rachis
            rachis_fresh_biomass = leaf.rank <= 0 ? rank_1_leaf_biomass : pop!(rachis_fresh_biomasses)

            rachis_node = rachis(unique_mtg_id, i, 5, leaf.rank, leaf.rachis_length, petiole_node.height_cpoint, petiole_node.width_cpoint, leaf.zenithal_cpoint_angle, rachis_fresh_biomass, parameters; rng=rng)
            addchild!(petiole_node, rachis_node)

            # Add the leaflets to the rachis:
            leaflets!(unique_mtg_id, rachis_node, 5, leaf.rank, leaf.rachis_length, parameters; rng=rng)
        end
    end

    return plant
end
