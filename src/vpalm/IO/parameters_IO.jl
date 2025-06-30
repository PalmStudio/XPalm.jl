"""
    read_parameters(file; verbose=true)

Reads a parameter file and returns the contents as an ordered dictionary.

# Arguments

- `file`: The path to the parameter file.
- `verbose`: Whether to show warnings for units (default: true)

# Returns

An ordered dictionary containing the contents of the parameter file with appropriate units.

# Example

```julia
file = joinpath(dirname(dirname(pathof(VPalm))),"test","files","parameter_file.yml")
read_parameters(file)
```
"""
function read_parameters(file; verbose=false)
    p = YAML.load_file(file; dicttype=OrderedCollections.OrderedDict{String,Any})

    # Convert integer parameters
    p["seed"] = p["seed"] |> Int
    p["nb_leaves_emitted"] = p["nb_leaves_emitted"] |> Int
    p["stem_growth_start"] = p["stem_growth_start"] |> Int
    p["nb_leaves_in_sheath"] = p["nb_leaves_in_sheath"] |> Int
    p["internode_rank_no_expansion"] = p["internode_rank_no_expansion"] |> Int
    p["nbInflorescences"] = p["nbInflorescences"] |> Int

    # Apply length units (meters)
    length_params = [
        "initial_stem_height", "internode_length_at_maturity",
        "stem_height_variation", "stem_diameter_max", "stem_diameter_inflection",
        "stem_diameter_residual", "leaflets_nb_inflexion",
        "stem_diameter_snag", "internode_final_length",
        "leaf_base_width", "cpoint_width_intercept",
        "rachis_width_tip", "leaf_base_height",
        "rachis_length_reference", "leaflet_length_at_b_intercept", "leaflet_width_at_b_intercept",
    ]

    for param in length_params
        if haskey(p, param)
            p[param] = @check_unit p[param] u"m" verbose param
        end
    end

    # Apply angle units (degrees)
    angle_params = [
        "phyllotactic_angle_mean", "phyllotactic_angle_sd",
        "stem_bending_mean", "stem_bending_sd",
        "leaf_max_angle",
        "cpoint_decli_intercept",
        "cpoint_angle_SDP", "rachis_twist_initial_angle",
        "rachis_twist_initial_angle_sdp", "leaflet_lamina_angle",
        "leafletAxialAngleC", "leafletAxialAngleA",
        "leafletAxialAngleSlope", "leafletAxialAngle_SDP",
        "leaflet_axial_angle_c", "leaflet_axial_angle_a",
        "leaflet_axial_angle_sdp"
    ]

    for param in angle_params
        if haskey(p, param)
            p[param] = @check_unit p[param] u"°" verbose param
        end
    end

    # Apply mass units for rachis_fresh_weight (kg)
    if haskey(p, "rachis_fresh_weight")
        p["rachis_fresh_weight"] = uconvert.(u"kg", [@check_unit rachis_fw u"g" verbose "rachis_fresh_weight" for rachis_fw in p["rachis_fresh_weight"]])
    end

    # Apply length units for rachis_final_lengths (m)
    if haskey(p, "rachis_final_lengths")
        p["rachis_final_lengths"] = [@check_unit rachis_length u"m" verbose "rachis_final_lengths" for rachis_length in p["rachis_final_lengths"]]
    else
        haskey(p, "leaf_length_intercept") || haskey(p, "leaf_length_slope") || error("Either 'rachis_final_lengths' or both 'leaf_length_intercept' and 'leaf_length_slope' must be provided.")
        p["leaf_length_intercept"] = @check_unit p["leaf_length_intercept"] u"m" verbose "leaf_length_intercept"
        p["leaf_length_slope"] = @check_unit p["leaf_length_slope"] u"m/kg" verbose "leaf_length_slope"
    end

    # Apply pressure units (MPa) for elastic and shear modulus
    pressure_params = [
        "elastic_modulus", "shear_modulus", "leaflet_stiffness", "leaflet_stiffness_sd"
    ]

    for param in pressure_params
        if haskey(p, param)
            p[param] = @check_unit p[param] u"MPa" verbose param
        end
    end

    # Apply units to biomechanical model parameters
    if haskey(p, "biomechanical_model")
        if haskey(p["biomechanical_model"], "angle_max")
            p["biomechanical_model"]["angle_max"] = @check_unit p["biomechanical_model"]["angle_max"] u"°" verbose "angle_max"
        end
    end

    @assert p["nb_leaves_emitted"] > 0
    return p
end

"""
    write_parameters(file, params)

Write the given parameters to a file using YAML format.

# Arguments
- `file`: The file path to write the parameters to.
- `params`: The parameters to be written.

# Example

```julia
file = joinpath(dirname(dirname(pathof(VPalm))),"test","files","parameter_file.yml")
params = read_parameters(file)
write_parameters(tempname(), params)
```
"""
function write_parameters(file, params)

    params["rachis_fresh_weight"] = uconvert.(u"g", params["rachis_fresh_weight"])
    # Strip units before writing to YAML
    params_no_units = OrderedCollections.OrderedDict{String,Any}()
    for (k, v) in params
        if applicable(unit, v)
            params_no_units[k] = ustrip(v)
        elseif v isa Vector && length(v) > 0 && applicable(unit, v[1])
            params_no_units[k] = ustrip.(v)
        elseif v isa Dict || v isa OrderedCollections.OrderedDict
            params_no_units[k] = Dict(sk => applicable(unit, sv) ? ustrip(sv) : sv for (sk, sv) in v)
        else
            params_no_units[k] = v
        end
    end

    YAML.write_file(file, params_no_units)
end



"""
    default_parameters()

Returns a dictionary of default parameters for the VPalm model.

# Example

```julia
default_params = default_parameters()
```
"""
function default_parameters()
    YAML.load_file(joinpath(dirname(pathof(VPalm)), "test", "references", "vpalm-parameter_file.yml"))
end