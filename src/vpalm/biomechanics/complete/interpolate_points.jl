"""
    interp_points(points, step)

Interpolate points along a path to have equidistant points.

# Arguments
- `points`: Vector of Meshes.Point objects defining the original path.
- `step`: Distance between interpolated points.

# Returns
- `vec_points`: Vector of interpolated Meshes.Point objects.
- `i_discret_pts_exp`: Indices of the original points in the interpolated path.
- `vec_dist_p2p1`: Vector of distances between consecutive points.
- `vec_angle_xy`: Vector of angles between segments and the XY plane.
- `vec_angle_xz`: Vector of angles between segments and the XZ plane.
"""
function interp_points(points::AbstractVector{P}, step) where P<:Meshes.Point
    n_points_exp = length(points)

    # Calculate the distances and angles of the original path
    dist_p2p1, vangle_xy, vangle_xz = xyz_to_dist_and_angles(points)

    # Calculate cumulative distance
    zero_distance = zero(eltype(dist_p2p1))
    dist_lineique = [zero_distance; cumsum(dist_p2p1)]
    dist_totale = last(dist_lineique)

    # Determine the number of interpolated points
    nlin = round(Int, dist_totale / step + 1)

    # Create distance array for interpolated points
    vec_dist = collect(range(zero(step), dist_totale, length=nlin))

    # Create array to store interpolated points
    vec_points = Vector{P}(undef, nlin)
    # Process each segment from the original path
    for i in 1:n_points_exp
        # Find all interpolation points that fall within this segment
        start_dist = i == 1 ? zero_distance : dist_lineique[i]
        end_dist = dist_lineique[i+1]

        # Find interpolation points in this segment
        segment_points = findall(d -> start_dist <= d <= end_dist, vec_dist)
        # Skip if no points in this segment
        if isempty(segment_points)
            continue
        end

        # Get the start and end points for this segment
        p1 = i == 1 ? Meshes.Point(zero_distance, zero_distance, zero_distance) : points[i-1]
        p2 = points[i]

        # Calculate the segment vector
        segment_vector = p2 - p1

        # Get the rotation that aligns with this segment
        rotation = RotZY(-vangle_xz[i], -vangle_xy[i])

        for j in segment_points
            # Calculate relative position in the segment
            rel_pos = (vec_dist[j] - start_dist) / (end_dist - start_dist)

            # Interpolate along the segment
            if i == 1
                # For the first segment, interpolate directly
                vec_points[j] = p1 + segment_vector * rel_pos
            else
                # Calculate the displacement vector
                displacement = Meshes.Point(rel_pos * dist_p2p1[i], zero_distance, zero_distance)

                # Apply rotation to the displacement
                rotated_displacement = rotation * Meshes.to(displacement)

                # Apply the rotated displacement to the segment start point
                vec_points[j] = p1 + rotated_displacement
            end

        end
    end

    # Identify indices of original points in the interpolated path
    i_discret_pts_exp = zeros(Int, n_points_exp)
    for i in 1:n_points_exp
        # Find the closest interpolated point to each original point
        target_dist = dist_lineique[i+1]
        _, idx = findmin(abs.(vec_dist .- target_dist))
        i_discret_pts_exp[i] = idx
    end

    # Calculate distances and angles for the interpolated path
    dist_p2p1, vangle_xy, vangle_xz = xyz_to_dist_and_angles(vec_points)

    return (points=vec_points, i_discret_pts_exp=i_discret_pts_exp, vec_dist_p2p1=dist_p2p1, vec_angle_xy=vangle_xy, vec_angle_xz=vangle_xz)
end