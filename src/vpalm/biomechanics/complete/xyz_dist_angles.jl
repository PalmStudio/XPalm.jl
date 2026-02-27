"""
    xyz_to_dist_and_angles(points)

Compute segment lengths and angles from point coordinates.

# Arguments

- `points`: A vector of `GeometryBasics.Point{3}`.

# Returns

- A NamedTuple with fields:
  - `dist_p2p1`: Vector of segment lengths (m).
  - `vangle_xy`: Vector of angles between the segment and the XY plane (radians).
  - `vangle_xz`: Vector of angles between the segment and the XZ plane (radians).
"""
function xyz_to_dist_and_angles(points::AbstractVector{P}) where {P<:GeometryBasics.Point}
    n = length(points)

    coord_type = typeof(points[1][1])
    zero_coord = zero(coord_type)
    zero_point = GeometryBasics.Point{3,coord_type}(zero_coord, zero_coord, zero_coord)
    dist_p2p1 = fill(zero_coord, n)
    vangle_xy = zeros(n)
    vangle_xz = zeros(n)

    for iter in 1:n
        p2 = points[iter]

        if iter == 1
            p1 = zero_point
        else
            p1 = points[iter-1]
        end

        p2p1 = p2 - p1

        # Distance:
        dist_p2p1[iter] = sqrt(p2p1[1]^2 + p2p1[2]^2 + p2p1[3]^2)

        # Calculate angles using atan2 which handles all quadrants and edge cases
        xy_projection = sqrt(p2p1[1]^2 + p2p1[2]^2)

        # Elevation angle (from XY plane up to vector)
        vangle_xy[iter] = atan(p2p1[3], xy_projection)

        # Azimuth angle (in XY plane, from X-axis)
        vangle_xz[iter] = atan(p2p1[2], p2p1[1])
    end

    return (dist_p2p1=dist_p2p1, vangle_xy=vangle_xy * u"rad", vangle_xz=vangle_xz * u"rad")
end

"""
    dist_and_angles_to_xyz(dist_p2p1, vangle_xy, vangle_xz)

Transform distances and angles into point coordinates.

# Arguments
- `dist_p2p1`: Vector of segment lengths (m).
- `vangle_xy`: Vector of angles between the segment and the XY plane (radians).
- `vangle_xz`: Vector of angles between the segment and the XZ plane (radians).

# Returns

The points as a vector of `GeometryBasics.Point{3}`.
"""
function dist_and_angles_to_xyz(dist_p2p1, vangle_xy, vangle_xz)
    n = length(dist_p2p1)

    if length(vangle_xy) != n
        error("length of vangle_xy != n")
    end
    if length(vangle_xz) != n
        error("length of vangle_xz != n")
    end

    coord_type = typeof(dist_p2p1[1] * cos(vangle_xy[1]) * cos(vangle_xz[1]))
    zero_coord = zero(coord_type)
    zero_point = GeometryBasics.Point{3,coord_type}(zero_coord, zero_coord, zero_coord)
    points = Vector{typeof(zero_point)}(undef, n)

    for iter in 1:n
        # Create vector in spherical-like coordinates
        # (We're using the elevation-azimuth convention here)
        magnitude = dist_p2p1[iter]
        elevation = vangle_xy[iter]
        azimuth = vangle_xz[iter]

        # Convert to Cartesian coordinates and create a vector
        dz = magnitude * sin(elevation)
        dist_xy = magnitude * cos(elevation)
        dx = dist_xy * cos(azimuth)
        dy = dist_xy * sin(azimuth)

        displacement = GeometryBasics.Vec{3,coord_type}(dx, dy, dz)

        if iter == 1
            points[iter] = zero_point + displacement
        else
            # Add the displacement to the previous point
            points[iter] = points[iter-1] + displacement
        end
    end

    return points
end
