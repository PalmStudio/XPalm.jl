
"""
    petiole_length(petiole_rachis_ratio_mean, petiole_rachis_ratio_sd, rachis_length; rng=Random.MersenneTwister(1))
    
Compute the length of the petiole based on the rachis length and the petiole/rachis length ratio.

# Arguments

- `rachis_length`: Length of the rachis (m)
- `petiole_rachis_ratio_mean=0.25`: Average value of the petiole/rachis length ratio
- `petiole_rachis_ratio_sd=0.034`: Standard deviation of the petiole/rachis length ratio
- `rng`: Random number generator

# Returns

The length of the petiole (m)
"""
function petiole_length(rachis_length, petiole_rachis_ratio_mean=0.25, petiole_rachis_ratio_sd=0.034; rng=Random.MersenneTwister(1))
    return mean_and_sd(petiole_rachis_ratio_mean, petiole_rachis_ratio_sd, rng) * rachis_length
end

"""
    petiole_azimuthal_angle(; rng=Random.MersenneTwister(1))

Compute the azimuthal angle of the petiole based on the petiole/rachis length ratio.

# Arguments

- `petiole_rachis_ratio_mean`: Average value of the petiole/rachis length ratio
- `petiole_rachis_ratio_sd`: Standard deviation of the petiole/rachis length ratio
- `rng`: Random number generator

# Returns

The azimuthal angle of the petiole (°)
"""
function petiole_azimuthal_angle(; rng=Random.MersenneTwister(1))
    return normal_deviation_draw(5.0u"°", rng) #! this should be a parameter. And we should be able to remove the randomness with an option.
end

const _LEAF_BASE_JUVENILE_DIMENSION_KEYS = (
    "leaf_base_width_juvenile",
    "leaf_base_height_juvenile",
    "leaf_base_dimensions_juvenile_max_emitted_leaf",
    "leaf_base_dimensions_adult_min_emitted_leaf",
)

"""
    leaf_base_dimensions(emitted_leaf_number, parameters::AbstractDict)

Compute petiole-base dimensions for a leaf emission index. Without the optional
juvenile parameters, return the historical constant dimensions exactly.

When all juvenile parameters are present, the juvenile dimensions are kept up
to `leaf_base_dimensions_juvenile_max_emitted_leaf`. A smoothstep interpolation
in log space then joins them to the historical adult dimensions, which are
reached at `leaf_base_dimensions_adult_min_emitted_leaf`.
"""
function leaf_base_dimensions(emitted_leaf_number, parameters::AbstractDict)
    adult_dimensions = (
        width_base=parameters["leaf_base_width"],
        height_base=parameters["leaf_base_height"],
    )

    parameters_present = map(
        key -> haskey(parameters, key),
        _LEAF_BASE_JUVENILE_DIMENSION_KEYS,
    )
    any(parameters_present) || return adult_dimensions
    all(parameters_present) || throw(
        ArgumentError(
            "The juvenile leaf-base dimension parameters must be provided together",
        ),
    )

    juvenile_dimensions = (
        width_base=parameters["leaf_base_width_juvenile"],
        height_base=parameters["leaf_base_height_juvenile"],
    )
    juvenile_max_emitted_leaf =
        parameters["leaf_base_dimensions_juvenile_max_emitted_leaf"]
    adult_min_emitted_leaf =
        parameters["leaf_base_dimensions_adult_min_emitted_leaf"]

    juvenile_max_emitted_leaf < adult_min_emitted_leaf || throw(
        ArgumentError(
            "leaf_base_dimensions_juvenile_max_emitted_leaf must be lower than leaf_base_dimensions_adult_min_emitted_leaf",
        ),
    )
    juvenile_max_emitted_leaf >= zero(juvenile_max_emitted_leaf) || throw(
        ArgumentError(
            "leaf_base_dimensions_juvenile_max_emitted_leaf must be non-negative",
        ),
    )
    emitted_leaf_number >= zero(emitted_leaf_number) || throw(
        ArgumentError("emitted_leaf_number must be non-negative"),
    )

    for (name, value) in (
        ("leaf_base_width_juvenile", juvenile_dimensions.width_base),
        ("leaf_base_height_juvenile", juvenile_dimensions.height_base),
        ("leaf_base_width", adult_dimensions.width_base),
        ("leaf_base_height", adult_dimensions.height_base),
    )
        value > zero(value) || throw(
            ArgumentError("$name must be strictly positive"),
        )
    end

    emitted_leaf_number <= juvenile_max_emitted_leaf &&
        return juvenile_dimensions
    emitted_leaf_number >= adult_min_emitted_leaf && return adult_dimensions

    transition =
        (emitted_leaf_number - juvenile_max_emitted_leaf) /
        (adult_min_emitted_leaf - juvenile_max_emitted_leaf)
    smoothstep = transition^2 * (3.0 - 2.0 * transition)

    return (
        width_base=
            juvenile_dimensions.width_base *
            (adult_dimensions.width_base / juvenile_dimensions.width_base)^smoothstep,
        height_base=
            juvenile_dimensions.height_base *
            (adult_dimensions.height_base / juvenile_dimensions.height_base)^smoothstep,
    )
