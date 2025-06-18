"""
    final_angle(young_modulus, z_angle, length, tapering)

Calculate the maximal deformation angle of a beam.

# Arguments
- `young_modulus`: Value of Young's modulus
- `z_angle`: Angle from vertical (upright) in radians
- `length`: Length of the beam where the load is applied
- `tapering`: Tapering factor of the beam

# Returns
- The final angle from vertical at the cantilever extremity (in radians)
"""
function final_angle(young_modulus, z_angle, beam_length, tapering)
    beam_length = beam_length * 100.0  # Convert to centimeters (the original java function used cm)
    # Evaluation
    cos_theta = cos(z_angle)
    young = 1.0 / sqrt(young_modulus)
    h = beam_length / tapering

    coeff = young * h * sqrt(abs(cos_theta))

    # Initial deflection estimate
    deflection = if 1.553 < z_angle < 1.588
        young^2 * h^2 / 2.0
    else
        sin(z_angle) * (1.0 - cos(coeff)) / cos(coeff) / abs(cos_theta)
    end

    # Integration to find the actual deflection
    a_min = 0.0
    a_max = π - z_angle
    threshold = π / 180.0
    precision = beam_length / 10.0

    while (a_max - a_min) > threshold
        deflection = (a_max + a_min) / 2.0
        omega = 0.0
        sum_ = 0.0
        increment = 1.0
        nb_iter = 0

        while omega < deflection && increment != 0.0 && nb_iter < 500
            increment = precision * sqrt(2) * young *
                        sqrt(abs(cos(z_angle + omega) - cos(z_angle + deflection)))
            omega += increment
            sum_ += precision
            nb_iter += 1
        end

        if sum_ <= (h - precision)
            a_min = deflection
        else
            a_max = deflection
        end
    end

    deflection = (a_min + a_max) / 2.0
    final_angle = deflection + z_angle

    return final_angle
end

"""
    local_flexion(current_angle, final_angle, young_modulus, tapering, relative_position)

Calculate the local bending angle at a specific position along the beam.

# Arguments
- `current_angle`: Current angle in radians
- `final_angle`: Final angle of the beam in radians
- `young_modulus`: Value of Young's modulus
- `tapering`: Tapering factor of the beam
- `relative_position`: Relative position along the beam (0 to 1)

# Returns
- Flexion angle at the current position (in radians)
"""
function local_flexion(current_angle, final_angle, young_modulus, tapering, relative_position)
    angle = 2.0 * (cos(current_angle) - cos(final_angle))
    if angle < 0.0
        return 0.0
    end

    aux = 1.0 - ((1.0 - tapering) * relative_position)
    aux *= aux
    fl_re = 1.0 / (sqrt(young_modulus) * aux)
    angle = fl_re * sqrt(angle)

    return angle
end

"""
    calculate_segment_angles(young_modulus, initial_angle, leaflet_length, tapering, segment_positions)

Calculate the global angles for each segment of a bent leaflet based on the Young's modulus model.

# Arguments

- `young_modulus`: Value of Young's modulus
- `initial_angle`: Initial angle from vertical in radians
- `leaflet_length`: Total length of the leaflet
- `tapering`: Tapering factor
- `segment_positions`: Array of segment boundary positions (normalized 0-1)

# Returns

- Array of segment angles in radians
"""
function calculate_segment_angles(young_modulus, initial_angle, leaflet_length, tapering, segment_positions)
    @assert length(segment_positions) > 1 "`segment_positions` must contain more than one element."

    total_deflection = final_angle(young_modulus, initial_angle, leaflet_length, tapering)

    # Calculate angles at each segment boundary
    boundary_angles = zeros(length(segment_positions))
    boundary_angles[1] = initial_angle

    for i in 2:length(segment_positions)
        relative_pos = segment_positions[i] - segment_positions[1]
        current_angle = boundary_angles[i-1]

        # Calculate accumulated flexion up to this segment boundary
        flexion = 0.0
        prev_pos = segment_positions[i-1] - segment_positions[1]
        steps = 10  # Number of integration steps between segments
        step_size = (relative_pos - prev_pos) / steps

        for step in 1:steps
            step_pos = prev_pos + step * step_size
            flexion += local_flexion(
                current_angle + flexion,
                total_deflection,
                young_modulus,
                tapering,
                step_pos
            )
        end

        boundary_angles[i] = boundary_angles[i-1] + flexion
    end
    # If we need the local angles: `diff(boundary_angles)`
    return boundary_angles
end