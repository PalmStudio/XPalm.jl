"""
    biomechanical_properties_rachis(
        rachis_twist_initial_angle, rachis_twist_initial_angle_sdp,
        elastic_modulus, shear_modulus, rachis_length,
        leaflet_length_at_b_intercept, leaflet_length_at_b_slope, relative_position_bpoint,
        relative_position_bpoint_sd, relative_length_first_leaflet, relative_length_last_leaflet, relative_position_leaflet_max_length,
        rachis_fresh_weight, rank, height_cpoint, zenithal_cpoint_angle, nb_sections,
        height_rachis_tappering,
        points, iterations, angle_max;
        verbose, rng
    )

Use of the biomechanical model to compute the properties of the rachis.

# Arguments
- `rachis_twist_initial_angle`: initial twist angle of the rachis (°)
- `rachis_twist_initial_angle_sdp`: standard deviation of the initial twist angle of the rachis (°)
- `elastic_modulus`: elastic modulus of the rachis (Pa)
- `shear_modulus`: shear modulus of the rachis (Pa)
- `rachis_length`: length of the rachis (m)
- `leaflet_length_at_b_intercept`: intercept of the linear function for the leaflet length at the B point (m)
- `leaflet_length_at_b_slope`: slope of the linear function for the leaflet length at the B point (m)
- `relative_position_bpoint`: relative position of the B point on the rachis (0: base to 1: tip)
- `relative_position_bpoint_sd`: standard deviation of the relative position of the B point on the rachis
- `relative_length_first_leaflet`: relative length of the first leaflet on the rachis (0 to 1)
- `relative_length_last_leaflet`: relative length of the last leaflet on the rachis (0 to 1)
- `relative_position_leaflet_max_length`: relative position of the longest leaflet on the rachis (0.111 to 0.999)
- `rachis_fresh_weight`: fresh weight of the rachis (kg)
- `rank`: rank of the rachis
- `height_cpoint`: height of the C point (m)
- `zenithal_cpoint_angle`: zenithal angle of the C point (°)
- `nb_sections`: number of sections to compute the bending
- `height_rachis_tappering`: tappering factor for the rachis height
- `npoints_computed`: number of points to compute the bending
- `iterations`: number of iterations to compute the bending
- `angle_max`: maximum angle to compute the bending (°)
- `verbose`: display information about the computation (e.g. checks on the units)
- `rng`: the random number generator

# Returns
A named tuple with the following fields:
- `length`: vector with the length of each segment
- `points_positions`: the position of the points along the rachis
- `bending`: the bending angle of the rachis
- `deviation`: the deviation of the rachis (angle in the xz plane)
- `torsion`: the torsion of the rachis
- `x`: the x coordinates of the rachis
- `y`: the y coordinates of the rachis
- `z`: the z coordinates of the rachis

# Details
Split the rachis into 5 segments defined by remarkable points (C, C-B, B, B-A, A).
Each segment has a particular shape, a mass, and the leaflets on both sides of the rachis have a mass.
Coefficents are used to compute the mass distribution and relative lengths of segments.
The rachis is bent using the `bend` function.
"""
function biomechanical_properties_rachis(
    rachis_twist_initial_angle, rachis_twist_initial_angle_sdp,
    elastic_modulus, shear_modulus, rachis_length,
    leaflet_length_at_b_intercept, leaflet_length_at_b_slope, relative_position_bpoint,
    relative_position_bpoint_sd, relative_length_first_leaflet, relative_length_last_leaflet, relative_position_leaflet_max_length,
    rachis_fresh_weight, rank, height_cpoint, zenithal_cpoint_angle, nb_sections,
    height_rachis_tappering, npoints_computed, iterations, angle_max;
    verbose, rng
)

    rachis_twist_initial_angle = @check_unit rachis_twist_initial_angle u"°" verbose
    rachis_twist_initial_angle_sdp = @check_unit rachis_twist_initial_angle_sdp u"°" verbose
    elastic_modulus = @check_unit elastic_modulus u"MPa" verbose
    shear_modulus = @check_unit shear_modulus u"MPa" verbose
    rachis_length = @check_unit rachis_length u"m" verbose
    leaflet_length_at_b_intercept = @check_unit leaflet_length_at_b_intercept u"m" verbose
    rachis_fresh_weight = @check_unit rachis_fresh_weight u"kg" verbose
    height_cpoint = @check_unit height_cpoint u"m" verbose
    zenithal_cpoint_angle = @check_unit zenithal_cpoint_angle u"°" verbose
    angle_max = @check_unit angle_max u"°" verbose

    # Frond section types (e.g., rectangle, ellipsoid, etc.)
    type = [1, 2, 3, 4, 5]
    npoints = length(type)

    # Compute initial torsion (using prms and rnd assumed to be defined)
    initial_torsion_sdp = rachis_twist_initial_angle + normal_deviation_draw(rachis_twist_initial_angle_sdp, rng)

    initial_torsion_vec = fill(initial_torsion_sdp, npoints)
    # Relative position of the remarkable points (C, C-B, B, B-A, A) on the rachis:
    relative_position_remarkable_points = [0.0000001, 0.336231351023383, 0.672462702046766, 0.836231351023383, 1.0]
    # Note: we use those positions as remarkable points along the rachis, and each segment (or section) is defined by two consecutive points.
    # Each segment has a particular shape, a mass, and the leaflets on both sides of the rachis have a mass.

    # Relative position at the middle of each segment:
    relative_position_mid_segment = [0.1681157, 0.504347, 0.672462702046766, 0.754347, 0.9181157]

    # Distribution of the mass for each segment relative to the total rachis mass:
    mass_distribution_segment_rachis = [0.0, 0.648524097435024, 0.277401814695433, 0.0601164171693578, 0.0139576707001849]

    # Distribution of the mass for each leaflet relative to the total rachis mass:
    mass_distribution_segment_leaflet = [0.0, 0.0658151279405379, 0.201957451540734, 0.105263443497354, 0.0475385258600695]

    # Initialization of data computed for each of the 5 remarkable points:
    mass = fill(0.0u"kg", npoints)               # Mass of each segment represented by the points
    mass_right = fill(0.0u"kg", npoints)         # Mass of the leaflets on the right-hand side of each segment
    mass_left = fill(0.0u"kg", npoints)          # Mass of the leaflets on the left-hand side of each segment
    width_bend = fill(0.0u"m", npoints)          # Width of the segment (rachis width)
    height_bend = fill(0.0u"m", npoints)         # Height of the segment (rachis height)
    distances = fill(0.0u"m", npoints)           # Distance between the points projected on the X axis
    distance_application = fill(0.0u"m", npoints) # Application distance for forces (if needed)

    leaflet_length_at_b = leaflet_length_at_bpoint(rachis_length, leaflet_length_at_b_intercept, leaflet_length_at_b_slope)
    leaflet_max_length = leaflet_length_max(leaflet_length_at_b, relative_position_bpoint, relative_length_first_leaflet, relative_length_last_leaflet, relative_position_leaflet_max_length, relative_position_bpoint_sd, rng)

    # Parameters to compute rachis width from rachis height:
    ratioPointC = 0.5220
    ratioPointA = 1.0053
    posRatioMax = 0.6636
    ratioMax = 1.5789

    for i in 1:npoints
        distances[i] = rachis_length * relative_position_remarkable_points[i]
        mass[i] = mass_distribution_segment_rachis[i] * rachis_fresh_weight
        # we consider that the leaflets on both sides of the rachis have the same mass:
        mass_right[i] = mass_distribution_segment_leaflet[i] * rachis_fresh_weight
        mass_left[i] = mass_distribution_segment_leaflet[i] * rachis_fresh_weight

        # leaflet length at the middle of the segment (in m):
        length_leaflets_segment = leaflet_max_length * relative_leaflet_length(
            relative_position_mid_segment[i],
            relative_length_first_leaflet, relative_length_last_leaflet,
            relative_position_leaflet_max_length
        )

        distance_application[i] = length_leaflets_segment / 10.0  # The leaflet weight is applied at the middle of the leaflets

        if rank < 3
            distance_application[i] = 1e-8u"m"
            initial_torsion_vec[i] = 0.0u"°"
        end

        height_bend[i] = rachis_height(relative_position_remarkable_points[i], height_cpoint, height_rachis_tappering)
        width_bend[i] = height_bend[i] / height_to_width_ratio(relative_position_remarkable_points[i], ratioPointC, ratioPointA, posRatioMax, ratioMax)
    end

    # Un-bent coordinates (take the leaf as a straight line in x and z)
    x = fill(0.0u"m", 5)
    y = fill(0.0u"m", 5)
    z = fill(0.0u"m", 5)

    points = Vector{typeof(Meshes.Point(0.0, 0.0, 0.0))}(undef, npoints)
    for n in eachindex(distances)
        # zenithal_cpoint_angle is at 0° when vertical (along the Z axis), or 90° when horizontal (along the X axis)
        position_ref = Meshes.Point(0.0u"m", 0.0u"m", distances[n])
        points[n] = Meshes.Rotate(RotY(deg2rad(zenithal_cpoint_angle)))(position_ref)
    end

    step = rachis_length / (nb_sections - 1)

    # extract the points coordinates to give to bend:
    x = [Meshes.coords(p).x for p in points]
    y = [Meshes.coords(p).y for p in points]
    z = [Meshes.coords(p).z for p in points]
    #! Update bend so we can pass the points directly

    # Call the bend function, which returns a vector of arrays:
    # bending -> { PtsX, PtsY, PtsZ, PtsDist, PtsAglXY, PtsAglXZ, PtsAglTor }
    bending = bend(
        type, width_bend, height_bend, initial_torsion_vec, x, y, z, mass, mass_right, mass_left,
        distance_application, elastic_modulus, shear_modulus, step, npoints_computed, iterations;
        verbose=false, all_points=true, angle_max=angle_max
    )

    # points_bending = .-bending.angle_xy
    # points_bending[1] = -zenithal_cpoint_angle         # Initialize the first angle as the angle at C point
    x_coordinates = [Meshes.coords(p).x for p in bending.points]
    y_coordinates = [Meshes.coords(p).y for p in bending.points]
    z_coordinates = [Meshes.coords(p).z for p in bending.points]

    #! update this function to return the points directly
    return (
        length=fill(step, length(x_coordinates)), points_positions=bending.length, bending=bending.angle_xy, deviation=bending.angle_xz, torsion=bending.torsion,
        x=x_coordinates, y=y_coordinates, z=z_coordinates
    )
