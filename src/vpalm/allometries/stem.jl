
"""
    stem_bending(stem_bending_mean, stem_bending_sd; rng)

Computes the stem bending (°) using an average bending and a standard deviation (random draw from a normal distribution).

# Arguments

- `stem_bending_mean`: The average stem bending (°).
- `stem_bending_sd`: The standard deviation of the stem bending (°).

# Optional arguments

- `rng`: The random number generator.
"""
function stem_bending(stem_bending_mean, stem_bending_sd; rng)
    return mean_and_sd(stem_bending_mean, stem_bending_sd, rng)
end

"""
    stem_height(nb_leaves_emitted, initial_stem_height, stem_height_coefficient, internode_length_at_maturity, stem_growth_start; rng)

Computes the stem height (m) at a given number of leaves emitted.

# Arguments

- `nb_leaves_emitted`: The number of leaves emitted from planting.
- `initial_stem_height`: The initial stem height at planting (m).
- `stem_height_coefficient`: The coefficient of the exponential function.
- `internode_length_at_maturity`: The internode length when the plant is mature (m).
- `stem_growth_start`: The number of leaves emitted at which the stem starts to grow (m). This is because the stem does not grow at the same rate at the beginning of the plant's life,
because it first grows more in diameter than in height.
- `stem_height_variation`: The variation of the stem height (m) due to the random draw from a normal distribution.
- `rng`: The random number generator.

# Details

The stem height is computed using an exponential function for the first `stem_growth_start` leaves emitted, and then a linear function for the remaining leaves emitted.

Note that the stem height can also be subject to some variability using `stem_height_variation`, simulating natural variations that might occur in real-world scenarios, but
this variability will never make the stem height go below 30% of the intial computed height.
"""
function stem_height(nb_leaves_emitted, initial_stem_height, stem_height_coefficient, internode_length_at_maturity, stem_growth_start, stem_height_variation; rng)
    if nb_leaves_emitted <= stem_growth_start
        stem_height = initial_stem_height * exp(stem_height_coefficient * nb_leaves_emitted)
    else
        stem_height = internode_length_at_maturity * (nb_leaves_emitted - stem_growth_start) + initial_stem_height * exp(stem_height_coefficient * stem_growth_start)
    end

    # Add some variability to the stem_height, simulating natural variations that might occur in real-world scenarios:
    stem_height = max(0.3 * stem_height, mean_and_sd(stem_height, stem_height_variation, rng))
    # Note that we use max(0.3 * stem_height,...) to ensure that the stem height is always at least 30% of the maximum height.

    return stem_height
end

"""
    stem_diameter(rachis_length_reference, stem_diameter_max, stem_diameter_slope, stem_diameter_inflection, stem_diameter_residual; rng)

Computes the stem diameter (m) at a given rachis length reference (m).

# Arguments

- `rachis_length_reference`: The rachis length reference (m). Taken as the rachis length of the first leaf.
- `stem_diameter_max`: The maximum stem diameter (m).
- `stem_diameter_slope`: The slope of the logistic function.
- `stem_diameter_inflection`: The inflection point of the logistic function.
- `stem_diameter_residual`: The residual of the stem diameter (m).
- `stem_diameter_snag`: The diameter estimation due to snags (m).
- `rng`: The random number generator.

# Details

The stem diameter is computed using a logistic function, and then some variability is added to simulate natural variations that might occur in real-world scenarios.
"""
function stem_diameter(rachis_length_reference, stem_diameter_max, stem_diameter_slope, stem_diameter_inflection, stem_diameter_residual, stem_diameter_snag; rng)
    # Logistic function for stem diameter
    stem_diameter = logistic(rachis_length_reference, stem_diameter_max, stem_diameter_slope, stem_diameter_inflection)
    # Add some variability to the stem_diameter, simulating natural variations that might occur in real-world scenarios:
    # Note that we use max(0.3 * stem_diameter,...) to ensure that the stem diamter is always at least 30% of the maximum diameter.
    stem_diameter = max(0.3 * stem_diameter, mean_and_sd(stem_diameter, stem_diameter_residual, rng))
    # Remove extra diameter estimation due to snags
    stem_diameter = stem_diameter - min(stem_diameter_snag, 0.6 * stem_diameter)

    return stem_diameter
end
