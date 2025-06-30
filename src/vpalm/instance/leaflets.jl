"""
    create_leaflets_for_side!(
        unique_mtg_id,
        rachis_node,
        scale,
        leaf_rank,
        rachis_length,
        nb_rachis_sections,
        leaflets_position,
        leaflets,
        leaflet_max_length,
        leaflet_max_width,
        side,
        parameters;
        last_rank_unfolding=2,
        rng=Random.MersenneTwister(1234)
    )

Create leaflets for one side of the palm frond rachis.

# Arguments

- `unique_mtg_id`: Reference to the unique ID counter for MTG nodes
- `rachis_node`: Root node of the rachis
- `scale`: MTG scale for leaflets
- `leaf_rank`: Rank of the leaf (affects unfolding for young fronds)
- `rachis_length`: Total length of the rachis in meters
- `nb_rachis_sections`: Number of segments dividing the rachis
- `leaflets_position`: Array of positions along the rachis for each leaflet
- `leaflets`: NamedTuple with leaflet grouping information (group, group_size, plane)
- `leaflet_max_length`: Maximum length of leaflets (length of the longest leaflet)
- `leaflet_max_width`: Maximum width of leaflets (width of the widest leaflet)
- `side`: Side of rachis (1=right, -1=left)
- `parameters`: Model parameters
- `last_rank_unfolding=2`: Rank at which leaflets are fully unfolded (default is 2)
- `rng=Random.MersenneTwister(1234)`: Random number generator

# Returns

Nothing (leaflets are attached directly to the rachis node in the MTG structure)
"""
function create_leaflets_for_side!(
    unique_mtg_id,
    rachis_node,
    scale,
    leaf_rank,
    rachis_length,
    nb_rachis_sections,
    leaflets_position,
    leaflets,
    leaflet_max_length,
    leaflet_max_width,
    side,
    parameters;
    last_rank_unfolding=2,
    rng=Random.MersenneTwister(1234)
)
    # Calculate the length of each rachis section
    rachis_segment_length = rachis_length / nb_rachis_sections
    nb_leaflets = length(leaflets_position)

    # Get all rachis section nodes in preorder traversal 
    # (from base to tip, including all hierarchical levels)
    rachis_children = descendants(rachis_node, symbol="RachisSegment") # Starting at 1 because we don't want the rachis node

    for i in 1:nb_leaflets
        # Determine which rachis segment this leaflet should be attached to
        # based on its position along the rachis
        rachis_segment = floor(Int, leaflets_position[i] / rachis_segment_length)
        rachis_segment = min(rachis_segment, nb_rachis_sections - 1)

        # Calculate offset from the start of the rachis segment
        offset = leaflets_position[i] - (rachis_segment_length * rachis_segment)

        # Find the corresponding rachis section node where this leaflet will attach
        rachis_section_node = rachis_children[rachis_segment+1]

        # Calculate normalized leaflet rank (0-1) and relative position along rachis (0-1)
        norm_leaflet_rank = (i - 1) / nb_leaflets
        leaflet_relative_pos = leaflets_position[i] / rachis_length

        # Create a single leaflet and add it as a child to the rachis section
        leaflet_node = create_single_leaflet(
            unique_mtg_id,
            i,                     # Index for node identification
            scale,                 # Scale for the leaflet
            leaf_rank,
            leaflet_relative_pos,
            norm_leaflet_rank,
            leaflets.plane[i],     # Determines vertical orientation (high, medium, low)
            side,                  # Right or left side
            leaflet_max_length,
            leaflet_max_width,
            parameters,
            offset=offset,         # Offset from start of rachis segment
            last_rank_unfolding=last_rank_unfolding, # Rank at which leaflets are fully unfolded
            rng=rng
        )

        addchild!(rachis_section_node, leaflet_node)
    end
end

