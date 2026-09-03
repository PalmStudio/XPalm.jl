import YAML
import OrderedCollections

function _vpalm_read_parameters(file; verbose=false)
    p = YAML.load_file(file; dicttype=OrderedCollections.OrderedDict{String,Any})
    return _normalize_vpalm_parameters!(p; verbose)
end

function _default_vpalm_parameters(; type="static")
    type in ("static", "dynamic") || throw(ArgumentError("""type must be "static" or "dynamic"."""))
    file_name = type == "static" ? "vpalm-parameter_file.yml" : "vpalm-parameter_file_dynamic.yml"
    file = joinpath(dirname(@__DIR__), "test", "references", file_name)
    return _vpalm_read_parameters(file)
end
