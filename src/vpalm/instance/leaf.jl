

function leaf(unique_mtg_id, index, rank, rachis_fresh_biomass, rachis_final_length, leaf_node=Node(NodeMTG(:+, :Leaf, index, 4)), parameters=default_parameters(); rng)
    leaf_node.rank = rank

    compute_properties_leaf!(leaf_node, leaf_node.rank, rachis_final_length, parameters, rng)

    petiole_node = petiole(unique_mtg_id, leaf_node, index, 5, leaf_node.rachis_length, leaf_node.zenithal_insertion_angle, leaf_node.zenithal_cpoint_angle, parameters; rng=rng)

    rachis_node = rachis(unique_mtg_id, petiole_node, index, 5, leaf_node.rank, leaf_node.rachis_length, petiole_node.height_cpoint, petiole_node.width_cpoint, leaf_node.zenithal_cpoint_angle, rachis_fresh_biomass, parameters; rng=rng)

    # Add the leaflets to the rachis:
    leaflets!(unique_mtg_id, rachis_node, 5, leaf_node.rank, leaf_node.rachis_length, parameters; rng=rng)
end