"""
    create_single_leaflet(
        unique_mtg_id,
        index,
        scale,
        leaf_rank,
        leaflet_relative_pos,
        norm_leaflet_rank,
        plane,
        side,
        leaflet_max_length,
        leaflet_max_width,
        parameters;
        offset=0.0,
        last_rank_unfolding=2,
        rng=Random.MersenneTwister(1234)
    )

Create a single leaflet with properly computed angles, dimensions and segments.

# Arguments

- `unique_mtg_id`: Reference to the unique ID counter
- `index`: Index for the leaflet node (for identification in MTG)
- `scale`: MTG scale level for the leaflet
- `leaf_rank`: Rank of the leaf (affects unfolding for young leaves)
- `leaflet_relative_pos`: Relative position of leaflet on rachis (0 to 1)
- `norm_leaflet_rank`: Normalized rank of the leaflet (0 to 1)
- `plane`: Plane type of leaflet (1=high/upward, 0=medium/horizontal, -1=low/downward)
- `side`: Side of the leaf (1=right, -1=left)
- `leaflet_max_length`: Maximum leaflet length in meters (length of the longest leaflet)
- `leaflet_max_width`: Maximum leaflet width in meters (width of the widest leaflet)
- `parameters`: Model parameters dictionary
- `offset`: Offset from the start of parent node (when applicable)
- `last_rank_unfolding`: Rank at which leaflets are fully unfolded (default is 2)
- `rng`: Random number generator

# Returns

The created leaflet node with all its segment children
"""
function create_single_leaflet(
    unique_mtg_id,
    index,
    scale,
    leaf_rank,
    leaflet_relative_pos,
    norm_leaflet_rank,
    plane,
    side,
    leaflet_max_length,
    leaflet_max_width,
    parameters;
    offset=0.0,
    last_rank_unfolding=2,
    rng=Random.MersenneTwister(1234)
)
    # Create a new leaflet node with unique ID
    leaflet_node = Node(
        unique_mtg_id[],
        NodeMTG("+", "Leaflet", index, scale),
        Dict{Symbol,Any}()
    )
    unique_mtg_id[] += 1

    # Set basic leaflet attributes
    leaflet_node.offset = offset
    leaflet_node.plane = plane  # Controls vertical orientation type
    leaflet_node.side = side    # Controls which side of rachis

    # Cache some attributes in case we need to update the angles later
    leaflet_node.leaflet_relative_pos = leaflet_relative_pos

    # Calculate azimuthal angle of the leaflet insertion based on position and side of the leaflet
    # It is mainly determined by position along rachis. The angle is relative to the rachis direction,
    # i.e. 0.0 puts a leaflet parallel to the rachis, 90.0 makes it perpendicular.
    leaflet_node.h_angle = leaflet_azimuthal_angle(
        leaflet_relative_pos,
        side,
        parameters["leaflet_axial_angle_c"],
        parameters["leaflet_axial_angle_slope"],
        parameters["leaflet_axial_angle_a"],
        parameters["leaflet_axial_angle_sdp"],
        rng
    ) * u"°"

    # Vertical angle (radial/X) is determined by position and plane type
    leaflet_node.v_angle = leaflet_zenithal_angle(
        leaflet_relative_pos,
        plane,
        side,
        parameters["leaflet_radial_high_a0_sup"],
        parameters["leaflet_radial_high_amax_sup"],
        parameters["leaflet_radial_high_a0_inf"],
        parameters["leaflet_radial_high_amax_inf"],
        parameters["leaflet_radial_low_a0_sup"],
        parameters["leaflet_radial_low_amax_sup"],
        parameters["leaflet_radial_low_a0_inf"],
        parameters["leaflet_radial_low_amax_inf"],
        rng
    ) * u"°"

    # We use intermediate variables for angles for further computations, but 
    # we keep the original angles in the node for later updates on the leaf
    h_angle = leaflet_node.h_angle
    v_angle = leaflet_node.v_angle

    # Add stiffness with random variation to simulate natural variability
    leaflet_node.stiffness_0 = parameters["leaflet_stiffness"] + rand(rng) * parameters["leaflet_stiffness_sd"]
    stiffness = leaflet_node.stiffness_0
    # Set leaflet attribute data
    leaflet_node["relative_position"] = leaflet_relative_pos
    leaflet_node["leaflet_rank"] = norm_leaflet_rank

    # Handle leaflet unfolding for young fronds (special case for fronds that are still developing)
    if leaf_rank < last_rank_unfolding
        if leaf_rank < 1
            v_angle = 0.0u"°"  # Very young fronds have vertical leaflets
        else
            v_angle *= leaf_rank * 0.2  # Very young fronds have vertical leaflets
        end
        h_angle *= leaf_rank * 0.2  # Reduce horizontal angle for young fronds
        if leaf_rank < 1
            h_angle = 0.0u"°"  # No horizontal angle for very young fronds
        end
        stiffness = 10000 + (2.0 - leaf_rank) * 20000  # Young fronds have higher stiffness
    end

    # Set the angles and other mechanical attributes
    leaflet_node["zenithal_angle"] = v_angle # defaultRotBearerXAttribute
    leaflet_node["azimuthal_angle"] = h_angle # defaultRotBearerZAttribute
    leaflet_node["stiffness"] = stiffness
    leaflet_node["tapering"] = 0.5  # Default tapering factor
    # V-shape of the leaflet:
    leaflet_node["lamina_angle"] = parameters["leaflet_lamina_angle"]

    # Set leaflet twist (rotation around its own axis)
    leaflet_twist = 10.0 * side
    leaflet_node["torsion_angle"] = leaflet_twist * u"°"# defaultRotLocalXAttribute

    # Calculate actual leaflet length and width based on relative position along rachis and length of the longest leaflet
    leaflet_length = leaflet_max_length * relative_leaflet_length(
        leaflet_relative_pos,
        parameters["relative_length_first_leaflet"],
        parameters["relative_length_last_leaflet"],
        parameters["relative_position_leaflet_max_length"]
    )
    # Same for width
    width_max = leaflet_max_width * relative_leaflet_width(
        leaflet_relative_pos,
        parameters["relative_width_first_leaflet"],
        parameters["relative_width_last_leaflet"],
        parameters["relative_position_leaflet_max_width"]
    )
    leaflet_node["length"] = leaflet_length
    leaflet_node["width"] = width_max

    # Create the detailed leaflet segments with proper bending
    create_leaflet_segments!(
        unique_mtg_id,
        leaflet_node,
        scale + 1,  # Segments are at one scale level higher than leaflet
        leaflet_length,
        width_max,
        stiffness,
        0.5,  # tapering factor
        leaflet_relative_pos,
        xm_intercept=parameters["leaflet_xm_intercept"], xm_slope=parameters["leaflet_xm_slope"],
        ym_intercept=parameters["leaflet_ym_intercept"], ym_slope=parameters["leaflet_ym_slope"]
    )

    return leaflet_node
end

"""
    create_leaflet_segments!(
        unique_mtg_id,
        leaflet_node,
        scale,
        leaflet_length,
        width_max,
        stiffness,
        tapering,
        leaflet_relative_pos;
        xm_intercept, xm_slope,
        ym_intercept, ym_slope  
    )

Create the segments that make up a leaflet with proper shape and bending properties.

# Arguments

- `unique_mtg_id`: Reference to the unique ID counter
- `leaflet_node`: Parent leaflet node
- `scale`: MTG scale for the segments
- `leaflet_length`: Total length of the leaflet in meters
- `width_max`: Maximum width of the leaflet in meters
- `stiffness`: Stiffness value (Young's modulus) for biomechanical bending
- `tapering`: Tapering factor (how width decreases along length)
- `leaflet_relative_pos`: Relative position of the leaflet on the rachis (0-1)
- `xm_intercept`, `xm_slope`: Parameters for defining maximum leaflet width **position**
- `ym_intercept`, `ym_slope`: Parameters for defining maximum leaflet width **value**

# Returns

Nothing (segments are added directly to the leaflet node as children)
"""
function create_leaflet_segments!(
    unique_mtg_id,
    leaflet_node,
    scale,
    leaflet_length,
    width_max,
    stiffness,
    tapering,
    leaflet_relative_pos;
    xm_intercept, xm_slope,
    ym_intercept, ym_slope,
)
    # Calculate beta distribution parameters for leaflet shape
    # xm = position of maximum width along the leaflet's length (0-1)
    # ym = value of the distribution at this maximum point
    position_max_width = linear(leaflet_relative_pos, xm_intercept, xm_slope)
    width_at_max = linear(leaflet_relative_pos, ym_intercept, ym_slope)

    # Define leaflet segment boundaries along length (5 segments as in Java)
    # These carefully positioned segments create a more realistic leaflet shape
    segment_boundaries = [
        0.01,                                                  # Start, slightly offset from base to get non-zero width and angles
        position_max_width * 9 / 20,                           # First segment boundary (before max width)
        position_max_width * 7 / 4,                            # Second boundary (after max width)
        position_max_width + (1 - position_max_width) * 7 / 10, # Third boundary
        position_max_width + (1 - position_max_width) * 11 / 12, # Fourth boundary (near tip)
        1.0                                                     # Tip of leaflet
    ]
    segment_widths = zeros(length(segment_boundaries) - 1)

    # Create a piecewise linear approximation of the beta distribution curve
    # This defines the width profile along the leaflet's length
    control_points_x = ones(length(segment_boundaries)) # Using ones as placeholders because the last value will remain at 1.0
    control_points_y = zeros(length(segment_boundaries)) # Using zeros as placeholders because the last value will remain at 0.0

    for j in eachindex(segment_boundaries[1:end-1])
        # Calculate width at each boundary point using beta distribution
        segment_widths[j] = beta_distribution_norm(segment_boundaries[j], position_max_width, width_at_max)
        control_points_x[j] = segment_boundaries[j]
        control_points_y[j] = segment_widths[j]
    end

    # Calculate scaling factor to ensure correct area proportion
    # This makes the piecewise linear approximation match the theoretical beta distribution area
    beta_distribution_area = beta_distribution_norm_integral(position_max_width, width_at_max)
    piecewise_function_area = piecewise_linear_area(control_points_x, control_points_y)
    scaling_factor = beta_distribution_area / piecewise_function_area

    # Convert vertical insertion angle to radians for bending calculations
    initial_angle_rad = deg2rad(leaflet_node["zenithal_angle"])

    # Calculate bending angles for each segment using Young's modulus model
    # This simulates how the leaflet bends under its own weight based on stiffness
    segment_angles = calculate_segment_angles(
        ustrip(stiffness),  # Strip units for calculation
        initial_angle_rad,
        ustrip(leaflet_length),
        tapering,
        segment_boundaries
    )

    # Start with leaflet node as the parent of first segment
    last_parent = leaflet_node

    # Force the first segment to be at the base of the leaflet (relative value)
    segment_boundaries[1] = 0.0

    # Create each leaflet segment with appropriate dimensions and bending
    for j in 1:length(segment_boundaries)-1
        # Create a leaflet segment node connected to previous segment
        segment_node = Node(
            unique_mtg_id[],
            last_parent,
            NodeMTG(
                j == 1 ? "/" : "<",  # First segment uses "/" edge type, others use "<" (successor)
                "LeafletSegment",
                j,
                scale
            )
        )
        unique_mtg_id[] += 1

        # Apply scaling factor to width for proper area proportion
        segment_widths[j] *= scaling_factor

        # Set segment width and length
        segment_node["width"] = segment_widths[j] * width_max
        segment_node["width"] < 0u"m" && error("Negative width: $segment_node")
        segment_node["length"] = (segment_boundaries[j+1] - segment_boundaries[j]) * leaflet_length
        segment_node["segment_boundaries"] = segment_boundaries[j]

        # Apply the bending angle based on biomechanical model
        # Direction depends on which side of the rachis the leaflet is on
        segment_node["zenithal_angle"] = rad2deg(segment_angles[j]) # Stiffness angle
        # Next segment will be attached to this one
        last_parent = segment_node
    end
