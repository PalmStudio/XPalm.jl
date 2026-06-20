import YAML
import OrderedCollections
import Unitful: @u_str, uconvert, unit, NoUnits

macro _vpalm_check_unit(variable, expected_unit, verbose=true, param_name=nothing)
    in_var_name = string(variable)
    return quote
        local var_name = isnothing($(esc(param_name))) ? $(in_var_name) : $(esc(param_name))
        local var = $(esc(variable))
        local exp_unit = $(esc(expected_unit))
        local is_verbose = $(esc(verbose))

        if unit(var) == NoUnits
            is_verbose && @warn "The `$(var_name)` argument should have units, using $(exp_unit) as default."
            var = var * exp_unit
        else
            try
                var = uconvert(exp_unit, var)
            catch
                error("Cannot convert $(var_name) from $(unit(var)) to $(exp_unit)")
            end
        end

        var
    end
end

function _vpalm_read_parameters(file; verbose=false)
    p = YAML.load_file(file; dicttype=OrderedCollections.OrderedDict{String,Any})

    for param in (
        "seed",
        "nb_leaves_emitted",
        "stem_growth_start",
        "nb_leaves_in_sheath",
        "internode_rank_no_expansion",
        "nbInflorescences",
    )
        p[param] = Int(p[param])
    end

    for param in (
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
        "leaflet_length_at_b_intercept",
        "leaflet_width_at_b_intercept",
    )
        haskey(p, param) && (p[param] = @_vpalm_check_unit p[param] u"m" verbose param)
    end

    for param in (
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
        haskey(p, param) && (p[param] = @_vpalm_check_unit p[param] u"°" verbose param)
    end

    if haskey(p, "rachis_fresh_weight")
        p["rachis_fresh_weight"] = uconvert.(
            u"kg",
            [@_vpalm_check_unit rachis_fw u"g" verbose "rachis_fresh_weight" for rachis_fw in p["rachis_fresh_weight"]],
        )
    end

    if haskey(p, "rachis_final_lengths")
        p["rachis_final_lengths"] = [
            @_vpalm_check_unit rachis_length u"m" verbose "rachis_final_lengths"
            for rachis_length in p["rachis_final_lengths"]
        ]
    end

    if haskey(p, "leaf_length_intercept") && haskey(p, "leaf_length_slope")
        p["leaf_length_intercept"] =
            @_vpalm_check_unit p["leaf_length_intercept"] u"m" verbose "leaf_length_intercept"
        p["leaf_length_slope"] =
            @_vpalm_check_unit p["leaf_length_slope"] u"m/kg" verbose "leaf_length_slope"
    end

    for param in (
        "elastic_modulus",
        "shear_modulus",
        "leaflet_stiffness",
        "leaflet_stiffness_sd",
    )
        haskey(p, param) && (p[param] = @_vpalm_check_unit p[param] u"MPa" verbose param)
    end

    if haskey(p, "biomechanical_model") && haskey(p["biomechanical_model"], "angle_max")
        p["biomechanical_model"]["angle_max"] =
            @_vpalm_check_unit p["biomechanical_model"]["angle_max"] u"°" verbose "angle_max"
    end

    @assert p["nb_leaves_emitted"] > 0
    return p
end

function _default_vpalm_parameters(; type="static")
    type in ("static", "dynamic") || throw(ArgumentError("""type must be "static" or "dynamic"."""))
    file_name = type == "static" ? "vpalm-parameter_file.yml" : "vpalm-parameter_file_dynamic.yml"
    file = joinpath(dirname(@__DIR__), "test", "references", file_name)
    return _vpalm_read_parameters(file)
end
