"""
    petiole(parent_node, index, scale, rachis_length, zenithal_insertion_angle, zenithal_cpoint_angle, parameters)

Make a leaf petiole.

# Arguments 

- `unique_mtg_id`: a next free unique id for the MTG nodes
- `parent_node`: the parent node on which the petiole will be attached
- `index`: the MTG index of the petiole
- `scale`: the MTG scale of the petiole
- `rachis_length`: the rachis length, used to feed allometries to compute the petiole dimensions
- `zenithal_insertion_angle`: petiole insertion angle
- `zenithal_cpoint_angle`: angle at the C point (tip of the petiole, starting point of the rachis)
- `parameters`: a list of parameters as a `Dict{String}`:
    - "leaf_base_width": the base width of the petiole (m)
    - "leaf_base_height": the base heigth of the petiole (m)
    - "cpoint_width_intercept": petiole width at the c-point intercept for linear interpolation (m)
    - "cpoint_width_slope": petiole width at the c-point slope for linear interpolation
    - "cpoint_height_width_ratio": height to width ratio at the C point
    - "petiole_rachis_ratio_mean": the average value of the ratio between rachis length and petiole length
    - "petiole_rachis_ratio_sd": its standard deviation
    - "petiole_nb_segments": the number of segments used to discretize the petiole
"""
function petiole(unique_mtg_id, index, scale, rachis_length, zenithal_insertion_angle, zenithal_cpoint_angle, parameters; rng=Random.MersenneTwister(1))
    petiole_node = Node(unique_mtg_id[], NodeMTG(:/, :Petiole, index, scale), Dict{Symbol,Any}())
    unique_mtg_id[] += 1
    compute_properties_petiole!(
        petiole_node,
        zenithal_insertion_angle, rachis_length, zenithal_cpoint_angle,
        parameters["leaf_base_width"], parameters["leaf_base_height"], parameters["cpoint_width_intercept"],
        parameters["cpoint_width_slope"], parameters["cpoint_height_width_ratio"],
        parameters["petiole_rachis_ratio_mean"],
        parameters["petiole_rachis_ratio_sd"], parameters["petiole_nb_segments"];
        rng=rng
    )

    petiole_sections!(petiole_node, parameters["petiole_nb_segments"], unique_mtg_id)

    return petiole_node
end

"""
    petiole_sections!(petiole_node, petiole_nb_segments, unique_mtg_id)

Create the sections of a petiole.

# Arguments

- `petiole_node`: the MTG Node of the petiole
- `petiole_nb_segments`: the number of segments used to discretize the petiole
- `unique_mtg_id`: a next free unique id for the MTG nodes, given as a `Ref{Int}`

# Returns

Nothing, the petiole node is updated in-place with its sections.
"""
function petiole_sections!(petiole_node, petiole_nb_segments, unique_mtg_id)
    last_parent = petiole_node
    # segment_insertion_angle = Ref(copy(petiole_node.zenithal_insertion_angle))
    for p in 1:petiole_nb_segments
        petiole_segment_node = Node(unique_mtg_id[], last_parent, NodeMTG(p == 1 ? :/ : :<, :PetioleSegment, p, 6))
        unique_mtg_id[] += 1
        petiole_section_insertion_angle = petiole_node[:zenithal_insertion_angle] + p * petiole_node[:section_insertion_angle]
        compute_properties_petiole_section!(petiole_node, petiole_segment_node, p, petiole_nb_segments, petiole_section_insertion_angle)
        last_parent = petiole_segment_node
    end

    return nothing
end


"""
    update_petiole_angles!(petiole_node)

Update the angles of the petiole segments based on the petiole node properties.

# Arguments

- `petiole_node`: the MTG Node of the petiole

# Returns

Nothing, the petiole node is updated in-place with its segments angles.
"""
function update_petiole_angles!(petiole_node)
    segment_id = Ref(1)
    petiole_nb_segments = descendants(petiole_node, symbol=:PetioleSegment) |> length
    traverse!(petiole_node[1], symbol=:PetioleSegment) do segment
        petiole_section_insertion_angle = petiole_node[:zenithal_insertion_angle] + segment_id[] * petiole_node[:section_insertion_angle]
        segment_id[] += 1

        compute_properties_petiole_section!(petiole_node, segment, segment_id[], petiole_nb_segments, petiole_section_insertion_angle)
    end
    return nothing
end