end

"""
    update_leaflet_angles!(
        leaflet, leaf_rank; 
        last_rank_unfolding=2, unique_mtg_id=max_id(leaflet), 
        xm_intercept=0.176, xm_slope=0.08, 
        ym_intercept=0.51, ym_slope=-0.025
    )


Update the angles and stiffness of a leaflet based on its position, side, and leaf rank.

# Arguments

- `leaflet`: The leaflet node to update
- `leaf_rank`: The rank of the leaf (affects unfolding for young leaves)
- `last_rank_unfolding`: Rank at which leaflets are fully unfolded (default is 2)
- `unique_mtg_id`: Reference to the unique ID counter for MTG nodes (default is the maximum ID in the MTG)
- `xm_intercept`, `xm_slope`: Parameters for defining maximum leaflet width **position**
- `ym_intercept`, `ym_slope`: Parameters for defining maximum leaflet width **value**
"""
function update_leaflet_angles!(
    leaflet, leaf_rank;
    last_rank_unfolding=2,
    unique_mtg_id=Ref(max_id(leaflet) + 1),
    xm_intercept=0.176, xm_slope=0.08,
    ym_intercept=0.51, ym_slope=-0.025
)
    # Using the original sampled vangle, and adjusting it if necessary:
    v_angle = leaflet.v_angle
    h_angle = leaflet.h_angle
    stiffness = leaflet.stiffness_0
    # Handle leaflet unfolding for young fronds (special case for fronds that are still developing)
    if leaf_rank < last_rank_unfolding
        if leaf_rank < 1
            v_angle = 0.0u"°"  # Very young fronds have vertical leaflets
        else
            v_angle *= leaf_rank * 0.2  # Very young fronds have vertical leaflets
        end
        h_angle *= leaf_rank * 0.2  # Reduce horizontal angle for young fronds
        if leaf_rank < 1
            h_angle = 0.0u"°"  # No horizontal angle for very young fronds
        end
        stiffness = 10000 + (2.0 - leaf_rank) * 20000  # Young fronds have higher stiffness
    end

    leaflet.stiffness = stiffness
    # We update the leaflet insertion angles:
    leaflet.zenithal_angle = v_angle
    leaflet.azimuthal_angle = h_angle
    # Note: the torsion is not supposed to change over time

    children_leaflet = children(leaflet)
    if length(children_leaflet) > 0 && symbol(children_leaflet[1]) == "LeafletSegment"
        # If we have leaflet segments, we need can simply update their angles:
        update_segment_angles!(leaflet, ustrip(leaflet.stiffness), deg2rad(leaflet.zenithal_angle), ustrip(leaflet.length), leaflet.tapering)
    else
        # If we have no segments (they were merged at leaflet scale), we need to re-create them:
        scale_leaflet_segments = scale(leaflet) + 1
        create_leaflet_segments!(
            unique_mtg_id,
            leaflet,
            scale_leaflet_segments,
            leaflet.length,
            leaflet.width,
            leaflet.stiffness,
            0.5,  # tapering factor
            leaflet.relative_position,
            xm_intercept=xm_intercept, xm_slope=xm_slope,
            ym_intercept=ym_intercept, ym_slope=ym_slope
        )
    end
end