end

"""
    petiole_dimensions_at_cpoint(rachis_length, cpoint_width_intercept, cpoint_width_slope, cpoint_height_width_ratio)

Compute the width and height of the petiole at the C point (end-point).

# Arguments

- `rachis_length`: Length of the rachis (m)
- `cpoint_width_intercept=0.0098u"m"`: Intercept of the linear relationship between rachis width at C point and rachis length (m)
- `cpoint_width_slope=0.012`: Slope of the linear relationship
- `cpoint_height_width_ratio=0.568`: Ratio between the height and width of the leaf at C point

# Returns

A named tuple with the following keys:

- `width_cpoint`: Width at the C point of the petiole (m)
- `height_cpoint`: Height at the C point of the petiole (m)
"""
function petiole_dimensions_at_cpoint(rachis_length, cpoint_width_intercept=0.0098u"m", cpoint_width_slope=0.012, cpoint_height_width_ratio=0.568)
    width_cpoint = width_at_cpoint(rachis_length, cpoint_width_intercept, cpoint_width_slope)
    height_cpoint = cpoint_height_width_ratio * width_cpoint
    return (width_cpoint=width_cpoint, height_cpoint=height_cpoint)
end

const _CPOINT_JUVENILE_DIMENSION_KEYS = (
    "cpoint_width_juvenile_coefficient",
    "cpoint_width_juvenile_exponent",
    "cpoint_height_juvenile_coefficient",
    "cpoint_height_juvenile_exponent",
    "cpoint_dimensions_juvenile_max_rachis_length",
    "cpoint_dimensions_adult_min_rachis_length",
)

