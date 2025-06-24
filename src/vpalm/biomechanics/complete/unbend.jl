"""
    unbend(distance, inclination)

Removes torsion and bending of a bent beam by transforming it into a straight line,
while preserving its insertion angle (inclination angle of the first segment).

# Arguments
- `distance`: Vector of distances between consecutive points (in meters)
- `inclination`: Vector of inclination angles (in degrees), only the first value is used

# Returns
- A vector of Meshes.Point objects representing the unbent positions

# Details
This function creates a straight line with the same cumulative length as the input
distances, while maintaining the insertion angle specified by the first inclination value.
The output points represent the unbent state of a curved structure.

# Note
Mainly used to compute the input coordinates for `bend()` from experimental points.

# Example

```jl
using VPalm, Unitful, Meshes
distances = [0.001, 1.340, 1.340, 0.770, 0.770]u"m";
inclinations = [48.8, 48.8, 48.8, 48.8, 48.8];  # degrees
points = VPalm.unbend(distances, inclinations)
```
"""
function unbend(distance, inclination)
    # Distance between points cannot be 0
    zero_dist = findall(iszero, distance)
    if !isempty(zero_dist)
        distance[zero_dist] .= 1e-3u"m" # (m)
    end
    # Cumulative distance of each segment
    x_distance = cumsum(distance)

    # Keep insertion angle of first segment
    agl_y = -deg2rad(inclination[1])
    agl_z = 0.0

    vec_points = Vector{typeof(Meshes.Point(0.0, 0.0, 0.0))}(undef, length(distance))

    # Compute coordinates of points (unbent state)
    for i in 1:length(distance)
        vec_points[i] = Meshes.Rotate(RotYZ(agl_y, agl_z))(Meshes.Point(x_distance[i], 0.0u"m", 0.0u"m"))
    end

    return vec_points
end