"""
    leaflets!(unique_mtg_id, rachis_node, scale, leaf_rank, rachis_length, parameters; rng=Random.MersenneTwister())

Create leaflets for a given rachis node, computing their positions, types, and dimensions.

# Arguments

- `unique_mtg_id`: Reference to a unique identifier for the MTG nodes.
- `rachis_node`: The parent node of the rachis where leaflets will be attached.
- `scale`: The scale of the leaflets in the MTG.
- `leaf_rank`: The rank of the leaf associated with the rachis.
- `rachis_length`: The total length of the rachis in meters.
- `height_cpoint`: The height of the central point of the rachis in meters.
- `width_cpoint`: The width of the central point of the rachis in meters.
- `zenithal_cpoint_angle`: The zenithal angle of the central point of the rachis in degrees.
- `parameters`: A dictionary containing biomechanical parameters for the leaflets.
- `rng`: A random number generator for stochastic processes (default is a new MersenneTwister).

# Note

The `parameters` is a `Dict{String}` containing the following keys:

- `"leaflets_nb_max"`: Maximum number of leaflets per rachis.
- `"leaflets_nb_min"`: Minimum number of leaflets per rachis.
- `"leaflets_nb_slope"`: Slope for the number of leaflets distribution.
- `"leaflets_nb_inflexion"`: Inflexion point for the number of leaflets distribution.
- `"nbLeaflets_SDP"`: Standard deviation for the number of leaflets.
- `"leaflet_position_shape_coefficient"`: Shape coefficient for the relative positions of leaflets.
- `"leaflet_frequency_high"`: Frequency of high-position leaflets.
- `"leaflet_frequency_low"`: Frequency of low-position leaflets.
- `"leaflet_frequency_shape_coefficient"`: Shape coefficient for the frequency distribution of leaflets.
- `"leaflet_between_to_within_group_ratio"`: Ratio of spacing between groups to within groups.
- `"leaflet_length_at_b_intercept"`: Intercept for the length of leaflets at point B.
- `"leaflet_length_at_b_slope"`: Slope for the length of leaflets at point B.
- `"relative_position_bpoint"`: Relative position of point B along the rachis.
- `"relative_position_bpoint_sd"`: Standard deviation of the relative position of point B.
- `"relative_length_first_leaflet"`: Relative length of the first leaflet.
- `"relative_length_last_leaflet"`: Relative length of the last leaflet.
- `"relative_position_leaflet_max_length"`: Relative position of the leaflet with maximum length.
- `"leaflet_width_at_b_intercept"`: Intercept for the width of leaflets at point B.
- `"leaflet_width_at_b_slope"`: Slope for the width of leaflets at point B.
- `"relative_width_first_leaflet"`: Relative width of the first leaflet.
- `"relative_width_last_leaflet"`: Relative width of the last leaflet.
- `"relative_position_leaflet_max_width"`: Relative position of the leaflet with maximum width.
- `"rachis_nb_segments"`: Number of segments in the rachis.
"""
function leaflets!(unique_mtg_id, rachis_node, scale, leaf_rank, rachis_length, parameters; rng=Random.MersenneTwister())
    nb_leaflets = compute_number_of_leaflets(rachis_length, parameters["leaflets_nb_max"], parameters["leaflets_nb_min"], parameters["leaflets_nb_slope"], parameters["leaflets_nb_inflexion"], parameters["nbLeaflets_SDP"]; rng=rng)

    leaflets_relative_positions = relative_leaflet_position.(collect(1:nb_leaflets) ./ nb_leaflets, parameters["leaflet_position_shape_coefficient"])
    leaflets_position = leaflets_relative_positions .* rachis_length

    leaflets_type_frequency = compute_leaflet_type_frequencies(parameters["leaflet_frequency_high"], parameters["leaflet_frequency_low"])

    leaflets = group_leaflets(leaflets_relative_positions, leaflets_type_frequency, rng)

    # Re-compute the leaflets positions taking grouping into account (leaflets are closer to each other within a group)
    shrink_leaflets_in_groups!(leaflets_position, leaflets, parameters["leaflets_between_to_within_group_ratio"])

    # Second pass: Normalize to ensure spreading along the full rachis length (from base to tip):
    normalize_positions!(leaflets_position, rachis_length)

    leaflet_length_at_b = leaflet_length_at_bpoint(rachis_length, parameters["leaflet_length_at_b_intercept"], parameters["leaflet_length_at_b_slope"])
    leaflet_max_length = leaflet_length_max(leaflet_length_at_b, parameters["relative_position_bpoint"], parameters["relative_length_first_leaflet"], parameters["relative_length_last_leaflet"], parameters["relative_position_leaflet_max_length"], parameters["relative_position_bpoint_sd"], rng)
    leaflet_width_at_b = leaflet_width_at_bpoint(rachis_length, parameters["leaflet_width_at_b_intercept"], parameters["leaflet_width_at_b_slope"])
    leaflet_max_width = leaflet_width_max(leaflet_width_at_b, parameters["relative_position_bpoint"], parameters["relative_width_first_leaflet"], parameters["relative_width_last_leaflet"], parameters["relative_position_leaflet_max_width"], parameters["relative_position_bpoint_sd"], rng)

    # Create leaflets for right side (side = 1)
    create_leaflets_for_side!(
        unique_mtg_id, rachis_node, scale, leaf_rank, rachis_length, parameters["rachis_nb_segments"],
        leaflets_position, leaflets, leaflet_max_length, leaflet_max_width, 1, parameters, rng=rng
    )

    # Create leaflets for left side (side = -1)
    create_leaflets_for_side!(
        unique_mtg_id, rachis_node, scale, leaf_rank, rachis_length, parameters["rachis_nb_segments"],
        leaflets_position, leaflets, leaflet_max_length, leaflet_max_width, -1, parameters, rng=rng
    )

    # Return complete leaflet data including positions
    return (
        group=leaflets.group,
        group_size=leaflets.group_size,
        plane=leaflets.plane,
        position=leaflets_position,
    )
end