end


"""
    rachis_height(relative_position, cpoint_height, rachis_height_tappering)

Computes the rachis height (m) at a given relative position using a the height at C Point and rachis tappering.

# Arguments

- `relative_position`: The relative position along the rachis (0: base to 1: tip).
- `cpoint_height`: The height of the rachis at the C point, *i.e.* rachis base (m).
- `rachis_height_tappering`: The tappering factor for the rachis height.
"""
function rachis_height(relative_position, cpoint_height, rachis_height_tappering)
    return (1.0 + rachis_height_tappering * (relative_position^3)) * cpoint_height
end



"""
    rachis_width(relative_position, cpoint_width, rachis_width_tip)

Computes the rachis width (m) at a given relative position using the width at C Point and rachis width at the tip.

# Arguments

- `relative_position`: The relative position along the rachis (0: base to 1: tip).
- `cpoint_width`: The width of the rachis at the C point, *i.e.* rachis base (m).
- `rachis_width_tip`: The width of the rachis at the tip (m).
"""
function rachis_width(relative_position, cpoint_width, rachis_width_tip)
    return cpoint_width * (1.0 - relative_position) + rachis_width_tip * relative_position
end

"""
    height_to_width_ratio(x, ratio_point_c, ratio_point_a, pos_ratio_max, ratio_max)

Computes the relative width along the rachis.

# Arguments

- `x`: relative position on the rachis
- `ratio_point_c`: ratio at point C
- `ratio_point_a`: ratio at point A
- `pos_ratio_max`: relative position of the maximum value of the ratio
- `ratio_max`: maximum ratio value
"""
function height_to_width_ratio(x, ratio_point_c, ratio_point_a, pos_ratio_max, ratio_max)
    if x < pos_ratio_max
        return ratio_point_c + x * (ratio_max - ratio_point_c) / pos_ratio_max
    else
        return x * (ratio_point_a - ratio_max) / (1 - pos_ratio_max) +
               (ratio_max - pos_ratio_max * ratio_point_a) / (1 - pos_ratio_max)
    end
end