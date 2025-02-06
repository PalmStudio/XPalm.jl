

"""
    xpalm(meteo; vars=Dict("Scene" => (:lai,)), palm=Palm(initiation_age=0, parameters=default_parameters()))
    xpalm(meteo, sink; vars=Dict("Scene" => (:lai,)), palm=Palm(initiation_age=0, parameters=default_parameters()))

Run the XPalm model with the given meteo data and return the results in a DataFrame.

# Arguments

- `meteo`: DataFrame with the meteo data
- `sink`: a `Tables.jl` compatible sink function to format the results, for exemple a `DataFrame`
- `vars`: A dictionary with the outputs to be returned for each scale of simulation
- `palm`: the Palm object with the parameters of the model

# Returns

A simulation output, either as a dictionary of variables per scales (default) or as a `Tables.jl` formatted object.

# Example

```julia
using XPalmModel, CSV, DataFrames
meteo = CSV.read(joinpath(dirname(dirname(pathof(XPalmModel))), "0-data/meteo.csv"), DataFrame)
df = xpalm(meteo; vars= Dict("Scene" => (:lai,)), sink=DataFrame)
```
"""
function xpalm(meteo, sink; vars=Dict("Scene" => (:lai,)), palm=Palm(initiation_age=0, parameters=default_parameters()))
    models = model_mapping(palm)
    out = PlantSimEngine.run!(palm.mtg, models, meteo, outputs=vars, executor=PlantSimEngine.SequentialEx(), check=false)
    return PlantSimEngine.outputs(out, sink, no_value=missing)
end

function xpalm(meteo; vars=Dict("Scene" => (:lai,)), palm=Palm(initiation_age=0, parameters=default_parameters()))
    models = model_mapping(palm)
    out = PlantSimEngine.run!(palm.mtg, models, meteo, outputs=vars, executor=PlantSimEngine.SequentialEx(), check=false)
    return PlantSimEngine.outputs(out)
end