"""
    group_leaflets(leaflets_relative_position, leaflets_type_frequency, rng)

Compute the group, group size and plane positions of each leaflet along the rachis.

# Arguments

- `leaflets_relative_position`: Array of relative positions for the leaflets along the rachis (see `relative_leaflet_position()`).
- `leaflets_type_frequency`: Vector of NamedTuples representing frequency distributions along the rachis (if *e.g.* 10 values are provided, it means the rachis is divided into 10 sub-sections), with fields:
  - `high`: Frequency of plane=+1 leaflets (first leaflet in each group), *i.e.* leaflets on "high" position
  - `medium`: Frequency of plane=0 leaflets (intermediate leaflets in groups), *i.e.* leaflets on "medium" position, horizontally inserted on the rachis
  - `low`: Frequency of plane=-1 leaflets (terminal leaflets in groups), *i.e.* leaflets on "low" position
- `rng`: Random number generator.

# Details

This function:

    1. Organizes leaflets into groups based on position-dependent size distributions
    2. Assigns a spatial plane to each leaflet within a group:
        - The first leaflet in each group is always placed on the high position (plane=1)
        - Subsequent leaflets are positioned on medium (plane=0) or low (plane=-1) positions based on their frequency distribution at that rachis segment

## Biological Context

Grouping of leaflets is a key morphological feature in palm species, particularly in oil palm (Elaeis guineensis).
Unlike some palms with regularly spaced leaflets, oil palms exhibit distinctive clustering patterns where:

1. Leaflets occur in groups of variable sizes, but typically around 3 leaflets per group
2. Within each group, leaflets emerge at different angles:
   - The first leaflet points upward (high position)
   - Others point horizontally or downward (medium and low positions)
3. The pattern of grouping changes along the rachis:
   - Closer to the base: typically larger groups with more leaflets
   - Toward the tip: smaller groups or single leaflets

The model uses an inverse relationship between high-position leaflet frequency and group size to
recreate the natural variation in leaflet insertion angle - sections with many high-position leaflets have smaller groups (but more of them),
while sections with few high-position leaflets form larger groups.

The grouping pattern changes along the rachis, creating the characteristic appearance of palm fronds with varying leaflet arrangement 
patterns from base to tip.

# Returns

A NamedTuple containing arrays for:
- `group`: Group identifier for each leaflet
- `group_size`: Size of the group that each leaflet belongs to
- `plane`: Spatial position/orientation of each leaflet (1=high, 0=medium, -1=low)
"""
function group_leaflets(leaflets_relative_position, leaflets_type_frequency, rng)

    @assert length(leaflets_type_frequency) > 0 "Frequency distribution must have at least one segment"

    nb_leaflets = length(leaflets_relative_position)

    # Structure of Arrays approach
    leaflets = (
        group=zeros(Int, nb_leaflets),
        group_size=zeros(Int, nb_leaflets),
        plane=zeros(Int, nb_leaflets),
    )

    current_group = 1
    current_group_size = 0
    leaflets_in_current_group = 0

    for (leaflet_index, relative_position) in enumerate(leaflets_relative_position)
        segment = calculate_segment(relative_position, length(leaflets_type_frequency))
        frequencies = leaflets_type_frequency[segment]

        # Determine if this leaflet starts a new group or belongs to current group
        if leaflets_in_current_group == 0 || leaflets_in_current_group >= current_group_size
            # Start a new group
            current_group_size = draw_group_size(segment, leaflets_type_frequency, rng)
            # Ensure we don't exceed the number of remaining leaflets
            current_group_size = min(current_group_size, nb_leaflets - leaflet_index + 1)
            leaflets_in_current_group = 0

            # Only increment group number if this isn't the first leaflet
            if leaflet_index > 1
                current_group += 1
            end
        end

        # Set group information for this leaflet
        leaflets.group[leaflet_index] = current_group
        leaflets.group_size[leaflet_index] = current_group_size

        # Determine plane position based on position within group
        if leaflets_in_current_group == 0
            # First leaflet in group is always high position (plane=1)
            leaflets.plane[leaflet_index] = 1
        else
            # Subsequent leaflets are medium or low based on frequencies
            if rand(rng) > (frequencies.medium / (frequencies.medium + frequencies.low))
                leaflets.plane[leaflet_index] = -1  # Low position
            else
                leaflets.plane[leaflet_index] = 0   # Medium position
            end
        end

        # Increment counter for leaflets in this group
        leaflets_in_current_group += 1
    end

    return leaflets
end


"""
    calculate_segment(relative_position, num_segments=10)

Calculate the segment index for a given relative position along the rachis.

# Arguments

- `relative_position`: Relative position along the rachis [0 to 1), where 0 is the base and 1 is the tip.
- `num_segments`: Number of segments the rachis is divided into (default: 10).

# Details

We divide the rachis into segments to capture variations in properties along its length. This function:

1. Converts a continuous relative position (0-1) into a discrete segment index
2. Ensures the segment index is within valid bounds (1 to num_segments)

# Biological Context

The palm rachis exhibits changing properties along its length, including:

- Leaflet grouping patterns
- Leaflet sizes and angles

Dividing the rachis into discrete segments allows the model to represent these
gradual changes in a computationally efficient manner. Each segment can have different
parameter values that together create the characteristic patterns seen in real palms.

# Returns

The segment index (starts at 1 in Julia).
"""
function calculate_segment(relative_position, num_segments=10)
    # Calculate segment index (convert to 1-based indexing for Julia)
    segment = floor(Int, relative_position * num_segments) + 1

    # Ensure segment is within valid range
    segment = clamp(segment, 1, num_segments)

    return segment
end


"""
    compute_number_of_leaflets(rachis_final_length, nb_max, nb_slope, nb_infl, nbLeaflets_SDP; rng)

Compute the number of leaflets based on the logistic function, a standard deviation and a minimum value allowed.

# Arguments

- `rachis_final_length`: Final length of the rachis (m).
- `nb_max`: Maximum number of leaflets.
- `nb_min`: Minimum number of leaflets.
- `nb_slope`: Slope parameter for the logistic function (leaflet m⁻¹).
- `nb_infl`: Inflection point parameter for the logistic function (m).
- `nbLeaflets_SDP`: Standard deviation of the normal distribution for the number of leaflets.
- `rng`: Random number generator.

# Returns

The computed number of leaflets (integer).
"""
function compute_number_of_leaflets(rachis_final_length, nb_max, nb_min, nb_slope, nb_infl, nbLeaflets_SDP; rng)

    @assert rachis_final_length >= 0u"m" "Rachis length must be non-negative"
    @assert nb_max > 0 "Maximum number of leaflets must be positive"
    @assert nb_min >= 0 "Minimum number of leaflets must be non-negative"
    @assert nb_slope > 0 "Slope parameter must be positive"
    @assert nb_infl > 0u"m" "Inflection point must be positive"

    nb_leaflets = logistic(rachis_final_length, nb_max, nb_slope, nb_infl)

    deviation_factor = rachis_final_length < 1.0u"m" ? 0.3 : 1.0
    nb_leaflets += deviation_factor * normal_deviation_draw(nbLeaflets_SDP, rng)

    nb_leaflets = round(Int, max(nb_min, nb_leaflets))

    return nb_leaflets
end

"""
    relative_leaflet_position(relative_rank, shape_coefficient)

Compute the relative leaflet position on the rachis.

# Arguments

- `relative_rank`: Relative leaflet rank, usually in the form of (0 to 1].
- `shape_coefficient`: Shape coefficient (around 0).

# Returns

The relative leaflet position, in the same form as `relative_rank`, usually (0 to 1].
"""
function relative_leaflet_position(relative_rank, shape_coefficient)
    return ((1.0 + shape_coefficient) * (relative_rank^2)) / (1.0 + shape_coefficient * (relative_rank^2))
end

