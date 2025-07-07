

"""
    xpalm(meteo; vars=Dict("Scene" => (:lai,)), architecture=false, palm=Palm(initiation_age=0, parameters=default_parameters()))
    xpalm(meteo, sink; vars=Dict("Scene" => (:lai,)), architecture=false, palm=Palm(initiation_age=0, parameters=default_parameters()))

Run the XPalm model with the given meteo data and return the results in a DataFrame.

# Arguments

- `meteo`: DataFrame with the meteo data
- `sink`: a `Tables.jl` compatible sink function to format the results, for exemple a `DataFrame`
- `vars`: A dictionary with the outputs to be returned for each scale of simulation
- `architecture`: A boolean indicating whether to compute the 3D architecture of the palm (default is false)
- `palm`: the Palm object with the parameters of the model

# Returns

A simulation output, either as a dictionary of variables per scales (default) or as a `Tables.jl` formatted object.

# Example

```julia
using XPalm, CSV, DataFrames
meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalm))), "0-data/meteo.csv"), DataFrame)
df = xpalm(meteo, DataFrame; vars= Dict("Scene" => (:lai,)))
```
"""
function xpalm(meteo, sink; vars=Dict("Scene" => (:lai,)), architecture=false, palm=Palm(initiation_age=0, parameters=default_parameters(), architecture=architecture))
    models = model_mapping(palm, architecture=architecture)
    out = PlantSimEngine.run!(palm.mtg, models, meteo, tracked_outputs=vars, executor=PlantSimEngine.SequentialEx(), check=false)
    return PlantSimEngine.convert_outputs(out, sink, no_value=missing)
end

function xpalm(meteo; vars=Dict("Scene" => (:lai,)), architecture=false, palm=Palm(initiation_age=0, parameters=default_parameters(), architecture=architecture))
    models = model_mapping(palm, architecture=architecture)
    out = PlantSimEngine.run!(palm.mtg, models, meteo, tracked_outputs=vars, executor=PlantSimEngine.SequentialEx(), check=false)
    return out
end