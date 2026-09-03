"""
    read_parameters(file; verbose=false)

Reads a parameter file and returns the contents as an ordered dictionary.

# Arguments

- `file`: The path to the parameter file.
- `verbose`: Whether to show warnings for units (default: false)

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
    return _normalize_vpalm_parameters!(p; verbose)
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
    default_parameters(; type="static")

Returns a dictionary of default parameters for the VPalm model.

# Arguments

- `type`: The type of parameters to return, either "static" or "dynamic". Default is "static".

# Details

VPalm can be used in two modes:

- "static": For static plant architecture, where the plant structure does not change over time. The parameters are measured from one or several real oil palm plants and are used to build mockups of the plant architecture,
which can then be used for simulations or visualizations around this age.
- "dynamic": For dynamic plant architecture, where the plant structure can change over time (e.g., growth, environmental effects). This is typically used for simulations that involve plant growth over time (like XPalm), or for digital twins of oil palm plants.

# Example

```julia
default_params = default_parameters()
```
"""
function default_parameters(; type="static")
    type in ("static", "dynamic") || throw(ArgumentError("""type must be "static" or "dynamic"."""))
    file_name = type == "static" ? "vpalm-parameter_file.yml" : "vpalm-parameter_file_dynamic.yml"
    file = joinpath(dirname(dirname(dirname(@__DIR__))), "test", "references", file_name)
    read_parameters(file)
end
