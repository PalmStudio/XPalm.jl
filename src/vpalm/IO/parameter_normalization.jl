import Unitful: @u_str, NoUnits, uconvert, unit

const _VPALM_INTEGER_PARAMETERS = (
    "seed",
    "nb_leaves_emitted",
    "stem_growth_start",
    "nb_leaves_in_sheath",
    "internode_rank_no_expansion",
    "nbInflorescences",
)

const _VPALM_LENGTH_PARAMETERS = (
    "initial_stem_height",
    "internode_length_at_maturity",
    "stem_height_variation",
    "stem_diameter_max",
    "stem_diameter_inflection",
    "stem_diameter_residual",
    "leaflets_nb_inflexion",
    "stem_diameter_snag",
    "internode_final_length",
    "leaf_base_width",
    "cpoint_width_intercept",
    "rachis_width_tip",
    "leaf_base_height",
    "rachis_length_reference",
    "rachis_length_age_intercept",
    "rachis_length_age_slope",
    "rachis_length_age_max",
    "leaflet_length_at_b_intercept",
    "leaflet_width_at_b_intercept",
)

const _VPALM_ANGLE_PARAMETERS = (
    "phyllotactic_angle_mean",
    "phyllotactic_angle_sd",
    "stem_bending_mean",
    "stem_bending_sd",
    "leaf_max_angle",
    "cpoint_decli_intercept",
    "cpoint_angle_SDP",
    "rachis_twist_initial_angle",
    "rachis_twist_initial_angle_sdp",
    "leaflet_lamina_angle",
    "leafletAxialAngleC",
    "leafletAxialAngleA",
    "leafletAxialAngleSlope",
    "leafletAxialAngle_SDP",
    "leaflet_axial_angle_c",
    "leaflet_axial_angle_a",
    "leaflet_axial_angle_sdp",
)

const _VPALM_PRESSURE_PARAMETERS = (
    "elastic_modulus",
    "shear_modulus",
    "leaflet_stiffness",
    "leaflet_stiffness_sd",
)

function _vpalm_parameter_unit(value, expected_unit, verbose, parameter_name)
    if unit(value) == NoUnits
        verbose && @warn "The `$(parameter_name)` argument should have units, using $(expected_unit) as default."
        return value * expected_unit
    end

    try
        return uconvert(expected_unit, value)
    catch
        error(
            "Cannot convert $(parameter_name) from $(unit(value)) to $(expected_unit)",
        )
    end
end

# Normalize one parsed VPalm parameter dictionary to the canonical runtime values.
function _normalize_vpalm_parameters!(parameters::AbstractDict; verbose=false)
    for parameter in _VPALM_INTEGER_PARAMETERS
        parameters[parameter] = Int(parameters[parameter])
    end

    for parameter in _VPALM_LENGTH_PARAMETERS
        haskey(parameters, parameter) && (
            parameters[parameter] = _vpalm_parameter_unit(
                parameters[parameter],
                u"m",
                verbose,
                parameter,
            )
        )
    end

    for parameter in _VPALM_ANGLE_PARAMETERS
        haskey(parameters, parameter) && (
            parameters[parameter] = _vpalm_parameter_unit(
                parameters[parameter],
                u"°",
                verbose,
                parameter,
            )
        )
    end

    if haskey(parameters, "rachis_fresh_weight")
        parameters["rachis_fresh_weight"] = uconvert.(
            u"kg",
            [
                _vpalm_parameter_unit(
                    fresh_weight,
                    u"g",
                    verbose,
                    "rachis_fresh_weight",
                ) for fresh_weight in parameters["rachis_fresh_weight"]
            ],
        )
    end

    if haskey(parameters, "rachis_final_lengths")
        parameters["rachis_final_lengths"] = [
            _vpalm_parameter_unit(
                rachis_length,
                u"m",
                verbose,
                "rachis_final_lengths",
            ) for rachis_length in parameters["rachis_final_lengths"]
        ]
    end

    if haskey(parameters, "leaf_length_intercept") &&
       haskey(parameters, "leaf_length_slope")
        parameters["leaf_length_intercept"] = _vpalm_parameter_unit(
            parameters["leaf_length_intercept"],
            u"m",
            verbose,
            "leaf_length_intercept",
        )
        parameters["leaf_length_slope"] = _vpalm_parameter_unit(
            parameters["leaf_length_slope"],
            u"m/kg",
            verbose,
            "leaf_length_slope",
        )
    end

    for parameter in _VPALM_PRESSURE_PARAMETERS
        haskey(parameters, parameter) && (
            parameters[parameter] = _vpalm_parameter_unit(
                parameters[parameter],
                u"MPa",
                verbose,
                parameter,
            )
        )
    end

    if haskey(parameters, "biomechanical_model") &&
       haskey(parameters["biomechanical_model"], "angle_max")
        parameters["biomechanical_model"]["angle_max"] = _vpalm_parameter_unit(
            parameters["biomechanical_model"]["angle_max"],
            u"°",
            verbose,
            "angle_max",
        )
    end

    p = parameters
    @assert p["nb_leaves_emitted"] > 0
    return parameters
end