"""
    compute_leaflet_type_frequencies(leaflet_frequency_high, leaflet_frequency_low)

Compute the frequency of leaflet type within the sub-sections of a rachis.

# Arguments

- `leaflet_frequency_high`: Vector of frequency values for the +1 leaflet types (high) along the rachis sub-sections.
- `leaflet_frequency_low`: Vector of frequency values for the -1 leaflet types (low) along the rachis sub-sections..

Note that the length of the two vectors must be the same. It will define how many sub-sections the rachis is divided into
for this computation.

# Returns

A vector of NamedTuples representing the `(;high, medium, low)` frequencies for each sub-section.
"""
function compute_leaflet_type_frequencies(leaflet_frequency_high, leaflet_frequency_low)
    @assert length(leaflet_frequency_high) == length(leaflet_frequency_low) "Vectors must be of the same length"

    n = length(leaflet_frequency_high)
    leaflet_type_frequencies = Vector{NamedTuple{(:high, :medium, :low),Tuple{Float64,Float64,Float64}}}(undef, n)

    for i in 1:n
        medium_frequency = 1.0 - leaflet_frequency_high[i] - leaflet_frequency_low[i]
        @assert medium_frequency >= 0 "The sum of frequencies for high (+1) and low (-1) leaflets must be less than or equal to 1 for each section: section $i has a sum of $(leaflet_frequency_high[i] + leaflet_frequency_low[i])"
        leaflet_type_frequencies[i] = (high=leaflet_frequency_high[i], medium=medium_frequency, low=leaflet_frequency_low[i])
    end

    return leaflet_type_frequencies
end

"""
    draw_group_size(group, leaflet_type_frequencies, rng)

Determine the size of a leaflet group based on the relative position along the rachis and frequency patterns.

# Arguments

- `group`: Index of the leaflet group based on its relative position on the rachis (1 to `length(leaflet_type_frequencies)`).
- `leaflet_type_frequencies`: Vector of NamedTuples representing frequency distributions for each rachis segment, with fields:
  - `high`: Frequency of plane=+1 leaflets (first leaflet in each group), *i.e.* leaflets on "high" position
  - `medium`: Frequency of plane=0 leaflets (intermediate leaflets in groups), *i.e.* leaflets on "medium" position, horizontally inserted on the rachis
  - `low`: Frequency of plane=-1 leaflets (terminal leaflets in groups), *i.e.* leaflets on "low" position
- `rng`: Random number generator for stochastic determination.

# Details

This function implements an inverse relationship between the frequency of high (plane=1) leaflets
and group size, modeling a fundamental biological pattern in palm frond architecture:

- Segments with high frequency of high leaflets produce many small groups of leaflets
- Segments with low frequency of high leaflets produce fewer, larger groups of leaflets

The calculation uses a probabilistic rounding mechanism to ensure proper statistical distribution 
of group sizes. This creates the natural variation in leaflet grouping patterns seen along real palm
fronds, where clustering patterns change systematically from base to tip.

# Returns

An integer representing the number of leaflets in the group.
"""
function draw_group_size(group, leaflet_type_frequencies, rng)
    size_d = 1.0 / leaflet_type_frequencies[group].high
    size_i = max(1, floor(Int, size_d))
    delta = size_d - size_i

    if rand(rng) < delta
        size_i += 1
    end

    return size_i
end

"""
    shrink_leaflets_in_groups!(positions, leaflets, ratio=2.0)

Adjust the spacing between leaflets to create appropriate within-group and between-group distances.

# Arguments

- `positions`: Vector of current leaflet positions along the rachis.
- `leaflets`: A NamedTuple containing arrays for leaflet properties (group, group_size, plane).
- `ratio=2.0`: Ratio of inter-group to intra-group spacing.

# Details

This function implements a biological principle where leaflets within the same group
are positioned closer together than leaflets in different groups. It:

1. Uses a fixed ratio (2:1) between inter-group and intra-group spacing
2. Preserves the overall distribution pattern while creating distinct groups
3. Processes each group sequentially, adjusting positions based on group size

# Biological Context

In many palm species, particularly oil palm, leaflets appear in distinct groups along the rachis.
This grouping pattern is characterized by:

1. Consistent, smaller spacing between leaflets within the same group
2. Larger spacing between adjacent groups
3. The ratio between these spacings is typically species-specific

This spacing pattern is essential for the palm's characteristic appearance and 
affects light interception patterns along the frond.
"""
function shrink_leaflets_in_groups!(positions, leaflets, ratio=2.0)
    current_group = -1
    last_leaflet_pos = 0.0u"m"
    l = 1

    while l <= length(positions)
        # Check if this is the first leaflet in a new group
        group = leaflets.group[l]
        if group != current_group
            group_size = leaflets.group_size[l]
            current_group = group

            # Find the last leaflet in this group
            last_leaflet_index = l + group_size - 1

            # Calculate spacings
            total_spacing = positions[last_leaflet_index] - last_leaflet_pos
            intra_group_spacing = total_spacing / (ratio + group_size - 1)
            inter_group_spacing = intra_group_spacing * ratio

            # Position first leaflet in group
            positions[l] = last_leaflet_pos + inter_group_spacing
            last_leaflet_pos = positions[l]

            # Position remaining leaflets in group
            for p in 1:(group_size-1)
                positions[l+p] = last_leaflet_pos + intra_group_spacing
                last_leaflet_pos = positions[l+p]
            end

            l += group_size
        else
            l += 1
        end
    end
end

"""
    normalize_positions!(positions, rachis_length)

Scale and offset positions to span the full rachis length.

# Arguments

- `positions`: Vector of positions to be modified in place.
- `rachis_length`: Total length of rachis in meters.

# Details

This function:

1. Offsets positions so the first leaflet is at position 0
2. Scales all positions to ensure the last leaflet is exactly at rachis_length
3. Maintains the relative spacing pattern established by previous processing

This ensures leaflets are properly distributed along the entire rachis while
preserving the characteristic grouping patterns.
"""
function normalize_positions!(positions, rachis_length)
    offset = positions[1]
    rescale_factor = rachis_length / (positions[end] - offset)

    for l in eachindex(positions)
        positions[l] = (positions[l] - offset) * rescale_factor
    end

    return nothing
end

"""
    leaflet_length_at_bpoint(rachis_length, intercept, slope)

Compute the length of leaflets at the B point of the rachis using a linear relationship.

# Arguments

- `rachis_length`: The total length of the rachis (m).
- `intercept`: The intercept parameter of the linear function (m).
- `slope`: The slope parameter of the linear function (dimensionless).

# Details

This function uses a linear model to determine leaflet length at the B point:
    
    leaflet_length = intercept + slope * rachis_length

The B point is a key reference point on the rachis that marks the transition from an oval to a round shape of the 
rachis. The leaflet length at this point serves as a reference for calculating the distribution of leaflet lengths 
along the entire rachis.

# Returns

The length of leaflets at the B point position (m).
"""
function leaflet_length_at_bpoint(rachis_length, intercept, slope)
    return intercept + slope * rachis_length