"""
    petiole_dimensions_at_cpoint(rachis_length, parameters::AbstractDict)

Compute the petiole/rachis dimensions at C from a parameter dictionary. When
the optional juvenile section allometry is absent, this delegates exactly to
the historical linear width allometry and fixed height-to-width ratio.

When all juvenile parameters are present, width and height follow independent
power laws below the juvenile length limit. Between the juvenile and adult
length limits, a smoothstep blend connects those laws to the historical adult
allometry.
"""
function petiole_dimensions_at_cpoint(rachis_length, parameters::AbstractDict)
    adult_dimensions = petiole_dimensions_at_cpoint(
        rachis_length,
        parameters["cpoint_width_intercept"],
        parameters["cpoint_width_slope"],
        parameters["cpoint_height_width_ratio"],
    )

    parameters_present = map(
        key -> haskey(parameters, key),
        _CPOINT_JUVENILE_DIMENSION_KEYS,
    )
    any(parameters_present) || return adult_dimensions
    all(parameters_present) || throw(
        ArgumentError(
            "The juvenile C-point dimension parameters must be provided together",
        ),
    )

    juvenile_max_length =
        parameters["cpoint_dimensions_juvenile_max_rachis_length"]
    adult_min_length =
        parameters["cpoint_dimensions_adult_min_rachis_length"]
    juvenile_max_length < adult_min_length || throw(
        ArgumentError(
            "cpoint_dimensions_juvenile_max_rachis_length must be lower than cpoint_dimensions_adult_min_rachis_length",
        ),
    )
    rachis_length >= zero(rachis_length) || throw(
        ArgumentError("rachis_length must be non-negative"),
    )

    rachis_length >= adult_min_length && return adult_dimensions

    # The fitted coefficients are the dimensions at a one-metre rachis length;
    # keeping the predictor dimensionless makes the power exponents unit-safe.
    relative_rachis_length = rachis_length / (1.0u"m")
    juvenile_dimensions = (
        width_cpoint=
            parameters["cpoint_width_juvenile_coefficient"] *
            relative_rachis_length^parameters["cpoint_width_juvenile_exponent"],
        height_cpoint=
            parameters["cpoint_height_juvenile_coefficient"] *
            relative_rachis_length^parameters["cpoint_height_juvenile_exponent"],
    )
    rachis_length <= juvenile_max_length && return juvenile_dimensions

    transition = (rachis_length - juvenile_max_length) /
                 (adult_min_length - juvenile_max_length)
    smoothstep = transition^2 * (3.0 - 2.0 * transition)
    return (
        width_cpoint=
            (1.0 - smoothstep) * juvenile_dimensions.width_cpoint +
            smoothstep * adult_dimensions.width_cpoint,
        height_cpoint=
            (1.0 - smoothstep) * juvenile_dimensions.height_cpoint +
            smoothstep * adult_dimensions.height_cpoint,
    )
end

"""
    width_at_cpoint(rachis_length, cpoint_width_intercept, cpoint_width_slope)

Compute width at C point based on rachis length.

# Arguments

- `rachis_length`: Length of rachis (m)
- `cpoint_width_intercept`: Intercept of linear function (m)
- `cpoint_width_slope`: Slope of linear function
"""
function width_at_cpoint(rachis_length, cpoint_width_intercept, cpoint_width_slope)
    return linear(rachis_length, cpoint_width_intercept, cpoint_width_slope)
end


"""
    c_point_angle(leaf_rank, cpoint_decli_intercept, cpoint_decli_slope, cpoint_angle_SDP; rng)

Compute the angle at the C point of the leaf.

# Arguments

- `leaf_rank`: Rank of the leaf
- `cpoint_decli_intercept`: Intercept of the linear relationship between leaf rank and C point declination
- `cpoint_decli_slope`: Slope of the linear relationship
- `cpoint_angle_SDP`: Standard deviation of the C point angle
- `rng`: Random number generator

# Returns

The zenithal angle at the C point of the leaf (°)
"""
function c_point_angle(leaf_rank, cpoint_decli_intercept, cpoint_decli_slope, cpoint_angle_SDP; rng=Random.MersenneTwister(1))
    angle = linear(leaf_rank, cpoint_decli_intercept, cpoint_decli_slope)
    angle += normal_deviation_draw(cpoint_angle_SDP, rng) |> abs
    angle = leaf_rank < 3 ? 0.5 * angle : angle
    return angle * unit(cpoint_decli_intercept)
end

"""
    petiole_height(relative_position, height_cpoint, height_base)

Compute the height profile along the petiole (m).

# Arguments

- `relative_position`: Position along the petiole (0-1)
- `height_base`: Height at the base of the leaf
- `height_cpoint`: Height of the leaf section at C point
"""
function petiole_height(relative_position, height_base, height_cpoint)
    return height_base - (height_base - height_cpoint) * sqrt(relative_position)
end

"""
    petiole_width(relative_position, width_cpoint, width_base)

Compute the width profile along the petiole (m).

# Arguments

- `relative_position`: Position along the petiole (0-1) 
- `width_base`: Width at base of leaf
- `width_cpoint`: Width of the leaf at C point
"""
function petiole_width(relative_position, width_base, width_cpoint)
    return width_base - (width_base - width_cpoint) * relative_position^0.17
end
