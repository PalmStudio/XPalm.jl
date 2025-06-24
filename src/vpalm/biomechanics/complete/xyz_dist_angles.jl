"""
    xyz_to_dist_and_angles(points)

Compute segment lengths and angles from point coordinates.

# Arguments

- `points`: A vector of `Meshes.Points`.

# Returns

- A NamedTuple with fields:
  - `dist_p2p1`: Vector of segment lengths (m).
  - `vangle_xy`: Vector of angles between the segment and the XY plane (radians).
  - `vangle_xz`: Vector of angles between the segment and the XZ plane (radians).
"""
function xyz_to_dist_and_angles(points::AbstractVector{P}) where {P<:Meshes.Point}
    n = length(points)

    zero_point = Meshes.Point(0.0, 0.0, 0.0)
    dist_p2p1 = fill(Meshes.coords(zero_point).x, n)
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
        dist_p2p1[iter] = Meshes.norm(p2p1)

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

The points as a vector of `Meshes.Point`.
"""
function dist_and_angles_to_xyz(dist_p2p1, vangle_xy, vangle_xz)
    n = length(dist_p2p1)

    if length(vangle_xy) != n
        error("length of vangle_xy != n")
    end
    if length(vangle_xz) != n
        error("length of vangle_xz != n")
    end

    points = Vector{Meshes.Point}(undef, n)

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

        # Create a displacement vector using Meshes
        displacement = Meshes.Vec(dx, dy, dz)

        if iter == 1
            points[iter] = Meshes.Point(displacement...)
        else
            # Add the displacement to the previous point
            points[iter] = points[iter-1] + displacement
        end
    end

    return points
end