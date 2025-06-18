"""
    bend(
        type, width_bend, height_bend, init_torsion, x, y, z, mass_rachis, mass_leaflets_right, mass_leaflets_left,
        distance_application, elastic_modulus, shear_modulus, step, npoints, nsegments;
        all_points=false,
        angle_max=deg2rad(21),
        force=true,
        verbose=true
    )

Compute the deformation of the rachis by applying both bending and torsion.

# Arguments
- `type`: Vector of section types (1: triangle bottom, 2: rectangle, 3: triangle top, 4: ellipse, 5: circle).
- `width_bend`: Vector of segment section widths (m).
- `height_bend`: Vector of segment section heights (m).
- `init_torsion`: Vector of initial torsion angles (degrees).
- `x`: Vector of x coordinates of the segments.
- `y`: Vector of y coordinates of the segments.
- `z`: Vector of z coordinates of the segments.
- `mass_rachis`: Vector of rachis segment masses (kg).
- `mass_leaflets_right`: Vector of leaflet masses carried by the segment, on the right side (kg).
- `mass_leaflets_left`: Vector of leaflet masses carried by the segment, on the left side (kg).
- `distance_application`: Vector of application distances for the left and right weights (m).
- `elastic_modulus`: Vector of elasticity moduli (bending, MPa).
- `shear_modulus`: Vector of shear moduli (torsion, MPa).
- `step`: Length of the segments that discretize the object (m).
- `npoints`: Number of points used in the grid discretizing the section.
- `nsegments`: Number of segments dividing the rachis to compute the torsion and bending.
- `all_points=false`: return all points used in the computation (`true`), or only the input points corresponding to x, y and z coordinates (`false`, default).
- `angle_max=deg2rad(21)`: Maximum angle for testing the small displacement hypothesis (radians).
- `force=true`: Check if verify the small displacements hypothesis and bounds the values to be at maximum `angle_max`
- `verbose=true`: Provide information during computation.

# Returns
Named tuple with geometrical fields describing the rachis bended and with torsion applied
- `x`: x coordinates of the points.
- `y`: y coordinates of the points.
- `z`: z coordinates of the points.
- `length`: length of the segments.
- `angle_xy`: angle between the xy-plan and the segment.
- `angle_xz`: angle between the xz-plan and the segment.
- `torsion`: torsion angle of the segment.
All these fields are vectors of the same length as the input vectors (i.e. number of segments).

# Details
The bending and torsion are applied to the sections of the rachis defined by 5 segments.

"""
function bend(type, width_bend, height_bend, init_torsion, x, y, z, mass_rachis, mass_leaflets_right, mass_leaflets_left,
    distance_application, elastic_modulus, shear_modulus, step, npoints, nsegments;
    all_points=false,
    angle_max=deg2rad(21u"°"),
    force=true,
    verbose=true
)

    @assert length(type) == length(width_bend) == length(height_bend) == length(init_torsion) == length(x) == length(y) == length(z) == length(mass_rachis) == length(mass_leaflets_right) == length(mass_leaflets_left) == length(distance_application) "All arguments should have the same length."

    # Number of experimental points
    npoints_exp = length(x)  # Assuming x, y, z have the same length

    if length(elastic_modulus) != npoints_exp
        if length(elastic_modulus) == 1
            elastic_modulus = fill(elastic_modulus, npoints_exp)
        else
            error("`elastic_modulus` argument should be of length 1 or equal to `npoints_exp`")
        end
    end

    if length(shear_modulus) != npoints_exp
        if length(shear_modulus) == 1
            shear_modulus = fill(shear_modulus, npoints_exp)
        else
            error("`shear_modulus` argument should be of length 1 or equal to `npoints_exp`")
        end
    end

    step = @check_unit step u"m"
    mass_leaflets_right = [@check_unit m u"kg" for m in mass_leaflets_right]
    mass_leaflets_left = [@check_unit m u"kg" for m in mass_leaflets_left]
    mass_rachis = [@check_unit m u"kg" for m in mass_rachis]
    width_bend = [@check_unit w u"m" for w in width_bend]
    height_bend = [@check_unit h u"m" for h in height_bend]
    distance_application = [@check_unit d u"m" for d in distance_application]
    elastic_modulus = [@check_unit e u"MPa" for e in elastic_modulus]
    shear_modulus = [@check_unit s u"MPa" for s in shear_modulus]

    # use coordinates x,y,z to make points:
    points = [Meshes.Point(x[i], y[i], z[i]) for i in eachindex(x)]
    gravity = 9.8u"m/s^2"

    # Distances and angles of each segment P2P1
    vdist_p2p1, = xyz_to_dist_and_angles(points)
    zero_m = zero(eltype(vdist_p2p1))
    dist_lineique = [zero_m; cumsum(vdist_p2p1)] # For interpolation
    dist_totale = last(dist_lineique)

    # The distances of the segments cannot be zero. The origin point (0,0,0) cannot be in the data
    if any(vdist_p2p1 .== zero_m)
        error("Found distances between segments equal to 0.")
    end

    # vdist_p2p1_nounit = ustrip(vdist_p2p1)
    poids_lin_tige = mass_rachis ./ vdist_p2p1 ./ nsegments # Should be in kg/m (linear density)
    v_poids_feuilles_d = mass_leaflets_right ./ vdist_p2p1 ./ nsegments
    v_poids_feuilles_g = mass_leaflets_left ./ vdist_p2p1 ./ nsegments
    v_poids_flexion = poids_lin_tige .+ v_poids_feuilles_d .+ v_poids_feuilles_g

    # Linear interpolations, segment length = step
    nlin = round(Int, dist_totale / step + 1)
    step = dist_totale / (nlin - 1)
    vec_dist = collect((0:(nlin-1)) .* step)
    vec_dist[end] = dist_totale
    # Note: we force vec_dist[end] to dist_lineique[end] to avoid any rounding error

    vec_moe = uconvert.(u"Pa", linear_interpolation(dist_lineique, [elastic_modulus[1]; elastic_modulus])(vec_dist)) # Should be in Pa
    vec_g = uconvert.(u"Pa", linear_interpolation(dist_lineique, [shear_modulus[1]; shear_modulus])(vec_dist)) # Should be in Pa
    vangle_tor = deg2rad.(init_torsion)
    vec_agl_tor = linear_interpolation(dist_lineique, [vangle_tor[1]; vangle_tor])(vec_dist)
    vec_d_appli_poids_feuille = linear_interpolation(dist_lineique, [distance_application[1]; distance_application])(vec_dist)

    # Interpolation of coordinates in the origin frame
    # Identification of experimental points in the linear discretization
    vec_points, i_discret_pts_exp, vec_dist_p2p1, vec_angle_xy, vec_angle_xz = interp_points(points, step)

    val_epsilon = 1e-6u"m"
    if (vec_dist_p2p1[2] > (step + val_epsilon)) || (vec_dist_p2p1[2] < (step - val_epsilon))
        error("Point distance too narrow")
    end
    if (length(vec_points) != nlin)
        error("length(vec_points) != nlin")
    end

    # Increment of weight for the iterative calculation
    mat_dist_pts_exp = zeros(nsegments, npoints_exp) * u"m"

    som_cum_vec_agl_tor = copy(vec_agl_tor)  # geometric rotation and section

    for iter_poids in 1:nsegments
        # Inertias and surfaces of the experimental points
        v_ig_flex = fill(0.0u"m^4", npoints_exp)
        v_ig_tor = fill(0.0u"m^4", npoints_exp)
        v_sr = fill(0.0u"m^2", npoints_exp)

        for iter in 1:npoints_exp
            ag_rad = som_cum_vec_agl_tor[i_discret_pts_exp[iter]]  # orientation section (radians)
            inertia_flex_rot = inertia_flex_rota(width_bend[iter], height_bend[iter], ag_rad, type[iter], npoints)
            v_ig_flex[iter] = inertia_flex_rot.ig_flex
            v_ig_tor[iter] = inertia_flex_rot.ig_tor
            v_sr[iter] = inertia_flex_rot.sr
        end

        # Linear interpolation of inertias
        vec_inertie_flex = linear_interpolation(dist_lineique, [v_ig_flex[1]; v_ig_flex])(vec_dist) # Should be in m⁴
        vec_inertie_tor = linear_interpolation(dist_lineique, [v_ig_tor[1]; v_ig_tor])(vec_dist)

        # Write angles from the new coordinates
        # Distance and angles of each segment P2P1
        vec_dist_p2p1, vec_angle_xy, vec_angle_xz = xyz_to_dist_and_angles(vec_points)

        vec_dist_p2p1[1] = zero(eltype(vec_dist_p2p1))
        vec_angle_xy[1] = vec_angle_xy[2]
        vec_angle_xz[1] = vec_angle_xz[2]

        # Flexion: linear bending forces and linear interpolation
        v_force = v_poids_flexion .* cos.(vec_angle_xy[i_discret_pts_exp]) .* gravity # Should be in N*m, or kg·m²·s⁻²

        vec_force = linear_interpolation(dist_lineique, [v_force[1]; v_force])(vec_dist)

        # Shear forces and bending moments
        vec_shear = cumsum(vec_force[nlin:-1:1] .* step)
        vec_shear = vec_shear[nlin:-1:1]

        vec_moment = -cumsum(vec_shear[nlin:-1:1] .* step)
        vec_moment = vec_moment[nlin:-1:1]

        # Classic calculation of the deflection (distance delta)
        fct = vec_moment ./ (vec_moe .* vec_inertie_flex)

        vec_angle_flexion = cumsum(fct[nlin:-1:1] .* step)
        vec_angle_flexion = vec_angle_flexion[nlin:-1:1]

        # Embedded condition (derivative 1 = 0)
        vec_angle_flexion = vec_angle_flexion[1] .- vec_angle_flexion

        # Test of the small displacement hypothesis
        if verbose && maximum(abs.(vec_angle_flexion)) > angle_max
            @warn string("Maximum bending angle: ", rad2deg(maximum(abs.(vec_angle_flexion))), "°. Hypothesis of small displacements not verified for bending.")
            force && (vec_angle_flexion[abs.(vec_angle_flexion).>angle_max] .= angle_max)
        end

        # Torsion
        zero_force = 0.0u"N"
        zero_torque = 0.0u"N*m"
        v_m_tor = fill(zero_torque, npoints_exp) # should be in kg·m²·s⁻² == N·m

        for iter in 1:npoints_exp
            # Calculate forces with explicit units
            force_z_right = -v_poids_feuilles_d[iter] * vdist_p2p1[iter] * gravity  # N
            force_z_left = -v_poids_feuilles_g[iter] * vdist_p2p1[iter] * gravity   # N

            force_feuille_dr = RotYZ(vec_angle_xy[iter], -vec_angle_xz[iter]) * [zero_force, zero_force, force_z_right]
            force_feuille_ga = RotYZ(vec_angle_xy[iter], -vec_angle_xz[iter]) * [zero_force, zero_force, force_z_left]

            dist_point = vec_d_appli_poids_feuille[i_discret_pts_exp[iter]]
            angle_point = som_cum_vec_agl_tor[i_discret_pts_exp[iter]]

            # Hypothesis of contribution part right or left
            if angle_point > 0
                kd = 0
                kg = 1
            elseif angle_point < 0
                kd = 1
                kg = 0
            else # angle_point == 0
                kd = 0
                kg = 0
            end

            md = dist_point * kd * cos(angle_point) * force_feuille_dr[3]
            mg = dist_point * kg * cos(angle_point + π) * force_feuille_ga[3]

            v_m_tor[iter] = md + mg
        end

        vec_m_tor = linear_interpolation(dist_lineique, [v_m_tor[1]; v_m_tor])(vec_dist)

        vec_deriv_agl_tor = vec_m_tor ./ (vec_g .* vec_inertie_tor)

        vec_angle_torsion = cumsum(vec_deriv_agl_tor .* step)  # integration along the stem

        if verbose && maximum(abs.(vec_angle_torsion)) > angle_max
            @warn string("Maximum torsion angle: ", rad2deg(maximum(abs.(vec_angle_torsion))), "°. Hypothesis of small displacements not verified for torsion.")
            force && (vec_angle_torsion[abs.(vec_angle_torsion).>angle_max] .= angle_max)
        end

        som_cum_vec_agl_tor .+= vec_angle_torsion  # cumulative by weight increment

        if verbose && iter_poids == nsegments
            @info string("Final torsion angle at the tip: ", rad2deg(som_cum_vec_agl_tor[end]), "°")
        end

        # New coordinates of the points
        neo_points = fill(Meshes.Point(0.0u"m", 0.0u"m", 0.0u"m"), nlin)

        for iter in 1:nlin
            # Origin P1
            p2 = vec_points[iter]
            if iter == 1
                p1 = Meshes.Point(0.0u"m", 0.0u"m", 0.0u"m")
            else
                p1 = vec_points[iter-1]
            end

            p2p1_vec = p2 - p1

            # Change of basis
            # Segment becomes collinear to the OX axis
            p2_rot = Meshes.Rotate(RotYZ(vec_angle_xy[iter], -vec_angle_xz[iter]))(p2p1_vec)

            # Flexion equivalent to a rotation around OY
            # Rotation around OY: The rotation is wrong for strong angles
            flex_point = Meshes.Point(p2_rot[1], p2_rot[2], step * vec_angle_flexion[iter])
            # Torsion
            # Equivalent to a rotation around OX, initially the section is rotated but without torsion
            agl_tor_geom = som_cum_vec_agl_tor[iter] - vec_agl_tor[iter]
            # point_rot = Meshes.Rotate(RotXYZ(agl_tor_geom, -vec_angle_xy[iter], -vec_angle_xz[iter]))(flex_point)
            point_rot = Meshes.Rotate(Rotations.RotZYX(vec_angle_xz[iter], -vec_angle_xy[iter], agl_tor_geom))(flex_point)
            # point_rot = Meshes.Rotate(Rotations.RotZY(vec_angle_xz[iter], agl_tor_geom))(flex_point)

            # Re-writing the points:
            if iter == 1
                neo_points[iter] = point_rot
            else
                neo_points[iter] = neo_points[iter-1] + Meshes.to(point_rot)
            end
        end

        # Conservation of distances
        XYZangles = xyz_to_dist_and_angles(neo_points)
        vec_points .= dist_and_angles_to_xyz([zero(step); fill(step, nlin - 1)], XYZangles.vangle_xy, XYZangles.vangle_xz) # Assuming this function is defined elsewhere

        # Calculation of the distances of the experimental points
        # Between before and after deformation
        for i in 1:npoints_exp
            vec_p = Meshes.coords(vec_points[i_discret_pts_exp[i]])
            p = Meshes.coords(points[i])
            c1 = (p.x - vec_p.x)^2
            c2 = (p.y - vec_p.y)^2
            c3 = (p.z - vec_p.z)^2

            mat_dist_pts_exp[iter_poids, i] = sqrt(c1 + c2 + c3)
        end
    end

    if all_points
        i_discret_pts_exp = eachindex(vec_points)
    end

    pts_agl_tor = rad2deg.(som_cum_vec_agl_tor[i_discret_pts_exp])

    pts_dist, pts_agl_xy, pts_agl_xz = xyz_to_dist_and_angles(vec_points[i_discret_pts_exp])
    pts_agl_xy[1] = pts_agl_xy[2]
    pts_agl_xz[1] = pts_agl_xz[2]

    return (points=vec_points[i_discret_pts_exp], length=pts_dist, angle_xy=rad2deg.(pts_agl_xy), angle_xz=rad2deg.(pts_agl_xz), torsion=pts_agl_tor)
end
