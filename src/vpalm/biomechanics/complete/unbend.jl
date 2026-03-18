"""
    unbend(distance, inclination)

Removes torsion and bending of a bent beam by transforming it into a straight line,
while preserving its insertion angle (inclination angle of the first segment).

# Arguments
- `distance`: Vector of distances between consecutive points (in meters)
- `inclination`: Vector of inclination angles (in degrees), only the first value is used

# Returns
- A vector of `GeometryBasics.Point{3}` objects representing the unbent positions

# Details
This function creates a straight line with the same cumulative length as the input
distances, while maintaining the insertion angle specified by the first inclination value.
The output points represent the unbent state of a curved structure.

# Note
Mainly used to compute the input coordinates for `bend()` from experimental points.

# Example

```jl
using VPalm, Unitful, GeometryBasics
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

    point_type = GeometryBasics.Point{3,typeof(x_distance[1])}
    zero_length = zero(x_distance[1])
    vec_points = Vector{point_type}(undef, length(distance))

    # Compute coordinates of points (unbent state)
    rotation = RotYZ(agl_y, agl_z)
    for i in 1:length(distance)
        rotated = rotation * GeometryBasics.Vec{3,typeof(x_distance[i])}(x_distance[i], zero_length, zero_length)
        vec_points[i] = point_type(rotated[1], rotated[2], rotated[3])
    end

    return vec_points
end