end

"""
    leaflet_length_max(
        leaflet_length_at_b, 
        relative_position_bpoint, 
        relative_length_first_leaflet, 
        relative_length_last_leaflet, 
        relative_position_leaflet_max_length, 
        relative_position_bpoint_sd, 
        rng
    )

Calculate the maximum leaflet length for the rachis, used to scale the relative length profile.

# Arguments

- `leaflet_length_at_b`: Length of leaflets at the B point on the rachis (m).
- `relative_position_bpoint`: Relative position of the B point along the rachis (0 to 1).
- `relative_length_first_leaflet`: Relative length of the first leaflet at rachis base [0 to 1].
- `relative_length_last_leaflet`: Relative length of the last leaflet at rachis tip [0 to 1].
- `relative_position_leaflet_max_length`: Relative position where leaflets reach maximum length [0 to 1].
- `relative_position_bpoint_sd`: Standard deviation for stochastic variation in B point position.
- `rng`: Random number generator.

# Details

This function calculates the maximum leaflet length that would result in the specified 
leaflet length at the B point, considering the shape of the length profile along the rachis.

The calculation uses the inverse of the relative length function at the B point position 
to determine what maximum value would yield the desired length at that specific position.

# Biological Context

In palm fronds, leaflet length typically follows a bell-shaped distribution along the rachis:

1. Leaflets are short at the base (petiole end)
2. They increase in length to reach a maximum somewhere close to the middle of the rachis
3. They decrease in length toward the tip

The B point is a key morphological reference point where the rachis cross-section 
transitions from oval to round. By knowing the leaflet length at this specific point,
we can calculate the maximum leaflet length for the entire frond, which serves as
a scaling factor for all other leaflets.

The stochastic variation in B point position reflects natural biological variability
between individual palms or fronds.

# Returns

The maximum leaflet length for the rachis (m).
"""
function leaflet_length_max(leaflet_length_at_b, relative_position_bpoint, relative_length_first_leaflet, relative_length_last_leaflet, relative_position_leaflet_max_length, relative_position_bpoint_sd, rng)
    relative_position_bpoint = relative_position_bpoint + normal_deviation_draw(relative_position_bpoint_sd, rng)

    return leaflet_length_max(leaflet_length_at_b, relative_position_bpoint, relative_length_first_leaflet, relative_length_last_leaflet, relative_position_leaflet_max_length)
end


function leaflet_length_max(leaflet_length_at_b, relative_position_bpoint, relative_length_first_leaflet, relative_length_last_leaflet, relative_position_leaflet_max_length)
    @assert relative_position_bpoint >= 0 && relative_position_bpoint <= 1 "Relative position bpoint must be between 0 and 1."
    @assert leaflet_length_at_b > zero(leaflet_length_at_b) "Leaflet length at b must be positive."

    return leaflet_length_at_b / relative_leaflet_length(relative_position_bpoint, relative_length_first_leaflet, relative_length_last_leaflet, relative_position_leaflet_max_length)
end

"""
    relative_leaflet_length(x, relative_length_first_leaflet, relative_length_last_leaflet, relative_position_leaflet_max_length)

Relative leaflet length given by their relative position along the rachis.

# Arguments

- `x`: relative leaflet position on the rachis (0: base to 1: tip)
- `relative_length_first_leaflet`: relative length of the first leaflet on the rachis (0 to 1)
- `relative_length_last_leaflet`: relative length of the last leaflet on the rachis  (0 to 1)
- `relative_position_leaflet_max_length`: relative position of the longest leaflet on the rachis (0.111 to 0.999)
"""
function relative_leaflet_length(x, relative_length_first_leaflet, relative_length_last_leaflet, relative_position_leaflet_max_length)
    if x < relative_position_leaflet_max_length
        return relative_length_first_leaflet + ((1 - relative_length_first_leaflet) * x * (2 * relative_position_leaflet_max_length - x)) / relative_position_leaflet_max_length^2
    else
        return 1 + (relative_length_last_leaflet - 1) * (x - relative_position_leaflet_max_length)^2 / (1 - relative_position_leaflet_max_length)^2
    end
end


"""
    leaflet_width_at_bpoint(rachis_length, intercept, slope)

Calculate leaflet width at B point (reference point).

# Arguments
- `rachis_length`: The total length of the rachis (m).
- `intercept`: The intercept parameter of the linear function (m).
- `slope`: The slope parameter of the linear function (dimensionless).

# Details
This function uses a linear model to determine leaflet width at the B point:
    
    leaflet_width = intercept + slope * rachis_length

The B point is a key reference point on the rachis that marks the transition 
between different architectural zones. The leaflet width at this point serves 
as a reference for calculating the distribution of leaflet widths along the 
entire rachis.

# Returns
- The width of leaflets at the B point position (m).
"""
function leaflet_width_at_bpoint(rachis_length, intercept, slope)
    return intercept + slope * rachis_length
end

"""
    leaflet_width_max(
        leaflet_width_at_b,
        relative_position_bpoint,
        width_first,
        width_last,
        pos_width_max,
        relative_position_bpoint_sd,
        rng
    )

    leaflet_width_max(
        leaflet_width_at_b,
        relative_position_bpoint,
        width_first,
        width_last,
        pos_width_max,
    )

Calculate the maximum leaflet width for the rachis, used to scale the width profile.

# Arguments

- `leaflet_width_at_b`: Width of leaflets at the B point on the rachis (m).
- `relative_position_bpoint`: Mean relative position of the B point along the rachis [0 to 1].
- `width_first`: Relative width of the first leaflet at rachis base [0 to 1].
- `width_last`: Relative width of the last leaflet at rachis tip [0 to 1].
- `pos_width_max`: Relative position where leaflets reach maximum width [0 to 1].
- `relative_position_bpoint_sd`: Standard deviation for stochastic variation in B point position (optional).
- `rng`: Random number generator (optional). 

# Details

This function calculates the maximum leaflet width that would result in the specified 
width at the B point, considering the shape of the width profile along the rachis.

The calculation uses the inverse of the relative width function at the B point position 
to determine what maximum value would yield the desired width at that specific position.

# Biological Context

In palm fronds, leaflet width typically varies along the rachis:
1. Narrow leaflets at the base (petiole end)
2. Wider leaflets in the middle region
3. Narrowing again toward the tip

By knowing the leaflet width at the B point, we can calculate the maximum 
leaflet width for the entire frond, which serves as a scaling factor for 
all other leaflets.

# Returns

The maximum leaflet width for the rachis (m).
"""
function leaflet_width_max(
    leaflet_width_at_b,
    relative_position_bpoint,
    width_first,
    width_last,
    pos_width_max,
    relative_position_bpoint_sd,
    rng
)
    relative_position_bpoint = relative_position_bpoint + normal_deviation_draw(relative_position_bpoint_sd, rng)
    return leaflet_width_max(leaflet_width_at_b, relative_position_bpoint, width_first, width_last, pos_width_max)
end


function leaflet_width_max(
    leaflet_width_at_b,
    relative_position_bpoint,
    width_first,
    width_last,
    pos_width_max,
)
    return leaflet_width_at_b / relative_leaflet_width(relative_position_bpoint, width_first, width_last, pos_width_max)
end

"""
    relative_leaflet_width(x, width_first, width_last, pos_width_max)

Calculate the relative leaflet width at a given position along the rachis.

# Arguments

- `x`: Relative position of the leaflet on the rachis [0 to 1].
- `width_first`: Relative width of the first leaflet (at rachis base).
- `width_last`: Relative width of the last leaflet (at rachis tip).
- `pos_width_max`: Relative position where leaflets reach maximum width [0 to 1].

# Details

This function uses a piecewise linear model to calculate relative leaflet width:

1. From base to maximum width position: Linear increase from `width_first` to 1.0
2. From maximum width position to tip: Linear decrease from 1.0 to `width_last`

# Biological Context

The width of leaflets along a palm frond typically follows a pattern where:

- Leaflets start relatively narrow at the base
- Widen to reach maximum width at some point along the rachis
- Narrow again toward the tip

# Returns

The relative width at position x [0 to 1].
"""
function relative_leaflet_width(x, width_first, width_last, pos_width_max)
    if x < pos_width_max
        return width_first + x * (1 - width_first) / pos_width_max
    else
        return x * (width_last - 1) / (1 - pos_width_max) +
               (1 - pos_width_max * width_last) / (1 - pos_width_max)
    end
end

"""
    leaflet_azimuthal_angle(relative_pos, side, angle_c, angle_slope, angle_a, angle_sdp, rng)

Calculate the leaflet insertion angle in the horizontal plane (in degrees).

# Arguments
- `relative_pos`: Relative position of the leaflet on the rachis [0 to 1].
- `side`: Side of the leaf (1 for right, -1 for left).
- `angle_c`: Constant parameter for the axial angle calculation (°).
- `angle_slope`: Slope parameter for the axial angle calculation (°).
- `angle_a`: Amplitude parameter for the axial angle calculation (°).
- `angle_sdp`: Standard deviation percentage for random variation (°).
- `rng`: Random number generator.

# Returns
- Horizontal insertion angle in degrees.
"""
function leaflet_azimuthal_angle(relative_pos, side, angle_c, angle_slope, angle_a, angle_sdp, rng)
    a = ustrip(angle_c)^2
    b = angle_slope * 2.0 * sqrt(a)
    c = ustrip(angle_a)^2 - a - b

    eq = a + b * relative_pos + c * relative_pos^3
    eq < 0.0 && (eq = 0.0)
    angle = sqrt(eq)

    # Add random variation based on standard deviation percentage
    angle += normal_deviation_percent_draw(angle, angle_sdp, rng)

    return angle * side
end

"""
    leaflet_zenithal_angle_boundaries(rel_pos, a0, a_max, xm=0.5)

Calculate the boundaries of the radial angle based on position along the rachis.

# Arguments
- `rel_pos`: Relative position on the rachis [0 to 1].
- `a0`: Radial angle around C point.
- `a_max`: Maximum value of radial angle (in degrees).
- `xm`: Relative position on rachis of the maximum radial angle (default: 0.5).

# Returns
- Radial angle in degrees.
"""
function leaflet_zenithal_angle_boundaries(rel_pos, a0, a_max, xm=0.5)
    a0 = ustrip(a0)
    a_max = ustrip(a_max)
    c1 = (a0 - a_max) / (xm * xm)
    b1 = -2 * c1 * xm

    c2 = -a_max / ((xm - 1) * (xm - 1))
    b2 = -2 * c2 * xm
    a2 = -b2 - c2

    if rel_pos < xm
        return a0 + b1 * rel_pos + c1 * rel_pos * rel_pos
    else
        return a2 + b2 * rel_pos + c2 * rel_pos * rel_pos
    end
end

"""
    leaflet_zenithal_angle(relative_pos, leaflet_type, side, high_a0_sup, high_amax_sup, high_a0_inf, high_amax_inf, 
                 low_a0_sup, low_amax_sup, low_a0_inf, low_amax_inf, rng)

Calculate the leaflet insertion angle in the vertical plane (in degrees).

# Arguments
- `relative_pos`: Relative position of the leaflet on the rachis [0 to 1].
- `leaflet_type`: Type of leaflet (-1=down, 0=medium, 1=up).
- `side`: Side of the leaf (1 for right, -1 for left).
- `high_a0_sup`: Upper bound of angle at position 0 for high position leaflets.
- `high_amax_sup`: Upper bound of maximum angle for high position leaflets.
- `high_a0_inf`: Lower bound of angle at position 0 for high position leaflets.
- `high_amax_inf`: Lower bound of maximum angle for high position leaflets.
- `low_a0_sup`: Upper bound of angle at position 0 for low position leaflets.
- `low_amax_sup`: Upper bound of maximum angle for low position leaflets.
- `low_a0_inf`: Lower bound of angle at position 0 for low position leaflets.
- `low_amax_inf`: Lower bound of maximum angle for low position leaflets.
- `rng`: Random number generator.

# Returns
- Vertical insertion angle in degrees.
"""
function leaflet_zenithal_angle(relative_pos, leaflet_type, side, high_a0_sup, high_amax_sup, high_a0_inf, high_amax_inf,
    low_a0_sup, low_amax_sup, low_a0_inf, low_amax_inf, rng)
    xm = 0.5
    if leaflet_type == 1  # High position
        a0_sup = high_a0_sup
        a_max_sup = high_amax_sup
        a0_inf = high_a0_inf
        a_max_inf = high_amax_inf
    elseif leaflet_type == -1  # Low position
        a0_sup = low_a0_sup
        a_max_sup = low_amax_sup
        a0_inf = low_a0_inf
        a_max_inf = low_amax_inf
    else  # Medium position
        a0_sup = high_a0_inf
        a_max_sup = high_amax_inf
        a0_inf = low_a0_sup
        a_max_inf = low_amax_sup
    end

    angle_max = leaflet_zenithal_angle_boundaries(relative_pos, a0_sup, a_max_sup, xm)
    angle_min = leaflet_zenithal_angle_boundaries(relative_pos, a0_inf, a_max_inf, xm)

    return (angle_min + (angle_max - angle_min) * rand(rng)) * side
end
